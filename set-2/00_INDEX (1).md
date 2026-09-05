# The Quilt ↔ Quantum Research Documentation — Index

> *An interconnected documentation set exploring whether (and how) Casey Digennaro's quilt system reaches the same epistemic regimes the quantum-information community has identified as the only methodologically defensible target for "quantum advantage."*
> *Started: 2026-09-05. Last updated: 2026-09-05 (Phase 5 — verification asymmetry reframing, red-team brief, keystone benchmark spec).*

---

## What this is

This is an iterative, interconnected set of research documents. It was built in response to a user question:

> *"I am trying to think of the right approach to explain on a very visual level why quilt can actually do what a lot of people are saying only a quantum computer can do."*

The user's chosen framing (locked in via clarifying questions after the Phase 2 synthesis):

- **Target quantum claim:** Google OTOC verifiable-advantage (Mi & Kechedzhi et al., Nature s41586-025-09526-6, Oct 2025).
- **Comparison kind:** STRUCTURAL — same epistemic invariants, different mathematics. Not "quilt produces quantum outputs."
- **Author-stance:** INVERT Casey's "not a quantum curio" disclaimer. Take it as the wedge. Quilt is *not* quantum; quilt reaches the same regimes through different mathematics; this is the more interesting and more defensible claim.
- **Phase 3 priority:** visual argument first.

## How to read this

If you are new to the project, read in this order:

1. **`01_SYNTHESIS.md`** — the Phase 2 synthesis. Summarizes both scout reports (1-a: the quilt corpus; 1-b: quantum breakthrough science 2019–2026), identifies five structural bridges, recommends the user's narrative is ready for deep research/ideation conditional on three clarifications, and proposes the Phase 3 structure.
2. **`02_THE_VISUAL_ARGUMENT.md`** — the Phase 3 first deliverable. The visual-level explanation centered on Bridge 1 (verifiability). Four SVG figures showing the structural isomorphism between Google OTOC and quilt's t-minus + ternary-predict cycle.
3. **`03_STRUCTURAL_BRIDGES.md`** — full treatment of all 8 bridges (the original 5 + 3 new bridges the deep-dive scout surfaced). Honest assessment of what strengthens vs breaks each bridge.
4. **`04_THE_FOG_OF_WAR_INVERSION.md`** — standalone essay on Bridge 5. The most original move in the documentation set: quilt builds *out of* decoherence rather than escaping it. Inverts the user's framing.
5. **`05_AARONSON_HAGAR_AND_QUILT.md`** — engagement with the live July 2026 Aaronson-vs-Hagar debate. Locates quilt in a *third position* neither side has articulated.
6. **`06_THE_AUTHOR_DISCLAIMER_QUESTION.md`** — full treatment of Casey's "not a quantum curio" disclaimer. Finds the corpus contains THREE distinct stances on quantum; the inversion honors all three.
7. **`07_OPEN_RESEARCH_QUESTIONS.md`** — formal complexity-theoretic questions, down-graded formal claims, prioritized scout targets for Phase 4.
8. **`08_GLOSSARY.md`** — quilt ↔ quantum ↔ classical-complexity-theory terminology cross-reference.

If you are a **physicist**, read `03_STRUCTURAL_BRIDGES.md` (especially Bridges 2 and 7), then `05_AARONSON_HAGAR_AND_QUILT.md`, then `07_OPEN_RESEARCH_QUESTIONS.md` §A (formal complexity-theoretic questions).

If you are a **philosopher**, read `01_SYNTHESIS.md` §3 (the structural bridges), then `06_THE_AUTHOR_DISCLAIMER_QUESTION.md` (the three stances and the inversion), then `04_THE_FOG_OF_WAR_INVERSION.md`.

If you are a **software engineer**, read `01_SYNTHESIS.md` §1 (the quilt side, compressed), then Figure 2 in `02_THE_VISUAL_ARGUMENT.md`, then `08_GLOSSARY.md` for terminology.

If you are a **complexity theorist**, read `07_OPEN_RESEARCH_QUESTIONS.md` §A (formal complexity-theoretic questions A1-A5), then `03_STRUCTURAL_BRIDGES.md` Bridge 7 (Monotone Crystal / Dedekind asymptotic), then `05_AARONSON_HAGAR_AND_QUILT.md` (the third position).

## Documents

### All written (Phase 4 — deep-dive findings, executive summary, Aaronson response)

- **`00_INDEX.md`** (this file) — the map.
- **`01_SYNTHESIS.md`** — Phase 2 synthesis. ~9KB. The argument-state document.
- **`02_THE_VISUAL_ARGUMENT.md`** — Phase 3 deliverable #1. The visual argument centered on Bridge 1 (verifiability). 4 SVG figures.
- **`03_STRUCTURAL_BRIDGES.md`** — Phase 3 deliverable #2. Full treatment of all 8 bridges with primary-source quotes and honest assessment of strengths/breaks.
- **`04_THE_FOG_OF_WAR_INVERSION.md`** — Phase 3 deliverable #3. Standalone essay on Bridge 5. The most original move in the documentation set.
- **`05_AARONSON_HAGAR_AND_QUILT.md`** — Phase 3 deliverable #4. Engagement with the live July 2026 Aaronson-vs-Hagar debate. Locates quilt in a third position.
- **`06_THE_AUTHOR_DISCLAIMER_QUESTION.md`** — Phase 3 deliverable #5. Full treatment of Casey's three stances on quantum; the inversion honors all three.
- **`07_OPEN_RESEARCH_QUESTIONS.md`** — Phase 3 deliverable #6. Formal complexity-theoretic questions, down-graded formal claims, prioritized scout targets.
- **`08_GLOSSARY.md`** — Phase 3 deliverable #7. Quilt ↔ quantum ↔ complexity-theory terminology cross-reference.
- **`09_DEEP_DIVE_FINDINGS.md`** — Phase 4 deliverable #1. Integrates deep-dive scout 5-a findings: 3 honest refinements + 2 NEW bridges (Bridge 9 adjoint-inference / dual-additivity; Bridge 10 impossibility-floor as no-signaling analog). The argument survives, strengthened at the formal level, with a primary-source verification gap flagged.
- **`10_EXECUTIVE_SUMMARY.md`** — Phase 4 deliverable #2. 1-page synthesis of the whole argument for new readers.
- **`11_RESPONSE_TO_AARONSON.md`** — Phase 4 deliverable #3. DRAFT response to Aaronson's July 18 2026 blog articulating the third position. Not yet sent; for user review. **NOTE: must be updated per `13_RED_TEAM_BRIEF.md` Refutation 6 to address the Gustiani et al. (PRL Oct 2025) quantum self-verification counterexample.**
- **`12_VERIFICATION_ASYMMETRY_REFRACTION.md`** — Phase 5 deliverable #1. Assessment of user-uploaded `try1.md` (5-iteration AI deep-dive). Identifies 8 ideas that are genuinely new (the gold) and 4 things try1.md gets wrong (fact-checked). Proposes the integration: the verification asymmetry reframes the 10 bridges.
- **`13_RED_TEAM_BRIEF.md`** — Phase 5 deliverable #2. The skeptic's brief against our own claims, written before any further bridge documents. The methodological correction the documentation set needs. Identifies 8 refutations; the red team wins on Refutation 2 (no measured scaling law) until `quilt-shadow-bench` runs.
- **`14_THE_VERIFICATION_ASYMMETRY.md`** — Phase 5 deliverable #3. The new organizing concept, fact-checked and developed. Cites Wei (jasonwei.net, July 15 2025, "verifier's rule") and Neutert (LinkedIn Pulse, June 2 2026, "The Verification Asymmetry"). Supersedes the 10-bridge table as the primary organizing principle.
- **`15_QUILT_SHADOW_BENCH.md`** — Phase 5 deliverable #4. The keystone benchmark spec. The single artifact that converts the entire narrative from poetry to data. N cells, tunable coupling topology, k sensor reads, predict M held-out states, plot error vs k/N/topology against shadow-tomography scaling. Both outcomes (polylog or linear) are publishable. STATUS: SPEC — implemented in documents 16-17.
- **`16_BENCHMARK_RESULTS.md`** — Phase 6 deliverable #1. MEASURED scaling curves from quilt-shadow-bench (3 versions, 500+ configurations). Finding: scaling exponent α ≈ 0.1-0.2 — closer to LINEAR than polylog. Outcome B from the spec: the exponential lives in coupling, not state. BUT coupling structure provides a measurable advantage (2× at high coupling), and quilt-side methods are more robust than kriging on sparse graphs.
- **`17_H4_RESULTS.md`** — Phase 6 deliverable #2. The H4 learning-rate experiment — the most consequential measured result. Simulation-first converges **11.8× faster** than event-triggered (episode 17 vs 200-never). Even at equal event frequency (threshold=0.01), simulation-first is still 3.9× faster. The advantage is about the MODE of feedback, not the FREQUENCY. This is evidence FOR Wei's verifier's rule in a distributed multi-agent system, and is the strongest measured result in the documentation set.
- **`18_FOUNDATIONAL_MATH_TO_APPLICATION.md`** — Phase 7 deliverable #1 (bottom-up angle). 10 peer-reviewed mathematical foundations (classical shadow tomography, tensor networks, IP/PCP, self-triggered control, Kuramoto, Dec-POMDP, lattice gauge theory, Pontryagin adjoint, noncommutative geometry, fiber bundles) → quilt instantiation → measured evidence. The argument grounded bottom-up in established mathematics.
- **`19_APPLICATION_TO_METAL.md`** — Phase 7 deliverable #2 (top-down angle). 5 use cases (THE EILEEN fishing boat, oil pressure monitor, reflex-arc critic gate, scrap-quilt game, quilt-verilog FPGA fabric) each traced through 7 layers: physical accomplishment → application → coordination → cell → substrate (5+1 opcodes) → hardware → metal (transistor). The chain from "a boat caught fish" to "a CMOS transistor switched at 240 MHz."

### Figures (all VLM-verified clean)

In `figures/`:

1. `fig1_otoc_anatomy.svg` / `.png` — Google OTOC protocol anatomy.
2. `fig2_tminus_anatomy.svg` / `.png` — quilt t-minus + ternary-predict cycle anatomy.
3. `fig3_isomorphism_overlay.svg` / `.png` — 5-row structural isomorphism table.
4. `fig4_verifiability_convergence.svg` / `.png` — 2019→2026 quantum timeline converging on quilt's day-one verifiability bar.
5. `fig5_paper207_mapping.svg` / `.png` — paper-207's mapping of quilt opcodes to quantum-mechanical operations (Bridge 2 centerpiece).
6. `fig6_three_stances_inversion.svg` / `.png` — Casey's three stances on quantum and how the inversion honors all three.
7. `fig7_three_positions.svg` / `.png` — the Aaronson / Hagar / Quilt three-positions triangle.
8. `fig8_math_to_quilt.svg` / `.png` — bottom-up: 10 foundational math → 10 quilt instantiations → measured evidence.
9. `fig9_application_to_metal.svg` / `.png` — top-down: 5 use cases × 7 layers from physical accomplishment to transistor.

## Source material

The four scout reports that ground all of this are in `/home/z/my-project/worklog.md`:

- **Task 1-a** — the quilt corpus scout. ~776 lines. Documents 101+ quilt-titled repos + adjacent; verbatim definitions of every coined term; architecture summary; philosophy summary in the author's own words; intellectual influences; open questions. Primary-source files mirrored under `/home/z/my-project/download/superinstance-scout/readmes/`.
- **Task 1-b** — the quantum breakthrough science scout. ~240 lines. Chronological table of ~30 quantum-advantage claims 2019–2026; layer-by-layer breakdown of the top 10 results; structural reasons for classical hardness; 5 cautionary tales where "impossible classically" was later matched; 5 cases where the quantum result still stands; quantum-for-discovery results; skeptic-vs-advocate positions and where consensus has moved.
- **Task 4-g** — the first deep-dive scout. ~360 lines. Deep-dives quilt-verilog (formal proofs), quilt-substrate-meta (prover + synthesizer), quilt-polyformalism-dsl, quilt-wiki-2126 (5+1+1 laws, 6 tiers / 14 levels / 6 lifecycle stages, Monotone Crystal), quilt-id (spectral triple thesis), quilt-llvm, quilt-cuda, quilt-mesh, and 24 priority papers from AI-Writings. Found 3 strengthened bridges, 3 breaks, and 3 NEW bridges. Primary-source files mirrored under `/home/z/my-project/download/scout-4g/`.
- **Task 5-a** — the second deep-dive scout. ~290 lines. Deep-dives quilt-foundation (the "10 round-stones + fire" original research), zeroclaw-dissertation THESIS-V3 (fiber theorems about rooms on S⁶ + adjoint inference), and quilt-verilog/docs/academic/{BRIDGES,CONJECTURES,RHO-F-FLOOR,DRIFT-AS-PREFILTER,FOLD-COVERED,ELEGANCE,DEPENDENCY-GRAPH}.md + annals-1905/. Found that the formal academic spine is the strongest formal content in the corpus (RF-T2 impossibility floor, machine-checked 844,223 exact-arithmetic checks), that the "10 rounds of research" are LLM brainstorming not formal derivation (BREAKS the origin story), and that the adjoint-inference formula provides the formal unification Bridge 4 needed (with a verification gap — the cited paper is not in the public repo). Surfaced 2 NEW bridges: Bridge 9 (adjoint-inference / dual-additivity) and Bridge 10 (impossibility-floor as no-signaling analog). Primary-source files mirrored under `/home/z/my-project/download/scout-5a/`.

## The 10 structural bridges (per `03_STRUCTURAL_BRIDGES.md` + `09_DEEP_DIVE_FINDINGS.md`)

| # | Bridge | Strength | Status after Phase 4 |
|---|---|---|---|
| 1 | Verifiability (expectation values / sensors-as-confirmations) | STRONG | Dramatically strengthened by RF-T2 impossibility floor (formal, machine-checked, 844,223 exact-arithmetic checks). |
| 2 | Schrödinger pattern ↔ wavefunction collapse | STRONG | paper-207's quantum formalism is real but essay-not-spec; runtime doesn't implement. |
| 3 | agent-sync mutual subjective simulation ↔ entanglement | PARTIAL | Same algebraic shape; breaks at physical level (no Bell violation). |
| 4 | t-minus predict-and-confirm ↔ OTOC time-reversal | STRONG (was PARTIAL) | Now has formal anchor: DA-C2 "twin sentence" + adjoint inference λ_t = Aᵀλ_{t+1}. Verification gap: anchor cites local paper not in public repo. |
| 5 | Fog-of-war decay ↔ decoherence | WEAK (inversion survives) | Full treatment in `04_THE_FOG_OF_WAR_INVERSION.md`. |
| 6 | **NEW**: Noncommutative geometry (spectral triple) | ASSERTED, NOT IMPLEMENTED | quilt-id README invokes Connes' spectral triple; implementation is BLAKE2b + golden-ratio. |
| 7 | **NEW**: Monotone Crystal / Dedekind asymptotic | STRONG (complexity-theoretic) | Now backed by FC-P2's Ω(c) lower bound on walk-state. |
| 8 | **NEW**: Meta-epistemic self-correction discipline | STRONG (meta-level) | Now formalized by DENY-BY-RUNNING.md evidence-grade method. |
| **9** | **NEW (Phase 4)**: Adjoint-inference / dual-additivity | **STRONG (formal)** | DA-C2's "twin sentence" + adjoint formula unify predict-correct with OTOC's forward U + backward U†. |
| **10** | **NEW (Phase 4)**: Impossibility-floor as no-signaling analog | **STRONG (formal)** | RF-T2 audit-freshness floor is structurally analogous to no-cloning/no-signaling in quantum information. |

## The bottom line

The documentation set's central claim, refined through Phase 6 (with MEASURED data):

**A quantum computer exploits the representation/measurement asymmetry: it generates states (2ⁿ amplitudes, free, physics holds them) that it can only verify with external infrastructure. A quilt fleet exploits the generation/verification asymmetry: it generates states (compressed simulations, expensive, maintained) whose verification is inherent in the operation — the sensor reading that confirms the simulation is simultaneously the audit. By verifier's rule (Wei, July 2025: ease of training ∝ verifiability), this intrinsic verification gives quilt agents a MEASURED 11.8× learning-rate advantage in coordination tasks. The sample complexity is closer to linear than polylog (the exponential lives in coupling, not state), but the learning-rate advantage is large, measured, and robust.**

## The critical update (Phase 6)

**The red team's Refutation 2 ("no scaling law has been measured") is now ADDRESSED.** Two measured results:

1. **`quilt-shadow-bench` (document 16):** scaling exponent α ≈ 0.1-0.2. Closer to linear than polylog. Outcome B: the exponential lives in coupling, not state. The coupling structure provides a modest (2×) advantage at high coupling.

2. **H4 learning-rate experiment (document 17):** simulation-first converges **11.8× faster** than event-triggered. This is the strongest measured result in the documentation set, and it is the one that connects to Wei's verifier's rule.

**The narrative has pivoted from sample complexity (weak) to learning rate (strong).** The architectural advantage is not "you need fewer sensor reads" but "your agents learn 11.8× faster from the same sensor reads, because verification is intrinsic."

## How to extend this documentation

This documentation is iterative. To add a new document:

1. Add it to the **Documents** list above with a one-line description.
2. Cross-reference it from at least one existing document (so the graph stays connected).
3. Append a worklog entry to `/home/z/my-project/worklog.md` with Task ID, agent name, work log, and stage summary.
4. If you used a Python/Node script to generate any artifacts (figures, tables, etc.), persist it to `/home/z/my-project/scripts/` per the script-persistence rule.

## Citation policy

Every primary-source claim is grounded in either:

- A quilt-corpus URL (raw.githubusercontent.com/SuperInstance/...) — verbatim quotes only.
- A quantum-literature citation (arXiv ID, DOI, or peer-reviewed journal reference).

Vendor blog posts are admissible as one voice but never as primary evidence. The Hagar "NISQ Trap" preprint (arXiv:2607.07530) and Aaronson's blog (scottaaronson.blog) are treated as primary sources for the live July 2026 debate because they are the actual sites of that debate.

## Phase 4 candidates

The documentation set has reached a natural stopping point for Phase 3. Phase 4 (if the user chooses to pursue it) should focus on:

1. **Formal complexity-theoretic engagement** (questions A1-A5 in `07_OPEN_RESEARCH_QUESTIONS.md`). These are the questions a quantum-information theorist or a complexity theorist would engage with directly.
2. **Deeper scouting** of the HIGH-priority targets (C1-C3 in `07_OPEN_RESEARCH_QUESTIONS.md`): quilt-foundation (the "10 round-stones + fire" original research), zeroclaw-dissertation THESIS-V3 (fiber theorems + adjoint inference), quilt-verilog/docs/academic/{BRIDGES,CONJECTURES,RHO-F-FLOOR}.md (the formal academic spine).
3. **Engagement with the quantum-information community.** The Aaronson-Hagar exchange (July 2026) is the live debate this documentation set engages with. The next step would be to write a response to either Aaronson's blog or Hagar's preprint that articulates the third position (per `05_AARONSON_HAGAR_AND_QUILT.md`).
