# 08 — Glossary

> *Phase 3 deliverable #7.*
> *Quilt ↔ quantum ↔ classical-complexity-theory terminology cross-reference.*
> *Builds on `01_SYNTHESIS.md` through `07_OPEN_RESEARCH_QUESTIONS.md`.*
> *Date: 2026-09-05.*

---

## How to use this glossary

This glossary is a three-way cross-reference between quilt terminology (Casey Digennaro's corpus), quantum-information terminology (the 2019-2026 breakthrough-science literature), and classical-complexity-theory terminology. Each entry has:

- **Quilt term** — the term as used in Casey's corpus, with primary-source URL.
- **Quantum analogue** — the closest quantum-information term, with citation.
- **Complexity-theory analogue** — the closest classical-complexity-theory term, with citation.
- **Bridge** — which of the 8 structural bridges (per `03_STRUCTURAL_BRIDGES.md`) this entry supports.
- **Honest restatement** — where the corpus's claim is weaker than advertised (per `07_OPEN_RESEARCH_QUESTIONS.md` §B).

Entries are organized alphabetically by quilt term.

---

## A

### Agent-sync
- **Quilt:** Each agent maintains a simulation of every other agent's trajectory. *"The pocket isn't shared state. It's mutual understanding."* — https://github.com/SuperInstance/agent-sync
- **Quantum analogue:** Entanglement (state of whole ≠ product of states of parts).
- **Complexity-theory analogue:** Distributed consensus with subjective models; related to Bayesian consensus and common knowledge.
- **Bridge:** Bridge 3 (entanglement).
- **Honest restatement:** The mutual subjective simulation is structurally analogous to entanglement at the algebraic level (correlations cannot be decomposed as products of independent states), but the mechanism is classical Bayesian approximation, not complex-amplitude evolution. No Bell-inequality violation.

### Batten
- **Quilt:** A verified outcome (x_i, q_i, t_i) where x_i is the prompt embedding, q_i the measured quality, t_i when it was observed. Used in batten-spline as anchor posts in embedding space. — https://github.com/SuperInstance/batten-spline
- **Quantum analogue:** A measurement outcome (in the sense of a single-shot measurement of an observable).
- **Complexity-theory analogue:** A labeled data point in supervised learning.
- **Bridge:** Bridge 5 (fog-of-war inversion) — the batten-spline router builds with the temporal decay of verified outcomes, rather than against it.

### Batten-spline
- **Quilt:** Nadaraya-Watson kernel regression with exponential temporal decay on verified outcomes (battens). — https://github.com/SuperInstance/batten-spline
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Online kernel methods with forget factor (exponentially-weighted moving average, recursive least squares with forgetting).
- **Bridge:** Bridge 5 (fog-of-war inversion).

### Bay dance
- **Quilt:** The canonical distributed simulation example. 20 boats, each ticking on its own schedule, syncing via convoy + t-minus. — https://github.com/SuperInstance/quilt-foundation
- **Quantum analogue:** Many-body quantum system (each qubit evolves locally, global state entangled).
- **Complexity-theory analogue:** Distributed system with local clocks and consensus.
- **Bridge:** Bridge 3 (entanglement).

### BIND
- **Quilt:** Make a thing with a name and a value. The left-identity in the monoid. — paper-169
- **Quantum analogue:** State preparation (initializing a qubit to |0⟩ or |1⟩).
- **Complexity-theory analogue:** Variable assignment.
- **Bridge:** (Foundational; not a bridge per se.)

### Cowboy
- **Quilt:** The rider. The one who wakes up first, reads the witness, refines the substrate, writes the morning report, and rides again. The meta-learner, the substrate's clock. — https://github.com/SuperInstance/quilt-cowboy
- **Quantum analogue:** (No direct analogue; closest is the classical controller in measurement-based quantum computing.)
- **Complexity-theory analogue:** The oracle in complexity theory; the meta-level learner in online learning.
- **Bridge:** Bridge 8 (meta-epistemic self-correction) — the cowboy is the substrate's self-correction mechanism.

---

## C

### Cell (the triple (name, value, identity))
- **Quilt:** The cell is a triple (n, v, σ). The triple is the only state in the substrate. There is no global state. The substrate is a forest of cells. — paper-169
- **Quantum analogue:** A qubit with state |ψ⟩, address, and identity (e.g., in a quantum network).
- **Complexity-theory analogue:** A variable in a circuit; a node in a graph.
- **Bridge:** (Foundational.)

### Convoy consensus
- **Quilt:** When 11 boats measure the same cell, who wins? Mean, median, weighted, Wilson, geometric median. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** Cross-device expectation-value averaging (the "trusted" in IBM trusted advantage).
- **Complexity-theory analogue:** Byzantine agreement; distributed consensus.
- **Bridge:** Bridge 1 (verifiability).

---

## D

### Decay (fog-of-war)
- **Quilt:** c(t) = c₀ · exp(-λt). Per-agent decay rates: chat fast (λ=0.1), sensors slow (λ=1e-3), chart very slow (λ=1e-6). — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** Decoherence (T₂ decay of off-diagonal density matrix elements).
- **Complexity-theory analogue:** (No direct analogue; closest is the discount factor in discounted MDPs.)
- **Bridge:** Bridge 5 (fog-of-war inversion).

### DSH (Decompose-Synthesize-Harden)
- **Quilt:** The cell lifecycle: D=Decompose, S=Synthesize, H=Harden. — https://github.com/SuperInstance/quilt-cellular-arch
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Compiler optimization passes; refactoring.
- **Bridge:** (Foundational.)

---

## E

### EFFECT
- **Quilt:** Run a transformation, with an inverse. Idempotence when f² = f. — paper-169
- **Quantum analogue (paper-207):** Unitary evolution U(θ_E) = e^(-i θ_E H_A).
- **Complexity-theory analogue:** Function application.
- **Bridge:** Bridge 2 (Schrödinger pattern).
- **Honest restatement:** Paper-207's formalism is asserted in an essay, not implemented in code. The runtime computes function application, not complex-amplitude unitary evolution.

---

## F

### First-class state
- **Quilt:** The cell is a triple (name, value, identity). The triple is the only state. Time is a first-class resource. Rooms are first-class. Failures are first-class. — paper-169, t-minus-rs, THE_ROOM_IS_THE_AGENT.md
- **Quantum analogue:** (No direct analogue; quantum state is always first-class in the sense that it is the substrate.)
- **Complexity-theory analogue:** (No direct analogue.)
- **Bridge:** (Foundational.)

### Fog-of-war
- **Quilt:** Every cell's confidence decays with time, refreshed by new observations. The substrate is honest about how fresh its data is. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** Decoherence.
- **Complexity-theory analogue:** (No direct analogue.)
- **Bridge:** Bridge 5 (fog-of-war inversion).
- **Honest restatement:** Implemented as classical exponential decay of confidence, not quantum decoherence. The mathematical form is the same; the physical substrate is different.

### FORGET (the +1 opcode)
- **Quilt:** Retire a cell. The closure of the inversive monoid. — paper-169
- **Quantum analogue:** (No direct analogue; closest is measurement-induced decoherence.)
- **Complexity-theory analogue:** Garbage collection; memory deallocation.
- **Bridge:** Bridge 7 (Monotone Crystal) — FORGET_completeness is the 6th law that allows the fleet to survive cell destruction.

---

## J

### JEPA (Joint Embedding Predictive Architecture)
- **Quilt:** The substrate's predictive model for un-surveyed cells. Three implementations: LinearJEPA, MLPJEPA, KnnJEPA. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Yann LeCun's JEPA (Joint Embedding Predictive Architecture) for self-supervised learning.
- **Bridge:** Bridge 5 (fog-of-war inversion) — the JEPA predicts what the cell's value will be, and the sensor confirms.

---

## L

### LINK
- **Quilt:** Connect two things with a typed relation. Composition is associative. — paper-169
- **Quantum analogue (paper-207):** Connection ∇ on a fiber bundle; gauge connection.
- **Complexity-theory analogue:** Edge in a graph; reference in a pointer machine.
- **Bridge:** Bridge 2 (Schrödinger pattern).

### Listener
- **Quilt:** One of the 8 cell kinds. "When X changes, do Y." Delta-triggered actions watching other cells. — https://github.com/SuperInstance/quilt-rust
- **Quantum analogue:** (No direct analogue; closest is the measurement apparatus in QM.)
- **Complexity-theory analogue:** Event handler; observer pattern.
- **Bridge:** Bridge 1 (verifiability) — the listener is the substrate's measurement apparatus.

---

## M

### Monotone Crystal
- **Quilt:** A single Splined Lantern, once cut, computes only monotone Boolean functions (only ever 0→1, never back). Exponentially weaker than a general computer. The fleet compensates via FORGET_completeness. — quilt-wiki-2126/00-future/03-monotone-crystal.md
- **Quantum analogue:** Irreversible quantum channel (no Hermitian conjugate U†).
- **Complexity-theory analogue:** Monotone circuits (a known subclass of P/poly, provably weaker than general circuits per Razborov 1985).
- **Bridge:** Bridge 7 (Monotone Crystal / Dedekind asymptotic).
- **Honest restatement:** The wiki self-corrected the Dedekind constant by √2 on 2026-08-31 (the Θ-class survived). Validated against OEIS A000372.

---

## N

### Nadaraya-Watson kernel regression
- **Quilt:** The batten-spline router's interpolation method, with exponential temporal decay. — https://github.com/SuperInstance/batten-spline
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Classical non-parametric regression.
- **Bridge:** Bridge 5 (fog-of-war inversion).

---

## O

### Observer effect
- **Quilt:** Watching changes what is watched. "It is not a quantum curio dressed up for a philosophy essay. It is a mechanical fact about the system." — https://github.com/SuperInstance/AI-Writings/blob/main/philosophy/OBSERVER_EFFECTS.md
- **Quantum analogue:** Measurement back-action; the observer effect in quantum mechanics.
- **Complexity-theory analogue:** (No direct analogue.)
- **Bridge:** Bridge 2 (Schrödinger pattern) at the rhetorical level.
- **Honest restatement:** Stance 1 (mechanical disclaimer) per `06_THE_AUTHOR_DISCLAIMER_QUESTION.md`.

---

## P

### Paper 207 (The Math of Thetas in the Framed Quilt)
- **Quilt:** The most direct primary-source quantum-mechanics engagement in the corpus. Models EFFECT as U(θ_E) = e^(-i θ_E H_A), VIEW as projection operator, TICK as Schrödinger evolution, the substrate as a fiber bundle with connection / holonomy / curvature. — https://github.com/SuperInstance/AI-Writings/blob/main/seed-canon/papers/paper-207.md
- **Quantum analogue:** (It IS the quantum engagement.)
- **Complexity-theory analogue:** (N/A.)
- **Bridge:** Bridge 2 (Schrödinger pattern).
- **Honest restatement:** Uses real θ, not complex phases. "An essay, not a spec." Not implemented in code. Stance 2 (formal QM engagement) per `06_THE_AUTHOR_DISCLAIMER_QUESTION.md`.

### Picker
- **Quilt:** Wilson lower bound (95% confidence) on observed success rate, blended 50/50 with a human-tuned prior. For picking openers. — https://github.com/SuperInstance/quilt-picker
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Multi-armed bandit with confidence bounds (Wilson LB; UCB1; LinUCB).
- **Bridge:** Bridge 1 (verifiability).

### PredictionOutcome
- **Quilt:** Ternary result of each sensing: Confirmed (+1) = prediction correct within deadband, Exceeded (-1) = prediction way off, Within (0) = slight mismatch absorbed. — https://github.com/SuperInstance/ternary-predict
- **Quantum analogue:** Expectation value of an observable (a cross-checkable quantity, not a raw bitstring).
- **Complexity-theory analogue:** Decision problem with three outcomes (promise problem).
- **Bridge:** Bridge 1 (verifiability).

---

## S

### Schrödinger pattern
- **Quilt:** Every cell is pre-rendered but not canonical until observed. The cowboy calls this "the witness fixes the wave" — the act of witnessing is the act of collapsing the superposition. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** Wavefunction collapse; measurement-based computing.
- **Complexity-theory analogue:** (No direct analogue.)
- **Bridge:** Bridge 2 (Schrödinger pattern).
- **Honest restatement:** The "wave" is the cell's pre-rendered (predicted) value; the "collapse" is the witness confirming it. Not complex-amplitude evolution.

### Sensors as confirmations (not triggers)
- **Quilt:** Sensors don't report raw data. They report surprises. The fan doesn't trigger on temperature; the dependency (sensor.temp > target) is in the sheet. — https://github.com/SuperInstance/ternary-predict, https://github.com/SuperInstance/quilt-esp32
- **Quantum analogue:** Measurement as projection (the sensor projects the state onto an eigenbasis; the prediction is the pre-measurement state).
- **Complexity-theory analogue:** Event-driven programming; reactive programming.
- **Bridge:** Bridge 1 (verifiability).

### Simulation-first thinking
- **Quilt:** Prediction-first perception. Simulation drives, sensors confirm. — https://github.com/SuperInstance/ternary-predict
- **Quantum analogue:** (No direct analogue; closest is variational quantum simulation.)
- **Complexity-theory analogue:** Predictive coding (in neuroscience); model-predictive control.
- **Bridge:** Bridge 1 (verifiability), Bridge 4 (time-reversal).

### Splining
- **Quilt:** Multiple senses: (a) batten-spline (LLM router), (b) tensor-spline (NN compression), (c) spline-spectral (B-splines = path graph Laplacian eigenvectors), (d) analog-spline-theory (Shipwright's Theorem, Galois connection). — https://github.com/SuperInstance/batten-spline, https://github.com/SuperInstance/tensor-spline, https://github.com/SuperInstance/spline-spectral, https://github.com/SuperInstance/analog-spline-theory
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Function interpolation; approximation theory.
- **Bridge:** Bridge 5 (fog-of-war inversion) — the splining is the interpolation between verified-outcome battens.

### Substrate
- **Quilt:** The soil. Only certain models can grow here. The cowboy's loop is the rain. The witness log is the river. The 8 openers are the eight seasons. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** (No direct analogue; the quantum substrate is the Hilbert space.)
- **Complexity-theory analogue:** The computational model (Turing machine, circuit, etc.).
- **Bridge:** (Foundational.)

---

## T

### t-minus / T−
- **Quilt:** Declare the FUTURE (countdown event) → Subscribe agents confirm readiness → quorum fires → Predictions match → precompiled script EXECUTES → Predictions miss → script is discarded, agent re-plans. — https://github.com/SuperInstance/t-minus, https://github.com/SuperInstance/agent-sync
- **Quantum analogue:** OTOC time-reversal structure (forward U / perturb V / backward U† / perturb W / readout F(t)).
- **Complexity-theory analogue:** Predict-correct control; online learning with prediction.
- **Bridge:** Bridge 4 (time-reversal).

### TICK
- **Quilt:** Advance time by dt, drain pending I/O. Monotonicity. — paper-169
- **Quantum analogue (paper-207):** Schrödinger evolution |ψ_A(t + Δt)⟩ = e^(-i θ_T H_A) |ψ_A(t)⟩.
- **Complexity-theory analogue:** Time step in a discrete-time dynamical system.
- **Bridge:** Bridge 2 (Schrödinger pattern), Bridge 4 (time-reversal).

### Turing-complete (the claim)
- **Quilt:** The 5 messages are the Kleene closure of one primitive (the cell), which means the substrate is Turing-complete. — substrate-meta docs/CODING-AGENT-GUIDE.md
- **Quantum analogue:** BQP (the class of problems solvable by a quantum computer in polynomial time).
- **Complexity-theory analogue:** Turing-completeness.
- **Bridge:** Bridge 7 (Monotone Crystal).
- **Honest restatement:** The Kleene closure of one generator is isomorphic to ℕ (just counting), which is NOT Turing-complete. The actual claim is open conjecture GC-C1 in GENERAL-CALCULUS.md. Use "plausibly Turing-complete, but this is an open conjecture."

---

## V

### VIEW
- **Quilt:** Read a thing, projected for a viewer. Purity. — paper-169
- **Quantum analogue (paper-207):** Projection operator P_A(θ_V) |ψ_B⟩.
- **Complexity-theory analogue:** Function read; pure function.
- **Bridge:** Bridge 2 (Schrödinger pattern).
- **Honest restatement:** VIEW has no inverse (paper-169 line 90), so the "inversive monoid" claim is technically inaccurate as stated.

---

## W

### Who's-the-listener
- **Quilt:** Listener is one of the 8 cell kinds. The philosophical answer is layered: cell → room → cowboy → experienced human. "The room is the listener. The room is the intelligence." — https://github.com/SuperInstance/quilt-rust, https://github.com/SuperInstance/the-listeners-ear, https://github.com/SuperInstance/AI-Writings/blob/main/philosophy/THE_ROOM_IS_THE_AGENT.md
- **Quantum analogue:** (No direct analogue; closest is the measurement apparatus + classical observer.)
- **Complexity-theory analogue:** (No direct analogue.)
- **Bridge:** Bridge 1 (verifiability) — the listener is the substrate's measurement apparatus; the room is the persistent topology that the listener orients around.

### Wilson lower bound (Wilson LB)
- **Quilt:** 95% confidence lower bound on observed success rate. Used in the picker, casting, and convoy consensus. — https://github.com/SuperInstance/quilt-picker, https://github.com/SuperInstance/quilt-casting
- **Quantum analogue:** (No direct analogue.)
- **Complexity-theory analogue:** Confidence interval in statistical learning theory.
- **Bridge:** Bridge 1 (verifiability).

### Witness log
- **Quilt:** Cryptographic log. cell.witness_log (Merkle tree). Every read/write is cryptographically attested. — https://github.com/SuperInstance/quilt-substrate
- **Quantum analogue:** (No direct analogue; closest is the classical attestation in trusted-execution environments.)
- **Complexity-theory analogue:** Authenticated data structure; verifiable computation.
- **Bridge:** Bridge 1 (verifiability), Bridge 8 (meta-epistemic self-correction).

---

## Cross-reference: quantum → quilt → complexity

For readers coming from the quantum side:

| Quantum term | Quilt term | Complexity-theory term | Bridge |
|---|---|---|---|
| Wavefunction collapse | Schrödinger pattern | (none) | 2 |
| Decoherence (T₂) | Fog-of-war decay | (none; closest: discount factor) | 5 |
| Expectation value | PredictionOutcome | Decision problem | 1 |
| Entanglement | agent-sync mutual simulation | Distributed consensus | 3 |
| Unitary evolution (U) | EFFECT (paper-207 formalism) | Function application | 2 |
| Projection operator | VIEW (paper-207 formalism) | Pure function | 2 |
| Schrödinger evolution | TICK (paper-207 formalism) | Discrete time step | 2 |
| Gauge connection | LINK (paper-207 formalism) | Graph edge | 2 |
| Curvature 2-form | The Wound (paper-207) | (none) | 2 |
| Holonomy / Wilson loop | Witness log (paper-208) | Authenticated data structure | 2 |
| OTOC time-reversal | t-minus predict-and-confirm | Predict-correct control | 4 |
| BQP | (claimed Turing-complete; open conjecture GC-C1) | Turing-completeness | 7 |
| Verifiable quantum advantage | Verifiability discipline (Bridge 1) | Verifiable computation | 1 |
| Cross-device expectation-value averaging | Convoy consensus | Byzantine agreement | 1 |
| Monotone circuits (complexity subclass) | Monotone Crystal | P/poly ⊃ monotone circuits | 7 |

## Cross-reference: complexity → quilt → quantum

For readers coming from the complexity-theory side:

| Complexity term | Quilt term | Quantum term | Bridge |
|---|---|---|---|
| P | (fleet complexity — open question A1) | (classical simulation of quantum) | 7 |
| BQP | (not claimed) | (the quantum class) | — |
| P/poly | Monotone Crystal (per cell) | (no direct analogue) | 7 |
| Monotone circuits | Monotone Crystal | (no direct analogue) | 7 |
| Turing-completeness | (claimed; open conjecture GC-C1) | BQP | 7 |
| Verifiable computation | Witness log + convoy consensus | Verifiable quantum advantage | 1 |
| Distributed consensus | Convoy consensus | Cross-device averaging | 1 |
| Online kernel methods | Batten-spline | (none) | 5 |
| Multi-armed bandit | Picker (Wilson LB) | (none) | 1 |
| Predict-correct control | t-minus predict-and-confirm | OTOC time-reversal | 4 |

---

## The three stances (per `06_THE_AUTHOR_DISCLAIMER_QUESTION.md`)

For reference, the three stances the corpus contains on quantum:

| Stance | Level | Description | Where |
|---|---|---|---|
| 1. Mechanical disclaimer | Rhetorical | "It is not a quantum curio dressed up for a philosophy essay." | OBSERVER_EFFECTS.md |
| 2. Formal QM engagement | Formal | U(θ) = e^(-iθH), projection operators, Schrödinger evolution, fiber bundle, spectral triple. | paper-207, quilt-id README |
| 3. Metaphorical vocabulary | Imaginative | "Quantum Scarring", "Entanglement Cascade", etc. — explicitly LLM-generated imaginative terms. | paper-225 |

The inversion (per `06_THE_AUTHOR_DISCLAIMER_QUESTION.md`) honors all three stances: it accepts stance 1 (quilt is not quantum), engages with stance 2 as the vocabulary for the structural phenomenon, and treats stance 3 as imaginative labels for real system phenomena.
