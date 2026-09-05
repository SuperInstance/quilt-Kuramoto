# SYNTHESIS-RESULTS — every measured number, one table, full provenance

The consolidated record of what the quilt costs on real FPGA silicon:
devices, logic cells, IO, fmax against the 12 MHz target, bitstream size,
and the date each number was measured. Companion to `docs/SYNTHESIS-FPGA.md`
(the narrative of the synthesis lanes) and `docs/VERIFICATION.md` lane 4
(how to run the flow). Undersold by policy: **every number below was
either measured by the pass named in its *source* column or is committed
in the artifact named there.** Nothing on this page is an estimate quoted
as a measurement; where nextpnr's post-placement estimate differs from
the routed result, both are shown and the routed number is the headline.

Toolchain: oss-cad-suite — yosys 0.47+22, nextpnr-ice40 0.7-131,
nextpnr-ecp5, icepack. Target frequency 12 MHz on every run
(`--freq 12 --timing-allow-fail`); no PCF exists, IO is auto-placed
(`--pcf-allow-unconstrained`) — a real pin constraint file could move
fmax in either direction. **Nothing here is tested on hardware**; every
row is synth → place → route → (where noted) bitstream-pack, with no
board attached.

## How to read the columns

- **LUT4 / CARRY**: yosys post-synth cell counts (deterministic — same
  tree, same counts: 6,002/898 reproduced identically across three
  independent passes on this tree).
- **LC / cap**: nextpnr packed logic cells over device capacity.
- **fmax**: nextpnr critical-path frequency, **post-route** unless a row
  says otherwise. The target is 12 MHz; PASS means the routed design
  closes at or above it.
- **date / source**: when the number was measured and where it lives
  (tracked artifact at `synth/…`, or commit message / doc where the
  artifact is regenerable-but-not-tracked).

---

## Table 1 — the converged build: `q_fabric_top`, k4b4a8e1 (NCELL=2, EDGES_N=1, K=4, B=4, AGEW=8 — the formal conservation proof's exact parameters), iCE40 HX8K-CT256

| run (pass) | LUT4 | CARRY | FF-class | LC used / 7,680 | IO used / 256 | fmax post-route @ 12 MHz | bitstream | date | source |
|---|---|---|---|---|---|---|---|---|---|
| round 2 (fpga-metal) | 5,800 | — | — | 7,400 (96%) | 157 | **27.72 MHz** PASS | 135,100 B (tracked, this era) | 2026-08-29 | `synth/report_k4b4a8e1.json` (tracked), commit 117b649 |
| round 3, PIPE_EFF=1 retime (fpga-round3) | 5,951 | 878 | ~2,340 | 7,528 (98%) | 157 | **40.44 MHz** PASS | 135,100 B (fresh, not tracked) | 2026-08-29 | `synth/stat_fabric2_k4b4a8e1.txt` (tracked), commit 7375afb; fmax from `synth/report_k4b4a8e1_r3.json` (untracked) + commit message |
| audit re-run, same tree | 6,002 | 898 | ~2,430 | 7,596 (98%) | 157 | **44.43 MHz** PASS (see note †) | 135,100 B (fresh, not tracked) | 2026-08-29 | commit dd74d4a message (see †) |
| iteration 2, same tree | 6,002 | 898 | ~2,430 | 7,596 (98%) | 157 | **44.43 MHz** PASS | 135,100 B (fresh, not tracked) | 2026-08-29 | commit 536f22c message |
| **iteration 3 (this pass), same tree** | **6,002** | **898** | **2,434** | **7,596 (98%)** | **157** | **44.43 MHz PASS** | **135,100 B (fresh, tracked)** | 2026-08-29 | **`synth/iter3/` (committed): `report_k4b4a8e1.json`, `pnr_k4b4a8e1.log`, `stat_fabric2_k4b4a8e1.txt`, `fabric2_k4b4a8e1.bin`** |

**† The 43.36 vs 44.43 correction (post-place vs post-route, again).**
The audit pass reported "fmax 43.36 MHz post-route" for this build.
Iteration 3 re-ran the identical flow on the identical tree (yosys and
nextpnr are deterministic here — cell counts and checksum reproduce
exactly). The fresh log shows **two** "Max frequency" lines: **43.36 MHz
immediately after placement** (the estimate) and **44.43 MHz after
routing** (the final), with the end-of-run report json recording 44.426
MHz. The audit almost certainly quoted the placement estimate as routed —
the same error class it had just corrected on the UP5K row (below).
Corrected record: **44.43 MHz post-route; 43.36 MHz is the post-placement
estimate.** Iteration 2's 44.43 was right all along.

Notes: "same tree" = the working tree has not changed since iteration 2
(verified clean at HEAD). FF-class 2,434 = 51 SB_DFF + 58 SB_DFFE + 1,731
SB_DFFESR + 50 SB_DFFESS + 544 SB_DFFSR (iteration-3 stat). Round-2 row's
CARRY/FF left blank rather than reconstructed from prose.

## Table 2 — the tracked bitstream's provenance (a wrinkle, stated)

- `synth/fabric2_k4b4a8e1.bin` — 135,100 bytes, **tracked since the
  round-2 commit (117b649) and content-identical ever since** (md5
  `a000ae54…`). The PIPE_EFF retime (round 3) and every later flow packed
  a **same-size, different-content** bin that was never committed over it
  — so the tracked bitstream is the *pre-retime* round-2 build, not the
  current tree's. (README's "(40.44 MHz at its commit tree)" phrasing is
  wrong on this point; its commit tree measured 27.72 MHz.)
- `synth/iter3/fabric2_k4b4a8e1.bin` — 135,100 bytes, md5 `58e6d679…`,
  **the current tree's bitstream**, packed by this pass and committed so
  the shipped-tree flow finally has matching provenance. Still untested on
  metal — packing is not bring-up.

## Table 3 — device ladder: max cells closing 12 MHz (from `synth/scale.tsv`, tracked, commit 7375afb, 2026-08-29; PIPE_EFF tree, k4b4a8e1 params, parallel config front-end)

| family | device | NCELL | LUT4 | FF | packed / cap | fmax @ 12 MHz | closes? |
|---|---|---|---|---|---|---|---|
| ecp5 | LFE5U-12F | 2 | 4,732 | 2,430 | 5,886 / 24,288 (24%) | 66.2 MHz | PASS |
| ecp5 | LFE5U-12F | 4 | 9,282 | 4,698 | 11,554 / 24,288 (48%) | 62.9 MHz | PASS |
| ecp5 | LFE5U-12F | 6 | 13,851 | 6,966 | 17,245 / 24,288 (71%) | 63.0 MHz | PASS ‡ |
| ecp5 | LFE5U-12F | 8 | 18,299 | 9,234 | 22,791 / 24,288 (94%) | 63.7 MHz | PASS ‡ |
| ecp5 | LFE5U-12F | 12 | 27,314 | 13,770 | ~34,080 est | — | PNR_FAIL |
| ecp5 | LFE5U-25F | 4 | 9,282 | 4,698 | 11,554 / 24,288 (48%) | 62.9 MHz | PASS |
| ecp5 | LFE5U-25F | 8 | 18,299 | 9,234 | 22,791 / 24,288 (94%) | 63.7 MHz | PASS |
| ecp5 | LFE5U-25F | 12 | 27,314 | 13,770 | ~45,273 est | — | PNR_FAIL |
| ecp5 | LFE5U-25F | 16 | 36,269 | 18,306 | — | — | PNR_FAIL |
| ice40 | UP5K sg48 | 1 | 3,127 | 1,296 | ~3,958 est / 5,280 | — | PNR_FAIL (IO-gated: 157 IO > 96 pins) |
| ice40 | UP5K sg48 | 2 | 5,951 | 2,430 | ~7,528 est / 5,280 | — | PNR_FAIL |
| ice40 | UP5K sg48 | 4 | 11,650 | 4,698 | ~14,732 est / 5,280 | — | PNR_FAIL |

**‡ the 12F die quirk, honestly**: nextpnr-ecp5 `--12k` places against the
LFE5U-25F die (the 12F is binned-down 25F silicon; nextpnr does not
restrict it), so its capacity column reads /24,288. The **physical 12F
capacity is 12,144 LUT4s** — against which N6 is 142% and N8 is 188%: those
two rows do not fit a real 12F. The committed tsv carries a `util12f%`
column making this explicit (95% at N4). **Max cells on a real 12F: 4.**
On a 25F: 8, at 63.7 MHz.

**The pre-pinfix UP5K rows are the wall the serialized front-end broke**:
at 157 IO the UP5K's 96 pins cannot even place NCELL=1 (Table 4 fixed
that). `~N est` rows are yosys-count estimates, not PnR results.

## Table 4 — the pin-fix lane: serialized fabric front-end (from `synth/scale-pinfix.tsv`, tracked, commit 225a9c1, 2026-08-29; serf = serialized front-end, serq = serialized + queued)

| family | device | front-end | NCELL | LUT4 | FF | LC / cap | IO / cap | fmax @ 12 MHz | closes? |
|---|---|---|---|---|---|---|---|---|---|
| ice40 | UP5K sg48 | serf | 1 | 3,220 | 1,477 | 4,231 / 5,280 (80.1%) | 37 / 96 | **15.97 MHz** PASS | PASS |
| ice40 | UP5K sg48 | serq | 1 | 4,773 | 2,176 | — | 37 / 96 | — | PNR_FAIL (LC) |
| ice40 | UP5K sg48 | serf | 2 | 6,073 | 2,611 | — | 37 / 96 | — | PNR_FAIL (LC) |
| ice40 | HX8K-CT256 | serf | 1 | 3,220 | 1,477 | 4,231 / 7,680 (55.1%) | 37 / 256 | **43.12 MHz** PASS | PASS |
| ice40 | HX8K-CT256 | serq | 1 | 4,773 | 2,176 | 6,327 / 7,680 (82.4%) | 37 / 256 | **31.07 MHz** PASS | PASS |
| ice40 | HX8K-CT256 | serf | 2 | 6,073 | 2,611 | — | 37 / 256 | — | PNR_FAIL (LC) |

The serialized front-end moves the config plane onto 37 pins
(byte-exact vs the parallel path, differential-TB-proven at its commit) —
that is what unlocks the UP5K at all.

## Table 5 — re-measurements of the UP5K headline (the 16.78 vs 17.36 correction, explicitly)

| run | fmax quoted | what it actually was | date | source |
|---|---|---|---|---|
| pinfix commit run | 15.97 MHz | post-route (correct) | 2026-08-29 | `synth/scale-pinfix.tsv` (tracked), commit 225a9c1 |
| iteration 1 | **17.36 MHz** | **nextpnr's post-PLACEMENT estimate, quoted as final — wrong** | 2026-08-29 | corrected by the audit pass (dd74d4a) |
| audit re-run | **16.78 MHz** | **post-route (correct)** — same flow re-run, log shows 17.36 after placement, 16.78 after routing | 2026-08-29 | `synth/report_verify_up5k_serf_n1.json` (16.779, untracked), commit dd74d4a message |

Corrected record: **UP5K sg48, serf, NCELL=1: 16.78 MHz post-route**
(17.36 post-placement estimate; the older pinfix-commit tree measured
15.97 post-route). All three PASS the 12 MHz target. The lesson is now a
quoting rule for this repo: **post-route numbers only; if you cite
nextpnr's estimate, label it.** Table 1's † is the same error caught on
the HX8K row, one iteration later.

## Summary the undersold way

- **Biggest fabric proven on iCE40 HX8K at 12 MHz**: 2 cells (k4b4a8e1),
  98% LC, 44.43 MHz post-route — tracked bitstream (round-2-era content,
  see Table 2) plus this pass's tree-matching bin.
- **Smallest useful device**: UP5K sg48, 1 cell, 80.1% LC, 37 IO,
  16.78 MHz post-route — needs the serialized front-end.
- **ECP5 (the boat chip)**: LFE5U-25F closes 8 cells at 63.7 MHz;
  a real 12F closes 4 (see ‡).
- **fmax across passes on effectively the same design**: 27.72 → 40.44
  (PIPE_EFF retime, +46%) → 44.43 (same tree re-measured; the audit's
  43.36 was the placement estimate). Target 12 MHz passes with ≥1.4×
  margin everywhere it closes at all.
- **Nothing on this page has met a board.** No PCF, no IO constraints, no
  bring-up: `docs/VERIFICATION.md`'s not-covered list applies to every
  row. A bitstream that packs is not a bitstream that boots.

## Reproduce the iteration-3 headline row

```sh
export PATH=/home/eileen/tools/oss-cad-suite/bin:$PATH
yosys -s synth/fpga-converged.ice40        # ~18 s -> 6,002 LUT4 / 898 CARRY
nextpnr-ice40 --hx8k --package ct256 \
  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained \
  --asc synth/fabric2_k4b4a8e1.asc --report synth/report_k4b4a8e1.json
icepack synth/fabric2_k4b4a8e1.asc synth/fabric2_k4b4a8e1.bin
```

(The script writes fixed filenames; iteration 3's committed copies live
under `synth/iter3/` with the same names, produced by this exact command
sequence on 2026-08-29 ~23:20–23:21 AKDT, yosys 18.2 s + PnR 31.9 s +
icepack.)
