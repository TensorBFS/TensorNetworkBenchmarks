# Benchmarking Tensor Network Contractions

Comparing **PyTorch** and **OMEinsum.jl** for tensor network contractions.

## Latest Results (NVIDIA A800 80GB PCIe)

| Device | Framework | Backend | Min Time (s) | Speedup vs PyTorch |
|--------|-----------|---------|--------------|-------------------|
| GPU | PyTorch | CUDA | 0.107 | baseline |
| GPU | OMEinsum | cuTENSOR | 0.057 | **1.87× faster** |
| GPU | OMEinsum | CUBLAS | 0.238 | 2.23× slower |
| CPU | PyTorch | — | 17.2 | — |
| CPU | OMEinsum | MKL | 14.7 | — |

**Configuration:** Float32, Tensor network with 220 nodes (degree 3), contraction complexity 2^33.2

## Setup

Requirements:
- [uv](https://github.com/astral-sh/uv) for Python dependency management
- [Julia](https://julialang.org/downloads/)
- [Typst](https://typst.app/) (optional, for PDF reports)

```bash
make init        # Initialize both environments
make update      # Update dependencies
```

## Usage

```bash
# Run all benchmarks
make run-all

# Run individual benchmarks
make run-pytorch-gpu
make run-pytorch-cpu
make run-julia-gpu          # CUBLAS backend
make run-julia-cutensor     # cuTENSOR backend
make run-julia-cpu

# Generate reports
make summary     # Generate summary.json
make report      # Generate PDF report with plots
```

Customizable parameters:
```bash
make run-julia-gpu DEVICE_ID=1 REPEAT=20
```

Results are saved to `results/` directory. Run `make help` for all options.

## Acknowledgments

Python scripts contributed by @Fanerst. See the [original discussion](https://github.com/under-Peter/OMEinsum.jl/issues/133).
