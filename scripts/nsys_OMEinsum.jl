using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools

optcode_loaded = readjson("tensornetwork.json")
@show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
GC.gc()
@show Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
#CUDA.@profile Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
GC.gc()
CUDA.@profile Array(OMEinsum.fast_contract(optcode_loaded.eins,([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...,)))
