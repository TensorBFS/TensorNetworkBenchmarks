using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools
using MKL
using Comonicon
using LinearAlgebra

@cast function gpu(deviceid::Int=0, tensornetwork::String="tensornetwork_permutation_optimized.json")
    CUDA.device!(deviceid)
    optcode_loaded = readjson(tensornetwork)
    @show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    display(@benchmark println(Array($optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv($optcode_loaded)]...))) setup=(GC.gc()))
end

@cast function cpu(tensornetwork::String="tensornetwork_permutation_optimized.json", nthreads::Int=1)
    BLAS.set_num_threads(nthreads)
    optcode_loaded = readjson(tensornetwork)
    @show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    display(@benchmark println(Array($optcode_loaded([fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv($optcode_loaded)]...))) setup=(GC.gc()))
end

@main
