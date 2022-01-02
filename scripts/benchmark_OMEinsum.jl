using OMEinsum, OMEinsumContractionOrders
using CUDA, BenchmarkTools

optcode_loaded = readjson("test.json")
display(@benchmark CUDA.@sync optcode_loaded([CUDA.rand(fill(2, length(ix))...) for ix in getixsv(optcode_loaded)]...))