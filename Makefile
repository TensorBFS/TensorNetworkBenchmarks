JL = julia --project=. --threads 1

# Benchmark parameters
DEVICE_ID ?= 0
TENSORNETWORK ?= tensornetwork_permutation_optimized.json
REPEAT ?= 1
NTHREADS ?= 1

# Directories
PYTHON_DIR = python
JULIA_DIR = julia
RUST_DIR = rust
DATA_DIR = data
RESULTS_DIR = results
FIGURES_DIR = figures

.PHONY: help init init-python init-julia init-rust update update-python update-julia run-all run-pytorch-gpu run-pytorch-cpu run-julia-gpu run-julia-cpu run-julia-cutensor run-rust-cpu clean clean-results summary report figures

help:
	@echo "TensorNetworkBenchmarks - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  init              - Initialize Julia, Python, and Rust environments"
	@echo "  init-julia        - Initialize Julia environment"
	@echo "  init-python       - Initialize Python environment (via uv)"
	@echo "  init-rust         - Build Rust benchmark (release mode)"
	@echo "  update            - Update all dependencies"
	@echo ""
	@echo "  run-all           - Run all benchmarks (PyTorch + OMEinsum + omeinsum-rs)"
	@echo "  run-pytorch-gpu   - Run PyTorch GPU benchmark"
	@echo "  run-pytorch-cpu   - Run PyTorch CPU benchmark"
	@echo "  run-julia-gpu     - Run OMEinsum GPU benchmark (CUBLAS)"
	@echo "  run-julia-cpu     - Run OMEinsum CPU benchmark"
	@echo "  run-julia-cutensor - Run OMEinsum GPU benchmark (cuTENSOR)"
	@echo "  run-rust-cpu      - Run omeinsum-rs CPU benchmark"
	@echo ""
	@echo "  summary           - Generate summary.json from all results"
	@echo "  report            - Generate PDF report with plots (using Typst)"
	@echo "  figures           - Generate SVG figures (using Typst)"
	@echo "  clean             - Remove all generated files"
	@echo ""
	@echo "Parameters:"
	@echo "  DEVICE_ID=$(DEVICE_ID)           - CUDA device ID"
	@echo "  TENSORNETWORK=$(TENSORNETWORK)"
	@echo "  REPEAT=$(REPEAT)                 - Number of repetitions"
	@echo "  NTHREADS=$(NTHREADS)             - Number of threads (for CPU benchmarks)"

init: init-julia init-python init-rust

init-julia:
	@echo "Initializing Julia environment..."
	cd $(JULIA_DIR) && $(JL) -e 'using Pkg; Pkg.instantiate()'

init-python:
	@echo "Initializing Python environment via uv..."
	cd $(PYTHON_DIR) && uv sync

init-rust:
	@echo "Building Rust benchmark (release mode)..."
	cd $(RUST_DIR) && cargo build --release

update: update-julia update-python

update-julia:
	@echo "Updating Julia packages..."
	cd $(JULIA_DIR) && $(JL) -e 'using Pkg; Pkg.update()'

update-python:
	@echo "Updating Python packages via uv..."
	cd $(PYTHON_DIR) && uv sync --upgrade

# Create results directory
$(RESULTS_DIR):
	mkdir -p $(RESULTS_DIR)

run-all: run-pytorch-gpu run-pytorch-cpu run-julia-gpu run-julia-cpu run-julia-cutensor run-rust-cpu
	@echo ""
	@echo "All benchmarks completed!"
	@echo "Run 'make summary' to generate summary.json"
	@echo "Run 'make report' to generate PDF report with plots"

run-pytorch-gpu: $(RESULTS_DIR)
	@echo "Running PyTorch GPU benchmark..."
	cd $(PYTHON_DIR) && uv run benchmark_pytorch.py gpu --deviceid=$(DEVICE_ID) --tensornetwork=../$(DATA_DIR)/$(TENSORNETWORK) --repeat_times=$(REPEAT)

run-pytorch-cpu: $(RESULTS_DIR)
	@echo "Running PyTorch CPU benchmark..."
	cd $(PYTHON_DIR) && uv run benchmark_pytorch.py cpu --tensornetwork=../$(DATA_DIR)/$(TENSORNETWORK) --repeat_times=$(REPEAT)

run-julia-gpu: $(RESULTS_DIR)
	@echo "Running OMEinsum GPU benchmark (CUBLAS backend)..."
	cd $(JULIA_DIR) && $(JL) -e 'include("runner.jl"); run_julia_gpu($(DEVICE_ID), "../$(DATA_DIR)/$(TENSORNETWORK)", $(REPEAT), "cublas")'

run-julia-cpu: $(RESULTS_DIR)
	@echo "Running OMEinsum CPU benchmark..."
	cd $(JULIA_DIR) && $(JL) -e 'include("runner.jl"); run_julia_cpu("../$(DATA_DIR)/$(TENSORNETWORK)", $(REPEAT))'

run-julia-cutensor: $(RESULTS_DIR)
	@echo "Running OMEinsum GPU benchmark (cuTENSOR backend)..."
	cd $(JULIA_DIR) && $(JL) -e 'include("runner.jl"); run_julia_gpu($(DEVICE_ID), "../$(DATA_DIR)/$(TENSORNETWORK)", $(REPEAT), "cutensor")'

run-rust-cpu: $(RESULTS_DIR)
	@echo "Running omeinsum-rs CPU benchmark..."
	cd $(RUST_DIR) && ./target/release/benchmark --tensornetwork ../$(DATA_DIR)/$(TENSORNETWORK) --repeat-times $(REPEAT) --nthreads $(NTHREADS) --output-dir ../$(RESULTS_DIR)

summary: $(RESULTS_DIR)
	@echo "Generating summary from all results..."
	cd $(PYTHON_DIR) && uv run generate_summary.py

report: summary
	@echo "Generating PDF report with Typst..."
	typst compile report.typ report.pdf
	@echo "Report generated: report.pdf"

figures: summary
	@echo "Generating SVG figures with Typst..."
	typst compile --root . $(FIGURES_DIR)/benchmark_comparison.typ $(FIGURES_DIR)/benchmark_comparison.svg
	@echo "Figure generated: $(FIGURES_DIR)/benchmark_comparison.svg"

clean:
	@echo "Cleaning generated files..."
	rm -rf $(RESULTS_DIR)
	rm -f report.pdf
	rm -f $(FIGURES_DIR)/*.svg
	@echo "Done"

clean-results:
	@echo "Cleaning result files..."
	rm -f $(RESULTS_DIR)/*.json
	@echo "Done"
