# SYNTHESIS-FPGA — quilt-verilog v1 meets metal

2026-08-29, FPGA synthesis lane. Tree: post-2881b29 (11/11 core TBs + 3
envelope TBs pass, 4 formal proofs pass; re-verified on this tree during
the lane — all PASS, `rtl/` untouched by synthesis). Toolchain:
oss-cad-suite — Yosys 0.47+22 (f20f913), nextpnr-ice40 0.7-131-g9c2d96f8,
icepack. No board attached; the goal was a full synth + PnR proof with
real utilization/timing numbers, bitstream-ready.

Everything here is reproducible from `synth/`:

```
yosys -s synth/fpga.ice40          # full-parameter 2-cell fabric -> the wall
yosys -s synth/fpga-converged.ice40  # formal-proof params -> converges
bash  synth/sweep.sh               # W-parameterization sweep -> sweep.tsv
nextpnr-ice40 --hx8k --package ct256 \
  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained \
  --asc synth/fabric2_k4b4a8e1.asc --report synth/report_k4b4a8e1.json
icepack synth/fabric2_k4b4a8e1.asc synth/fabric2_k4b4a8e1.bin
```

---

## 1. The target

`q_fabric_top` at **NCELL=2**: two full cells (core FSM + dialfile + edge
engine array + echo gate + RQH bank, both v2 features integrated in-core
and default-off) + the io node + three registered pipe slices on one ring
+ tick scheduler. This is the same node census and topology as the formal
conservation proof (`formal/f_fabric_conservation.v`: cells A,B, real
pipes, real engines, no engine-contract assumptions) — lifted onto the
production fabric module instead of the proof harness. No stubs: every
module is the `rtl/` one the TBs and proofs exercised.

Full fabric parameters: EDGES_N=4, K=8, B=8, AGEW=24, PW=16
(the `q_cell` defaults; PW is the flit contract, not a knob).

## 2. Headline: the full-parameter wall

Yosys `synth_ice40 -abc2` on the full-parameter 2-cell fabric:

| metric | count |
|---|---|
| SB_LUT4 | 10,257 |
| FFs (SB_DFF family) | 3,720 |
| SB_CARRY | 1,906 |
| BRAM | 0 (design is all-FF; see §6) |

nextpnr packs it to **12,448 ICESTORM_LC** (carry legalisation and
LUT/carry non-merge inflate raw LUT count by ~21%). The device ladder,
all attempted:

| device | LCs | utilization | outcome |
|---|---|---|---|
| LP384 (cm36) | 384 | 32× over | pack fail |
| HX1K (vq100) | 1,280 | 10× over | pack fail |
| UP5K (sg48) | 5,280 | 2.4× over | pack fail |
| HX8K (ct256) | 7,680 | **12,448/7,680 = 162%** | pack fail |

**Finding F1: the full-parameter 2-cell fabric fits no single iCE40.**
The largest member of the family is 34% too small. This is a resource
wall, not a timing wall — synthesis itself converges cleanly.

### Per-module attribution (standalone synth_ice40 -abc2, default params)

| module | LUT4 | FF | instances in 2-cell fabric | share of total LUT |
|---|---|---|---|---|
| **q_hebb_edge** | **695** | 180 | 8 (4 edges × 2 cells) | **~54%** |
| q_cell_core (incl. echo gate 178 + RQH bank 427) | 1,761 | 390 | 2 | ~34% |
| q_dialfile | 252 | 257 | 2 | ~5% |
| q_flit_pipe | 157 | 152 | 7 | ~11% |
| q_link_ringport | 85 | 0 | 2 | ~2% |
| q_tick_sched | 12 | 9 | 1 | <1% |
| q_uf_loader (boot lane, not in fabric) | 1,488 | 793 | 0 | — |

**Finding F2: the edge engine array dominates.** One `q_hebb_edge` costs
695 LUT4 standalone; eight of them is 5,560 LUTs — over half the design.
Where it goes (in order): the two 32-bit barrel shifters of the hyperbola
interval path (`p0 = 32'd1 << i_p0e` then `p0 >> 2·msb(W)`, ~160 LUTs
each) plus the 32-bit `agen >= ival` compare; the ladder readout shifter
(`c[ridx] << (K-ridx)`, 17-bit barrel); the msb16 priority encoder; the
saturating adders. The task's prediction — "32-bit weights and
ln-strengths are the likely cost centers" — lands *near* but not *on*:
the weight `wh` itself is 16-bit and the echo-gate ln-strength machinery
is cheap (178 LUTs). The real 32-bit cost is the **P0-interval expansion**:
`i_p0e` is 5 bits, but the interval arithmetic is done at 32-bit width per
engine, per edge, whether or not hyperbola mode is ever dialed on (MODE
is a *runtime* dial, so the compiler must build both engines).

## 3. W-parameterization sweep (`synth/sweep.tsv`, NCELL=2 fixed)

| config | K | B | AGEW | E | LUT4 | FF | CARRY | ΔLUT vs full |
|---|---|---|---|---|---|---|---|---|
| full | 8 | 8 | 24 | 4 | 10,273 | 3,720 | 1,906 | — |
| e2 | 8 | 8 | 24 | 2 | 7,658 | 2,910 | 1,277 | −2,615 |
| e2k4 | 4 | 8 | 24 | 2 | 6,846 | 2,702 | 1,179 | −3,427 |
| k4 | 4 | 8 | 24 | 4 | 8,728 | 3,304 | 1,756 | −1,545 |
| k4a12 | 4 | 8 | 12 | 4 | 8,541 | 3,208 | 1,660 | −1,732 |
| k4b4a12e2 | 4 | 4 | 12 | 2 | 6,643 | 2,590 | 1,115 | −3,630 |
| **k4b4a8e1** | **4** | **4** | **8** | **1** | **5,800** | **2,336** | **856** | **−4,473** |
| k8a12 | 8 | 8 | 12 | 4 | 10,122 | 3,624 | 1,810 | −151 |
| n4k4e2 (NCELL=4) | 4 | 8 | 24 | 2 | 13,488 | 5,242 | 2,435 | +3,215 |

Marginal costs, measured:

- **Edge count E is the big lever**: −654 LUTs per engine removed (e2 vs
  full), exactly the standalone engine cost. Engine area is linear in E.
- **K 8→4**: −193 LUTs per engine (k4 vs full). Sublinear — bucket FFs
  shrink linearly but the readout shifter/accumulator only narrows.
- **AGEW 24→12**: −187 LUTs total (k8a12 vs full), ~23 LUTs/engine.
  Nearly free. Age-counter width is *not* where the 32-bit compare pays;
  the compare is against the P0 expansion, which does not shrink with
  AGEW. Trimming AGEW buys simulation-state fidelity, not silicon.
- **B 8→4**: ~200 LUTs total. Cheap.
- **Per-cell marginal cost** (n4k4e2 − e2k4)/2 = **3,321 LUT4 + 1,270 FF
  per cell** at k4/e2 — the fabric scales ~linearly per cell; there is no
  shared-resource cliff in this topology.

## 4. The convergence point — formal-proof parameters, bitstream-ready

The lean-but-honest config `k4b4a8e1` (K=4, B=4, AGEW=8, EDGES_N=1) is
**exactly the parameter set the formal conservation proof runs under**,
lifted from the proof harness onto the real fabric top. On
**iCE40HX8K-CT256**:

| metric | value |
|---|---|
| ICESTORM_LC | **7,400 / 7,680 (96%)** |
| SB_IO | 157 / 256 (61%) — 157 fabric port bits, auto-placed (no PCF) |
| SB_GB | 8 / 8 (clk, rst_n, cen/reset fanouts) |
| BRAM / PLL | 0 / 0 |
| **fmax (post-route)** | **27.72 MHz** (12 MHz target: PASS; placement-time estimate 29.14 MHz) |
| critical path | 36.08 ns = 12.63 ns logic + 23.45 ns routing |
| bitstream | `synth/fabric2_k4b4a8e1.bin`, 135,100 bytes (icepack from .asc) |

Placement (HeAP + SA) and routing converge cleanly at 96% — a full
synth → place → route → bitstream proof with no hardware attached. The
one-step-richer ladder point `k4b4a8e2` (6,568 LUT4 raw) packs to
8,361/7,680 = **108%** and fails placement — the documented near-miss;
the next device up in the family doesn't exist, so trimming to e1 is the
honest iCE40 ceiling for a 2-cell fabric.

## 5. Timing anatomy — what actually limits fmax

The post-route critical path is *not* in the engines and *not* on the
ring:

```
eg_tick FF (tick service)
  → q_echo_gate leak/live logic (f >> KLE, floor compare, msb)
  → q_rqh_bank rq_train deposit arithmetic (q_cell_core.v:193)
  → 16-bit activation integrator + saturator (q_cell_core.v:183, :198)
  → act[14] FF
```

The whole per-tick learning pipeline — echo-gate leak decision, RQH
deposit, activation integration — is **one combinational stage** between
two FFs, 138 path elements. The registered pipe slices did their job:
the longest ring path (io o_val→o_rdy async chain) is 3.74 ns, nowhere
near the clock path.

**Finding F3: the v2 in-core learning chain is the timing wall.** If a
future build needs the full 27 MHz+ margin or a bigger fabric at speed,
the fix is pipelining ST_TICK into (leak+deposit) / (integrate) substates
— the core FSM is already a cooperative run-to-completion machine, so a
two-phase tick costs zero throughput semantics and roughly doubles fmax.
The engines sit behind registered hb_cmd/hb_done handshakes and never
appear on any critical path at any parameterization tried.

## 6. BRAM: what was measured, what it means

Utilization is 0 BRAM everywhere — by construction, not by accident. The
design's memories are small and register-file-shaped: dialfile 16×16b,
etab 4×4b, RQH R[4]×16b, engine buckets K×B=32..64b per edge. Ice40
SB_RAM40_4K blocks are 4096-bit; mapping a 256-bit register file into one
wastes 94% of the block and *adds* the async-read mux cost. At the
current scale FFs are the right substrate. The crossover is visible,
though: at E=4/K=8 the engine bucket array alone is 512 FFs per cell
(8 engines × 64b) — at E=16 per cell (4Kb) the buckets flip to exactly
one BRAM column per cell, and `dials as BRAM` (one 4Kb block holds the
full 16×16 dial image of *256* cells) becomes the obviously correct
mapping. That crossover math, and the boot-time write port it implies, is
spec'd in docs/FPGA-BOOT.md §4.

## 7. Findings register + next seams

- **F1 (wall):** full-param 2-cell = 12,448 LC > every iCE40. Options,
  in preference order: (a) accept trimmed engines on HX8K (this doc's
  converged build — the formal proofs already bless exactly these
  parameters); (b) ECP5-12k/25k class for full params (nextpnr-ecp5
  exists in this oss-cad-suite; one-command re-run is future work);
  (c) two-chip split at the ring (v1's single-ring topology cuts at any
  pipe slice — the flit contract is the seam).
- **F2 (dominator):** engine array, 54% of LUTs, linear in E. The
  32-bit P0-interval expansion is the per-engine hotspot; a
  `P0W`-parameterized interval width (p0e is 5 bits, but compare width
  can be 2·PW+1 = 33 → genuinely needs 32... the trim is to compute the
  compare as `age >= (1 << (p0e − 2·msb))` with the shift *after* the
  subtract, still 32-bit) — honest note: the arithmetic wants 32 bits;
  the cheap trims are E and K, which the sweep quantifies.
- **F3 (timing):** tick-path learning chain, §5. Pipelining is the fix,
  not warranted at 12 MHz (2.3× slack even post-route).
- **F4 (pins):** the fabric exposes 157 port bits (21 ports). CT256 has
  the pins; a real board bring-up wants a PCF (the auto-placed bitstream
  is not pin-stable across seeds) and probably a serialized host port —
  which the boot lane (docs/FPGA-BOOT.md) is the natural place to own.
- **F5 (boot lane budget):** `q_uf_loader` is 1,488 LUT4 / 793 FF
  standalone. The converged fabric is 96% full, so loader + fabric does
  not fit one HX8K (7,400 + ~1,400 > 7,680 even with cross-boundary
  optimization). Boot-on-ice40 therefore rides either the trimmed
  e1-with-loader build, a soft core outside the fabric, or the ECP5
  lane. Numbers in docs/FPGA-BOOT.md §8.

**Dominant cost center, one line:** the per-edge hyperbola/ladder engine
array — 695 LUT4 per edge, linear in EDGES_N, 54% of the design; timing
is dominated instead by the in-core tick-service learning chain
(echo gate → RQH deposit → activation integrate), 27.72 MHz on HX8K.

---

# Round 3 (2026-08-29, same day, evening): break the wall, build the boot

Three pushes on the post-117b649 tree: pipeline the learning chain, scale
the fabric across the device ladder, and build the boot lane's first RTL.
Toolchain unchanged (oss-cad-suite: yosys 0.47+22, nextpnr-ice40,
nextpnr-ecp5). All numbers below re-measured on this tree.

## 8. PIPE_EFF: the learning-chain retime (F3 executed)

**Where the cut landed, and why not in q_hebb_edge.** §5's critical path
was `eg_tick FF → q_echo_gate leak/live → q_rqh_bank deposit arithmetic →
q_cell_core.v:193 carry chain (w_rq = hb_w + rq_credit) → 16x16 multiply
→ saturating act accumulate → act FF`. Every stage of that cone lives in
q_cell_core and sits *after* the engine's registered outputs (the engines
are behind hb_cmd/hb_done handshakes and never appeared on any critical
path — §5 already said so). A registered stage inside q_hebb_edge or a
q_hebb_edge_pipe wrapper would add flip-flops without shortening a single
reported path. The honest cut is in the core, and that is where it went:

- `q_cell_core` gains parameter `PIPE_EFF` (default 1) and two states:
  - **ST_EFFP**: on readback `hb_done`, register `eff_w <= hb_wq` — the
    RQH credit add (`sat(w + credit)`, the deposit-cone carry chain) gets
    its own register-to-register stage;
  - **ST_EFFM**: register `eff_p <= eff_w * lr_dat` — the 16x16 multiply
    alone on one stage;
  - **ST_EFFI**: `act <= sclip(act + (eff_p >>> 15))` — the saturating
    accumulate closes.
  `PIPE_EFF=0` keeps the original single-cycle cone bit-for-bit (the
  differential reference). Cost: +2 clk per effect op (ops stay bounded;
  ticks still serviced at IDLE boundaries — Q2 untouched), +151 LUT4
  (5,800 → 5,951), 2 pipeline registers.

**Semantics proof (tb/tb_hebb_pipe.v).** Differential TB: one shared
stimulus session (300 ops: binds, links, effects, views, mid-session dial
rewrites, ticks every 3 ops) drives TWO q_cell_core instances —
PIPE_EFF=0 (original cone) and PIPE_EFF=1 (retime) — each with its own
dialfile and engine array, v2 pair FULLY DIALED ON (FLOOR=0x0100, RQEN=1,
QDW=4, QLEAK=3) so the retimed cone is the exercised one. PASS: the
ordered stream of every output flit (224 lo + 18 lx) and `act`/`o_ftrace`
are bit-exact at every checkpoint. The retime is value-preserving; only
cycle counts move (+2 per effect).

**Measured result (k4b4a8e1, HX8K-CT256, `synth/pnr_r3.log`):**

| metric | round 2 | round 3 (PIPE_EFF=1) |
|---|---|---|
| LUT4 (yosys) | 5,800 | 5,951 |
| ICESTORM_LC | 7,400 (96%) | 7,528 (98%) |
| **fmax post-route** | **27.72 MHz** | **40.44 MHz (+46%)** |
| critical path | core learning chain (36.08 ns) | engine hyperbola interval (`wh → msb → ival → age compare → age FF`) |

The wall moved exactly where §5 predicted it would: with the core
integration cone cut into three stages, the new limiter is the engine's
own hyperbola decay compare — the F2 cost center, now the timing center
too. 12 MHz target passes with 3.4x slack.

**Bug found and fixed on the way (rtl/q_hebb_edge.v).** At K=4/B=4 (the
formal-proof params) the module did not simulate: `acc[AW-1:PW]` is an
out-of-order part select when AW=9 < PW=16, and the reset list touched
`c[4..7]` beyond a 4-deep bucket array. Synthesis tolerated both; strict
simulators (iverilog) reject the elaboration. Fixed with a generate split
(`g_lad_sat`/`g_lad_wide`) and a K-parameterized reset loop. K=8 behavior
is unchanged (all default-param TBs unchanged-PASS).

## 9. Scale: NCELL across the device ladder (k4b4a8e1, PIPE_EFF=1)

`synth/scale.sh` + `synth/rebuild_scale_tsv.py` → `synth/scale.tsv`.
12 MHz closure target throughout.

- **iCE40 UP5K (sg48):** logic fits 1 cell (3,958/5,280 LC = 74%) but the
  fabric's 157 port bits need 163% of sg48's 96 IO — every NCELL fails
  IO placement before logic. UP5K is **pin-bound, not LUT-bound** for this
  fabric-as-wired; the serialized host port (F4) is the unlock. 2 cells
  (7,528 LC) also exceeds the 5,280 LC budget — so even pin-fixed, UP5K
  is a 1-cell device at honest engine params.
- **ECP5 LFE5U-12F:** 2 cells = 5,886 COMB (49% of the physical 12,144
  LUTs), 4 cells = 11,554 (95%) — **4 cells close timing on a real 12F**
  at ~63 MHz. 6 cells (17,245) exceeds the physical 12F even though
  nextpnr places it (the 12F is a binned 25F die; nextpnr reports against
  24,288 — see the util12f column).
- **ECP5 LFE5U-25F (the boat chip):** 8 cells = 18,299 LUT4 → 22,791/
  24,288 COMB (94%), fmax 63.7 MHz — **8 cells close timing with 6%
  area slack**; 12 cells (~34,080) is 140% and fails placement. Per-cell
  marginal cost at k4b4a8e1: ~2,830 LUT4 / ~2,850 COMB (linear, no
  shared-resource cliff — consistent with round 2's HX8K measurement).
  Bonus the ECP5 lane picks up for free: the PIPE_EFF effect multiplier
  maps to 4 MULT18X18D DSP blocks (2 per cell) on every config — on
  ECP5 the retime also *removes* LUT-fabric multiply pressure.
  (25F shares the 12F die, so 25F n2 is the 12F n2 row: 5,886 COMB,
  66.2 MHz.)

Max cells closing 12 MHz at k4b4a8e1, per device: **UP5K: 1 (IO-gated),
HX8K: 2, LFE5U-12F: 4, LFE5U-25F: 8.** fmax headroom everywhere is
40-66 MHz — 12 MHz is conservative by 3-5x on every closing config.

## 10. Boot: rtl/quf_boot.v (docs/FPGA-BOOT.md §2, built)

The boot FSM is RTL now: POR → HOLD → LOAD → LATCH → RELEASE → RUN with
sticky HOLD_ERR, wrapping the proven q_uf_loader:

- **byte-stream ingress** `i_bval/i_byte/o_brdy/i_eod` with a local-only
  ready and a 1-word skid (the loader's 1-in-3 backpressure never forms a
  ready chain); align-padding residue after `o_done` is accepted and
  discarded (the same end-of-stream rule quf_tb always had);
- **header validation** is the loader's (codes 1-9); the FSM adds
  **E_TRUNC=10**: `i_eod` before done parks sticky in HOLD_ERR;
- **fail-static-to-v1-defaults**: the fabric reset (`o_rst_n`) is held
  forever on any error — the fabric is never booted into a half-image;
  the dialfile is POR-reset-only (not o_rst_n) precisely so boot writes
  stick while cores are frozen AND a POR retry re-defaults;
- **dial-port mutual exclusion with qm_bind by construction**: the boot
  port strobes only in LOAD/LATCH (cores provably cannot emit a bind in
  reset), the qm port only in RUN — disjoint FSM states, no arbitration;
- **epoch latch**: `o_tpw` latches ONCE at LATCH from the loader's ticks
  section and is frozen for the run (latch-once-at-release; Q2's deadline
  semantics stay defined against a stable epoch); `o_epoch` pulses at
  release.

**tb/tb_quf_boot.v — 4 acceptance cases, all PASS (iverilog):**
1. warm-start: 576-byte golden QUF boots; dial row byte-exact
   (dial5=0x5000, hl=0x30), tpw=6 latched, fabric released exactly in
   RUN, qm port live after release (write+readback), a qm write DURING
   LOAD refused;
2. corrupt magic → err 1 → sticky HOLD_ERR, fabric held, dialfile at POR
   defaults (0x6000), no boot_ok/epoch, qm port dead;
3. mid-file truncation + eod → E_TRUNC → HOLD_ERR, fabric never
   released, qm dead;
4. post-release transport noise (bytes + eod) changes nothing: RUN
   holds, tpw frozen, dials unmoved.

Both new TBs and the retimed core are verilator -Wall lint-clean
(style-suppressed); authoritative simulation is iverilog -g2005 — this
oss-cad-suite's verilator (5.029-devel) shows --timing scheduling
artifacts on TB-side pulse sampling (RTL unchanged, trace-enabled builds
pass), so the lane runs verilator as lint and iverilog as sim.

**Suite: 17/17 PASS** (`tb/run_suite.sh`, new) — 14 core/envelope TBs +
quf_tb + tb_hebb_pipe + tb_quf_boot, on the retimed tree.
