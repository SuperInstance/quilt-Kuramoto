#!/usr/bin/env python3
"""Reproduce the band experiment. Writes results/band_study.json.

Companion to run_study.py, which covers the positive results. The band
experiment is a NEGATIVE result, and a negative result whose numbers cannot be
regenerated is just an assertion -- so every figure the README states about
banded coupling is produced here and committed alongside it.
"""
import json, pathlib, random, sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from phase_lock.banded import simulate_banded
from phase_lock.model import Ring, sawtooth, simulate

RING = Ring(360)
RUNS = 120          # seeds per cell
STEPS = 400
KDEN = 8


def _ensemble(seed):
    random.seed(seed)
    n = random.randint(3, 12)
    om = [random.randint(-6, 6) for _ in range(n)]
    ph = [random.randrange(360) for _ in range(n)]
    return ph, om


def rate_plain(k_num, *, observe_every=1, base=3000):
    hit = 0
    for s in range(RUNS):
        ph, om = _ensemble(base + s)
        hit += simulate(phases=list(ph), omegas=list(om), ring=RING, k_num=k_num,
                        k_den=KDEN, steps=STEPS, coupling=sawtooth,
                        lock_window=50, observe_every=observe_every).locked
    return hit / RUNS


def rate_banded(k_num, *, base=3000, **kw):
    hit = 0
    for s in range(RUNS):
        ph, om = _ensemble(base + s)
        hit += simulate_banded(phases=list(ph), omegas=list(om), ring=RING,
                               k_num=k_num, k_den=KDEN, steps=STEPS,
                               lock_window=50, seed=base + s, **kw).locked
    return hit / RUNS


out = {"runs_per_cell": RUNS, "steps": STEPS, "ring": RING.m, "k_den": KDEN}

# --- headline: plain vs banded at three couplings ------------------------
head = {}
for kn in (1, 4, 8):
    head[f"{kn / KDEN:.3f}"] = {"plain": rate_plain(kn), "banded": rate_banded(kn)}
out["headline"] = head

# --- rescue 1: under-coupling? sweep K up to 32x -------------------------
sweep = {}
for kn in (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 128, 256):
    sweep[f"{kn / KDEN:.3f}"] = {"plain": rate_plain(kn), "banded": rate_banded(kn)}
out["k_sweep"] = sweep
out["k_sweep_best"] = {
    "plain": max(v["plain"] for v in sweep.values()),
    "banded": max(v["banded"] for v in sweep.values()),
}

# --- rescue 2: warm-up artifact? start more confident --------------------
conf = {}
for mh in (90, 60, 30, 15, 5):
    conf[str(mh)] = rate_banded(8, max_half=mh)
out["start_confidence"] = conf

# --- rescue 3: wrong regime? make observation sparse ---------------------
sparse = {}
for every in (1, 2, 5, 10):
    sparse[str(every)] = {
        "plain": rate_plain(1, observe_every=every),
        "banded": rate_banded(1, observe_every=every),
    }
out["sparse_observation"] = sparse

# --- rescue 4: missing decay? widen on unobserved ticks ------------------
decay = {}
for widen in (0, 1, 2, 4):
    decay[str(widen)] = rate_banded(1, observe_every=5, stale_widen=widen)
out["stale_widen"] = decay

pathlib.Path("results").mkdir(exist_ok=True)
pathlib.Path("results/band_study.json").write_text(json.dumps(out, indent=2))
print(json.dumps(out, indent=2))
print("wrote results/band_study.json")
