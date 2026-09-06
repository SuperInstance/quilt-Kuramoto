# DOCTRINE: llama.cpp, but Verilog and cellularized

llama.cpp won because: one repo, zero dependencies, quantized-by-default,
runs anywhere, weights are just a file (GGUF). We take the same shape to silicon logic:

1. **One repo, zero vendor deps.** Pure Verilog-2005. iverilog/verilator are the only tools. Same RTL from a 5k-LUT iCE40 to the biggest fabric.
2. **Quantized-by-default.** Every intelligence primitive is fixed-point from birth (Q-formats, saturating). No floating-point escape hatch. GGML's insight applies: the quantization IS the algorithm.
3. **State is a file.** QUF (QUilt Format, named after GGUF): a flat binary container for cell state — dials, edges (with Hebbian walk counts), tick schedule, routing tables. Same file loads into sim (testbench), soft core, or fabric. Cells are byte-addressable state machines; the file is the fleet's weights.
4. **Cellularized.** No global anything. Every operation is a cell opcode (qm_bind/link/effect/view/tick). llama.cpp parallelizes over tensors; we parallelize over cells. Composition = wiring, not scheduling.
5. **Inference everywhere.** The end state: a Hebbian corpus-brain that runs in simulation on a laptop, in an ESP32's soft fabric, and on a real FPGA — identical QUF, identical behavior, bit-exact where the fabric allows.

Definition of done (v0): 9 rtl modules + testbenches green on oss-cad-suite, QUF reader/writer reference implementation (Python for sim + Verilog loader), one end-to-end demo: load QUF → tick N times → observe a dial move and an edge strengthen, bit-identical in sim and RTL.
