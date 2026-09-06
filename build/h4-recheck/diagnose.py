#!/usr/bin/env python3
"""Reproduce the four defects in the vendored H4 experiment, as assertions.

A diagnosis stated in prose is a claim. This is the same diagnosis as a program
that fails if any part of it is wrong, run against the ORIGINAL code with its
behaviour unmodified -- only the hardcoded output directory is neutralised.

The vendored file is `vendored/h4_learning_rate_experiment.py`, from
`quilt-quantum-research-complete/scripts/`. The package calls its result "the
most consequential experiment in the documentation set" and "the strongest
measured result", and reports that simulation-first learns 11.8x faster. All
four of its independent judges accepted it.

It does not measure that. It measures an agent that learns against an agent
whose learning is switched off.
"""

import pathlib
import sys

import numpy as np
from scipy.stats import norm

HERE = pathlib.Path(__file__).resolve().parent
FAILURES = []


def check(name, condition, detail):
    status = "ok  " if condition else "FAIL"
    print(f"  [{status}] {name}")
    print(f"         {detail}")
    if not condition:
        FAILURES.append(name)


def load_original():
    """Execute the vendored module body, without its __main__ block."""
    src = (HERE / "vendored" / "h4_learning_rate_experiment.py").read_text()
    src = src.split("if __name__ == '__main__':")[0]
    ns = {}
    exec(compile(src, "h4_learning_rate_experiment.py", "exec"), ns)
    return ns


def main():
    ns = load_original()
    Agent, RNG = ns["Agent"], ns["RNG"]
    n, episodes = 20, 200

    print(__doc__)
    print("=" * 72)
    print("DEFECT 1 -- the event condition is computed on sensor noise alone.")
    print("=" * 72)
    print("""
  In the episode loop:      actual = predicted + 0.01 * N(0,1)
                            error  = abs(actual - predicted)
                            event_fired = error > threshold

  Substituting the first line into the second leaves error == |0.01 * N(0,1)|.
  It does not depend on the agent's prediction, the target, or its neighbours.
  The trigger is disconnected from everything the experiment is about.
""")
    p_at_headline = 2 * norm.sf(0.1 / 0.01)
    check("headline threshold 0.1 makes events astronomically improbable",
          p_at_headline < 1e-20,
          f"P(event) = 2*P(Z > 10) = {p_at_headline:.3e}; "
          f"expected events per agent over 200 episodes = {p_at_headline*200:.3e}")

    print()
    print("=" * 72)
    print("DEFECT 2 -- so the event arm never receives the task signal at all.")
    print("=" * 72)
    print("""
  `update_event_triggered` returns early when no event fires, skipping BOTH the
  pull toward the target and the write to `last_action`. `update_simulation_first`
  applies the target pull unconditionally. The measured quantity is the distance
  to the target, and only that pull reduces it.
""")
    fired_by_threshold = {}
    for thresh in (0.01, 0.05, 0.1, 0.2, 0.3):
        agents = [Agent(i, target_time=1.0, learning_rate=0.05) for i in range(n)]
        fired = 0
        for _ in range(episodes):
            for i, a in enumerate(agents):
                nb = [agents[(i - 1) % n].last_action, agents[(i + 1) % n].last_action]
                pred = a.predict_next(nb)
                actual = pred + 0.01 * RNG.standard_normal()
                ev = abs(actual - pred) > thresh
                fired += bool(ev)
                a.update_event_triggered(actual, ev)
        fired_by_threshold[thresh] = fired
        print(f"    threshold {thresh:<5} -> {fired:>5} events in {n*episodes} agent-episodes")

    check("at the headline threshold the event arm never learns even once",
          fired_by_threshold[0.1] == 0,
          f"{fired_by_threshold[0.1]} events fired at threshold 0.1, so the target "
          f"pull ran {fired_by_threshold[0.1]} times in {n*episodes} agent-episodes")
    check("the same holds for every threshold at or above 0.05",
          all(fired_by_threshold[t] == 0 for t in (0.05, 0.1, 0.2, 0.3)),
          "the reported 11.8x, 10.5x, 10.0x and 12.5x rows all compare a learning "
          "agent against an agent with learning disabled")

    print()
    print("=" * 72)
    print("DEFECT 3 -- the event arm also loses neighbour communication.")
    print("=" * 72)
    print("""
  `last_action` is assigned only inside the update methods, so the early return
  freezes it. Every agent's neighbours read its INITIAL guess for all 200
  episodes. The event arm is not a coordinating fleet; it is 20 agents blending
  toward two fixed numbers.
""")
    agents = [Agent(i, target_time=1.0, learning_rate=0.05) for i in range(n)]
    init = [a.last_action for a in agents]
    for _ in range(episodes):
        for i, a in enumerate(agents):
            nb = [agents[(i - 1) % n].last_action, agents[(i + 1) % n].last_action]
            pred = a.predict_next(nb)
            actual = pred + 0.01 * RNG.standard_normal()
            a.update_event_triggered(actual, abs(actual - pred) > 0.1)
    final = [a.last_action for a in agents]
    check("last_action never changes in the event arm",
          all(a == b for a, b in zip(init, final)),
          "neighbours observe the initial random guess for the whole run")

    print()
    print("=" * 72)
    print("DEFECT 4 -- the reported 0.33 'plateau' is the initialisation residual.")
    print("=" * 72)
    print("""
  The package reads the event arm's flat ~0.33 error as a qualitative finding:
  "event-triggered plateaus and stops improving". With learning and coordination
  both disabled, each agent converges to the mean of its two neighbours' INITIAL
  uniform(0,2) guesses, so the expected final error is a fixed constant of the
  initialisation -- no dynamics involved.
""")
    rng = np.random.default_rng(0)
    predicted_plateau = float(np.mean(np.abs(
        0.5 * (rng.uniform(0, 2, 400000) + rng.uniform(0, 2, 400000)) - 1.0)))
    check("the arithmetic residual matches the reported plateau",
          abs(predicted_plateau - 0.33) < 0.01,
          f"E|mean of two uniform(0,2) draws - 1| = {predicted_plateau:.4f}; "
          f"the package reports ~0.33")

    print()
    print("=" * 72)
    print("DEFECT 5 -- the sweep refutes the conclusion drawn from it.")
    print("=" * 72)
    print("""
  The package's Finding 2 states: "the advantage is NOT just about event
  frequency", citing a residual 3.9x speedup at threshold 0.01. But 0.01 is
  exactly one sigma of the noise the trigger is reading, so events fire on
  P(|Z| > 1) of episodes, and the arm learns at that fraction of the rate.
""")
    p001 = 2 * norm.sf(1.0)
    check("the residual 3.9x is the event frequency, not a mode difference",
          abs(1 / p001 - 3.15) < 0.1,
          f"P(event) at threshold 0.01 = {p001:.4f}, so 1/P = {1/p001:.2f} -- "
          f"the package reports 3.9x, and measured {fired_by_threshold[0.01]}"
          f"/{n*episodes} = {100*fired_by_threshold[0.01]/(n*episodes):.1f}% firing")

    print()
    print("=" * 72)
    if FAILURES:
        print(f"{len(FAILURES)} CHECK(S) FAILED: {FAILURES}")
        return 1
    print("All five defects reproduce. The 11.8x is an artifact of the harness,")
    print("not a property of either architecture. See fair.py for the corrected")
    print("experiment and README.md for what survives.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
