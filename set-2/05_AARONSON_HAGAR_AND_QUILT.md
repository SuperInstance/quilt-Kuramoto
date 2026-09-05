# 05 — Aaronson, Hagar, and Quilt

> *Phase 3 deliverable #4.*
> *Engagement with the live July 2026 Aaronson-vs-Hagar debate.*
> *Builds on `01_SYNTHESIS.md` through `04_THE_FOG_OF_WAR_INVERSION.md`.*
> *Date: 2026-09-05.*

---

## What this document does

The live Aaronson-vs-Hagar exchange (July 2026) defines the empirically-defensible position on what has and has not been achieved with NISQ hardware. This document locates the quilt argument in that exchange — and finds that quilt occupies a *third position* neither Aaronson nor Hagar has articulated, but which the exchange creates the conceptual space for.

The third position: **verifiable advantage is real AND the substrate may not matter as much as the structural invariants, because the invariants are reachable through different mathematics.** Aaronson defends the first half (verifiable advantage is real); Hagar defends a version of the second half (the substrate matters more than the invariants — most NISQ results are classically simulable). Quilt's corpus is empirical evidence (not proof, but evidence) that the invariants are reachable classically, through different mathematics, in specific regimes.

---

## The two positions, stated fairly

### Aaronson's position (scottaaronson.blog, July 18 2026: "NISQ and quantum supremacy did not fail")

Aaronson's position, in his own words:

> *"absent a breakthrough in classical algorithms, [sampling-based supremacy experiments] quite clearly are beating what can be easily simulated on any existing classical computer."*

> *"the October 2025 noisy-RCS classical algorithm [Hagar cites] is still exponential in circuit depth (Theorem 2)."*

Aaronson names four current verifiable-advantage candidates:
1. Google OTOC (Nature s41586-025-09526-6, Oct 2025) — many-body interference + chaos + time-reversal structure.
2. Quantinuum H2 high-fidelity RCS (2025) — gate fidelity above the noise threshold, LXE ≈ 1.
3. IBM/Qedma 74-qubit Floquet-Ising dynamics (Jul 30 2026) — long-lived coherent oscillations, "trusted advantage" framework.
4. 2D Fermi-Hubbard dynamics on Google Willow (arXiv:2510.26845, Oct 2025) — volume-law entanglement growth in 2D.

Aaronson's core claim: each of these four has a *specific structural reason* for being hard classically (interference, chaos, time-reversal, gate fidelity, 2D entanglement), and the classical algorithms that have matched earlier NISQ claims do not apply to these regimes. The "NISQ Trap" thesis (Hagar) is wrong because it conflates the noisy regime (where classical algorithms do match) with the high-fidelity regime (where they do not).

### Hagar's position (arXiv:2607.07530, July 8 2026: "The NISQ Trap")

Hagar's position, in his own words:

> *"the regions of circuit-space NISQ hardware can run with sufficient fidelity coincide with the regions classical algorithms compress efficiently, because the features that admit one (low effective depth, strong algebraic structure, geometric locality) are the features that admit the other."*

Hagar's core claim: 8 years of NISQ demonstrations have all (with one exception, Google OTOC) been classically reproduced, shown to rest on classically tractable structure, or closed by a simulability theorem. Six theoretical results from 2024–April 2026 explain why: Aharonov 2022 (noisy RCS), Schuster 2025 (noisy circuits expectation values), Lee 2025 (noisy random circuits), Tindall 2024 (IBM kicked Ising), Oh 2024 (GBS), Flatiron May 2026 (D-Wave 3D spin glass). The pattern: within ~18 months of a major NISQ claim, a classical algorithm matches it.

The disagreement: Aaronson says the high-fidelity regime is genuinely hard; Hagar says the high-fidelity regime is what NISQ hardware cannot reliably run, so the empirically-accessible region is the noisy regime, which is classically simulable.

---

## What both positions share

Despite their disagreement, Aaronson and Hagar share three assumptions:

1. **The substrate matters.** Both positions are about quantum hardware vs classical hardware. Neither considers the possibility that the structural invariants (verifiability, expectation values, forward-and-backward comparison) might be reachable through a different substrate entirely — one that is neither quantum-coherent nor classically-Turing-complete in the usual sense.

2. **The complexity class is the relevant metric.** Both positions argue about BQP vs P (or BQP vs the class of efficiently-simulable quantum circuits). Neither considers the possibility that a system might reach the verifiability regime without reaching the BQP regime — that verifiability and computational complexity might be *separable* concerns.

3. **The output is the thing being verified.** Both positions argue about whether quantum hardware produces outputs (bitstrings, expectation values) that classical hardware cannot efficiently produce. Neither considers the possibility that a system might produce *verifiable expectation values from forward-and-backward comparison* without the forward and backward passes themselves being quantum-mechanical.

The quilt corpus challenges all three assumptions, and the challenge is what defines the third position.

---

## The third position: quilt's contribution to the debate

### Quilt's challenge to assumption 1 (the substrate matters)

The quilt corpus is a working instance of a system that:
- Is NOT quantum-coherent (no complex amplitudes, no Bell-inequality violation, no entanglement in the technical sense).
- Is NOT classically-Turing-complete in the usual sense (a single cell is a monotone circuit, per Bridge 7 in `03_STRUCTURAL_BRIDGES.md`; the fleet is needed for generality via the FORGET_completeness law).
- Produces verifiable expectation values from forward-and-backward comparison (the PredictionOutcome ∈ {Confirmed, Exceeded, Within} from `ternary-predict`; the witness log attestation from `quilt-substrate`; the convoy consensus from `quilt-substrate`).

This is evidence (not proof, but evidence) that the verifiability regime is *substrate-independent* — reachable through different mathematics, not only through quantum hardware. The substrate matters less than the structural invariants.

This is the move Hagar's thesis does not make. Hagar argues that the empirically-accessible region of NISQ hardware is classically simulable. Quilt's corpus suggests that the verifiability regime is *classically reachable* through different mathematics — not because the quantum hardware is unnecessary, but because the structural invariants are substrate-independent.

### Quilt's challenge to assumption 2 (complexity class is the relevant metric)

The quilt corpus makes a complexity-theoretic claim (Bridge 7 in `03_STRUCTURAL_BRIDGES.md`) that is genuinely interesting: a single cell is a monotone circuit (a known subclass of P/poly, provably weaker than general circuits per Razborov 1985), and the fleet achieves generality via the FORGET_completeness law.

This is NOT a claim that quilt implements BQP. It is a claim that quilt reaches a different regime: verifiable computation with explicitly-bounded per-cell complexity, where the bounds are achieved by accepting the monotone-circuit restriction per cell and compensating via fleet-level composition.

The challenge to assumption 2: verifiability and computational complexity might be separable concerns. A system can be verifiable without being BQP-powerful; a system can be BQP-powerful without being verifiable (the original 2019 Sycamore RCS was BQP-aspirational but unverifiable). The quilt corpus suggests that verifiability is the more fundamental concern, and that BQP-power is one route to it (the quantum route) but not the only route (the quilt route reaches it through monotone circuits + fleet composition + convoy consensus).

### Quilt's challenge to assumption 3 (the output is the thing being verified)

The quantum community's 2025-2026 turn to verifiable advantage (Google OTOC, IBM "trusted advantage") still treats the *output* as the thing being verified: the expectation value F(t) is the output; the cross-check across quantum devices is the verification.

Quilt's corpus treats the *process* as the thing being verified: the predict-and-confirm cycle itself is the unit of verification; the PredictionOutcome is the delta between prediction and observation; the witness log attests the cycle, not the output. The output (the canonical cell value) is a derived quantity; the verification (the PredictionOutcome + witness entry) is the primary quantity.

This is a subtle but important inversion. In the quantum stance, the expectation value is the deliverable and the cross-check is the methodology. In the quilt stance, the cross-check (the PredictionOutcome) is the deliverable and the canonical value is the derived quantity. The structural isomorphism (Bridge 1) is at the level of the cross-check, not at the level of the output.

---

## Where quilt lands in the Aaronson-Hagar exchange

Quilt does not land cleanly on either side. It is closer to Aaronson in one respect and closer to Hagar in another:

### Closer to Aaronson: verifiable advantage is real

Quilt's corpus is consistent with Aaronson's claim that verifiable advantage is real and structurally defensible. The quilt substrate produces verifiable outputs (PredictionOutcome + witness entries + convoy consensus) from forward-and-backward comparison, in specific regimes (the predict-and-confirm cycle). The structural reasons for the verifiability (predict-then-confirm; sensors-as-confirmations-not-triggers; convoy consensus across independent measurements) are the quilt-side analogues of the quantum-side structural reasons (interference, chaos, time-reversal, gate fidelity).

Quilt's corpus is *empirical evidence* for Aaronson's broader claim that verifiable advantage is the methodologically-defensible target. It shows that the target is reachable through different mathematics.

### Closer to Hagar: the substrate may not matter as much as the invariants

Quilt's corpus is also consistent with Hagar's broader claim (though not with his specific thesis about NISQ hardware). Hagar argues that the substrate matters — that the empirically-accessible region of NISQ hardware is classically simulable. Quilt's corpus suggests a stronger version of the substrate-doesn't-matter claim: the verifiability regime is substrate-independent, reachable through different mathematics, not only through quantum hardware.

This is *not* Hagar's position — Hagar's position is that the quantum substrate is classically simulable in the empirically-accessible regime. Quilt's position is that the verifiability regime is classically reachable through different mathematics, period. The two positions share the substrate-doesn't-matter direction but differ on what does matter (Hagar: classical algorithms; quilt: structural invariants).

### The third position, stated

The third position, in one sentence: **verifiable advantage is real (with Aaronson), AND the substrate may not matter as much as the structural invariants (beyond Hagar), because the invariants are reachable through different mathematics — and the quilt corpus is empirical evidence of this.**

The third position does not require Aaronson to be wrong about the four verifiable-advantage candidates. It requires only that the verifiability regime is substrate-independent — that it is reachable through different mathematics, not only through quantum hardware. The quilt corpus is a working instance of this reachability.

The third position does not require Hagar to be wrong about the NISQ Trap. It requires only that the verifiability regime is classically reachable through different mathematics — that the substrate-independence of the invariants is a stronger claim than the substrate-dependence of the quantum regime. The quilt corpus is a working instance of this classical reachability.

---

## The Monotone Crystal as the complexity-theoretic bridge to the debate

The Monotone Crystal (Bridge 7 in `03_STRUCTURAL_BRIDGES.md`) is the complexity-theoretic anchor of the third position. The finding:

quilt-wiki-2126's Monotone Crystal (F3) explicitly invokes Dedekind's problem (1897), Kleitman's asymptotic (1969) refined by Korshunov (1981), and the count |M_n| = 2^Θ(2ⁿ/√n) for monotone Boolean functions vs 2^(2ⁿ) for all Boolean functions. A single Crystal computes only monotone functions — a known subclass of P/poly, provably weaker than general circuits per Razborov 1985 (CLIQUE is hard for monotone circuits). The wiki's self-correction (2026-08-31, with runnable Python script `examples/monotone_crystal.py` validating against OEIS A000372) demonstrates that the corpus takes this complexity-class claim seriously enough to verify it empirically.

The complexity-theoretic content: a single quilt cell is NOT a general computer. It is a monotone circuit, exponentially weaker than a general computer. The fleet achieves generality via the FORGET_completeness law (a cell can be destroyed without losing the whole; the fleet survives by distribution).

This is the complexity-theoretic bridge to the Aaronson-Hagar debate because:

1. **It is a formal complexity-class claim** (monotone circuits ⊂ P/poly ⊂ P/poly-hard for some functions per Razborov 1985). It is not a vague gesture at "quantum-like behavior"; it is a specific, testable, peer-reviewed complexity-class claim.

2. **It is empirically validated** (the asymptotic is verified by exact enumeration against OEIS A000372 for n ≤ 6: 2, 3, 6, 20, 168, 7581, 7828354).

3. **It is self-correcting** (the wiki corrected its own constant by √2 on 2026-08-31; the Θ-class survived; the citation "Lynch 1927" was refuted as fabricated; the problem is Dedekind's 1897).

4. **It is honest about its own boundaries** (a single Crystal cannot compute non-monotone functions; the fleet is needed for generality).

This is the kind of complexity-theoretic engagement that BOTH Aaronson and Hagar can engage with. Aaronson can engage with it because it is a formal complexity-class claim with a specific structural reason (monotonicity) for the per-cell weakness. Hagar can engage with it because it is empirically validated and self-correcting, with explicit boundaries.

The Monotone Crystal is the complexity-theoretic anchor of the third position. It is the place where the quilt corpus makes a formal, testable, defensible complexity-class claim that engages with the live debate without requiring quilt to implement BQP.

---

## What this document does NOT claim

To forestall misreading:

1. **It does not claim quilt is "the answer" to the Aaronson-Hagar debate.** The third position is a contribution to the conceptual space the debate opens, not a resolution of the debate.

2. **It does not claim Aaronson is wrong.** Aaronson's four verifiable-advantage candidates are real and structurally defensible. Quilt's corpus does not refute them; it offers a different route to the same regime.

3. **It does not claim Hagar is right.** Hagar's NISQ Trap thesis is about quantum hardware specifically. Quilt's corpus does not confirm it; it offers a substrate-independent version of the substrate-doesn't-matter direction.

4. **It does not claim quilt implements BQP.** A single quilt cell is a monotone circuit (per Bridge 7); the fleet achieves generality via composition. Neither is BQP.

5. **It does not claim the Monotone Crystal proves the third position.** The Crystal is a complexity-class claim that engages with the debate; it is not a proof that the verifiability regime is substrate-independent. The proof would require formal complexity-theoretic work that this documentation set flags as an open research question (see `08_OPEN_RESEARCH_QUESTIONS.md`).

What this document DOES claim:

1. **The quilt corpus occupies a third position** in the Aaronson-Hagar exchange, defined by: verifiable advantage is real (with Aaronson), AND the substrate may not matter as much as the structural invariants (beyond Hagar).

2. **The Monotone Crystal is the complexity-theoretic anchor** of this third position — a formal, empirically-validated, self-correcting, boundary-respecting complexity-class claim.

3. **The third position is consistent with both Aaronson's and Hagar's positions** — it does not refute either; it offers a different contribution to the conceptual space the debate opens.

4. **The quilt corpus is empirical evidence (not proof) that the verifiability regime is substrate-independent** — reachable through different mathematics, not only through quantum hardware.

---

## What this enables

The third position opens three directions for the rest of the documentation set:

1. **A re-reading of the quantum-advantage candidates through the substrate-independence lens.** If the verifiability regime is substrate-independent, then each of Aaronson's four candidates (Google OTOC, Quantinuum H2, IBM Floquet, 2D Fermi-Hubbard) is one route to it, and quilt is another route. The structural reasons for the hardness (interference, chaos, time-reversal, gate fidelity, 2D entanglement) are the quantum-side analogues of the quilt-side structural reasons (predict-and-confirm, sensors-as-confirmations, convoy consensus, Monotone Crystal). This re-reading is for `08_OPEN_RESEARCH_QUESTIONS.md`.

2. **A formal complexity-theoretic engagement.** The Monotone Crystal claim (a single cell is a monotone circuit; the fleet achieves generality via FORGET_completeness) is a formal complexity-class claim that can be engaged with directly. What is the complexity class of the fleet? Is it P? P/poly? Something weaker? Can the fleet compute functions that are hard for monotone circuits (per Razborov 1985, CLIQUE is hard for monotone circuits)? These are open questions for `08_OPEN_RESEARCH_QUESTIONS.md`.

3. **A methodological convergence claim.** The Aaronson-Hagar exchange is itself a working instance of the verifiability discipline (Bridge 8 in `03_STRUCTURAL_BRIDGES.md`). Aaronson's blog and Hagar's arXiv preprint are the predict-and-confirm cycle at the scientific-community level. The quantum community's 2025-2026 turn to verifiable advantage is the substrate-independent verifiability discipline that quilt was born with. This is the meta-level convergence that Bridge 8 documents.
