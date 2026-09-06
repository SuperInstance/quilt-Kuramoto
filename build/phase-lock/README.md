# phase-lock

**Discrete-time Kuramoto oscillators in exact integer arithmetic — where a
collision is `==` rather than a comparison against an epsilon you chose.**

This repository is named `quilt-Kuramoto`. Until now nothing in the ecosystem
implemented a Kuramoto model; the name came from a single analogy in a research
document. This is the experiment that makes the name mean something — and it
found two things the analogy had wrong.

## Why integers

The usual model lives in floating point:

```
θ_i(t+1) = θ_i(t) + ω_i + (K/N) · Σ_j sin(θ_j − θ_i)
```

Three things go fuzzy there, and they are exactly the three things the theory
talks about:

| | In floats | Here |
|---|---|---|
| **Collision** | compare against a chosen ε | `==` on `ℤ/M` |
| **Phase-locking** | offsets "stop changing" within a threshold, over a window | offsets are *identical* to the previous step |
| **Reproducibility** | drifts between machines | byte-identical anywhere |

The discrete-time phase-locking criterion is stated in terms of *finitely many
collisions*. A criterion you cannot decide is not a criterion. On `ℤ/M` it is
decidable.

## The result

**Frozen locking implies crossings stop — 2,600 runs, 1,069 of them locked,
zero counterexamples.**

That is an exact claim, not a statistical one. It is observable only because
"locked" and "crossing" are both equalities here.

The converse does **not** hold, and that asymmetry is the interesting part: a
tight cluster stops overtaking long before its offsets stop jittering by a single
slot. Crossing-free is strictly weaker than frozen.

## Two things the experiment corrected

### 1. A coincidence is not a collision

I first counted *coincidences* — pairs sharing a slot — and got a result that
inverted the theory: coincidences were **highest** when the system was most
synchronised. Of course they were. A tight cluster on a discrete circle shares
slots constantly, precisely because it is tight.

The continuous theory means a **crossing**: an event where one oscillator
overtakes another, i.e. the signed offset changes sign. That is what the
criterion bounds. Measured on the same system:

| K | spread | crossings | coincidences |
|---|---|---|---|
| 1.00 | 8 | **16** | **1592** |
| 2.00 | 87 | **20752** | **398** |

The two quantities invert. Anything reasoning about "collisions" in a discrete
phase space has to say which it means.

### 2. Phase-locked is not synchronised

Four oscillators at 90° spacing with identical frequencies sit in a **splay
state**: the coupling sums cancel exactly, the offsets never move. It is a
genuine phase-locked equilibrium at *maximum* spread.

Locking and coherence are independent axes. Testing one as a proxy for the other
disagreed on 116 of 480 runs, and every disagreement was one of these two cases.

## An upper critical coupling

Continuous Kuramoto has no upper bound — more coupling never hurts. The discrete
map overshoots, and the effect is sharp:

```
   K= 0.12   91.0%  ########################################
   K= 0.50   89.5%  ###################################
   K= 1.00   88.5%  ###################################
   K= 1.25   19.5%  #######          <- cliff
   K= 1.50    7.0%  ##
   K= 2.00    0.0%
```

Locking collapses between K=1.0 and K=1.25 and is gone by K=2.0.

Two anomalies, recorded rather than smoothed:
- A reproducible non-monotonic dip at **K=0.75 (64%)**, between neighbours at
  89.5% and 88.5%. Unexplained.
- Under sine coupling, lock rate is 0.0% from K=1.25 through K=2.00 and then
  **0.5% at K=3.00** — one system out of 200 re-locks. Also unexplained, and
  small enough that it could be a single well-conditioned initial condition
  rather than a real re-entrant window.

## Two coupling laws, honestly labelled

- **`sawtooth`** — the signed shortest offset itself. Fully exact, no table, no
  constants. A genuine and studied Kuramoto variant, but **not** sine coupling.
- **`sine_coupling`** — a frozen integer sine table, built once by exact
  rounding and then constant. The dynamics never touch a float; the table is an
  auditable artifact whose symmetries (`t[0]=0`, `t[M/2]=0`, `t[M/4]=scale`,
  `sum=0`, odd symmetry) are asserted by tests.

Sine locks over a much narrower window — sawtooth is linear all the way to the
antipode and so keeps a strong restoring force at large separations, while sine
flattens out:

| K | sawtooth | sine |
|---|---|---|
| 0.12 | 93.0% | 91.5% |
| 0.50 | 91.5% | 65.0% |
| 1.00 | 90.5% | 9.0% |
| 1.25 | 20.5% | 0.0% |

## Reproducing

```bash
python run_study.py        # writes results/study.json
python -m pytest tests/ -q # 12 tests
```

Every number above comes from `run_study.py` and is checked against
`results/study.json`, which is committed. Same seed, same answer, any machine.

## What this does not show

- **This is not evidence for the quantum-bridge argument.** That document mapped
  Kuramoto onto a multi-agent timing protocol as one of ten analogies. This
  experiment tests the *oscillator model*, not the analogy, and if anything it
  complicates the mapping: the "finitely many collisions" criterion it cites
  needs the crossing/coincidence distinction to survive translation into a
  discrete setting.
- **The sawtooth law is not sine.** Results under it are results about that model.
- **No claim about continuous-time Kuramoto.** The upper critical coupling here
  is a property of the discrete map.
- **`ω` and `K` are integers/rationals by construction.** Irrational frequency
  ratios — where the richest continuous behaviour lives — are unreachable on a
  finite ring, by design.

Built on [`exact-band`](https://github.com/SuperInstance/exact-band)'s `Phase<N>`
type, which supplies the same exact circular metric in Rust.

## License

MIT
