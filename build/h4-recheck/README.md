# h4-recheck — the corpus's strongest claim does not survive

`quilt-quantum-research-complete` calls its H4 experiment **"the most
consequential experiment in the documentation set"** and **"the strongest
measured result"**. It reports that simulation-first coordination learns
**11.8× faster** than event-triggered, and offers this as empirical support for
Wei's verifier's rule in a distributed multi-agent system. All four of the
package's independent judges accepted it as real.

It does not measure that. **It measures an agent that learns against an agent
whose learning is switched off.**

```
$ python3 diagnose.py     # five defects, reproduced as assertions
$ python3 fair.py         # the corrected experiment
```

## The defects

Run `diagnose.py`; it executes the original code from `vendored/`, unmodified
except for a hardcoded output path, and asserts every claim below.

**1. The event condition is computed on sensor noise alone.**

```python
actual = predicted + 0.01 * RNG.standard_normal()
error  = abs(actual - predicted)          # ==  |0.01 * N(0,1)|
event_fired = error > event_threshold
```

Substituting the first line into the second leaves pure noise with σ = 0.01. The
trigger does not depend on the agent's prediction, the target, or its
neighbours — the three things the experiment is about.

**2. So at the headline threshold the event arm never learns, once.**

| threshold | events in 4,000 agent-episodes |
|---|---|
| 0.01 | 1,265 (31.6%) |
| 0.05 | **0** |
| 0.1 ← headline | **0** |
| 0.2 | **0** |
| 0.3 | **0** |

`update_event_triggered` returns early when no event fires, skipping the pull
toward the target. That pull is the *only* term that reduces the measured
quantity. The reported 11.8×, 10.5×, 10.0× and 12.5× rows all compare a learning
agent against an agent with learning disabled.

**3. The event arm also loses neighbour communication.** `last_action` is written
only inside the update methods, so the early return freezes it. Every agent's
neighbours read its *initial random guess* for all 200 episodes. It is not a
coordinating fleet.

**4. The "plateau at ~0.33" is the initialisation residual.** The package reads
the flat error as a qualitative finding — *"event-triggered plateaus and stops
improving"*. With learning and coordination both disabled, each agent converges
to the mean of its two neighbours' initial `uniform(0,2)` guesses. That constant
is `E|½(U₁+U₂) − 1| = 0.3332`. The package reports ~0.33. There are no dynamics
in it at all.

**5. The sweep refutes the conclusion drawn from it.** The package's Finding 2
says *"the advantage is NOT just about event frequency"*, citing a residual 3.9×
at threshold 0.01. But 0.01 is exactly one σ of the noise the trigger reads, so
events fire on `P(|Z| > 1) = 31.7%` of episodes and the arm learns at that
fraction of the rate. `1/0.317 = 3.15`. The residual speedup *is* the event
frequency — the one thing Finding 2 rules out.

## The fair experiment

`fair.py` asks the question the original meant to ask. Both arms get identical
update rules and identical ring coupling; the sensor reports the agent's real
residual from the target; the **only** difference is when the sensor is read.

And it reports the metric the original omitted: **error per sensor read.**
Reading less often is the entire purpose of event-triggered control. Charging it
for episodes while it is deliberately not spending reads measures nothing.

| arm | converged at episode | **sensor reads to converge** | final error |
|---|---|---|---|
| simulation-first | **21** | 440 | 0.00057 |
| event-triggered t=0.01 | 22 | 374 | 0.0117 |
| event-triggered t=0.05 | 27 | 311 | 0.0270 |
| event-triggered t=0.1 | 58 | **215** | 0.0418 |
| event-triggered t=0.2 | never | — | 0.0599 |
| periodic every 2 | 36 | 380 | 0.00086 |
| periodic every 5 | 70 | 300 | 0.0122 |

**The advantage runs the other way.** Simulation-first is ~2.8× faster per
*episode* — but it spends 18× more sensor reads to get there, and needs **2.05×
more reads** than event-triggered to reach the same accuracy. Even *periodic
sampling* — the trivial control the original never ran — beats it per read.

The 11.8× appears nowhere, in either direction, under any setting tested.

## What is actually true, including the part that favours simulation-first

The corrected result is a **trade, not a winner**, and `fair.py` asserts both
halves across 16 parameter settings:

- **With coupling, event-triggered converges in about half the sensor reads.**
  This holds in **all 12** settings with coupling > 0, across two noise levels
  and two learning rates.
- **Without coupling, event-triggered often does not converge at all** — 3 of 4
  uncoupled settings. Once an agent is inside its threshold it stops reading, so
  its error floor is set by the threshold rather than by the noise. A loose
  threshold (t ≥ 0.2) never reaches the target accuracy even *with* coupling.

So: **event-triggered buys sensor reads and pays in guaranteed floor.
Simulation-first buys a guaranteed floor and pays in sensor reads.** That is the
classical event-triggered-control trade-off, and it is well known. The corpus
rediscovered it backwards, through a harness that had disabled one arm.

## Why this matters beyond one script

The package's own summary lists the 11.8× as one of exactly **three results that
survive its cross-critique**, alongside the machine-checked conservation
invariant and the formally verified FPGA fabric. Removing it leaves two.

It also matters for how the other two should be read. Four independent judges —
quantum, hardware, complexity, distributed systems — reviewed this and none ran
the code. The defect is not subtle once executed: one `print` of the event count
shows a hard zero. **A review process that reads conclusions and checks
reasoning will not catch a harness that silently disabled an arm.** Only running
it does.

This repository's other studies are structured to fail loudly for exactly that
reason: `divergence/` asserts a negative control on its own contrast, and
`CONFORMANCE-STREAM.md` records which layer catches which planted mutation. That
discipline is not ceremony. This is what it is for.

## What this does *not* say

- **Not a claim that the verifier's rule is false.** It is a claim that this
  experiment provides no evidence either way. A correct test remains possible and
  interesting; `fair.py` is a starting point, not that test.
- **Not a claim about the other two surviving results.** The conservation
  invariant and the FPGA proofs are untouched here. They deserve the same
  treatment — running the artifact, not reading the write-up.
- **Not a claim that simulation-first is worse.** It converges to a far lower
  floor and needs no threshold tuning. On a system where sensor reads are cheap
  and accuracy matters, it is the right choice. The point is that the reported
  advantage was 11.8× in the wrong units of the wrong experiment.
- **Single-process Python, one machine.** Same limitation the package itself
  acknowledged for the original.
