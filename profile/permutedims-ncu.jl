using CUDA, BenchmarkTools, Random, OMEinsum

let D = 28
    a = CUDA.randn(fill(2, D)...)
    b = CUDA.randn(fill(2, D)...)
    pm = (randperm(D)...,)
    CUDA.@sync permutedims!(b, a, pm)
    CUDA.@sync permutedims!(b, a, pm)
end
