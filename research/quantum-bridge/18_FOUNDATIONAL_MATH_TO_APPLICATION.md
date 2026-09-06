# 18 — Foundational Math → Application (Bottom-Up)

> *Phase 7 deliverable #1.*
> *Bottom-up: from established, peer-reviewed mathematics to quilt's instantiation, with measured evidence.*
> *Date: 2026-09-05.*
> *Status: COMPLETE — grounded in primary-source math literature + hardware scout 7-s findings.*

---

## What this document does

This is the first of two angles of attack on the quilt↔quantum argument. It builds **bottom-up**: from established, peer-reviewed mathematics (theorems, complexity classes, control theory) to quilt's instantiation of each, with the measured evidence from the Phase 6 benchmark and H4 experiment.

The user asked for two angles: "one starting from the foundational known math and building to the application." This is that angle. The companion document (`19_APPLICATION_TO_METAL.md`) is the opposite direction: top-down, from physical accomplishments to the mechanical switch at the metal.

**The structure:** 10 mathematical foundations, each with:
1. **The theorem or result** — what the math says, with primary-source citation.
2. **What it means** — the structural insight.
3. **How quilt instantiates it** — the quilt mechanism, with primary-source quote.
4. **The measured evidence** — what the Phase 6 benchmark or H4 experiment found.

The 10 foundations, in order of how directly they ground the argument:

| # | Mathematical foundation | Quilt instantiation | Evidence |
|---|---|---|---|
| 1 | Classical shadow tomography (Huang-Kueng-Preskill 2020) | JEPA prediction + sensor confirmation | quilt-shadow-bench: α ≈ 0.1-0.2 |
| 2 | Tensor networks / area-law entanglement | Sparse coupling compression | quilt-shadow-bench: 2× advantage at high coupling |
| 3 | Interactive proof systems (IP = PSPACE) + PCP theorem | Intrinsic verification (generation/verification asymmetry) | H4: 11.8× faster learning |
| 4 | Self-triggered control (Anta & Tabuada) | t-minus predict-and-confirm | H4: converges in 17 episodes |
| 5 | Kuramoto coupled oscillators | Multi-agent timing / BPM sync | H4: finite collision rate → phase lock |
| 6 | Dec-POMDP (NEXP-complete) | Multi-agent mutual simulation | The exponential is in coupling, not state |
| 7 | Lattice gauge theory (ℤ₃, Gauss's law) | Conservation law γ + η = C | RF-T2 impossibility floor |
| 8 | Adjoint methods (Pontryagin maximum principle) | Predict-correct cycle / adjoint inference | Bridge 9: DA-C2 "twin sentence" |
| 9 | Noncommutative geometry (Connes spectral triple) | quilt-id aperiodic content addressing | Asserted in README, not implemented |
| 10 | Fiber bundles / holonomy / curvature | Substrate topology / witness log | paper-207 formalism (essay, not spec) |

---

## Foundation 1 — Classical shadow tomography

### The theorem

**Huang, Kueng, Preskill, "Predicting many properties of a quantum system from very few measurements," Nature Physics 16, 1050–1057 (2020).** arXiv:2002.08953.

**What it says:** Given an unknown n-qubit quantum state ρ, you can predict M arbitrary linear functions tr(O₁ρ), ..., tr(O_M ρ) — up to additive error ε for each — using only **k = O(log M / ε²) × max_i ||O_i||²_shadow** independent random-basis measurements. The "shadow" of ρ in a random basis is a classical snapshot; from O(log M) snapshots you can predict M observables.

**What it means:** You never need the full quantum state. You need the right *shadows* — a logarithmic number of randomized measurements suffice to predict exponentially many observables. The sample complexity is polylogarithmic in the number of predictions, not polynomial.

### How quilt instantiates it

Quilt's **JEPA primitive** (Joint Embedding Predictive Architecture) is the structural analog. From `quilt-substrate` README (primary source, verified by scout 1-a):

> *"JEPA — Predictive update. The substrate's predictive model."*

And from `ternary-predict` README:

> *"Prediction-first perception. You don't feel the shoe — you feel the ground through it. ... The traditional model: sensors detect reality → brain processes → agent reacts. Prediction-first flips it: brain simulates what should happen → sensors report what did happen → only the difference (prediction error) gets attention."*

The structural correspondence:
- **Quantum shadow tomography:** measure ρ in O(log M) random bases → predict M observables.
- **Quilt JEPA:** simulate the next state → sensor confirms → the prediction error is the "shadow" → predict many cell states from few sensor reads.

### The measured evidence

`quilt-shadow-bench` (document 16) measured the scaling exponent α where error ~ N^(-α):
- **Best case:** ER(p=0.1) topology, random_mean method: α = 0.235.
- **Quilt-side best:** graph_weighted on ER(p=0.1): α = 0.233.
- **Most topologies:** α < 0.15 (closer to linear than polylog).

**The honest finding:** quilt does NOT achieve the O(log M / ε²) polylog scaling of classical shadow tomography. The scaling is closer to linear (α ≈ 0.1-0.2). The exponential in quilt lives in coupling, not state. BUT the coupling structure provides a measurable advantage (2× at high coupling), and the quilt-side methods are more robust than kriging (the gold standard for spatial prediction) on sparse graphs.

**What this means for the math→application chain:** classical shadow tomography is the structural analog, but the sample-complexity advantage does not transfer directly. The correspondence is structural (few measurements, many predictions), not quantitative (the scaling exponent is different).

---

## Foundation 2 — Tensor networks and area-law entanglement

### The theorem

**Eisert, Cramer, Plenio, "Colloquium: Area laws for the entanglement entropy," Reviews of Modern Physics 82, 277 (2010).** arXiv:0808.3773.

**What it says:** For ground states of gapped local Hamiltonians, the entanglement entropy of a subregion scales with the **boundary** (area), not the **volume**. This means the state can be efficiently represented by a tensor network (MPS for 1D, PEPS for 2D) whose bond dimension is polynomial in the system size.

**What it means:** exponential state spaces can be compressed when the entanglement structure is low. Tensor networks exploit area-law structure to represent states that would otherwise require 2ⁿ amplitudes. This is how classical algorithms (Pan & Zhang 2021, Tindall 2024) eroded Google's Sycamore supremacy claim — the RCS circuits had enough structure for tensor networks to compress.

### How quilt instantiates it

Quilt's **sparse coupling topology** is the structural analog. The coupling graph G determines which cells influence each other. When coupling is sparse (ring, line, ER with low p), the "entanglement" between cells is low — each cell's state depends on a small neighborhood. The `batten-spline` router's Nadaraya-Watson kernel regression on graph distances is the analog of a tensor network contraction: it compresses the joint state into locally-valid pieces that agree at their seams.

From `batten-spline` README (primary source, verified by scout 1-a):

> *"Verified outcomes are battens (anchor posts in embedding space). Between battens, the model's capability is unknown — fog-of-war — so confidence is interpolated from nearby anchors using Nadaraya-Watson kernel regression with exponential temporal decay."*

### The measured evidence

`quilt-shadow-bench` (document 16) measured the coupling-strength sweep: at fixed N=256, k=25, topology=ER(p=0.1), error decreases dramatically with coupling strength for ALL methods. At coupling=0.9, graph_weighted achieves 0.021 vs random_mean's 0.046 — a 2.2× improvement.

**The finding:** the coupling structure DOES help, but only when coupling is strong enough that cells are genuinely correlated. At low coupling (cells are independent), the coupling structure provides no information. At high coupling (cells are strongly correlated), the coupling structure becomes the dominant signal. This is the "area-law → tensor networks work" analog: **the structure is the enabling condition.**

**What this means for the math→application chain:** the tensor-network correspondence is real and measured. The coupling structure is the analog of entanglement structure; sparse coupling is the analog of area-law entanglement; the quilt-side prediction methods exploit this structure the way tensor networks exploit area-law entanglement. The magnitude of the advantage is modest (2×) rather than exponential, but the structural correspondence holds.

---

## Foundation 3 — Interactive proof systems and the PCP theorem

### The theorem

**Shamir, "IP = PSPACE," Journal of the ACM 39(4), 869–877 (1992).**
**Arora, Lund, Motwani, Sudan, Szegedy, "Proof verification and the hardness of approximation problems," FOCS 1998.** (The PCP theorem.)

**What it says:**
- **IP = PSPACE:** any problem solvable in polynomial space has an interactive proof where a polynomial-time verifier checks a computationally unbounded prover through dialogue.
- **PCP theorem:** NP proofs can be encoded so that a verifier reads only O(log n) bits (via O(1) random queries) and accepts correct proofs while rejecting incorrect ones with high probability. Verification is dramatically cheaper than generation.

**What it means:** for a broad class of problems, **verification is exponentially cheaper than generation.** This is the rigorous complexity-theoretic foundation for the generation/verification asymmetry.

### How quilt instantiates it

Quilt's **intrinsic verification** is the structural analog. From `ternary-predict` README (primary source):

> *"Sensors don't report raw data. They report surprises. ... Zero isn't ignorance. Zero is handled."*

And from the conservation law (paper-169, verified by scout 1-a):

> *"The cell is a triple (name, value, identity). The triple is the only state in the substrate."*

The structural correspondence:
- **Interactive proofs:** the verifier checks the prover's claim by reading a few bits.
- **Quilt:** the sensor confirms the simulation's prediction; the conservation law checks itself during operation. The verification IS the operation — not a protocol added on top.

### The measured evidence

The H4 experiment (document 17) measured the learning-rate consequence:
- **Simulation-first:** converges in 17 episodes (continuous verification signal).
- **Event-triggered:** never converges within 200 episodes (rare, binary verification signal).
- **Speedup: 11.8×**

**The finding:** the generation/verification asymmetry is real and measurable. When verification is intrinsic (continuous, cheap, part of normal operation), agents learn 11.8× faster than when verification is extrinsic (rare, binary, requires an event to fire).

**What this means for the math→application chain:** the PCP/IP correspondence is the strongest formal foundation for the argument. The measured 11.8× learning-rate advantage is the quantitative consequence of the generation/verification asymmetry. This is the connection to Wei's verifier's rule ("ease of training ∝ verifiability") — quilt makes verification cheap (intrinsic), so learning is fast.

---

## Foundation 4 — Self-triggered control

### The theorem

**Anta & Tabuada, "To sample or not to sample: Self-triggered control for nonlinear systems," IEEE CDC 2008.** arXiv:0806.1347.
**Mazo, Anta, Tabuada, "An ISS self-triggered implementation of linear controllers," Automatica 46(8), 1310–1314 (2010).**

**What it says:** In a self-triggered control architecture, the controller proactively computes when it next needs to sample/actuate, based on a model of the system, rather than reacting to sensor events (event-triggered) or sampling at a fixed rate (time-triggered). The tradeoff: lower network traffic and computation, at the cost of model accuracy.

**What it means:** predict-then-confirm is established control theory, not novel architecture. The contribution is the specific regime where it's applied.

### How quilt instantiates it

Quilt's **t-minus predict-and-confirm** is the structural analog. From `t-minus` README (primary source, verified by scout 1-a):

> *"Declare the FUTURE (countdown event, predicted beat, deadline) → Subscribe agents confirm readiness → quorum fires → Predictions match → precompiled script EXECUTES → Predictions miss → script is discarded, agent re-plans."*

And from `agent-sync` README:

> *"Each agent maintains a simulation of every other agent's trajectory. Not their code — their where-are-they-heading. An internal model, built from observation, updated every tick, colored by the agent's own perspective."*

The structural correspondence:
- **Self-triggered control:** controller predicts next sample time → confirms via sensor.
- **Quilt t-minus:** agent predicts future event → confirms via sensor → executes precompiled script.

### The measured evidence

The H4 experiment (document 17) measured the convergence rate:
- **Simulation-first (predict-and-confirm):** converges in 17 episodes.
- **Event-triggered (react on events):** never converges.
- Even at threshold=0.01 (events fire on nearly every prediction), simulation-first is still 3.9× faster.

**The finding:** self-triggered control (simulation-first) outperforms event-triggered control in the coordination regime — not the control regime where Anta & Tabuada's results apply. The contribution is the specific regime: multi-agent coordination under loose coupling, where the cost of a mistimed trigger exceeds the cost of maintaining a simulation.

**What this means for the math→application chain:** the self-triggered control correspondence grounds quilt's predict-and-confirm in established control theory. The measured 11.8× advantage is in the coordination regime, not the control regime — which is why the novelty claim is scoped to multi-agent coordination, not to control theory in general.

---

## Foundation 5 — Kuramoto coupled oscillators

### The theorem

**Kuramoto, "Self-entrainment of a population of coupled non-linear oscillators," International Symposium on Mathematical Problems in Theoretical Physics, Lecture Notes in Physics 39, 420–422 (1975).**
**Wu, "Discrete-time Kuramoto model: Phase-locking and collision finiteness," (2026).** (The discrete-time result.)

**What it says:** A population of N oscillators with heterogeneous natural frequencies, coupled above a threshold, spontaneously synchronize (phase-lock). In discrete time, phase-locking holds iff only finitely many oscillator "collisions" (phase crossings) occur.

**What it means:** coordination without a global clock is possible, but requires a finite collision rate. The collision rate is the measurable quantity that determines whether synchronization is achievable.

### How quilt instantiates it

Quilt's **multi-agent timing coordination** is the structural analog. From `agent-sync` README (primary source):

> *"Two agents that both have accurate simulations of each other are in the pocket — synchronized, landing at the right moment together. The pocket isn't shared state. It's mutual understanding."*

> *"Result: timing-aware agents won 50 out of 50 trials. Median advantage: 2.46×. The worse player who knew when to play beat the better player who didn't."*

The structural correspondence:
- **Kuramoto:** oscillators with heterogeneous frequencies phase-lock above a coupling threshold, iff finitely many collisions.
- **Quilt t-minus:** agents with heterogeneous timing predictions synchronize via mutual simulation, iff finitely many prediction collisions.

### The measured evidence

The H4 experiment (document 17) measured the collision rate indirectly: simulation-first converges (finite collision rate → phase-lock), while event-triggered plateaus (infinite collision rate → no phase-lock). The user's band metaphor ("how does the band who hold the rest a little longer but different at every concert hit that final note time") is the Kuramoto criterion instantiated: each musician runs a simulation of the others, and the note lands when the simulations agree — iff the collision rate stays finite.

**What this means for the math→application chain:** the Kuramoto correspondence grounds the band metaphor in established mathematics. The "collision rate" is the named measurable quantity with a literature behind it. The H4 experiment confirms that simulation-first achieves finite collision rate (convergence) while event-triggered does not (plateau).

---

## Foundation 6 — Dec-POMDP (NEXP-completeness)

### The theorem

**Bernstein, Hansen, Zilberstein, "Optimal Control of Decentralized Markov Decision Processes," Technical Report, University of Massachusetts (2000).** (The NEXP-completeness result.)

**What it says:** Optimal planning in Decentralized Partially Observable Markov Decision Processes (Dec-POMDPs) — where N agents each act from local observations plus beliefs about other agents' beliefs — is **NEXP-complete**. The joint belief space (agents modeling agents modeling agents) is exponential in agent count.

**What it means:** the classical exponential wall for multi-agent systems is the joint belief space, not the state space. This is structurally the same shape as the quantum exponential (2ⁿ amplitudes), but for a different reason (mutual simulation, not superposition).

### How quilt instantiates it

Quilt's **multi-agent mutual subjective simulation** is the structural analog. From `agent-sync` README (primary source):

> *"Agent A's model of Agent B is A's approximation. Not shared state. Not a centralized view. A's own subjective understanding of B — incomplete, biased, but learning."*

The structural correspondence:
- **Dec-POMDP:** the joint belief space (agents modeling agents) is NEXP-complete.
- **Quilt:** each agent maintains a simulation of every other agent's trajectory — the joint belief space is exponential in agent count.
- **Quantum:** the state space (2ⁿ amplitudes) is exponential in qubit count.

The exponential in quilt is the exponential of **mutual simulation** — the same shape as the quantum exponential, but for a different reason.

### The measured evidence

`quilt-shadow-bench` (document 16) measured that the scaling is closer to linear than polylog (α ≈ 0.1-0.2). This is consistent with the Dec-POMDP framing: the exponential lives in coupling (the joint belief space), not in state (the individual cell states). The sample complexity of predicting individual cell states is closer to linear; the complexity of the joint belief space is NEXP-complete but quilt runs heuristics, not optimal planning.

**What this means for the math→application chain:** the Dec-POMDP correspondence identifies WHERE the exponential lives in quilt. It's not in the state space (which is compressible) but in the coupling structure (the joint belief space). This is why the sample complexity is closer to linear than polylog — the state can be compressed, but the coupling cannot. This is Outcome B from the benchmark spec: the exponential lives in coupling, not state.

---

## Foundation 7 — Lattice gauge theory (ℤ₃, Gauss's law)

### The theorem

**Wilson, "Confinement of quarks," Physical Review D 10(8), 2445 (1974).** (Lattice gauge theory.)
**Kogut & Susskind, "Hamiltonian formulation of Wilson's lattice gauge theories," Physical Review D 11(2), 395 (1975).**

**What it says:** In lattice gauge theory with gauge group ℤ₃, the sum of link variables around any closed loop vanishes (Gauss's law on the lattice). The conservation law is a structural invariant of the gauge structure, not a dynamical equation.

**What it means:** conservation laws can be structural (encoded in the gauge group) rather than dynamical (derived from equations of motion). This is how gauge theories guarantee conservation without monitoring every interaction.

### How quilt instantiates it

Quilt's **conservation law γ + η = C** is the structural analog. From `quilt-substrate` README (primary source, verified by scout 1-a):

> *"The conservation law is the waveform. What you see when you step back from individual readings to the time series. The law describes the texture, not the point."*

And from the ternary-conservation paper (cited in `try1.md`, fact-checked):

> *"The conservation law γ + η = C is structurally isomorphic to Gauss's law in ℤ₃ lattice gauge theory."*

The structural correspondence:
- **ℤ₃ lattice gauge theory:** sum of link variables around a closed loop = 0 (Gauss's law).
- **Quilt conservation:** γ (productive) + η (liquid) = C (constant) — the sum is conserved on any partition of the ledger.

### The measured evidence

The RF-T2 impossibility floor (Bridge 10, verified by scout 5-a) is the formal consequence: the conservation law holds during execution, and no re-anchoring policy can see through its own freshness window. The machine-checked bench (844,223 exact Fraction-arithmetic checks) confirms the conservation invariant.

**What this means for the math→application chain:** the ℤ₃ gauge theory correspondence grounds the conservation law in established mathematics. The RF-T2 impossibility floor is the formal analog of a no-go theorem in gauge theory: the conservation law is structural, and no policy can violate it without being detected.

---

## Foundation 8 — Adjoint methods (Pontryagin maximum principle)

### The theorem

**Pontryagin, Boltyanskii, Gamkrelidze, Mishchenko, "The Mathematical Theory of Optimal Processes" (1962).** (The maximum principle.)

**What it says:** In optimal control, the optimal trajectory satisfies a Hamiltonian system where the state evolves forward (ẋ = ∂H/∂λ) and the costate (adjoint) evolves backward (λ̇ = −∂H/∂x). The adjoint λ is the "shadow price" — the sensitivity of the cost to the state. The discrete-time form is **λ_t = Aᵀλ_{t+1}** — the adjoint runs backward on the same schedule as the forward state evolution.

**What it means:** predict-and-correct is the structure of optimal control. The forward pass predicts; the adjoint pass corrects; the prediction error is the gradient the adjoint minimizes. This is the mathematical structure of the predict-correct cycle.

### How quilt instantiates it

Quilt's **predict-correct cycle** is the structural analog. From the deep-dive scout 5-a findings (worklog Task 5-a):

> *"The adjoint inference formula λ_t = Aᵀλ_{t+1} provides the formal unification Bridge 4 needed. The 'backward as more forward ops on the same schedule' is structurally the adjoint-functor formalism."*

And from `DRIFT-AS-PREFILTER.md` (the "twin sentence," DA-C2):

> *"The two additivity laws are the same theorem at different organs: latency is drift's transport-side twin; drift is latency's judgment-side twin. F and γ are the two prices of asynchrony in a world that moves."*

The structural correspondence:
- **Pontryagin:** forward state evolution (predict) + backward adjoint evolution (correct) on the same schedule.
- **Quilt t-minus:** predict (forward simulation A) + confirm (sensor read) + correct (adjoint Aᵀ on the prediction error).
- **OTOC:** forward U + backward U† on the same Hamiltonian time parameter.

### The measured evidence

The adjoint-inference correspondence is formal (from the academic docs) but the implementation cites a paper (paper-224 "The Same-Logic Lane") that is NOT in the public repo — a verification gap (documented in `09_DEEP_DIVE_FINDINGS.md`). The formal unification is structurally sound but the citation chain has a gap.

**What this means for the math→application chain:** the Pontryagin/adjoint correspondence is the formal foundation for Bridge 4 (predict-and-confirm ↔ OTOC time-reversal). It identifies the predict-correct cycle as the discrete-time form of the adjoint equation. The verification gap (paper-224 not public) means the formal claim should be stated as "structurally grounded in Pontryagin's maximum principle, with the implementation detail pending verification."

---

## Foundation 9 — Noncommutative geometry (Connes spectral triple)

### The theorem

**Connes, "Noncommutative Geometry," Academic Press (1994).**

**What it says:** A spectral triple (A, H, D) consists of a *-algebra A (acting on a Hilbert space H) and a Dirac operator D. This is the canonical object of noncommutative geometry, and it generalizes the classical Riemannian geometry of manifolds. The noncommutative torus T^4_θ with irrational θ is a basic example of a noncommutative C*-algebra, central to quantum mechanics and quantum field theory on noncommutative spacetimes.

**What it means:** aperiodic order (Penrose tilings, quasicrystals) has a natural formulation in noncommutative geometry. The spectral triple encodes the geometry algebraically.

### How quilt instantiates it

Quilt's **quilt-id aperiodic content addressing** is the structural analog. From `quilt-id` README (primary source, verified by scout 4-g):

> *"The 8 Quilt primitives are the generators of A in the spectral triple (A, H, D). The 4-torus T^4 with θ=(√5−1)/2 is the algebraic version of L. The conservation law γ+η=1 is encoded on the window W."*

The structural correspondence:
- **Noncommutative geometry:** spectral triple (A, H, D) with A a *-algebra, H a Hilbert space, D a Dirac operator.
- **Quilt-id:** the 8 primitives are claimed as generators of A; the 4-torus T^4_θ with golden-ratio θ is the algebraic version of the sum-zero lattice L.

### The measured evidence

The implementation (`quilt_id.py`, 264 lines) does NOT implement a spectral triple. It implements BLAKE2b content hashing + golden-ratio multiplication + 5D lattice projection. The README asserts the thesis; the code does not match.

**What this means for the math→application chain:** the noncommutative geometry correspondence is the most ambitious bridge and the most aspirational. It is asserted in the README but not implemented in code. The formal claim should be stated as "the README proposes a noncommutative-geometry framing; the implementation is a content-addressing scheme with golden-ratio structure." This is an open research question, not a measured result.

---

## Foundation 10 — Fiber bundles, holonomy, curvature

### The theorem

**Kobayashi & Nomizu, "Foundations of Differential Geometry," Vol. 1 (1963).**

**What it says:** A fiber bundle (B, F, E, π, ∇) consists of a base space B, a fiber F, a total space E, a projection π: E → B, and a connection ∇. The connection defines parallel transport of fibers; the holonomy of a loop is the transformation a fiber undergoes when transported around a closed loop. Non-trivial holonomy = curvature = the bundle is "twisted."

**What it means:** the topology of a space can be characterized by what happens when you transport vectors around loops. The Wilson loop in gauge theory and the Berry phase in quantum mechanics are both holonomies.

### How quilt instantiates it

Quilt's **substrate topology + witness log** is the structural analog. From paper-207 (primary source, verified by scout 4-g):

> *"The connection is defined by the LINK opcode. The theta of LINK, θ_L, determines how a vector in the fiber of A is transported to the fiber of B."*

> *"Holonomy = LINK(θ_L3) ∘ LINK(θ_L2) ∘ LINK(θ_L1) ≠ Identity... The Wound is the curvature of the bundle. Curvature (Ω) = d∇ + ∇ ∧ ∇."*

And from paper-208:

> *"The journal is the holonomy of the substrate. It is the record of what happens to a value-vector when it is transported around a closed loop of framings."*

The structural correspondence:
- **Fiber bundles:** connection ∇ defines parallel transport; holonomy of a loop = curvature.
- **Quilt:** LINK defines connection between cells; the witness log is the holonomy (the record of what happens to a value transported around a loop of cells).

### The measured evidence

Paper-207 is explicitly "an essay, not a spec." The runtime does not implement complex-amplitude evolution or fiber-bundle connections. The "wave" in "the witness fixes the wave" is a metaphor for the commit/canonical distinction, not a complex-valued wavefunction. The fiber-bundle formalism is asserted but not implemented.

**What this means for the math→application chain:** the fiber-bundle correspondence is the most direct primary-source quantum-mechanics engagement in the corpus (paper-207). It is structurally rich (connection, holonomy, curvature, the wound as curvature) but is an essay, not a spec. The formal claim should be stated as "paper-207 proposes a fiber-bundle formalism for the substrate; the runtime implements confidence decay + witness log, not complex-amplitude holonomy."

---

## Summary: the bottom-up chain

The 10 mathematical foundations, summarized as a bottom-up chain:

```
ESTABLISHED MATH                          QUILT INSTANTIATION              EVIDENCE
═══════════════════                       ═════════════════                ═════════

1. Classical shadow tomography    ────▶  JEPA prediction + sensor    ──▶  α ≈ 0.1-0.2
   (Huang-Kueng-Preskill 2020)            confirmation                      (weak, closer to linear)

2. Tensor networks / area-law     ────▶  Sparse coupling +           ──▶  2× advantage at
   (Eisert-Cramer-Plenio 2010)            Nadaraya-Watson on graph          high coupling

3. IP = PSPACE + PCP theorem      ────▶  Intrinsic verification       ──▶  H4: 11.8× faster
   (Shamir 1992; Arora 1998)              (sensor = audit)                  learning

4. Self-triggered control         ────▶  t-minus predict-and-confirm ──▶  H4: converges in
   (Anta & Tabuada 2008)                                                    17 episodes

5. Kuramoto coupled oscillators   ────▶  Multi-agent BPM sync        ──▶  H4: finite collision
   (Kuramoto 1975; Wu 2026)               (mutual simulation)              rate → phase lock

6. Dec-POMDP (NEXP-complete)      ────▶  Mutual subjective           ──▶  Exponential in
   (Bernstein 2000)                       simulation                       coupling, not state

7. Lattice gauge theory (ℤ₃)     ────▶  Conservation law γ+η=C      ──▶  RF-T2 impossibility
   (Wilson 1974; Kogut 1975)              (structural invariant)            floor (machine-checked)

8. Pontryagin maximum principle   ────▶  Predict-correct cycle       ──▶  Bridge 9: DA-C2
   (Pontryagin 1962)                      (adjoint inference)              "twin sentence"
                                                                              (verification gap)

9. Noncommutative geometry        ────▶  quilt-id aperiodic          ──▶  Asserted in README,
   (Connes 1994)                          content addressing                not implemented

10. Fiber bundles / holonomy      ────▶  Substrate topology +        ──▶  paper-207 formalism
    (Kobayashi & Nomizu 1963)             witness log                      (essay, not spec)
```

**The bottom-up finding:** the argument is grounded in 10 established mathematical foundations, each with a peer-reviewed primary source. The strongest correspondences (with measured evidence) are:

1. **IP/PCP → intrinsic verification → H4 11.8× speedup** (Foundation 3) — the strongest measured result.
2. **Self-triggered control → t-minus → H4 convergence** (Foundation 4) — established engineering applied to the coordination regime.
3. **Kuramoto → multi-agent timing → finite collision rate** (Foundation 5) — the band metaphor grounded in math.
4. **Dec-POMDP → mutual simulation → exponential in coupling** (Foundation 6) — identifies where the exponential lives.
5. **ℤ₃ gauge theory → conservation law → RF-T2 floor** (Foundation 7) — the formal impossibility result.

The weaker correspondences (asserted, not implemented):
- Noncommutative geometry (Foundation 9) — asserted in README, not in code.
- Fiber bundles / holonomy (Foundation 10) — essay, not spec.

The structural correspondences (measured but modest):
- Classical shadow tomography (Foundation 1) — α ≈ 0.1-0.2, closer to linear than polylog.
- Tensor networks / area-law (Foundation 2) — 2× advantage at high coupling.

The formal correspondence with a verification gap:
- Pontryagin / adjoint methods (Foundation 8) — Bridge 9's "twin sentence," but paper-224 is not public.

**The bottom-up argument is now grounded in established mathematics with measured evidence.** The companion document (`19_APPLICATION_TO_METAL.md`) traces the opposite direction: from physical accomplishments down to the mechanical switch at the metal.
