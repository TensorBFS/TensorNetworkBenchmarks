# Benchmarking tensor network contractions

Device information:
1. NVIDIA A100-PCIE 80G with NVIDIA Driver Version 470.82.01 and CUDA Version 11.4
2. NVIDIA V100-SXM2 16G with NVIDIA Driver Version 470.63.01 and CUDA Version 11.4

Contraction order `scripts/tensornetwork.json` is generated by the following code (you do not need to run this, because we have put the contraction order in the scripts folder)
```julia
julia> using OMEinsum, OMEinsumContractionOrders, Graphs

julia> function random_regular_eincode(n, k; optimize=nothing)
            g = Graphs.random_regular_graph(n, k)
            ixs = [minmax(e.src,e.dst) for e in Graphs.edges(g)]
            return EinCode((ixs..., [(i,) for i in     Graphs.vertices(g)]...), ())
           end
random_regular_eincode (generic function with 1 method)

julia> code = random_regular_eincode(220, 3);

julia> optcode_tree = optimize_code(code, uniformsize(code, 2), TreeSA(sc_target=29, βs=0.1:0.1:20,
                                                             ntrials=5, niters=30, sc_weight=2.0));

julia> timespace_complexity(optcode_tree, uniformsize(code, 2))
(33.17598124621909, 28.0)

julia> writejson("test.json", optcode_tree)
```

## pytorch

```bash
$ cd scripts
$ python benchmark_pytorch.py
```

Timing ~0.23s (on V100, the minimum time is ~0.14s)

## OMEinsum.jl

```bash
$ cd scripts
$ JULIA_CUDA_USE_BINARYBUILDER=false julia benchmark_OMEinsum.jl
```

Timing ~1.0s (on V100, the minimum time is ~0.88s)


## Notes
The python scripts are contributed by @Fanerst, please check the [original post](https://github.com/under-Peter/OMEinsum.jl/issues/133#issuecomment-1003662057).
