using CUDA, BenchmarkTools, Random

let D = 28
    a = CUDA.randn(fill(2, D)...)
    b = CUDA.randn(fill(2, D)...)
    pm = (randperm(D)...,)
    display(@device_code_ptx permutedims!(b, a, pm))
    display(@benchmark (CUDA.@sync permutedims!($b, $a, $pm)))
end
