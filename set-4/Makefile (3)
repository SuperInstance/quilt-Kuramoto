# quilt-cuda — Makefile
#
# STATUS: this environment has NO nvcc (WSL without the CUDA toolkit)
# and the dxgk bridge is unstable — no GPU runs. `make` reports the
# honest state. When the toolkit lands: `make ptx` is the compile
# check (PTX generation needs no GPU), `make demo` needs one.

NVCC ?= $(shell command -v nvcc 2>/dev/null)
ARCH ?= -arch=sm_86   # RTX 4050 is sm_89; sm_86 PTX is forward-compatible via JIT

ifeq ($(NVCC),)

all:
	@echo "quilt-cuda: nvcc NOT FOUND in this environment — build is PENDING."
	@echo "  src/ and host_demo.cu are written but UNCOMPILED (by design, honestly)."
	@echo "  Install the CUDA toolkit, then:  make ptx   (compile check, no GPU)"

ptx:
	@echo "quilt-cuda: cannot generate PTX without nvcc — PENDING (see README status table)."

demo:
	@echo "quilt-cuda: cannot build the demo without nvcc — PENDING (see README status table)."

else

BUILD = build

all: $(BUILD)/host_demo

# Compile check: PTX for both TUs. No GPU required, no execution.
ptx: $(BUILD)/quilt_cells.ptx $(BUILD)/quilt_graph.ptx

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.ptx: src/%.cu | $(BUILD)
	$(NVCC) -c --ptx $(ARCH) -Isrc $< -o $@

$(BUILD)/quilt_cells.o: src/quilt_cells.cu | $(BUILD)
	$(NVCC) -c $(ARCH) -Isrc $< -o $@

$(BUILD)/quilt_graph.o: src/quilt_graph.cu | $(BUILD)
	$(NVCC) -c $(ARCH) -Isrc $< -o $@

$(BUILD)/host_demo.o: host_demo.cu | $(BUILD)
	$(NVCC) -c $(ARCH) -Isrc $< -o $@

# Needs a working GPU to run (dxgk stability permitting).
$(BUILD)/host_demo: $(BUILD)/host_demo.o $(BUILD)/quilt_cells.o $(BUILD)/quilt_graph.o
	$(NVCC) $(ARCH) $^ -o $@

demo: $(BUILD)/host_demo
	./$(BUILD)/host_demo

clean:
	rm -rf $(BUILD)

endif

.PHONY: all ptx demo clean
