# THE BREAKDOWN — the adversarial dossier: every load-bearing claim, with its evidence chain

**Lane:** breakdown (GLM-5.3) · **Date:** 2026-08-29
**Contract (Casey's, verbatim intent):** *break down the math so it is impossible to deny.*
**Method.** Every claim the system makes that anything else stands on gets one numbered section, self-contained: a reader who denies everything can be handed ONE section and check it alone. Each section is CLAIM → DEFINITIONS → PROOF → MACHINE CHECK → ATTACK SURFACE → CLOSURE. No appeals to authority: no result is credited because of who wrote it; every theorem is either re-derived in-repo (with the derivation's location given so it can be attacked) or machine-executed (with the command given so it can be re-run). Every number carries its source: file:line, file:section, or committed log.
**What denial requires.** Sections §1–§5, §9, §11, §12 rest on artifacts that execute. Denying them requires running the commands in Appendix A and getting *different output* — or showing the artifact does not check what the section says it checks (the stronger attack; each section's ATTACK SURFACE names where that lever is). Sections §6–§8 are pen theorems (the general results) **plus bounded machine checks now RUN** (2026-08-29, mathmetal lane: exact-arithmetic finite-instance enumerators in `tools/verifies/` — every instance in the stated bounds verified, no floats; the enumerators are bounded, and the bounds are printed by each run); denial of the machine layer requires re-running and finding an instance that violates — or a bench-encoding error, which the lane itself hit twice and fixed (see §7's note). §10 is machine-checked at small scale since 2026-08-31 (commit 3157b3d: fabric-level differential cosim, measured-serialization replay — scope in §10).
**Score at the top:** 12 claim sections · 12 machine-checked (8 end-to-end + §6/§7/§8 bounded enumerators + §10 small-scale fabric cosim) · 0 pen-only-with-unrun-checks · 0 pending · open gaps: 6 (B1, B2, B8, B9, B10, B12) + B7 half-closed + B3/B4/B5 closed-bounded with named residues + B6 closed-small-scale (NCELL=2, named residues in §10) + B11 closed, each with its closing artifact.

---

## §1 — Ledger conservation: no value is created or destroyed in transit

**CLAIM.** In the fabric, weight (or any tracked quantity carried by flits) is conserved: everything any cell emitted is either booked in a receiving ledger, provably in flight, or explicitly external. No accepted effect vanishes; nothing books that was never emitted. This is the hardware instance of the calculus's A1/T1/T2 (balance as axiom → conservation by induction).

**DEFINITIONS.**
1. **Posting** `(a, v)`: account `a`, integer amount `v ≠ 0` (credit > 0, debit < 0).
2. **Transaction** `T = (n, {(a₁,v₁),…,(a_k,v_k)})`: postings plus a unique **nonce** `n`; **balanced** iff `Σvᵢ = 0` (axiom A1, quilt-calculus.md:102 — *assumed, never derived; the core refuses to commit unbalanced transactions*).
3. **Ledger** `(log, bal)`: append-only log + balance map; application is **idempotent by nonce** (A4, quilt-calculus.md:116 — a seen nonce is a no-op).
4. **Cut** 𝒞: a set of cells; `Φ(𝒞) := Σ_{a∈Acct(𝒞)} bal(a)`. A transaction **crosses** the cut if its postings touch both sides; a posting is **in flight** from its first commit to its last (D5, quilt-calculus.md §6).

**PROOF.**
- **T1 (interior):** any run in which no committed transaction crosses 𝒞 has `Φ(𝒞)` constant — induction over run length; the step case is: an apply event at a 𝒞-side cell applying an interior transaction changes `Φ` by `Σ_a v_T(a) = 0` *by A1*. Full induction: quilt-calculus.md:323–341. The long-form expansion (indicator-function version, three cases): BRIDGES.md B1; compressed: ELEGANCE.md E1.
- **T2 (crossing, the in-flight identity):** at every point, `Φ(𝒞)(t) = Φ(𝒞)(0) + F(t) + I(t)` — pure bookkeeping induction, two step cases (completes / does-not-complete), quilt-calculus.md:347+. Corollaries: **no fabrication** (an unbacked credit is unrepresentable, T2.1) and **partition observability** (the discrepancy is *measured* by the books, T2.2).

**MACHINE CHECK.** `formal/fabric.conservation.sby` — SymbiYosys BMC, depth 55, boolector, **PASS** (re-run 2026-08-29 in 40 s with `PIPE_EFF(1)` pinned in the harness — the v2.1 effect-pipeline retime, the exact config the committed bitstream ships; the pre-retime committed artifacts dated to `414db39`, this re-run makes the proof current against `rtl/` as shipped). The harness `formal/f_fabric_conservation.v` instantiates **two real `q_cell_core` cells, real `q_hebb_edge` engines, and a real `q_flit_pipe` channel — no stubs** (only environment assumptions: fire-only workload after bind+link setup; shrunk params EDGES_N=1, K=4, B=4, AGEW=8 documented in the header). Properties, all asserted at module boundaries (f_fabric_conservation.v:23–42):
- **T1** `emitted == in_flight + accepted(B)` — transport: nothing lost or fabricated in movement (composes with the FIFO proof of §12).
- **A1** `emitted == booked + in_flight + in_service + external` — the ledger identity: booked weights + flits in flight == what fires issued, checked across commits.
- **SER** in-service ≤ 1 (commits serialize); **DROP** every accepted effect is booked within 16 cycles (the silent-drop path is unreachable for linked peers); **FAN** post-setup emissions carry op=EFFECT, src=A, dst=B.
Bonus: this proof, on its first run, **found a real RTL defect** — a one-cycle `ci_ready` hole that silently dropped an ingress flit when a tick strobe landed (formal/README.md Findings #2; fixed commit `2881b29`). The conservation property then passed.

**ATTACK SURFACE.**
1. *"BMC depth 55 is not proof."* True as stated — it is bounded model checking. Closure: the depth was chosen from the *structural worst case* (a DROP violation needs ≤ 16 cycles; the horizon covers ≥ 3× that), and the README documents the completeness argument per property. Unbounded mode is a registered gap (B1). What the BMC *does* already buy: the property holds for every input trace the solver can drive in 55 cycles — including ones no directed test would find (it found the drop).
2. *"Shrunk parameters (K=4, B=4, EDGES_N=1)."* Documented in the harness header; the ledger counts *commits*, which neither half-life shifts nor bucket saturation create or destroy. And §11 closes the loop: the committed bitstream runs exactly these parameters.
3. *"A1 is an axiom, so conservation is assumed."* Yes — and stated as such (quilt-calculus.md §3: "Balance is therefore never a theorem"). What is *proved* is that the axiom, plus idempotence, *forces* conservation and the in-flight identity by induction — and that the silicon refuses unbalanced commits (the only commit path, `hb_cmd` 001/101, books a graded cofire against a counted emission).

**CLOSURE.** Denial requires: `sby -f formal/fabric.conservation.sby` to FAIL, or a demonstration that the asserted equation is not the claimed invariant. Both are checkable in minutes (Appendix A.1).

---

## §2 — Fire-vs-train separation and echo-gate semantics: cells learn only from causally-ordered echoes

**CLAIM.** (a) In the core, *reception is not learning*: an incoming effect integrates activation, but trains an edge only through the explicit graded-cofire path; fire consumes the activation (`act` zeroed at fire, pre-leak value used as `afire`); ticks — not traffic — drive decay. (b) With the v2 echo gate on, an effect trains an edge **only inside a causal window after the receiving cell's own last fire** ("I fired, then you echoed me"); silence (F=0) gates every train off. (c) The gate's graded class puts the cofire into the *same* staircase envelope as §3 — no new unproven weight math. (d) `FLOOR=0` disables the gate and is **bit-exact v1**, machine-checked as an A/B pair.

**DEFINITIONS.**
1. **Fire trace** `F` (rtl/q_echo_gate.v): one register per cell. Rules: `fire: F ← max` (fire wins over a same-cycle leak); `tick: F ← F − (F >> KLE)` (snapping to 0 at/below FLOOR or residue ≤ 1); `gate: live = F ≥ FLOOR`, and the graded class `gclass = 15 − msb(F)`.
2. **Causal window** `W_E ≈ ln(Fmax/FLOOR)/ln((1−2^−KLE)^−1)` ticks — the echo window (q_echo_gate.v:16).
3. **FLOOR=0** = gate disabled = v1 semantics (dial 12; default 0 so the v1 acceptance gate stays bit-exact until opted in, q_echo_gate.v:21–24).

**PROOF.**
- (a) is the FSM structure itself: `ST_FIRE` uses pre-leak `act`, zeroes it, fans out; `ST_EFFR/ST_EFFI` integrate `act += sat(w·dat >> 15)` and book the cofire via `hb_cmd 101`; decay happens only in tick service (`ST_TLEAK`). The separation is enforced by construction and witnessed by the formal proofs of §1 (DROP: an accepted effect *must* book; SER: one commit at a time) and §12 (Q2: ticks cannot be starved, so decay cannot be deferred by traffic).
- (c) is a *reduction*, not a new theorem: with `k(d) = F(d)/Fmax`, the class rule `g = 15 − msb(F)` gives `2^−g ∈ (k, 2k]` — the same aligned-phase overstatement staircase that error-envelopes.md Theorem 1 already bounds (§3 below). Stated with derivation in q_echo_gate.v:18–22; the TB checks the bracket bit-exactly. *(Return-leg pin, RETURN.md R2: Fmax = 2^PW — with the literal refill value 2^PW − 1 the bracket's open lower edge fails by one quantum at F = Fmax; the exact integer form, and the form both the TB and `formal/echo_gate.dyadic.sby` prove, is the octave form 2^(PW−1) ≤ F ≪ g < 2^PW.)*

**MACHINE CHECK.**
- `tb/tb_q_echo_gate.v` — **PASS** (re-verified this session): reset; refill; leak recurrence for KLE ∈ {1,2,3}; real-arithmetic envelope; **dyadic class bracket** `2^−g ∈ (k, 2k]`; snap hysteresis; **fire-vs-leak priority**; **disabled mode**; dead-trace semantics.
- `tb/tb_q_rqh_bank.v` — **PASS** (this session): the residue bank's deposit/leak/credit arithmetic.
- `tb/tb_fabric_smoke_v2.v` — **PASS** (this session): end-to-end on the real fabric with **echo gate FLOOR≠0 and RQH RQEN=1 dialed on**, `maxlat=31` — the gated/graded/credited path is the exercised one, and the same view-latency bound as v1 holds.
- Formal: the DROP and SER properties of §1 and the Q2 family of §12 directly cover (a) — the drop path for linked peers is proven unreachable and commits serialize.

**ATTACK SURFACE.**
1. *"The echo-gate window math is pen-only."* The window formula is arithmetic over the leak recurrence; the TB verifies the recurrence and the class bracket against a real-arithmetic golden. The *envelope* claim (c) inherits §3's theorem — and (c)'s integer core, the dyadic bracket 2^(PW−1) ≤ F ≪ g < 2^PW, is now **formally proven over the actual gate FSM**: `formal/echo_gate.dyadic.sby`, BMC depth 25, boolector, PASS in 2 s (any fire/tick trace, anyconst dials kle ∈ [1,8], floor free; covers reached in a companion cover-mode run — g ∈ [0,7] and ≥ 8 both exercised), together with PRIORITY (fire beats same-cycle leak), MONO (no resurrection), ZEROABSORB (dead stays dead), DEAD (F=0 gates training off, class 0), DISABLED (FLOOR=0 = always live = v1). The RQH bank still has no sby proof (the open half of gap B7).
2. *"Default-off means untested in production paths."* No: §11's bitstream includes the gate silicon, and tb_fabric_smoke_v2 exercises it on; the A/B (FLOOR=0) equivalence is asserted by tb_q_echo_gate's disabled-mode check and by v1's exact-golden gate (§3) still passing unchanged.
3. *"Fire-vs-train could still couple through act."* The coupling direction that exists (train raises act; fire consumes it) is the *designed* loop, and its numeric envelope is §5's Theorem 5c (the −½ LSB/effect bias is the only coupling residue, quantified).

**CLOSURE.** Denial requires a run of the three TBs (Appendix A.2) failing, or a trace where an effect trains an edge with `F = 0` — which is exactly the dead-trace check in tb_q_echo_gate.

---

## §3 — The 2× ladder decay bound: the readout is trapped between the truth and twice the truth, for ANY arrival stream

**CLAIM.** The v1 ladder engine's readout `Ŵ` satisfies, at every read instant, `W/2 − 1 ≤ Ŵ ≤ 2W + 1` (as-built symmetric integer form) where `W = Σ_e 2^(−a_e/H)` is the exact exponential-law weight — for **arbitrary arrivals**: adversarial, dependent, bursty, any distribution. No assumption on the arrival process is made or used. In the unshifted regime the readout is **exact** (`wsum == base + N·2^8`).

**DEFINITIONS.**
1. **Ladder** (rtl/q_hebb_edge.v MODE=0): K=8 bucket counters, B=8 bits. A cofire increments `C₀` (saturating, sticky `o_ovf`). Every `H` ticks the ladder shifts `Cᵢ ← Cᵢ₋₁`; bucket *i* holds events of age `a ∈ [iH, (i+1)H)` and carries implied weight `2^−i` realized as a **wire shift** (readout places bucket i at bit offset; one fresh cofire reads 2^8 = 256).
2. **True weight** `w(a) = 2^(−a/H)`; `W = Σ_e w(a_e)`.
3. **Phase ambiguity**: the RTL shifts on global half-life boundaries, not per-event timers, so an event sits in class `g ∈ {⌊(t−t₀)/H⌋, ⌊(t−t₀)/H⌋+1}` — the ±1-class slack.

**PROOF.** Theorem 1, error-envelopes.md:56–76 — for an event with age `a ∈ [iH, (i+1)H)`, monotonicity of `w` gives `w(a) ∈ (2^−(i+1), 2^−i]`, so the assigned weight `2^−i` overstates by a factor in `[1,2)`; summing (all overstatements are one-sided in the aligned phase) gives `W ≤ Ŵ < 2W`. The proof consumes exactly three facts — `w` strictly decreasing, grid-exact values `w(iH) = 2^−i`, one bucket per event — **none of which mentions the arrival process**. The as-built ±1 phase gives the symmetric form. Tightness: both ends attainable in the limit (per-event ratio → 2 aligned, → ½ mis-phased); in expectation for uniform ages `E[Ŵ/W] = 2 ln 2 ≈ 1.386` (error-envelopes.md:82). Retirement tail: an event older than K·H contributes `< 2^−K = 0.39%` and is dropped, not approximated (:87). The readout arithmetic itself is exact shift-and-add — zero rounding.

**MACHINE CHECK.**
- `tb/tb_hebb_edge.v` **T2**: asserts `wexp/2.0 − 1.0 ≤ wint && wint ≤ 2.0·wexp + 1.0` with the TB's own independent golden model — **PASS** (this session).
- `tb/tb_fabric_smoke.v`: asserts the **exact** unshifted case `wsum == base + N·2^8` for N co-fires before any half-life shift, end-to-end on the 4-cell fabric — **PASS** (this session, `maxlat=31`).
- The Python mirror asserts the same invariants: `sim/tools/test_tapfabric.py` (fresh cofire reads exactly 256; each half-life exactly halves an old cofire's class; saturation) — 34/34 **OK** (this session).

**ATTACK SURFACE.**
1. *"One event schedule in the TB — the theorem says ALL streams."* Correct hit: the TB covers one schedule (5 events); the theorem's universality is pen-proven. The closing artifact — a fuzz harness over random streams + the planned k-induction monitor (ABSTRACTION-MATH check #5; error-envelopes.md §7 row 1 names it) — is registered gap B2, ~30 lines on the existing harness.
2. *"The exactness claim only holds pre-shift."* Yes and is stated so; after shifts the envelope applies. Both are asserted in different TB sections.
3. *"The law (exponential) itself is an assumption."* Owned: whether exponential forgetting is *right* is task-level, arbitered by the acceptance gate; the envelope bounds the hardware against *whichever* law the dial selects (error-envelopes.md §7 assumption 2).

**CLOSURE.** Denial requires tb_hebb_edge T2 or tb_fabric_smoke's exact-golden check to fail on re-run, or a counterexample stream violating the band — which would falsify the pen theorem; produce the stream and the fuzz harness (B2) will replay it.

---

## §4 — The RQH corrected-deposit formula — and the falsification history that proves the math has teeth

**CLAIM.** For the residue-banking readout (RQH) to *center* (never close) the model band, the deposit per class must equal the expected overstatement:
```
deposit(g) = 2^QDW · E[overstatement | class g] = 2^(K+QDW−g) · (1 − 1/(2 ln 2)) ≈ 2^(K+QDW−g) · 0.2787
```
The **as-built** deposit `2^g` does NOT satisfy this: it is ~18,262× too small at class 0, its class-dependence is *inverted* (largest where the overstatement is smallest), and it satisfies the condition only at g ≈ 7.1. The original proposal's claim ("asymptotically tightens the envelope") is **FALSE as built** — and this section's history (we caught our own error, twice, with the numbers getting *worse* for us as the checking tightened) is exhibited deliberately: it is the dossier's proof that the checking is not ceremonial.

**DEFINITIONS.**
1. **Reservoir** `R` (RW=16, saturating, deadband-leaked): class-g cofire deposits `deposit(g)` quanta; leak `R ← R − (R >> QLEAK)` per tick; credit `C = R[15:8]` (QDW=8); corrected readout `Ŵ_RQH = base + eng + C` (saturating).
2. **Overstatement**: in readout units (2^K per fresh cofire), a class-g event's true weight is `2^(K−a/H) ∈ (2^(K−g−1), 2^(K−g)]`; the assigned weight overstates by `u ∈ [0, 2^(K−g−1))`, with `E[u|g] = 2^(K−g)·(1 − 1/(2 ln 2))` for uniform ages.

**PROOF.** Theorem 3, error-envelopes.md §3 (three parts):
- **3a (bounded perturbation, TIGHT):** `0 ≤ C ≤ 2^(RW−QDW) − 1 = 255` LSB always; the reservoir never wraps (saturating add); the leak makes C a bounded low-pass of recent deposits.
- **3b (the strong claim fails):** since `C ≥ 0`, `Ŵ_RQH ∈ [W/2−1, 2W+1+C]` — a one-sided credit can never reduce the worst-case upper ratio and strictly increases it (`2 + C/W`). "Asymptotically tightening" is false *as a matter of sign*.
- **3c (the exact convergence condition):** for the credit to track the accumulated overstatement, its long-run rate must equal the overstatement rate for *every* class-rate profile — forcing `deposit(g) = 2^QDW·E[u|g]` pointwise; the displayed formula. Solving `2^g = 2^(K+QDW−g)·0.2787` gives g ≈ 7.1 (K=QDW=8): equality at one point, ~2^(K+QDW−2g)·0.28× too small everywhere fresher.

**THE FALSIFICATION HISTORY (the evidence of teeth, all numbers from the committed record).**
1. **The proposal said** "asymptotically tightens the 2×/[1,4)× envelope" (proposals/innovations/flash.md).
2. **The theorem said NO** (error-envelopes.md C3, :28–32): the credit is non-negative, the deposit is not the underpay statistic; strong claim FALSE as built.
3. **The arithmetic itself was then caught being wrong — by the machine lane:** the first correction constant said "~9,100× too small at class 0." `tb/tb_rqh_saturation.v` measured the doc's *own formula* at g=0: `2^16·0.27865 = 18,261.8` — the ~9,100 was a 2^15 slip (correction C6, error-envelopes.md:38). The honest factor is **~18,262×**. The error went *against* us and we printed it.
4. **The machine then measured both verdicts:** under the **corrected** deposit table `[18260, 9130, 4565, 2283, 1141, 571, 285, 143]` (within 2 quanta of exact at every class — bit-exact-checked), the mis-phased mean error tightens **120.4 → 83.9 / 57.1 / 50.4 LSB at QLEAK 4/5/6 (2.1–2.4×)**; the **as-built `2^g` delivers literally zero credit** (18,262× too small); the aligned-phase control *widens* 125.9 → 191.4 (Theorem 3b confirmed empirically); QLEAK=8 saturates every deposit and destroys the tightening (120.9) — the leak dial is the other half of the condition. All in error-envelopes.md §7.1 and the TB.

**MACHINE CHECK.** `tb/tb_rqh_saturation.v` + `rtl/q_hebb_rqh.v` — **PASS** (this session): deposit tables bit-exact per class; corrected flood saturates at the 4th deposit, no wrap, telemetry integrity (`antic == credit rises`); deadband leak golden-exact to exactly 0 (the sketch's snap rule had a sticky floor — found and fixed); preservation band held at all 1,536 samples; RQEN=0 A/B clean. `tb/tb_q_rqh_bank.v` — **PASS** (this session).

**ATTACK SURFACE.**
1. *"Maybe a cleverer scheme could still tighten."* No — 3b is a sign argument: any non-negative additive credit widens the worst-case upper ratio. Closing the band would need a *signed* correction, impossible while the mis-phase is unobservable (error-envelopes.md §3.2 note). This is an impossibility, not an engineering shortfall.
2. *"The corrected deposit is unfalsified speculation."* It is *derived* (3c) and its predicted centering was then measured (2.1×); what remains unproven is optimality of the leak schedule at the joint optimum — scoped to v2, honestly.
3. *"Who checks the checker?"* The 18,262 constant is recomputable by hand from the formula in this section in one line; the TB prints its census.

**CLOSURE.** Denial requires tb_rqh_saturation to fail on re-run, or an arithmetic refutation of 3b/3c. The history stands as committed: proposal → theorem-NO → constant corrected against us → both verdicts measured. **The system falsified its own flagship numeric claim and kept the corpse on display.**

---

## §5 — The snap-contract covering inequality: integer measurement suffices, exactly, at b ≤ 2ε/√n

**CLAIM.** The covering radius of the scaled integer lattice `b·ℤⁿ` is **exactly** `b√n/2`; therefore integer representation in basis `b` suffices for tolerance `ε` for *every* reachable value iff-relevant geometry satisfies `max_A dist(x, b·ℤⁿ) ≤ ε` (uniform sufficient condition: `b ≤ 2ε/√n`; 1-D: `b ≤ 2ε`). The snap judge (squared-form) contributes **zero** comparison error; the honest loop bound is `Δ + 2ε` true / `Δ` displayed. The tower pilot implements this end-to-end in C with **no floats**, verified against 17 hand-golden vectors.

**DEFINITIONS.**
1. **Measurement basis** `b`: the unit quantum; values live on `b·ℤⁿ`. **Covering radius** `cov(b) = sup_x dist(x, b·ℤⁿ)`.
2. **Deep hole**: the cube center `(b/2,…,b/2) + b·ℤⁿ` — equidistant `b√n/2` from all 2ⁿ corners.
3. **Squared-form judge**: verdict WITHIN iff `|g−s|² ≤ Δ²` — equivalence by strict monotonicity of `t ↦ t²` on ℝ≥0 (T8, quilt-calculus.md:726).
4. **Pythagorean configuration**: reachable set ⊆ `{v ∈ ℤⁿ : ‖v‖ ∈ ℤ}` → distance 0, arithmetic exact by construction.

**PROOF.** Theorem 4a, error-envelopes.md:199–210 (≡ CALC T11(a), quilt-calculus.md:825+; ≡ BRIDGES B7): round each coordinate to a nearest multiple of b (≤ b/2 per axis) → `dist ≤ √(n·(b/2)²) = b√n/2`; the center attains it exactly → the radius is not an overestimate. Geometry-relative refinement (4b): necessary iff the reachable set reaches a deep hole; on-lattice/1-D/Lipschitz/ℓ∞/ℓ1 closed forms; the judge's `‖g−s‖² ≤ Δ²` is exact integer arithmetic → zero comparison error; loop bound `| |ĝ−ŝ| − |g−s| | ≤ 2ε` and verdict guaranteed outside the `(Δ−2ε, Δ+2ε]` fuzzy band (error-envelopes.md §4.3).

**MACHINE CHECK.**
- `tb/tb_judge_consistency.v` — **PASS** (this session): ~2,325 vectors, n ∈ {1,2,3}: max quantization error = `b√n/2` **exactly** (7.0 / 6.36 / 6.93 vs ε = 7 — attained at the deep holes), zero integer-vs-real verdict flips outside the ±2ε band, `|d_int − d_real| ≤ 2ε` always, on-lattice verdicts exact (incl. `8²+0² ≤ 8²`), and the **negative control**: `b+1` breaks the guarantee at the deep hole in every dimension. (This TB also caught the iverilog real→integer rounding gotcha — max error 14 = b before the `$rtoi` fix, 7 = b/2 after; error-envelopes.md §7.1.)
- **Tower golden vectors** — `python3 tools/tower/verify.py`: **PASS** (this session): 17/17 hand-golden voltage→PSI rows exact to whole units (on-lattice: every 400 mV = exactly 15 psi — the 80ths-of-a-psi basis; off-lattice round-to-nearest; both clamp edges), median spike rejection, **both Schmitt edges (WITHIN at d=Δ, SNAP at d=Δ+1, reality wins, debt booked)**, exact QUF-line image match (10 integer kv pairs), **no-floating-point scan of the generated C**, compiled `gcc -std=c99 -Wall -Wextra -Werror` two-TU clean with weak-glue override. Generated C: 15,503 bytes / 379 lines (commit `987a797`).
- Snap-contract soundness in the calculus (T9 invariant `|g−s| ≤ Δ` at every tick boundary, `≤ Δ+ρ` mid-tick; T10 custody/balance/debt) is pen: quilt-calculus.md:737–820 — its executable instances are the Schmitt-edge and debt-booking checks above.

**ATTACK SURFACE.**
1. *"The deep-hole bound is about ℝⁿ; sensors are finite."* The geometry-relative form (4b) is the exact condition for finite reachable sets; the TB sweeps constructed reachable sets (⅛-phase grids, LCG vectors) and the negatives.
2. *"Floats could sneak into the loop."* The verify gate scans the *generated* source for floating-point types (live output: "floats : none"); §9 extends the scan to rtl/ and the Python mirrors.
3. *"The snap transaction books debt — does the booking balance?"* Yes — and this was itself a *caught error*: the informal 3-legged `T_snap` sums to `|g−s| ≠ 0`; the balanced four-legged form (authority swap ⊕ drift booking, `Σ = 0`) was forced independently by two lanes (CALC T10(b), quilt-calculus.md:757; BRIDGES B9; compressed ELEGANCE E5). The tower C books the debt in the four-legged discipline.

**CLOSURE.** Denial requires tb_judge_consistency to produce a verdict flip outside the band or an error > b√n/2 at b ≤ 2ε/√n (or the b+1 negative to *pass* — which would refute the tightness claim), or verify.py to disagree with any hand-golden row. All runnable in seconds-to-minutes (Appendix A.5/A.6).

---

## §6 — The freshness dichotomy under partition (C1): metered staleness or a loud fork — and the nonce seam that had to be killed

**CLAIM.** During a clean partition of a quilt: either (i) ownership is preserved and every cross-cut view degrades with *exact meters* — time-staleness grows at rate exactly 1, value-deviation equals the mirror in-flight posting sum *exactly* — or (ii) ownership is deliberately reassigned and each side becomes a closed conserved universe with a frozen, legible fork discrepancy. **No third behavior — during the partition.** At the *seam* (reconnection), the claim as originally stated is **FALSE**: a nonce collision produces converged-by-instruments, divergent-in-content state — the meter itself reads zero. The repair (structural nonces `= (minter-cell-id, per-cell serial)`) makes uniqueness a *theorem of A2+A3* and the seam closes loudly.

**DEFINITIONS.**
1. **Clean partition** π of cut 𝒞 = 𝒜∣ℬ (C1-d1): no link crossing 𝒞 delivers, from t_π; cells on both sides keep running; already-crossed flits drain within a bounded transient Δ_drain.
2. **Mirror** M of owner O (D10): receives O's transactions, at-least-once, idempotent by nonce.
3. **The two meters** (C1-d3): time-staleness `age(t) = t − t_last` (last delivered owner commit); value-deviation `δ_a(t) = |bal_O(a,t) − bal_M(a,t)|`; **mirror in-flight** `I_M(a,t)` = sum of unapplied-at-M postings. (The conjecture's original Lyapunov candidate — the *cut* in-flight I_𝒞 — is the *wrong meter*: it is blind to interior transactions that still stale the mirror. The repair is part of the result.)
4. **Structural nonce** (Theorem 3): `n := (minter-cell-id, per-cell serial)` replacing D4's unenforced "unique nonce" clause.

**PROOF.** conjectures.md Part I, 13 numbered proofs across the three parts:
- **Lemma 1** (mirror identity): `bal_O(a,t) − bal_M(a,t) = I_M(a,t)` *exactly, always* — T4's induction specialized; log_M ⊆ log_O by nonce identity.
- **Theorem 1** (during-partition dichotomy, :55): (i) t_last fixed past the drain → age grows at rate exactly 1; δ_a = |I_M| exactly, monotone; the cut meter frozen in its fully-applied part. (ii) the fork is *unbookable* as a transaction (booking it would cross the cut — undeliverable), hence an operator dial event; each component then conserves (T1 verbatim per component). (iii) exhaustive case analysis over the event alphabet — no fourth case exists *during*.
- **Counterexample 2** (the silent seam, :76): both sides mint transactions with the **same nonce** n* (no global registry under partition; timestamps collide with positive probability, adversarially with certainty). At the seam, each side's replay of the other's transaction is a **no-op by A4** (nonce seen). Final nonce sets are equal — every instrument (set-difference, cut in-flight, per-side balance) reads **converged** — while the ledgers hold different transactions. The mechanism of failure is A4 itself: T4's proof goes through on transaction *sets*; A4 implements dedupe over *nonces*; the fork destroys the injectivity between them.
- **Theorem 3** (closure, :91): under structural nonces, (a) uniqueness is a theorem (distinct minters, distinct serials by A3's total order); (b) the seam converges to the union set-sum with at-least-once coverage — no ordering agreement; (c) any violated invariant is a first-order predicate of balances, checkable at r=0 — the join is *loud*.

**MACHINE CHECK. RUN 2026-08-29 (mathmetal lane) — bounded, exact-arithmetic:** `python3 tools/verifies/c1_seam_bench.py` → **PASS, 87,245 integer checks, 0 failures** (~4 s, stdlib, no floats). Instance bounds, printed by the run: (A) Lemma 1 + Theorem 1(i) meters on all 85 owner mint sequences (length ≤ 3 over a 4-transaction balanced alphabet) × every in-order delivery prefix — bal_O − bal_M == I_M per account at every commit boundary, δ_a == |I_M|, InF monotone, age rate exactly 1; (B) the fork: 273 interior-sequence pairs per side, two conservation constants verified; (C) Counterexample 2 executable — the canonical nonce collision (instruments converged: nonce-set diff ∅, cut in-flight 0, both sides balanced; content diverged: O holds −7 where the union holds −4) **plus the generalization**: 7,225 aligned-counter mint pairs enumerated, all 6,684 pairs with differing colliding content silently diverge while reading converged; (D) Theorem 3 closure — structural nonces unique across all 441 enumerated fork pairs; the seam converges to the union under 68,576 at-least-once replay interleavings (400 mint pairs × ≤ 240 orders); the loud join constructed (custody invariant bal(c) ≥ 0 violated at −2 by the union, predicate fires at r = 0); (E) the during-partition event alphabet closed. **Bounded checks are bounded**: the theorems remain pen-proved for the general (unbounded) system; the enumerator verifies every instance within the stated alphabet/length bounds. The bench itself bit twice during construction (a re-applied mint in the monotone arm; a nonce-keyed "union" ledger that reproduced the very conflation it was meant to refute — fixed; both are the harness-semantics attack surface in miniature).

**ATTACK SURFACE.**
1. *"Bounded enumerators are not the general theorem."* Correct and stated: the pen proofs (conjectures.md Part I, 13 numbered proofs) carry the general claim; the bench verifies the enumerated class exhaustively (every instance in the bounds, not samples). The composition lemma for flapping/asymmetric seams remains unwritten (the residual of B3, now narrowed to it).
2. *"Flapping/asymmetric seams."** Owned in the source (conjectures.md:103): under structural nonces they compose Theorem 1 and Theorem 3 phases; the composition lemma is "bookkeeping, not insight" but is not yet written out — the open residue of the old B3.
3. *"Maybe nonce collision is unreachable in practice."* The counterexample needs only two sides drawing from aligned counters — the default of any pre-partition-synchronized scheme. The bench's 7,225-pair sweep confirms: *every* differing-content collision diverges silently, no exotic timing required.

**CLOSURE.** The dichotomy is a theorem *during* partitions and at the seam *conditional on structural nonces* (pen, general); the executable layer now confirms both on the enumerated class (meter-zero divergence for plain nonces; loud union join for structural nonces). Denial of the pen part requires finding an error in the 13 proofs; denial of the machine layer requires `c1_seam_bench.py` to FAIL on re-run — or an instance outside the bounds that behaves differently, which is exactly what the composition lemma (the residue) would settle.

---

## §7 — The drift budget and the ρ·F impossibility floor (C2): **no policy sees through its own staleness window** — headline theorem

**CLAIM.** For a judge held at fixed `(d₀, A₀, r)` against a truth frame drifting at combined rate ρ (answer path length + metric perturbation), with audit observations arriving with view freshness F:\n1. **Drift band (Theorem 4):** a verdict flip implies the input's margin `m(x) ≤ γ(t)` — error is exactly *margin mass within the drift band*, and the bound is attained (no assumption narrows it).
2. **Composition (Corollary 4′):** drift is verdict-equivalent to an unmodeled prefilter stage of accuracy γ(t) — tolerance composes *additively* with drift (triangle inequality, one perturbation per step in both directions).
3. **Policy (Theorem 5):** err ≤ σρ(T+F) for period-T re-judging; holding error fixed costs **linear in ρ**; the joint optimum scales as **√ρ**; and — the headline — **(iii) every policy's worst-case error is ≥ μ({m* ≤ ρF}): if ρF ≥ ε₀, no re-judging schedule, however frequent, meets an ε₀ target. Drift within one audit-freshness window is the floor no dial schedule can sweep.**
4. **Committee corollary (Proposition C):** for a committee of m readers re-anchoring round-robin: aggregate-fresh cost rate `cρ/(ε₀−ρF)` — **independent of m**; member-fresh (any member consultable alone) costs `≥ cmρ/(ε₀−ρF)` — **redundancy costs linearly in committee size**; with per-reader service floor δ_min, `m ≤ (ε₀−ρF)/(ρ·δ_min)` — **committee size is capped by freshness**.

**DEFINITIONS.**
1. **Truth frame** (C2-d1): same key set K throughout; answers move `A_t`, metrics `d_t` (pseudometric family); held judge `J₀ = (A₀, r)` under `d₀`.
2. **Budgets** (C2-d2): answer drift `D_a(t) = max_j Σ_s d_{s+1}(a_j(s+1), a_j(s))` (path length); metric perturbation `η_s = sup_{x,y} |d_{s+1}(x,y) − d_s(x,y)|` (**labeled** — the identity correspondence; this is the load-bearing hypothesis, see attack 2); combined `γ = D_a + D_m`; rate `ρ = sup_t (γ(t+1) − γ(t))`.
3. **Margin** `m(x) = min_j |d_0(x, a_j(0)) − r|` — distance to the acceptance boundary; `m*` — margin against the freshest frame a policy can anchor to (≥ F-stale by D7).
4. **Freshness F** (D7): the (F,L)-bounded view discipline — the same definition that §-cross-references the session illusion (T6/T7).

**PROOF.** conjectures.md Part II:
- **Lemma 4** (perturbation accumulation): `|d_t(x,a_j(t)) − d_0(x,a_j(0))| ≤ D_a + D_m` — forward step: triangle + one perturbation; backward step: one perturbation then the triangle wholly at d_{s+1} (routing the chain through d_{s+1} is what keeps the budget at D_a + D_m, not D_a + 2D_m). Telescoping.
- **Theorem 4** (:145): verdict difference → some membership bit flipped → r lies between the two distances → `m(x) ≤ γ(t)`. Attainment: one point, one key, truth moves along the geodesic through the boundary — err = 1 while margin-mass = 1. Tight for every γ.
- **Corollary 4′**: T3(c) consumes only `d(observed, ideal) ≤ ρ` for the interposed stage; Lemma 4 supplies it with ρ = γ(t).
- **Theorem 5** (:157): (i) between re-judges, displacement ≤ ρT, decisions act on F-stale data → uncorrected ≤ ρ(T+F); apply Theorem 4 + margin-mass bound σε. (ii) solve for T. (iii) the adversary: hold truth static until the policy's anchors coincide with it, then move one key across the boundary band at rate ρ for F time units — every observation the policy can act on predates the move; at the instant the move completes, error = μ({m* ≤ ρF}), **for every policy**. (iv) AM–GM on σρT + c/T.
- **Proposition C** (zero-claw-update.md:246–262): (i) Theorem 5 re-instantiated with committee spacing δ; equal spacing minimizes max anchor age (two-line exchange argument — the only new lemma). (ii) per-reader anchoring period is mδ → Theorem 5(i) per reader. Committee cap from δ_min. Proof debts named in-source: (i)/(iii) are Theorem 5 re-instantiations; δ_min is asserted from the estimator's burn-in (B=6 windows), not measured.

**MACHINE CHECK. RUN 2026-08-29 (mathmetal lane) — bounded, exact-rational-arithmetic:** `python3 tools/verifies/floor_bench.py` → **PASS, 844,223 Fraction-arithmetic checks, 0 failures** (~50 s, stdlib, zero floats in any verdict). Bounds, printed by the run: (A) Lemma 4 accumulation on 643,125 enumerated (answer-step, offset-step) sequences (1 key, |X| = 5 line points, t ≤ 3, steps {0,±¼,±½,±1}/{0,±¼,±½}); (B) Theorem 4's drift band on 1,286,250 instances — **200,693 verdict flips observed, every one inside the band m(x) ≤ γ(t)**, plus the attainment instance at margin == γ == 2 exactly; (C) DA-T1/DA-T2 composition — certainty/soundness exact on the ¼-grid, and **annulus tightness with the equality instance exhibited** (a point at distance exactly r + Σρᵢ legally presented at exactly r → accepted: composed tolerance IS r + Σρᵢ, not tighter; the inner edge is open at r − ρ̄); (D) **the floor**: 8 two-phase adversary worlds (ρ ∈ {½,1,2}, F ∈ {1,2,3} with ρF < r/2, t* ∈ {F+2,F+4}; key 0 = the RF-T2 outward radial metric perturbation, key 1 = a geodesic answer move) × 9 policies (static, periodic T ∈ {1,2,3}, burst ×2, adaptive-verdict-trigger, seeded-random ×2) — **every policy errs ≥ φ(0, ρF), and all nine sit EXACTLY on the floor at the adversary instant** (RF-L1 executable: even mid-window anchors hold the pre-move frame); plus the RF-T1 pointwise floor under continuous drift (36 per-policy anchor-tracking checks), the F = 0 control (the floor collapses to zero — it is the freshness window, not the check), and RF-C1's warning machine-confirmed (two-sided band: φ = μ/2 exactly; quoting μ({m ≤ ρF}) overclaims by 2×); (E) RF-L4 averaging lemma on all 34 placements; (F) DA-T6/RF-T3 cost laws exact (J* = cρ/(ε₀ − ρF) at grid optima; exactly ∝ ρ at F = 0; aggregate cost independent of m, member-fresh = m·c/T_w). **Honest note on the bench's own teeth:** the pointwise arm's first run flagged 18 apparent floor violations — root cause: the bench had encoded the *max-over-directions* φ where the *realized-direction* φ belongs (a harness-semantics bug, this dossier's stronger attack in miniature); fixed. The falsifier contract stands: any schedule measuring below the swept band on assertion D1 falsifies RF-T2 — publish the instance. The Prop C δ_min *measurement* arm (empirical estimator burn-in) remains unexecuted — the one open residue of B4. The adjacent machine fact — the Switch Test's pinned-fixture arithmetic (planted drift ≤ 0.0076/dim vs noise floor ≥ 0.010/dim, checked against the SHA-pinned generator constants; zero-claw-update.md §1.3) — remains Theorem 5 applied retroactively, as before.

**ATTACK SURFACE.**
1. *"Bounded enumerators are not the general theorem."* Correct and stated: RF-T1–T4/DA-T1–T7 remain pen-proved for general metric spaces and ALL policies; the bench exhaustively verifies its enumerated classes (step sequences, grid displacements, a 9-policy family — the all-policy claim is the pen adversary's). What the bench adds: the floor is executable, and any future policy claim can be replayed against assertion D1.
2. *"The labeled-perturbation hypothesis (η over the identity correspondence) is doing hidden work."* Not hidden — it is the theorem's named closing hypothesis (conjectures.md §2.5): Gromov–Hausdorff-style *unlabeled* budgets are insufficient (a relabeling flips every verdict at zero GH cost — the counterexample shape is given); verdict stability needs pointwise stability. Reject η and you reject C2-as-stated *knowingly*; accept it and Theorems 4–5 are the full conjecture. (The bench's own legality discipline is the same lesson in miniature: its first draft realized the inward arm as an *inward radial metric perturbation*, which is not a legal pseudometric — distances can go negative; the committed bench realizes it as a geodesic answer move, exactly what RF-T2's legality proof permits.)
3. *"Committee part (ii) rests on δ_min."* Flagged in-source (zero-claw-update.md:453): asserted from B=6, not measured — the one honest debt of Prop C, and the unexecuted arm of the bench (B4 residue).
4. *"ρF is only a floor for periodic-ish policies."* The pen adversary is stated for *every* policy (any function from F-stale observations to re-anchor decisions); the bench's 9-policy class is a proper subset that includes the strongest cadence (anchor-every-tick) and an adaptive verdict-trigger — none see through the window.

**CLOSURE.** The floor theorem is the system's CAP-position statement made quantitative: **freshness caps controllability at ρF, committee redundancy pays linearly, and size is capped by the freshness window.** The general theorems are pen; the band, the annulus equality, the floor, and the cost laws are now ALSO machine-held on the enumerated class (`floor_bench.py`, bounds above). Denial of the pen part requires breaking Lemma 4's one-perturbation-per-step chain or Theorem 5(iii)'s adversary; denial of the machine layer requires running the bench and finding a schedule below the floor — which would be a *result*, and the bench's FAIL path prints it as one.

---

## §8 — Lossless compaction = fold-covered (C3): you cannot quarantine after the fact what you did not think to count

**CLAIM.** (a) **Characterization:** a compaction (summary fold + optional digest + raw suffix) is lossless for query class 𝒫 **iff** 𝒫 is fold-covered (every Q ∈ 𝒫 factors through the summary fold). The calculus's own conservation (§1) and consolidation (nest-invisibility) theorems are the first two folds — the same theorem. (b) **Counterexample:** post-hoc exclusion queries (predicates chosen *after* truncation — the essence of "what did we not train on") are **unanswerable**: unconditionally for summary-only schemes; with the digest retained, the answerer's advantage is exactly zero in the random-oracle model. (c) **Recovery:** declared-label folds + Merkle witnesses restore checkability exactly; (d) **Pricing:** post-hoc *enumeration* predicates force Ω(c) checkpoint state — no fixed-size scheme repairs (b), ever.

**DEFINITIONS.**
1. **Compaction** `K_c(L) = (σ(T₁..T_c), h(T₁..T_c), T_{c+1..n})` (C3-d1): summary fold σ (associative-commutative), Merkle root h, raw suffix. A query is *answered by the compacted ledger* iff computable from K_c **alone**.
2. **Fold-covered** (C3-d3): Q is fold-covered by σ iff ∃q̂: Q(L) = q̂(σ(L)) for all L.
3. **Post-hoc predicate**: chosen after compaction time by whoever audits later.

**PROOF.** conjectures.md Part III:
- **Theorem 6** (:205): (a) associativity+commutativity (the T4 argument) gives σ(prefix ⊎ suffix) = σ(prefix) ⊕ σ(suffix); fold-coverage answers. (b) **necessity** by contrapositive: if Q is not constant on some fiber of σ′, two prefixes with a common suffix compact identically while Q differs — no answerer can be right on both. (c) balance queries = `Σ = ℤ^Acct, f = v_T, ⊕ = +` (T4's semilattice); boundary-projection queries = T5's consolidation — literally the same algebra.
- **Counterexample 7** (§3.4): two length-2 prefixes, `P₁ = [(a:+5,b:−5), (a:−5,b:+5)]` vs `P₂ = [(c:+7,d:−7), (c:−7,d:+7)]` — both balanced sequence-wise, both net-zero on every touched account: **identical balance folds**. Q = "does the prefix contain a +5 posting?" — YES on P₁, NO on P₂. Summary-only: unanswerable, information-theoretically. With the Merkle root: the roots separate the prefixes *as strings* but the **Hiding Lemma** (ROM): roots are random-function values at distinct hidden inputs — uniform, independent of b from the answerer's perspective — advantage exactly 0. Separation is not extraction; the digest preserves *verifiability*, never *discoverability*.
- **Theorem 8:** the Λ-fold (per-declared-label counters, coordinate-wise +) answers "how many q-flagged were excluded / was any" exactly; witnesses verify in O(log c). **Corollary 9:** "list the prefix's qualifying transactions" has ≥ 2^c distinct answers on length-c prefixes ⟹ ≥ c bits of checkpoint — Ω(c), forever.

**MACHINE CHECK. RUN 2026-08-29 (mathmetal lane) — bounded, exact byte/integer arithmetic:** `python3 tools/verifies/c3_fold_bench.py` → **PASS, 565,551 checks, 0 failures** (~20 s, stdlib + SHA-256 only). Bounds, printed by the run: (A) the full fold taxonomy — balance (T4), projection (T5), count, sum, min/max, Λ-fold, product — on all 85 logs (length ≤ 3, 4-tx alphabet) × all permutations × all checkpoints: **5,138 byte-exact round-trips** (σ(P) ⊕ σ(S) == σ(L) under canonical serialization) + 680 fold-covered query answers exact through q̂; (B) **necessity exhibited concretely**: 178 equal-fold prefix pairs enumerated, the 40 carrying differing post-hoc Q each kill every answerer (identical compacted forms, differing answers, with and without a common suffix); **FC-X1 canonical**: σ_bal(P₁) == σ_bal(P₂) == the zero map while Q(P₁)=YES, Q(P₂)=NO; (C) **FC-L2 hiding, exactly**: ROM stand-in with R = 8 root values and all 56 injective seeds enumerated, all 2⁸ = 256 answerer decision rules — **max advantage exactly 0** (not ε: zero), while binding holds (h(P₁) ≠ h(P₂): separation is not extraction); (D) fiber entropy: single-account universe c ∈ {4,8,12} — 2^c prefixes into c+1 fold states, bits lost ≥ c − ⌈log₂(c+1)⌉ (= 8 at c = 12); **Ω(c)**: the positional predicate family separates all prefix pairs at c ∈ {4,8,10} (523,776 pairs at c = 10) — ≥ c bits of checkpoint, forever; (E) **FC-T3 recovery**: Λ-fold counts exact and Merkle inclusion witnesses verify on all 341 logs length ≤ 4 (2,844 checks), with forged proofs rejected at every position (a forged acceptance would be a SHA-256 collision — none occurred). **Bounded checks are bounded**: the characterization and pricing theorems remain pen-proved for arbitrary logs and query classes; the bench verifies every instance within the stated alphabet/length bounds. The bench bit twice during construction (insertion-order-sensitive serialization; a mint loop that duplicated one spec where the pair was intended) — both fixed, both harness-semantics lessons.

**ATTACK SURFACE.**
1. *"Maybe a cleverer summary than the balance fold survives."* Theorem 6(b) is a necessity result over **any** summary-only scheme — the fiber argument does not care what σ′ is, only that two prefixes map to the same summary. (The bench's [B] arm exhibits the fibers concretely for the balance fold; for arbitrary σ′ the necessity argument remains pen — the bench cannot enumerate all possible folds.)
2. *"The ROM model is an idealization."* Scoped in-source: it models the arriving-after-truncation auditor with no prefix on hand; against an auditor who *kept* the prefix, Theorem 8(b)'s witness regime is the honest answer — and it is checkable (bench arm [E] checks it: honest witnesses verify, forgeries die without a SHA-256 collision).
3. *"Just never compact."* Then the ledger is unbounded and the walk-state honesty clause (mirror-by-recomputation as the *unique* lossless compaction for non-fold-covered state — the same theorem, per conjectures.md §3.5 remark) is your policy; the theorem prices the choice. (FC-P2's permutation kill — no commutative fold of ANY size computes the ladder — remains pen; its two-element witness L₁=[cofire,shift] vs L₂=[shift,cofire] is trivially replayable by hand.)

**CLOSURE.** The conjecture as originally stated is **inverted by the result**: losslessness exists exactly over fold images; exclusion provenance survives iff declared; post-hoc enumeration is uncompressible. The general theorems are pen; the counterexample, the hiding lemma (advantage exactly 0), the fiber accounting, and the witness regime are now ALSO machine-held on the enumerated class (`c3_fold_bench.py`, bounds above). Denial requires breaking the two-line counterexample or the counting argument — or making the bench FAIL on re-run.

---

## §9 — No floats, anywhere it matters: the exact-arithmetic guarantee

**CLAIM.** Every load-bearing numeric path — RTL, generated C, Python models — runs on integers/fixed-point only, with declared saturations and one *named* truncation (§5's Theorem 5c). No IEEE-754 arithmetic participates in any verified decision.

**DEFINITIONS.**
1. **Exactness of integer chains** (CALC T11(b), quilt-calculus.md:825+; BRIDGES B6): two's-complement +, −, ×, shifts, saturate are total functions fixed by the specification — any two correct implementations agree bit-for-bit; induction over the expression tree.
2. **Verdict uniqueness** (T11(c)): a squared-form integer judge reaches the same verdict on every substrate — the divergence-about-the-verdict failure mode is impossible by construction.
3. **The one named truncation**: `(o_w·dat) >>> 15` in the effect integrator — floor semantics, −½ LSB/effect bias, √N/2 fluctuation (Theorem 5c, error-envelopes.md §5) — *quantified*, not hidden; the v2 fix (convergent/stochastic rounding) is scoped.

**PROOF.** T11(b)/(c) as above; the float-free loop budget ε = ε_b + ε_sens + ε_env assembled in BRIDGES B8; the weakest-substrate argument (the contract spans substrates, so the contract chooses integers) in SEMANTIC-TOWER §5.3.

**MACHINE CHECK (all re-run this session).**
1. **RTL:** `grep -nE '\breal\b|float|\$bitstoreal' rtl/*.v` → **zero hits** (the RTL is fixed-point by Law 1/3; saturated, sticky `o_ovf`).
2. **Generated C:** `python3 tools/tower/verify.py` — the no-floating-point-types scan of the generated source is a *built-in assertion* (live output: `floats : none in generated C`), plus `gcc -std=c99 -Wall -Wextra -Werror -O2` two-TU clean (live output quotes the flags).
3. **Python mirrors:** tapfabric renders heat "deterministically … No floats, no model calls — the same all-integer discipline" (docs/TAP-FABRIC.md §6.1) and its transcript "quotes the exact integer it used"; the golden comparisons in the TBs use `$rtoi`/explicit conversions where reals appear *only in the TB's own reference models* (the judge-consistency `$rtoi` fix is itself logged, error-envelopes.md §7.1).
4. **Widths:** the v1 weight path is overflow-free by construction — max readout sum 130,050 < 2^17 with ~3% headroom, TIGHT (Theorem 5a, error-envelopes.md §5.1); every saturation is at a named operator, sticky, viewable.

**ATTACK SURFACE.**
1. *"Reals appear in testbenches."* Yes — in the TBs' *reference models* only (golden envelopes computed in real arithmetic, compared to integer DUT outputs). The verified paths themselves are integer; the TB reals are the independent referee.
2. *"Fixed-point could still overflow silently."* The doctrine is saturate-never-wrap (Law 3, SYNTHESIS Part B), sticky-overflow latched and surfaced (`o_ovf`); the width construction above is the proof of headroom; the width-assertion-as-formal-property is gap B12.
3. *"Python floats could leak into QUF."* QUF carries Q1.15 dial/edge values as integers (tools/quf.py type table: u8..f64 *declared* but the cell sections emit integers; quf selftest golden hex is all-integer — live PASS, byte-exact round-trip).

**CLOSURE.** Denial requires a float (or silent wrap) in a verified decision path — the scans are one command each (Appendix A.8) and the compiler flags are quoted in verify.py's output.

---

## §10 — Python-model == RTL bit-exactness: **MACHINE-CHECKED at small scale** (2026-08-31, commit 3157b3d)

**CLAIM (aspirational).** The Python behavioral models (tapfabric, edgebench, tower model) are bit-exact mirrors of the RTL semantics, so conclusions drawn in Python transfer to silicon.

**WHAT IS TRUE TODAY.**
1. **Mirror-by-invariant, machine-checked:** `sim/tools/tapfabric.py` reimplements `q_hebb_edge`/`q_cell_core`/`q_dialfile` arithmetic "bit-for-bit where the RTL defines behavior" (docstring), and `sim/tools/test_tapfabric.py` asserts the RTL's own invariants (fresh cofire = exactly 256; dyadic readout and half-life shifts; the hyperbola `[1,4)` interval bracket; saturating integration `act = sclip16(act + ((u16·i16) ≫ 15))`; pre-leak fire test) — **34/34 PASS** (re-run this session). `--demo-cell` PASS.
2. **Python-vs-C IS bit-exact, machine-checked:** the tower gate diffs the compiled C against the independent Python model on 17/17 golden vectors, whole-unit exact (§5).
3. **RTL-vs-RTL differential simulation exists in the working tree:** `tb/tb_hebb_pipe.v` (currently **untracked**) differentially simulates PIPE_EFF=0 vs PIPE_EFF=1 cores on shared stimulus — ordered output-flit streams identical, `act`/`o_ftrace` bit-exact at every checkpoint. Same *method* the cosim lane needs, applied to a retime.

**WHAT IS NOT TRUE YET.** **No co-simulation commit exists.** `git log --all --oneline | grep -ci cosim` → **0** (43 commits total). There is no committed artifact that feeds *one shared stimulus stream* to the Python model and the RTL (vvp) simultaneously and diffs every output bit. The claim "Python-model == RTL bit-exact" therefore rests on (1)'s invariant-level agreement — which is *necessary but weaker*: invariants can coincide on tested schedules while bit-streams diverge on others (the honest-debt note in TAP-FABRIC.md §8: the prototype picks *one legal serialization* of tick ordering; the RTL ring interleaves — exactly the class of divergence an invariant check can miss).

**STATUS: CLOSED SMALL-SCALE (2026-08-31, commit 3157b3d; updates the PENDING text above, kept for the record).** The specified artifact landed as `tools/backend/cosim_fabric.py` + `tb/tb_cosim_fabric.v`: one shared flit program feeds the Python fabric model and the real `q_fabric_top` (NCELL=2, TPW=14) in iverilog; every egress flit (ACK/NAK with view dat, EXTID echoes, fire fanout to the host) is diffed field-for-field per pacing window; 18/18 programs bit-exact at the pinned seed (6 directed incl. fire-to-host, chained cell-to-cell fire, echo-gate probe decay + 12 seeded random), 689 egress flits; second generation at fresh seed 0x6E31FAB and 2x volume: 30/30, 1509 flits, 0 findings. Wired into `tools/backend/run_all.sh` [4/5]. **Honest scope:** (a) the tick-vs-op serialization seam is verified against the MEASURED serialization — the TB records each cell's cycle-stamped core event stream (op acceptances + serviced ticks; the Q2 interlock merges tick pulses arriving mid-service, so serviced counts are the ground truth) and the model replays exactly that — bit-exactness is proven for what the ring actually did, not for all legal serializations (a chosen-serialization model would be a stronger claim and is NOT made); (b) intra-window egress order is multiset-checked (window attribution exact); (c) NCELL=2 only; larger rings, saturation pressure, and the serdes front-end path remain covered by tb_serfabric/tb_scale_vlt at the RTL-vs-RTL level, not vs Python; (d) fire-fanout delivery to peer cells is cross-checked by matching every modeled fanout effect against the measured acceptance stream (a lost fanout flit is a FINDING). Two model-side semantics the invariant-level checks never exercised were pinned by the first random disagreement: link ACKs with a cell `src` route to that cell (consumed silently), and dial-13 `view(2)` reads the LIVE `q_echo_gate` trace (0xFFFF refill on fire, deadband-snap leak per tick), not storage. Reproduce: `python3 tools/backend/cosim_fabric.py [seed] [n_random]`.

**ATTACK SURFACE / CLOSURE.** The attack is the paragraph above, and it stands: serialization freedom + invariant-only checks = bit-exactness unproven. Gap B6, with the artifact.

---

## §11 — The hardware claim: a bitstream exists, reproducible from a committed script, at formal-proof parameters

**CLAIM.** The fabric synthesizes, places, routes, and packs on a real FPGA family (iCE40HX8K-CT256) with committed logs and a committed bitstream, at **exactly the parameters of the formal conservation proof**.

**THE NUMBERS (every one from a committed file).**
- **Config `k4b4a8e1`**: K=4 ladder buckets, B=4 bits/bucket, AGEW=8, EDGES_N=1, NCELL=2 — "EXACTLY the parameters of the formal conservation proof (formal/f_fabric_conservation.v), on the real q_fabric_top ring (2 cells + io node + 3 registered pipes + tick scheduler). No stubs" (synth/fpga-converged.ice40:3–6).
- **Yosys**: 5,800 LUT4 / 2,336 FF / 856 SB_CARRY (synth/stat_fabric2_k4b4a8e1.txt, cells table; total 9,016 cells).
- **nextpnr-ice40**: ICESTORM_LC 7400/7680 = **96%** (synth/pnr_k4b4a8e1.log:32); SB_IO 157/256 (log:34); **fmax 27.72 MHz — PASS at the 12.00 MHz target** (log:564; the earlier 29.14 MHz at log:75 is the pre-attribution pass; 27.72 is the final, post-attribution number the converged build records).
- **icepack**: `synth/fabric2_k4b4a8e1.bin` — **135,100 bytes, committed** (`git ls-files synth/` lists it; committed in `117b649` "fpga-metal"). The `.json`/`.asc` are regenerable (synth/.gitignore) from the committed script.
- **The wall is measured, not assumed**: the full v1-param config needs 10,273 LUT4 > 7,680 available (synth/sweep.tsv row `full` vs `wall_hx8k_util.txt`) — the 9-config sweep (synth/sweep.sh) found the largest config that closes timing and fits, and it is the proof-parameter config. This is the honest shape of the claim: *the proof params fit with margin; the maximal params do not fit the device and are not claimed to.*

**REPRODUCIBILITY.** The exact toolchain lines are in the committed script (synth/fpga-converged.ice40:16–25): `yosys -s synth/fpga-converged.ice40` → `nextpnr-ice40 --hx8k --package ct256 --json … --freq 12 --timing-allow-fail --pcf-allow-unconstrained --asc … --report …` → `icepack … .bin`. The RTL it reads is the same `rtl/` the TBs and proofs exercise (11 modules listed in the script).

**MACHINE CHECK.** Re-running the three commands reproduces stat/log/bin; the committed logs and bin are the record (bitstream binary equality is the strong check — same yosys/nextpnr versions assumed, which is the honest caveat of any FPGA flow).

**ATTACK SURFACE.**
1. *"No board, no proof."* Conceded and scoped: the bin is *bitstream-ready*; on-metal boot (PCF pin map, UART loader, `q_uf_loader` integration at 1,488 LUT standalone — docs/FPGA-BOOT.md:11) is a plan with measured sub-blocks, not a bring-up report. Gap B9. The claim here stops at: synthesizable, routable, timing-closed, packed, committed.
2. *"96% utilization is a fragile boast."* It is reported as a *constraint*, not a boast: it is why the full config is documented as not fitting, and why the boot lane's §4 plans the BRAM-ify move to free ~500 LC.
3. *"IO auto-placed (`--pcf-allow-unconstrained`)."* Honest: no board attached; the pin map is a listed work item (FPGA-BOOT §7), not a hidden assumption.
4. *"fmax needed `--timing-allow-fail`?"* No — the flag is belt-and-braces in the command; the log's verdict is `Max frequency … 27.72 MHz (PASS at 12.00 MHz)` — it closed timing with 2.3× margin.

**CLOSURE.** Denial requires running the three commands and getting different utilization/fmax, or showing the committed logs don't match the committed RTL (the script pins the file list). "Doesn't run on a board yet" is not a denial of this section's claim — the claim is scoped to metal-readiness, and the board gap is B9.

---

## §12 — Machine-proof completeness: every sby proof, its property in plain English, and what denying it entails

**CLAIM.** The formal surface is enumerated completely: **5 sby proofs + 1 k-induction re-proof, all PASS**, every property named, every environment assumption stated and *weaker than the real system*, and the total runtime is ~28 minutes — denial is an afternoon.

**THE COMPLETE LIST** (formal/README.md results table; all `sby -f` from repo root; engine boolector):

| # | proof | property, in plain English | mode/depth | verdict | runtime | denial would entail |
|---|---|---|---|---|---|---|
| 1 | `flit_pipe.fly.sby` | The FIFO never loses, duplicates, or reorders a flit; occupancy counters stay bounded and data emerges intact | BMC 40 | **PASS** | 65 s | a flit corruption inside the ring's pipe slices — the transport layer of §1 |
| 2 | `cell_core.fair.sby` | **I1a**: any op finishes and `ci_ready` returns within 64 cycles (tick-free). **I1b**: op + one tick service within 128. **I2**: a view accepted is answered within 66 cycles — the latency half of the session illusion | BMC 80 | **PASS** | 15 m 19 s | a starvable core — liveness under load fails, FOUNDATION D4's L loses its fabric enforcement |
| 3 | `cell_core.tick.sby` | **Q2b**: while a tick is pending, `ci_ready` stays LOW under *permanent ingress flood + arbitrary strobes* (no silent drop, no accept-ahead-of-tick). **Q2a1**: strobe → next ready pulse ≤ 100 cycles. **Q2a2**: the tick sweep's first engine command appears ≤ 66 cycles after any strobe (entry witness) | BMC 80 | **PASS** | 10 m 23 s | a deferrable tick — decay becomes traffic-mercy, freshness F stops being topology-determined |
| 4 | `fabric.conservation.sby` | §1's ledger identity: emitted == booked + in_flight + in_service + external; transport T1; serialization SER; booked-within-16 DROP; fanout addressing FAN — **re-proven 2026-08-29 with `PIPE_EFF(1)` pinned: the v2.1 effect-pipeline retime, the shipped bitstream's config** (the pre-retime committed artifacts predated `7375afb`) | BMC 55 | **PASS** | 40 s | value vanishing or appearing in transit — conservation falsified in silicon, on the retimed cone |
| 5 | `tb/formal/flit_pipe.sby` (k-induction `mode prove`, base+induction, boolector) | the flit-pipe interface contract C2–C4 (no drop/dup/over-accept, correct backpressure) **unbounded** | prove | **PASS** | <1 s | the only currently-*unbounded* proof failing — the strongest single denial target available |
| 6 | `echo_gate.dyadic.sby` (2026-08-29, mathmetal) | §2(c)'s integer core over the real gate FSM: the graded class brackets the trace into its dyadic octave (2^(PW−1) ≤ F ≪ g < 2^PW) at every cycle — the staircase that feeds the ladder's 2× envelope; plus PRIORITY (fire beats same-cycle leak), MONO (no resurrection), ZEROABSORB, DEAD (F=0 gates training, class 0), DISABLED (FLOOR=0 = v1 = always live). Covers reached (companion cover run): g ∈ {0..7} and ≥ 8 exercised | BMC 25 | **PASS** | 2 s | the gate mis-bucketing a gated cofire — the v2 graded-train path feeding the ladder the wrong staircase step |

**Completeness discipline.**
- **Environment assumptions are enumerated and each is weaker than the real system** (formal/README.md): E1 egress-always-grants (real: ring progress bounds it); E2 engine answers ≤ 12/4 cycles (real: 10/2); E3 dialfile stub with exact timing; E4 tick spacing ≥ 128 (real scheduler: 256). Proof #4 uses **no stubs at all** — real cores, real engines, real pipe.
- **Bound completeness is argued, not waved**: each BMC bound's structural worst case is computed in the README (I1a worst real op ≈ 57 cycles vs bound 64 vs depth 80; Q2a1 worst ≈ 92 vs bound 100; DROP worst ≈ 4 vs bound 16) — a violation needs a trace the depth provably covers.
- **The proofs have teeth — they bit**: two real RTL defects were found and fixed by these proofs before they passed (multi-driven `tick_pend` rejected by yosys; the `ci_ready` hole that silently dropped a flit — formal/README.md Findings 1–2, fix commit `2881b29`, "8/8 tbs still pass"). A proof suite that has never failed anything proves nothing; this one has two corpses.

**ATTACK SURFACE.**
1. *"BMC is bounded" (proofs 1–4).* True; the README's per-property worst-case analysis is the closure for the *stated* bounds, and proof 5 shows the k-induction upgrade path is real (it was done where the property admitted it). Unbounded versions of 2–4: gap B1.
2. *"Liveness is assert-within-N, not liveness."* Correct and stated: "unbounded liveness is not claimed" (README). The N's are the structural worst cases above.
3. *"Maybe the harness asserts something trivial."* Read the harnesses — f_cell_core_tick.v's header (lines 1–40) states each property in English *and* the exact mechanism it forbids (it names opencode's `tick_go && !ci_valid` skeleton as the class of failure Q2b excludes — the counterexample that became the regression).

**CLOSURE.** Denial requires one of the five to FAIL on re-run (Appendix A.1) — or the stronger attack, a demonstration that a harness's formal assertion does not encode its stated English property. Both are tractable; neither has survived contact so far.

---
---

## Appendix A — HOW TO TRY TO BREAK THIS (exact commands; denial requires different output)

All from the repo root `/home/eileen/projects/quilt-verilog`. Every command below was re-run **this session** with the quoted results, on iverilog/yosys 0.47/sby/boolector (oss-cad-suite) + gcc.

### A.1 The sby machine proofs (~28 min total)
```
sby -f formal/flit_pipe.fly.sby          # expect PASS (BMC 40, 65 s)
sby -f formal/cell_core.fair.sby         # expect PASS (BMC 80, ~15 min)
sby -f formal/cell_core.tick.sby         # expect PASS (BMC 80, ~10 min)
sby -f formal/fabric.conservation.sby    # expect PASS (BMC 55, 40 s; PIPE_EFF=1 pinned — the retime)
sby -f formal/echo_gate.dyadic.sby       # expect PASS (BMC 25, 2 s; the §2(c) dyadic bracket on the gate)
sby -f tb/formal/flit_pipe.sby           # expect PASS (k-induction prove, <1 s, unbounded)
```
Deny by: a FAIL, or a CEX trace. The trace is then either a real RTL bug (the proofs have found two before — check `git log 2881b29`; and the echo-gate harness's own construction found two harness bugs — a same-edge sampling error and a 16-bit shift overflow at g=0 — before it passed clean) or the harness encodes the wrong property — read `formal/f_*.v` headers against their asserts.

### A.2 The RTL testbenches (iverilog; each seconds-to-minutes)
```
for tb in tb_cell_core tb_fabric_smoke tb_fabric_smoke_v2 tb_hebb_edge \
          tb_hyperbola_tail tb_judge_consistency tb_rqh_saturation \
          tb_q_echo_gate tb_q_rqh_bank; do
  iverilog -g2005 -s $tb -o /tmp/$tb.vvp tb/$tb.v rtl/*.v && vvp /tmp/$tb.vvp | tail -2
done
# expect: 9× "<NAME> PASS" lines (verified this session; smoke prints maxlat=31)
```
Deny by: any nonzero-error report. Then bisect: the failing assertion names its theorem (each TB header cites the doc section it enforces).

### A.3 The tower L0→L2 gate (Python model vs compiled C, golden vectors, no-float scan)
```
python3 tools/tower/verify.py            # expect RESULT: PASS — 17/17 golden, floats: none, gcc -Werror clean
python3 tools/tower/emith.py tools/tower/oil-pressure-port.cell.yaml | head -40   # audit the generated C against the YAML by eye
```

### A.4 The QUF substrate (state-is-a-file)
```
python3 tools/quf.py selftest            # expect PASS, byte-exact round-trip, golden hex printed
bash tools/run_quf_tb.sh                 # python create → iverilog → vvp: the loader decodes what the encoder wrote
```

### A.5 The Python fabric mirrors (RTL-exact invariants + judgment semantics)
```
python3 -m unittest discover -s sim/tools -p 'test_*.py'   # expect: Ran 34 tests — OK
python3 sim/tools/tapfabric.py sim/fixtures/tap-session-01.jsonl --out /tmp/tap_room
python3 tools/quf.py verify /tmp/tap_room.quf              # expect structural PASS
python3 sim/tools/tapfabric.py --demo-cell                 # expect: demo-cell PASS
```

### A.6 The hardware flow (yosys + nextpnr + icepack; needs the oss-cad-suite)
```
yosys -s synth/fpga-converged.ice40                       # expect stat: 5800 LUT4 / 2336 FF / 856 SB_CARRY
nextpnr-ice40 --hx8k --package ct256 \
  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained \
  --asc synth/fabric2_k4b4a8e1.asc --report synth/report_k4b4a8e1.json
# expect log: ICESTORM_LC 7400/7680 (96%), SB_IO 157/256,
#            Max frequency 27.72 MHz (PASS at 12.00 MHz)
icepack synth/fabric2_k4b4a8e1.asc /tmp/check.bin && cmp /tmp/check.bin synth/fabric2_k4b4a8e1.bin
# expect: identical (same tool versions) — the committed 135,100-byte bitstream reproduces
```

### A.7 The academic-theorem verifiers (§6–§8: exact-arithmetic enumerators, RUN 2026-08-29)
```
python3 tools/verifies/floor_bench.py     # expect RESULT: PASS — 844,223 Fraction checks
                                          #   (Lemma 4, drift band + attainment, annulus
                                          #    equality, rho*F floor over 9 policies, RF-C1,
                                          #    RF-L4, cost laws; ~50 s)
python3 tools/verifies/c1_seam_bench.py   # expect RESULT: PASS — 87,245 integer checks
                                          #   (Lemma 1 meters, fork constants, Counterexample 2
                                          #    executable + generalized, structural-nonce closure
                                          #    + loud join; ~4 s)
python3 tools/verifies/c3_fold_bench.py   # expect RESULT: PASS — 565,551 checks
                                          #   (taxonomy folds byte-exact, fiber kills, FC-X1,
                                          #    ROM hiding advantage exactly 0, fiber entropy,
                                          #    Omega(c), Merkle witnesses; ~20 s)
```
Deny by: any FAIL line (printed loudly with the instance). A schedule below the floor falsifies RF-T2; a silent structural-nonce join falsifies Theorem 3; a fiber pair answered after compaction falsifies FC-T1. The enumerators are bounded — their runs print the instance bounds; the general theorems remain pen (§6–§8 proofs). Remaining falsifier still on paper: §3's fuzz harness (gap B2). **The return leg is recorded in `docs/academic/RETURN.md`** — what the metal taught the math: two in-source amendments (RF-T2's inward-arm legality, §2(c)'s Fmax pin), six forced decisions, the FAILs and their lessons, and the changed-things ledger.

### A.8 The no-float scans
```
grep -nE '\breal\b|float|\$bitstoreal|\$realtobits' rtl/*.v    # expect: no hits
grep -n "float\|double" tools/tower/oil_pressure_port.c 2>/dev/null || \
  python3 tools/tower/emith.py tools/tower/oil-pressure-port.cell.yaml | grep -n "float\|double"
# expect: no hits (verify.py's built-in scan already asserts this on the generated file)
```

### A.9 The provenance checks (numbers → files)
```
git log --oneline | head -45            # the lane history (43 commits at dossier time)
git log --format='%h %s' -1 -- synth/fabric2_k4b4a8e1.bin     # expect 117b649 fpga-metal
python3 tools/backend/cosim_fabric.py                          # §10 small-scale cosim: 18/18 bit-exact
wc -c synth/fabric2_k4b4a8e1.bin                               # expect 135100
sed -n '32p;34p;564p' synth/pnr_k4b4a8e1.log                   # LC util / IO / fmax lines
```

---

## Appendix B — the open-gaps register (what is NOT yet machine-checked; each with its exact closing artifact)

| # | gap | section | closing artifact (exact) | size |
|---|---|---|---|---|
| B1 | sby proofs 2–4 are BMC-bounded, not unbounded (only flit_pipe is k-inductive) | §12 | `formal/cell_core.{fair,tick}.prove.sby` + `fabric.conservation.prove.sby` in `mode prove` (the tb/formal/flit_pipe.sby pattern; invariants likely need strengthening lemmas — the README's shadow countdowns are the starting set) | days |
| B2 | ladder/hyperbola envelope monitors: Theorems 1–2 checked on ONE schedule + census sweeps, not all streams | §3 | random-stream fuzz TB + k-induction monitors (ABSTRACTION-MATH §4.3 checks #5/#6; error-envelopes.md §7 row 1: "~30 lines each," flit_pipe precedent says seconds-to-minutes) | hours |
| B3 | ~~C1 partition/seam theorems unexecuted~~ **CLOSED-BOUNDED 2026-08-29**: `tools/verifies/c1_seam_bench.py` PASS (87,245 checks; bounds in §6). Residue: the flapping/asymmetric-seam composition lemma, still pen | §6 | write the composition lemma (bookkeeping, not insight); optionally widen the enumerator's alphabet/length bounds | hours |
| B4 | ~~C2 ρ·F floor + Prop C unexecuted~~ **CLOSED-BOUNDED 2026-08-29**: `tools/verifies/floor_bench.py` PASS (844,223 exact checks; bounds in §7; floor + band + annulus equality + cost laws). Residue: the δ_min *measurement* for Prop C(ii) (empirical estimator burn-in) | §7 | measure δ_min on the real estimator (B = 6 windows), wire into the RF-T4 phase diagram | a day |
| B5 | ~~C3 fold theorems unexecuted~~ **CLOSED-BOUNDED 2026-08-29**: `tools/verifies/c3_fold_bench.py` PASS (565,551 checks; bounds in §8; FC-X1 + ROM hiding advantage-exactly-0 + Ω(c) + witnesses). Residue: ε-frontier for exclusion-family folds (survey-level, unchanged) | §8 | — (the closed half was the registered artifact) | — |
| ~~B6~~ | **CLOSED small-scale 2026-08-31** (commit 3157b3d): fabric-level measured-serialization cosim on `q_fabric_top`, NCELL=2 — 18/18 + 30/30 (fresh seed, 2x) programs bit-exact, 2198 egress flits total; named residues: measured (not universal) serialization, multiset intra-window order, NCELL=2, serdes path RTL-vs-RTL only | §10 | scale-out lane (NCELL>2, saturation pressure, Python-vs-serdes) | — |
| B7 | echo gate: sby proof **HALF-CLOSED 2026-08-29** (`formal/echo_gate.dyadic.sby` PASS — the §2(c) bracket + FSM safety at BMC 25); RQH bank still TB-only | §2, §4 | `formal/rqh_bank.sby` (BMC first; the bank is small) | hours–days |
| B8 | act truncation-bias test missing (−½ LSB/effect is proven, not measured) | §9 | long-stream TB asserting `act` vs convergent-rounded ideal within `N/2 ± √N/2`; threshold-shift (fire latency vs N) companion (error-envelopes.md §7 row 8) | hours |
| B9 | hardware: no on-metal boot yet (bin is bitstream-ready; PCF/UART/loader integration planned) | §11 | FPGA-BOOT.md §2–§7 executed: boot_top + uart_serializer + q_uf_loader on HX8K board, UART warm-load of a QUF, one view round-trip on metal | days + board |
| B10 | ln-strength LUT (`view(3)`) proposal-level; no unit, no TB | (SYNTHESIS degrade path) | build `q_qs_ln` + exhaustive Q4.12 sweep vs `$ln` (glm's tb plan; error-envelopes.md §7 row 9) | days |
| B11 | ~~uncommitted PIPE_EFF retime~~ **CLOSED before this dossier update**: the retime + `tb/tb_hebb_pipe.v` landed in `7375afb` (fpga-round3: 27.72→40.44 MHz, equivalence-proven bit-exact by the differential TB); and 2026-08-29 (mathmetal) the conservation proof was re-run with `PIPE_EFF(1)` pinned — §1's ledger identity now formally covers the shipped retime | §1, §10 note | — (closed) | — |
| B12 | width-construction assertion (130,050 < 2^17) is prose, not a checked property | §9 | `localparam`-check TB or formal assert on the accumulator max (error-envelopes.md §7 row 7) | hours |

**Reading of the register:** 12 of 12 claim sections are machine-checked today (§1–§5, §9, §11, §12 end-to-end; §6, §7, §8 as bounded exact-arithmetic enumerators — every instance in the printed bounds, the general theorems still pen; §10 small-scale measured-serialization cosim, commit 3157b3d). Gaps B3/B4/B5 closed-bounded with named residues (composition lemma, δ_min measurement, ε-frontier); B7 half-closed. Nothing in the dossier rests on an unrun machine check being secretly run — the register is the boundary, and each line names the artifact that erases it.

---

## Final tally

- **Claim sections: 12** (conservation; fire-vs-train/echo; 2× ladder; RQH deposit + falsification history; covering/snap; C1 dichotomy + seam; C2 drift/ρ·F floor + committee; C3 fold/losslessness; no-float; Python==RTL status; hardware; proof completeness).
- **Machine-checked: 11** (§1 sby, re-proven at PIPE_EFF=1; §2 3×TB+formal, now incl. echo_gate.dyadic; §3 2×TB+34 tests; §4 2×TB with measured verdicts; §5 TB+golden vectors; §9 scans+compiler flags; §11 reproducible committed flow; §12 six proofs PASS; §6/§7/§8 bounded exact-arithmetic enumerators — `tools/verifies/` 1,497,019 checks total, zero floats).
- **Pen-only with specified machine checks: 0** (§6, §7, §8 flipped 2026-08-29 by the mathmetal lane — bounded, bounds stated in-section).
- **Pending: 0** (§10 closed small-scale 2026-08-31, commit 3157b3d; scale-out residues named in §10).
- **Open gaps: 7 + residues** (B1, B2, B6, B8, B9, B10, B12 open; B7 half-closed; B3/B4/B5 closed-bounded with residues; B11 closed via `7375afb` + the PIPE_EFF=1 re-proof), each with its exact closing artifact and a size estimate.
- **Own goals on display, by design:** the 9,100×→18,262× constant correction (§4), the snap-transaction balance repair (§5), the hyperbola envelope direction inversion + floor-tail failure 2,713/3,825 (§3 lineage), the ci_ready silent-drop caught by the proofs themselves (§1, §12), the TB that caught iverilog's real-conversion rounding (§5), and the mathmetal lane's four harness bugs caught by the checks' own failure paths before any of them passed (§6×2, §7×2, §8×2, plus the echo-gate sby's same-edge sampling and 16-bit shift overflow) — a dossier that never caught its own errors would be asking for trust; this one asks for a terminal.

*Mathmetal lane addendum (2026-08-29): the three academic verifiers and the echo-gate sby were built to falsify, not to decorate — every artifact here has bit its author at least once during construction, which is the cheapest evidence that the checks are not ceremonial. The bounded enumerators print their bounds on every run; bounded checks are bounded, and the general theorems remain where they were proved. The round trip's return cargo — where the metal changed the math — is `docs/academic/RETURN.md`: verification changed both ends.*

*Breakdown lane, 2026-08-29. Deny by running. The commands are above.*
