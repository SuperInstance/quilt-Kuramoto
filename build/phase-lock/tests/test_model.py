"""Tests for the exact-integer Kuramoto model.

The point of exact integers is that these assertions are equalities, not
tolerances. Nothing here compares against an epsilon.
"""

import pathlib
import random
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from phase_lock.model import (Ring, Run, make_sine_table, sawtooth,  # noqa: E402
                              simulate, sine_coupling)


# --- the ring metric -------------------------------------------------------

def test_distance_takes_the_short_way_round():
    r = Ring(360)
    assert r.distance(359, 1) == 2, "359 and 1 are 2 apart, not 358"
    assert r.distance(1, 359) == 2
    assert r.distance(0, 180) == 180


def test_distance_never_exceeds_half_the_circle():
    r = Ring(360)
    for a in range(0, 360, 7):
        for b in range(0, 360, 11):
            assert r.distance(a, b) <= 180


def test_offset_is_signed_and_agrees_with_distance():
    r = Ring(360)
    assert r.offset(359, 1) == 2
    assert r.offset(1, 359) == -2
    for a in range(0, 360, 13):
        for b in range(0, 360, 17):
            assert abs(r.offset(a, b)) == r.distance(a, b)


# --- the sine table --------------------------------------------------------

def test_sine_table_has_the_exact_symmetries_of_sine():
    m, scale = 360, 1000
    t = make_sine_table(m, scale)
    assert len(t) == m
    assert t[0] == 0 and t[m // 2] == 0, "sin(0) = sin(pi) = 0 exactly"
    assert t[m // 4] == scale, "sin(pi/2) = 1 exactly"
    assert t[3 * m // 4] == -scale
    assert sum(t) == 0, "a full period must sum to zero exactly"
    for k in range(1, m // 2):
        assert t[k] == -t[m - k], f"odd symmetry broken at {k}"


def test_sine_table_is_a_frozen_constant_not_live_floats():
    t = make_sine_table(90, 100)
    assert all(isinstance(v, int) for v in t), "every entry must be an integer"


# --- determinism, which is the whole point ---------------------------------

def test_two_runs_of_the_same_system_are_identical():
    ring = Ring(360)
    kw = dict(phases=[0, 40, 130, 250], omegas=[2, -1, 3, -3], ring=ring,
              k_num=4, k_den=8, steps=200)
    a, b = simulate(**kw), simulate(**kw)
    assert a.final_phases == b.final_phases
    assert a.crossings_total == b.crossings_total
    assert a.spread_history == b.spread_history


def test_no_float_ever_enters_the_state():
    ring = Ring(360)
    r = simulate(phases=[0, 40, 130], omegas=[2, -1, 3], ring=ring,
                 k_num=3, k_den=8, steps=50)
    for v in (*r.final_phases, *r.final_offsets, *r.spread_history,
              *r.crossings_per_step, r.crossings_total, r.coincidences_total):
        assert isinstance(v, int), f"{v!r} is not an integer"


# --- the distinctions the experiment turned up -----------------------------

def test_the_splay_state_is_locked_but_not_synchronised():
    """Phase-locking and coherence are independent axes.

    Four oscillators at 90-degree spacing with identical frequencies sit in a
    symmetric splay state: the coupling sums cancel exactly, so the offsets
    never move. It is locked, at maximum spread.
    """
    ring = Ring(360)
    r = simulate(phases=[0, 90, 180, 270], omegas=[3, 3, 3, 3], ring=ring,
                 k_num=4, k_den=8, steps=200)
    assert r.locked, "the splay state is a genuine phase-locked equilibrium"
    assert r.final_spread == 180, "and it is maximally spread"


def test_coincidences_and_crossings_are_different_quantities():
    """The definitional trap, as a measured inversion.

    A coincidence is a *state* (two oscillators share a slot now); a crossing is
    an *event* (one overtook the other). They are not proxies for each other,
    and the phase-locking criterion is about crossings.

    Here the same system at two coupling strengths inverts them: the clustered
    run coincides constantly while almost never crossing, and the scattered run
    crosses constantly while rarely coinciding.
    """
    import random
    ring = Ring(360)
    random.seed(7)
    n = 8
    om = [random.randint(-4, 4) for _ in range(n)]
    ph = [random.randrange(360) for _ in range(n)]
    kw = dict(omegas=om, ring=ring, k_den=8, steps=800, coupling=sawtooth)

    clustered = simulate(phases=list(ph), k_num=8, **kw)    # K = 1.0
    scattered = simulate(phases=list(ph), k_num=16, **kw)   # K = 2.0, over-coupled

    assert clustered.final_spread < scattered.final_spread
    assert clustered.coincidences_total > scattered.coincidences_total, \
        "the clustered run should coincide far more"
    assert clustered.crossings_total < scattered.crossings_total, \
        "yet cross far less -- the two quantities invert"


# --- the criterion ---------------------------------------------------------

def test_frozen_lock_implies_crossings_stop():
    """The one-directional criterion, exactly.

    Across a randomised sweep, every system whose pairwise offsets froze also
    stopped crossing. Zero counterexamples -- an exact claim, only observable
    because collisions here are equality rather than an epsilon.
    """
    ring = Ring(360)
    locked = counterexamples = 0
    for seed in range(40):
        random.seed(5000 + seed)
        n = random.randint(3, 10)
        om = [random.randint(-6, 6) for _ in range(n)]
        ph = [random.randrange(360) for _ in range(n)]
        for kn in (1, 2, 4, 8, 12, 16, 24):
            r = simulate(phases=list(ph), omegas=list(om), ring=ring,
                         k_num=kn, k_den=8, steps=400, lock_window=50)
            if r.locked:
                locked += 1
                if not r.tail_is_crossing_free(80):
                    counterexamples += 1
    assert locked > 100, f"expected a real sample of locked systems, got {locked}"
    assert counterexamples == 0, \
        f"{counterexamples} locked systems were still crossing"


def test_the_converse_does_not_hold():
    """Crossings can stop without the offsets freezing.

    Recorded so the asymmetry is not mistaken for a bug: a tight cluster stops
    overtaking long before its offsets stop jittering by a slot.
    """
    ring = Ring(360)
    found = False
    for seed in range(40):
        random.seed(6000 + seed)
        n = random.randint(4, 10)
        om = [random.randint(-5, 5) for _ in range(n)]
        ph = [random.randrange(360) for _ in range(n)]
        r = simulate(phases=ph, omegas=om, ring=ring, k_num=12, k_den=8,
                     steps=400, lock_window=50)
        if r.tail_is_crossing_free(80) and not r.locked:
            found = True
            break
    assert found, "expected at least one crossing-free but unfrozen system"


def test_over_coupling_destroys_locking():
    """A discrete-time phenomenon with no continuous-Kuramoto counterpart.

    In continuous time, stronger coupling never hurts. A discrete map overshoots.
    """
    ring = Ring(360)
    def rate(kn):
        hits = 0
        for seed in range(40):
            random.seed(7000 + seed)
            n = random.randint(4, 10)
            om = [random.randint(-6, 6) for _ in range(n)]
            ph = [random.randrange(360) for _ in range(n)]
            hits += simulate(phases=ph, omegas=om, ring=ring, k_num=kn,
                             k_den=8, steps=300, lock_window=50).locked
        return hits / 40

    assert rate(4) > 0.5, "moderate coupling should lock most systems"
    assert rate(24) == 0.0, "over-coupling should lock none"
