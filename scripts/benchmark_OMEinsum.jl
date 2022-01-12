using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools
using MKL
using Comonicon
using LinearAlgebra

@cast function gpu(deviceid::Int=0, tensornetwork::String="tensornetwork_permutation_optimized.json")
    CUDA.device!(deviceid)
    optcode_loaded = readjson(tensornetwork)
    @show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    xs = [CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    display(@benchmark println(Array($optcode_loaded($xs...; active_free=true))))# setup=(GC.gc(); CUDA.synchronize()))
    @time for i=1:10
        println(Array(optcode_loaded(xs...; active_free=true)))
    end
end

@cast function cpu(tensornetwork::String="tensornetwork_permutation_optimized.json", nthreads::Int=1)
    BLAS.set_num_threads(nthreads)
    optcode_loaded = readjson(tensornetwork)
    @show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    xs = [fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    display(@benchmark println(Array($optcode_loaded($xs...))) setup=(GC.gc()))
end

@main
