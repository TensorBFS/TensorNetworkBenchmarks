##  How to profile with nsight-system?
```bash
$ JULIA_CUDA_USE_BINARYBUILDER=false nsys launch julia nsys_OMEinsum.jl
```

Then open nsys UI on your local host.

## How to profile the register pressure
Run your code remotely on your GPU host.

```bash
$ sudo JULIA_CUDA_USE_BINARYBUILDER=false /home/ubuntu/.local/bin/ncu -o profile /home/ubuntu/.local/bin/julia permutedims-ncu.jl
```

Download the profile output and type locally

```bash
$ ncu-ui profile.ncu-rep
```

Analyse the profile results, the "Registers Per Thread" matters a lot, should be [`<64`](https://stackoverflow.com/questions/17553417/cuda-registers-per-thread) for good performance.

## Profile pytorch program

```bash
$ nsys profile -w true -t cuda,nvtx,osrt,cudnn,cublas -s cpu  --capture-range=cudaProfilerApi --stop-on-range-end=true --cudabacktrace=true -x true -o my_profile python benchmark_pytorch.py profilegpu
```
