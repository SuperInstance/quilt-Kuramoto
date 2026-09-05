# FORMAL-PROOFS — the six proofs, one section each

The depth companion to `formal/README.md` (the suite contract and summary
table) and `docs/VERIFICATION.md` (all lanes). This document goes the other
way: one section per `.sby` — `formal/*.sby` plus the k-induction harness in
`tb/formal/` — stating the invariant in plain mathematics, what a violation
would mean in hardware, the engine and strategy used, the measured wall
time, and the honest assumptions each proof rests on. If a number here
cannot be reproduced on this tree, that is a bug in this document.

Toolchain: stock oss-cad-suite — SymbiYosys (sby) driving yosys 0.47+22,
engine `smtbmc boolector` for every proof. Run any of them from the repo
root: `sby -f <path>.sby`, or all six via `make formal`.

**Timing convention.** Wall times below marked *(iter 3, re-run)* were
measured on this tree, this machine, 2026-08-29 ~23:17–23:19 AKDT, by this
documentation pass. The two proofs that exceed a few minutes (fair, tick)
were **not** re-run here; their most recent measured timings (iteration 2,
same tree, 2026-08-29, from `docs/VERIFICATION.md`) are cited instead.
Wall time varies with machine load across runs — the verdict is the stable
fact; the seconds are context, not claim.

| proof | mode / depth | verdict | wall time (this pass) | wall time (iter 2, cited) |
|---|---|---|---|---|
| `formal/echo_gate.dyadic.sby` | BMC 25 | PASS | **2.4 s** | 3 s |
| `tb/formal/flit_pipe.sby` | prove (k-induction), depth 15 | PASS | **0.34 s** | <1 s |
| `formal/fabric.conservation.sby` | BMC 55 | PASS | **35.9 s** | 38 s |
| `formal/flit_pipe.fly.sby` | BMC 40 | PASS | **74.0 s** | 72 s |
| `formal/cell_core.tick.sby` | BMC 80 → 105 (2026-08-30, 4dd8195) | PASS | not re-run | 215 s |
| `formal/cell_core.tick.prove.sby` | prove (PDR), depth 130 | PASS | **747 s** (2026-09-03) | — |
| `formal/cell_core.fair.sby` | BMC 80 → 130 (2026-08-30, 4dd8195) | PASS | not re-run | 498 s |
| `formal/g3-kinduction/fabric.conservation.g3-certificate.sby` | prove (k-induction), depth 12, smtbmc boolector | PASS | **10 s** (2026-09-02) | — |

For scale across passes (same proofs, same tree family): iteration-1
measured 607 / 284 / 102 / 55 / 3 s (fair / tick / fly / conservation /
dyadic); the independent audit pass 605 / 249 / 82 / 42 / 3 s; the
original proof-suite runs 919 / 623 / 65 / 40 / 2 s. Every run PASS.

---

## Method shared by all six (read once)

- **BMC (bounded model checking)** unrolls the design for *depth* cycles
  and searches for a counterexample trace of at most that length. A PASS
  means: **no violating trace of length ≤ depth exists**, from the reset
  state, under the harness's assumptions. It is not a statement about
  longer traces — except where the structural worst case is argued to fit
  inside the depth (done per-proof below).
- **k-induction** (`mode prove`) is unbounded: base case + induction step.
  A PASS is a proof for all reachable futures, not just a window. Two
  proofs here are k-inductive (`tb/formal/flit_pipe.sby` and, since
  2026-09-02, the g3 certificate
  `formal/g3-kinduction/fabric.conservation.g3-certificate.sby`, which
  closes the G3 gap: fabric.conservation proven unboundedly by plain
  k-induction over a sticky-guarded netlist plus 910 named
  machine-mined PDR clauses — engine-independent, no PDR run log; see
  `formal/g3-kinduction/README.md`); the rest are BMC.
- **Bounded liveness** is encoded as *assert-within-N*: a shadow countdown
  register arms on an event and the assertion fails if the deadline passes.
  This proves "the deadline holds within the BMC depth", never "eventually"
  in the unbounded sense. Unbounded liveness is **not claimed** anywhere in
  this suite.
- **Shadow models**: each harness builds a small reference machine
  (occupancy counters, ledger accounts, a 2-deep payload FIFO) from the
  DUT's *boundary* handshakes only, and asserts the DUT matches it. No
  hierarchical references into the DUT (yosys's Verilog frontend turns
  `dut.x` into an undriven wire — everything is proven at module
  boundaries).
- **Reset preamble**: DUT registers carry no init values, so the first two
  timesteps are forced into reset (`assume (!rst_n)`) before properties
  bind; a 2-bit counter guards the handoff.
- **Non-vacuity**: every harness ships `cover` statements (the solver must
  show the interesting states are reachable — a full pipe, a booked commit,
  a priority clash). A proof over an unreachable environment would be
  vacuous; the covers are the antidote, and they are checked by companion
  cover runs where noted.

---

## 1. `formal/flit_pipe.fly.sby` — the flit slice is an ideal 2-deep FIFO

**DUT**: `rtl/q_flit_pipe.v` — the skid-buffered flit slice used at every
ring hop and every cell boundary. **Strategy**: BMC, depth 40, shadow
occupancy counter + 2-deep shadow payload FIFO.

**Invariant (plain math).** Let `accept(t)` = a downstream handshake at
cycle t (`s_valid ∧ s_ready`), `emit(t)` = an upstream handshake
(`m_valid ∧ m_ready`), and `occ(t) = Σ_{τ≤t} accept(τ) − emit(τ)` (the
shadow count, reset-aware). At every cycle after reset:

- **C2**  `occ ≤ 2` — accepted flits never exceed capacity;
- **C3**  `m_valid ⇔ occ ≠ 0` — data is presented iff something is queued
  (nothing hidden, no phantom);
- **C4**  `s_ready ⇔ occ < 2` — backpressure asserted exactly at capacity;
- **V1**  on every `emit`, the emitted payload equals the head of the
  shadow FIFO fed in arrival order — no loss, no duplication, no
  reordering of payload *values*.

**What it rules out**: a flit silently swallowed or minted inside any pipe
slice, a stall presented as full when empty (deadlock fodder), an
over-accepted third flit (guaranteed corruption), and payload reorder or
duplication — the failure modes that make a network fabric untrustworthy
at its most basic layer.

**Measured**: PASS, 74.0 s this pass (72 s iter 2, 102 s iter 1, 82 s
audit, 65 s original).

**Caveats**: V1 is BMC-bounded, not inductive — payload equality cannot be
carried through arbitrary DUT register states without hierarchical refs.
C2–C4 *are* inductive and are re-proven unbounded by
`tb/formal/flit_pipe.sby` (§6). No environment assumptions at all: both
handshake partners are free.

---

## 2. `formal/fabric.conservation.sby` — the two-cell ledger conserves credit

**DUT**: two real `q_cell_core` instances (PIPE_EFF=1 — the shipped
retime), two real `q_hebb_edge` engines, one real `q_flit_pipe` between
them. **No stubs.** **Strategy**: BMC, depth 55, shadow ledger accounts
counted at module boundaries.

**Invariant (plain math).** After a constrained bind+link setup (cells A,B
linked; A dialed to fire on every tick), for every cycle t of the run
phase, with accounts: `emit` = effect flits A handed to the pipe, `pipe` =
flits occupying the pipe, `acc` = effects accepted at B, `book` = cofire
commits strobed at B, `ext` = B's own fire flits sunk externally:

- **T1**  `emit = pipe + acc` — transport conservation: nothing lost or
  fabricated in movement;
- **A1**  `emit + ext = book + pipe + (acc − book) + ext` — the ledger:
  everything fires issued is either booked as weight, in flight, in
  service, or externally sunk. Constant across commits — a commit moves a
  flit from in-flight to booked; nothing else mints or burns credit;
- **SER**  `acc − book ≤ 1` — commits serialize through the core;
- **DROP**  every accepted effect is booked within 16 cycles — the silent
  unknown-source drop path is unreachable for linked peers;
- **FAN**  every A emission carries op=EFFECT, src=A, dst=B — fanout
  addresses the linked peer.

**What it rules out**: weight appearing from nowhere or vanishing — the
hardware analog of a bank minting money; effects accepted then silently
dropped at booking; misaddressed fanout. This is the quilt calculus A1/T1
(cut conservation) as a machine-checked property of real RTL, on the exact
config the committed bitstream ships (PIPE_EFF retime included — the
ledger identity survived the pipeline change, because conservation is a
property of commits, not of latency).

**Measured**: PASS, 35.9 s this pass (38 s iter 2, 55 s iter 1, 42 s audit;
originally 40 s).

**Caveats (all stated, none hidden)**:

- Parameters are shrunk for tractability: EDGES_N=1, K=4, B=4, AGEW=8 —
  not the shipped fabric's scale. Conservation at full scale is unproven.
- The horizon is 55 cycles: within it neither ladder half-life decay nor
  bucket saturation can occur — but the ledger counts *commits*, which
  neither decay nor saturation create or destroy, so A1 does not lean on
  the horizon.
- The workload is fire-only after setup (the regime where A1 is exact);
  mixed traffic with unbind/refund postings is not covered here.
- The environment is constrained only in that sense; the DUT cone has no
  assumption stubs (no E1–E4 needed — the engines are real).

---

### Prove-mode attempt (2026-08-29, expert-nudge lane)

Followed the honest-broker question: can conservation lift from BMC-55 to `mode prove`?
Tried. It cannot — yet — and the induction failures are informative.

Runs (all `sby -f`, oss-cad-suite, boolector; probe harnesses committed here):

- `formal/fabric.conservation.prove.sby` (full harness, prove, depth 55):
  basecase PASS; induction FAIL — engine descends 38→32 without closing (run killed;
  depth-8 probe confirms).
- Depth-8 probe names the first non-inductive assertion: line 293 —
  **SER's `assert (f_ins <= 1)`** *(corrected 2026-08-30; originally and
  wrongly recorded here as DROP's `f_icnt <= 16` — see the correction note
  below; the description of the counterexample state was right, only the
  line/property attribution was wrong)*. Counterexample
  (`fabric.conservation.probe/engine_0/trace_induct.vcd`):
  an arbitrary induction state with `f_ins = 2`, `f_acc = 170`, `f_book = 168`,
  `f_icnt = 16`, `f_pocc = 0`, and core-B internals unconstrained — two
  effects simultaneously in service (SER broken) with the DROP countdown at
  its bound, a state unreachable from reset that k-induction cannot exclude
  on boundary-visible state alone.
- `formal/fabric.conservation.prove-t1.sby` (SER/DROP/bookA stripped, only T1 +
  A1 + pipe-capacity + FAN): still FAILS induction. This is the real finding: even
  the flagship ledger identity is not k-inductive on shadow counters alone. Two
  missing strengthening lemmas, now named precisely:
  - **L1 (pipe content):** every flit resident in or emitted by the pipe post-setup
    has `op == OP_EFF`, `src == A_ID`, `dst == B_ID`. Without it, an induction state
    may pop a non-EFF flit (`f_pop` decrements `f_pocc` without incrementing `f_acc`),
    breaking T1; the shadow occupancy counter is only tied to real pipe contents
    through history k-induction cannot see.
  - **L2 (command provenance):** core B's `hb_cmd` strobes only occur as commits of
    genuinely accepted effect ops. Without it, an arbitrary core-B state can mint a
    booking strobe with no matching `f_effB`, incrementing `f_book` unbounded and
    breaking A1.

So the BMC-55 prose worst-case argument stays the honest statement for now. The
canonical path to `mode prove` is: prove L1 and L2 as auxiliary invariants over the
pipe/core state (likely needing visibility past the no-XMR harness boundary, e.g.
whitebox assertions inside `q_flit_pipe`/`q_cell_core` under a FORMAL define), then
T1/A1 close by induction and DROP/SER follow from L1+L2 plus the 16-cycle structural
bound. Cross-repo: until then, quilt-deck should keep citing THIS document's BMC-55
statement as the canonical conservation-invariant description rather than
paraphrasing it.
**Correction note (2026-08-30).** The second bullet above originally
recorded the depth-8 probe's first failure as "line 293, DROP's
`f_icnt <= 16`". That mislabeled the line. Three-way evidence
(docs/ACADEMIC-RIGOR.md §3.3, re-run against the elaborated model):

1. `formal/f_fabric_conservation.v` line 293 is `assert (f_ins <= 1);` —
   **SER**. DROP is the *guarded* assert at line 295
   (`if (f_acc != f_book) assert (f_icnt <= 16);`).
2. The elaborated netlist (`fabric.conservation.probe/model/design.il`,
   lines 8772–8789) contains exactly the assert cells `_v_290_82` (T1),
   `_v_291_85`, `_v_293_87` (**SER**), `_v_295_90` (**DROP**), `_v_300_92`
   (A1); the failed witness is `_v_293_87`, and its column range 9–28
   matches the 20-character SER statement, not the indented DROP guard.
3. The VCD counterexample's final state — `f_ins = 2`, `f_acc = 170`,
   `f_book = 168`, `f_icnt = 16`, `f_pocc = 0` — shows SER actually
   violated (two effects simultaneously in service), which is what an
   unreachable-from-reset arbitrary induction state produces.

The correction sharpens rather than weakens the finding: the first
non-inductive assertion is a property of core-B internals the flat
harness cannot see, which is precisely why L1/L2 whitebox visibility is
the canonical path named above. The bullet above has been corrected in
place; this note preserves the record of the mislabeling.

### L1/L2 strengthening attempt (2026-08-30)

Tried the canonical path named above: `formal/fabric.conservation.prove-l12.sby`
with harness `formal/f_fabric_conservation_l12.v` — the identical model plus
the L1/L2 lemmas of ACADEMIC-RIGOR §3.4 as whitebox assertions on `u_pipe`
(resident flit content: `a_q`/`b_q` op/src/dst) and `u_coreB` (`state`,
`lr_src`), including the one-op-FSM commit exclusivity (a booking strobe
exists only inside the ST_EFFT→ST_EFFR→ST_EFFP→ST_EFFM→ST_EFFI chain;
`f_ins != 0` pins core B in that chain). `rtl/` untouched: this Yosys
implements neither hierarchical references nor `bind`, so the harness
declares peek wires (`f_ws_*`) that the sby `[script]` connects to the real
flattened signals (`flatten` + `rename` + `connect`) — the script is part
of the harness.

Result, honestly: **basecase PASS** (`Status: passed` at 0:00:37 — the
lemmas hold from reset; a BMC-30 sanity pass also PASSED), **induction
still FAILS** — run killed at the 15-minute budget with the engine
descended k = 55→28 without closing (`EXIT=124`). The informative shift:
a depth-8 probe on the strengthened model names a **new first failure —
line 378, FAN's `assert (lxA_src == A_ID)`** — where the un-strengthened
probe's first failure was SER at line 293. The frontier moved off SER/DROP
and onto core A's emission provenance: `lxA_src` is driven by core-A
internals (its identity/lx registers) invisible to the boundary harness —
the same class of whitebox lemma as L1/L2, but for core A. Named for the
next pass as **L3 (emission provenance at core A):** post-setup, whenever
A drives `lx_valid`, `lx_src == A_ID` (its own identity register); not
added here (out of this attempt's L1/L2 scope). The counterexample state
at step 0: `f_emitA = 3`, `f_pocc = 2`, `f_acc = f_book = 32`, `f_ins = 0`,
core B resting at ST_IDLE — the garbage lives in core A.

## 3. `formal/echo_gate.dyadic.sby` — the gate brackets every trace into its dyadic octave

**DUT**: `rtl/q_echo_gate.v` (PW=16). **Strategy**: BMC, depth 25 (>5 leak
generations at the fastest leak), dials fixed per run via `anyconst`
(kle ∈ [1,8] per the dial contract, floor free), strobes free. Companion
cover runs confirmed the bracket is exercised at g ∈ [0,7] and g ≥ 8.

**Invariant (plain math).** With `F` the live trace value, `g` the gate's
output class, and PW=16, at every cycle after reset, whenever the gate is
enabled (floor ≠ 0) and the trace is nonzero:

- **DYAD**  `2^(PW−1) ≤ F ≪ g < 2^PW` — equivalently `2^(15−g) ≤ F <
  2^(16−g)`: the class rule `g = 15 − msb(F)` lands the trace in its dyadic
  octave, so ladder bucket g overstates the true weight by a factor in
  [1,2) — exactly the staircase the ladder's proven 2× envelope prices
  (error-envelopes Theorem 1);
- **PRIORITY**  fire beats a same-cycle leak: `fire ∧ tick ⇒ F′ = 2^PW − 1`;
- **MONO**  without fire, `F` never grows (leak/snap only decrease);
- **ZEROABSORB**  `F = 0` is absorbing until the next fire;
- **DEAD**  a dead trace gates every train off (`live = 0`), class frozen 0;
- **DISABLED**  floor = 0 recovers v1 exactly (always live).

**What it rules out**: a trace value the ladder buckets wrong by more than
2× (mis-bucketed staircase — the whole graded-class scheme would
overstate/understate weights unboundedly); resurrection of dead traces
(dead cells training again); leak winning a same-cycle tie with fire.

**Measured**: PASS, 2.4 s this pass (3 s in every prior pass).

**Caveats**: PW=16 only (the shipped width, but not parameterized-proof
general). The bracket is proven over the gate FSM as instantiated — the
*ladder's* use of gclass (the [1,2) overstatement argument) is the math
document (error-envelopes), with this proof supplying its integer core.

---

## 4. `formal/cell_core.tick.sby` — non-deferrable time survives permanent flood

**Unbounded upgrade (2026-09-03): `formal/cell_core.tick.prove.sby`
CLOSES the tick-depth lane — the same deadline assertions (Q2a1 <=100
cycles, Q2a2 <=66, Q2b pending⇒!ci_ready), same harness
(`formal/f_cell_core_tick.v`), closed by abc PDR (depth 130): **PASS,
747 s, no traces**. This is genuine unbounded liveness: EVERY strobed
tick is serviced within 100 cycles in ALL reachable futures, under
permanent ingress flood and arbitrary strobes, with fairness exactly
E1/E2/E3 (hardware contracts: local egress single-owner lo/lx_ready=1,
q_hebb_edge answers in 10/2 silicon — BACKEND-NOTES). BMC-80 remains
the fast regression; the prove run is the certificate.

**DUT**: `rtl/q_cell_core.v` (EDGES_N=4, K=8), the real engine/dialfile
contracts below. **Strategy**: BMC, depth 80, shadow trackers. The
adversarial environment: **ingress flood** (`ci_valid` held high forever,
free opcode mix) and **arbitrary tick strobes** — no scheduler spacing
assumed (stronger than the real system's).

**Invariant (plain math).** Past the first accepted flit (the birth
phase is out of scope by design), for every cycle t:

- **Q2b**  while a strobed tick has not entered service (shadow armed at
  the strobe, cleared at the sweep's first engine command or a
  post-service ready pulse): `¬ci_ready` — no ingress accept can occur.
  The pending tick is front of queue;
- **Q2a1**  from any strobe to the next `ci_ready` pulse is at most 100
  cycles (structural worst ≈ 92: a strobe landing on a view(1) accept plus
  a full tick service; the deadline restarts on newer strobes, so chained
  services stay bounded without a spacing assumption);
- **Q2a2**  once the cell has linked ≥ 1 edge (witnessed by an executed
  set-base engine command), the tick sweep's first engine command
  (`hb_cmd == 010`, issued only by tick service) appears within 66 cycles
  of any strobe — the tick was deferred by at most the in-flight op,
  never queued behind traffic.

**What it rules out**: starvation of the tick lane under load — the
"learning freezes while the network talks" failure; and the specific
one-cycle `ci_ready` hole where an upstream pipe pops a flit the
dispatching core ignores (**a silent ingress drop — found by the first run
of this proof**, fixed in `rtl/q_cell_core.v`, documented in
`formal/README.md` finding 2). It is also the exact property a rejected
competition skeleton violated (`tick_go && !ci_valid`, ADVOCACY SS1.2).

**Measured (cited, iteration 2 — not re-run by this pass)**: PASS, 215 s
(audit: 249 s; iter 1: 284 s; original run 623 s).

**Caveats**: E1 (egress always grants), E2 (engine answers readout within
12 / others within 4 cycles — real q_hebb_edge: 10 and 2, so every real
trace satisfies it), E3 (dialfile stub with exact timing). Strobes landing
before the first accepted flit are not claimed. All deadlines are
assert-within-N inside depth 80.

---

## 5. `formal/cell_core.fair.sby` — every op terminates and every op is answered

**DUT**: `rtl/q_cell_core.v` (EDGES_N=4, K=8) under the real scheduler's
spacing. **Strategy**: BMC, depth 80, shadow gap/response counters.

**Invariant (plain math).** For every cycle t:

- **I1a**  if no tick strobe arrived during the current low period, the
  gap between consecutive `ci_ready` pulses is ≤ 64 cycles (structural
  worst ≈ 57: a view(1) over 4 edges; the FSM has no unbounded wait);
- **I1b**  with tick strobes spaced ≥ 128 cycles (E4), the gap is ≤ 128 —
  at most one op plus one tick service per low period;
- **I2**  every accepted bind/link/view (plus the first flit of an unbound
  cell, and undefined opcodes) receives a response flit handshake within 66
  cycles, under **arbitrary** tick strobing — responses are emitted inside
  the op, and a pending tick dispatches only at the following idle, so
  ticks can never preempt or delay a response;
- plus: every response is an ack or a nak.

**What it rules out**: a host sending an op and waiting forever (the
run-to-completion FSM is proven to run to completion); a tick storm
stretching op latency unboundedly; response channels starving.

**Measured (cited, iteration 2 — not re-run by this pass)**: PASS, 498 s
(audit: 605 s; iter 1: 607 s; original run 919 s).

**Caveats**: E1–E4 as in §4 plus **E4** (scheduler spacing ≥ 128; the
shipped q_tick_sched default spaces one strobe per 256). Without E4,
adversarial sub-service strobes chain services forever — which is *why*
the scheduler spaces ticks; E4 is the documented fabric contract, not a
proof convenience. Depth-80 completeness: an I1a violation needs ≤ 67
steps and I2 ≤ 60, so both are exhausted well inside the depth; an I1b
violation would need ≥ 129 steps — not excluded beyond margin 34 cycles by
this run (the structural worst is ≈ 94).

---

## 6. `tb/formal/flit_pipe.sby` — the same FIFO contract, proven unbounded

**DUT**: `rtl/q_flit_pipe.v` read with `-D FORMAL`. **Strategy**:
`mode prove` — **k-induction**, depth 15, base case + induction step.
This is the original proof harness (predates `formal/flit_pipe.fly.sby`,
which strengthened it with V1).

**Invariant**: C2, C3, C4 exactly as §1 (capacity, no-phantom/no-hide,
exact backpressure) — but as an **unbounded** proof: no depth window, no
trace-length caveat. k-induction passes because the three properties are
inductive over the boundary-visible state (the shadow occupancy is
reconstructible at every step).

**What it rules out**: the same structural failure classes as §1, for all
time, not 40 cycles.

**Measured**: PASS (basecase + induction), 0.34 s this pass (<1 s iter 2).

**Caveats**: V1 (payload values) is *not* in this proof — value integrity
is BMC-bounded only (§1). This is the suite's only unbounded certificate;
everything else on this page is bounded.

---

## The assumption ledger, gathered (E1–E4)

Each assumption is *weaker than* the real system's behavior — the proofs
hold in a strictly more adversarial environment than the shipped fabric
provides — but they are assumptions about the environment, not facts
proven from the RTL above the cell:

| id | used by | statement | real system |
|---|---|---|---|
| E1 | fair, tick | egress always grants (`lo/lx_ready = 1`) | ring-progress backpressure is the fabric-level property (SYNTHESIS Q1), out of these proofs' scope |
| E2 | fair, tick | engine readout answered ≤ 12 cycles, other cmds ≤ 4 (counted only while an engine op is active) | real q_hebb_edge: 10 and 2 |
| E3 | fair, tick | dialfile stub with exact q_dialfile timing, free data | real q_dialfile |
| E4 | fair | tick strobes ≥ 128 cycles apart | q_tick_sched default: one strobe per 256 |

The conservation proof uses **none** of these (no stubs; real engines) but
at shrunk parameters and a 55-cycle horizon — the trade is stated in §2.

## What the proofs bought (defects found)

Two RTL defects were forced out by these proofs' first runs, both fixed
and committed (`formal/README.md`, findings 1–2): a multi-driven
`tick_pend` register (yosys rejected the module; simulators accepted it),
and the one-cycle `ci_ready` hole — a silent ingress drop under a pending
tick. Both fixes are required for reproduction; the proofs double as
regression guards on them.

## Reproduce

```sh
make formal                       # all six, in Makefile order
# or individually:
sby -f formal/flit_pipe.fly.sby   # ~1 min
sby -f formal/fabric.conservation.sby  # ~40 s
sby -f formal/echo_gate.dyadic.sby     # ~3 s
sby -f formal/cell_core.tick.sby       # ~4-10 min
sby -f formal/cell_core.tick.prove.sby # ~12.5 min (unbounded liveness)
sby -f formal/cell_core.fair.sby       # ~8-15 min
sby -f tb/formal/flit_pipe.sby         # <1 s (k-induction)
```

All timings on this machine (WSL2, oss-cad-suite at
`/home/eileen/tools/oss-cad-suite/bin`; the Makefile pins the PATH).
Nothing here is tested on hardware — see `docs/VERIFICATION.md`'s
not-covered list before relying on any of it.

### PDR referee (IDEATOR nudge, 2026-08-30): conservation closes UNBOUNDED

The IDEATOR leap: before paying the whitebox L1/L2 implementation pass,
ask `abc pdr` (IC3/PDR — auto-derives inductive invariants, no
hand-strengthening needed) as a referee. Scout canon:
`ecosystem/scout/2026-08-30-bmc-passes-induction-fails-glossed-state.md`.

**Result: PDR CLOSED.** `formal/fabric.conservation.pdr.sby` (identical
model, `mode prove`, engine `abc pdr`):

- **Property proved unbounded** — DONE (PASS, rc=0), engine elapsed
  25.9 s, converged at frame 9, 0 counterexamples, 6184 learned clauses,
  0 timeouts. Wall-clock 28 s including prep.
- Comparison: the same property needed depth-55 BMC + a prose worst-case
  argument before; k-induction failed (see above); PDR closed it
  unattended in half a minute, with no L1/L2 lemmas written.

**What this means for L1/L2.** The referee's verdict is outcome (a):
PDR's auto-derived invariant subsumes whatever strengthening T1/A1 need —
which proves the strengthening EXISTS and is derivable, but the sby
`abc pdr` wrapper does not surface the learned clauses in readable form.
**FOLLOW-UP CLOSED (2026-08-31):** the invariant was dumped — 854 clauses
over 169 latches, machine-derived and inductive, committed readable at
`formal/pdr-invariant/` with the analysis in `docs/PDR-INVARIANT.md`.
Headline: it DOES contain the `op`-style pipe-content clauses
(`!u_pipe.m_a0[3]` conditions 752/854 clauses), plus per-bit conservation
core lemmas (`f_acc`/`f_book`/`f_emitA`/`f_pocc`) and cross-core handshake
coordination. The honest statement is: **the conservation
invariant is now a machine-checked UNBOUNDED fact, not a BMC-55 window
plus prose** — the canonical citation for cross-repo consumers upgrades
from "BMC 55 PASS" to "mode prove / abc pdr PASS, 25.9 s".

**The whitebox L1/L2 Verilog pass is no longer the only path to the
unbounded statement** — it remains valuable only as human-readable
documentation of *why* (the `pdr -i` dump comparison decides whether it
is worth writing at all).

**Same-cost bonus ask (in flight at write time):** `cell_core.fair.pdr`
— the depth-130 fairness suite (2 h 29 m in BMC) as `mode prove` +
`abc pdr`. Early log shows frame ~131 with solver timeouts appearing —
plausibly outcome (b) for the big state space, which would be evidence
the fair strengthening needs exactly the structural lemmas its BMC
window approximates. Adjudicated in a follow-up entry either way.

**DEVIL audit closure (2026-08-30, same lane).** The PDR trophy is
engine-attributed, not harness-attributed — verified, not assumed:

1. **Assert set identical, byte-verified.**
   `diff <(git show b82cd19:formal/fabric.conservation.prove.sby)
   formal/fabric.conservation.pdr.sby` differs on exactly one line — the
   engine (`smtbmc boolector` → `abc pdr`). Mode, script, files, and the
   full harness `f_fabric_conservation.v` are byte-identical to b82cd19
   (which postdates cd55d03's ringport fix, so the RTL is the current
   tree too). Nothing was narrowed, assumed, or restructured for PDR.
2. **The asymmetry is the engine, re-demonstrated on today's tree:**
   re-ran b82cd19's exact prove run against HEAD — basecase PASS,
   induction UNCLOSED within a 25-min budget (descending unwind, step 32
   at kill), while abc pdr proved the same model unbounded in 25.9 s.
   Claim stands: PDR derives what k-induction cannot, on identical
   asserts.
3. **Citation discipline:** every doc carrying the conservation claim
   (FORMAL-PROOFS, formal/README, VERIFICATION) now records
   engine + mode (`mode prove` + `abc pdr`, 25.9 s, frame 9), with the
   explicit warning that a re-verifier running bare smtbmc prove will
   NOT reproduce it — that run fails, by design of the property, not by
   doc error.

## Whistle two-sided contract — first worked A-G instance (2026-09-03)

The TEACHER assume-guarantee naming doctrine (29d0b3c) called for a
worked example. Here it is, complete before the word spread:

**q_whistle (T3 byzantine tripwire) closes as a two-sided contract:**

- **Guarantee under the honest premise** (whistle.honest, mode prove,
  k-induction, UNBOUNDED): given the calibration premise
  `honest_rate <= d_base` (the assumed side), honest windows NEVER
  alarm — zero false positives, any stimulus timing ($anyseq i_can /
  i_tick / i_clr), any legal dial pair.
- **Guarantee under the attack premise** (whistle.attack, BMC-45):
  given sustained maximal lying (`i_can` every cycle) against regular
  windows, the alarm fires at the FIRST judged window within
  `2*d_win+8`, for every legal dial pair — exhaustive, not sampled:
  dials are `$anyconst` under assume-guards, so the solver quantifies
  universally over the entire legal space; the cover companion proves
  the dial set nonempty (no vacuity).

This is the A-G shape in miniature: environment assumptions stated as
formal premises (honest-rate bound / attack model), component
guarantees as proven properties, and the two arms bracket the behavior
completely — nothing outside (no-FP ∪ bounded-alarm) is left
unpriced. When G2 composition reuses the whistle as a leaf, THIS
contract is the interface: compose on the premises, inherit the
guarantees. Both .sby files + harnesses in formal/ (700380c).
