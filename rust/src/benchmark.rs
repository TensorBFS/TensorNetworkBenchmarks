//! Benchmark runner for omeinsum-rs
//!
//! Loads tensor network from JSON and benchmarks contraction.

use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::PathBuf;
use std::time::Instant;

use chrono::Utc;
use clap::Parser;
use omeco::{EinCode, NestedEinsum};
use omeinsum::algebra::Standard;
use omeinsum::{Cpu, Einsum, Tensor};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sysinfo::System;

/// Benchmark runner for omeinsum-rs
#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Args {
    /// Path to tensor network JSON file
    #[arg(short, long, default_value = "../data/tensornetwork_permutation_optimized.json")]
    tensornetwork: PathBuf,

    /// Number of benchmark repetitions
    #[arg(short, long, default_value = "10")]
    repeat_times: usize,

    /// Number of threads (for BLAS)
    #[arg(short, long, default_value = "1")]
    nthreads: usize,

    /// Output results directory
    #[arg(short, long, default_value = "../results")]
    output_dir: PathBuf,
}

/// CPU information for results
#[derive(Serialize)]
struct CpuInfo {
    cpu_name: String,
    cpu_threads: usize,
    machine: String,
}

/// Benchmark result
#[derive(Serialize)]
struct BenchmarkResult {
    framework: String,
    device: String,
    backend: String,
    nthreads: usize,
    tensornetwork: String,
    repeat_times: usize,
    min_time: f64,
    avg_time: f64,
    total_time: f64,
    all_times: Vec<f64>,
    result: f32,
    timestamp: String,
    cpu_info: CpuInfo,
    gpu_info: Option<()>,
}

/// JSON structure for tensor network file
#[derive(Deserialize, Debug)]
#[allow(dead_code)]
struct TensorNetwork {
    slices: Vec<Value>,
    output: Vec<usize>,
    tree: TreeNode,
}

/// Tree node in the JSON
#[derive(Deserialize, Debug)]
struct TreeNode {
    isleaf: bool,
    #[serde(default)]
    tensorindex: Option<usize>,
    #[serde(default)]
    eins: Option<EinsSpec>,
    #[serde(default)]
    args: Option<Vec<TreeNode>>,
}

/// Einsum specification in the JSON
#[derive(Deserialize, Debug)]
struct EinsSpec {
    ixs: Vec<Vec<usize>>,
    iy: Vec<usize>,
}

/// Convert JSON tree to omeco's NestedEinsum
fn parse_tree(node: &TreeNode) -> NestedEinsum<usize> {
    if node.isleaf {
        // JSON uses 1-indexed tensor indices, convert to 0-indexed
        let tensor_index = node.tensorindex.expect("Leaf node must have tensorindex") - 1;
        NestedEinsum::leaf(tensor_index)
    } else {
        let eins_spec = node.eins.as_ref().expect("Non-leaf node must have eins");
        let args = node.args.as_ref().expect("Non-leaf node must have args");

        let child_trees: Vec<_> = args.iter().map(|arg| parse_tree(arg)).collect();
        let eins = EinCode::new(eins_spec.ixs.clone(), eins_spec.iy.clone());

        NestedEinsum::node(child_trees, eins)
    }
}

/// Collect all tensor indices and their shapes from the tree
fn collect_tensor_info(node: &TreeNode, parent_ixs: Option<&[usize]>) -> Vec<(usize, Vec<usize>)> {
    if node.isleaf {
        let tensor_index = node.tensorindex.expect("Leaf must have tensorindex");
        let ixs = parent_ixs.expect("Leaf must have parent indices").to_vec();
        vec![(tensor_index, ixs)]
    } else {
        let eins_spec = node.eins.as_ref().expect("Non-leaf must have eins");
        let args = node.args.as_ref().expect("Non-leaf must have args");

        let mut results = Vec::new();
        for (i, arg) in args.iter().enumerate() {
            let child_ixs = &eins_spec.ixs[i];
            results.extend(collect_tensor_info(arg, Some(child_ixs)));
        }
        results
    }
}

/// Build size dictionary (all indices have size 2)
fn build_size_dict(tensor_infos: &[(usize, Vec<usize>)]) -> HashMap<usize, usize> {
    let mut size_dict = HashMap::new();
    for (_, ixs) in tensor_infos {
        for &ix in ixs {
            size_dict.insert(ix, 2);
        }
    }
    size_dict
}

/// Get CPU information
fn get_cpu_info() -> CpuInfo {
    let sys = System::new_all();
    let cpu_name = sys
        .cpus()
        .first()
        .map(|c| c.brand().to_string())
        .unwrap_or_else(|| "Unknown".to_string());

    CpuInfo {
        cpu_name,
        cpu_threads: sys.cpus().len(),
        machine: std::env::consts::ARCH.to_string(),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Set number of threads for BLAS
    std::env::set_var("OPENBLAS_NUM_THREADS", args.nthreads.to_string());
    std::env::set_var("MKL_NUM_THREADS", args.nthreads.to_string());

    println!("Running omeinsum-rs CPU benchmark with {} thread(s)...", args.nthreads);

    // Load tensor network from JSON
    let file = File::open(&args.tensornetwork)?;
    let reader = BufReader::new(file);
    let network: TensorNetwork = serde_json::from_reader(reader)?;

    println!("  Loaded tensor network from {:?}", args.tensornetwork);

    // Parse the contraction tree
    let tree = parse_tree(&network.tree);

    // Collect tensor information
    let tensor_infos = collect_tensor_info(&network.tree, None);
    let num_tensors = tensor_infos.iter().map(|(i, _)| *i).max().unwrap_or(0);
    println!("  Number of tensors: {}", num_tensors);

    // Build size dictionary
    let size_dict = build_size_dict(&tensor_infos);
    println!("  Number of unique indices: {}", size_dict.len());

    // Create input index vectors for Einsum (sorted by tensor index)
    let mut sorted_infos = tensor_infos.clone();
    sorted_infos.sort_by_key(|(i, _)| *i);

    let ixs: Vec<Vec<usize>> = sorted_infos.iter().map(|(_, ixs)| ixs.clone()).collect();

    // Create Einsum with the pre-optimized tree
    let mut einsum = Einsum::new(ixs, network.output.clone(), size_dict);
    einsum.set_contraction_tree(tree);

    // Create tensors (all filled with 0.5^0.4)
    let fill_value: f32 = 0.5_f32.powf(0.4);
    let tensors: Vec<Tensor<f32, Cpu>> = sorted_infos
        .iter()
        .map(|(_, ixs)| {
            let shape: Vec<usize> = ixs.iter().map(|_| 2).collect();
            let size: usize = shape.iter().product();
            Tensor::from_data(&vec![fill_value; size], &shape)
        })
        .collect();

    let tensor_refs: Vec<&Tensor<f32, Cpu>> = tensors.iter().collect();

    // Warm up
    println!("  Warming up...");
    for _ in 0..3 {
        let _ = einsum.execute::<Standard<f32>, f32, Cpu>(&tensor_refs);
    }

    // Benchmark
    println!("  Running {} iterations...", args.repeat_times);
    let mut times = Vec::with_capacity(args.repeat_times);
    let total_start = Instant::now();

    for _ in 0..args.repeat_times {
        let start = Instant::now();
        let _ = einsum.execute::<Standard<f32>, f32, Cpu>(&tensor_refs);
        let elapsed = start.elapsed().as_secs_f64();
        times.push(elapsed);
    }

    let total_time = total_start.elapsed().as_secs_f64();
    let min_time = times.iter().cloned().fold(f64::INFINITY, f64::min);
    let avg_time = times.iter().sum::<f64>() / times.len() as f64;

    // Get result value
    let result = einsum.execute::<Standard<f32>, f32, Cpu>(&tensor_refs);
    let result_val = result.to_vec()[0];

    println!("  Result: {}", result_val);
    println!("  Min time: {:.4}s", min_time);
    println!("  Avg time: {:.4}s", avg_time);
    println!("  Total time: {:.4}s", total_time);

    // Create results directory if needed
    std::fs::create_dir_all(&args.output_dir)?;

    // Save results
    let result = BenchmarkResult {
        framework: "omeinsum-rs".to_string(),
        device: "cpu".to_string(),
        backend: "openblas".to_string(),
        nthreads: args.nthreads,
        tensornetwork: args.tensornetwork.to_string_lossy().to_string(),
        repeat_times: args.repeat_times,
        min_time,
        avg_time,
        total_time,
        all_times: times,
        result: result_val,
        timestamp: Utc::now().format("%Y-%m-%dT%H:%M:%S").to_string(),
        cpu_info: get_cpu_info(),
        gpu_info: None,
    };

    let output_path = args.output_dir.join("rust_cpu.json");
    let file = File::create(&output_path)?;
    serde_json::to_writer_pretty(file, &result)?;

    println!("  Results saved to: {:?}", output_path);

    Ok(())
}
