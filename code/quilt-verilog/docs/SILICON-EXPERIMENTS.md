# SILICON-EXPERIMENTS — measured synthesis + simulation at scale (2026-08-30)

The red team's sharpest hit was "verified once, by hand, at toy scale."
This lane answers with numbers measured in one session on the local box
(RTX 4050 host, WSL2). Every number below was produced by the quoted
commands THIS session; logs live in `synth/*silicon*` (regenerable,
gitignored) and `sim/vlt/scale-run.log` (committed evidence).
Toolchain: yosys 0.47+22, nextpnr-ice40 0.7-131, verilator 5.029
(oss-cad-suite), iverilog 13.0 (dev). iverilog is the functional lane;
verilator is the scale lane.

**Provenance (multi-lane tree, see docs/INCIDENTS.md):** this lane was
mid-debug when an adjudication lane snapshotted it as WIP 9300092 / a
referee bench-committed an earlier partial state as 0eb231b and wrote
this file's first version. The lane did not die; it completed. §0 below
preserves the referee's adjudications verbatim-in-substance; §1-5 are
the FINAL verified results and supersede the referee's interim numbers
(its "UP5K 98.9% fit" was the NCELL=2 HX8K run mislabeled — 7,680 LC is
HX8K capacity; see §1 for the true sg48 picture). Final bench re-run
twice from cold after tree reconciliation: identical PASS both times.

## 0. Adjudications (devil-nudge lane, preserved)

**XFER_TIMEOUT storms — ADJUDICATED: bench artifact over a real event.**
The ~4,096-cycle periodicity was the bench's own xfer timeout constant;
underneath it a REAL fabric-wide ring deadlock at cyc≈34.5k (cell 3
state=13, full inbuf, ring heads dst=3/dst=f, counters frozen). The
lane subsequently root-caused that deadlock into TWO RTL bugs (fixed,
§3 F1/F2) plus one architectural limit (§3 F3) — the adjudication's
"next lane's job" is done and documented below.
**P4 HASH-SENSE — ADJUDICATED: vacuous corpse-hashing.** The old hash
compared three identically-dead states. The final bench hashes live
egress streams instead (§3 determinism) and carries a liveness guard.

## 1. SYNTH — the canonical core vs the smallest UP5K (sg48)

Config: the Makefile `synth` target's PnR-converged top — `q_fabric_top`,
engine params K=4 B=4 AGEW=8, NCELL=2, EDGES_N=1, PIPE_EFF=1 (the exact
parameters of the committed HX8K bitstream and the conservation proof).

```
yosys -s synth/fpga-converged.ice40          # 6002 SB_LUT4, 2434 FF
nextpnr-ice40 --up5k --package sg48 \
  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained
```

**Result: FIT-FAIL, twice over.** ICESTORM_LC 7596/5280 (**143%**) and
SB_IO 157/96 (**163%**); placement dies with "no BELs remaining
(ICESTORM_LC)" (synth/pnr_silicon_up5k_k4b4a8e1.log). The headline:
*the canonical parallel fabric does not fit the smallest UP5K package on
either axis* — logic AND pins. BRAM: 0 SB_RAM40 anywhere in the design
(dialfiles/engine state map to FFs+LUTRAM; state pays area, not memory).
For the record the same netlist on HX8K-CT256 closes at ~98% LC,
~40-44 MHz (synth/report_k4b4a8e1.json, prior rounds).

The smallest thing that DOES close on sg48 — the serialized front-end
(`q_serfabric_top`, SER_BOOT_QUF=0, NCELL=1, same engine params):

```
yosys -p "read_verilog <fabric rtl + serdes>; chparam -set K 4 -set B 4 \
  -set AGEW 8 q_cell; hierarchy -check -top q_serfabric_top \
  -chparam NCELL 1 -chparam EDGES_N 1 -chparam SER_BOOT_QUF 0; \
  synth_ice40 -top q_serfabric_top -abc2 -json synth/silicon_up5k_serf_n1.json"
nextpnr-ice40 --up5k --package sg48 --json synth/silicon_up5k_serf_n1.json \
  --freq 12 --timing-allow-fail --pcf-allow-unconstrained --asc ... --report ...
```

**3221 LUT4 / 1479 FF / 4232/5280 LC (80.2%) / 37 IO / fmax 16.78 MHz**
(PASS at the 12 MHz target; bitstream packed). One cell + narrow port is
the honest sg48 ceiling today. Full table: `make synth-report` →
`synth/silicon.tsv` (synth/silicon.sh, ~4 min). NOTE: the simulation
fabric below is 15 cells — no iCE40 device in the drawer holds it
(15 cells ≈ 45k LUT4 est., ECP5 25F territory per synth/scale.tsv).

## 2. SCALE SIM — a million cycles on the largest legal fabric

(Numbers below are the PRE-F3-fix run, kept as the wedged-state
evidence; the post-fix re-run (§3.2) shows 497,608 P1 injections, clean
quiesce, same 0-violation ledger, total 1,852,899 cycles — the ~1M-cycle
difference is the quiesce no longer burning its wait budget on a dead
fabric.)

Largest legal = what the parameters admit: AIDW=4 caps ids at 0..15 and
EXTID=0xF owns one, so **NCELL=15**; EIW=2 (q_cell default, not exposed
by the top) caps **EDGES_N=4**; engines at q_cell defaults **K=8, B=8,
AGEW=24** (the widest config in the tree — wider than the bitstream's).

```
verilator --cc --build --exe -j 4 --top-module q_fabric_top \
  -GNCELL=15 -GEDGES_N=4 --public-flat-rw -Mdir sim/vlt/obj_scale \
  -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM \
  <11 fabric rtl files> sim/vlt/tb_scale_vlt.cpp     # or: make sim-scale
```

Phase P1: **1,000,000 cycles, ~10% effect rate** (5,814 of 58,080
injected flits; host windows ≤12 outstanding views):

- wall **11.0 s** (0.09 Mcyc/s sim rate, includes always-on per-cycle
  ledger/trace instrumentation — the bench IS its own checker)
- **58,431 ops accepted** at cell cores (5,866 effects, 52,275 views);
  4,042 ticks × 15 cells = 60,630 decay sweeps; 52,560 core emissions
  (55 fires); 52,393 flits drained at the io port
- **cell-ops = 171,621 → 15,574 cell-ops/sec** (accepts + tick sweeps +
  emissions — the fabric's own service throughput under mixed load)
- **conservation: 0 violations in 2,852,899 total cycles.** The LEDGER
  checker is the runtime form of the formal A1/T1 ledger
  (formal/f_fabric_conservation.v): cum(io_injected + core_emitted) −
  cum(core_accepted + io_drained) == pipes occupied, checked every 256
  cycles and exactly zero at every clean quiesce — it held through every
  phase INCLUDING the wedged states of §3 F3.

## 3. STRESS FINDINGS — three RTL/fabric bugs, all fixed (F3: §3.2)

**F1 commissioning wedge (RTL, FIXED — q_cell_core ST_RESP).** Any
non-bind flit delivered to an unbound cell (e.g. a link ACK from a peer
commissioned earlier) kicked it ST_UNB → ST_RESP → ST_IDLE with bound=0,
after which every bind executed as a dial write AND ACKED SUCCESS —
silent misconfiguration; the cell NAKs views forever. Found at scale
(cells 1-14 all `bound=0` after a fully-acked setup), reproduced
minimal on iverilog AND verilator (tb/tb_wedge_repro.v, now in the TB
suite). Fix: return to ST_UNB while unbound. Suite 19/19.

**F2 ringport flit cloning (RTL, FIXED — q_link_ringport transit).** A
HIT flit blocked by a full ingress buffer satisfied `transit` while
`ri_ready` held the original in the upstream slice: the ringport PUSHED
A COPY downstream every stalled cycle. Measured by the bench's
ENTRY-IDENTITY trap (per-pipe push/pop witnesses): ring(push−pop)=2
with io_li+cell_li=1 — one phantom entry per stall cycle; the ring
filled with clones and the ledger broke by exactly the clone count.
This is the mechanism under the referee's adjudicated "net≠occ"
sub-issue #1a — resolved: neither undercount nor invisible pipes; the
fabric was manufacturing flits. Fix: `transit = ri_valid && !hit` (hold
at the slice head, per the unit-TB contract "stalls ring, no ro
progress"). Suite 19/19.

**F3 saturation deadlock (ARCHITECTURAL → FIXED 2026-08-30, §3.2).**
No end-to-end flow control. Mixed traffic with effects — whose fire
fanout is fabric-internal traffic no host window can throttle —
eventually wedged the ring in a cyclic wait (egbuf→ring→inbuf→core→
egbuf across cells). Measured on the pre-fix RTL: P1's drain left 11
flits permanently stuck (occ=11, ledger intact, QUIESCE-DEADLOCK line
in the pre-fix scale-run.log); view latency exceeded 8192 cycles 10
times (ACKLAT-TRIP lines) before that; earlier fire-prone
configurations froze mid-run at occ=23-26. Conservation survived;
liveness did not. Fixed by the ringport escape lane (§3.2) — this
block preserves the pre-fix record.

**Reset mid-pipeline (PASS).** 15 flits held in pipes (egress drain
gated off), rst_n asserted 16 cycles under load: post-release residue
0, ledger rebased clean, full re-commissioning + 50k-cycle recovery
pass CLEAN (errors +0).

**Determinism (PASS).** Same-seed full runs (reset → commission → 100k
traffic) reproduce the egress stream bit-exactly: FNV-1a-64 over the
ordered (op,dst,dat) of all drained flits = 2126a3c74072d7ff twice
(49,968 flits each); different seed → 2b25401359ce0215. This replaces
the task's suggested QUF round-trip variant honestly: v1 has no RTL
unload sink (q_serfabric_top header), so replay-hash is the equivalent
at this scale.

## 3.1 Rescue-lane amendment (2026-08-30, independent verification)

A rescue lane re-verified the aborted WIP (`9300092`) from scratch,
blind to this file's final version (which landed mid-verification as
`07e04b9`). Results — independent confirmation plus three additions:

**Verification (all re-measured).** Suite 19/19; tb_wedge_repro PASS;
formal conservation + flit_pipe.fly PASS on the fixed RTL; full scale
run reproduces the final bench bit-for-bit in the invariants that
matter: 2,852,899 cycles, errors=0, acklat_trips=10, P0 ledger OK /
SETUP_WSUM 0, P1 counters identical (inj=58,080 drain=52,393
accept=58,431 emit=52,560 fires=55), P3 clean, P4 stream hashes
A=A'=2126a3c74072d7ff ≠ B=2b25401359ce0215.

**Causal decomposition of the XFER_TIMEOUT family (new measurement).**
Four cells built from exact master/WIP sources by the rescue lane:

| RTL | bench | result |
|-----|-------|--------|
| master | master (0eb231b run) | 6,940 errors; freeze cyc≈34.5k |
| master | rescue | ENTRY-IDENTITY BREAK @cyc=34586; 6,284 errors; LEDGER FAIL @34816, occ=42, **all 16 ring slices presenting the same dst=a** — F2's clone captured at birth |
| fixed | master | **0 XFER_TIMEOUT**; 5 residual errors (1 F3-quiesce + 4 old-P4 vacuity) |
| fixed | rescue | errors=0, BENCH PASS |

F2 (the clone) eliminates the entire XFER_TIMEOUT family (~6.9k of
6,940); the bench hardening accounts for the remaining ~650. The
aborted lane's interim "6,873 persists" was a property of the
half-hardened bench, not of the fixed RTL.

**F3 root cause sharpened: the cycle closes within ONE cell.** Minimal
repro committed: `sim/vlt/tb_quiesce_repro.cpp` (`make
sim-quiesce-repro`, deterministic seed 0xC0FFEE, ~15 s). 120k windowed
mixed-traffic cycles → quiesce → **occ=14 frozen through 500k cycles**;
100k cycles drains clean in 21 (the wedge forms in the 100k–120k window
of this trajectory). Stuck anatomy: cell 13 `ST_FIRE`
(rtl/q_cell_core.v, state 5'd18) holds `ci_ready=0` while emitting, so
its inbuf fills; the flit addressed to cell 13 parks at the ring head
of its OWN port (`ld_ready=0`); that blocked hit forces `inject_ok=0`,
so the cell's own fire flits cannot enter the ring
(rtl/q_link_ringport.v: `li_ready = inject_ok && ro_ready`); and the
io-bound flits queued behind the parked delivery cannot overtake
(single in-order ring, no escape lane). Self-deadlock — no second cell
required, which makes the fix direction concrete: pop the inbuf during
ST_FIRE, or give EXTID-bound flits an escape lane, or credit-gate fire
fanout.

**Formal coverage gap named.** `formal/fabric.conservation*` proves a
2-cell `q_flit_pipe` path — it does not instantiate `q_link_ringport`,
so F2's clone lived in the one fabric module formal never covered. Unit
cover is `tb/tb_link_ringport.v` (sim only). A ringport conservation/
liveness proof would have caught F2 pre-silicon; booked as formal
backlog.

**Comment correction.** The bench's "fire_prone=false: cells CANNOT
fire" comment was wrong in fact (fires are rare, not impossible — 55
measured in P1; F3's wedge is a fire wedge). Corrected in the rescue
commit.

## 3.2 F3 fix — ringport injection escape lane (2026-08-30, this lane)

**Mechanism (chosen from the §3.1 booked directions by measured cost).**
The three booked candidates: (1) credits on inject, (2) admission
control, (3) the escape lane / inbuf-pop variants. Credits need
per-destination counters and a protocol at every node (the doc's own
"design work" pricing); popping the inbuf during ST_FIRE just moves the
full condition into a core-internal skid of unbounded-filling depth and
does not close the loop. The escape lane is one line of combinational
logic in ONE module: `inject_ok = !ri_valid || hit` (was `!ri_valid ||
consumed`). Rationale: a hit flit NEVER claims the ring output (its
exit is ld/delivery), so the old gate blocked injection behind a parked
delivery for no structural reason — the blocked hit simply waits in the
upstream slice (ri_ready=0, no clone: the F2 clone was transit claiming
ro; an accepted injection pops its own li, so push/pop stays paired).
This severs exactly the measured single-cell cycle: ST_FIRE can now
inject past its own parked delivery, completes, reasserts ci_ready,
drains the inbuf, and the parked hit delivers. Overtaking is limited to
a node's injections passing flits addressed to that node; ring order
among transit flits is unchanged (no delivered-order contract existed
between a node's outflow and its own inflow — ops are independent and
ack-correlated by a2).

**Verified (all re-measured this lane, fixed RTL):**
- minimal repro `make sim-quiesce-repro` (seed 0xC0FFEE): pre-fix on
  HEAD f7027c4 re-confirmed freshly — cell 13 state=18 (ST_FIRE),
  in=11 eg=11, occ=14 frozen through 500k cycles, ledger intact,
  exit 1. Post-fix: **drains to occ=0 in 21 cycles**, exit 0, output
  bit-identical across two re-runs. Unit guard added: tb_link_ringport
  cases 8-9 (escape + no-clone + delivery-after-overtake); suite 19/19.
- `make sim-scale` (1M-cycle P1 + P2 storm + P3 reset + P4 hash):
  **errors=0, 0 conservation violations** (ledger exactly zero at the
  now-completing P1 quiesce, which is a HARD bench error on wedge —
  upgraded from the booked expect-deadlock canary). No QUIESCE-DEADLOCK
  line. Two runs identical modulo wall-clock lines. New committed
  evidence: sim/vlt/scale-run.log (post-fix; supersedes the pre-fix
  counters quoted in §2 — inj 497,608 vs 58,080 per P1, see below).
- P2 fire storm (100% effects, unbounded, fire-prone dials): pre-fix
  froze-or-fire-starved (46 fires); post-fix **15,600 fires, 200k
  cycles, no freeze** — the storm is now the heaviest exercise of the
  escape path, not a liveness death.
- P4 determinism: stream hashes unchanged vs the pre-fix run
  (A=A'=2126a3c74072d7ff, B=2b25401359ce0215) — consistent: the P4
  window never wedged pre-fix, and the escape path changes ordering
  only where a delivery was parked, so P4's clean-trajectory stream is
  untouched (also a useful cross-check that the fix does not perturb
  non-wedged traffic).

**Throughput side-effect (measured, not designed for):** P1
mixed-traffic throughput rose 58,080 → 497,608 injections/M-cycles
(8.6x) — the pre-fix fabric spent most of P1 half-wedged (acks stuck
behind parked hits throttled every host window; ACKLAT-TRIPs 10 → 48
absolute, but per-injection trip rate fell ~172 to ~96 per M injected).
Liveness, not throughput, was the fix's contract; the throughput number
is a measured consequence.

**Cost (measured at synthesis; PnR/fmax NOT re-run):** canonical NCELL=2
flow (`yosys -s synth/fpga-converged.ice40`), pre-fix committed stat vs
fresh post-fix run: SB_LUT4 5997 → 5992 (−5), SB_CARRY 898 → 878 (−20),
FF 2434 → 2434 (±0). The fix is slightly CHEAPER than the broken logic
(`inject_ok` lost a term). Timing estimate (not measured): no new arc;
the ld_ready → li_ready arc is removed — neutral-to-better fmax
expected. Labeled: LUT/FF = measured at yosys-stat level; fmax =
estimate.

**Not claimed:** end-to-end guaranteed drain under an adversarial host
that never drains EXTID (the io port's ld can still park — that is the
external contract, documented in q_io_port); a formal ringport
liveness proof (still backlog, §3.1 formal-coverage note — the unit
cover + scale storm are the guards today).

## 4. Incident note

Mid-session, an adjudication lane snapshotted this lane's in-flight
bench (9300092), a referee bench-committed an earlier partial state and
wrote this file's first version (0eb231b), and a rescue lane stashed
the lane's trace-gating edits; one rebuild from the mid-revert tree
produced a spurious failing run. After reconciliation the final bench
was re-run twice from cold: identical PASS (2,852,899 cycles, errors=0,
acklat_trips=10). Full story: docs/INCIDENTS.md.

## 5. Re-run everything

```
make test          # 19/19 iverilog TBs (wedge repro is a permanent guard)
make sim           # 34/34 python QUF lane
make synth-report  # E1: fresh sg48 numbers -> synth/silicon.tsv (~4 min)
make sim-scale     # E2+E3: build + run the scale bench (~2 min + build)
```
