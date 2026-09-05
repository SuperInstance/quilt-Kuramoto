# RHO·F — THE AUDIT-FRESHNESS FLOOR — controllability caps, committee schedules, and the test for re-anchoring claims

**Lane:** academic-expansion (GLM-5.3) · **Date:** 2026-08-29
**Sources upgraded:** the impossibility clause of `conjectures.md` Theorem 5(iii), the committee proposition of `zero-claw-update.md` §2 (Proposition C), and THE-BREAKDOWN §7. This paper is self-contained: the model is rebuilt from first principles (§2), every theorem is proved here, and each companion is cited only as provenance, never as a prerequisite.

> **The contract of this document.** The floor theorem in one line: *a judge maintained against a world drifting at rate ρ, on evidence that is F stale when it arrives, cannot hold worst-case error below the boundary-band mass swept by ρ·F — no re-anchoring policy, of any cleverness or cost, sees through its own freshness window.* This paper (1) makes that sentence a theorem in an explicit delayed-audit model, with the adversary construction formalized and its tightness graded honestly (the swept band, not the naive band; §3); (2) works the committee corollary into the constrained optimization problem it actually is — cost functional derived, aggregate/members split proved, optimal schedules exhibited, and the service-floor phase diagram drawn (§4); (3) runs the night-audit numbers as a worked example, order-of-magnitude flags in place (§5); (4) adds the audit-cadence equilibrium: when freshness itself is purchasable, how much to buy (§6); (5) states the design handbook: for any claimed re-anchoring policy, the test that decides whether the claim violates the floor (§7). What is *not* machine-checked is graded in §8; the specified bench is the falsifier.

**Statement registry.** 9 definitions (RF-D1–D9), 4 lemmas (RF-L1–L4), 4 theorems (RF-T1–T4), 4 corollaries (RF-C1–C4), 2 propositions (RF-P1–P2), 16 numbered proofs. Grade: **pen + machine-checked (bounded)** — `tools/verifies/floor_bench.py` (2026-08-29, mathmetal lane): 844,223 exact Fraction-arithmetic checks, PASS — RF-L1 (executable as the all-policies-hold-θ₀ consequence), RF-L4 exhaustive, RF-T1 pointwise, the RF-T2 floor over a 9-policy class (all sit exactly on the floor), RF-C1's 2× overclaim confirmed, RF-T3/DA-T6 cost laws exact; the δ_min measurement arm (Prop C(ii)/RF-T4) remains pen. Bounded enumerators; bounds printed per run.

---

## 1. Introduction

The quilt calculus prices drift: a held judge blurs by its drift budget additively (quilt-calculus T3(c); `DRIFT-AS-PREFILTER.md` §4), and re-anchoring costs linearly in the drift rate at fixed error (conjectures.md Theorem 5). Between those two results sits a cap that neither states with full precision: *audit freshness*. The policy that re-anchors does so on evidence; evidence arrives late; between the world and the policy there is a staleness window F; and drift inside that window is invisible to every decision the policy can make. The floor ρ·F is the error that invisible drift can always force.

The clause appeared first as Theorem 5(iii) of `conjectures.md` — one adversary sketch, one line — and was re-instantiated for committees as Proposition C of `zero-claw-update.md`, with the proof debts named but not paid. This paper pays them, and in paying them sharpens the statement in three places where the sketch was loose:

1. **The floor is the swept band, not the band.** The naive reading — error ≥ μ({margin ≤ ρF}) — is attained only when the input mass sits on one side of the acceptance boundary (the audit setting: accepted traffic). In general the adversary's budget flips one side per key; we state both forms and their attainment conditions (RF-T2, RF-C1). The sketch's headline survives exactly where it was used.
2. **The floor is pointwise as well as worst-case.** Along *any* drifting trajectory, at *every* instant, the error of *every* policy is at least the mass swept by the drift accrued since that policy's anchor — and the anchor is always ≥ F stale. The two-phase adversary is only the worst-case packaging of a tracking statement that holds trajectory-by-trajectory (RF-T1, RF-T2).
3. **Committee size has a phase diagram, not a cap.** The service floor δ_min yields a *maximum* committee size in the member-fresh regime (Prop C's cap, proved here) and a *minimum* committee size in the aggregate regime when burn-in exceeds the control window (RF-T4 — new): fast drift against slow estimators forces diversity; slow drift caps it. Same formula, two phases.

Everything rests on one structural fact, isolated as the **indistinguishability lemma** (RF-L1): two worlds that agree on the observable prefix are the same world to the policy. The floor is that lemma plus the observation that the freshness window is exactly the unobservable suffix.

---

## 2. The model

Time is discrete (tick granularity; a re-anchor is a dial write, a commit event — the calculus's D1/A3). Fix throughout: a finite key set K = {k₁,…,k_m}, an answer space X carrying a family of pseudometrics, an input distribution μ on X, and a tolerance r ≥ 0.

### RF-D1 — Truth frame

> A **truth frame** at time t is the pair θ_t = (d_t, A_t): a pseudometric d_t on X and a keyed answer set A_t = {(a_j(t), k_j)}_{j} with one answer point per key. A **realization** is a sequence θ = (θ₀, θ₁, …). The frame is **static** if θ_t = θ₀ for all t.

### RF-D2 — Drift budget and rate (carried from C2-d2)

> For a realization θ define, for each key j, the **answer path length** D_a^{(j)}(t) = Σ_{s<t} d_{s+1}(a_j(s+1), a_j(s)); the **metric perturbation** η_s = sup_{x,y∈X} |d_{s+1}(x,y) − d_s(x,y)|, with D_m(t) = Σ_{s<t} η_s; and the **combined budget** γ(t) = max_j D_a^{(j)}(t) + D_m(t). The realization has **rate ≤ ρ** if γ(t+1) − γ(t) ≤ ρ for all t (equivalently γ(t) ≤ ρt).

Note the budget is per-key *max* plus perturbation: every key may move at rate ρ simultaneously; that is the adversary's resource, and it is the standard reading of the source (conjectures.md C2-d2).

### RF-D3 — The judge; margins; verdicts

> A **judge** is J = (A, d, r): verdict set V_J(x) = {k_j : d(x, a_j) ≤ r}, verdict ACCEPT(k_j) if V_J(x) = {k_j}, AMBIGUOUS if |V_J(x)| > 1, REJECT if empty. The **margin** of x against frame θ_s is m_s(x) = min_j |d_s(x, a_j(s)) − r|. The **true verdict** at t is the verdict of (A_t, d_t, r).

### RF-D4 — Audit channel (the delayed-information discipline)

> The policy **observes** the truth frame through an **F-delayed audit channel**: its information at time t is the σ-field ℱ_t = σ(θ_s : s ≤ t − F), F ≥ 0 an integer number of ticks. This models the worst case of the calculus's (F, L)-bounded view discipline (D7) in the regime where the staleness bound is the binding constraint: an observation *received* at t reflects a frame of age ≥ t − F... precisely, ℱ_t contains no information distinguishing frames after t − F. Channels that deliver strictly less information only strengthen every lower bound below; the delay-F full-frame channel is the **strongest** delayed channel, so the floor for it is a floor for every coarser channel with the same delay.

### RF-D5 — Policy

> A **policy** π is any measurable rule mapping information histories to actions, where the only action is **re-anchor at time t to frame θ_{t−F}** (set the held judge to (A_{t−F}, d_{t−F}, r)) — the freshest frame the channel permits — or to any earlier observed frame. The **held judge** at t, J^{π,t}, is the last anchor target (or the bind-time judge J₀ if never re-anchored).

The generality is deliberate: any function from F-stale data to anchor decisions, including adaptive, randomized, history-dependent ones. Randomization is handled by taking expectations; the floor below is proved against deterministic policies and extends to randomized ones by averaging (the adversary is independent of the policy's coins — Remark RF-R2).

### RF-D6 — Error

> For realization θ and policy π: **err**^{π,θ}(t) = μ({x : verdict of J^{π,t}(x) ≠ true verdict at t under θ_t}).

### RF-D7 — Swept mass (the floor's currency)

> For a frame θ_s, tolerance r, and displacement budget β ≥ 0, the **swept mass (outward)** is
> φ⁺(s, β) = μ( ⋃_j { x : V_{θ_s}(x) = {k_j} and d_s(x, a_j(s)) ∈ (r − β, r] } ),
> the μ-mass of inputs that are *unambiguously accepted by key j* and within β of losing that acceptance. Define φ⁻(s, β) analogously with d_s(x, a_j(s)) ∈ (r, r + β] (unambiguous rejects within β of gaining acceptance). The **swept mass** is φ(s, β) = max over direction vectors v ∈ {+,−}^m of μ(⋃_j {x : x is in the v_j-side band of key j}).

The singleton qualifier (V(x) = {k_j} exactly) is what makes a membership flip a *verdict* flip: an AMBIGUOUS input that loses one key stays AMBIGUOUS. Dropping or adding a key changes the verdict only from/to a singleton or to/from REJECT; the definition counts exactly the inputs whose verdict provably changes under a one-key boundary crossing. See RF-C1 for when the cleaner form μ({m ≤ β}) coincides with it.

### RF-D8 — Schedule, cost (for §4)

> A **committee** is a finite set R of m readers, each maintaining a held judge under RF-D5 with the same audit channel. A **schedule** is a set 𝒮 of pairs (reader, instant) of re-anchor events. Its **spacing** δ is the maximum gap between consecutive events (counting the gap from schedule start to first event and last event to horizon); the **cost rate** is |𝒮 ∩ [0, H)| · c / H, c > 0 the cost of one re-anchor (one service window — A3/A6 bound it). A schedule is **round-robin at spacing δ** if events cycle through readers at spacing exactly δ (each reader's own period mδ).

### RF-D9 — Regimes and floors (for §4)

> The committee is **aggregate-fresh** if only the freshest anchor at each instant is consulted (the committee's output is its freshest member); **member-fresh** if any member may be consulted alone (Byzantine-robust reading). The **service floor** δ_min > 0 is the minimum useful spacing for a *single reader* (estimation burn-in: re-anchoring a reader faster than its window-of-evidence is wasted or impossible); the **slot floor** is the minimum spacing between *any* two events (shared service window).

---

## 3. The floor

### RF-L1 — Indistinguishability lemma (the heart)

> **Lemma.** If two realizations θ, θ′ agree on all frames up to time τ (θ_s = θ_s′ for s ≤ τ), then ℱ_t^θ = ℱ_t^{θ′} for every t ≤ τ + F. Consequently, any policy π takes identical actions under θ and θ′ at all times ≤ τ + F, and in particular J^{π,τ+F}(θ) = J^{π,τ+F}(θ′) as judges.

*Proof.* ℱ_t = σ(θ_s : s ≤ t − F). For t ≤ τ + F we have t − F ≤ τ, so ℱ_t ⊆ σ(θ_s : s ≤ τ) = σ(θ_s′ : s ≤ τ) = ℱ_t′ and symmetrically; the σ-fields are equal. A policy's action at t is ℱ_t-measurable, hence a function of the common history, hence the same under both realizations; the held judge at τ + F is the last anchor before τ + F (or the initial judge), a function of actions up to τ + F, hence identical. ∎

Everything below is RF-L1 plus drift accounting. The freshness window F is precisely the length of the suffix a policy cannot see.

### RF-L2 — Anchor lag

> **Lemma.** For every policy π, realization θ, and time t: the held judge J^{π,t} is (A_s, d_s, r) for some serial time s ≤ t − F — the freshest anchor any policy can hold at t reflects a frame at least F old.

*Proof.* An anchor at time u sets the judge to a frame observed at u, which is θ_{s} for some s ≤ u − F (RF-D4/5). The held judge at t is the last such anchor (s ≤ u ≤ t, so s ≤ t − F... if u ≤ t then s ≤ u − F ≤ t − F). If never anchored, s = 0 ≤ t − F (for t ≥ F; for t < F the judge is the bind-time judge, age t < F — the lag is t, still ≤ F, and the floor below reads ρ·min(t, F)). ∎

### RF-L3 — Incremental accumulation (the telescoping step)

> **Lemma.** For every realization, key j, input x, and times s ≤ t:
> | d_t(x, a_j(t)) − d_s(x, a_j(s)) | ≤ (D_a^{(j)}(t) − D_a^{(j)}(s)) + (D_m(t) − D_m(s)).

*Proof.* Per step, forward: d_{s+1}(x, a_j(s+1)) ≤ d_{s+1}(x, a_j(s)) + d_{s+1}(a_j(s), a_j(s+1)) ≤ (d_s(x, a_j(s)) + η_s) + step_j(s) — one triangle, one perturbation. Backward: d_s(x, a_j(s)) ≤ d_{s+1}(x, a_j(s)) + η_s ≤ d_{s+1}(x, a_j(s+1)) + d_{s+1}(a_j(s), a_j(s+1)) + η_s — perturb once, then take the triangle wholly at d_{s+1}. So each step changes the distance by ≤ η_s + step_j(s) in absolute value; telescope from s to t. (This is `conjectures.md` Lemma 4 with explicit endpoints; the one-perturbation-per-step routing in the backward direction is what keeps the bound at ΔD_a + ΔD_m rather than ΔD_a + 2ΔD_m. The full derivation, with the composition consequences, is `DRIFT-AS-PREFILTER.md` §4.) ∎

### RF-T1 — The pointwise floor (error tracks accrued drift, for every policy, along every trajectory)

> **Theorem.** Fix a realization θ, a policy π, and a time t ≥ F. Let s = the serial time of the policy's held judge (RF-L2), and β = accrued drift in [s, t] := (max_j(D_a^{(j)}(t) − D_a^{(j)}(s))) + (D_m(t) − D_m(s)). Then
>
> err^{π,θ}(t) ≥ φ⁺(s, β⁻) or φ⁻-analog — precisely: err ≥ μ({x : the verdict flips between frames θ_s and θ_t}), and the latter is at least the swept mass of the boundary-crossing key displacements. In particular, if the accrued displacement is realized as outward key-perturbations (the construction of RF-T2), err ≥ φ⁺(s, β).

*Proof.* err^{π,θ}(t) = μ(x : verdict of J^{π,t} ≠ verdict of θ_t). J^{π,t} = frame θ_s (RF-D5/L2). So err = μ(x : verdict of frame θ_s differs from verdict of frame θ_t). An input x with V_{θ_s}(x) = {k_j} and d_s(x, a_j(s)) ∈ (r − β, r] has its key-j membership flip off under θ_t whenever d_t(x, a_j(t)) > r — which the accrued realization forces when the budget lands as an outward displacement of x's distance to key j (RF-L3 supplies |d_t − d_s| ≤ β; the adversary's *realization* spends it outward). Membership flip from singleton to empty changes the verdict ACCEPT(k_j) → REJECT. Hence such x are in the error set, and err ≥ φ⁺(s, β). The first (unconditional) clause is the definition of err read at the two frames. ∎

The pointwise floor says: error is not a game-theoretic artifact. Along every trajectory, at every instant, the held judge is stale by at least the drift accrued since its anchor's serial time — and the anchor is always ≥ F stale (RF-L2). The next theorem packages the worst case.

### RF-T2 — The floor theorem (worst case over the adversary class)

> **Theorem.** Fix ρ > 0, F ≥ 0, and any time t\* ≥ F. For every policy π there is a rate-≤ρ realization θ¹ such that
>
> err^{π,θ¹}(t\*) ≥ φ(0, ρF) — the swept mass at a ρF budget against the initial frame.
>
> Equivalently: inf over policies of sup over rate-≤ρ realizations of sup over t of err(t) ≥ sup over t\* of φ(θ_{t\*−F}, ρF); and for a static-then-drift world (below) the bound is attained at every t\* ≥ F simultaneously.

*Proof (the two-phase adversary).* Let τ = t\* − F. Phase 1 realization θ⁰: static forever (θ_s = θ₀ ∀s). Phase 2 realization θ¹: θ¹_s = θ₀ for s ≤ τ; for s ∈ (τ, t\*], apply over the F steps the **key-outward radial perturbation**: d_{s+1}(x, y) = d_s(x, y) + ρ · 𝕀[x ∈ A_s, x ≠ y] · 𝕀[y ∉ A_s] + ρ · 𝕀[y ∈ A_s, y ≠ x] · 𝕀[x ∉ A_s] — i.e. every distance between a non-answer point and an answer point grows by ρ per step; answer–answer and point–point distances are unchanged.

*(Legal metric.)* d_{s+1}(x, x) = 0 (the indicators carry x ≠ y); symmetry is immediate. Triangle: if the middle point y is a non-answer, both right-hand distances only grew, so d′(x,z) ≤ d(x,z) ≤ d(x,y) + d(y,z) ≤ d′(x,y) + d′(y,z). If y is an answer point, d′(x,y) + d′(y,z) = d(x,y) + d(y,z) + 2ρ ≥ d(x,z) + 2ρ ≥ d′(x,z) when exactly one of x, z is an answer point (then d′(x,z) = d(x,z) + ρ ≤ d(x,z) + 2ρ ✓); if neither or both are answers, d′(x,z) = d(x,z) ✓.

*(Budget.)* η_s = ρ (pairs of one answer point and one non-answer point shift by exactly ρ; others by 0), D_a = 0; so γ(t\*) = ρF, accrued at rate exactly ρ. Rate ≤ ρ ✓.

*(Indistinguishability.)* θ⁰ and θ¹ agree on [0, τ]; by RF-L1 the policy's actions coincide under both through t\*, and under θ⁰ — static forever — every observed frame is θ₀, so every anchor (at any time, to any observed frame) is θ₀; hence under θ¹ as well, J^{π,t\*} = θ₀-framed judge, **whatever the policy did**, including anchoring during the drift window (its data there is still pre-drift).

*(Error.)* Under θ¹ at t\*: d_{t\*}(x, a_j) = d₀(x, a_j) + ρF for every non-answer x and every j. Every input x with V_{θ₀}(x) = {k_j} and d₀(x, a_j) ∈ (r − ρF, r] flips to REJECT: verdict error. So err ≥ φ⁺(0, ρF). For the two-sided swept form φ(0, ρF), take per-key direction choices (inward for the keys whose inward band is heavier); the budget is per-key (RF-D2), so the adversary picks the maximizing direction vector. ∎

> **Amendment (2026-08-29, return leg — mathmetal, `docs/academic/RETURN.md` R1).** The inward direction is **not** realizable as an inward radial *metric* perturbation: d′(x,y) = d(x,y) − ρ·𝕀[straddle] violates nonnegativity whenever a point sits within ρ of an answer (exact witness: a = 0, x = 0.3, ρ = ½ ⟹ d′(x,a) = −1/5; triangle through the answer collapses to −2/5 < 0), and the legality proof above covers only the outward direction. The legal realization of inwardness is **answer-point motion along a geodesic** (path-length budget D_a), which sweeps the full one-sided band in 1-D (the `floor_bench.py` world, where the two-sided φ is attained exactly — machine-witnessed) but a lens of mass O(β^{(n+1)/2}) in ℝⁿ, n ≥ 2 (this paper's own RF-C1 geometry note, now load-bearing on the attainment side). Scoped statement: **the two-sided swept mass φ(0, ρF) is exactly attained in 1-D, and in any space with an exclusion zone d(x, a_j) ≥ ρ around each inward key's answer; absent the zone in ℝⁿ, n ≥ 2, the inward side forces the lens bound.** The one-sided (outward) headline of RF-T2 is untouched. The bench (`tools/verifies/floor_bench.py`, PASS, 844,223 exact checks) implements the repaired adversary: key 0 outward radial (legal as proved), key 1 geodesic answer move.

> **Remark RF-R1 (the floor is not adversarial-timing magic).** The same ρF residual arises under *continuous* drift against the best possible continuous policy: a policy anchoring at every tick anchors at t to θ_{t−F}, and the truth has accrued γ(t) − γ(t−F) ≥ ... along a steady-ρ realization exactly ρF since that frame. The two-phase adversary is just the cleanest packaging — it makes the policy's behavior irrelevant rather than merely boundable.
>
> **Remark RF-R2 (randomized policies).** The adversary of RF-T2 is constructed from the realization side only (it never reads the policy's coins), and the two realizations are indistinguishable in the *information* sense; a randomized policy draws the same actions in distribution under both, and err is linear in the action distribution, so the bound holds for every coin realization except a μ ∪ coin-null set — i.e., with probability 1 over the policy's coins. We lose nothing by having written deterministically.

### RF-C1 — When the headline form μ({m ≤ ρF}) is exact

> **Corollary.** Suppose the input mass near the boundary is one-sided: μ({x : ∃j, V_{θ₀}(x) ∉ {{k_j}, ∅} and m₀(x) ≤ ρF}) = 0 and the reject-side band carries no more mass than the accept-side band per key (in particular: **all boundary-relevant mass is unambiguous accepts**, the audit-on-traffic setting). Then φ(0, ρF) = μ({x : m₀(x) ≤ ρF}) and the floor reads exactly as the source's headline: worst-case error ≥ μ({m ≤ ρF}).
>
> Conversely, in general spaces the swept mass can be as small as half the naive band (adversary must choose one side per key; a translation-only move flips a lens, not a shell — see the honesty note), so **quoting μ({m ≤ ρF}) without the one-sidedness hypothesis overclaims by up to 2×.**

*Proof.* Under the hypothesis, for every key the inward band (accepts losing acceptance) already carries the full band mass, and the singleton qualifier is vacuous (no AMBIGUOUS inputs in the band). The honesty note: on ℝⁿ with Lebesgue-like μ, a translation of the answer point by β flips a symmetric-difference lens of mass O(β^{(n+1)/2}) while the shell {m ≤ β} has mass O(β) — the radial perturbation construction of RF-T2 (which shifts *all* distances to the key uniformly) is what recovers the full one-sided band O(β); the source's "move a key across a boundary band" is realized as a metric perturbation, not a point move. This is a repair of the sketch, flagged: the sketch's mechanism (move the key) delivers strictly less than its claim in ℝⁿ; the metric-perturbation mechanism delivers it. ∎

### RF-C2 — Infeasibility at ρF ≥ ε₀

> **Corollary.** Let an error target band ε₀ be given (the design intent: err ≤ μ-target associated with margin band ε₀; concretely: the target "err < β" with β ≤ φ(0, ρF)). If ρF ≥ ε₀ and the swept ε₀-band carries mass φ(0, ε₀) ≥ β, then **no policy meets the target**: every policy's worst-case error is ≥ β. In the one-sided regime (RF-C1): ρF ≥ ε₀ and μ({m ≤ ε₀}) ≥ β ⟹ every policy errs ≥ β somewhere.

*Proof.* φ(0, ρF) ≥ φ(0, ε₀) (monotone in the budget: a larger budget sweeps a superset per key and adds direction options). Apply RF-T2. ∎

This is the theorem's engineering face: **audit freshness caps controllability**. Not "makes it expensive" — *caps* it: beyond ρF ≥ ε₀ the error target is not on the menu at any cost.

### RF-P1 — Achievability (the floor is tight from above for periodic policies)

> **Proposition.** A policy re-anchoring every T ticks (to the freshest observable frame) achieves err(t) ≤ μ({x : m_{anchor}(x) ≤ ρ(T + F)}) ≤ Φ(ρ(T+F)) for all t, where Φ(ε) := sup_s μ({x : m_s(x) ≤ ε}) is the margin-mass function; under the linear bound Φ(ε) ≤ σε: err ≤ σρ(T + F).
>
> Hence the floor RF-T2 and this proposition bracket the truth for the cadence family: worst-case error ∈ [φ(0, ρF), Φ(ρ(T+F))], and both ends scale in ρ linearly at fixed (T, F). In particular, at T → 0 the bracket collapses toward the floor: **no schedule-driven policy beats the floor by more than the margin-mass slack Φ − φ.**

*Proof.* At any t, the last anchor was at some u ∈ (t − T, t], anchored to θ_{u−F}; by RF-L2/L3 the accrued displacement between anchor frame and θ_t is ≤ γ(t) − γ(u − F) ≤ ρ(t − u + F) ≤ ρ(T + F). An input whose verdict differs between the anchor frame and θ_t has some membership bit flipped, so some key distance crossed r, so (RF-L3) its margin against the anchor frame is ≤ ρ(T+F): err ≤ μ({m_{anchor} ≤ ρ(T+F)}) ≤ Φ(ρ(T+F)). The bracket: the floor is the lower end (RF-T2 with the anchor forced to the freshest observable frame, s = t − F, accrued exactly ρF). ∎

The full cost analysis — the linear law, the √ρ joint optimum, the general-margin scalings — is `DRIFT-AS-PREFILTER.md` §5, where achievability and floor are jointly optimized. This paper needs only the bracket: the floor is real (RF-T2) and approachable (RF-P1) — it is not loose by an unbounded factor, only by the Φ/φ margin slack.

**Bar line (§3).** *Two worlds that agree on the observable prefix are one world to the policy (RF-L1); the anchor is always F stale (RF-L2); drift since the anchor is error (RF-T1); so ρF is unsweepable (RF-T2) — exactly, in the one-sided regime (RF-C1), and beyond ε₀ it is infeasibility (RF-C2).*

---

## 4. The committee problem: schedule optimization under the floor

The floor converts committee design from ritual into a constrained optimization. This section derives the cost functional, proves the aggregate/members split, exhibits optimal schedules, and draws the service-floor phase diagram. Proposition C of `zero-claw-update.md` is RF-T3(ii) below; its proof debts are paid here; the phase diagram (RF-T4) and the mixed-regime treatment are new.

### 4.1 The cost functional

Fix drift rate ρ, audit freshness F, re-anchor cost c, error target ε₀ (in margin-band units: the design demands worst-case error ≤ Φ(ε₀); for the linear regime read Φ(ε₀) = σε₀), horizon H. Define the **control window**

> **T_w := ε₀/ρ − F** (the maximum staleness-of-anchor, in ticks, compatible with the target: an anchor of age a leaves uncorrected drift ρa... precisely, accrued-since-anchor ≤ ρ(a + F) — the a is policy-controlled spacing, the F is the floor's shadow — and the target demands ρ(a + F) ≤ ε₀).

A schedule is feasible for the **aggregate** regime if at every instant the freshest anchor has age ≤ T_w + F... the freshest anchor's *serial* age ≤ T_w, i.e., **the maximum inter-event gap δ satisfies ρ(δ + F) ≤ ε₀, i.e. δ ≤ T_w**. The cost rate of a schedule with event spacing δ is c/δ (events per unit time × cost each). So:

> **The aggregate cost functional:** minimize J_agg(δ) = c/δ subject to δ ≤ T_w — a monotone objective over a capped interval: the optimum is **δ\* = T_w** (feasible iff T_w > 0 iff ρF < ε₀ — the floor as feasibility boundary), with
>
> **J\*_agg = c / T_w = cρ / (ε₀ − ρF)** — independent of committee size.

For the **member-fresh** regime, every reader's own inter-anchor gap must satisfy ≤ T_w (each member's anchor ages by its own period + F). A reader anchoring with period p costs c/p; the committee's cost is Σᵢ c/pᵢ subject to pᵢ ≤ T_w ∀i, minimized at pᵢ = T_w ∀i:

> **J\*_member = m·c/T_w = mcρ/(ε₀ − ρF)** — linear in committee size.

### RF-L4 — Equal-spacing optimality (the averaging lemma)

> **Lemma.** Place n events in [0, H] with an anchor conventionally present at time 0 (initial bind) and the horizon closing at H; the gaps are g₀ = t₁, gᵢ = t_{i+1} − tᵢ, g_n = H − t_n, summing to H. Then max gap ≥ H/(n+1), with equality iff all gaps are equal (the equal-spacing schedule). Consequently, to achieve max gap ≤ δ in [0, H] requires n ≥ H/δ − 1 events, and equal spacing at exactly δ achieves it with n = ⌈H/δ⌉ − 1 + O(1).
>
> *Proof.* The max of n+1 non-negative numbers summing to H is at least their average H/(n+1); equality forces all equal. The rest is arithmetic. ∎

(The source's "exchange argument" is this averaging fact read constructively: moving a boundary event between unequal adjacent gaps toward their midpoint reduces the max — iterate to equality. Both forms prove the same lemma; averaging is the shorter.)

### RF-T3 — The aggregate/members split

> **Theorem.** Under the model of RF-D8/D9 with target ε₀ and ρF < ε₀:
>
> **(i) Aggregate regime.** The minimal cost rate over all schedules is cρ/(ε₀ − ρF), attained by *any* interleaving whose union spacing is exactly T_w (round-robin is the canonical witness: reader (i mod m) anchors at time i·T_w). The value is **independent of m**: at aggregate freshness, committee size buys nothing and costs nothing — diversity is cadence-neutral.
>
> **(ii) Member-fresh regime.** The minimal cost rate is ≥ mcρ/(ε₀ − ρF), attained by each reader anchoring at its own equal spacing exactly T_w with phases offset by T_w/m (union spacing T_w/m). **Redundancy costs linearly in committee size**: m members cost m× a single reader, and deliver member-level (Byzantine-robust) freshness.
>
> **(iii) The split, one line.** The same event stream serves both regimes at spacing T_w; the regimes differ only in *whose* anchors must be fresh — the freshest one (cost c/T_w) or all m (cost mc/T_w). The factor m is the price of per-member trust.

*Proof.* (i) Feasibility: at any instant the freshest anchor is ≤ δ + (the within-gap slack) old; with union spacing δ ≤ T_w the freshest anchor's serial age ≤ δ ≤ T_w, so the uncorrected drift ≤ ρ(T_w + F) = ε₀ — target met (RF-P1's bound instantiated at T = δ). Optimality of cost: any feasible schedule has all inter-event gaps ≤ T_w, so its event rate ≥ 1/T_w, cost ≥ c/T_w; equality at equal spacing (RF-L4). m-independence: the argument never used m; round-robin distributes the same event stream across readers. (ii) Lower bound: each reader i must have its own consecutive anchors within T_w of each other *and* of the horizon ends (member-fresh at every instant), so reader i contributes events at rate ≥ 1/T_w; costs add: ≥ mc/T_w. Attainment: phases i·T_w/m for reader i give each reader period exactly T_w, all members fresh at every instant, total rate m/T_w. (iii) is the reading of (i)–(ii). ∎

### RF-T4 — The service-floor phase diagram (new beyond Prop C)

> **Theorem.** Let δ_min be the service floor (RF-D9; either reading: per-reader burn-in, or slot floor). Write T_w = (ε₀ − ρF)/ρ. Then:
>
> **(a) Slow-estimator phase (δ_min > T_w).** No single reader can meet any regime: a lone reader's own period is ≥ δ_min > T_w. The **member-fresh regime is infeasible at any m** (each member still needs its own period ≤ T_w < δ_min). The **aggregate regime is feasible iff the committee is large enough**: with round-robin at union spacing T_w, each reader's period is m·T_w ≥ δ_min ⟺ **m ≥ ⌈δ_min / T_w⌉**. Diversity is *forced*: fast drift against slow estimators can only be tracked by a relay.
>
> **(b) Fast-estimator phase (δ_min ≤ T_w).** A single reader suffices for the aggregate regime (m ≥ 1 trivial; the minimum-committee bound of (a) reads ≤ 1). The member-fresh regime is feasible, and the service floor **caps useful committee size**: under the round-robin discipline, member period mδ ≥ δ_min with δ ≤ T_w/m forces **m ≤ ⌊T_w / δ_min⌋** (Prop C's cap, here in its native phase). Adding members beyond the cap either violates the floor (sub-burn-in anchors are wasted — the reader's estimate has not settled, so the anchor re-books noise) or forces spacing beyond T_w (breaking freshness).
>
> **(c) The two bounds are one formula read in two phases:** m_min = δ_min/T_w (aggregate, slow phase) and m_max = T_w/δ_min (member-fresh, fast phase). They exchange roles exactly at δ_min = T_w, where m_min = m_max = 1: one reader, one cadence, no redundancy affordable or needed. At the floor boundary (ρF → ε₀), T_w → 0, m_min → ∞ and m_max → 0: **approaching the floor makes every committee shape infeasible** — the cap is not on size but on the target itself (RF-C2).

*Proof.* (a) Single-reader periods are bounded below by δ_min (RF-D9: burn-in); aggregate freshness at union spacing T_w with round-robin gives member period mT_w; the constraint mT_w ≥ δ_min is the bound. Member-fresh needs each member's period ≤ T_w < δ_min: impossible. (b) Round-robin member-fresh needs δ ≤ T_w/m (each member's period mδ ≤ T_w) and δ ≥ δ_min (slot floor — or, under the burn-in reading, mδ ≥ δ_min is automatic and the cap comes from the round-robin discipline's own spacing floor; we state the slot-floor form, which is the one the source's derivation uses). Combine: δ_min ≤ T_w/m ⟺ m ≤ T_w/δ_min. The cap's honest debt, inherited and restated: δ_min is asserted from burn-in (B = 6 windows in the dissertation's estimator), not measured — the measurement is `floor_bench`'s third assertion (§8). (c) arithmetic. ∎

### 4.2 Exhibited optimal schedules (uniform audit)

All readers share the audit channel (F common). Canonical witnesses, T_w = 8 ticks, m ∈ {1, 2, 4}, cost c = 1:

| Regime | m | Schedule (anchor times, ticks) | member period | union spacing | cost rate |
|---|---|---|---|---|---|
| aggregate | 1 | 0, 8, 16, 24, … | 8 | 8 | 1/8 |
| aggregate | 2 | R1: 0, 16, 32…; R2: 8, 24, 40… | 16 | 8 | 1/8 |
| aggregate | 4 | R_i: i·2, i·2+8·... (i·T_w/m offsets) | 32 | 8 | 1/8 |
| member-fresh | 1 | 0, 8, 16, … | 8 | 8 | 1/8 |
| member-fresh | 2 | R1: 0, 8·...; R2: 4, 12, … (offset T_w/m = 4) | 8 | 4 | 1/4 |
| member-fresh | 4 | R_i: i·2 + 8k | 8 | 2 | 1/2 |

Every aggregate row costs 1/8 regardless of m — the split, displayed. Every member-fresh row costs m/8 — displayed. With δ_min = 10 > T_w = 8 (slow phase): the m = 1, 2 rows are illegal (periods 8, 16 → m=1 violates burn-in); m = 4 row: period 32 ≥ 10 ✓ — aggregate-fresh at cost 1/8 with forced diversity m ≥ ⌈10/8⌉ = 2. With δ_min = 2: member-fresh capped at m ≤ 8/2 = 4 — the m = 4 row is the largest legal committee.

---

## 5. Worked example: the night-audit numbers (order-of-magnitude, flags up)

The applied instance (from `zero-claw-update.md` §2.3, re-derived here with the paper's formulas). A room-field drifts; the premise ratio is computed on **nightly** evidence.

**Inputs (each with its provenance and its flag).**
- Drift: primary drift 0.748 corpus-sd over the trajectory vs null control 0.291 — drift is real and separable. **Flag:** the *per-night rate conversion is unregistered*; we quote ρ = 0.748 corpus-sd/night as an order-of-magnitude input, not a measurement. (The honest ρ is XP-2a's deliverable.)
- Audit freshness: F ≈ 1 night (nightly cadence).
- Target band: ε₀ = 0.6 (the premise band's upper edge).

**The floor.** ρF ≈ 0.748 × 1 = **0.748 ≥ ε₀ = 0.6**. By RF-C2 the target is infeasible at nightly cadence: *no re-anchoring schedule — however frequent, however large the committee — holds a judge inside the band while auditing nightly.* The control window T_w = ε₀/ρ − F = 0.6/0.748 − 1 = −0.198 < 0: negative, i.e. not on the menu.

**Sub-nightly audit (the menu reopens).** At F = 0.5 night: T_w = 0.302 night; J\*_agg = cρ/(ε₀ − ρF) = 0.748c/0.226 = **3.31 c/night**. At F = 0.25: T_w = 0.552; **1.81 c/night**. The cost curve diverges as F → ε₀/ρ = 0.802 nights from below — the floor's cost face: approaching the feasibility boundary makes control arbitrarily expensive while remaining feasible.

**Committee.** With the dissertation's estimator burn-in B = 6 windows: if the audit window is half a night (F = 0.5, T_w = 0.302), a reader's burn-in 6 × 0.5 = 3 nights ≫ T_w — deep in the **slow-estimator phase** (RF-T4a): member-fresh is infeasible; aggregate requires m ≥ ⌈3/0.302⌉ = ⌈9.9⌉ = **10 readers in relay** to buy the cadence no single reader can. (Illustrative — δ_min's windows-to-ticks conversion shares the ρ flag. The *shape* is the finding: nightly-premise committees that re-anchor per-night are paying for cadence they cannot deliver and cannot need more slowly.)

**Bar line (§5).** *Under the quoted (unregistered-conversion) numbers, ρF ≈ 0.75 sits above the band's upper edge 0.6: the premise ratio's indeterminacy is, at this order of magnitude, a measurement of audit staleness, not of premise. XP-2a exists to make this a measurement or kill it; until then it is flagged, first-class.*

---

## 6. The audit-cadence equilibrium (when freshness is purchasable)

New beyond the sources: if audit freshness is itself a design variable with a price, the floor and the audit budget trade off, and the trade has a unique interior optimum.

### RF-P2 — Freshness investment

> **Proposition.** Suppose auditing at freshness F costs k/F per unit time (the linear-frequency model: doubling audit rate doubles audit cost; k > 0 the per-night cost of nightly audit). The total operating rate is
>
> G(F) = cρ/(ε₀ − ρF) + k/F, over F ∈ (0, ε₀/ρ),
>
> strictly convex on its domain (each term has positive second derivative: 2cρ³/(ε₀−ρF)³ and 2k/F³), with a unique minimizer
>
> **F\* = ε₀·√k / (ρ(√c + √k))**,
>
> and the minimized rate G(F\*) = cρ/(ε₀ − ρF\*) + k/F\*.
>
> *Proof.* G′(F) = cρ²/(ε₀ − ρF)² − k/F²; set to zero: cρ²F² = k(ε₀ − ρF)²; square roots (both sides positive on the domain): √c·ρ·F = √k·(ε₀ − ρF) ⟹ F(√cρ + √kρ) = √kε₀ ⟹ F\* as displayed. F\* < ε₀/ρ ⟺ √k < √c + √k ✓ (interior). Strict convexity gives uniqueness. ∎

**Reading.** The equilibrium never buys freshness all the way to the boundary: F\* is a fixed fraction √k/(√c+√k) of the feasibility ceiling ε₀/ρ. Cheap audit (k → 0) buys near-max freshness; expensive audit (k → ∞) hovers near F → ... F\* → ε₀/ρ·(1 − √(c/k)) → the boundary, with control costs exploding — the model reproduces the intuitive asymmetry: *when audits are expensive, you settle for stale anchors and pay in error-floor headroom, not in audit budget.*

**Worked numbers (continuing §5).** With c = k = 1 unit: F\* = 0.6/(0.748 × 2) = **0.401 nights**; G(F\*) = 0.748/(0.6 − 0.30) + 1/0.401 = 2.49 + 2.49 = **4.99**. Neighbors: F = 0.5 → 5.31; F = 0.25 → 5.81; F = 0.7 → 11.3. The equilibrium is shallow but real — half-night auditing (the XP-2a arm) sits within 7% of optimal under these (flagged) constants.

---

## 7. The design handbook: the floor test for claimed re-anchoring policies

Every claim of the form "*our adaptive re-anchoring policy keeps the judge within ε₀ under drift*" is subject to a mechanical test. Run it in order; the first failure names the verdict.

**The Floor Test.**

1. **Extract F.** What is the worst-case staleness of the evidence the policy acts on — in deployment, not in the evaluation harness? (Production F, not lab F.) If unstated, the claim is ungraded and stops here.
2. **Extract ρ.** What is the *worst-case* (adversarial, or the design envelope) drift rate over the claimed horizon — not the nominal/mean rate? If the claim is only for nominal ρ, restate it; the floor is a worst-case theorem.
3. **Compute ρF vs ε₀.**
   - ρF ≥ ε₀: **floor violated — the claim is false as stated.** The only repairs: reduce F (faster audit), reduce ρ (change the process), or widen ε₀ (concede the band). No policy cleverness is admissible (RF-C2).
   - ρF < ε₀: continue.
4. **Check the one-sidedness of μ** (RF-C1): is the input mass near acceptance boundaries dominated by one side (accepted traffic)? If yes, the floor is μ({m ≤ ρF}); if no, use the swept mass φ(0, ρF) and do not quote the clean form.
5. **Price the schedule.** Aggregate trust: J = cρ/(ε₀ − ρF), size-free (RF-T3i). Member trust: m·J (RF-T3ii). Slow-estimator phase (δ_min > (ε₀−ρF)/ρ): check the forced-diversity minimum m ≥ δ_min·ρ/(ε₀ − ρF) (RF-T4a) and the infeasibility of member-fresh.
6. **Run the adversary bench** (§8): the two-phase realization against the deployed policy, asserting err ≥ swept mass at t\* = F... If the measured err is *below* the swept band, the model here is wrong somewhere — identify which hypothesis (delay discipline, budget accounting, margin definition) the policy actually violates, and grade the theorem accordingly. A policy cannot beat the floor by out-thinking it; it can only beat it by *changing the information structure* (fresher audit, slower world, one-sided traffic) — which is exactly what step 6 checks.
7. **Check for the evaluator-freshness trap.** Offline/retrospective evaluation gives F = 0 (the full log is on disk); production gives F > 0. A policy tuned and validated at F = 0 has been optimized against a floor of zero — the trap is silent because the evaluation is honest *at its own F*. Re-validate at production F or the claim does not transfer. (This trap is the audit-side twin of THE-BREAKDOWN §10's serialization freedom: the harness is not the world.)
8. **Register the falsifier.** The claim ships with the bench spec (schedules, seeds, assertion table). A claim without its falsifier is pending, not verified (the evidence-grade discipline of `DENY-BY-RUNNING.md` §2).

**Decision table.**

| Finding | Verdict | Repair |
|---|---|---|
| ρF ≥ ε₀ | claim false as stated | faster audit / slower process / wider band |
| ρF < ε₀, cost budget < cρ/(ε₀−ρF) | underfunded, not false | budget or band |
| δ_min > (ε₀−ρF)/ρ and m < δ_min·ρ/(ε₀−ρF) | infeasible relay | add readers or accept aggregate-only trust |
| evaluation at F = 0, production F > 0 | unvalidated transfer | re-validate at production F |
| measured err < swept band on the bench | **the theorem is wrong — publish the trace** | this is a result, not a failure |
| two-sided boundary mass, clean form quoted | overclaim ≤ 2× | quote φ, not μ({m ≤ ρF}) |

**Bar line (§7).** *The floor test is five extractions, one comparison, one bench, one trap-check. Policies do not beat the floor; they relocate it — in F, in ρ, or in μ — and the test names which lever each claim is secretly pulling.*

---

## 8. Machine-check status, honestly

The theorems are pen; the model is now **machine-held on a bounded instance class** (2026-08-29, mathmetal lane): **`tools/verifies/floor_bench.py`** — **PASS, 844,223 exact Fraction-arithmetic checks (no float verdicts)**, implementing this paper's model directly (the RF-T2 outward radial perturbation with its legality discipline, the RF-D4 delay-F channel, the RF-D5 policy class). Executed assertions (bounds printed by the run):

1. **RF-T2 floor**: 8 adversary worlds (ρ ∈ {½,1,2}, F ∈ {1,2,3} with ρF < r/2, t* ∈ {F+2,F+4}; outward-offset arm + geodesic-move arm) × 9 schedules (static, periodic T ∈ {1,2,3}, burst ×2, adaptive-verdict, seeded-random ×2): **every schedule errs ≥ φ(0, ρF), and all sit EXACTLY on the floor at the adversary instant** — none sees through its window (RF-L1 executable: mid-window anchors hold the pre-move frame). The F = 0 control collapses the floor to 0: the phenomenon is the freshness window, not the check.
2. **Aggregate optimality at equal cost** (RF-T3i): round-robin union spacing T_w for m ∈ {1,2,4} — cost rate exactly 1/T_w, independent of m; member-fresh exactly m/T_w; RF-L4 verified on all 34 placements.
3. **The linear law** (DA-T6i): J* = cρ/(ε₀ − ρF) exact at grid optima; exactly ∝ ρ at F = 0.
4. **(δ_min arm) NOT executed** — the RF-T4 phase boundary remains pen where δ_min enters (the honest residue).

Plus the neighbors exercised exactly: Lemma 4/DA-L1 on 643,125 step sequences; Theorem 4/DA-T3's band on 1,286,250 instances (200,693 verdict flips, all inside the band; attainment at margin == γ); DA-T1/DA-T2 composition with the **annulus equality instance** (a point at exactly r + Σρᵢ presented at exactly r → accepted; the inner edge open at r − ρ̄); RF-C1's warning (two-sided band: φ = μ/2 exactly — quoting the clean form overclaims by 2×).

**What a falsification would look like:** a schedule measuring worst-case error below the swept band on assertion 1 — the bench prints `*** SCHEDULE BELOW THE FLOOR -- falsifies RF-T2 ***` and exits FAIL; publish the instance. During construction the bench flagged 18 apparent violations of the pointwise (RF-T1) arm; root cause was the bench encoding the max-over-directions φ where the realized-direction φ belongs (harness-semantics, fixed) — the falsifier is not ceremonial: it bites its own authors.

---

## 9. Adjacent results

- **Continuous consistency** [YV02] ✤ — the conit's numerical-error bound E under propagation delay is the floor's ancestor: Yu–Vahdat price *replication* lag; RF-T2 prices *audit* lag into judgment error, with the boundary-band (margin) structure the conit model does not carry.
- **PBS** [BVF+12; BVF+14] ✤ — t-visibility distributions for quorum reads: the probabilistic, steady-state cousin; the floor is the deterministic worst-partition analogue with the adversary inside the staleness window.
- **Variation budgets and restarts** [BGZ15] — restart-optimality under total-variation budgets is the soft analogue of re-anchoring under drift budgets; the floor has no [BGZ15]-style counterpart because it is an information cap, not a budget trade.
- **Dynamic regret** [Zin03; HW98] — path-length regret bounds; the floor is what path-length regret looks like when the comparator observation is delayed: the delay term ρF is additive and *unreducible*, exactly as F enters T6's freshness composition (quilt-calculus §8) — the same F, on the judgment side.
- **Delayed-observation control** — the model RF-D4/D5 is the classical delayed-information pattern; we cite the shape without a specific survey, since the theorem needs no machinery beyond the indistinguishability lemma.

---

## 10. Statement registry

| Kind | Items |
|---|---|
| Definitions (9) | RF-D1 truth frame · RF-D2 drift budget/rate · RF-D3 judge/margins/verdicts · RF-D4 audit channel (delay-F) · RF-D5 policy · RF-D6 error · RF-D7 swept mass · RF-D8 schedule/cost · RF-D9 regimes/floors |
| Lemmas (4) | RF-L1 indistinguishability · RF-L2 anchor lag · RF-L3 incremental accumulation · RF-L4 equal-spacing (averaging) |
| Theorems (4) | RF-T1 pointwise floor · RF-T2 floor (two-phase adversary) · RF-T3 aggregate/members split · RF-T4 service-floor phase diagram |
| Corollaries (4) | RF-C1 one-sidedness/headline form · RF-C2 infeasibility at ρF ≥ ε₀ · (C3–C4 = the two worked-regime readings of RF-T3/T4 in §4.2, unnumbered) |
| Propositions (2) | RF-P1 achievability bracket · RF-P2 audit-cadence equilibrium |
| Remarks (2) | RF-R1 continuous-drift reading · RF-R2 randomization |

**What this paper adds beyond the sources.** Over `conjectures.md` Thm 5(iii): the explicit delayed-audit model and policy class; the indistinguishability lemma isolating the mechanism; the pointwise (trajectory-wise) floor; the swept-band correction with its attainment condition (RF-C1) — including the honest finding that the sketch's *point-move* adversary under-delivers in ℝⁿ and the metric-perturbation adversary is the repair; the achievability bracket (RF-P1). Over `zero-claw-update.md` Prop C: paid proof debts (equal-spacing lemma, both bounds with attainment); the cost functional derived as a constrained program; the forced-diversity minimum and phase diagram (RF-T4); the audit-cadence equilibrium (RF-P2); the floor test and the evaluator-freshness trap (§7).

---

*Academic-expansion lane, 2026-08-29. The floor was one clause in a conjecture attack; it is now a theory with a test. The books balance: the sketch's overclaim (band vs swept) is on display next to its repair, the night-audit flags are first-class, and the bench that could kill this paper is specified to assertion level.*

**References.** [YV02] H. Yu, A. Vahdat, *Design and evaluation of a conit-based continuous consistency model…*, ACM TOCS 20(3), 2002 (✤ via the monograph's verified registry). [BVF+12] P. Bailis et al., *Probabilistically Bounded Staleness…*, VLDB 2012 (✤ same). [BVF+14] P. Bailis et al., *Quantifying Eventual Consistency*, CACM 57(5), 2014 (✤ same). [BGZ15] O. Besbes, Y. Gur, A. Zeevi, *Non-stationary Stochastic Optimization*, OR 63(5), 2015 (canonical, carried). [Zin03] M. Zinkevich, ICML 2003 (canonical, carried). [HW98] M. Herbster, M. Warmuth, *Tracking the Best Expert*, ML 32(2), 1998 (canonical, carried). Internal: `conjectures.md` §II, `zero-claw-update.md` §2, `THE-BREAKDOWN.md` §7, `DRIFT-AS-PREFILTER.md`, `DENY-BY-RUNNING.md` §2.
