# SYNTHESIS — quilt-verilog v1

2026-08-29, synthesis lane. Binds the round-2 scorecard (winner glm, steal-list),
the jester curveballs, the socratic expansion (Preferring Fabric), and the hermes
advocacy gate questions into one buildable v1. Companion RTL: `rtl/`, `tb/`.

---

## Part A — the three gate questions, answered with mechanisms

The advocate's rule: *mechanisms, not paragraphs.* Each answer names the invariant,
the mechanism that enforces it in `rtl/`, and the test that would fail if the
mechanism were a wave of the hand.

### Q1 — Liveness under load

**Invariant (I1).** Every core op is bounded: `MAX_OP_CYCLES` (v1 bound: 64) after
an ingress accept, the cell core reasserts `ci_ready`, because the core FSM is a
cooperative run-to-completion machine with no unbounded waits on shared engines —
v1 has **no shared math tail** (cosine is not provisioned; `view(3)` NAKs), so the
grant-starvation failure mode the advocate found in glm (§1.1 of ADVOCACY.md) is
*designed out*, not scheduled. The only potentially unbounded wait is fire-fanout
egress backpressure (`lx_ready`), and that is bounded by ring progress: on a single
ring every non-delivering transit advances one node per cycle and every delivery
frees a slot, so a correctly-addressed ring never reaches a state where zero
flits advance; a full ring drains at ≥1 flit per `MAX_OP_CYCLES` in the worst
case. (Honest limit, deferred with curveball 3: a flit misaddressed to a
nonexistent node has no owner and circulates forever; v1's traffic contract is
that senders address valid nodes — cells or EXTID — and the v2 seam/bridge work
owns the drop policy.)

**Mechanism (I0, found the hard way).** The first bring-up hit the exact
hazard the advocate predicted for glm's unscheduled seams (§1.1): a core
holding a response while an inbound flit awaited delivery deadlocked
(`inject_ok=0` because the slot was occupied by the undeliverable hit-flit;
`ld_ready=0` because the core was busy emitting — mutual wait). The fix is
structural and now part of I1: `q_cell` wraps the core in **elastic ingress
and egress skid buffers** (`q_flit_pipe`, whose `s_ready` is purely local —
the 1-deep form's ready chain also closed a combinational loop around the
full ring, UNOPTFLAT in verilator and a real hazard). The core always
returns to IDLE, delivery frees a slot, and the egress buffer drains into
the bubble; the deadlock is unreachable in v1's traffic class.

**Consequence (I2).** A `qm_view` accepted at a cell is answered within
`(flits queued ahead of it) × MAX_OP_CYCLES + ring latency`, even under a
continuous effect storm, because the ingress is not droppable-by-starvation: the
core takes one flit per bounded op and views/effects/binds all enter through the
same bounded serialization point. Contrast: opencode's `tick_go && !ci_valid`
(counterexample in ADVOCACY §1.2) and glm's unsketched math-tail grant (§1.1).

**Enforcement.** `tb/tb_cell_core.v` floods the cell with back-to-back effect
flits (`ci_valid` never idle) and asserts (a) the gap between consecutive
`ci_ready` pulses never exceeds `MAX_OP_CYCLES`, and (b) a view injected behind
the flood is answered within the composed bound. `tb/tb_fabric_smoke.v` measures
every view-response latency on the real fabric and asserts the same bound while
training traffic runs. A formal check is a one-liner over the same signal:
`assert (fell(ci_ready) |-> ##[1:MAX_OP_CYCLES] ci_ready);` — the TB replicates
it as a cycle loop because v1's open tools are simulators, not SVA solvers.

### Q2 — Non-deferrable time

**Mechanism.** The tick is a hardware-interlocked deadline, not an advisory phase.
`s_tick` latches `tick_pend` in a dedicated register; in `ST_IDLE` the core
services `tick_pend` **before** accepting any new ingress (`ci_ready` is
suppressed while `tick_pend` is set). A tick can therefore be deferred by at most
the op currently executing (≤ `MAX_OP_CYCLES` by I1) — never by traffic, no matter
how saturated. The decay sweep / activation leak / fire test run on every tick at
every cell, busiest cell included. This is jester curveball 8 (pre-emptive tick)
implemented as front-of-queue priority at an op boundary — strictly cheaper than
mid-op preemption because no op has saved context to corrupt.

**Control plane independence.** Config and observation travel as ordinary flits
(Law 2), and the no-drop ingress FIFO of the ring is drained by the same bounded
core, so bind/view can be starved by nothing slower than I1's per-flit bound —
zeroclaw's "no-drop becomes unreachable" (ADVOCACY §1.3) cannot occur in v1
because v1 has no separate ingress FIFO to fill; backpressure is one bounded op
deep.

**Enforcement.** `tb/tb_cell_core.v` holds effect ingress continuously valid,
strokes `s_tick` mid-flood, and counts cycles from the strobe to the observable
entry into the tick service state (`dut.u_core.state == ST_TICK`, hierarchical
probe). Asserted < 2×`MAX_OP_CYCLES`. This test *fails* on opencode's skeleton
verbatim (`tick_go && !ci_valid` never fires under the flood) — the counterexample
is now the regression test.

### Q3 — The rule that is verified is the rule that learns

**Mechanism.** The acceptance gate is end-to-end on the real datapath:
`tb/tb_fabric_smoke.v` runs bind → link → 100 co-active effects → `qm_view`
golden-value check → tick → fire observed at the neighbor cell (via `qm_view` of
the neighbor's activation, round-tripped through the real ring) → decay-only
ticks shrink the weight below THRESH (verified by view). Golden-model error
bounds are asserted at every integrating boundary, in the engine TBs:

- **Ladder (glm):** at every readout, `Ŵ` stays within a factor of 2 of the
  continuous law `W_exact = Σ 2^(-age/H)` (`W_exact/2 − 1 ≤ Ŵ ≤ 2·W_exact + 1`;
  the dyadic envelope — global shift boundaries put each event in class
  `floor(age/H)` or `floor(age/H)+1` depending on phase, which is exactly the
  ±1-class ambiguity the staircase bound permits), plus exact-value equality on
  the unshifted ladder in the fabric smoke test (`wsum == base + N·2^8` exactly
  for N co-fires before any half-life shift).
- **Hyperbolic (zeroclaw):** `W_true(P0) ≤ W_rtl ≤ W_true(P0/4)` at checkpoint
  ticks — the dyadic-interval envelope (decrement interval `P₀ >> 2·msb(W)` is
  within [1,4)× the exact interval `P₀/W²`), asserted with real arithmetic in
  `tb/tb_hebb_edge.v`.

**Why the named failure modes cannot pass.** A placeholder write (claude's
`16'h0000`) fails the first wsum assertion — the golden value is computed
independently in the TB. A stale accumulator (claude's one-cycle-lagged
saturator) fails the exact-equality check at the first integrating boundary
(`act` is asserted after each effect against the TB's own saturating model).
A magnitude-confounded product (seed's AND tree) is out of scope by construction:
v1's only products are one signed multiply in the effect integrator and zero in
the weight engine (counts are integers; the "multiply" in the ladder readout is
wiring). No placeholder writes and no stale accumulators exist in `rtl/`; the
TBs are written so that re-committing either fails CI.

---

## Part B — v1 architecture: glm chassis, three steals, socratic split

### Chassis (glm, per scorecard)

- Ring-of-cells fabric; one streaming contract (valid/ready flit:
  `{op, src, dst, a0, a1, a2, dat}`); registered pipe slices for ring timing.
- The cell core FSM is the only interpreter of the five quilt opcodes (Law 2).
- Saturate-never-wrap everywhere a value integrates (`act`, `wsum`, engine
  outputs); sticky overflow flag surfaced to the fabric top (`o_ovf`).
- Degrade gracefully: v1 provisions no cosine engine — `view(3)` NAKs — and the
  fabric still runs all five verbs (glm's `HAS_COS=0` stance).
- Scorecard fixes owed by the winner, paid: no use-before-declaration (v1 core is
  written clean); the ladder readout is a **registered sequential loop** (no
  combinational adder tree ⇒ no UNOPTFLAT); widths swept until
  `verilator -Wall` is silent on `rtl/`.

### The three mandated steals

1. **zeroclaw's power-law decay counter** → `q_hebb_edge` implements both engines:
   `MODE=0` glm ladder (K·B staircase, proven 2× bound) and `MODE=1` zeroclaw
   hyperbola (integer `W`, `age`, decrement interval `P₀ >> 2·msb(W)`, floor 1).
   Going beyond the letter of the steal (and answering the advocate's steelman
   residue: "make law-select a bind-time dial wherever silicon allows"): **the
   law select is a runtime dial** (`MODE`, `P0E` in `q_dialfile`), not a
   compile-time constant — the forgetting law is data, and the acceptance gate
   is the referee.
2. **opencode's runtime dial/config map** → `q_dialfile` ships the full map
   (ETA_F/ETA_S/KF/KS/KA/THRESH/REFR/COS_MIN, reset defaults) plus the v1
   additions P0E/MODE/HL. All writes go through `qm_bind` (Law 2). ETA_F/ETA_S/
   KF/KS/COS_MIN are readable fabric state reserved for the engines that consume
   them post-v1 (per-value view via `view(2)`).
3. **opencode's train-to-fire-decay acceptance test** → `tb/tb_fabric_smoke.v`
   is the CI gate, on the real 4-cell fabric, end-to-end (Q3 above). The
   `q_link_ringport` / `q_flit_pipe` skeletons are reused directly as advised
   (they compiled clean and their ready logic is correct).

### Socratic ideas: what enters v1, what waits, and why

**In v1:**

- **Tick as epoch + hard deadline (R6's backstop reading).** v1 is single-clock;
  the tick is the time reference *and* the interlocked deadline (Q2). The socratic
  demotion of the tick to "epoch reference" is adopted in the spec, implemented
  as the v1 backstop.
- **Event-serialized core (R8 view atomicity).** One cooperative FSM means a view
  is atomic with respect to the local event stream by construction — no torn
  entries, no snapshot protocol needed in v1.
- **Law-select as dial (R6/R3 "bindings are data" instinct).** See steal 1.

**Deferred to v2 (each with the reason and the curveball that owns it):**

- **Memory-is-routing (R3) and the hierarchy (R4).** v1's single ring has no
  routing decision — bypass-unless-dst, mechanical — so route-shaped memory would
  be decoration (the socratic lane's *own* attack #1). It earns its keep at
  bridges/tiers; v2 builds bridge selection as the learned decision surface
  (their R7 scoping, which we accept).
- **Traffic-based tick (curveball 6).** The C golden model is dt-based; event
  semantics is a spec change to the reference model. v1 keeps decay on the tick
  backstop only; the event-count decay engine lands with the respec in v2.
- **Flit-drop policy at seams (curveball 3) and effect-drop marking
  (curveball 4).** Meaningful only with bridges/congestion; v1's single ring
  cannot deadlock (wrap direction is acyclic; delivery frees slots). Documented
  as the v1 liveness limit: simultaneous full-node response backpressure on a
  saturated ring is not reachable in v1's traffic class and becomes the v2
  question exactly as curveballed.
- **GALS source-synchronous links (R5), dither/deadband bridge bandit (R8),
  affinity sidecar (R8), κ̂/vMF (zeroclaw §2.2).** All v2+; ports and dial slots
  are reserved so none of them is a redesign.

### v1 module map

| File | Role |
|---|---|
| `rtl/q_dialfile.v` | runtime dial registers (steal 2) |
| `rtl/q_hebb_edge.v` | hebbian_edge_update: ladder + hyperbola engines (steal 1) |
| `rtl/q_link_ringport.v` | comb ring node: deliver/transit/inject (opencode, reused) |
| `rtl/q_flit_pipe.v` | registered flit slice (opencode, reused) |
| `rtl/q_tick_sched.v` | tick strobe generator |
| `rtl/q_cell_core.v` | cell core FSM: the only opcode interpreter; Q1/Q2 mechanisms |
| `rtl/q_cell.v` | one cell: core + dialfile + edge array + ringport + inject mux |
| `rtl/q_io_port.v` | streaming IO contract module (Law 4 boundary; thin by law) |
| `rtl/q_fabric_top.v` | 4-cell ring fabric + io node + tick |

Testbenches in `tb/`: one per module, plus `tb_fabric_smoke.v` (the acceptance
gate). All run on `iverilog -g2005`; `rtl/` is `verilator -Wall` clean.

### Weight formats (one paragraph, so TBs and RTL agree)

Ladder readout: bucket *i* carries implied weight `2^-i`; the adder-loop places
bucket *i* at bit offset `(K-1-i)·B`, and the engine reports the **top PW bits**
`P[KB-1:PW]` — one fresh cofire (K=8, B=8) reads as `2^8 = 256` (Q1.15 ≈ 0.0078),
plus the bind-time `base`. Hyperbolic readout: `W` scaled by 256, saturating
(`W=100 → 0x6400`), plus `base`. THRESH (`0x6000` default) therefore means the
same thing in both engines, and the smoke test's "100 co-fires cross THRESH"
holds in either law.
