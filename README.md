# Benchmarking tensor network contractions

Device information:
1. NVIDIA A100-PCIE 80G with NVIDIA Driver Version 470.82.01 and CUDA Version 11.4
2. NVIDIA V100-SXM2 16G with NVIDIA Driver Version 470.63.01 and CUDA Version 11.4
3. Intel(R) Xeon(R) CPU E5-2686 v4 @ 2.30GHz

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

julia> writejson("tensornetwork_permutation_optimized.json", optcode_tree)
```

## Setup

* Install [pytorch](https://pytorch.org/get-started/locally/).
* Install [Julia](https://julialang.org/downloads/) and related packages by typing

```bash
$ cd scripts
$ julia --project -e 'using Pkg; Pkg.instantiate()'
```

(NOTE: if you want to update your local environment, just run `julia --project -e 'using Pkg; Pkg.update()`)

## pytorch

```bash
$ cd scripts
$ python benchmark_pytorch.py gpu
$ python benchmark_pytorch.py cpu
```

#### Timing

* on A100, the minimum time is ~0.12s (needs update)
* on V100, the minimum time is ~0.12s, 10 execusions take ~1.76s
* on CPU (MKL backend, single thread), it is 38.87s (maybe MKL is not set properly?)

## OMEinsum.jl

```bash
$ cd scripts
$ JULIA_NUM_THREADS=1 JULIA_CUDA_USE_BINARYBUILDER=false julia --project benchmark_OMEinsum.jl gpu
$ JULIA_NUM_THREADS=1 JULIA_CUDA_USE_BINARYBUILDER=false julia --project benchmark_OMEinsum.jl cpu
```

#### Timing
* on A100, the minimum time is ~0.22s (needs update)
* on V100, the minimum time is ~0.13s, 10 execusions take ~1.39s
* on CPU (MKL backend, single thread), it is 23.05s

Note: The Julia garbadge collection time is avoided.


## Notes
The python scripts are contributed by @Fanerst, there are other people in the discussion and provide helpful advices, please check the [original post](https://github.com/under-Peter/OMEinsum.jl/issues/133#issuecomment-1003662057).
