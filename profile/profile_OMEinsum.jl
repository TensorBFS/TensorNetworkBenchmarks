using OMEinsum, OMEinsumContractionOrders
using CUDA, Profile

optcode_loaded = readjson(joinpath(dirname(@__DIR__), "scripts", "tensornetwork_permutation_optimized.json"))
@show timespacereadwrite_complexity(optcode_loaded, uniformsize(optcode_loaded, 2))
GC.gc()
@show Array(optcode_loaded([CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.@profile Array(optcode_loaded([CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.clear()
GC.gc()
Profile.@profile Array(optcode_loaded([CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.print(mincount=4)#, recur=:flat)
