#!/usr/bin/env python3
"""A fair re-run of the H4 experiment.

The original (`vendored/h4_learning_rate_experiment.py`, diagnosed in
`diagnose.py`) did not compare two architectures. It compared an agent that
learns against an agent whose learning was switched off. This script asks the
question the original meant to ask.

WHAT THE FAIR VERSION FIXES
---------------------------
1. The event condition must depend on something. In the original,
   `actual = predicted + noise`, so `|actual - predicted|` was pure sensor
   noise -- independent of the prediction, the target and the neighbours. Here
   the sensor reports the agent's ACTUAL residual from the target, which is
   what an event-triggered controller actually watches.

2. Both arms get identical update rules and identical neighbour coupling. The
   original gated the target-pull AND the `last_action` write behind the event,
   so the event arm lost learning and coordination together.

3. The comparison is reported per SENSOR READ as well as per episode. Reading
   less often is the entire purpose of event-triggered control; charging it for
   episodes while it is deliberately not spending reads measures nothing. If
   simulation-first still wins at an equal read budget, the claim survives in a
   form worth having.
"""

import json
import pathlib

import numpy as np

TARGET = 1.0
N_AGENTS = 20
N_EPISODES = 200
N_REPEATS = 40
LR = 0.05
COUPLING = 0.3
SENSOR_NOISE = 0.01
CONV = 0.05


def _init(rng):
    return rng.uniform(0.0, 2.0, N_AGENTS)


def _couple(x):
    """Ring coupling, applied identically in every arm."""
    nbr = 0.5 * (np.roll(x, 1) + np.roll(x, -1))
    return x + COUPLING * (nbr - x)


def run_always(rng):
    """Simulation-first: read the sensor every episode; the read confirms the
    prediction and its residual is the learning signal."""
    x = _init(rng)
    err, reads = [], []
    total = 0
    for _ in range(N_EPISODES):
        y = (x - TARGET) + SENSOR_NOISE * rng.standard_normal(N_AGENTS)
        x = x - LR * y
        total += N_AGENTS
        x = _couple(x)
        err.append(np.mean(np.abs(x - TARGET)))
        reads.append(total)
    return np.array(err), np.array(reads)


def run_event(rng, threshold):
    """Event-triggered: read only while the last residual was large.

    This is the real pattern, including the real hazard the original document
    described: once an agent is inside its threshold it stops reading, so it
    stops learning, and its error floor is set by the threshold rather than by
    the noise. That is a genuine limitation and it is measured here rather than
    manufactured.
    """
    x = _init(rng)
    last_res = np.full(N_AGENTS, np.inf)   # force a read on episode 0
    err, reads = [], []
    total = 0
    for _ in range(N_EPISODES):
        do_read = np.abs(last_res) > threshold
        if do_read.any():
            y = (x - TARGET) + SENSOR_NOISE * rng.standard_normal(N_AGENTS)
            x = np.where(do_read, x - LR * y, x)
            last_res = np.where(do_read, y, last_res)
            total += int(do_read.sum())
        x = _couple(x)
        err.append(np.mean(np.abs(x - TARGET)))
        reads.append(total)
    return np.array(err), np.array(reads)


def run_periodic(rng, every):
    """The control the original never ran: the SAME architecture, simply reading
    less often. If simulation-first's advantage is really about reading every
    tick, this is what it has to beat -- not a disabled agent."""
    x = _init(rng)
    err, reads = [], []
    total = 0
    for t in range(N_EPISODES):
        if t % every == 0:
            y = (x - TARGET) + SENSOR_NOISE * rng.standard_normal(N_AGENTS)
            x = x - LR * y
            total += N_AGENTS
        x = _couple(x)
        err.append(np.mean(np.abs(x - TARGET)))
        reads.append(total)
    return np.array(err), np.array(reads)


def converged_at(curve, thresh=CONV):
    idx = np.argmax(curve < thresh) if (curve < thresh).any() else None
    return int(idx) if idx is not None else None


def reads_to_converge(err, reads, thresh=CONV):
    hit = np.flatnonzero(err < thresh)
    return int(reads[hit[0]]) if hit.size else None


def average(fn, *args):
    errs, rds = [], []
    for r in range(N_REPEATS):
        rng = np.random.default_rng(1000 + r)
        e, d = fn(rng, *args)
        errs.append(e)
        rds.append(d)
    return np.mean(errs, axis=0), np.mean(rds, axis=0)


def main():
    out = {"n_agents": N_AGENTS, "episodes": N_EPISODES, "repeats": N_REPEATS,
           "lr": LR, "coupling": COUPLING, "sensor_noise": SENSOR_NOISE,
           "convergence_threshold": CONV, "arms": {}}

    def record(name, err, reads):
        out["arms"][name] = {
            "convergence_episode": converged_at(err),
            "reads_to_converge": reads_to_converge(err, reads),
            "total_reads": int(reads[-1]),
            "final_error": float(err[-1]),
        }
        ce = out["arms"][name]["convergence_episode"]
        rc = out["arms"][name]["reads_to_converge"]
        print(f"  {name:<28} episode {str(ce):>6}   reads {str(rc):>8}   "
              f"total reads {int(reads[-1]):>6}   final err {err[-1]:.5f}")

    print(f"Fair H4, {N_REPEATS} repeats, {N_AGENTS} agents, {N_EPISODES} episodes.")
    print("Both arms: identical update rule, identical ring coupling.")
    print("The only difference is WHEN the sensor is read.\n")

    e, d = average(run_always)
    record("simulation-first", e, d)

    for th in (0.01, 0.05, 0.1, 0.2, 0.5):
        e, d = average(run_event, th)
        record(f"event-triggered t={th}", e, d)

    for k in (2, 5, 10):
        e, d = average(run_periodic, k)
        record(f"periodic every {k}", e, d)

    # --- robustness -------------------------------------------------------
    # The finding below inverts the package's conclusion, so it gets the same
    # scrutiny the package's own result did not: does it survive the parameters?
    g = globals()
    base = (g["COUPLING"], g["SENSOR_NOISE"], g["LR"])
    sweep = []
    print("\nRobustness -- reads to converge (lower is better; null = never):")
    print(f"  {'coup':>5} {'noise':>6} {'lr':>5} | {'sim-first':>9} {'evt .1':>7} "
          f"{'evt .05':>8} {'per/5':>7}")
    for coup in (0.0, 0.1, 0.3, 0.5):
        for noise in (0.01, 0.05):
            for lr in (0.05, 0.15):
                g["COUPLING"], g["SENSOR_NOISE"], g["LR"] = coup, noise, lr
                cells = {}
                for label, fn, args in (("sim_first", run_always, ()),
                                        ("event_0.1", run_event, (0.1,)),
                                        ("event_0.05", run_event, (0.05,)),
                                        ("periodic_5", run_periodic, (5,))):
                    e, d = average(fn, *args)
                    cells[label] = reads_to_converge(e, d)
                sweep.append({"coupling": coup, "noise": noise, "lr": lr, **cells})
                print(f"  {coup:>5} {noise:>6} {lr:>5} | {str(cells['sim_first']):>9} "
                      f"{str(cells['event_0.1']):>7} {str(cells['event_0.05']):>8} "
                      f"{str(cells['periodic_5']):>7}")
    g["COUPLING"], g["SENSOR_NOISE"], g["LR"] = base
    out["robustness"] = sweep

    # --- the claims, asserted --------------------------------------------
    coupled = [r for r in sweep if r["coupling"] > 0]
    better = [r for r in coupled
              if r["event_0.05"] is not None and r["sim_first"] is not None
              and r["event_0.05"] < r["sim_first"]]
    out["claims"] = {
        "coupled_rows": len(coupled),
        "rows_where_event_beats_simfirst_on_reads": len(better),
        "uncoupled_rows_where_event_never_converges": sum(
            1 for r in sweep if r["coupling"] == 0 and r["event_0.05"] is None),
    }
    bad = []
    if len(better) != len(coupled):
        bad.append(f"event-triggered beat simulation-first on reads in only "
                   f"{len(better)}/{len(coupled)} coupled rows")
    if out["arms"]["simulation-first"]["convergence_episode"] is None:
        bad.append("simulation-first failed to converge at all")
    ratio = (out["arms"]["simulation-first"]["reads_to_converge"] /
             out["arms"]["event-triggered t=0.1"]["reads_to_converge"])
    out["claims"]["read_advantage_at_t0.1"] = ratio
    if ratio < 1.5:
        bad.append(f"the per-read advantage collapsed to {ratio:.2f}x")

    pathlib.Path("results.json").write_text(json.dumps(out, indent=2))
    print("\nwrote results.json")
    if bad:
        for b in bad:
            print("FAIL:", b)
        raise SystemExit(1)
    print(f"\nEvent-triggered needs {ratio:.2f}x FEWER sensor reads than "
          f"simulation-first to converge,")
    print(f"in all {len(coupled)} coupled parameter settings. With no coupling it "
          f"does not converge at all")
    print(f"in {out['claims']['uncoupled_rows_where_event_never_converges']}/4 "
          f"settings -- the honest limitation.")
    return out


if __name__ == "__main__":
    main()
