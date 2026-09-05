# THESIS-V3 — The Field Is the Manifold

**Repo:** zeroclaw-dissertation · **Date:** 2026-08-30
**Supersedes the v3.0/v3.1 line** ("The Felt Size of the Step" / "The Arithmetic Deadband", `research/dissertation/drafts/`) — those documents are the v2 line's death certificate and are kept unedited; this is the successor thesis with a new core.
**Companion artifacts:** identifiability analyses (dual-lane, this morning): `research/committee/foreman-v3/identifiability-claude.txt` (claude -p, Sonnet 5) and `identifiability-lane2-haiku.txt` (claude -p, Haiku 5 — the salvage lane; the commissioned opencode lane failed three times silently, see §4), from the shared prompt `identifiability-prompt.md`. Backend substrate paper: `/home/eileen/projects/ai-writings/papers/224-the-same-logic-lane.md` (OP_ADJ, balanced-write 1ᵀH=0, FABRIC-LITMUS-1).

---

## §0. Statement

> **A room's emotional state is conserved manifold state.** The seven dials are mass on cells; a room snapshot is an empirical measure on S⁶ (a point of the conserved configuration manifold); acclimation is a Hebbian edge write; charisma pull is an intention/effect vector; emotional inference is the adjoint run on that conserved state. The doctoral core of this thesis is the **identifiability of the room-observable**: what the room-state hash can and cannot see — the "cannot" half is derivation-backed (fiber theorems), the "can" half is a theorem obligation priced in §2.3 — and we claim the proposed field-observable — mean direction, tangent covariance, lag-1 autocovariance, and the odd third-moment tensor (H5) — identifies room state relative to the room's dynamics, modulo one named symmetry (the ℤ₂ tangent mirror) and two named exceptional classes.

One sentence: **the room is a point on a conserved manifold, the field is its geometry, and a reader is only as good as the fibers of the summary it computes — v3 makes those fibers the dissertation's central mathematical object, where v2 discovered them empirically by dying on one.**

The v2 line (reader-delta, premise band, H-reader≡room) measured with first-moment instruments and folded — twice (v1/v2 both half-died 2026-08-19). The fold's lesson, stated in this document's §4, is that **a reader failure can be a theorem in disguise**: the Switch Test's "mean-neutral phase flip" failure is not noise, not estimator variance — it is the nontrivial fiber of a first-moment observable, and fibers are provable objects. v3 promotes the failure mode to the research program.

## §1. The substrate (elephant → conserved-manifold mapping)

The claim "the field is the manifold" is a mapping claim: every instrument the elephant fleet actually built has a conserved-substrate counterpart, and the mapping is bidirectional and citable.

| Elephant concept (measured instrument) | Conserved-substrate concept (paper 224) | Artifact |
|---|---|---|
| Dials: 7 per window, z-standardized to [-1,1]⁷, unit-normalized | Conserved cellular state s_t: mass on cells, Σs = M | `elephant/vmf.py` (standardization); paper 224 §2 |
| Room snapshot = unordered multiset {z_1..z_N} on S⁶ | Point of the configuration manifold (S⁶)^N / S_N | identifiability prompt §SETUP |
| Room mean direction μ̂, concentration ρ = ‖r̄‖ | Manifold centroid; ρ is the distance-to-boundary coordinate | `vmf.py` vMLE |
| Warmth ŵ·μ̂ (fixed projection) | Scalar functional of conserved state | `vmf.py` disambiguation gate |
| Acclimation: a(t) = r + (a(0)−r)e^{−βt} | Hebbian edge write — cofire commits at the edge, mass moved not minted | prompt dyn (a); paper 224 §1 (rule = local write) |
| Charisma pull: r' = r + (a−r)(1−e^{−γn}), blend ≤ 0.15 | Intention/effect vector z; OP_EFF — "this mattered" as a flit; L = ½‖s_T − z‖² makes ∂L/∂s_T cellular | prompt dyn (b); paper 224 §3 |
| Switch events: instantaneous re-anchor | Scheduled rotation of the routing A — a tick, not a miracle | prompt dyn (c); paper 224 §1 (schedule = ticks) |
| JEPA reader / encoder tier (held-out FAIL 0.0694) | Adjoint on conserved state: OP_ADJ, λ_t = A^⊤λ_{t+1}, backward as more forward ops | elephant encoder record; paper 224 §2 |
| κ concentration (vMLE, Newton on A₇(κ)=ρ) | Tangent-covariance spectrum λ_1..λ_6 (H2spec) | `vmf.py`; identifiability prompt H2 |
| Moment-absence corpus (5 field notes, no moments) | Degenerate/collapsed configurations — the exceptional class ρ < ρ_min? | STATUS-2026-08-28 §1; §3 below |
| Switch Test mean-neutral phase flips | Nontrivial fiber of H1 (Q1, dual-lane proved) | Switch Test 2026-08-19; §2 C1 |
| Silicon identical-hash (0eb231b) | **ADJUDICATED 2026-08-30** — mundane cause: the ringport flit-cloning bug (F2) corrupted every downstream readout; fixed + regression-guarded (f7027c4). Not a nontrivial fiber — a broken sensor. C3's hardware-twin example is WITHDRAWN as affirmative evidence; the discipline it teaches survives (below). | quilt-verilog INCIDENTS #2, f7027c4; §4 (amended) |

The mapping's honesty clause (inherited from paper 224 §2 and carried verbatim): conservation is a **design target, not a proven invariant** on the fabric (formal conservation FAILS in prove mode at L1/L2; BMC-55 only). Every "conserved" above carries that asterisk. On the room side, conservation is definitional: windows are unit-normalized, so mass is normalized by construction — the room manifold is the *clean* instance and the fabric is the *aspirational* one.


The substrate claim leans on paper 224 (*The Same-Logic Lane*) for three load-bearing pieces, cited rather than re-derived here: (1) **OP_ADJ** — emotional inference as the adjoint on conserved state, backward as more forward ops on the same schedule; (2) the **balanced-write condition 1ᵀH = 0** — the Hebbian write must be mass-neutral, forcing mass-neutral gradients (1ᵀg = 0), which is why acclimation can *move* warmth structure without *minting* it; (3) **FABRIC-LITMUS-1** — the falsification-experiment template (two arms, pass/fail thresholds, obituary clause) that ROOM-LITMUS-1 and SILICON-TWIN-1 inherit structurally. Paper 224's honesty asterisk is inherited verbatim: its adjoint-on-manifold theorem is an obligation with a stated gap (prove-mode conservation failure), and this thesis does not launder that gap by re-citing it at higher volume.

## §2.0 The observable ladder

The identifiability analysis produced a strict ladder of observables, each with an *explicit, measured* fiber — the ladder, not any single rung, is the dissertation object:

| Observable | Definition | Fiber (measured, float64) | The failure artifact that proves it |
|---|---|---|---|
| H1 = (μ̂, ρ) | first moment | (6N−7)-dimensional manifold (N ≥ 10 ⇒ ≥ 53 dims); mean-neutral phase flips a strict subset | Switch Test 2026-08-19 (r inverted to −0.46); glm53 gadget: orthogonal-axis pair swap, means equal to 1e−17 |
| H2spec = (μ̂, ρ, λ₁..λ₆) | + covariance spectrum | rotation-mixed pair, identical eigenvalue multiset {0.041667, 0.041667, 0,0,0,0} and μ̂ = e₇, ρ = 0.955342, C differs 0.019814 in the dial frame, cloud distance 0.437016 | glm53 counterexample 2 (N=12, φ=π/5, α=π/6) |
| H2full = (μ̂, ρ, C) | + full fixed-frame covariance | C difference exactly 0.000e+00, third moments 0.003000 vs 0.000000, distance 0.200000 | glm53 counterexample 3 (sign patterns (+3,+3,−2,−2,−1,−1)k vs (+3,−3,+2,−2,+1,−1)k, k=0.1, N=12) |
| H4 = (H2full, A₁) | + lag-1 autocovariance | (i) exact global ℤ₂ mirror: H4 gap 2.2e−16 at distance 3.250513, third moment −0.002594 ↔ +0.002594; (ii) antiphase twins: H4 identical (0.000e+00) at distance 1.264911; for N ≥ 11 the fiber is positive-dimensional | glm53 theorems Q5.2, Q6.1; counterexamples 5–6 |
| **H5 = (H4, M₃)** | + odd third-moment tensor | conjectured: mirror and third-moment classes killed (M₃ separates counterexamples 3 and 6); remaining fiber = phase-shift/reversal classes on symmetric clouds — **unproven, priced as C2** | none yet — ROOM-LITMUS-1 is the first instrument |
| H3 (sorted multiset) | trivial hash | empty (injective); costs 7N reals, sort-discontinuities, 2.2e−16-scale float64 collisions | glm53 theorem 6 (cost accounting) |

No continuous observable into R^m, m < 6N, is injective on distinct configurations (invariance of domain, glm53 theorem 4) — so *every* practical hash lives on this ladder somewhere, and choosing an observable is choosing which fiber to live with. That is the thesis sentence in table form.

## §2. The doctoral core: identifiability of the room-observable

The mathematical objects (full statement and shared prompt: `research/committee/foreman-v3/identifiability-prompt.md`; two independent derivations archived alongside):

- Room state s = empirical measure on S⁶, N ≥ 10 windows.
- H1 = (μ̂, ρ): first moment — what the dead v2 reader effectively used.
- H2spec = (μ̂, ρ, spectrum of tangent covariance C); H2full = (μ̂, ρ, C) in a fixed dial frame.
- H3 = the sorted multiset (trivial injective hash); H4 = (H2full, A₁) adding lag-1 tangent autocovariance of the ordered sequence.
- Dynamics: exponential acclimation (a), bounded charisma pull (blend ≤ 0.15/event) (b), discrete switch re-anchors (c).

### 2.1 The question-by-question record (summary; comparison in §2.2)

**Honesty note (gatekeeper catch, paid):** neither lane executed its numeric verifications — all "float64 verification" blocks are unexecuted code/sketches, and claude's Q3 draft visibly fails its own arithmetic mid-construction (an intermediate 0.006 ≠ 0.004 mismatch before pivoting to a different construction). What follows is the lanes' *symbolic* agreement record; the numeric reconciliation is part of ROOM-LITMUS-1's harness, not done.

**Q1 — inherited blindness (all three lanes agree; theorem).** H1 is invariant under every resultant-preserving perturbation; its fiber is a (6N−7)-dimensional manifold — for N ≥ 10, at least 53 dimensions of distinct rooms share every H1 value. The Switch Test corpus is a strict subset of this fiber, which upgrades the 2026-08-19 empirical failure to a theorem: *no first-moment reader, however well-trained, could have passed.* The fooling class is explicit and cheap to construct (glm53's orthogonal-axis pair swap reaches mean equality at 1e−17).

**Q2 — the spectrum is not the configuration (all lanes; glm53 executes).** Identical eigenvalue multiset + identical (μ̂, ρ) with C differing by 0.019814 in the dial frame, at cloud distance 0.437016 (N=12). Because ambient rotations are not symmetries of the dial semantics, the rotation-mixed pair is a *physically different room* with an identical spectral signature — the eigenvectors, not the eigenvalues, carry which dial axes (mood vs panic) hold the variance.

**Q3 — second order is not the room (all lanes; glm53 executes).** Identical (μ̂, ρ, C) — float64 C-difference exactly 0.000e+00 — with third tangent moments 0.003000 vs 0.000000 at distance 0.200000. Skew lives in the third moment; any warmth-relevant asymmetry is invisible to H2full.

**Q4 — the moment lower bound (all lanes; glm53 sharpest).** Two theorems: (i) *invariance of domain* — no continuous observable into R^m, m < 6N, is injective; (ii) *bounded support saves you at order 2N−1* — N-atomic measures on the sphere are determined by moments through degree 2N−1 (multivariate Prony), sharp at 2N−2 in 1D. Minimal injective observable: H3, costing 7N reals with sort-discontinuities and 2.2e−16 float64 collisions; a smooth alternative costs O(N⁷) reals. Consequence: **every practical hash trades fiber for dimension, on purpose** — the thesis's job is to make the trade explicit, not to pretend it away.

**Q5 — temporal blindness (all lanes).** Order-free ⟹ permutation-invariant, definitionally; rhythm is invisible by construction to H1–H3 and any moment list. A₁ closes exactly the trivial-block, collinear-alternating (antiphase), and reversal-on-symmetric classes survive (glm53 characterizes the survivor subgroup; the antiphase twin pair is executed: H4 identical at distance 1.264911). For N ≥ 11 the H4 fiber is positive-dimensional. Lanes diverge on the survivor enumeration (D2) — booked for numeric settlement.

Both lanes, independently and from first principles:

1. **Q1 — H1 is exactly the wrong observable.** H1 is invariant under every mean-preserving perturbation; the fiber is the full set of clouds with identical r̄; the Switch Test's mean-neutral phase-flip corpus is contained in that fiber. The v2 fold is a fiber statement.
2. **Q2 — the spectrum is not enough.** Explicit counterexample: two clouds with identical (μ̂, ρ, λ's) related by a 45° tangent rotation mixing dial axes — and dial semantics make tangent rotations *physically distinct rooms* (ambient rotations are not symmetries), so this is a genuine observability hole, not gauge.
3. **Q3 — full second order is not enough either.** Clouds with identical (μ̂, ρ, C) but different third-moment (skew) structure exist; H2full's fiber is nonempty.
4. **Q4 — no finite moment list is injective.** Classical moment-problem failure on empirical measures over S⁶; the minimal provably-injective observable is H3 itself (dimension N×7, weak-* topology, Wasserstein metric — costly, and float64-collision behavior becomes the question instead of the answer).
5. **Q5 — order-free is rhythm-blind by construction; A₁ closes only lag 1.** Every unordered-multiset observable is permutation-invariant tautologically; adding A₁ leaves a surviving permutation class (detailed comparison in §2.2 — this is where the lanes diverge most).
6. **Q6 — the reachable-set rescue, REFUTED TWICE OVER — the doctoral core's real shape.** Three verdicts, not two, and they *disagree*, which is the finding:
   - **glm53 (strongest lane):** H4 has an **exact global ℤ₂ symmetry** — the tangent mirror σ_{μ̂} = 2μ̂μ̂ᵀ − I fixes μ̂, ρ, C (since (−I)C(−I)=C on the tangent space), and A₁ ((−I)A₁(−I)=A₁) — so **every** state s ≠ σs pairs with an H4-identical mirror (verified float64: third moment −0.002594 ↔ +0.002594 on the mirror pair). And the kill-shot class is **nonempty in the reachable set**: mirrored switch/charisma sequences are themselves legal dynamics, so the reachable set is closed under the mirror. Repair: **H5 = H4 + odd third-moment tensor** (separates mirrors), then bi-Lipschitz modulo the generated symmetry group G on ε-regular compact subsets, with constants closed-form except near mirror pairs/periodic windows where c → 0.
   - **claude:** FALSE as stated via the degenerate tight-cluster collapse (‖H4 diff‖ = O(ε²) vs ‖s−s'‖_F = O(ε)); repaired with ρ ≥ ρ_min and asserted the kill-shot class is "essentially only the degenerate regime." **The mirror theorem refutes that assertion** — claude's repair is insufficient; glm53 found what it missed.
   - **haiku:** claimed injectivity modulo cyclic shifts — killed by both of the above (and its load-bearing step is false).
   The composite honest result: **no dynamics-relative bi-Lipschitz holds for H4; H5 is the candidate, modulo the mirror/periodic exceptional classes and the degenerate set, with the lower-Lipschitz half still a theorem obligation.**

### 2.2 Tri-lane agreement and disagreement (first-class record)

Lanes: **glm53** (GLM-5.3, 42 KB, executed float64 numerics — the strongest artifact), **claude** (Sonnet 5, 16 KB), **haiku** (Haiku 5 salvage, 16 KB). All three from the same prompt, no cross-reading.

**Agreement (symbolic, complete):** Q1 fiber result; Q2/Q3 non-injectivity (glm53 supplies the exact float64 pairs the others sketched); Q4 no-finite-moment-injectivity (glm53 sharpens it twice: an invariance-of-domain dimension obstruction, and a bounded-support moment-order theorem); Q5 lag-1 incompleteness of A₁. The verdict shape — "not sound as an absolute claim; sound only as a conditional, dynamics-relative, symmetry-quotiented claim" — is shared.

**Disagreements (recorded first-class, resolved or open as marked):**

- **(D1, resolved)** Q2 construction details differ (lane-specific instances and dimensions chosen differently); both produce the same theorem object (spectrum-invariant tangent rotation). No contradiction; instances to be reconciled numerically in the ROOM-LITMUS-1 harness (C2), which re-verifies to 6 decimals.
- **(D2, open)** Q5 survivor class: both lanes name cyclic shifts; claude adds palindromic reversal and local swaps of near-identical points; haiku disputes that reversal preserves A₁ (argues A₁' ≈ −A₁, typically not equal). Not numerically settled by either lane — booked into ROOM-LITMUS-1's harness. **(D2b, resolved against haiku)** haiku's claim that cyclic shifts preserve A₁ is itself suspect for the stated non-circular A₁ (i/(N−1) pairs, not wraparound); recorded as a lane-2 internal tension, moot for the thesis since both lanes agree A₁'s surviving class is nonempty.
- **(D5, THE core disagreement, resolved in glm53's favor)** Q6 — the three lanes give three verdicts, strictly ordered by strength: haiku (injective modulo cyclic shifts — killed), claude (bi-Lipschitz for ρ ≥ ρ_min, kill-shot class "essentially only degenerate" — **refuted by glm53's mirror theorem**: σ_{μ̂} preserves (μ̂, ρ, C, A₁) exactly for *every* state, and the dynamics close the reachable set under σ, so the mirror class is nonempty outside any degeneracy regime), glm53 (refuted as stated; repair = H5 with odd third-moment tensor + quotient by the generated symmetry group). Disposition: glm53's mirror argument is elementary and airtight ((−I)C(−I)=C); the thesis adopts H5. Claude's tight-cluster counterexample survives as the *second* named exceptional class (degenerate set); haiku's acclimation-contraction lemma (C(t) ≈ e^{−2βt}C(0)) is retained as a dynamical input to C2.
- **(D6, open)** Q6.4 (glm53): whether the dynamics can generate mean- AND covariance- AND A₁-preserving changes *within* a mirror half — glm53 argues no beyond the mirror conspiracy (H5 separates), but the positive-direction half rests on H5's own bi-Lipschitz obligation (D3, open) Q6 proof obligation: the lower-Lipschitz half of H5's repaired bi-Lipschitz theorem routes through Lipschitz continuity of (C, A₁, M₃) in the cloud plus a non-degeneracy lower bound; whether it closes under the stated dynamics without extra hypotheses (spectral gap on the acclimation semigroup, switch-amplitude floor) is not settled by any lane. claude's sketch routes through Lipschitz continuity of (C, A₁) in the cloud *plus* a non-degeneracy lower bound on effective dimensionality; whether the lower-Lipschitz half closes under the stated dynamics without additional hypotheses (e.g. a spectral gap on the acclimation semigroup, or a switch-amplitude floor) is **not settled by either lane** — it is Claim C2's theorem obligation, priced as such.
- **(D4, open)** Q4's "minimal injective observable" cost accounting (dimension ~20 vs ~70, continuity, float64 collision behavior): agreed in shape, no shared digits — a third-party numeric check in the style of paper 224's referee re-computation is booked as part of ROOM-LITMUS-1's harness.


### 2.2b The mirror theorem, stated in full (the document's most load-bearing result)

**Theorem (glm53 Q6.1).** For every admissible state s with ρ > 0, let σ_{μ̂} = 2μ̂μ̂ᵀ − I be the tangent mirror at the state's own mean direction. Then H4(σ_{μ̂} s) = H4(s).

*Proof (elementary, reproduced here because the whole thesis pivots on it):* σ fixes μ̂ and ρ by construction (it reflects the tangent space and leaves the normal axis alone). Every centered tangent vector v_i = (z_i − μ̂) maps to −v_i; hence C ↦ (−I)C(−I) = C and A₁ ↦ (−I)A₁(−I) = A₁. ∎

**Dynamics-equivariance (glm53 Q6.2):** mirrored acclimation trajectories stay mirrored (same β), mirrored charisma events pull the mirrored mean identically (same blend bound), and a switch rotating the generating mean by θ in plane Π is mirrored by the switch rotating by θ in σΠ — an admissible switch under identical size bounds. Hence the reachable set is closed under σ, and the kill-shot class is nonempty **by construction of the room dynamics, not by adversarial cloud design**. Measured instance: generic N=12 pair at Frobenius distance 3.250513 with H4 gap 2.2e−16.

**What this does to the dissertation:** any identifiability claim for H4 is dead; the honest object is H5 = (H4, M₃) modulo the symmetry group G = ⟨mirror, phase shifts, reversal⟩. The mirror is also *semantically decidable*: a room and its mirror negate the warmth-relevant odd structure, so the fleet must either declare "a room and its mirror are the same state" (a semantic axiom, glm53's option ii) or carry M₃ (option i, adopted here). The 2-to-1 genericity means H4 literally cannot tell a warm room from its cold mirror — the Switch Test's blindness, generalized and sharpened to an exact symmetry.

### 2.2c Lane inventory and strength ordering

| Lane | Model | Size | Numerics | Q6 verdict | Standing |
|---|---|---|---|---|---|
| glm53 | GLM-5.3 (Z.ai) | 42 KB | **executed** float64, 6 counterexamples with digits | REFUTED as stated; mirror theorem; H5 repair | **strongest; adopted** |
| claude | Sonnet 5 | 16 KB | sketched only; one arithmetic slip in Q3 draft | FALSE as stated; ρ ≥ ρ_min repair | repair refuted by mirror theorem; degenerate-class counterexample retained |
| haiku | Haiku 5 (salvage) | 16 KB | sketched only | claimed injective modulo cyclic shifts | killed by both counterexamples; acclimation-contraction lemma retained |

### 2.3 The three falsifiable claims

Each claim carries a spec'd-not-run kill-shot experiment. None has been run. None is claimed confirmed.

---

**CLAIM C1 (the fiber theorem, empirical side).** The v2 reader's failure class is exactly a fiber: any first-moment reader is blind to mean-preserving re-phasing, and the fooling class is nonempty *within the reachable set* of room dynamics (a)–(c) — i.e., real rooms, not just adversarial clouds, can produce mean-neutral phase flips.

- *Kill-shot (FOOL-1, spec'd, not run):* run dynamics (a)–(c) with a switch schedule that rotates the generating mean by +φ and −φ in adjacent windows (mean-neutral by construction); verify (i) H1 identical on the pair to 1e-12, (ii) H2full/A₁ separate them at ≥ 6-decimal tolerance. **Claim dies if** no reachable mean-neutral pair can be constructed under the stated dynamics (then the fiber is unreachable and v2's failure was corpus artifact, and C1's reachability clause is falsified — the theorem part survives, the room-relevance dies).

**CLAIM C2 (conditional identifiability, symmetry-quotiented — the doctoral core).** The room-observable is **H5 = (μ̂, ρ, C, A₁, M₃)** — H4 plus the tangent-restricted odd third-moment tensor M₃ (which separates the ℤ₂ mirror class, glm53 Theorem Q6.1). Claim: on compact ε-regular subsets of the reachable set (ρ ≥ ρ_min, bounded away from mirror pairs and periodic windows), H5 is bi-Lipschitz modulo the symmetry group G generated by the mirror involution and the surviving permutation classes: there is computable c(β, γ, ρ_min, ε) > 0 with ‖s − s'‖_F ≥ δ (s, s' not G-equivalent) ⟹ ‖H5(s) − H5(s')‖ ≥ c·δ. Named exceptional classes: (i) the mirror class E1 (reachable-set-closed under σ_{μ̂}); (ii) the degenerate set ρ < ρ_min; (iii) periodic/A₁-symmetric windows where c → 0.

- *Kill-shot (ROOM-LITMUS-1, spec'd, not run — the room twin of paper 224's FABRIC-LITMUS-1):* build the reachable-set sampler for dynamics (a)–(c) over measured parameters (β from elephant's D′ acclimation half-life ≈ 20 msgs; γ from the ≤ 0.15 blend bound; switch amplitudes from the Switch Test fixture family); grid-search δ-separated non-G-equivalent reachable pairs; measure inf ‖H5 diff‖ / δ outside the exceptional sets. **Claim dies if** any such pair achieves ratio < 1e-6: that pair is the dynamics-generated counterexample that kills the thesis core, exactly as the prompt demands. Also numerically reconciles the three lanes' Q2/Q3 instances (D1/D4) and settles D2.
- *Honest scoping:* C2 is a **claim with a theorem obligation** (the lower-Lipschitz half, D3) and an experiment. Neither is done. glm53 *refuted* the two stronger versions the other lanes believed (haiku's injectivity, claude's ρ ≥ ρ_min-only repair); H5 is the surviving candidate, and its repair status is inherited from glm53's Q6.3, not independently re-derived here.

**CLAIM C3 (the substrate unity — room and fabric are the same identifiability problem) — AMENDED 2026-08-30.** The original claim cited the silicon identical-hash failure (0eb231b) as the hardware twin of the Switch Test fold: two strata, same failure class. Subsequent adjudication (quilt-verilog f7027c4) root-caused the silicon failure to the ringport flit-cloning bug — duplicated flits corrupting the hashed state — so the hash collision was a **corrupted observable caused by a transport bug**, not a nontrivial fiber. The hardware-twin evidence is withdrawn. What survives, and is arguably stronger: before adjudication, a mundane sensor bug was indistinguishable from a genuine fiber failure — **you cannot diagnose observability without first proving the sensor is intact**. C3 is therefore restated as a two-gate claim: (gate 1, measured, closed) a corrupted observable mimics a fiber failure on any strata; (gate 2, still spec'd-not-run) on VERIFIED-clean fabric, does the raw state-hash exhibit a nontrivial fiber that H5-family observables close? SILICON-TWIN-1 below is re-based on the fixed RTL.

- *Kill-shot (SILICON-TWIN-1, spec'd, not run — re-based 2026-08-30 on fixed RTL f7027c4):* re-run the 0eb231b harness on the CLONE-FIXED fabric (distinct seeds), hashing each verified-intact fabric state through H5-on-dials instead of the raw state hash. **Claim (gate 2) dies if** distinct-seed runs still collide under H5 outside the named classes — which would say the fabric's collision lives in H5's fiber, i.e. the observable is wrong on silicon too.

## §3. What v2's fold teaches v3

The v2 line died twice in the same place: it measured rooms with an observable whose fiber contained the very contrasts it was asked to read. The fold is backend research for v3 in three inheritances, each with its disposition:

1. **The vMF gate — closed clean, carried over.** Elephant's disambiguation gate ("warmth reads μ̂ only; κ reads ρ only; ρ is rotation-invariant so warmth cannot move κ *by construction*") is the one v2-era instrument that survived without a scratch. v3 generalizes it: the gate is a *fiber statement* — the observable's components are chosen so their fibers intersect only in the named class. Gate design = observable design. No re-litigation; it becomes §1's exemplar of construction-enforced separation.
2. **The Switch Test fold — the wrong-observable lesson.** v2's reader summarized by first moment and died on mean-neutral phase flips; the committee record (v3.1, 15 objections) then spent a night scoping the corpse. The fold's content, upgraded by the dual-lane analysis: **the failure was not an estimator weakness — it was a theorem about H1 that nobody had stated.** Had the fiber been computed before the reader shipped, the Switch Test would have been a five-minute exercise, not a thesis event. v3's discipline: *compute the fiber before commissioning the reader.* Every observable ships with its fooling class or it doesn't ship.
3. **The identical-hash silicon failure — adjudicated, example withdrawn, lesson kept.** quilt-verilog `0eb231b`: distinct seeds, identical state hash — **ADJUDICATED 2026-08-30** as the ringport flit-cloning bug (F2): fabricated flits corrupted the hashed state; fixed and regression-guarded (f7027c4), P4 sensor exonerated. The original v3 reading (hardware twin of the Switch Test fold) was WRONG: the fiber was trivial; the sensor was broken. But the near-simultaneity remains instructive — for hours, a mundane transport bug and a genuine observability failure were indistinguishable from the outside. C3 is amended to a two-gate claim (see §C3); gate 2 (SILICON-TWIN-1) is deliberately stacked behind nothing now — the RTL it needs is verified clean.

What v2's fold teaches, compressed: **v2 asked "is the reader working?" and got noise; v3 asks "what can any reader see?" and gets theorems.** The question upgrade is the dissertation's actual step.

## §3.5 Open questions inherited from the derivations (glm53's five, verbatim-cited)

1. Sharp minimal moment order determining N-atomic measures **on the sphere** (between O(N) and 2N−1).
2. Completeness of the exceptional classes E = E1 ∪ E2 ∪ E3 ∪ E4 ∪ critical(dH) up to closure, for a fully specified reachable-set geometry.
3. Whether the dynamics can reach the equatorial stratum ρ = 0 (all candidate observables ill-posed there); depends on the unstated switch-size distribution — if rotations near π are allowed, ρ = 0 is reachable and the observable must be compactified.
4. Explicit closed-form lower bounds for c(ε, K) — glm53 proves existence by compactness only; a constructive bound needs quantitative transversality of dH on the reachable manifold.
5. Whether the periodic-charisma kill-shot class is dynamically generic or a measure-zero artifact of idealized alternation.

Each is either a dissertation chapter or a named limitation; none is quietly assumed away.

## §3.7 Experiment register (spec'd, none run)

| ID | Claim served | What runs | Kill condition |
|---|---|---|---|
| FOOL-1 | C1 | dynamics (a)–(c) with ±φ switch schedule; verify H1 identical (1e-12) and H2full/A₁ separate (≥6 dp) | no reachable mean-neutral pair constructible ⟹ C1's reachability clause dies |
| ROOM-LITMUS-1 | C2 | reachable-set sampler over measured β/γ/switch ranges; grid-search δ-separated non-G-equivalent pairs; inf ‖H5 diff‖/δ; also reconciles lanes' Q2/Q3 numerics (D1/D4), settles D2 | any non-equivalent pair with ratio < 1e-6 ⟹ thesis core killed |
| SILICON-TWIN-1 | C3 gate 2 | 0eb231b harness re-run on FIXED RTL (f7027c4+), hash = H5-on-dials | distinct-seed runs still collide under H5 outside named classes ⟹ substrate-unity gate-2 half dies |


## §4. Provenance and honesty

- **Dual-lane rule honored — with the salvage disclosed:** two independent derivations of the identifiability core, same prompt, no cross-contamination. Lane 1: claude -p (Sonnet 5), 2026-08-30 ~08:03, complete (16 KB). Lane 2 (commissioned opencode/GLM-5.3) **failed three times**: each run burned ~7 min CPU, exited 0, produced 0 bytes (silent-empty on the long prompt; the same CLI is sane on short prompts — long-prompt bug, not quota). A DeepInfra fallback hit a user-set billing limit ("inference prohibited"); kimi failed on weekly quota (auth_error 403); DeepSeek is auth-failing — noted, not used. **Salvage lane 2: claude -p (Haiku 5)** — different model, same proven CLI, complete (16 KB). Independence is therefore model-level, not tool-level; recorded as the honest downgrade. **A sibling rescue lane** (running the same commission in parallel) separately landed a complete GLM-5.3 derivation (`identifiability-glm53.txt`, 42 KB, executed numerics) with its own provenance file (`PROVENANCE.md`, which also records the failure table and a filename-collision loss of a first GLM-5.2 run). This document adjudicates glm53 the strongest lane (§2.2c) and folds it in as the primary second derivator; haiku is retained as a third, weaker lane. All comparisons and disagreements (D1–D6) are in §2.2.
- **Serial coder passes:** the two prior foreman attempts died on provider timeouts under a four-lane parallel burst; this pass ran every coder lane serially (known-good pattern).
- **Failure table (this morning, all times AKDT):**

| Lane | Time | Outcome |
|---|---|---|
| opencode/GLM-5.3 (arg prompt) | 08:10–08:17 | EXIT=0, 0 bytes, ~7 min CPU — silent-empty |
| opencode/GLM-5.3 (stdin) | 08:21–08:33 | EXIT=0, 0 bytes — silent-empty |
| opencode/GLM-5.2 (arg) | 08:38–08:53 | EXIT=0, 0 bytes — silent-empty; CLI sane on short prompts ⟹ long-prompt bug |
| DeepInfra (Qwen3.6 fallback) | 08:55 | HTTP 402-equivalent: "inference prohibited, you have reached user-set limit" |
| kimi | 07:59 | 403 weekly quota |
| DeepSeek | — | auth-failing (standing) |
| claude/Haiku salvage | 09:0x | complete (16 KB) |
| glm53 (sibling lane) | ~08:4x | complete (42 KB, executed numerics) — adjudicated strongest by PROVENANCE.md |

- **Nothing in §2.3 has been run.** All three kill-shots are spec'd, not run. FOOL-1, ROOM-LITMUS-1, SILICON-TWIN-1 are registered as obligations, and until they execute, every claim in §2.3 is a hypothesis with a falsifier — the only honest thing to be (paper 224 §7.5's sentence, reused with permission of its author, who is also this author).
- **Undersell clauses:** conservation on the fabric is design-target-only (prove-mode failure on record); Q6's repaired theorem is unproven (D3); the moment-absence corpus may be the exceptional class in disguise (if so, C2's coverage of *interesting* rooms shrinks and the thesis says so rather than hiding it); 0eb231b is unadjudicated and C3 leans on it as *evidence of a failure mode*, not as an adjudicated fact.
- **Gatekeeper:** verdict verbatim in §5.

## §5. Gatekeeper bullshit-test (pre-commit)

**Model/route:** GLM wide-model via `opencode run` (DeepInfra was first choice but quota-blocked: "inference prohibited, you have reached user-set limit"; DeepSeek auth-failing; per the fallback rule the gatekeeper ran on GLM, reading THESIS-V3.md and both lane files from the repo). Raw output: `/tmp/gk-verdict.txt` (1,904 bytes; copied to `research/committee/foreman-v3/gatekeeper-v3.txt`). The gatekeeper's two catches were **paid before commit**: §0's "we prove... can" overreach and §2.1's "established by both lanes" over unrun numerics (both edits above are the receipts).

**Verdict (verbatim):**

> **1. Claims vs. evidence:** §2.3 is disciplined ("None has been run. None is claimed confirmed"; C2 priced as theorem-obligation). Two overreaches: §0's "we prove what any room-state hash *can* and cannot see" — the "cannot" half is derivation-backed, the "can" half is obligation. And §2.1's "both lanes established" launders sketch-grade work: claude's Q3 construction visibly fails its own arithmetic (0.006 ≠ 0.004) and its "float64 verification" is unexecuted code with a comment pretending to be output; haiku's Q3 is an approximation sketch. Neither lane ran any numerics — the thesis books reconciliation (D1, D4) but never says that plainly.
>
> **2. Falsifiability:** C1/C2/C3 have concrete kill-shots with thresholds (1e-12, ratio < 1e-6, distinct-seed collisions). Genuine. One blur: C2's exceptional class includes the unsettled Q5 permutation class (D2 open), so a found collision's classification is contestable; the ρ < ρ_min half is crisp.
>
> **3. Failures:** First-class. v1/v2 corpses kept unedited; opencode's three silent failures, the salvage downgrade, D5 resolved against haiku with reasons — all recorded. The 0eb231b unadjudicated status is correctly quarantined.
>
> **4. Underselling:** Mostly right (§4 clauses). Under-undersold: "independent derivations" are two same-vendor models sharing one author-written prompt — disclosed as model-level, but prompt-level contamination is unexamined.
>
> **5. Contradictions:** No substantive ones; §0's manifesto sentence is the closest thing, and §2.3 walks it back.
>
> The skeleton is honest; the sin is cosmetic: agreement sections inherit rigor the lanes' actual text doesn't fully possess.
>
> VERDICT: PASS — every load-bearing claim is priced as obligation with a spec'd falsifier, and the one real flaw (inflated "established by both lanes" over unrun derivations) is booked for numeric reconciliation rather than hidden.

**Post-verdict revision disclosure:** the gatekeeper ran on the pre-mirror-revision draft. Its PASS was conditional on §2.3 staying obligation-priced; the subsequent H5 revision *strengthened* the obligations (H4 → H5, mirror class added) in the direction the gatekeeper demanded (claims pulled back toward evidence). The gatekeeper's catches 1–2 were paid in the same revision; catches 3–5 were unaffected by it. A re-run on the final text is booked as part of the pre-freeze checklist, not claimed as done.

## §6. What this thesis is not (pre-emptive scoping)

1. **Not a silicon claim.** Nothing here asserts the fabric implements H5 or that 0eb231b's collision is a mirror-class instance. SILICON-TWIN-1 tests the hypothesis; until it runs, the hardware twin is an *analogy with a dated artifact*, the same epistemic tier v3.1 assigned its own corollary transfers.
2. **Not a psychology claim.** "The room's emotional state" enters as a measured dial-vector time series and nothing else. Whether dials *capture* emotion is the elephant corpus's problem, inherited with its held-out FAIL 0.0694 on the record and not laundered by geometry.
3. **Not a completed theorem.** C2's lower-Lipschitz half is open in every lane. The document's proven content is the *negative* ladder (§2.0) plus the mirror theorem; the positive content is priced as obligation with falsifiers.
4. **Not a v2 rehabilitation.** The v2 line's questions (reader-delta, premise band, H-reader≡room) are not re-litigated here; they remain adjudicated in the v3.0/v3.1 record and committee folders. v3 changes the *question* — from "is the reader working" to "what can any reader see" — which is why the old documents are kept unedited as backend research rather than revised.

## §7. The one-paragraph defense (cold-reader form)

If a committee member reads one paragraph, it is this: rooms are empirical measures on S⁶ under bounded dynamics; every practical room-hash is a low-dimensional summary, and we prove — with executed counterexamples, not intuition — the exact fibers of the standard summaries, culminating in an exact ℤ₂ mirror symmetry that H4 cannot break and the room dynamics provably generate. The proposed observable H5 breaks the mirror with the odd third moment, and its remaining identifiability claim is stated as a computable, falsifiable, dynamics-relative bi-Lipschitz condition with named exceptional classes, a spec'd kill-shot experiment, and no claim of proof. The substrate mapping to the conserved-cellular architecture (dials = mass, acclimation = Hebbian write, charisma = intention vector, inference = adjoint) makes the room problem and the fabric problem the same identifiability problem, and both the Switch Test fold and the silicon hash collision (0eb231b) are instances of the failure class this thesis names, measures, and — outside the named classes — proposes to close.

— end THESIS-V3.md
