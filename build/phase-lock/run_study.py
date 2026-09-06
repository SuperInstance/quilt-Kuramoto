#!/usr/bin/env python3
"""Reproduce every number in README.md. Writes results/study.json."""
import json, random, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from phase_lock.model import Ring, make_sine_table, sawtooth, simulate, sine_coupling

ring, out = Ring(360), {}

# 1. frozen-lock => crossings stop
tot = locked = viol = 0
for seed in range(200):
    random.seed(1000 + seed); n = random.randint(3, 12)
    om = [random.randint(-6, 6) for _ in range(n)]; ph = [random.randrange(360) for _ in range(n)]
    for kn in (1, 2, 3, 4, 6, 8, 10, 12, 16, 20, 24, 32, 48):
        r = simulate(phases=list(ph), omegas=list(om), ring=ring, k_num=kn, k_den=8,
                     steps=500, coupling=sawtooth, lock_window=50)
        tot += 1
        if r.locked:
            locked += 1
            viol += not r.tail_is_crossing_free(100)
out["implication"] = {"runs": tot, "locked": locked, "counterexamples": viol}

# 2. the coupling window
win = {}
for kn in (1, 2, 3, 4, 6, 8, 10, 11, 12, 13, 14, 16, 20, 24, 32):
    hit = 0
    for seed in range(200):
        random.seed(1000 + seed); n = random.randint(3, 12)
        om = [random.randint(-6, 6) for _ in range(n)]; ph = [random.randrange(360) for _ in range(n)]
        hit += simulate(phases=list(ph), omegas=list(om), ring=ring, k_num=kn, k_den=8,
                        steps=400, coupling=sawtooth, lock_window=50).locked
    win[f"{kn/8:.3f}"] = hit / 200
out["lock_rate_by_K"] = win

# 3. sawtooth vs frozen integer sine
SCALE = 180
sine = sine_coupling(make_sine_table(360, SCALE), SCALE)
cmp_ = {}
for kn in (1, 2, 4, 6, 8, 10, 12, 16, 24):
    hs = hn = 0
    for seed in range(200):
        random.seed(2000 + seed); n = random.randint(3, 12)
        om = [random.randint(-6, 6) for _ in range(n)]; ph = [random.randrange(360) for _ in range(n)]
        hs += simulate(phases=list(ph), omegas=list(om), ring=ring, k_num=kn, k_den=8,
                       steps=400, coupling=sawtooth, lock_window=50).locked
        hn += simulate(phases=list(ph), omegas=list(om), ring=ring, k_num=kn,
                       k_den=8 * SCALE // 90, steps=400, coupling=sine, lock_window=50).locked
    cmp_[f"{kn/8:.3f}"] = {"sawtooth": hs / 200, "sine": hn / 200}
out["sawtooth_vs_sine"] = cmp_

pathlib.Path("results").mkdir(exist_ok=True)
pathlib.Path("results/study.json").write_text(json.dumps(out, indent=2))
print(json.dumps(out["implication"], indent=2))
print("wrote results/study.json")
