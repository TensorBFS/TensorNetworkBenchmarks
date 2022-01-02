# Benchmarking tensor network contractions

Device information: NVIDIA A100-PCIE 80G with NVIDIA Driver Version 470.82.01 and CUDA Version 11.4

## pytorch

```bash
$ cd scripts
$ python benchmark_pytorch.py
```

Timing ~0.27s

## OMEinsum.jl

```bash
$ cd scripts
$ JULIA_CUDA_USE_BINARYBUILDER=false julia benchmark_OMEinsum.jl
```

Timing ~23s


## Notes
The python scripts are contributed by @Fanerst, please check the [original post](https://github.com/under-Peter/OMEinsum.jl/issues/133#issuecomment-1003662057).
