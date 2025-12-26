using OMEinsum
using CUDA
using BenchmarkTools
using MKL
using Comonicon
using LinearAlgebra
#CUDA.attribute!(memory_pool(device()), CUDA.MEMPOOL_ATTR_RELEASE_THRESHOLD, UInt64(2*2^30))

@cast function gpu(deviceid::Int=0, tensornetwork::String="../data/tensornetwork_permutation_optimized.json"; cudaversion::String="", backend::String="default")
    !isempty(cudaversion) && CUDA.set_runtime_version!(cudaversion)
    CUDA.attribute!(memory_pool(device()), CUDA.MEMPOOL_ATTR_RELEASE_THRESHOLD, typemax(UInt64))
    CUDA.device!(deviceid)
    
    # Set backend
    if backend == "cutensor"
        try
            @eval using cuTENSOR
            set_einsum_backend!(CuTensorBackend())
            println("Using cuTENSOR backend")
        catch e
            @warn "Failed to load cuTENSOR, using default backend" exception=e
            set_einsum_backend!(DefaultBackend())
        end
    else
        set_einsum_backend!(DefaultBackend())
        println("Using default CUBLAS backend")
    end
    
    optcode_loaded = readjson(tensornetwork)
    @show contraction_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    xs = [CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    display(@benchmark println(Array($optcode_loaded($xs...; active_free=false))))# setup=(GC.gc(); CUDA.synchronize()))
    @time for i=1:10
        println(Array(optcode_loaded(xs...; active_free=false)))
    end
end

@cast function cpu(tensornetwork::String="../data/tensornetwork_permutation_optimized.json", nthreads::Int=1)
    BLAS.set_num_threads(nthreads)
    optcode_loaded = readjson(tensornetwork)
    @show contraction_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    xs = [fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    display(@benchmark println(@time Array($optcode_loaded($xs...))) setup=(GC.gc()))
end

@main
