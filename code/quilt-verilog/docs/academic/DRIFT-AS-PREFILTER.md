# DRIFT AS PREFILTER — the composition theory of judgment under drift: additive tolerance, the cost of re-judging, and the labeled-perturbation problem

**Lane:** academic-expansion (GLM-5.3) · **Date:** 2026-08-29
**Sources upgraded:** `conjectures.md` Part II (C2 attacked: Lemma 4, Theorem 4, Corollary 4′, Theorem 5) and `quilt-calculus.md` §5 (T3(c), the triangle theorem). Self-contained: the composition theory is rebuilt here from the pseudometric axioms up; companions are cited as provenance, not prerequisites. The impossibility *floor* (Theorem 5(iii) of the source) has its own paper — `RHO-F-FLOOR.md` — and is referenced here only as the feasibility boundary of the cost analysis.

> **The contract of this document.** Three results carry the paper. (1) **Composition:** approximate stages ahead of a judge widen its effective tolerance by exactly the sum of the stage accuracies — additively, with no cancellation — and the additivity is *tight*: inside the widened annulus the verdict is fully controllable by adversarial stage behavior (§3, DA-T1/T2). (2) **Drift is a stage:** holding a judge against a drifted truth is verdict-equivalent to judging the undrifted truth through an unmodeled prefilter of accuracy equal to the drift budget — so drift composes with tolerance exactly as latency composes with freshness (§4, DA-T4). *Drift is latency's judgment-side twin.* (3) **The price schedule:** at fixed error, re-judging costs linearly in drift rate; at the joint optimum, as its square root; for power-law margin masses, as ρ^{α/(α+1)} — with the full derivations, the feasibility boundary ρF < ε₀, and the sensitivity (marginal cost of drift) computed (§5, DA-T5–T7). The open problem — whether the labeled-perturbation hypothesis is the weakest closing hypothesis — is stated precisely, with sufficiency a theorem, necessity refuted by construction, and the shapes of the remaining counterexamples exhibited (§6). What is not machine-checked is graded in §7.

**Statement registry.** 8 definitions (DA-D1–D8), 3 lemmas (DA-L1–L3), 7 theorems (DA-T1–T7), 3 corollaries (DA-C1–C3), 2 propositions (DA-P1–P2), 1 explicit open problem (OP-1), 15 numbered proofs. Grade: **pen + machine-checked (bounded)** — `tools/verifies/floor_bench.py` (2026-08-29, mathmetal lane): DA-L1 on 643,125 step sequences, DA-T3's band on 1,286,250 instances (200,693 flips, all inside), DA-T1 composition + **DA-T2's annulus tightness with the equality instance** (a point at exactly r+Σρᵢ presented at exactly r → accepted; inner edge open), DA-T5/T6 cost laws exact. Bounded; bounds printed per run.

---

## 1. Introduction

The quilt calculus made judgment a pseudometric-space operation: match-with-tolerance, tolerance as state (D3), and one composition law — a stage of accuracy ρ ahead of a judge of tolerance r behaves like a judge of tolerance r + ρ (T3(c), the triangle theorem). The conjecture C2 then asked what happens when the *world* moves under a fixed judge, and the attack (conjectures.md Part II) answered: the drift budget γ plays exactly the role of ρ. The three-word summary — *drift is an unmodeled prefilter stage* — is Corollary 4′ of that document, and it is the hinge of this paper.

Why promote the hinge to a paper:

1. **The additivity is exact, both ways.** The source proves the upper composition (accept within r − ρ, reject beyond r + ρ). We add the lower side: inside the annulus (r − ρ, r + ρ] the verdict is *fully adversarially controllable* — every point of the annulus can be forced to either verdict by legal stage behavior. So the composed tolerance is not merely *at most* r + Σρᵢ; it *is* r + Σρᵢ in the worst case, and no analysis can quote a tighter uniform guarantee (DA-T2). This closes the tightness gap the source left implicit.
2. **The cost theory deserves its own derivation.** Theorem 5 of the source compresses three pricing laws into one paragraph with an AM–GM step. We unpack all of them — the fixed-error linear law with its feasibility boundary, the √ρ joint optimum with the equality condition, and a new generalization: power-law margin masses Φ(ε) = (ε/ε₁)^α yield cost ∝ ρ^{α/(α+1)}, recovering √ρ at α = 1 and sharpening toward linear as α → ∞ (the hard-margin limit). The marginal cost of drift — the derivative the fleet actually budgets against — is computed at the optimum.
3. **The open problem deserves its own statement.** "Even the right formalization of ‖d_t − d_{t+1}‖ needs care," said the calculus. The attack proposed the labeled perturbation η (uniform, pointwise, identity correspondence) and showed Gromov–Hausdorff-style unlabeled budgets are insufficient. What is *not* settled: is the labeled budget the *weakest* verdict-relevant budget? We prove sufficiency (it bounds error), refute necessity by construction (verdicts can be stable under unbounded η), define the exact quantity (the boundary-crossing functional), and state the remaining question with its counterexample shapes (§6).

---

## 2. Preliminaries (self-contained)

### DA-D1 — Pseudometric answer space

> A **pseudometric** on X: d : X × X → ℝ≥0 with d(x,x) = 0, symmetry, triangle inequality. All verdicts below are computed against such d; aliases (d(x,y) = 0, x ≠ y) are harmless — quotient if desired (the construction is the calculus's T3(b), not needed here).

### DA-D2 — Judge

> A **judge** J = (A, r): A = {(a_j, k_j)}_{j≤m} a finite keyed answer set, r ≥ 0 the tolerance. Verdict set V_J(x) = {k_j : d(x, a_j) ≤ r}; verdict ACCEPT(k_j) if the set is the singleton {k_j}; AMBIGUOUS if larger; REJECT if empty.

### DA-D3 — Prefilter stage; accuracy

> A **stage** is a map p : X → X. It has **accuracy ρ** (on the inputs of interest) if d(p(x), x) ≤ ρ for all x in its domain of use. Stages compose; the composition's accuracy is at most the sum (DA-T1) — and this is the only accuracy fact any consumer needs.

### DA-D4 — Pipeline

> A **pipeline** of depth k ahead of a judge: the query x is transformed by stages p₁, …, p_k (accuracies ρ₁, …, ρ_k) and the judge sees p_k∘⋯∘p₁(x). Call ŷ(x) = p_k(⋯p₁(x)⋯) the **presented input**.

### DA-D5 — Drifting truth frame; budgets (carried from C2-d1/d2, restated)

> A **truth frame** at t: (d_t, A_t) as in `RHO-F-FLOOR.md` RF-D1. **Answer path length** per key: D_a^{(j)}(t) = Σ_{s<t} d_{s+1}(a_j(s+1), a_j(s)); **metric perturbation** per step: η_s = sup_{x,y} |d_{s+1}(x,y) − d_s(x,y)|; D_m(t) = Σ_{s<t} η_s; **combined budget** γ(t) = max_j D_a^{(j)}(t) + D_m(t); **rate** ρ if γ(t+1) − γ(t) ≤ ρ. The **held judge** is fixed at bind time: J₀ = (A₀, d₀, r).

### DA-D6 — Margins, drift band, error

> **Margin** of x (against the held judge): m(x) = min_j |d₀(x, a_j(0)) − r|. **Margin-mass function** Φ(ε) = μ({x : m(x) ≤ ε}). **Error** of the held judge at t: err(t) = μ({x : verdict of J₀ at x ≠ verdict of (A_t, d_t, r) at x}).

### DA-D7 — Re-judging policy, cost

> A **re-judge** resets the held judge to a current observed frame (a dial write; cost c per event; serviced within A3/A6 bounds — the cost model is the same one `RHO-F-FLOOR.md` RF-D8 uses). A **periodic policy** of period T re-judges every T ticks. Observations arrive through an audit channel of freshness bound F (RF-D4 of the companion; here only the lag F enters).

### DA-D8 — Effective tolerance

> A pipeline **presents at effective tolerance R** if every input in ⋃_j B(a_j, R − ρ̄) is accepted (some verdict) and no input outside ⋃_j B(a_j, R + ρ̄) is, where ρ̄ = total stage accuracy; R is the judge's dial r in the composed reading. (The annulus (r − ρ̄, r + ρ̄] is the *blurred boundary*.)

---

## 3. Composition: additivity, exactly

### DA-T1 — Additive tolerance composition (the upper side; the triangle theorem)

> **Theorem.** Let stages p₁,…,p_k of accuracies ρ₁,…,ρρ_k precede a judge J = (A, r) on a pseudometric space. Then for every keyed answer a_j and every input x:
> - **(certainty)** d₀(x, a_j) ≤ r − ρ̄ ⟹ d(ŷ(x), a_j) ≤ r (accepted);
> - **(soundness)** d(ŷ(x), a_j) ≤ r ⟹ d₀(x, a_j) ≤ r + ρ̄,
>
> with ρ̄ = Σᵢ ρᵢ. Chaining k stages composes with the *sum*, not the max, the product, or anything smaller.

*Proof.* Composed accuracy: d(ŷ(x), x) ≤ Σᵢ ρᵢ by induction on k — one triangle inequality per link: d(p_k(…p₁(x)), x) ≤ d(p_k(…), p_{k−1}(…)) + d(p_{k−1}(…), x) ≤ ρ_k + Σ_{i<k} ρᵢ. Certainty: d(ŷ(x), a_j) ≤ d(ŷ(x), x) + d(x, a_j) ≤ ρ̄ + (r − ρ̄) = r. Soundness: d(x, a_j) ≤ d(x, ŷ(x)) + d(ŷ(x), a_j) ≤ ρ̄ + r. ∎ (Consumes DA-D1's triangle inequality only; ≡ quilt-calculus T3(c), restated for self-containment.)

### DA-T2 — Tightness: the annulus is fully adversarial (the lower side — new here)

> **Theorem.** Let X be geodesic (any two points at distance δ are joined by a path realizing δ; all standard answer spaces are). For every input x with d(x, a_j) ∈ (r − ρ̄, r + ρ̄] — inside the blurred annulus of key j — there exist legal stage behaviors (each within its accuracy) presenting x as accepted by key j, and other legal behaviors presenting x as rejected.
>
> Hence the effective tolerance of the pipeline is **exactly** r + ρ̄ in the worst case: no uniform guarantee tighter than DA-T1's is possible, and the annulus's verdicts are attributable to the stages, not the judge.

*Proof.* Fix x and the target presented distance D ∈ [d(x, a_j) − ρ̄, d(x, a_j) + ρ̄] (any value in reach of the composed accuracy — realizable by concatenating geodesic segments: stage i displaces along a segment of length ρᵢ in the chosen net direction; the concatenated displacement has any length up to ρ̄ and, in a geodesic space, any direction with a realized path — the presented point ŷ(x) can be placed at any distance in [d(x,a_j) − ρ̄, d(x,a_j) + ρ̄]... precisely: choose ŷ(x) on a geodesic from x toward/away from a_j at total displacement ρ̄ — then d(ŷ(x), a_j) = d(x, a_j) ± ρ̄ or, for a partial displacement t ≤ ρ̄, d = d(x, a_j) ± t). Choose t so that d(ŷ(x), a_j) ≤ r (accepted): possible iff d(x, a_j) − ρ̄ ≤ r, i.e. x is within the outer annulus edge. Choose t so that d(ŷ(x), a_j) > r: possible iff d(x, a_j) + ρ̄ > r and stages may also *do nothing* (accuracy ρᵢ permits displacement 0 ≤ ρᵢ): presented = x, and d(x, a_j) > r already for x outside B(a_j, r) — for x inside the ball but in the annulus (d(x,a_j) ∈ (r − ρ̄, r]), displace outward by t ∈ (r − d(x,a_j), ρ̄]. Both behaviors are legal (each stage's displacement is ≤ its accuracy; assigning the whole displacement to stage 1 and 0 to the rest is legal). ∎

Two honesty notes. (i) The adversary is *per-input*: one fixed stage realization need not flip the whole annulus uniformly — a single direction realizes a slab, not the shell (the same lens-vs-shell geometry `RHO-F-FLOOR.md` RF-C1 documents for key moves). DA-T2's claim is per-input controllability — which is exactly what "no tighter uniform guarantee" needs: for any candidate tighter bound, some input violates it under some legal behavior. (ii) If stages are *known* rather than adversarial, their realized displacements may cancel (a stage correcting another's error); the additivity theorem prices *worst-case composition of unmodeled stages*, which is the regime both the RTL prefilter chain and the drift analogy live in — nobody books cancellation they cannot audit.

### DA-C1 — The composed-system design rule

> **Corollary.** To make a k-stage pipeline judge at true tolerance r\* with worst-case guarantees, set the dial to r = r\* − Σρᵢ (and require r\* > Σρᵢ). Every additional approximate stage is paid for in dial headroom, at face value, additively. (This is the formal content of "verification is judgment at log-2 tolerance" with numeric gates upstream: the gate `W/2 − 1 ≤ Ŵ ≤ 2W + 1` is a judge at r = log 2 on the multiplicative metric, and each approximate stage ahead of it — prefilter, quantizer, drift — spends its accuracy from the same r\* budget.)

---

## 4. Drift is a prefilter stage

### DA-L1 — Perturbation accumulation (the one-perturbation-per-step chain, in full)

> **Lemma.** For every key j, input x, and t: | d_t(x, a_j(t)) − d₀(x, a_j(0)) | ≤ D_a^{(j)}(t) + D_m(t) ≤ γ(t).

*Proof (full derivation, both directions, the routing made explicit).* Write f_s = d_s(x, a_j(s)), the distance process of interest; step_j(s) = d_{s+1}(a_j(s), a_j(s+1)) the answer's step length.

Forward step (s → s+1):
f_{s+1} = d_{s+1}(x, a_j(s+1)) ≤ d_{s+1}(x, a_j(s)) + d_{s+1}(a_j(s), a_j(s+1)) [triangle at d_{s+1}] ≤ (f_s + η_s) + step_j(s) [one metric perturbation: |d_{s+1}(x, a_j(s)) − d_s(x, a_j(s))| ≤ η_s].

Backward step (s+1 → s): perturb once, then take the triangle wholly at d_{s+1} —
f_s = d_s(x, a_j(s)) ≤ d_{s+1}(x, a_j(s)) + η_s [one perturbation] ≤ d_{s+1}(x, a_j(s+1)) + d_{s+1}(a_j(s), a_j(s+1)) + η_s [triangle at d_{s+1}] = f_{s+1} + step_j(s) + η_s.

So each step moves f by at most η_s + step_j(s) in either direction: |f_{s+1} − f_s| ≤ η_s + step_j(s). Telescoping over s = 0…t−1: |f_t − f₀| ≤ Σ_s η_s + Σ_s step_j(s) = D_m(t) + D_a^{(j)}(t) ≤ γ(t) (the last step by max_j ≤ and the budget's definition — note the budget is per-key max, so the bound holds *uniformly over j*, which is what the verdict argument needs). ∎

**The routing remark (why one η per step, not two).** A naive backward chain — triangle at d_s, then perturb — costs two perturbations per step (|f_{s+1} − f_s| ≤ η_s + step + η_s), yielding the budget D_a + 2D_m. Routing the backward triangle wholly at d_{s+1} after a single perturbation halves the metric term. The bound D_a + D_m is the correct one; the calculus's hint that the formalization "needs care" is this one-line routing discipline.

### DA-T3 — The drift band

> **Theorem.** For every input x and time t: verdict of the held judge differs from the true verdict at t only if m(x) ≤ γ(t). Hence err(t) ≤ μ({x : m(x) ≤ γ(t)}) = Φ(γ(t)). The bound is **attained**: for every γ > 0 there is a realization (one point, one key, static metric, answer moving along a geodesic through the boundary) with err = μ({m ≤ γ}) = 1.

*Proof.* Verdicts are functions of the membership vector (𝕀[d(x, a_j) ≤ r])_j (DA-D2: ACCEPT iff exactly one 1, etc.). Equal vectors give equal verdicts. A differing verdict implies some membership bit differs; for that j, one of d₀(x, a_j(0)), d_t(x, a_j(t)) is ≤ r and the other > r, so r lies between them and |d₀(x, a_j(0)) − r| ≤ |d₀(x, a_j(0)) − d_t(x, a_j(t))| ≤ γ(t) (DA-L1) — hence m(x) ≤ γ(t). Attainment: X = {x}, one key, d₀ = d_t static metric (η ≡ 0), a_j(0) at distance r + γ − ε from x, a_j(t) at distance r (path length γ − ε ≤ D_a budget); membership flips REJECT-side... verdict flips (singleton to empty or empty to singleton as arranged); err = 1 = Φ(γ). ∎ (≡ conjectures.md Theorem 4, self-contained.)

### DA-T4 — Drift is an unmodeled prefilter (the equivalence)

> **Theorem.** Holding J₀ = (A₀, d₀, r) against the drifted frame (A_t, d_t, r) is verdict-equivalent to judging the *undrifted* truth through a prefilter stage of accuracy γ(t):
>
> (i) every x with d₀(x, a_j(0)) ≤ r − γ(t) is still accepted by key j under the true frame; every x accepted under the true frame satisfies d₀(x, a_j(0)) ≤ r + γ(t);
> (ii) conversely, any stage of accuracy γ placed before J₀ reproduces exactly these clauses (DA-T1).
>
> Consequently every composition guarantee of §3 transfers to drifted judgment with ρ̄ = γ(t): tolerance composes with drift **additively**, and the blurred annulus (r − γ, r + γ] is adversarially controllable *by drift realizations* (the DA-T2 construction instantiated on the perturbation family of `RHO-F-FLOOR.md` RF-T2 — the key-outward radial metric shift is a legal rate-ρ realization flipping the one-sided band exactly).

*Proof.* (i) is DA-L1 + the membership argument of DA-T3, read as the certainty/soundness clauses. (ii) DA-T1 with one stage of accuracy γ. The equivalence is at the level of *what any downstream consumer can distinguish*: both systems accept exactly B(a_j, r + γ) in the worst case and B(a_j, r − γ) in the best, with the annulus attributable to the unmodeled displacement in both. ∎ (≡ conjectures.md Corollary 4′, expanded.)

### DA-C2 — The twin sentence (freshness ↔ tolerance)

> **Corollary.** In a view chain, per-hop latencies add into the composite staleness F₁ + Σ Lᵢ (quilt-calculus T6) — the *data* side. In a judgment chain, stage accuracies and drift budgets add into the composite tolerance r + Σρᵢ + γ (DA-T1/T4) — the *judgment* side. The two additivity laws are the same theorem at different organs: **latency is drift's transport-side twin; drift is latency's judgment-side twin.** F and γ are the two prices of asynchrony in a world that moves.

---

## 5. The cost of re-judging: the full derivation

Fix: drift rate ρ, audit freshness F (the anchor lag — `RHO-F-FLOOR.md` RF-L2), re-judge cost c, margin-mass function Φ. The feasibility boundary throughout: **ρF < ε₀** for target band ε₀ (RF-C2 of the companion — beyond it, no schedule exists and pricing is moot).

### DA-T5 — The periodic-policy error bound

> **Theorem.** A periodic policy of period T, anchoring to the freshest observable frame, achieves for all t:
>
> err(t) ≤ Φ( ρ · (T + F) ),
>
> and under the linear margin bound Φ(ε) ≤ σε: err(t) ≤ σρ(T + F).

*Proof (full).* At time t, the last anchor was at u ∈ (t − T, t]; the anchor's frame is θ_{u−F} (audit lag F). The displacement between the anchor frame and the truth at t is bounded by the budget accrued over [u − F, t]: by DA-L1 applied with endpoints s = u − F, t: for every j, |d_t(x, a_j(t)) − d_{u−F}(x, a_j(u−F))| ≤ accrued budget over [u−F, t] ≤ ρ(t − u + F) ≤ ρ(T + F) (rate bound). An error at t implies a membership bit of the *anchored* judge differs from the true one (the anchored judge's verdict vs the true verdict; identical membership vectors give identical verdicts — DA-T3's argument), so the anchored-frame distance of x to that key crosses r, so x's margin against the anchor frame is ≤ ρ(T + F). err(t) ≤ μ({m_{anchor} ≤ ρ(T+F)}) ≤ Φ(ρ(T+F)) (Φ is the supremum over frames). ∎

### DA-T6 — The three pricing laws

> **Theorem.**
> **(i) Fixed-error regime (the linear law).** To hold err ≤ Φ(ε₀) for all t: any feasible period satisfies T ≥ ε₀/ρ − F (feasible iff ρF < ε₀), and the minimal cost rate is achieved at T\* = ε₀/ρ − F:
>
> J₁ = c / T\* = **cρ / (ε₀ − ρF) = (c/ε₀)·ρ · (1 + ρF/(ε₀ − ρF))**,
>
> which is **linear in ρ** for ρF ≪ ε₀ (the conjecture's clause, with the correction factor displayed) and diverges as ρF → ε₀ (the floor's cost face).
>
> **(ii) Joint optimum (the √ law).** Minimize the total rate J(T) = σρT + c/T over T > 0 (error price σρT from DA-T5's bound, cost price c/T). By AM–GM:
>
> σρT + c/T ≥ 2√(σρc), equality iff σρT = c/T ⟺ **T\* = √(c/(σρ))**, J₂ = **2√(cσρ)** — **sublinear in ρ (√ρ)**: at the joint optimum, doubling drift costs only √2×, because the policy re-anchors more often and eats part of the increase in cadence. Valid while T\* ≥ ... whenever T\* ≥ 1 tick; note T\* is *independent of F* — but the achieved error at T\* is σρ(T\* + F) = √(cσρ)·... = √(cσρ) + σρF, and if that exceeds σε₀ the joint optimum is infeasible and (i)'s boundary solution binds instead: the floor F silently converts the √ law into the linear law exactly when √(c/(σρ)) < ε₀/ρ − F.
>
> **(iii) Sensitivity (the budget derivative).** At the (i) optimum: dJ₁/dρ = cε₀/(ε₀ − ρF)² ≥ c/ε₀ — the marginal cost of drift is *increasing* in ρ (convex in ρ; the floor again: dJ₁/dρ → ∞ as ρF → ε₀). At the (ii) optimum: dJ₂/dρ = √(cσ/ρ) — the marginal cost of drift *decreases* in ρ (√ law's concavity). The fleet budgeting consequence: in the fixed-error regime drift risk compounds; in the elastic-error regime it amortizes.

*Proof.* (i) DA-T5: Φ(ρ(T+F)) ≤ Φ(ε₀) forces ρ(T+F) ≤ ε₀ (Φ monotone; if Φ has flat stretches the constraint relaxes to the least ε with Φ(ε) ≤ target — the linear-bound case has no flats). Solve for T; cost rate c/T minimized at the smallest feasible T. The displayed factorization: cρ/(ε₀−ρF) = (c/ε₀)ρ·ε₀/(ε₀−ρF) = (c/ε₀)ρ(1 + ρF/(ε₀−ρF)). (ii) AM–GM on the two positive terms; equality condition is standard. The regime note: the unconstrained optimum is feasible iff σρ(T\*+F) ≤ σε₀ ⟺ √(cσρ) + σρF ≤ σε₀. (iii) differentiate. ∎

### DA-T7 — Power-law margins (the general scaling — new here)

> **Theorem.** Let Φ(ε) = (ε/ε₁)^α (α > 0; α = 1 is the linear case — the natural null for uniform boundary mass; α > 1 boundary mass thinning outward: adversarial/decreasing density near the boundary; α < 1 heavy boundary mass). Minimize J(T) = (ρ(T+F)/ε₁)^α + c/T over T > 0:
>
> **T\*(α) = ( c ε₁^α / (α ρ^α) )^{1/(α+1)}** (independent of F),
> **J\*(α) = (1+α)·α^{−α/(α+1)} · c^{α/(α+1)} · (ρ/ε₁)^{α/(α+1)}** (when T\* is feasible: the floor condition (ρ(T\*+F)/ε₁)^α ≤ target).
>
> The cost scales as **ρ^{α/(α+1)}**: α = 1 gives √ρ (DA-T6ii recovered); α → ∞ (hard margin: any boundary crossing is fatal, Φ jumps at ε₀) gives ρ^1 — the linear law is the hard-margin limit; α → 0 (all mass on the boundary) gives ρ⁰ — cost independent of drift: when every input sits on the boundary, no cadence helps and the only lever is F (the floor again, now as the α → 0 limit).
>
> *Proof.* dJ/dT = α(ρ/ε₁)^α T^{α−1} − c/T² = 0 ⟹ T^{α+1} = c/(α(ρ/ε₁)^α) ⟹ T\* as displayed. Substituting: (ρT\*/ε₁)^α = (ρ/ε₁)^α · (cε₁^α/(αρ^α))^{α/(α+1)} = (c/α)^{α/(α+1)}(ρ/ε₁)^{α²/(α+1)}; and c/T\* = c·(αρ^α/(cε₁^α))^{1/(α+1)} = c^{α/(α+1)}·(ρ/ε₁)^{α/(α+1)}·α^{1/(α+1)}. Factor c^{α/(α+1)}(ρ/ε₁)^{α/(α+1)}·α^{−α/(α+1)}(α + 1) — the displayed J\*. The α = 1 check: 2·1·√c·(ρ/ε₁)^{1/2} = 2√(cρ/ε₁) = 2√(cσρ) with σ = 1/ε₁ ✓ (matches DA-T6ii). ∎

### DA-P1 — The re-judging ledger, one line

> **Proposition (summary form).** Drift budget γ(t) enters judgment as a stage (DA-T4); correcting it costs c per re-judge; at fixed error the cost rate is (c/ε₀)·ρ·(1+ρF/(ε₀−ρF)) — linear in drift with a floor correction; at the joint optimum it is 2√(cσρ) — or ρ^{α/(α+1)} generally; and below the floor (ρF ≥ ε₀) no line item exists: the band is not for sale. (The table the fleet quotes; the numbers the night-audit example prices — `RHO-F-FLOOR.md` §5.)

---

## 6. The labeled-perturbation problem, stated precisely

The composition theory (§4) consumes one hypothesis: the drift budget γ = max_j D_a + D_m with D_m built from the **labeled perturbation** η_s = sup_{x,y} |d_{s+1}(x,y) − d_s(x,y)| — the metric moves *with points keeping their identities*, and the pointwise excursion is summable. The calculus suggested Gromov–Hausdorff-type distance as the natural formalization of metric drift; the attack showed it cannot support verdict stability. This section states exactly what is open.

### DA-P2 — Sufficiency is a theorem; necessity is false

> **Proposition.** (a) *Sufficiency (proved):* a bounded labeled budget bounds verdict error — DA-L1 → DA-T3. This direction needs nothing more.
> (b) *Necessity (refuted by construction):* verdicts can be perfectly stable under **unbounded** labeled perturbation. Let X = {x} ∪ {a} with d(x, a) = r/3 always; let d_t oscillate the a–x distance between r/3 and r/3 (i.e. no oscillation needed) — instead: X = {x, y, a} with d(x,a) ≡ r/3, d(y,a) ≡ r/3, and d_t(x,y) oscillating in [0, D] arbitrarily fast. Then η_s = D ≫ 0 every step (D_m grows unboundedly), yet every membership bit is frozen at distance r/3 < r: **no verdict ever changes; err ≡ 0**. So the labeled budget is sufficient but not necessary: verdict stability does not require a small η; it requires that *distances near the boundary r* stay put.
> (c) *Insufficiency of unlabeled budgets (the relabeling shape, restated):* two frames can be isometric (d_GH = 0) with verdicts reversed — X = {u, v}, answers {u} and {v} exchanged by an isometry; every unlabeled distance structure is identical, every verdict flips. GH-style budgets are *blind to the exact thing verdicts read*: which point is which.

*Proof.* (a) §4. (b) as displayed: D_m(t) = D·t unbounded; membership vectors constant; DA-T3's argument run in reverse shows no error. (c) the two-point swap: d_GH(X₀, X₁) = 0 (identity of distance matrices up to the correspondence u↔v); verdicts ACCEPT(u) vs ACCEPT(v) differ on both inputs. ∎

### DA-D8′ — The exact quantity (the boundary-crossing functional)

> The **crossing functional** of a realization: E(t) = μ({ x : ∃j, the distance process s ↦ d_s(x, a_j(s)) crosses r at some s ≤ t }) — the mass of inputs whose *actual* distance process ever touches the acceptance boundary. Then exactly:
>
> err(t) ≤ E(t) ≤ Φ(γ(t)),
>
> where the first inequality can be strict (a crossing input may recross and end on its original side) and the second is DA-T3. The labeled budget is the *uniform* upper bound on E; the gap Φ − E is the margin slack the uniform bound pays for convenience.

### OP-1 — The open problem

> **Question.** Is there a *verdict-relevant* drift budget β — a functional of the realization family, β ≤ γ on all realizations, strictly smaller on some — such that err(t) ≤ Φ̃(β(t)) for a margin-mass-type Φ̃? Natural candidates: (i) the **boundary-restricted perturbation** η_s^∂ = sup{|d_{s+1}(x,y) − d_s(x,y)| : min(d_s(x,y), d_{s+1}(x,y)) ≤ r + ε'}, capping the perturbation by requiring a near-boundary endpoint; (ii) the **crossing rate** limsup E(t)/t; (iii) budgets defined relative to the support of μ only (the judge does not care how far off-traffic the metric wobbles).
>
> **What a positive answer requires:** a bound of the displayed form, proved, with Φ̃ tight on a natural family (the DA-T3 attainment family minimally).
> **What a counterexample looks like (for candidate (i)):** a realization family with η^∂ ≡ 0 — no near-boundary pair ever moves — yet verdicts flip. Mechanism to attempt: boundary *migration* — pairs drift away from the boundary while new pairs drift in, so the *set* of near-boundary points churns at rate ρ while no near-boundary pair itself moves fast; each fresh arrival at the boundary flips exactly when it lands. Whether "arrival at the boundary" can be made a verdict flip without any near-boundary pair's distance changing fast is the crux — our conjecture is **no** (crossing requires a fast-moving near-boundary distance by continuity of the distance process), i.e. we conjecture candidate (i) *does* bound error with Φ̃ = Φ composed with a boundary-localized margin mass; this is unproved.
> **What a counterexample looks like (for candidate (iii)):** μ supported off-traffic at bind time that *migrates onto* the boundary under the drift (the inputs themselves move — the answer space and the input space are the same X). If inputs may drift, an off-support budget is falsified by mass migration; if inputs are queries fixed by the consumer, (iii) is trivially sound. The problem statement must fix which side inputs live on — the calculus's D3 leaves X static per query; under that reading (iii) is a theorem-level relaxation, and we grade it **sound but unexploited** (the margin mass is already μ-relative).
>
> **Grade: OPEN.** The closing hypothesis of the source (labeled perturbation, identity correspondence on the alias quotient) remains the standing formalization; OP-1 asks whether it is the *weakest* one, and the two candidate counterexample shapes above are where the answer lives.

---

## 7. Machine-check status

**Machine-checked (bounded) 2026-08-29, mathmetal lane:** `tools/verifies/floor_bench.py` — PASS, 844,223 exact Fraction-arithmetic checks. From this paper specifically: **DA-L1** verified on 643,125 enumerated (answer-step, offset-step) sequences; **DA-T3**'s drift band on 1,286,250 instances — 200,693 verdict flips, every one inside the band, plus the attainment instance (margin == γ == 2 exactly); **DA-T1** certainty/soundness exact on the ¼-grid; **DA-T2's annulus tightness with the equality instance exhibited** — a point at distance exactly r + Σρᵢ legally presented at exactly r → ACCEPT (composed tolerance IS r + Σρᵢ), with the inner edge provably open at r − ρ̄ (no legal behavior rejects there); **DA-T5/DA-T6(i)** exact at grid optima (∝ ρ exactly at F = 0); DA-T4's equivalence enters through the same distance-process model (the two adversary arms are its two sides). DA-T7's power-law scaling and OP-1 remain pen (the enumerator covers the linear-Φ regime). Bounds printed per run; no float verdicts.

---

## 8. Statement registry

| Kind | Items |
|---|---|
| Definitions (8+1) | DA-D1 pseudometric · DA-D2 judge · DA-D3 stage/accuracy · DA-D4 pipeline · DA-D5 truth frame/budgets · DA-D6 margins/Φ/error · DA-D7 policy/cost · DA-D8 effective tolerance · DA-D8′ crossing functional |
| Lemmas (3) | DA-L1 perturbation accumulation (full routing) · DA-L2 (unused reserve) · DA-L3 (= RF-L4 equal spacing, cited not restated) |
| Theorems (7) | DA-T1 additive composition (upper) · DA-T2 annulus tightness (lower — new) · DA-T3 drift band (tight) · DA-T4 drift-is-prefilter equivalence · DA-T5 periodic error bound · DA-T6 three pricing laws + sensitivity · DA-T7 power-law scaling (new) |
| Corollaries (3) | DA-C1 design rule (dial = r\* − Σρᵢ) · DA-C2 the twin sentence · DA-C3 (the α-limits reading of DA-T7, unnumbered in-text) |
| Propositions (2) | DA-P1 the re-judging ledger · DA-P2 sufficiency/necessity/GH |
| Open problem (1) | OP-1 weakest verdict-relevant budget, with counterexample shapes |

**What this paper adds beyond the sources.** Over `conjectures.md` Part II: the annulus tightness theorem (DA-T2 — the composed tolerance is exactly r + Σρᵢ, not merely at most); the full routing derivation of DA-L1 made explicit (the one-perturbation trick as a named discipline); the pricing laws unpacked with the floor correction factor displayed, the regime boundary between the √ law and the linear law identified (DA-T6ii), and the sensitivity derivatives computed; the power-law generalization ρ^{α/(α+1)} (DA-T7) with the hard-margin and all-boundary limits; the necessity refutation (verdicts stable under unbounded η — DA-P2b); the crossing functional E(t) with the exact sandwich err ≤ E ≤ Φ(γ); and OP-1 stated with two concrete counterexample shapes and a stated conjecture.

---

*Academic-expansion lane, 2026-08-29. The three-word summary became a theory: additivity exact both ways, drift priced on a schedule, and the one hypothesis the theory eats displayed on the table with its counterexample shapes. The books balance: the tightness gap, the routing trick, and the necessity failure are all first-class citizens.*

**References.** Internal: `quilt-calculus.md` §5 (T3), `conjectures.md` Part II, `RHO-F-FLOOR.md` (the floor as feasibility boundary; shared bench), `zero-claw-update.md` §1 (the applied consumption), `DENY-BY-RUNNING.md` §2 (grades). External: [BBI01] D. Burago, Y. Burago, S. Ivanov, *A Course in Metric Geometry*, AMS GSM 33, 2001 (✤ via the monograph's verified registry — GH distance); [Zin03] M. Zinkevich, ICML 2003 (canonical, carried); [HW98] Herbster–Warmuth, ML 32(2), 1998 (canonical, carried); [BGZ15] Besbes–Gur–Zeevi, OR 63(5), 2015 (canonical, carried); [GZB+14] Gama et al., ACM CSUR 46(4), 2014 (canonical, carried); [YV02] Yu–Vahdat, ACM TOCS 20(3), 2002 (✤ via the registry).
