using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools

optcode_loaded = readjson("tensornetwork_permutation_optimized.json")
@show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
display(@benchmark (@show Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))) setup=(GC.gc()))
