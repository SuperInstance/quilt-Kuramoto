# ERROR ENVELOPES — every numeric claim on the board, stated, proved, and graded

**Lane:** error-envelopes (Flash — the numerical-rigor pass) · **Date:** 2026-08-29
**Inputs:** `docs/{FOUNDATION,SEMANTIC-TOWER,ABSTRACTION-MATH,QUANT-RESEARCH,SYNTHESIS,INNOVATION-JUDGEMENT}.md`, `proposals/{glm,zeroclaw}/ARCHITECTURE.md`, `proposals/innovations/flash.md`, ai-writings research/67 (dyadic staircases) and 70 (semantic tower), `rtl/{q_hebb_edge,q_cell_core}.v`, `tb/{tb_hebb_edge,tb_fabric_smoke,tb_cell_core}.v`, `tb/formal/`.
**Companions:** `docs/academic/quilt-calculus.md` (the cell calculus; its covering-radius theorem is our Theorem 4, treated here with the measurement-geometry generalization), `docs/ABSTRACTION-MATH.md` §5 (the bounds' first statement).

> **The contract of this document.** Five claims are load-bearing on the board:
> (1) the age-bucket ladder's factor-2 decay bound; (2) zeroclaw's hyperbolic `[1,4)` interval envelope; (3) RQH's re-injected residue "asymptotically tightening" the envelope; (4) the snap covering inequality `b√n/2 ≤ ε`; (5) the end-to-end fixed-point error of a full hebbian update (`base + ln(1+W)` with ladder `W`). For each: **statement, proof, and a tight/loose grade.** Where the board's prose and the RTL disagree, the RTL and the testbenches win, and the correction is logged. Six corrections are logged in §0 — C1–C3 (found while writing this document) and C4–C6 (found by the machine-validation lane `tb-envelope`, 2026-08-29, when the three missing testbenches were built) — the reader should see the corrections before the proofs, so the proofs are not read through the wrong lens.

---

## 0. Correction ledger (read first)

Six claims are wrong as written. C1–C3: board-level (two implemented correctly in RTL/testbench with wrong prose, one wrong in the design itself). C4–C6: found 2026-08-29 by the tb-envelope machine-validation lane (two theorem statements in this document, one arithmetic constant). All are repaired below; C4–C6 carry their testbench evidence inline.

**C1 — the hyperbolic trajectory envelope has the parameter direction inverted (ABSTRACTION-MATH §5.2, paper 67 §2.2).** Both documents state

```
W_true(P₀) ≤ W_rtl ≤ W_true(P₀/4)        (as written — wrong)
```

The testbench asserts the opposite parameter order — `ghi = 100/(1+100·t/(4·4096))`, i.e. `W_true(4·P₀)`, the *slow* curve — and passes. The discrete engine's decrement interval is `Δ(W) ∈ [P₀/W², 4P₀/W²)`: **never shorter than the exact interval, up to 4× longer**; waiting longer decays slower, so the discrete trajectory sits *above* the fast curve and *below* the slow one. The correct statement (Theorem 2) is

```
W_true(P₀; t) − 1 ≤ W_rtl(t) ≤ W_true(4P₀; t)      (correct — this is what tb/tb_hebb_edge.v asserts)
```

`W_true(P₀/4)` is a curve four times *faster* than the fast one; the observed readout violates it massively (at t = 256, W₀ = 100, P₀ = 4096: `W_rtl = 26`, `W_true(P₀/4) = 3.85`). The general-k form is `W_true(P₀) − 1 ≤ W_rtl ≤ W_true(2^k·P₀)`.

**C2 — the staircase theorem's doubling property is shift-doubling, not scale-doubling (paper 67 §2.1).** Paper 67 states the property `w(a) ≤ b·w(ba)` ("b-doubling") and claims the exponential law `2^(−a/H)` satisfies it "exactly at the bucket grid." It does not: `2^(−a/H) ≤ 2·2^(−2a/H) ⟺ a ≤ H`, false for `a > H`. The exponential satisfies the **shift-doubling** property `w(a) = b·w(a+H)` — exactly, for all a — which is the property the v1 ladder actually uses (glm's own statement in `proposals/glm/ARCHITECTURE.md` §3.1 is correct: linear buckets `[iH, (i+1)H)` with grid-exact weights `2^(−i) = w(iH)`). Paper 67's dyadic bucket convention `[b^i H, b^(i+1)H)` makes its proof line `w(b^i H) = b^(−i)` false for the exponential (`w(b^i H) = b^(−b^i) ≠ b^(−i)`). Theorem 1 below is restated with the operative (RTL-matching) convention; the scale-doubling form is noted for power laws, and paper 67's "power laws are exact on shift ladders" is downgraded to *asymptotically* exact on the as-built linear buckets (§1.4).

**C3 — RQH's "asymptotically closes the envelope" has no as-built mechanism (proposals/innovations/flash.md).** The strong claim — the corrected readout converges toward the exact memory law, tightening inside the `2×` / `[1,4)` band — fails in both directions: the credit is non-negative, so it *widens* the upper ratio band (`Ŵ+C ∈ [W, 2W+C]`); and its deposit `2^g` is not the underpay statistic. The exact convergence condition is derived in Theorem 3: a credit can only *center* (never close) the band, and centering requires `deposit(g) = 2^QDW·E[overstatement | class g] = 2^(K+QDW−g)·(1 − 1/(2 ln 2))`, which the as-built `2^g` satisfies only at `g ≈ 7.1` (K = QDW = 8). What RQH provably delivers — boundedness, envelope preservation, anticipation cadence — is also Theorem 3. The proposal's own honest limits (§6.1–6.2) already conceded most of this; C3 quantifies it.

**C4 — Theorem 2a's floor-1 parenthetical is wrong: the tick-granularity floor breaks the upper edge, not the lower (found by `tb/tb_hyperbola_tail.v`, 2026-08-29).** The proof's parenthetical "(the floor-1 rule only tightens the lower edge at W=1)" fails: when `4P₀/W² < 1` (i.e. `W ≥ 2√P₀`), the interval is floored to `Δ = 1 ≥ 4P₀/W²`, violating the half-open upper edge. Machine census: **2,713 of 3,825 swept (P₀, W) pairs violate the band as written** — every pair with `W ≥ 2√P₀`. The corrected band is `Δ(W) ∈ [P₀/W², max(1, 4P₀/W²)]` with `Δ = 1` exactly in the floored regime; the lower edge `Δ ≥ P₀/W²` holds unconditionally (verified on all 3,825 pairs). T5's config (W₀ = 100 < 2√4096 = 128) never entered the violating region — that is why it passed.

**C5 — Theorem 2b's "upper bound is exact" holds only at level crossings; universally the upper bound needs its +1 slack too (found by `tb/tb_hyperbola_tail.v`, 2026-08-29).** Between crossings the staircase holds a level while the slow curve falls through it (W₀ = 3, P₀ = 8, t = 1: `W_rtl = 3 > W_true(4P₀) = 2.73`); the tail sweep counts **13 upper no-slack ticks** alongside **8,302 lower no-slack ticks** (the W = 1 plateau of the big config). The ±1 slack the TB asserts is necessary on **both** sides; "upper exact and tight" is downgraded to "exact at crossings, ±1 universally."

**C6 — the class-0 RQH shortfall constant is off by 2.004×: the honest factor is ~18,262×, not ~9,100× (measured by `tb/tb_rqh_saturation.v`, 2026-08-29).** The doc's own formula at g = 0 gives `2^(K+QDW)·(1 − 1/(2 ln 2)) = 2¹⁶·0.27865 = 18,261.8`; the "~9,100×" is a 2¹⁵ slip. Same conclusion (the as-built deposit is ~10⁴× too small), corrected constant. The corrected deposit itself stages to `[18260, 9130, 4565, 2283, 1141, 571, 285, 143]` quanta (within 2 of exact at every class).



---

## 1. Theorem 1 — the age-bucket ladder: the 2× bound, arbitrary arrivals

### 1.1 Setup (as built)

The v1 ladder (`rtl/q_hebb_edge.v`, MODE=0) keeps K bucket counters `C_0…C_{K−1}` (K=8, B=8 bits each). A cofire (train command) increments `C_0` (saturating, sticky `o_ovf`). Every `H = i_hl` tick commands, the ladder shifts: `C_i ← C_{i−1}`, `C_0 ← 0`, `C_{K−1}` retires. Bucket *i* therefore holds events with age `a ∈ [iH, (i+1)H)` and carries implied weight `2^(−i)`, realized as a *wire shift*: the readout places bucket *i* at bit offset `K−i` of a `K+B+1`-bit accumulator, so one fresh cofire reads `2^K = 256`. In normalized units (fresh cofire = 1), the readout is

```
Ŵ = Σ_i C_i · 2^(−i)        (the true exponential-law weight of event e is w(a_e) = 2^(−a_e/H))
```

The readout sum itself is **exact integer arithmetic**: counts are integers, weights are powers of two, the sum is a shift-and-add. There is no rounding in the readout at all — the only "error" is the *model* error between the staircase and the continuous law.

### 1.2 Theorem (staircase envelope; arbitrary arrivals)

> **Theorem 1.** Let `w(a) = 2^(−a/H)` (H > 0), and let events arrive at *arbitrary* times — any sequence, any inter-arrival distribution, adversarial or random, dependent or independent; no assumption is made or used. Bucket events by `floor(a_e/H)` and assign weight `2^(−floor(a_e/H))` (the phase-aligned assignment). Then at every read instant
>
> ```
> W ≤ Ŵ < 2W ,        W := Σ_e 2^(−a_e/H)
> ```
>
> where the upper bound is approached but not attained (`Ŵ ≤ 2W` with equality only in the limit).

**Proof.** For an event with age `a ∈ [iH, (i+1)H)`: by strict monotonicity of `w`, `w(a) ∈ (w((i+1)H), w(iH)] = (2^(−(i+1)), 2^(−i)]`. The assigned weight `2^(−i)` therefore overstates the true weight by a factor in `[1, 2)`. Summing over all events: `W ≤ Ŵ < 2W`. ∎

The proof uses exactly three facts — (i) `w` strictly decreasing, (ii) the grid-exact values `w(iH) = 2^(−i)` (the half-life property `w(a) = 2·w(a+H)`), (iii) each event is in exactly one bucket — and **none of them mentions how the events got there**. Hence: the bound holds for every arrival stream, at every instant, with no statistical hypothesis. This is the strongest possible form: *adversarial arrivals* are inside the theorem.

**The as-built ±1-class phase.** The RTL shifts on global half-life boundaries, not per-event timers. An event arriving at `t₀` and read at `t` sits in bucket `g = #(shifts in (t₀, t])`, and `g ∈ {⌊(t−t₀)/H⌋, ⌊(t−t₀)/H⌋+1}` — the phase ambiguity the testbench documents. In the `+1` phase the assigned weight is `2^(−(i+1))`, one class too old, and the per-event ratio can fall to `1/2`. The as-built symmetric envelope is therefore

```
W/2 − 1 ≤ Ŵ ≤ 2W + 1        (integer form; the ±1 is the integer-vs-real slack of the golden model)
```

which is exactly what `tb/tb_hebb_edge.v` T2 asserts (`wexp/2.0 − 1.0 <= wint && wint <= 2.0*wexp + 1.0`). Both ends are reachable: the `2W` end by events clustered just *below* a shift boundary (aligned phase), the `W/2` end by events that arrive just *after* a shift boundary and are read before the next (mis-phase). The v1 `tb/tb_fabric_smoke.v` additionally asserts the *exact* unshifted case: `wsum == base + N·2^8` for N cofires before any half-life shift — zero error in the regime the acceptance gate's golden value lives in.

### 1.3 Tightness

- **TIGHT as a worst-case bound.** The per-event overstatement ratio can approach 2 (age → (i+1)H⁻, aligned phase): sup ratio = 2, attained in the limit. The mis-phase ratio can approach 1/2. No smaller multiplicative band is possible for an assignment that depends only on the bucket.
- **LOOSE in expectation.** For ages uniform in `[iH, (i+1)H)` (the natural null model of arrival times), `E[2^(−a/H) | bucket i] = 2^(−i)/(2 ln 2)`, so `E[Ŵ/W] = 2 ln 2 ≈ 1.386` — the readout overstates by ~39% on average, not 100%. The gap between the 1.386 expectation and the 2.0 worst case is the *staircase's* price; it is the same gap that RQH (Theorem 3) cannot close with a one-sided credit.
- **The retirement tail is exact and small:** an event older than `K·H` contributes `< 2^(−K)` of a fresh cofire — for K=8, `< 0.39%`, and it is *dropped*, not approximated.

### 1.4 Generalizations (the board's, graded)

1. **Base-b ladders.** Buckets `[iH, (i+1)H)` with implied weights `b^(−i)` (shift of `i·log₂ b` bits) overstate by `∈ [1, b)`: `W ≤ Ŵ ≤ b·W`. The v1 ladder is b=2. A "coarse ladder" (p-bit shifts, b = 2^p) trades envelope factor `2^p` for `K/p` fewer buckets — a documented v2 dial slot. TIGHT as a bound, per-bucket.
2. **The scale-doubling form (paper 67's `D_b`).** The property `w(a) ≤ b·w(ba)` is satisfied by *power laws* `w(a) = (H/a)^k` with `k ≤ 1` (equality at k = 1), not by the exponential (C2). Its role: if the *target law* is such a power law and the buckets are linear, the per-bucket ratio `w(iH)/w((i+1)H) = (1 + 1/i)^k → 1`, so the relative error of the staircase *vanishes* as i grows: a shift-ladder represents a power-law tail with asymptotically vanishing relative error — the structural reason MODE=0 (ladder) and MODE=1 (hyperbola, whose tail `W(t) ≈ P₀/t` is the k=1 power law) can share one register file. Paper 67's "exact" is an overstatement; *asymptotically exact* is the correct grade.
3. **Exponential histograms.** The ladder is the ε=1 case of Datar–Gionis–Indyk–Motwani's dyadic exponential histogram (SODA 2002), which admits (1+ε)-tunable envelopes at more buckets. Our bound is the ε=1 member of that family.

**Bottom line (T1):** `W/2 − 1 ≤ Ŵ ≤ 2W + 1` on the as-built ladder, for arbitrary arrivals; TIGHT at both ends, ~1.39× expected. Zero arithmetic error in the readout itself.

---

## 2. Theorem 2 — zeroclaw's hyperbolic decay: the [1,4) interval envelope (corrected)

### 2.1 Setup (as built)

The hyperbola engine (MODE=1) maintains integer `W`, `age`. Every tick: `age++`; when `age ≥ Δ(W) := max(1, P₀ >> (2·msb W))` and `W > 0`: `W ← W−1`, `age ← 0`. (`msb W = ⌊log₂ W⌋`, one priority encoder; `P₀ = 2^P0E` is the decay horizon dial.) The continuous target is the Riccati death process

```
dW/dt = −W²/P₀      ⟹      W_true(P; t) = W₀/(1 + W₀ t / P) .
```

### 2.2 Theorem — the interval band (exact, tight)

> **Theorem 2a (interval band).** For all integer W ≥ 1,
>
> ```
> Δ(W) ∈ [P₀/W² , 4P₀/W²) ,
> ```
>
> i.e. the decrement interval is within `[1, 4)×` of the exact interval-at-current-W, `P₀/W²`.

**Proof.** `m = ⌊log₂ W⌋ ⟹ W ∈ [2^m, 2^{m+1}) ⟹ W² ∈ [2^{2m}, 2^{2m+2})`. Hence `2^{2m} ∈ (W²/4, W²]` and `Δ(W) = P₀ >> 2m = ⌊P₀/2^{2m}⌋` satisfies `P₀/W² ≤ Δ(W) < 4P₀/W²` — exact in the unfloored regime `W < 2√P₀`, where `P₀/2^{2m}` is a power of two (the floor is exact). In the floored tail `W ≥ 2√P₀` the upper edge **fails** (C4): the corrected band is `Δ(W) ∈ [P₀/W², max(1, 4P₀/W²)]` with `Δ = 1` exactly. **Machine-checked: `tb/tb_hyperbola_tail.v` (TA: 3,825-pair formula sweep; TB: per-level DUT cadence bit-exact vs `max(1, P₀ >> 2·msb L))`.** ∎

**Tightness.** Lower end *attained* at dyadic W (`W = 2^m ⟹ Δ = P₀/W²` exactly); upper end *approached* as `W → 2^{m+1}⁻` (`Δ → 4P₀/W²` from below — hence the half-open `[1,4)`). **TIGHT: both ends achievable.**

The k-parameter generalization: `Δ_k(W) = P₀ >> (k·msb W) ∈ [P₀/W^k, 2^k·P₀/W^k)` — the "2^k-factor envelope," k=2 being the shipped case. Same proof with `W^k ∈ [2^{km}, 2^{k(m+1)})`.

### 2.3 Theorem — the trajectory envelope (corrected; upper exact, lower up to +1)

> **Theorem 2b (trajectory).** Let `τ_n` be the tick at which the discrete engine first reaches level `W₀ − n` (τ₀ = 0), and let `T_n(P) = P(1/(W₀−n) − 1/W₀)` be the crossing time of the exact solution with parameter P. Then for all n < W₀:
>
> ```
> τ_n ≤ T_n(4P₀)                     (discrete crosses every level no later than the slow curve)
> ```
>
> and hence, for all t ≥ 0,
>
> ```
> W_true(P₀; t) − 1 ≤ W_rtl(t) ≤ W_true(4P₀; t) .
> ```
>
> The upper bound is exact and tight *at level crossings*; universally it also needs the +1 integer slack (C5 — between crossings the staircase holds a level while the slow curve falls through it; 13 upper no-slack ticks witnessed). The lower bound requires the additive slack of 1, which is genuinely necessary (the discrete engine reaches W = 0 in finite time; the exact hyperbola never does) and is the slack the testbench asserts.

**Proof (upper).** Between levels the engine waits `Δ(W)`; the exact solution at parameter `4P₀` takes `(4P₀)/(W(W−1))` to fall from level W to W−1 (integrating `dt = (4P₀/u²) du`). Since `Δ(W) ≤ 4P₀/W² ≤ 4P₀/(W(W−1))` (as `W² ≥ W(W−1)`), each discrete wait is no longer than the slow curve's wait at the same level, so by induction over levels `τ_n = Σ Δ(W₀−k) ≤ Σ 4P₀/((W₀−k)(W₀−k−1)) = T_n(4P₀)`. The discrete process is therefore never below the slow solution: `W_rtl(t) ≤ W_true(4P₀; t)`. **Tight:** at the top of each dyadic band (`W ≈ 2^{m+1}`), `Δ ≈ 4P₀/W²` equals the slow curve's local interval, and the two trajectories nearly coincide for long stretches. ∎

**Proof (lower, with the slack).** Two facts. (i) The only way the discrete can cross a level *before* the fast curve is at dyadic-bottom levels, where `Δ(W) = P₀/2^{2m} < P₀/(W(W−1))`; the deficit per such level is `P₀/(W(W−1)) − P₀/W² = P₀/(W²(W−1)) ≤ P₀/(W−1)³`, and it is reabsorbed within the same band (at all other levels of the band `Δ ≥ P₀/W² > P₀/(W(W−1))·(W−1)/W`, i.e. the discrete waits *longer* than fast and falls behind). The maximum time-deficit the discrete can accumulate relative to the fast curve is therefore confined to the small-W tail. (ii) At `W = 1` the engine spends a full `Δ(1) = P₀` ticks, which exceeds the fast curve's time to fall from `W₀` to `1`, `T_1(P₀) = P₀(1 − 1/W₀) < P₀`. The W=1 plateau alone absorbs the entire tail deficit; at every other level the deficit is below one unit of W. Hence `W_true(P₀; t) − 1 ≤ W_rtl(t)` for all t. The slack is used exactly once: `W_rtl` sits at 0 for `t ≥ τ_{W₀}` while `W_true(P₀; t) > 0` forever. **TIGHT in the tail** (the slack cannot be removed); empirically tight in the body (measured gap ≤ 1 over the full simulated horizon, `tb/tb_hebb_edge.v` T5, verified by trace: at t = 4096, `W_rtl = 1` vs `W_true(P₀) = 0.99`). ∎

**The ±1 integer slack in the testbench.** T5 asserts `glo − 1 ≤ wint ≤ ghi + 1` with `glo = W_true(P₀; t)`, `ghi = W_true(4P₀; t)` — the `+1`/`−1` are the integer-vs-real conversions (W_rtl is an integer). Note the TB's own comment "W_true(P₀) ≤ W_rtl ≤ W_true(t/4)" has the same parameter typo as the prose (C1); the *code* is correct (`100.0·t/(4.0·4096.0)` = `W_true(4P₀)`).

### 2.4 The [1,4) claim, once more, in one line

The decrement interval is `∈ [1,4)×` the exact interval at current W — **that** is the [1,4) that is exact and tight (2a). The trajectory is trapped between the exact solutions whose parameters bracket the interval band — `[W_true(P₀), W_true(4P₀)]` — because a longer interval means a slower decay (2b). The board's "`W_true(P₀/4)`" swapped the direction (C1).

**Bottom line (T2):** interval band `[1,4)` TIGHT; trajectory `W_true(P₀) − 1 ≤ W_rtl ≤ W_true(4P₀)` — upper exact/tight, lower exact up to the necessary +1 slack.

---

## 3. Theorem 3 — RQH residue banking: what converges, what does not

### 3.1 Setup

RQH (`proposals/innovations/flash.md`) wraps the engine with a per-edge quantum reservoir `R` (RW=16, saturating, deadband-leaked): a class-g cofire deposits `2^g` quanta; `R` leaks `R ← R − (R >> QLEAK)` per tick, snapping to 0 at ≤ 1; the readout credit is `C = R[15:8]` (high byte; `QDW=8` quanta per credit, 1 credit = 1 readout LSB); `o_antic` pulses on a high-byte carry. Corrected readout: `Ŵ_RQH = base + eng + C` (saturating). Claim under examination: *re-injected residue asymptotically tightens the envelope toward the exact law.*

In readout units (`2^K` = 256 per fresh cofire), a class-g event's true exponential weight is `2^(K−a/H) ∈ (2^(K−g−1), 2^(K−g)]`; the assigned weight `2^(K−g)` overstates by `u ∈ [0, 2^(K−g−1))` (aligned phase), with `E[u | g] = 2^(K−g)·(1 − 1/(2 ln 2)) = 2^(K−g)·0.2787` for uniform ages.

### 3.2 Theorem — the three provable properties and the convergence condition

> **Theorem 3a (bounded perturbation; exact, tight).** For all t, all streams, `0 ≤ C(t) ≤ 2^(RW−QDW) − 1 = 255` LSB, and `|Ŵ_RQH − Ŵ| ≤ 255` for all t. The reservoir never wraps (saturating add), the credit is monotone in the deposit stream, and the deadband leak makes `C` a bounded low-pass of recent deposits, not an accumulator of history.

**Proof.** `R` is confined to `[0, 2^RW − 1]` by the saturating add; `C = R[15:8] ≤ 2^(RW−QDW) − 1`; the readout add is saturating. Boundedness is by construction. **Tight:** flooding deposits drive `R` to saturation and `C = 255`. ∎

> **Theorem 3b (envelope preservation; the strong claim fails).** Let `Ŵ ∈ [W/2 − 1, 2W + 1]` (Theorem 1). Then the RQH readout satisfies `Ŵ_RQH ∈ [W/2 − 1, 2W + 1 + C]` — the multiplicative ratio band is `[1/2 − o(1), 2 + C/W]`. Since `C ≥ 0`, the credit never reduces the worst-case upper ratio and strictly increases it for any W < ∞. The worst-case envelope is **not tightened; it is additively widened by ≤ 255 LSB**.

**Proof.** Immediate from `Ŵ_RQH = Ŵ + C`, `C ≥ 0`. The "asymptotically closing the 2× envelope" claim is false as a worst-case statement. What the credit *does* do in the aligned phase is move the readout's *expected* position toward the band center (below). ∎

> **Theorem 3c (the exact convergence condition).** For the corrected readout to converge, in expectation, to the *center* of the model band — the strongest property a one-sided credit can deliver — the deposit must be the expected overstatement:
>
> ```
> deposit(g) = 2^QDW · E[ 2^(K−g) − 2^(K−A/H) | A ∈ bucket g ]
>            = 2^(K+QDW−g) · (1 − 1/(2 ln 2))          (uniform ages; b = 2)
> ```
>
> The as-built deposit `2^g` equals this only when `g = (K + QDW + log₂(1 − 1/(2 ln 2)))/2` — for K = QDW = 8, **g ≈ 7.1, the top of the ladder**. For fresh classes the as-built deposit is too small by a factor `2^(K+QDW−2g)·0.2787` (class 0: ~18,262× too small — C6: the earlier ~9,100× was a 2¹⁵ slip), and its class-dependence is inverted (largest where the overstatement is smallest). **The as-built RQH does not satisfy its own convergence condition.**

**Proof.** In the aligned phase the readout overstates; a credit can only push the readout *up*, so the achievable target is the band center `E[Ŵ] + E[Σu]`. For the credit to track the accumulated overstatement, its long-run rate must equal the overstatement rate: `rate(C) = Σ_g r_g·deposit(g)/2^QDW = Σ_g r_g·E[u|g]` for class rates `r_g`; equality for all rate profiles forces `deposit(g) = 2^QDW·E[u|g]`, which evaluates to the displayed quantity. The as-built deposit is `2^g`; solve `2^g = 2^(K+QDW−g)·0.2787` for g. ∎

Note the sign subtlety: even with the correct magnitude, a *one-sided* credit centers the band (converges to ~1.5·W for uniform ages); only a signed correction (subtract where over, add where under — impossible while the mis-phase is unobservable) could converge to W itself. The mis-phased case (`Ŵ < W`, the `+1` class of Theorem 1) is the one place a positive credit genuinely reduces error — and there the as-built deposit is directionally right but still ~2^(K+QDW−2g)·0.28× too small for fresh classes.

### 3.3 What RQH does deliver (provable)

1. **Boundedness / no-wrap** (3a) — the credit cannot corrupt the engine, `RQEN=0` restores bit-exact v1. This is the property the proposal's "Saturation safety" TB check targets.
2. **Anticipation cadence (exact, tight):** in the absence of leak, `o_antic` fires exactly every `2^(QDW−g)` class-g cofires (every 256 class-0 cofires; every 32 class-3 cofires) — a deterministic countdown, tick-aligned, dollar-zero telemetry. This is the proposal's strongest genuine asset.
3. **Rate tracking (convergence in the weak sense):** for a stationary stream with total rate r and class distribution p, the reservoir converges to the low-pass fixed point `R* ≈ 2^QLEAK·r·Σ_g p_g 2^g` (within the saturation cap), so `C(t) → ⌊2^(QLEAK−QDW)·r·E[2^g]⌋` — the credit tracks the *recent cofire rate*, not the accumulated history. This is the honest meaning of "converges": to a bounded function of the current rate, not to the true kernel.

### 3.4 MODE=1 (hyperbola) verdict

Agreed with `INNOVATION-JUDGEMENT.md` §4.2, now quantitatively: the hyperbola's dominant error is *temporal* (the [1,4) interval band, Theorem 2a), not placement; train-side deposits cannot correct decay-time error, and the reservoir's deadband leak bleeds during decay-only epochs. Credit remains monotone and bounded (harmless), but no envelope-tightening claim is even *formally expressible* for MODE=1 with a train-side deposit. Ship RQH scoped to MODE=0; the v2 deposit that satisfies 3c is `deposit(g) = round(2^(K+QDW−g)·0.2787)` — still shifts and saturating adds.

**Bottom line (T3):** bounded perturbation ≤ 255 LSB — TIGHT, provable; envelope *preservation* (not tightening) — provable; strong tightening — FALSE as built; exact convergence condition derived and unmet by a factor ~2^(K+QDW−2g)·0.28 (class 0: ~18,262× — C6).

---

## 4. Theorem 4 — the snap covering inequality `b√n/2 ≤ ε` and its geometry

### 4.1 The theorem (lattice covering radius; exact and tight)

> **Theorem 4a (covering radius of the scaled integer lattice).** For the lattice `b·ℤⁿ ⊂ ℝⁿ` with the Euclidean norm,
>
> ```
> μ(b·ℤⁿ) = b·√n / 2 .
> ```
>
> Consequently, if the measurement basis satisfies `b ≤ 2ε/√n`, then **every** point of ℝⁿ lies within ε of the lattice, and integer representation in basis b suffices for tolerance ε for *any* reachable set.

**Proof.** The nearest lattice point to `x` is the coordinate-wise rounding `r(x) = (b·⌊x₁/b + 1/2⌋, …, b·⌊xₙ/b + 1/2⌋)`; hence the Voronoi cell of a lattice point is the cube `[kb − b/2, kb + b/2)ⁿ` (mod translation), and the maximum distance from a cell point to its lattice point is attained at the cell center `(b/2, …, b/2)` (and its 2ⁿ corner translates): distance `√(n·(b/2)²) = b√n/2`. ∎

**Tightness — exact and attained.** The deep hole `(b/2,…,b/2) + b·ℤⁿ` is equidistant (distance exactly `b√n/2`) from all 2ⁿ corners of its cell; a true value at the deep hole is at distance exactly ε when `b = 2ε/√n`. The covering radius is not an overestimate: no smaller radius covers ℝⁿ. **TIGHT.**

### 4.2 Sufficiency vs necessity — the measurement-geometry refinement

> **Theorem 4b (geometry-relative covering).** Let `A ⊆ ℝⁿ` be the *reachable set* — the values the measurement can actually take (sensor placements, physical ranges, report units). Integer measurement at basis b suffices for tolerance ε iff
>
> ```
> max_{x ∈ A} dist(x, b·ℤⁿ) ≤ ε .
> ```
>
> The uniform condition `b ≤ 2ε/√n` (Theorem 4a) is sufficient for every geometry; it is *necessary* iff A reaches (arbitrarily close to) a deep hole of the lattice. For structured A the threshold is strictly larger:
>
> 1. **1-D** (`n = 1`): the condition is `b ≤ 2ε` — sufficient always; necessary iff A crosses a cell center `(k + 1/2)b` (an interval of length ≥ b covering one, or a point value at one). The oil-pressure calibration is the canonical instance: `psi = (mV − 500)·3/80` with mV ∈ ℤ puts the reachable set on the lattice `(3/80)·ℤ` (spacing 0.0375 psi), max distance 3/160 psi — the basis inequality with ε ≫ 0.019 is satisfied *by choosing the unit*, which is the whole trick.
> 2. **On-lattice (Pythagorean) geometries:** if `A ⊆ {v ∈ ℤⁿ : ‖v‖ ∈ ℤ}` — the 3-4-5 family and its multiples — the quantity of interest (the norm) is *on* the lattice: distance 0, arithmetic over ℤ exact, no covering argument needed at all. This is the "choose the measurement points" end of the spectrum (SEMANTIC-TOWER §5.3): no floats because none are needed.
> 3. **Lipschitz-composed quantities:** if the quantity of interest is `q = f(x)` with f Lipschitz (constant L), then integer measurement at basis b gives `|q̂ − q| ≤ L·b√n/2`; the condition becomes `b ≤ 2ε/(L√n)`. The squared-form judge is the instance that matters: `‖g − s‖² ∈ ℤ` for lattice points, so the comparison `‖g−s‖² ≤ Δ²` (Δ ∈ ℤ) is *exact integer arithmetic* — no square root, no float, and — critically — **zero comparison error**. The only error in the whole snap loop is the sensing quantization of Theorem 4a.
> 4. **Other judge metrics:** the covering radius of `b·ℤⁿ` is `b/2` in the ℓ∞ metric and `n·b/2` in ℓ1 — so a judge that tolerates per-coordinate deviations (ℓ∞) needs `b ≤ 2ε` *independent of n*, while a Manhattan judge pays `n`. The dimension dependence `√n` in the board's inequality is a property of the Euclidean metric; the judge's metric is a D2 dial choice, and the condition must be recomputed when it changes.

### 4.3 The snap loop's honest error statement

Let the sensor-derived value be quantized: `|ŝ − s| ≤ ε`, `|ĝ − g| ≤ ε` (Theorem 4a). Then:

```
| |ĝ − ŝ| − |g − s| | ≤ 2ε .
```

- The verdict is *guaranteed correct* whenever the true distance avoids the fuzzy band: `|g−s| > Δ + 2ε ⟹ SNAP` guaranteed; `|g−s| ≤ Δ − 2ε ⟹ WITHIN` guaranteed. Inside `(Δ − 2ε, Δ + 2ε]` the verdict may flip — the deadband's Schmitt character (no action until exceed, snap on exceed) absorbs the ambiguity, and the snap debt books whatever happened. Choosing the dial `Δ ≫ 2ε` (the design intent) makes the band measure-zero in practice.
- **True divergence is bounded by `Δ + 2ε` at all times, and by `2ε` immediately after a snap** (the snapped value is the quantized sensor value `ŝ`, so the true residual is the sensing error alone). This sharpens the board's "never displays divergence beyond max(Δ, sensor error)": in *displayed* (lattice) units the bound is exactly Δ and 0; in *true* units it is Δ + 2ε and 2ε. The squared-form judge is exact (case 3); no float can enter, and the weakest-substrate argument (both sides must run the same integer arithmetic or the two sides can disagree about the verdict itself) is what forces the lattice to be *identical* across substrates — the compiler's job, already measured in the fleet (reflex-arc: 500 vectors, 100.0000% integer agreement).

**Bottom line (T4):** `b√n/2` is the exact Euclidean covering radius of `b·ℤⁿ` — TIGHT (deep hole attained); `b ≤ 2ε/√n` sufficient for all geometries, necessary only at deep-hole reachability; the geometry-relative form `max_A dist(x, bℤⁿ) ≤ ε` is the exact condition, with the 1-D, on-lattice, Lipschitz, and ℓ∞/ℓ1 variants as the closed-form special cases. The judge itself contributes zero error; the loop's honest bound is `Δ + 2ε` true, `Δ` displayed.

---

## 5. Theorem 5 — end-to-end fixed-point error through the full hebbian update

### 5.1 The pipeline (as built + the proposal form)

```
events → [ladder Ŵ (MODE 0) | hyperbola W (MODE 1)]      model error: Theorem 1 / 2
       → eng (saturating top-PW readout)                  declared saturation
       → o_w = sat₁₆(base + eng)                         declared saturation        (v1)
       → [proposal: S = sat₁₆(base + ln̂(1+Ŵ)), Q4.12]   LUT error δ_ln             (glm §3.2)
       → act ← sat(act + (o_w·dat) >>> 15)               one truncation per effect  (q_cell_core)
       → fire test: act ≥ THRESH                          exact integer compare
```

The doctrine's claim — *saturate-never-wrap, integer state, zero drift* — is here made quantitative. Three error sources exist in this chain, and only three:

**(E1) The dyadic model envelope** (Theorems 1–2): a model error, not an arithmetic error — the fixed-point representation is exact; the *law* it implements is the staircase. This is the dominant term.

**(E2) One truncation: `(o_w·dat) >>> 15`** in the effect integrator (`rtl/q_cell_core.v`, `ST_EFFI`). The 16×16 product is exact (32 bits); the arithmetic shift right is a floor: per-effect error `r_e ∈ [−1, 0]` LSB of `act` (Q1.15), mean `−1/2` LSB. **This is a real, named bias**: after N effects since the last fire/reset, `E[act_error] = −N/2` LSB — the effective firing threshold `THRESH` is met that much later, and the view of `act` reads low by the same amount. The bias is linear in the effect count, bounded by the saturation rail, and re-zeroed at fire; it is the exact hazard zeroclaw's policy §3.3 and QUANT-RESEARCH §6 call "floor costs zero gates but biases −½ LSB/op; in an integrator that bias accumulates." The v1 golden model in `tb/tb_cell_core.v` must model this floor *exactly* (it does — the RTL equals its floor-model by construction); the *ideal* (convergent-rounded) model differs by `−N/2 ± √N/2` after N effects. Fix (v2, dial-cheap): convergent rounding at the integrating boundary — or stochastic rounding (Gupta et al., 2015), which removes the bias entirely and is the principled upgrade; the widths (32-bit product, 36-bit sums) leave headroom for the round.

**(E3) Saturation events** — declared, sticky (`o_ovf`), interval-truncations to the rail. By width construction they are *rare*, and provably so:

> **Theorem 5a (width construction; exact, tight).** With K=8, B=8, PW=16: the readout accumulator (17 bits) cannot overflow — `max Σ C_i·2^(K−i) = (2^B−1)(2^(K+1)−2) = 130,050 < 2^17`; the 16×16 product fits 32 bits exactly; `base + eng` is a 17-bit add whose only exit is the declared saturator. The engine's integer state is therefore *overflow-free by construction*: every saturation is at a named operator, latched sticky, viewable. The headroom is ~3% above the true ladder maximum (130,050 vs 131,072) — **TIGHT** (one more bit of B or K would overflow; the widths were swept to silence verilator, and the sweep landed one bit from the edge).

### 5.2 Theorem — the proposal strength `S = sat₁₆(base + ln̂(1+Ŵ))`

> **Theorem 5b (log-domain composition; exact).** Let `Ŵ ∈ [W/2 − 1, 2W + 1]` (Theorem 1) and let `ln̂` be the Q4.12 LUT+interpolate log with `|ln̂(1+u) − ln(1+u)| ≤ δ_ln = 2^(−11) ≈ 4.88·10⁻⁴` (glm §3.2: ±2 LSB at Q4.12). Then for W ≥ 2,
>
> ```
> | S − (base + ln(1 + W)) | ≤ δ_ln + ln 2 ≈ 0.6935
> ```
>
> **Proof.** `|ln(1+Ŵ) − ln(1+W)| = |ln((1+Ŵ)/(1+W))|`; from `Ŵ ∈ [W/2−1, 2W+1]` the ratio lies in `[(W/2)/(1+W), (2+2W)/(1+W)] ⊂ [1/2, 2]` for W ≥ 2, so the log error ≤ ln 2; add the LUT error and the (exact, integer) base add. ∎

**Tightness.** Both band extremes are reachable in the limit (events clustered at bucket boundaries, aligned phase): `Ŵ = 2W ⟹ ln error → ln 2`; mis-phase `Ŵ = W/2 ⟹ −ln 2`. **TIGHT** as a bound; the LUT term is three orders of magnitude below the model term. Relative error: `(δ_ln + ln 2)/ln(1+W)` — 12.5% at W = 256, 6.2% at W = 65,535, vanishing as W grows: **the log compression is doing its job — the 2× multiplicative model error becomes a bounded additive log error, and the fixed-point implementation contributes ≤ 0.07% of the error budget at W ≥ 256.** This is the quantitative form of "quantization IS the algorithm" (DOCTRINE): the dyadic model, not the arithmetic, is the error.

**Where interval arithmetic is right and where affine arithmetic is needed (Moore 1966; Stolfi & de Figueiredo).**

- **IA is the correct tool, and tight, for E1 and the log composition.** The ladder envelope is a *one-sided* (or two-sided-but-non-cancelling) interval: per-event overstatement factors are all ≥ 1 in the aligned phase, so the enclosure `[W/2−1, 2W+1]` is a genuine range, and the monotone `ln` maps it exactly (`f([a,b]) = [f(a),f(b)]` for monotone f). Affine arithmetic buys nothing here: AA's power is tracking *cancellations* between correlated errors, and a one-sided error has nothing to cancel — AA's radius degenerates to the IA width (this is the honest limit of AA for signed-biased integrands).
- **AA is the right tool for E2.** Model the per-effect truncations as affine noise: `act = act_exact − N/2 + Σ_e (r_e + 1/2)`, where `r_e ∈ [−1,0]` and `(r_e + 1/2) ∈ [−1/2, 1/2]` are zero-mean. AA separates the **deterministic bias −N/2** (a first-order term IA also gets) from the **fluctuation**, whose AA radius is `√N/2` (independent zero-mean terms) versus IA's `N` — a factor `√N` tighter, and *correct*: the worst case (all truncations at −1) is measure-zero for well-mixed `dat`, and the fluctuation is what actually shows up in simulation. The same AA budget is the planned contract for the v2 cosine accumulator (QUANT-RESEARCH §6: N products at 2^(−7) rounding, zero-mean with convergent rounding, shared inputs ⟹ correlated errors ⟹ IA's O(N) range collapses to AA's O(√N) with shared noise symbols). This is precisely the Stolfi–de Figueiredo program: represent each quantity as `x₀ + Σ cᵢεᵢ`, keep the correlations, bound the radius.

> **Theorem 5c (effect-integrator envelope; AA form).** After N effects since the last fire (no saturation), with per-effect rounding `r_e ∈ [−1, 0]`:
>
> ```
> act = act_exact_floor − N/2 ± √N/2        (AA: deterministic bias −N/2, fluctuation radius √N/2)
> act ∈ [act_exact_floor − N, act_exact_floor]        (IA: worst case, TIGHT against adversarial dat)
> ```
>
> The IA band is tight (an adversary can force `w·dat ≡ −1 (mod 2^15)` every effect); the AA band is the honest envelope for real traffic; the difference is the price of floor truncation, and the fix is convergent rounding at the integrating boundary (v2).

### 5.3 The end-to-end budget, one line

```
|o_w − (base + ln(1+W))| ≤ 0.6935     (model + LUT; arithmetic exact — Theorem 5b)
|act − act_ideal|        ≤ N/2 ± √N/2 LSB per epoch   (truncation bias + fluctuation — Theorem 5c)
saturations              ≤ declared, sticky, viewable; widths overflow-free (Theorem 5a)
fire decision            exact integer compare; threshold uncertainty inherits ±N/2 LSB bias
```

**Bottom line (T5):** the fixed-point chain's arithmetic error is **zero except one named floor-truncation** (E2: −½ LSB/effect bias, √N/2 fluctuation) **and declared saturations** (E3, overflow-free by width construction); the log-compressed strength carries the model envelope as ±ln 2 ≈ 0.69 absolute — TIGHT; the LUT is negligible. IA is tight for the one-sided model error; AA is the right (and √N-tighter) tool for the integrator's zero-mean fluctuation.

---

## 6. Citations (verified this session where noted)

- **Moore, R. E., *Interval Analysis*, Prentice-Hall, Englewood Cliffs NJ, 1966** (ISBN 0-13-476853-1). The founding monograph of interval arithmetic: values as ranges, enclosures by outward rounding. **VERIFIED this session** (bibliographic record + content confirmed via web fetch). The modern treatment is Cloud–Moore–Kearfott, *Introduction to Interval Analysis*, SIAM 2009.
- **de Figueiredo, L. H. & Stolfi, J., "Affine arithmetic: concepts and applications," *Numerical Algorithms* 37(1–4):147–158, 2004** (the survey the board cites as "2003"; the journal version is 2004, the tech-report form 2003). Origin: **Comba & Stolfi, "Affine arithmetic and its applications to computer graphics," SIBGRAPI 1993.** Content verified this session (affine forms `x₀ + Σ cᵢεᵢ`, εᵢ ∈ [−1,1], shared symbols carry correlations, non-affine ops introduce fresh noise symbols).
- **Datar, Gionis, Indyk, Motwani, "Maintaining Stream Statistics over Sliding Windows," SODA 2002** — exponential histograms; the ladder is the ε=1 member of the (1+ε) family (paper 67; standard literature, not re-verified this session).
- **Gupta, Agrawal, Gopalakrishnan, Narayanan, "Deep Learning with Limited Numerical Precision," ICML 2015** — stochastic rounding; the bias-removing upgrade of convergent rounding (standard).
- **Conway & Sloane, *Sphere Packings, Lattices and Groups*, Springer, 3rd ed., ch. 2** — covering radius theory; the `ℤⁿ` case is elementary and proved in-document (Theorem 4a). The covering-radius definition (smallest R such that balls of radius R centered at the set cover the space) confirmed via web fetch this session.
- **Sheeran, Singh, Stålmarck, "Checking Safety Properties Using Induction and a SAT-Solver," FMCAD 2000** — k-induction, the engine under sby `mode prove`; the planned machine-check of Theorems 1–2 as monitors (ABSTRACTION-MATH §4.3, checks #5/#6).
- **Halbwachs, Lagnier, Raymond, "Synchronous Observers and the Verification of Reactive Systems," 1994** — the TBs as observers; the reason the TB assertions are already the property language.

---

## 7. The honest ledger — what is proved, what is assumed, and the testbench that would validate each

Every bound above rests on a small set of assumptions. This section separates the theorems from the assumptions, and maps each assumption to the existing testbench that would validate it — or the testbench that is missing and must be written. Convention: **proved** = holds under the stated assumptions by the argument in this document; **validated** = exercised by an existing tb/ artifact; **unvalidated** = assumed, no tb/ exercise today.

| # | Claim | Status | Assumption (if any) | Validating testbench (existing / needed) |
|---|---|---|---|---|
| 1 | Ladder envelope `W/2−1 ≤ Ŵ ≤ 2W+1`, arbitrary arrivals | **Proved** (Thm 1) | None on arrivals; the *law* is exponential (task-level, owned by the acceptance gate) | Existing: `tb/tb_hebb_edge.v` T2 (ONE event schedule, 5 events) + `tb/tb_fabric_smoke.v` exact unshifted golden. **Missing:** random-stream fuzz (any stream must stay in the band) and the planned formal monitor (`tb/formal/`, ABSTRACTION-MATH check #5, k-induction) — the monitor is the only artifact that covers *all* arrival sequences |
| 2 | Hyperbola interval band `[1,4)` | **Proved** (Thm 2a), TIGHT in the unfloored regime `W < 2√P₀` (C4) | msb = ⌊log₂W⌋ — exact | **Now validated by `tb/tb_hyperbola_tail.v`** (3,825-pair formula sweep + per-level DUT cadence bit-exact vs the mirror, all 10 configs; C4's floor-tail correction included). Formal check #6 (k-induction monitor) remains open |
| 3 | Hyperbola trajectory `W_true(P₀)−1 ≤ W_rtl ≤ W_true(4P₀)` | **Proved** (Thm 2b); C5: ±1 slack necessary on **both** sides | The +1 slack suffices (proved up to the per-level deficit argument; empirically tight) | **Now validated by `tb/tb_hyperbola_tail.v`**: W₀ ∈ {1,2,3} × P₀ ∈ {2,4,8} + W₀=100/P₀=4096 driven past the W=1 plateau to t = 2τ₀, checked at **every** tick — ±1 held throughout; no-slack witnesses 8,302 lower / 13 upper (C5: both slacks necessary). τ₀ and every per-level interval bit-exact vs the formula |
| 4 | RQH boundedness ≤ 255 LSB, no wrap | **Proved** (Thm 3a) | Saturating add, widths | **Now validated by `tb/tb_rqh_saturation.v`** — and the module is committed (`rtl/q_hebb_rqh.v`, both deposit schemes): deposit math bit-exact per class, corrected table within 2 quanta of the real formula, corrected flood saturates at the 4th deposit with no wrap and telemetry integrity (antic == credit rises), deadband leak golden-exact to exactly 0, RQEN=0 A/B clean |
| 5 | RQH envelope *tightening* | **FALSE as built** (Thm 3b/3c) — convergence condition unmet | — | The honest regression **now runs in `tb/tb_rqh_saturation.v`**: preservation asserted per sample; centering measured — under the **corrected** deposit the mis-phased mean error tightens 120.4 → 57.1 LSB (QLEAK=5, 2.1×; → 50.4 at QLEAK=6), as-built `2^g` delivers literally zero credit (18,262× too small), the aligned-phase control *widens* 125.9 → 191.4 (Thm 3b confirmed), and QLEAK=8 saturates every deposit and destroys the tightening — the leak dial is the other half of the convergence condition (3c gives the deposit, not the leak) |
| 6 | Covering `b ≤ 2ε/√n` | **Proved** (Thm 4a), TIGHT | Euclidean metric; judge's metric is a D2 dial | **Now validated by `tb/tb_judge_consistency.v`** — the judge-consistency harness this row asked for: integer squared-form judge vs real golden over n ∈ {1,2,3}, ~2,325 vectors (on-lattice incl. the 64 ≤ 64 equality, deep holes, ⅛-phase grids, 500 LCG per dim): max quant error = b√n/2 exactly (n=1: 7.0 = ε attained; n=2: 6.36; n=3: 6.93), zero verdict flips outside the ±2ε band, `|d_int − d_real| ≤ 2ε` always, dial rule holds ∀ b ≤ b_max and the b+1 negative breaks at the deep hole in every dimension (ℓ∞ metric note logged) |
| 7 | v1 weight path arithmetic exact (no rounding) | **Proved** (Thm 5a) | Width construction (K,B,PW as parameterized) | Existing: `tb/tb_hebb_edge.v` T1/T4 (exact readouts), `tb/tb_fabric_smoke.v` (exact wsum). **Missing:** the width-construction assertion itself (accumulator max 130,050 < 2^17) as a `localparam`-check or formal property |
| 8 | Act truncation bias −½ LSB/effect | **Proved** (Thm 5c, floor semantics) | `>>>` = arithmetic floor (as implemented) | Existing: `tb/tb_cell_core.v` saturating golden — *consistent* with the floor by construction (validates the RTL equals its model, not the bias itself). **Missing:** a bias test — long effect streams, assert `act` against the *convergent-rounded* ideal within `N/2 ± √N/2`; and a threshold-shift test (fire latency vs N) |
| 9 | ln strength bound ±(δ_ln + ln 2) | **Proved** (Thm 5b) | ln̂ LUT error ≤ 2 LSB (glm §3.2) | **No ln unit exists in v1 RTL** (`view(3)` NAKs; the LUT is proposal-level). When built: an exhaustive Q4.12 sweep vs `$ln` (glm's `tb_qs_ln` plan) |
| 10 | Saturation rarity / no silent wrap | **Proved** (Thm 5a) | Dial policy (THRESH 0x6000, base small) | Existing: `tb/tb_fabric_smoke.v` (asserts exactness in the unsaturated regime); formal check #7 (saturate-never-wrap SEC, ABSTRACTION-MATH §4.3) — **planned, not run** |

**The three assumptions that genuinely need empirical attention:**

1. **The hyperbola lower envelope's +1 slack** (row 3) — the only bound where the proof stops one step short of a clean inequality. The TB's five checkpoints never enter the tail region where the slack is load-bearing. *Validate:* extend T5's checkpoint set into `t ∈ (T_1(P₀), 2τ_{W₀}]` and the small-W₀ corner; if any checkpoint violates `glo − 1 ≤ wint`, the theorem's slack is too small and the bound must be re-derived (it will not be: the W=1 plateau argument covers it, but it deserves the machine). **Done 2026-08-29 — `tb/tb_hyperbola_tail.v`: the lower +1 slack held at every tail tick (prediction confirmed); the surprise was the upper side, which also violates no-slack between crossings (C5).**
2. **The exponential-law target** (row 1) — every envelope in this document bounds the hardware readout against `Σ 2^(−a/H)`. Whether the exponential (or the hyperbolic tail, or the k=1 power law) is the *right* forgetting law for the application is a task-level question the envelopes cannot answer; the acceptance gate (`tb/tb_fabric_smoke.v`: train → fire → decay → view) is the existing arbiter, and it tests one scenario. A law-choice sweep (MODE=0 vs MODE=1 vs base-b variants against the same task statistics) is the missing experiment.
3. **The covering condition's reachable set** (row 6) — the design rule is only as good as the model of `A` (what values the sensor can actually produce). The oil-pressure example is exact by construction; the ToF case (`c/2` not a whole number of mm/ns) is *not* — it needs the dyadic fallback, and its reachable set (round-trip ns ∈ ℤ → distance spacing 0.1499 m) must be checked against ε before the integer-only claim is believed. The reflex-arc measurement is the fleet precedent; a quilt-side judge-consistency harness is the missing artifact. **Built and passing 2026-08-29 — `tb/tb_judge_consistency.v` (covering holds at deep holes for b ≤ 2ε/√n, breaks at b+1 in n ∈ {1,2,3}).**

### 7.1 Machine-validation addendum (tb-envelope lane, 2026-08-29)

The three testbenches this ledger named as missing are built and green — `iverilog -g2005`, verilator `-Wall` lint-clean, zero failures:

| bench | covers | headline result |
|---|---|---|
| `tb/tb_hyperbola_tail.v` | rows 2–3 | ±1 trajectory envelope held at **every** tick of 10 configs (incl. the tail t = 2τ₀ and W₀ ∈ {1,2,3} × P₀ ∈ {2,4,8}); per-level cadence **bit-exact** vs `max(1, P₀ >> 2·msb W)`; τ₀ bit-exact vs the level sum; **2,713/3,825 as-written interval-band violations (C4)**; no-slack witnesses 8,302 lower / 13 upper (C5) |
| `tb/tb_rqh_saturation.v` (+ `rtl/q_hebb_rqh.v`) | rows 4–5 | deposit tables bit-exact (corrected within 2 quanta of exact; **18,262× shortfall at class 0, C6**); saturation flood no-wrap, credit ≤ 255, antic == credit-rises; deadband leak golden-exact to exactly 0 (the sketch's snap rule had a sticky floor at R ∈ [2, 2^QLEAK] — fixed); **tightening under the corrected deposit, measured**: mis-phased mean error 120.4 → 83.9 / 57.1 / 50.4 LSB at QLEAK 4/5/6 (2.1–2.4×), destroyed at QLEAK 8 (saturation, 120.9); as-built `2^g` credit literally 0; aligned control *widens* 125.9 → 191.4 (Thm 3b); preservation band held at all 1,536 samples |
| `tb/tb_judge_consistency.v` | row 6 | ~2,325 vectors, n ∈ {1,2,3}: covering holds (max quant error = b√n/2 exactly, attained at the deep holes: 7.0 / 6.36 / 6.93 vs ε = 7), zero integer-vs-real verdict flips outside the ±2ε band, `|d_int − d_real| ≤ 2ε` always, on-lattice verdicts exact incl. 8²+0² ≤ 8²; the b+1 negative breaks at the deep hole in every dimension (ℓ∞ caveat logged) |

Tool gotcha archived for the fleet: **iverilog's implicit real→integer assignment rounds** (`0.57 → 1`), IEEE's truncating conversion is `$rtoi` — `tb_judge_consistency.v`'s quantizer hit exactly this (max error 14 = b before the fix, 7 = b/2 after).

**What is already machine-checked today:** the flit-pipe FIFO contract (C1–C4) — PASS by k-induction, smtbmc/boolector, ~0 s (`tb/formal/flit_pipe.sby`, re-run clean); and, since 2026-08-29 (tb-envelope lane), the three benches this ledger named as missing — `tb/tb_hyperbola_tail.v` (rows 2–3), `tb/tb_rqh_saturation.v` + `rtl/q_hebb_rqh.v` (rows 4–5), `tb/tb_judge_consistency.v` (row 6) — all PASS under `iverilog -g2005`, verilator `-Wall` lint-clean, findings C4–C6 logged in §0. That is the method precedent: the envelope monitors of Theorems 1–2 are ~30 lines each on the same harness (ABSTRACTION-MATH §4.3, checks #5/#6), and the flit-pipe experience says they are seconds-to-minutes. The bounds in this document are proved in prose; the monitors would make them proved in silicon.

---

## Appendix — the five results, one line each

- **T1 (ladder):** `W/2 − 1 ≤ Ŵ ≤ 2W + 1` for *arbitrary* arrivals — **TIGHT** at both ends (per-event ratio ∈ [1/2, 2), ~1.39× expected); readout arithmetic itself exact (shift-and-add, zero rounding).
- **T2 (hyperbola):** decrement interval `Δ ∈ [P₀/W², 4P₀/W²)` — **TIGHT** (`[1,4)`, both ends achievable); trajectory `W_true(P₀) − 1 ≤ W_rtl ≤ W_true(4P₀)` — upper **exact/TIGHT**, lower exact up to the **necessary +1 slack** (prose direction in ABSTRACTION-MATH §5.2 is inverted; TB implements the correct one).
- **T3 (RQH):** bounded perturbation ≤ 255 LSB, no wrap — **TIGHT, proved**; envelope *preserved*, not tightened — strong claim **FALSE as built**; exact convergence condition is `deposit(g) = 2^(K+QDW−g)·0.2787`, unmet by ~18,262× at class 0 (C6).
- **T4 (covering):** `μ(b·ℤⁿ) = b√n/2` — **exact and TIGHT** (deep hole attained); `b ≤ 2ε/√n` sufficient for all geometries, necessary iff the reachable set reaches a deep hole; geometry-relative form + 1-D / on-lattice / Lipschitz / ℓ∞-ℓ1 variants given; snap loop's honest bound: true divergence ≤ `Δ + 2ε`, displayed ≤ Δ.
- **T5 (fixed-point chain):** weight path arithmetic error **zero** in the unsaturated regime (overflow-free by width construction — tight, ~3% headroom); one named floor-truncation in the effect integrator (`−½ LSB/effect` bias, `√N/2` fluctuation — IA tight vs adversarial, AA the honest envelope); log-compressed strength: `|S − (base+ln(1+W))| ≤ δ_ln + ln 2 ≈ 0.69` — **TIGHT**, LUT negligible, the dyadic model — not the arithmetic — is the error (Moore 1966 for the one-sided enclosures; Stolfi & de Figueiredo 2004 for the correlated/zero-mean budgets).

*Error-envelopes lane, 2026-08-29. The bounds were already on the board; this document proves them, grades them, and logs the three places the board's prose drifted from its own RTL. The TBs were right all three times.*
