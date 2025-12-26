#import "@preview/cetz:0.4.0": canvas, draw
#import "@preview/cetz-plot:0.1.2": plot
#show link: set text(blue)

// Read the benchmark results
#let summary = json("results/summary.json")
#let results = summary.results

// Define colors for different frameworks/backends
#let get_color(framework, backend) = {
  if framework == "pytorch" {
    if backend == "cuda" { orange }
    else { red }
  } else if framework == "OMEinsum" {
    if backend == "cublas" { blue }
    else if backend == "cutensor" { green }
    else { purple }  // MKL/CPU
  } else {
    gray
  }
}

// Create label for framework/backend
#let get_label(framework, backend) = {
  if framework == "pytorch" {
    "PyTorch (" + backend + ")"
  } else {
    "OMEinsum (" + backend + ")"
  }
}

// Separate GPU and CPU results
#let gpu_results = results.filter(r => r.device == "gpu")
#let cpu_results = results.filter(r => r.device == "cpu")

// ============================================================================
// Report Header
// ============================================================================
#align(center, text(16pt, weight: "bold")[Tensor Network Contraction Benchmarks])
#align(center, text(10pt, fill: gray)[Generated: #summary.generated_at])

#v(20pt)

This report compares the performance of *PyTorch* and *OMEinsum.jl* for tensor network contractions. OMEinsum is tested with different backends: CUBLAS (default) and cuTENSOR.

// ============================================================================
// GPU Benchmark Comparison
// ============================================================================
#if gpu_results.len() > 0 {
  [== GPU Benchmark Comparison]
  v(10pt)
  
  // Find PyTorch GPU baseline
  let pytorch_gpu = gpu_results.find(r => r.framework == "pytorch")
  let pytorch_min = if pytorch_gpu != none { pytorch_gpu.min_time } else { 1.0 }
  
  // Bar chart for GPU results
  figure({
    canvas(length: 1cm, {
      let bar_data = ()
      let labels = ()
      let colors_list = ()
      
      for result in gpu_results {
        bar_data.push(result.min_time)
        labels.push(get_label(result.framework, result.backend))
        colors_list.push(get_color(result.framework, result.backend))
      }
      
      let max_time = calc.max(..bar_data) * 1.2
      
      plot.plot(
        size: (12, 6),
        x-label: none,
        y-label: "Minimum Time (seconds)",
        x-min: 0,
        x-max: gpu_results.len() + 1,
        y-min: 0,
        y-max: max_time,
        x-tick-step: none,
        legend: "inner-north-east",
        {
          let i = 1
          for result in gpu_results {
            let min_time = result.min_time
            let color = get_color(result.framework, result.backend)
            let label = get_label(result.framework, result.backend)
            
            // Draw bar
            plot.add(
              ((i - 0.35, 0), (i - 0.35, min_time), (i + 0.35, min_time), (i + 0.35, 0)),
              style: (stroke: color, fill: color.lighten(40%)),
              label: label
            )
            i += 1
          }
        }
      )
    })
  }, caption: [GPU Benchmark - Minimum Execution Time])
  
  v(15pt)
  
  // GPU Results Table
  figure(
    table(
      columns: 5,
      stroke: 0.5pt,
      align: (left, center, center, center, center),
      table.header(
        [*Framework*], [*Backend*], [*Min Time (s)*], [*Avg Time (s)*], [*Speedup*]
      ),
      ..for result in gpu_results {
        let speedup = pytorch_min / result.min_time
        let speedup_str = if result.framework == "pytorch" {
          "baseline"
        } else {
          str(calc.round(speedup, digits: 3)) + "×"
        }
        let avg_time = if "avg_time" in result { result.avg_time } else { result.min_time }
        (
          result.framework,
          result.backend,
          str(calc.round(result.min_time, digits: 4)),
          str(calc.round(avg_time, digits: 4)),
          speedup_str
        )
      }
    ),
    caption: [GPU Benchmark Results]
  )
}

#v(20pt)

// ============================================================================
// CPU Benchmark Comparison
// ============================================================================
#if cpu_results.len() > 0 {
  [== CPU Benchmark Comparison]
  v(10pt)
  
  // Find PyTorch CPU baseline
  let pytorch_cpu = cpu_results.find(r => r.framework == "pytorch")
  let pytorch_cpu_min = if pytorch_cpu != none { pytorch_cpu.min_time } else { 1.0 }
  
  // Bar chart for CPU results
  figure({
    canvas(length: 1cm, {
      let max_time = calc.max(..cpu_results.map(r => r.min_time)) * 1.2
      
      plot.plot(
        size: (12, 6),
        x-label: none,
        y-label: "Minimum Time (seconds)",
        x-min: 0,
        x-max: cpu_results.len() + 1,
        y-min: 0,
        y-max: max_time,
        x-tick-step: none,
        legend: "inner-north-east",
        {
          let i = 1
          for result in cpu_results {
            let min_time = result.min_time
            let color = get_color(result.framework, result.backend)
            let label = get_label(result.framework, result.backend)
            
            // Draw bar
            plot.add(
              ((i - 0.35, 0), (i - 0.35, min_time), (i + 0.35, min_time), (i + 0.35, 0)),
              style: (stroke: color, fill: color.lighten(40%)),
              label: label
            )
            i += 1
          }
        }
      )
    })
  }, caption: [CPU Benchmark - Minimum Execution Time])
  
  v(15pt)
  
  // CPU Results Table
  figure(
    table(
      columns: 5,
      stroke: 0.5pt,
      align: (left, center, center, center, center),
      table.header(
        [*Framework*], [*Backend*], [*Min Time (s)*], [*Avg Time (s)*], [*Speedup*]
      ),
      ..for result in cpu_results {
        let speedup = pytorch_cpu_min / result.min_time
        let speedup_str = if result.framework == "pytorch" {
          "baseline"
        } else {
          str(calc.round(speedup, digits: 3)) + "×"
        }
        let avg_time = if "avg_time" in result { result.avg_time } else { result.min_time }
        (
          result.framework,
          result.backend,
          str(calc.round(result.min_time, digits: 4)),
          str(calc.round(avg_time, digits: 4)),
          speedup_str
        )
      }
    ),
    caption: [CPU Benchmark Results]
  )
}

#v(20pt)

// ============================================================================
// Speedup Comparison (GPU)
// ============================================================================
#if gpu_results.len() > 1 {
  [== Speedup Analysis]
  v(10pt)
  
  let pytorch_gpu = gpu_results.find(r => r.framework == "pytorch")
  let pytorch_min = if pytorch_gpu != none { pytorch_gpu.min_time } else { 1.0 }
  
  let omesum_results = gpu_results.filter(r => r.framework == "OMEinsum")
  
  if omesum_results.len() > 0 {
    figure({
      canvas(length: 1cm, {
        let speedups = omesum_results.map(r => pytorch_min / r.min_time)
        let max_speedup = calc.max(..speedups) * 1.3
        
        plot.plot(
          size: (10, 6),
          x-label: none,
          y-label: "Speedup (×)",
          x-min: 0,
          x-max: omesum_results.len() + 1,
          y-min: 0,
          y-max: calc.max(max_speedup, 1.5),
          x-tick-step: none,
          {
            // Draw baseline at 1.0
            plot.add(
              ((0, 1), (omesum_results.len() + 1, 1)),
              style: (stroke: (paint: gray, dash: "dashed", thickness: 1pt)),
              label: "PyTorch baseline"
            )
            
            let i = 1
            for result in omesum_results {
              let speedup = pytorch_min / result.min_time
              let color = if speedup >= 1.0 { green } else { red }
              let label = "OMEinsum (" + result.backend + ")"
              
              // Draw bar
              plot.add(
                ((i - 0.35, 0), (i - 0.35, speedup), (i + 0.35, speedup), (i + 0.35, 0)),
                style: (stroke: color, fill: color.lighten(40%)),
                label: label
              )
              i += 1
            }
          }
        )
      })
    }, caption: [OMEinsum Speedup vs PyTorch (GPU)])
    
    v(10pt)
    
    [
    - Values above 1.0× indicate OMEinsum is faster than PyTorch
    - Values below 1.0× indicate PyTorch is faster
    ]
  }
}

#v(20pt)

// ============================================================================
// Notes
// ============================================================================
[== Notes]

- *Tensor Network*: Random regular graph with 220 nodes and degree 3
- *Contraction Order*: Optimized using TreeSA algorithm
- *Data Type*: Float32
- All benchmarks use the same optimized contraction order
- GPU benchmarks synchronize CUDA operations for accurate timing
- Julia garbage collection is minimized during benchmarks

#v(10pt)

For more details, see the #link("https://github.com/under-Peter/OMEinsum.jl/issues/133")[original discussion].

