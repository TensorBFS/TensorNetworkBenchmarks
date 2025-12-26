#import "@preview/cetz:0.4.0": canvas, draw
#import "@preview/cetz-plot:0.1.2": plot, chart
#show link: set text(blue)

// Read the benchmark results
#let summary = json("results/summary.json")
#let results = summary.results

// Separate GPU and CPU results
#let gpu_results = results.filter(r => r.device == "gpu")
#let cpu_results = results.filter(r => r.device == "cpu")

// Extract hardware info
#let gpu_result = gpu_results.find(r => r.gpu_info != none)
#let gpu_name = if gpu_result != none and gpu_result.gpu_info != none { gpu_result.gpu_info.name } else { "Unknown GPU" }
#let cuda_version = if gpu_result != none and gpu_result.gpu_info != none and "cuda_version" in gpu_result.gpu_info { gpu_result.gpu_info.cuda_version } else { "N/A" }

#let cpu_result = results.find(r => r.cpu_info != none)
#let cpu_name = if cpu_result != none and cpu_result.cpu_info != none and "cpu_name" in cpu_result.cpu_info { cpu_result.cpu_info.cpu_name } else if cpu_result != none and cpu_result.cpu_info != none and "processor" in cpu_result.cpu_info { cpu_result.cpu_info.processor } else { "Unknown CPU" }

// Create label for framework/backend
#let get_label(framework, backend) = {
  if framework == "pytorch" and backend == "cuda" { "PyTorch" }
  else if framework == "pytorch" and backend == "cpu" { "PyTorch" }
  else if backend == "cublas" { "OMEinsum\n (CUBLAS)" }
  else if backend == "cutensor" { "OMEinsum\n (cuTENSOR)" }
  else if backend == "MKL" { "OMEinsum (MKL)" }
  else { framework + " (" + backend + ")" }
}

// ============================================================================
// Report Header
// ============================================================================
#align(center, text(18pt, weight: "bold")[Tensor Network Contraction Benchmarks])
#align(center, text(10pt, fill: gray)[Generated: #summary.generated_at])

#v(15pt)

// ============================================================================
// Hardware & Configuration
// ============================================================================
#box(
  width: 100%,
  stroke: 0.5pt + gray,
  inset: 10pt,
  radius: 4pt,
)[
  #grid(
    columns: (1fr, 1fr),
    gutter: 10pt,
    [*GPU:* #gpu_name],
    [*CUDA Version:* #cuda_version],
    [*CPU:* #cpu_name],
    [*Data Type:* Float32],
  )
]

#v(15pt)

// ============================================================================
// GPU Benchmark Results - Plot
// ============================================================================
#if gpu_results.len() > 0 {
  figure({
    let bar_data = ()
    
    for result in gpu_results {
      bar_data.push((get_label(result.framework, result.backend), result.min_time))
    }
    
    canvas(length: 1cm, {
      chart.columnchart(
        size: (10, 5),
        label-key: 0,
        value-key: 1,
        bar-width: 0.6,
        y-label: "Time (seconds)",
        bar_data,
      )
    })
  }, caption: [GPU Benchmark - Minimum Execution Time (lower is better)])
}

#v(10pt)

// ============================================================================
// Results Table
// ============================================================================
#{
  let pytorch_gpu = gpu_results.find(r => r.framework == "pytorch")
  let pytorch_gpu_min = if pytorch_gpu != none { pytorch_gpu.min_time } else { 1.0 }
  
  figure(
    table(
      columns: 5,
      stroke: 0.5pt,
      align: (left, left, center, center, center),
      table.header(
        [*Device*], [*Framework*], [*Min Time (s)*], [*Avg Time (s)*], [*Speedup*]
      ),
      // GPU results
      ..for result in gpu_results {
        let speedup = pytorch_gpu_min / result.min_time
        let speedup_str = if result.framework == "pytorch" {
          "baseline"
        } else if speedup >= 1.0 {
          str(calc.round(speedup, digits: 2)) + "× faster"
        } else {
          str(calc.round(1.0/speedup, digits: 2)) + "× slower"
        }
        let avg_time = if "avg_time" in result { result.avg_time } else { result.min_time }
        (
          "GPU",
          get_label(result.framework, result.backend),
          str(calc.round(result.min_time, digits: 4)),
          str(calc.round(avg_time, digits: 4)),
          speedup_str
        )
      },
      // CPU results - only show time, no speedup
      ..for result in cpu_results {
        let avg_time = if "avg_time" in result { result.avg_time } else { result.min_time }
        (
          "CPU",
          get_label(result.framework, result.backend),
          str(calc.round(result.min_time, digits: 4)),
          str(calc.round(avg_time, digits: 4)),
          "—"
        )
      }
    ),
    caption: [Benchmark Results]
  )
}

#v(15pt)

// ============================================================================
// Notes
// ============================================================================
#text(size: 9pt)[
  *Notes:* Tensor network has 220 nodes with degree 3. Contraction order optimized using TreeSA algorithm. GPU benchmarks synchronize CUDA operations for accurate timing.
  
  For more details, see the #link("https://github.com/under-Peter/OMEinsum.jl/issues/133")[original discussion].
]
