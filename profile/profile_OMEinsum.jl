using OMEinsum, OMEinsumContractionOrders
using CUDA, Profile

optcode_loaded = readjson("tensornetwork.json")
@show timespacereadwrite_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
GC.gc()
@show Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.@profile Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.clear()
GC.gc()
Profile.@profile Array(optcode_loaded([CUDA.fill(0.5^(0.4), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]...))
Profile.print(mincount=10, recur=:flat)
