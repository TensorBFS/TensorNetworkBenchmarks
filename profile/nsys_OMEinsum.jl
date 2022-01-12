using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools

optcode_loaded = readjson(joinpath(dirname(@__DIR__), "scripts", "tensornetwork_permutation_optimized.json"))
@show timespacereadwrite_complexity(optcode_loaded, uniformsize(optcode_loaded, 2))
xs = [CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
@show Array(optcode_loaded(xs...; active_free=true))
CUDA.@profile Array(optcode_loaded(xs...; active_free=true))
CUDA.@profile Array(optcode_loaded(xs...; active_free=true))
