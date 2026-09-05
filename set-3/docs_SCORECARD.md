# Round 2 Scorecard — quilt-verilog competition

Cross-review + verification harness, 2026-08-29. Skeleton tally: **17/24 compiled clean**
(iverilog -g2005). Full logs: `tb/scratch/COMPILE-RESULTS.md`, `tb/scratch/compile-log.txt`.
Reviews: `docs/review-{glm,opencode,zeroclaw,seed,claude}.md`.

## Ranked table

| Rank | Entry | Novelty | Buildability | Purity | Distribution | Total | One-line rationale |
|---|---|---|---|---|---|---|---|
| 1 | **glm** | 8 | 9 | 8 | 8 | **33** | Age-bucket ladder with a *proven* 2× decay bound, ring-as-quilt distribution, 5/8 skeletons compile — best math-to-evidence ratio in the field. |
| 2 | **opencode** | 7 | 10 | 9 | 7 | **33** | 9/9 compile, fullest opcode semantics, best acceptance test — loses the tie on novelty: two-exponential "power-law" + cosine is the conservative reading of the doctrine. |
| 3 | **zeroclaw** | 9 | 6 | 9 | 8 | **32** | Best architecture (hyperbolic decay counter trick, κ̂ estimator, rounding policy) with zero code and no interconnect story. |
| 4 | **seed** | 4 | 4 | 5 | 5 | **18** | Multiplier-free doctrine is coherent; the bit-overlap "product" isn't math, the fabric can't route, numbers are confabulated. |
| 5 | **claude** | 3 | 2 | 4 | 5 | **14** | Generic FSM/arbiter with the intelligence designed out; core FSM doesn't elaborate; "ready for synthesis" was false. |

Tiebreak glm vs opencode: the competition's subject is the intelligence math at the bottom
layer; glm's ladder + bound + shared math tail is the stronger contribution, and its single
compile bug (`st`/`S_IDLE` use-before-declaration in `qs_cell_core`) is a two-line fix.
opencode wins on every buildability axis and is the natural chassis.

## Recommendation

**Winner: glm. Build glm in `rtl/` with testbenches, with the steals below merged in.
Runner-up opencode is the fallback chassis if glm's fabric-level arbitration (math-tail
grant, seam behavior under effect storms) proves heavier than sketched — and its skeletons
should be reused directly regardless (they compile).**

### Steal-list (MUST be merged into the winner)

1. **zeroclaw's power-law decay counter** — `proposals/zeroclaw/ARCHITECTURE.md` §2.1
   ("Power-law decay (the doctoral part)"): integer W/age state, decrement interval
   `P₀ >> 2·msb(W)`, integrating to the exact hyperbola `W₀/(1+W₀t/P₀)`, one shared priority
   encoder. Merge as an alternate edge-decay engine beside glm's ladder (glm itself reserves
   `LADDER_MODE` in §3.1 for exactly this); the hyperbola is the true heavy-tail law the
   ladder staircase approximates.
2. **opencode's runtime dial/config address map** — `proposals/opencode/RTL-SKETCH.md` §3
   (`q_dialfile`): bind-writable ETA_F/ETA_S/KF/KS/KA/THRESH/REFR/COS_MIN with reset
   defaults. glm's LEAK_SH/HALF_LIFE are compile-time parameters; stealing this map makes
   learning rates and decay horizons runtime fabric state (Law 2: config through qm_bind
   only).
3. **opencode's train-to-fire-decay acceptance test** — `proposals/opencode/ARCHITECTURE.md`
   §10, `tb_fabric_smoke`: bind → link → 100 co-active effects train w past THRESH (verified
   via qm_view) → tick until B fires → observe egress at neighbors → decay-only ticks shrink
   w below THRESH. Adopt verbatim as the `rtl/` CI acceptance gate; glm's TB plan proves
   modules, not that the fabric learns.

Honorable-mention steals (strongly advised):
- zeroclaw §3 rule 3 (convergent rounding at integrating boundaries only) + §3 rule 6
  (integer state where math allows) — fold into glm's §4 truncation policy; the dial
  random-walk argument justifies the change.
- zeroclaw §2.2 κ̂ via Sra's `(ρ̄d − ρ̄³)/(1 − ρ̄²)` with a bisection golden model — the
  post-v1 upgrade path glm lacks; both entries' ports already admit it.
- opencode `q_flit_pipe` / `q_link_ringport` skeletons as-is (compile clean, correct
  `ready` logic) instead of rewriting glm's ring plumbing from scratch.

### Fixes owed by the winner before rtl/ promotion
- `qs_cell_core`: declare `st`/`S_IDLE` before `core_take` (compile blocker).
- `qs_hebb_edge`: register or restructure the readout adder tree (verilator UNOPTFLAT).
- Sweep -Wall width warnings (qs_ln multiply widths, qs_mathtail index widths).

## Skeleton compile tally (per entry)

| Entry | Clean | Notes |
|---|---|---|
| opencode | 9/9 | width/unused warnings only |
| glm | 5/8 | qs_cell_core decl bug; qs_fabric unresolved wrapper deps; qs_hebb_edge comb loop |
| seed | 1/3 | SV block decls; array slice; reserved word `cell` |
| claude | 1/4 | wire-procedural assignment; array port; `int`/`disable` SV-isms |
| zeroclaw | 0/0 | no RTL-SKETCH.md shipped |

**Overall: 17/24.**
