#!/usr/bin/env julia
"""
Runner script for OMEinsum benchmarks - saves results to JSON
"""

using OMEinsum
using CUDA
using BenchmarkTools
using MKL
using JSON
using Dates
using LinearAlgebra

const RESULTS_DIR = joinpath(dirname(@__DIR__), "results")

function ensure_results_dir()
    mkpath(RESULTS_DIR)
end

"""
Get CPU information
"""
function get_cpu_info()
    return Dict(
        "cpu_name" => Sys.CPU_NAME,
        "cpu_threads" => Sys.CPU_THREADS,
        "machine" => Sys.MACHINE,
        "kernel" => Sys.KERNEL,
        "word_size" => Sys.WORD_SIZE,
    )
end

"""
Get GPU information for a specific device
"""
function get_gpu_info(deviceid::Int=0)
    if !CUDA.functional()
        return nothing
    end
    
    try
        CUDA.device!(deviceid)
        dev = CUDA.device()
        return Dict(
            "name" => CUDA.name(dev),
            "capability" => string(CUDA.capability(dev)),
            "total_memory_gb" => CUDA.total_memory(dev) / (1024^3),
            "device_id" => deviceid,
            "cuda_version" => string(CUDA.version()),
        )
    catch e
        @warn "Failed to get GPU info" exception=e
        return nothing
    end
end

"""
Run OMEinsum GPU benchmark and save results to JSON
"""
function run_julia_gpu(deviceid::Int=0, tensornetwork::String="../data/tensornetwork_permutation_optimized.json", 
                       repeat_times::Int=10, backend::String="cublas")
    ensure_results_dir()
    
    CUDA.device!(deviceid)
    CUDA.attribute!(memory_pool(device()), CUDA.MEMPOOL_ATTR_RELEASE_THRESHOLD, typemax(UInt64))
    
    # Set backend
    if backend == "cutensor"
        try
            @eval using cuTENSOR
            set_einsum_backend!(CuTensorBackend())
            println("Using cuTENSOR backend")
        catch e
            @warn "Failed to load cuTENSOR, using default backend" exception=e
            backend = "cublas"
            set_einsum_backend!(DefaultBackend())
        end
    else
        set_einsum_backend!(DefaultBackend())
        println("Using CUBLAS backend")
    end
    
    println("Running OMEinsum GPU benchmark on device $deviceid...")
    
    optcode_loaded = readjson(tensornetwork)
    cc = contraction_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    println("  Contraction complexity: $cc")
    
    xs = [CUDA.fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    
    # Warm up
    for _ in 1:3
        optcode_loaded(xs...)
        CUDA.synchronize()
    end
    GC.gc()
    
    # Benchmark
    times = Float64[]
    CUDA.synchronize()
    ta = time()
    for _ in 1:repeat_times
        GC.gc(false)  # Minor GC only
        t0 = time()
        res = optcode_loaded(xs...)
        CUDA.synchronize()
        t1 = time()
        push!(times, t1 - t0)
    end
    total = time() - ta
    
    min_time = minimum(times)
    avg_time = sum(times) / length(times)
    
    # Get result value
    result_val = Array(optcode_loaded(xs...))[]
    
    println("  Result: $result_val")
    println("  Min time: $(round(min_time, digits=4))s")
    println("  Avg time: $(round(avg_time, digits=4))s")
    println("  Total time: $(round(total, digits=4))s")
    
    # Save results
    result = Dict(
        "framework" => "OMEinsum",
        "device" => "gpu",
        "backend" => backend,
        "deviceid" => deviceid,
        "tensornetwork" => tensornetwork,
        "repeat_times" => repeat_times,
        "min_time" => min_time,
        "avg_time" => avg_time,
        "total_time" => total,
        "all_times" => times,
        "contraction_complexity" => Dict("tc" => cc.tc, "sc" => cc.sc, "rwc" => cc.rwc),
        "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
        "cpu_info" => get_cpu_info(),
        "gpu_info" => get_gpu_info(deviceid),
    )
    
    filename = joinpath(RESULTS_DIR, "julia_gpu_$(backend)_$(deviceid).json")
    open(filename, "w") do f
        JSON.print(f, result, 2)
    end
    println("✓ Results saved to: $filename")
    
    return result
end

"""
Run OMEinsum CPU benchmark and save results to JSON
"""
function run_julia_cpu(tensornetwork::String="../data/tensornetwork_permutation_optimized.json", 
                       repeat_times::Int=10, nthreads::Int=1)
    ensure_results_dir()
    
    BLAS.set_num_threads(nthreads)
    println("Running OMEinsum CPU benchmark with $nthreads thread(s)...")
    
    optcode_loaded = readjson(tensornetwork)
    cc = contraction_complexity(optcode_loaded.eins, uniformsize(optcode_loaded, 2))
    println("  Contraction complexity: $cc")
    
    xs = [fill(Float32(0.5^(0.4)), (fill(2, length(ix))...,)) for ix in getixsv(optcode_loaded)]
    
    # Warm up
    for _ in 1:3
        optcode_loaded(xs...)
    end
    GC.gc()
    
    # Benchmark
    times = Float64[]
    ta = time()
    for _ in 1:repeat_times
        GC.gc(false)
        t0 = time()
        res = optcode_loaded(xs...)
        t1 = time()
        push!(times, t1 - t0)
    end
    total = time() - ta
    
    min_time = minimum(times)
    avg_time = sum(times) / length(times)
    
    # Get result value
    result_val = optcode_loaded(xs...)[]
    
    println("  Result: $result_val")
    println("  Min time: $(round(min_time, digits=4))s")
    println("  Avg time: $(round(avg_time, digits=4))s")
    println("  Total time: $(round(total, digits=4))s")
    
    # Save results
    result = Dict(
        "framework" => "OMEinsum",
        "device" => "cpu",
        "backend" => "MKL",
        "nthreads" => nthreads,
        "tensornetwork" => tensornetwork,
        "repeat_times" => repeat_times,
        "min_time" => min_time,
        "avg_time" => avg_time,
        "total_time" => total,
        "all_times" => times,
        "contraction_complexity" => Dict("tc" => cc.tc, "sc" => cc.sc, "rwc" => cc.rwc),
        "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
        "cpu_info" => get_cpu_info(),
        "gpu_info" => nothing,
    )
    
    filename = joinpath(RESULTS_DIR, "julia_cpu.json")
    open(filename, "w") do f
        JSON.print(f, result, 2)
    end
    println("✓ Results saved to: $filename")
    
    return result
end

"""
Generate summary JSON from all results
"""
function generate_summary()
    ensure_results_dir()
    
    println("Generating summary from all results...")
    
    results = []
    for file in readdir(RESULTS_DIR)
        if endswith(file, ".json") && file != "summary.json"
            filepath = joinpath(RESULTS_DIR, file)
            try
                data = JSON.parsefile(filepath)
                push!(results, data)
                println("  ✓ Loaded: $file")
            catch e
                @warn "Failed to load $file" exception=e
            end
        end
    end
    
    # Sort by framework and device
    sort!(results, by = x -> (get(x, "framework", ""), get(x, "device", ""), get(x, "backend", "")))
    
    summary = Dict(
        "generated_at" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
        "num_results" => length(results),
        "results" => results
    )
    
    summary_file = joinpath(RESULTS_DIR, "summary.json")
    open(summary_file, "w") do f
        JSON.print(f, summary, 2)
    end
    
    println("\n✓ Summary saved to: $summary_file")
    println("  Total results: $(length(results))")
    
    # Print summary table
    println("\n" * "="^80)
    println("BENCHMARK SUMMARY")
    println("="^80)
    println(rpad("Framework", 15) * rpad("Device", 10) * rpad("Backend", 15) * "Min Time (s)")
    println("-"^80)
    
    for result in results
        framework = get(result, "framework", "N/A")
        device = get(result, "device", "N/A")
        backend = get(result, "backend", "N/A")
        min_time = get(result, "min_time", NaN)
        
        println(rpad(framework, 15) * rpad(device, 10) * rpad(backend, 15) * string(round(min_time, digits=4)))
    end
    println("="^80)
    
    return summary
end
