# VERIFICATION — what is proven, how to run it, and what is not

Every number on this page was measured by running the command shown, on this
tree, by the iteration named in the table. If you cannot reproduce a number,
that is a bug in this document.

## How to run everything

Toolchain: stock oss-cad-suite (Icarus 13.0, Yosys 0.47+22, SymbiYosys,
boolector, nextpnr-ice40 0.7-131, icepack, icetime) at
`/home/eileen/tools/oss-cad-suite/bin`. The root Makefile pins that path
itself; you do not need to export anything.

```sh
make test      # RTL testbench suite (iverilog)          — ~1-2 min
make sim       # behavioral Python lane (unittest)       — seconds
make formal    # all six SymbiYosys proofs               — see timings below
make synth     # yosys iCE40 elaboration of the converged top    — ~20 s
make pnr       # nextpnr-ice40 → icepack of the converged top   — ~3 min
make all       # all five, in that order
```

All five targets were run and verified green on 2026-08-29 (iteration 2;
`make pnr` added in the same audit wave — before it, the measured PnR
numbers were not reachable from any make target).
`make clean` removes generated proof dirs and `tb/run` artifacts (sources
untouched).

## Lane 1 — `make test`: the RTL testbench suite

Run: `bash tb/run_suite.sh` (the Makefile target). 18 testbenches compiled
with `iverilog -g2005` and executed; a PASS banner in the output is required
for each. What the suite proves, per bench:

- **tb_tick_sched / tb_flit_pipe / tb_link_ringport** — scheduler spacing,
  FIFO no-loss/no-reorder, ring-port handoff.
- **tb_dialfile / tb_hebb_edge / tb_hyperbola_tail** — dial storage, the
  Hebbian edge update, and the power-law decay tail, against golden values.
- **tb_q_echo_gate / tb_q_rqh_bank / tb_rqh_saturation** — echo-gate
  bracketing, RQH deposits, and saturation behavior (with `rtl/q_hebb_rqh.v`).
- **tb_cell_core / tb_io_port** — per-cell op FSM and the generic IO port.
- **tb_fabric_smoke / tb_fabric_smoke_v2** — whole-fabric train→fire→decay
  and echo-gate+RQH paths, max latency 31 cycles.
- **tb_judge_consistency** — UF-loader judge consistency (with
  `rtl/q_uf_loader.v`).
- **tb_hebb_pipe** — 300 pipelined ops, act/trace bit-exact at every checkpoint.
- **tb_quf_boot** — 4 boot cases: warm start, corrupt header, truncation,
  epoch latch.
- **tb_quf_loader lane** — Python golden builds a 576-byte QUF, iverilog
  loads it, round-trip byte-exact.
- **tb_serfabric** — serialized fabric front-end: serial vs parallel boot and
  egress streams byte/cycle-exact (68 flits), fail-static gate mode.

Beside the suite, the backend battery (`bash tools/backend/run_all.sh`, 5
benches) holds the adversarial lanes: QUF format fuzz, boot-boundary fuzz
(RTL), cell-level differential cosim (Python vs `q_cell`), **fabric-level
differential cosim (Python vs `q_fabric_top`, NCELL=2 — THE-BREAKDOWN §10:
18/18 programs bit-exact, 689 egress flits; fresh-seed second generation
30/30, 1509 flits; measured-serialization replay, scope named in §10)**,
and the 57-check bug regression bench. Numbers and method:
`docs/BACKEND-NOTES.md`.

*Fresh-clone note (2026-09-03):* one regression check —
`rebuild_scale_tsv` cwd independence — parses `synth/yosys_*_n*.log`,
which are gitignored artifacts of `bash synth/scale.sh`. On a fresh clone
that check SKIPs with a notice; run the scale sweep once and it counts
among the 57 again. (Found by re-running `make test` on a pristine
checkout: the same run also exposed that `tb_quf_boot` ran before the
golden container hex was generated — suite ordering fixed in
`tb/run_suite.sh`.)

**Result (2026-08-29, iteration 2): 18/18 PASS** (same tree as iteration 1's
recorded 18/18).

## Lane 2 — `make sim`: the behavioral Python lane

Run: `python3 -m unittest discover -s sim/tools -p 'test_*.py'`.

**Result (2026-08-29, iteration 2): 34 tests, all OK**, runtime under a
second. This lane proves the Python tap-fabric bridge carries the same
semantics as the RTL lane over the same QUF container — it is a model check,
not a hardware proof.

## Lane 3 — `make formal`: SymbiYosys proofs

Six proofs (five in `formal/`, one k-induction harness in `tb/formal/`).
Exact invariants, environment assumptions, and the two RTL defects the
proofs forced are documented in `formal/README.md` — read it before trusting
any number here. Summary:

| proof | invariant (short) | mode/depth | verdict |
|---|---|---|---|
| `flit_pipe.fly.sby` | FIFO safety + value integrity (no loss/dup/reorder) | BMC 40 | PASS |
| `fabric.conservation.sby` | 2-cell ledger conservation, no silent drops | BMC 55 PASS; **UNBOUNDED PASS 2026-08-30 via `mode prove` + `abc pdr` (25.9 s, frame 9, `fabric.conservation.pdr.sby`) — cite engine+mode, a bare smtbmc prove does NOT close this property** | PASS |
| `echo_gate.dyadic.sby` | dyadic octave bracket, PRIORITY, MONO, ZEROABSORB | BMC 25 | PASS |
| `cell_core.tick.sby` | tick suppression + service deadlines under flood | BMC 80 → **105** (raised 2026-08-30, 4dd8195) | PASS |
| `cell_core.fair.sby` | op-response bounds I1a/I1b/I2 | BMC 80 → **130** (raised 2026-08-30, 4dd8195) | PASS |
| `tb/formal/flit_pipe.sby` | k-inductive re-prove of pipe invariants | prove, depth 15 | PASS |

Measured on this machine, iteration 2 (2026-08-29, `make formal` re-run):

| proof | verdict | measured wall time (iter 2) |
|---|---|---|
| `cell_core.fair.sby` (BMC 80; depth since raised to 130) | PASS | 498 s |
| `cell_core.tick.sby` (BMC 80; depth since raised to 105) | PASS | 215 s |
| `flit_pipe.fly.sby` (BMC 40) | PASS | 72 s |
| `fabric.conservation.sby` (BMC 55) | PASS | 38 s — plus UNBOUNDED `mode prove` + `abc pdr` PASS 28 s wall (2026-08-30) |
| `echo_gate.dyadic.sby` (BMC 25) | PASS | 3 s |
| `tb/formal/flit_pipe.sby` (prove) | PASS | <1 s |

Total ~14 min. For comparison, iteration 1 same-day runs of the same
proofs: 607 s / 284 s / 102 s / 55 s / 3 s — wall time varies with machine
load; the verdicts are the stable fact.

Important scope notes (from `formal/README.md`): all bounded-liveness claims
are assert-within-N in BMC mode; **unbounded liveness is not claimed**. The
proofs hold under the environment contracts E1–E4 listed there (each weaker
than the real system's behavior — e.g. E2's 12-cycle engine bound vs the
real q_hebb_edge's 10). The conservation proof uses shrunk parameters
(EDGES_N=1, K=4, B=4, AGEW=8), not the full fabric.

**Operational gotcha — serialize formal runs per clone.** `sby -f` first
DELETES the shared workdir `formal/<task>/`, then rebuilds it. Two lanes
running the same `.sby` (or `make formal` overlapping anyone's solo
`formal/<task>.sby` run) will destroy each other's in-flight proof — the
victim loses its 15–60 minute run with no error pointing at the cause
(this bit the fair lane for real, 2026-08-30; the failure was a workdir
wiped mid-run, not a solver issue). Rule: one formal run per workdir; if
you must parallelize, clone the repo. Also note `cell_core.fair` is the
long pole (see its depth-130 note above) — start it first, or run it in
its own clone.

## Lane 4 — `make synth` + `make pnr`: iCE40 flow (yosys, then nextpnr → icepack)

`make synth` runs `yosys -s synth/fpga-converged.ice40` — ELABORATION
ONLY (~20 s): the PnR-converged k4b4a8e1 config (the formal conservation
proof's parameters) on the real `q_fabric_top`, emitting
`synth/fabric2_k4b4a8e1_ice40.json` + a `stat` table. It does NOT run
place-and-route. **`make pnr` is the rest of the flow** —
nextpnr-ice40 (HX8K-CT256, 12 MHz target) → icepack — and reproduces
the measured LC/fmax/bitstream numbers below.

**Result (2026-08-29, iteration 2): synth exit 0 ~20 s; pnr exit 0 ~3
min, full PnR + icepack.** 6,002 SB_LUT4, 898 SB_CARRY, ~2,430 FF-class cells, 157
port bits on this tree (the committed
`synth/stat_fabric2_k4b4a8e1.txt` records 5,951 LUT4 / 878 CARRY from the
PIPE_EFF-retime commit; the tree has moved since — both are real
measurements, of different trees). A fresh PnR in this run measured
**fmax 44.43 MHz @ the 12 MHz target — PASS** (report_k4b4a8e1.json;
iteration 1 and the audit pass measured 40.44 and 43.36 MHz on their
trees — PnR seed variance; every run passes the 12 MHz constraint with
margin). A fresh 135,100-byte `fabric2_k4b4a8e1.bin` was packed. Also
verified in iteration 1: UP5K sg48 serf NCELL=1 → 4,232/5,280 LC
(80.1%), 37/96 IO, fmax 16.78 MHz post-route (17.36 MHz is the
post-placement estimate) — PASS at 12 MHz. The committed bitstream
`synth/fabric2_k4b4a8e1.bin` is tracked.

## What is NOT covered — read this before relying on the quilt

- **No on-hardware test.** Every result above is simulation, formal, or
  synthesis. No board bring-up has been done; the bitstream is untested on
  metal. No PCF exists yet (IO is auto-placed, `--pcf-allow-unconstrained`).
- **Unbounded liveness is unproven.** BMC proofs bound violations within
  their depth; they are not k-induction certificates (except the one
  `tb/formal/flit_pipe.sby` prove run). Fair/tick proofs rely on E1–E4
  environment contracts, which are stated, not proven from the RTL above
  the cell.
- **Formal params are shrunk.** Conservation is proven at EDGES_N=1, K=4,
  B=4, AGEW=8 — not at the shipped fabric's scale.
- **The Python lane is a model, not a miter.** No formal equivalence proof
  between Python semantics and RTL exists.
- **PnR timing depends on unconstrained IO.** fmax numbers come from
  nextpnr with auto-placed pins; a real PCF could change them.
- **No CI.** Verification runs when an iterator runs it; nothing prevents
  regressions between commits except the discipline of running these
  targets. (Open lane.)

## History of verification runs

| date | iteration | what ran | result |
|---|---|---|---|
| 2026-08-29 | 1 | suite + python + 6 proofs + PnR through UP5K | 18/18, 34/34, 6×PASS, 16.78 MHz post-route fmax (17.36 post-place) |
| 2026-08-29 | 2 | `make test/sim/synth` + `make formal` (all six re-run) | 18/18, 34/34, 6×PASS, yosys exit 0 — one-command front door verified |
| 2026-08-29 | audit (independent) | suite + python + 5×sby + full PnR both tops (UP5K serf, HX8K k4b4a8e1) + icepack; README/VERIFICATION numbers re-measured and corrected | 18/18, 34/34, 5×PASS (fly 82 s, cons 42 s, dyadic 3 s, tick 249 s, fair 605 s), 16.78 / 43.36 MHz post-route |
| 2026-08-30 | snapshot 6e59409 | deterministic verdict snapshot from sby workdirs | tick PASS@79, dyadic PASS@24, conservation PASS@54, fly PASS@39 — **fair INCOMPLETE@85** (depths had been raised to 105/130 by 4dd8195 same day; no completed fair run at depth 130 is on record as of 2026-09-03) |
| 2026-09-03 | audit r13 (fresh clone) | suite re-run after fixing fresh-clone tb_quf_boot (new crc32 lane needs `tb/run/quf_crc.hex` pre-built) + python sim + link sweep | 21/21, 34/34, 0 FAIL — pre-fix fresh clone was 20/21 (tb_quf_boot FAIL: missing quf_crc.hex) |
