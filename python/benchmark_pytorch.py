import json
import math
import os
import platform
import time
from datetime import datetime

import fire
import torch


def myeinsum(ixs, iy, tensors):
    uniquelabels = list(set(sum(ixs, start=[]) + iy))
    allow_ascii = list(range(65, 90)) + list(range(97, 122))
    labelmap = {l: chr(allow_ascii[i]) for i, l in enumerate(uniquelabels)}
    eins = ",".join(["".join([labelmap[l] for l in ix]) for ix in ixs]) + "->" + "".join([labelmap[l] for l in iy])
    return torch.einsum(eins, *tensors)


def contract_recur(tree: dict, inputs):
    if "args" in tree:
        tensors = [contract_recur(arg, inputs) for arg in tree["args"]]
        return myeinsum(tree["eins"]["ixs"], tree["eins"]["iy"], tensors)
    else:
        return inputs[tree["tensorindex"] - 1]


def contract(tree: dict, inputs):
    return contract_recur(tree["tree"], inputs)


RESULTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "results")


def ensure_results_dir():
    os.makedirs(RESULTS_DIR, exist_ok=True)


def get_cpu_info():
    """Get CPU information"""
    return {
        "processor": platform.processor(),
        "machine": platform.machine(),
        "platform": platform.platform(),
        "cpu_count": os.cpu_count(),
    }


def get_gpu_info(deviceid: int = 0):
    """Get GPU information"""
    if not torch.cuda.is_available():
        return None
    
    device = torch.device(f"cuda:{deviceid}")
    props = torch.cuda.get_device_properties(deviceid)
    
    return {
        "name": props.name,
        "compute_capability": f"{props.major}.{props.minor}",
        "total_memory_gb": props.total_memory / (1024**3),
        "multiprocessor_count": props.multi_processor_count,
        "cuda_version": torch.version.cuda,
        "cudnn_version": torch.backends.cudnn.version() if torch.backends.cudnn.is_available() else None,
    }


def save_result(result, filename):
    ensure_results_dir()
    filepath = os.path.join(RESULTS_DIR, filename)
    with open(filepath, "w") as f:
        json.dump(result, f, indent=2)
    print(f"✓ Results saved to: {filepath}")


class CLI(object):
    def gpu(self, repeat_times=10, tensornetwork="../data/tensornetwork_permutation_optimized.json", deviceid: int = 0):
        """Run GPU benchmark and save results to JSON"""
        device = f"cuda:{deviceid}"
        print(f"Running PyTorch GPU benchmark on {device}...")

        with open(tensornetwork, "r") as f:
            optcode = json.load(f)

        tensors = [(0.5**0.4) * torch.ones((2,) * len(ix), dtype=torch.float32, device=device) for ix in optcode["inputs"]]

        # Warm up
        for _ in range(3):
            res = contract(optcode, tensors)
            torch.cuda.synchronize(device)

        # Benchmark
        torch.cuda.synchronize(device)
        times = []
        ta = time.time()
        for _ in range(repeat_times):
            t0 = time.time()
            res = contract(optcode, tensors)
            torch.cuda.synchronize(device)
            t1 = time.time()
            times.append(t1 - t0)
        total = time.time() - ta

        min_time = min(times)
        avg_time = sum(times) / len(times)

        result_value = res.item()
        print(f"  Result: {result_value}")
        print(f"  Min time: {min_time:.4f}s")
        print(f"  Avg time: {avg_time:.4f}s")
        print(f"  Total time: {total:.4f}s")

        # Save results
        result = {
            "framework": "pytorch",
            "device": "gpu",
            "backend": "cuda",
            "deviceid": deviceid,
            "tensornetwork": tensornetwork,
            "repeat_times": repeat_times,
            "min_time": min_time,
            "avg_time": avg_time,
            "total_time": total,
            "all_times": times,
            "result": result_value,
            "timestamp": datetime.now().isoformat(),
            "cpu_info": get_cpu_info(),
            "gpu_info": get_gpu_info(deviceid),
        }
        save_result(result, f"pytorch_gpu_{deviceid}.json")
        return result

    def cpu(self, repeat_times=10, tensornetwork="../data/tensornetwork_permutation_optimized.json", nthreads=1):
        """Run CPU benchmark and save results to JSON"""
        device = "cpu"
        torch.set_num_threads(nthreads)
        print(f"Running PyTorch CPU benchmark with {nthreads} thread(s)...")

        with open(tensornetwork, "r") as f:
            optcode = json.load(f)

        tensors = [(0.5**0.4) * torch.ones((2,) * len(ix), dtype=torch.float32, device=device) for ix in optcode["inputs"]]

        # Warm up
        for _ in range(10):
            res = contract(optcode, tensors)

        # Benchmark
        times = []
        ta = time.time()
        for _ in range(repeat_times):
            t0 = time.time()
            res = contract(optcode, tensors)
            t1 = time.time()
            times.append(t1 - t0)
        total = time.time() - ta

        min_time = min(times)
        avg_time = sum(times) / len(times)

        result_value = res.item()
        print(f"  Result: {result_value}")
        print(f"  Min time: {min_time:.4f}s")
        print(f"  Avg time: {avg_time:.4f}s")
        print(f"  Total time: {total:.4f}s")

        # Save results
        result = {
            "framework": "pytorch",
            "device": "cpu",
            "backend": "cpu",
            "nthreads": nthreads,
            "tensornetwork": tensornetwork,
            "repeat_times": repeat_times,
            "min_time": min_time,
            "avg_time": avg_time,
            "total_time": total,
            "all_times": times,
            "result": result_value,
            "timestamp": datetime.now().isoformat(),
            "cpu_info": get_cpu_info(),
            "gpu_info": None,
        }
        save_result(result, "pytorch_cpu.json")
        return result

    def profilegpu(self, repeat_times=10, tensornetwork="../data/tensornetwork_permutation_optimized.json", deviceid: int = 0):
        """Profile GPU execution with CUDA profiler"""
        device = f"cuda:{deviceid}"
        with open(tensornetwork, "r") as f:
            optcode = json.load(f)
        for i in range(repeat_times + 1):
            if i == repeat_times:
                torch.cuda.cudart().cudaProfilerStart()
            tensors = [(0.5**0.4) * torch.ones((2,) * len(ix), dtype=torch.float32, device=device) for ix in optcode["inputs"]]
            res = contract(optcode, tensors)
            torch.cuda.synchronize(device)
            if i == repeat_times:
                torch.cuda.cudart().cudaProfilerStop()


if __name__ == "__main__":
    fire.Fire(CLI())
