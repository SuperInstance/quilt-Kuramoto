# formal/ — machine-checked invariants (SYNTHESIS.md I1/I2/Q2 + calculus A1/T1)

SymbiYosys (sby) + yosys 0.47 + boolector, stock oss-cad-suite. Run from the
repo root:

    sby -f formal/flit_pipe.fly.sby
    sby -f formal/cell_core.fair.sby
    sby -f formal/cell_core.tick.sby
    sby -f formal/fabric.conservation.sby
    sby -f formal/echo_gate.dyadic.sby

## Results

| proof | invariant | mode/depth | verdict | runtime |
|---|---|---|---|---|
| `flit_pipe.fly.sby` | FIFO safety C2/C3/C4 + value integrity V1 (no flit lost, duplicated, or reordered; counters bounded) | BMC 40 | **PASS** | 65 s |
| `cell_core.fair.sby` | I1a op bound (gap ≤ 64, tick-free), I1b composite (gap ≤ 128, spaced ticks), I2 response ≤ 66 | BMC 130 in tree since 2026-08-30 (Finding 3 re-run depth; at 80, I1b's gap≤128 cannot be expressed). **Depth-130 PASS completed 2026-08-30: rc=0, 2 h 29 m 54 s wall (smtbmc boolector), log /home/eileen/fair130.log.** See VERIFICATION.md Lane 3 serialize rule | **PASS** (80) | 15 m 19 s |
| `cell_core.tick.sby` | Q2 under permanent ingress flood + arbitrary strobes: suppression Q2b, composite deadline Q2a1 ≤ 100, entry witness Q2a2 ≤ 66 | BMC 80 | **PASS** | 10 m 23 s |
| `fabric.conservation.sby` | 2-cell ledger: A1/T1 mirror — emitted == booked + in-flight (+ in-service/external); serialization; no silent drops; fanout addressing. **Re-proven 2026-08-29 with `PIPE_EFF(1)` pinned** (the v2.1 effect-pipeline retime — the shipped bitstream's config; the prior committed artifacts predated the retime) | BMC 55 · **UNBOUNDED via `mode prove` + `abc pdr` (2026-08-30, 25.9 s, `fabric.conservation.pdr.sby`) — see FORMAL-PROOFS "PDR referee"** | **PASS** (both) | 40 s · 28 s |
| `echo_gate.dyadic.sby` | echo gate (§2c mathmetal, 2026-08-29): the graded class brackets the trace into its dyadic octave `2^(PW-1) <= F << g < 2^PW` at every cycle (the staircase feeding the ladder's 2x envelope); PRIORITY fire-beats-leak; MONO no-resurrection; ZEROABSORB; DEAD gates training at F=0; DISABLED = FLOOR 0 = v1. Covers reached (companion cover run): g in [0,7] and >= 8 | BMC 25 | **PASS** | 2 s |

Total sby runtime (final passing runs): ~28 min. All bounded-liveness claims
are assert-within-N (shadow countdown) in BMC mode; unbounded liveness is not
claimed. Bounds and their structural worst cases:

- I1a 64: worst real op is view(1) (wsum, 4 valid edges, engine contract
  readout ≤ 12) ≈ 57 cycles. Complete at depth 80 (a violation needs ≤ 67).
- I1b 128: worst = op (57) + one tick service (~35) chained at the op
  boundary ≈ 94; a second service cannot chain because of the E4 scheduler
  spacing assumption. Verified within depth 80 (a >128 violation would need
  ≥129-step traces — not excluded by this run; margin is 34 cycles).
- I2 66: responses are emitted inside the op (ST_RESP) and a pending tick
  dispatches only at the following ST_IDLE, so ticks can never delay a
  response; worst ≈ 60. Complete at depth 80.
- Q2a1 100: strobe → next ci_ready pulse; worst ≈ 92 (strobe on a view(1)
  accept + full tick service incl. fire fanout). Deadline restarts on newer
  strobes, so chained services stay bounded without a spacing assumption.
- Q2a2 66: strobe → first sweep engine command (hb_cmd==010, issued only by
  tick service) when ≥1 edge is linked: worst ≈ 59.
- DROP 16: effect accepted at a cell → cofire commit strobe; worst ≈ 4.

## Environment contracts (assumptions, each weaker than the real system)

- E1 (fair/tick): egress always grants (`lo_ready`/`lx_ready` = 1).
  Ring-progress backpressure is the fabric-level property (SYNTHESIS Q1).
- E2 (fair/tick): engine responsiveness — readout (cmd 011) answered within
  12 cycles, other commands within 4, counted only while an engine op is
  active. Real q_hebb_edge: 10 and 2, so every real trace satisfies E2.
- E3 (fair/tick): dialfile stub with exact q_dialfile timing, free data.
- E4 (fair): tick scheduler spacing ≥ 128 cycles (q_tick_sched default:
  one strobe per 2^8 = 256). Without it, adversarial sub-service strobes
  chain services forever — which is why the scheduler spaces ticks.
- conservation: NO stubs — two real q_cell_core instances, real q_hebb_edge
  engines, real q_flit_pipe channel; only the environment (fire-only
  workload after a bind+link setup) is constrained. Shrunk params for
  tractability (EDGES_N=1, K=4, B=4, AGEW=8); the ledger counts commits,
  which neither ladder half-life shifts nor bucket saturation create or
  destroy, and neither is reachable inside the 55-cycle horizon anyway.

## Findings (RTL defects the proofs forced; both fixed in the working tree)

1. **`tick_pend` multi-driven** (rtl/q_cell_core.v): the main FSM block's
   reset clause assigned `tick_pend <= 1'b0;` while the dedicated Q2
   interlock block also drives it — two processes, one register. Icarus and
   Verilator 5.029 accept it; yosys's formal backends reject the module
   ("Found multiple drivers"). Fix: delete the redundant assignment in the
   main block (the interlock block resets it). No semantic change.

2. **One-cycle `ci_ready` hole with a pending tick → silent ingress drop**
   (rtl/q_cell_core.v): every return-to-IDLE path (and ST_IDLE's self-loop)
   asserted `ci_ready <= 1'b1` unconditionally, so when a tick strobe landed
   during an op (or during the consume-op dip), the first IDLE cycle offered
   `ci_ready` while the FSM took the tick-dispatch branch instead of
   consuming. The upstream `q_flit_pipe` pops on `valid && ready` at that
   edge — the flit is silently dropped. Caught independently by the first
   runs of cell_core.tick (Q2b counterexample) and fabric.conservation
   (SER/DROP counterexample: an accepted effect never booked). Fix: gate all
   six set-ready sites with `ci_ready <= !(s_tick || tick_pend);`
   (ST_UNB's birth contract left as-is). Both TBs still pass
   (tb_cell_core, tb_fabric_smoke), and the fixed invariant is now proven
   (Q2b).

Both fixes live in rtl/q_cell_core.v in the working tree and are required
for these proofs to reproduce; commit them with (or before) formal/.

## Harness notes (traps hit, for future lanes)

- `localparam [4:0] MAX = 64` silently truncates to 0 in Verilog — width
  your bound parameters.
- Two non-blocking assignments to the same shadow register in one always
  block: last-NBA-wins silently drops the first (hit f_pocc push+pop).
- No hierarchical references into the DUT (yosys turns them into undriven
  implicit wires) — everything is proven at module boundaries; "an edge
  exists" is witnessed by an executed set-base engine command (a LINK
  accepted while unbound is naked and creates no edge).
- flit_pipe value integrity (V1) is BMC-bounded, not k-inductive: shadow
  contents cannot be tied to DUT registers without XMRs. C2-C4 remain
  k-inductive and are re-proven so at tb/formal/flit_pipe.sby.

sby workdirs (`formal/<task>/`) are gitignored via formal/.gitignore.
