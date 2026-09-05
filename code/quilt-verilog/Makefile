# quilt-verilog — root Makefile (iteration 2, 2026-08-29)
# One command per lane. PATH resolution for oss-cad-suite:
#   1. stock location (below), 2. `oss-cad-suite` on PATH, else a clear error
#   naming the override variable.
OSSCAD_DEFAULT := /home/eileen/tools/oss-cad-suite/bin
ifeq ($(shell test -d /home/eileen/tools/oss-cad-suite/bin && echo y),y)
OSSCAD := $(OSSCAD_DEFAULT)
else ifneq ($(shell command -v oss-cad-suite 2>/dev/null),)
OSSCAD := $(shell dirname "$(shell command -v oss-cad-suite)")
else
OSSCAD := $(OSSCAD_DEFAULT)
endif
export PATH := $(OSSCAD):$(PATH)

NO_TOOLCHAIN := $(if $(shell test -d /home/eileen/tools/oss-cad-suite/bin && echo y),,$(if $(shell command -v oss-cad-suite 2>/dev/null),,1))
ifneq ($(NO_TOOLCHAIN),)
$(error oss-cad-suite not found: set OSSCAD=/path/to/oss-cad-suite/bin (make OSSCAD=... <target>))
endif

# Tool guard: fail with a hint, not a raw "command not found".
# Usage inside a recipe: @$(call GUARD,iverilog)
define GUARD
command -v $(1) >/dev/null 2>&1 || { \
  echo "ERROR: '$(1)' not found on PATH."; \
  echo "quilt-verilog builds with stock oss-cad-suite. Point the Makefile at yours:"; \
  echo "    make OSSCAD=/path/to/oss-cad-suite/bin <target>"; \
  echo "(currently pinned to: $(OSSCAD)). See README, 'Quickstart' -> Toolchain."; \
  exit 127; }
endef

FORMAL_SBY := formal/cell_core.fair.sby formal/cell_core.tick.sby \
              formal/flit_pipe.fly.sby formal/fabric.conservation.sby \
              formal/echo_gate.dyadic.sby tb/formal/flit_pipe.sby

.PHONY: all test sim formal formal-audit formal-audit-check synth pnr synth-report sim-scale sim-quiesce-repro clean verify-all

all: test sim formal synth pnr

## test — RTL testbench suite (iverilog). Expect 21/21 PASS (audit r13 2026-09-03; 18/18 before tern_dice/snaplog/whistle/crc32 lanes).
test:
	@$(call GUARD,iverilog)
	bash tb/run_suite.sh

## sim — behavioral Python lane over the same QUF. Expect 34/34 OK.
sim:
	python3 -m unittest discover -s sim/tools -p 'test_*.py'

## formal — all six SymbiYosys proofs (BMC + k-induction).
formal:
	@$(call GUARD,sby)
	@$(call GUARD,yosys)
	@$(call GUARD,boolector)
	@fail=0; for sby in $(FORMAL_SBY); do \
	  echo "== sby -f $$sby"; \
	  sby -f $$sby || fail=1; \
	done; exit $$fail

## formal-audit — deterministic verdict snapshot from existing workdirs (no solvers).
## Writes formal/AUDIT-SNAPSHOT.json + table. `make formal-audit-check` diffs vs committed.
formal-audit:
	python3 formal/audit_snapshot.py

formal-audit-check:
	python3 formal/audit_snapshot.py --check


## verify-all — run every tutorial (T1..T4) end to end.
verify-all:
	bash examples/verify.sh

## drift — measured piece of docs/UNSLOTH-CROSS-EXAM.md §3: tick-leak
## truncation drift, 2 x 100k ticks on a real q_cell (~4 s). PASS =
## models bit-exact vs RTL; the drift numbers are data, not pass/fail.
drift:
	@$(call GUARD,iverilog)
	iverilog -g2005 -s tb_decay_drift -o tb/run/tb_decay_drift.vvp \
	  rtl/q_tick_sched.v rtl/q_flit_pipe.v rtl/q_link_ringport.v rtl/q_dialfile.v \
	  rtl/q_hebb_edge.v rtl/q_echo_gate.v rtl/q_rqh_bank.v rtl/q_cell_core.v \
	  rtl/q_cell.v rtl/q_io_port.v rtl/q_fabric_top.v tb/tb_decay_drift.v
	vvp tb/run/tb_decay_drift.vvp

## synth — yosys iCE40 elaboration of the PnR-converged top (k4b4a8e1).
## Elaboration ONLY (~20 s); the measured PnR/bitstream numbers come next:
synth:
	@$(call GUARD,yosys)
	yosys -s synth/fpga-converged.ice40

## pnr — full place & route + bitstream of the converged top. Depends on
## synth (regenerates synth/fabric2_k4b4a8e1_ice40.json). Reproduces the
## measured HX8K-CT256 numbers: ~7,528/7,680 LC (98%), fmax ~40 MHz,
## 135,100-byte fabric2_k4b4a8e1.bin. ~3 min on a laptop.
pnr: synth
	@$(call GUARD,nextpnr-ice40)
	@$(call GUARD,icepack)
	nextpnr-ice40 --hx8k --package ct256 \
	  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
	  --timing-allow-fail --pcf-allow-unconstrained \
	  --asc synth/fabric2_k4b4a8e1.asc --report synth/report_k4b4a8e1.json
	icepack synth/fabric2_k4b4a8e1.asc synth/fabric2_k4b4a8e1.bin

## synth-report -- SILICON EXPERIMENT LANE (docs/SILICON-EXPERIMENTS.md):
## fresh yosys+nextpnr on UP5K sg48 (canonical k4b4a8e1 fit-fail + the
## serf front-end that closes, real fmax) -> synth/silicon.tsv. ~4 min.
synth-report:
	bash synth/silicon.sh

## sim-scale -- verilator scale bench on the largest legal fabric
## (NCELL=15, EDGES_N=4, K=8 B=8 AGEW=24): 1M-cycle mixed-traffic run +
## storm + reset-mid-pipeline + determinism hash. ~2 min + build.
sim-scale:
	bash sim/vlt/run_scale.sh

## sim-quiesce-repro -- F3 saturation-deadlock MINIMAL REPRO (deterministic,
## ~15 s incl. build): 120k windowed cycles; drains occ=0 in 21 cycles on
## fixed RTL (F3 escape lane, SILICON-EXPERIMENTS §3.2).
## Exit 0 = drained (expected); exit 1 = F3 REGRESSION.
sim-quiesce-repro:
	bash sim/vlt/run_quiesce_repro.sh

## clean — remove generated proof dirs and TB run artifacts (keeps sources).
clean:
	rm -rf formal/cell_core.fair formal/cell_core.tick formal/flit_pipe.fly \
	       formal/fabric.conservation formal/echo_gate.dyadic \
	       tb/formal/flit_pipe tb/run /tmp/quf_out*

## v1-consumer — QUF-FORGETTING-V1 §4-independence test: build the independent
## consumer, run the pass/reject matrix + latency bench over the checked-in corpus.
v1-consumer:
	cd hostile-consumer/v1_consumer && cargo build --release && ./run_matrix.sh
