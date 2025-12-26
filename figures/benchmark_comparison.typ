#import "@preview/cetz:0.4.0": canvas, draw
#import "@preview/cetz-plot:0.1.2": plot
#set page(width: auto, height: auto, margin: 10pt)

// Read the benchmark results
#let summary = json("../results/summary.json")
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

// GPU comparison bar chart
#let gpu_results = results.filter(r => r.device == "gpu")
#let cpu_results = results.filter(r => r.device == "cpu")

#figure({
  canvas(length: 1cm, {
    plot.plot(
      size: (12, 8),
      x-label: none,
      y-label: "Time (seconds)",
      x-min: 0,
      x-max: gpu_results.len() + 1,
      y-min: 0,
      y-tick-step: auto,
      legend: "inner-north-east",
      {
        let i = 1
        for result in gpu_results {
          let min_time = result.min_time
          let framework = result.framework
          let backend = result.backend
          let color = get_color(framework, backend)
          let label = get_label(framework, backend)
          
          // Draw bar
          plot.add(
            ((i - 0.3, 0), (i - 0.3, min_time), (i + 0.3, min_time), (i + 0.3, 0)),
            style: (stroke: color, fill: color.lighten(30%)),
            label: label
          )
          i += 1
        }
      }
    )
  })
}, caption: [GPU Benchmark Comparison - Minimum Time])

#v(20pt)

// Create comparison table
#figure(
  table(
    columns: 5,
    stroke: 0.5pt,
    align: (left, center, center, center, center),
    [*Framework*], [*Device*], [*Backend*], [*Min Time (s)*], [*Speedup*],
    ..{
      // Find PyTorch GPU baseline
      let pytorch_gpu = gpu_results.find(r => r.framework == "pytorch")
      let pytorch_min = if pytorch_gpu != none { pytorch_gpu.min_time } else { 1.0 }
      
      // GPU results
      for result in gpu_results {
        let speedup = pytorch_min / result.min_time
        let speedup_str = if result.framework == "pytorch" {
          "baseline"
        } else {
          str(calc.round(speedup, digits: 3)) + "×"
        }
        (
          result.framework,
          result.device,
          result.backend,
          str(calc.round(result.min_time, digits: 4)),
          speedup_str
        )
      }
      
      // Find PyTorch CPU baseline
      let pytorch_cpu = cpu_results.find(r => r.framework == "pytorch")
      let pytorch_cpu_min = if pytorch_cpu != none { pytorch_cpu.min_time } else { 1.0 }
      
      // CPU results
      for result in cpu_results {
        let speedup = pytorch_cpu_min / result.min_time
        let speedup_str = if result.framework == "pytorch" {
          "baseline"
        } else {
          str(calc.round(speedup, digits: 3)) + "×"
        }
        (
          result.framework,
          result.device,
          result.backend,
          str(calc.round(result.min_time, digits: 4)),
          speedup_str
        )
      }
    }
  ),
  caption: [Benchmark Results Summary]
)

