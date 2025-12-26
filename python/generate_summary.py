#!/usr/bin/env python3
"""
Generate summary JSON from all benchmark results.
For duplicate entries (same framework/device/backend), keeps only the latest.
"""

import json
import math
import os
from datetime import datetime
from pathlib import Path


RESULTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "results")


def get_entry_key(result):
    """Generate a unique key for an entry based on framework, device, and backend."""
    framework = result.get("framework", "")
    device = result.get("device", "")
    backend = result.get("backend", "")
    
    return (framework, device, backend)


def parse_timestamp(timestamp_str):
    """Parse timestamp string to datetime object for comparison."""
    try:
        # Try parsing with microseconds
        return datetime.strptime(timestamp_str, "%Y-%m-%dT%H:%M:%S.%f")
    except ValueError:
        try:
            # Try parsing without microseconds
            return datetime.strptime(timestamp_str, "%Y-%m-%dT%H:%M:%S")
        except ValueError:
            # If parsing fails, return a very old date
            return datetime.min


def get_device_name(result):
    """Extract detailed device name from result."""
    device_type = result.get("device", "").lower()
    
    if device_type == "cpu":
        # Try to get CPU name from cpu_info
        cpu_info = result.get("cpu_info", {})
        if cpu_info:
            cpu_name = cpu_info.get("cpu_name") or cpu_info.get("processor", "")
            if cpu_name:
                return cpu_name
        return "CPU"
    elif device_type == "gpu":
        # Try to get GPU name from gpu_info
        gpu_info = result.get("gpu_info")
        if gpu_info and isinstance(gpu_info, dict):
            gpu_name = gpu_info.get("name", "")
            if gpu_name:
                return gpu_name
        return "GPU"
    else:
        return device_type.upper() if device_type else "N/A"


def generate_summary():
    """Generate summary JSON from all results, keeping only latest for each unique entry."""
    ensure_results_dir()
    
    print("Generating summary from all results...")
    
    # Dictionary to store the latest result for each unique entry
    latest_results = {}
    
    # Load all result files
    results_dir = Path(RESULTS_DIR)
    for file_path in results_dir.glob("*.json"):
        if file_path.name == "summary.json":
            continue
        
        try:
            with open(file_path, "r") as f:
                data = json.load(f)
            
            entry_key = get_entry_key(data)
            timestamp_str = data.get("timestamp", "")
            
            # Parse timestamp
            timestamp = parse_timestamp(timestamp_str)
            
            # Keep only the latest result for this entry
            if entry_key not in latest_results:
                latest_results[entry_key] = (timestamp, data, file_path.name)
            else:
                existing_timestamp, _, _ = latest_results[entry_key]
                if timestamp > existing_timestamp:
                    latest_results[entry_key] = (timestamp, data, file_path.name)
            
            print(f"  ✓ Loaded: {file_path.name}")
        except Exception as e:
            print(f"  ⚠ Failed to load {file_path.name}: {e}")
    
    # Extract just the results (without timestamps)
    results = [result for _, result, _ in latest_results.values()]
    
    # Sort by framework, device, backend
    results.sort(key=lambda x: (
        x.get("framework", ""),
        x.get("device", ""),
        x.get("backend", "")
    ))
    
    summary = {
        "generated_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "num_results": len(results),
        "results": results
    }
    
    summary_file = os.path.join(RESULTS_DIR, "summary.json")
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)
    
    print(f"\n✓ Summary saved to: {summary_file}")
    print(f"  Total unique results: {len(results)}")
    
    # Print summary table
    print("\n" + "=" * 120)
    print("BENCHMARK SUMMARY")
    print("=" * 120)
    print(f"{'Framework':<15} {'Device':<30} {'Backend':<15} {'Result':<15} {'Min Time (s)':<15}")
    print("-" * 120)
    
    for result in results:
        framework = result.get("framework", "N/A")
        device_name = get_device_name(result)
        backend = result.get("backend", "N/A")
        result_value = result.get("result")
        min_time = result.get("min_time", float("nan"))
        
        min_time_str = f"{min_time:.4f}" if not math.isnan(min_time) else "N/A"
        result_str = f"{result_value:.6f}" if result_value is not None else "N/A"
        
        # Truncate device name if too long
        device_display = device_name[:28] + ".." if len(device_name) > 30 else device_name
        
        print(f"{framework:<15} {device_display:<30} {backend:<15} {result_str:<15} {min_time_str:<15}")
    
    print("=" * 120)
    
    return summary


def ensure_results_dir():
    """Ensure results directory exists."""
    os.makedirs(RESULTS_DIR, exist_ok=True)


if __name__ == "__main__":
    generate_summary()

