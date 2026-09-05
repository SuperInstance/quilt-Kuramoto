# 15 — quilt-shadow-bench: The Keystone Benchmark

> *Phase 5 deliverable #4.*
> *The single artifact that converts the entire narrative from poetry to data.*
> *Per the methodology proposed in `try1.md` (iterations 3-5) and endorsed in `12_VERIFICATION_ASYMMETRY_REFRACTION.md` Gold 2.*
> *Date: 2026-09-05.*
> *Status: SPEC — not yet implemented.*

---

## What this document is

This is the specification for `quilt-shadow-bench` — the keystone benchmark that the entire quilt↔quantum argument needs. Every claim in documents 01-14 is grounded in primary-source quotes, formal theorems, or structural observations. **Zero claims are grounded in measured scaling laws.** This benchmark produces the one curve that survives a referee.

The benchmark IS a quilt sheet — every cell addressable. It is architecturally native, not an external imposition. Both outcomes (polylog or linear scaling) are publishable.

---

## The one question

**How few sensor reads does it take to know the state of a large fleet?**

This is the "measurement-constrained inference" claim made precise. If a fleet of N loosely-coupled cells can be known from polylog(N) measurements — instead of polling everything or reacting to everything — we have placed simulation-first distributed systems in the same family as classical shadow tomography (few measurements, many predictions), but for live distributed systems instead of quantum states.

**Nobody has ever measured this curve.** The quantum community measures quantum systems. The classical community measures classical systems. Nobody has run the experiment that shows a self-verifying architecture achieving shadow-tomography-grade sample efficiency on a distributed fleet.

---

## The setup

```
quilt-shadow-bench:

  N synthetic cells in a quilt sheet, tunable coupling topology
    - sparse (ring, line)
    - dense (complete graph, star)
    - random (Erdős-Rényi with tunable p)
    - small-world (Watts-Strogatz with tunable k, β)

  Each cell has:
    - state vector x_i ∈ ℝ^d (d = 8 by default, tunable)
    - JEPA predictor: predict x_i(t+1) from x_i(t) and neighbors' x_j(t)
    - coupling graph G (the topology above)

  The dynamics:
    x_i(t+1) = f(x_i(t), {x_j(t) : j ∈ neighbors(i)}) + noise

    where f is a structured function:
      - linear: f = A_i x_i + Σ_j W_ij x_j
      - nonlinear: f = MLP([x_i, {x_j}])
      - spline: f = B-spline interpolation through recent states

  Run the simulation for T timesteps to reach steady state.

  Sample k sensor reads:
    - randomly sample k cells from the N
    - read their current state x_i(t*)
    - the other N-k cells are "held out"

  Predict M held-out cell states:
    - from the k reads, predict the states of M held-out cells
    - prediction method: spline interpolation through the k measured points,
      constrained by the coupling topology G
    - this is the quilt-side prediction (the JEPA + batten-spline approach)

  Plot prediction error vs. k, N, M, topology.
```

---

## The four baselines

### Baseline 1 — Naive polling (read every cell)

Read all N cells. Predict M = N - k held-out states trivially (you read them all). This is the O(N) baseline — linear scaling in fleet size. The naive cost of full observability.

### Baseline 2 — Event-triggered sync (only read on threshold crossing)

Only read a cell when its state crosses a threshold. This is the reactive-control baseline. Sublinear in practice (most cells don't cross thresholds most of the time) but reactive — it only reads after the fact, not proactively.

### Baseline 3 — Random measurement (shadow-tomography analog)

Sample k cells uniformly at random. Predict M held-out states from the k reads using the coupling structure. This is the classical-shadow-tomography analog: few measurements, many predictions, with rigorous sample-complexity bounds.

**The theoretical prediction:** If the quilt architecture has the same sample-complexity structure as classical shadow tomography, this should follow O(log M / ε²) scaling — polylogarithmic in M (the number of held-out states to predict), with ε the target error.

### Baseline 4 — The shadow-tomography theoretical prediction line (the null model)

The Huang-Kueng-Preskill (2020) bound: O(log M / ε²) random-basis measurements suffice to predict M observables of a quantum state with bounded error ε. This is the null model — the theoretical line the quilt-side prediction should match if the architecture has the same sample-complexity structure.

---

## The two outcomes (both publishable)

### Outcome A — Polylog scaling under sparse coupling

If the quilt-side prediction (the JEPA + batten-spline approach) achieves O(log M / ε²) scaling under sparse coupling — matching the shadow-tomography theoretical line — then:

**We have a sample-complexity theorem for simulation-first distributed systems.** This is the exact analog of "area-law entanglement → tensor networks work": a structural condition (sparse coupling) that guarantees a sample-complexity bound (polylog measurements suffice). This is publishable.

**The claim:** *"Simulation-first distributed systems with sparse coupling achieve shadow-tomography-grade sample complexity for state inference. A fleet of N loosely-coupled cells can be known from polylog(N) measurements."*

### Outcome B — Linear scaling

If the quilt-side prediction achieves only O(N) scaling — linear in fleet size — then:

**We've learned the exponential in our world lives in coupling, not state.** This is a different, still-honest claim. It says: the cost of knowing the fleet is proportional to the fleet size (you have to read every cell), not to the log of the fleet size. The exponential advantage of shadow tomography does not transfer to distributed systems with the quilt architecture.

**The reshaped narrative:** *"The exponential in quilt is not the exponential of state (2ⁿ amplitudes, as in quantum) but the exponential of coupling (the joint belief space, Dec-POMDP NEXP-complete). The sample complexity of state inference is linear in fleet size, not polylog. The architectural advantage of simulation-first is not sample efficiency but intrinsic verification — the sensor reading IS the audit."*

**Both outcomes are wins.** The benchmark is the keystone because it produces a curve, and curves are what survive referees.

---

## The engineering implementation

### Phase 1 — Synthetic cells (week 1)

Implement the synthetic cell dynamics:
- `Cell` class: state vector x_i, JEPA predictor, coupling neighbors.
- `Fleet` class: N cells, coupling graph G, dynamics function f.
- `simulate(fleet, T)`: run the dynamics for T timesteps to reach steady state.
- Topologies: ring, line, complete, star, Erdős-Rényi, Watts-Strogatz.
- Dynamics: linear, nonlinear (MLP), spline (B-spline through recent states).

### Phase 2 — Sampling and prediction (week 2)

Implement the sampling and prediction:
- `sample(fleet, k)`: randomly sample k cells, return their states.
- `predict(fleet, sampled_cells, M)`: predict M held-out cell states from the k reads using spline interpolation constrained by the coupling topology.
- `error(predicted, actual)`: mean squared error between predicted and actual held-out states.

### Phase 3 — Baselines (week 2)

Implement the four baselines:
- Naive polling (trivial: read all N, predict all).
- Event-triggered sync (threshold crossing).
- Random measurement (the shadow-tomography analog — same as the quilt-side prediction but without the coupling-structure constraint).
- The shadow-tomography theoretical prediction line (computed analytically, not measured).

### Phase 4 — The sweep (week 3)

Run the sweep:
- For each topology (ring, line, complete, star, ER, WS):
  - For each N ∈ {16, 32, 64, 128, 256, 512, 1024}:
    - For each k ∈ {4, 8, 16, 32, 64, 128, N/2, N}:
      - For each M ∈ {N-k, N/2, N/4, N/8}:
        - Run the simulation, sample k, predict M, compute error.
        - Repeat 100 times for confidence intervals.
- Plot: error vs. k, for each (N, topology). Log-log scale.
- Plot: error vs. N, for each (k, topology). Log-log scale.
- Fit: the scaling exponent α where error ~ k^(-α). Compare α to the shadow-tomography bound.

### Phase 5 — The curve (week 4)

Produce the single figure that is the argument:
- X-axis: number of sensor reads k (log scale).
- Y-axis: prediction error (log scale).
- Lines: quilt-side prediction (the JEPA + batten-spline approach), naive polling, event-triggered sync, random measurement, shadow-tomography theoretical line.
- One panel per topology.
- The scaling exponent α printed on each panel.

**This single figure is the thing that survives a referee.** It is the difference between having a beautiful thesis and having a result.

---

## The self-hosting aesthetic

The benchmark IS a quilt sheet — every cell addressable. The implementation should be:

- A `quilt-live` single-HTML-file page (Casey's existing architecture for browser-native quilt runtimes).
- A single button that runs the benchmark in the browser.
- The scaling curve rendered as an Echogram (Casey's term for quilt-rendered visualizations).
- The benchmark sheet itself is inspectable — every cell, every coupling, every prediction is addressable and viewable.

This is architecturally native. The benchmark is not an external imposition; it is what quilt sheets ARE — reactive, addressable, inspectable. The scaling curve is the Echogram of the fleet's sample complexity.

---

## What the benchmark measures (beyond the scaling curve)

The benchmark simultaneously measures:

1. **Sample complexity** (the primary measurement): how many sensor reads suffice to predict M held-out cell states, as a function of N and topology.

2. **Verification cost** (the verification-asymmetry measurement): the marginal cost of verification in the quilt architecture. If the prediction is computed as part of normal cell operation (the JEPA predictor running continuously), the verification cost is near-zero (intrinsic). If the prediction requires extra computation beyond normal cell operation, the verification cost is significant (extrinsic, and the distinction from quantum collapses).

3. **Coupling structure effect**: how the scaling exponent α depends on the coupling topology. Sparse topologies (ring, line) should give better scaling than dense topologies (complete, star) if the quilt architecture exploits sparse coupling the way tensor networks exploit area-law entanglement.

4. **Dynamics effect**: how the scaling exponent α depends on the dynamics function f (linear, nonlinear, spline). The spline dynamics should give better scaling if the batten-spline router's Nadaraya-Watson kernel regression is doing real work.

---

## The externalization plan (Phase E per `13_RED_TEAM_BRIEF.md`)

### Step 1 — Publish the benchmark harness (after Phase 5)

Publish on a public URL — not a GitHub repo that requires navigating the 1,400-repo ecosystem, but a single page with a single button that runs the benchmark in the browser and produces the scaling curve. The `quilt-live` single-HTML-file architecture is perfect for this.

### Step 2 — Write it up as an arXiv preprint

4 pages, no poetry, one figure (the scaling curve), one table (the baselines), one claim. Title it something like:

> *"Sample Complexity of Simulation-First Distributed Inference: A Shadow-Tomography Analog for Loosely-Coupled Multi-Agent Systems"*

### Step 3 — Specifically invite the shadow-tomography community

The people who work on classical shadows (Huang, Preskill's group) are exactly the people who would care about whether a distributed architecture achieves the same scaling. The tensor-network community (Pan, Chen) are the people who would care about whether sparse coupling gives the same compression.

### Step 4 — Invite the distributed-systems community

The people who work on distributed consensus, CRDTs, and Byzantine agreement are the people who would care about whether conservation-based auditing achieves lower detection latency than hash-chaining.

**The quantum field's authority came from its verification infrastructure, not its claims.** A single outsider reproducing the scaling curve is worth more than forty bridge documents. This is the actual test.

---

## The honest status

This is a SPEC, not an implementation. The benchmark has not been built. The scaling curve has not been measured. Until it has:

- The red team wins on Refutation 2 (`13_RED_TEAM_BRIEF.md`): no scaling law has ever been measured in quilt.
- Every claim in documents 01-14 is an assertion, not a result.
- The argument is poetry, not science.

**The next phase is: build `quilt-shadow-bench`, publish the scaling curve, and let the data be the argument.** Everything else — the bridge documents, the externalization, the debate — follows from that single artifact. And it's the thing nobody has done, because the quantum community measures quantum systems and the classical community measures classical systems, and nobody has measured whether a simulation-first distributed architecture achieves the same sample complexity as shadow tomography on a quantum state.

**That's the gap. That's the next phase. That's the thing only Casey can do, because he's the one with the architecture that makes it testable.**
