"""Integer zonotopes, Python substrate.

The conformance stream proves this port AGREES with the Rust and C ones. It
cannot prove all three are right — a shared mistake reproduces perfectly — so
these check the algebra against its definitions, and include the regression for
a soundness bug that shipped in the Rust original.
"""

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from tminus_band.zono import CAP, Symbols, Zono  # noqa: E402


def test_subtracting_a_value_from_itself_is_exactly_zero():
    p = Symbols()
    x = Zono.uncertain(10, 1, p)
    d = x.sub(x, p)
    assert d.center == 0
    assert d.radius() == 0, "x - x must be exactly zero, not a two-wide band"
    # What interval arithmetic gives for the same question, for contrast.
    assert (9 - 11, 11 - 9) == (-2, 2)


def test_independent_sources_do_not_cancel():
    """The unsound direction: two separate measurements are not one value."""
    p = Symbols()
    a = Zono.uncertain(10, 1, p)
    b = Zono.uncertain(10, 1, p)
    assert a.sub(b, p).radius() == 2, "independent uncertainties must add"


def test_a_shared_source_cancels_only_in_proportion():
    p = Symbols()
    s = p.fresh()
    a = Zono.from_symbol(0, s, 3)
    b = Zono.from_symbol(0, s, 5)
    assert b.sub(a, p).radius() == 2
    assert a.add(b, p).radius() == 8


def test_linear_chains_are_exactly_tight():
    p = Symbols()
    x = Zono.uncertain(50, 4, p)
    y = Zono.uncertain(-20, 6, p)
    r = x.scale(3).add(y.scale(-2), p).shift(7).sub(x, p)
    assert r.radius() == 2 * 4 + 2 * 6, "a linear result must be exactly tight"
    # Attained at the extremes, since the form IS the reachable set.
    for e0 in (-1, 1):
        for e1 in (-1, 1):
            truth = 3 * (50 + 4 * e0) - 2 * (-20 + 6 * e1) + 7 - (50 + 4 * e0)
            lo, hi = r.interval()
            assert lo <= truth <= hi


def test_division_rounds_up_and_stays_sound():
    for num in (-97, -1, 0, 1, 50, 1234):
        for rad in (0, 1, 7, 100):
            for d in (1, 2, 3, 7, 16, 1000):
                p = Symbols()
                q = Zono.uncertain(num, rad, p).div_round(d, p)
                lo, hi = q.interval()
                for e in (-1, 0, 1):
                    truth = (num + rad * e) / d
                    assert lo <= truth <= hi, f"div {num}±{rad} / {d}"


def test_condensation_only_ever_widens():
    p = Symbols()
    small = Zono.exact(0)
    big = Zono.exact(0)
    total = 0
    for k in range(1, 2 * CAP + 1):
        s = p.fresh()
        small = small.add(Zono.from_symbol(k, s, k), p)
        big.terms.append((s, k))          # reference, no capacity limit
        big.center += k
        total += k
    assert small.condensations > 0, "the small form must have condensed"
    assert small.radius() >= total, "condensing must widen, never narrow"


def test_condensation_must_never_narrow_a_difference_of_shared_forms():
    """REGRESSION for a bug that shipped in the Rust original.

    When full, the first version added the spilled magnitude to an EXISTING
    term, keeping its symbol id. Two forms that both did so cancelled that error
    on subtraction — because cancelling shared symbols is what subtraction is
    for — leaving a band too NARROW, which lets a caller conclude two values
    agree when they do not.
    """
    p = Symbols()
    shared = [p.fresh() for _ in range(4)]
    small_a = Zono.exact(500)
    small_b = Zono.exact(500)
    exact_radius = 0
    for k, s in enumerate(shared):
        ca, cb = 7 * (k + 1), 3 * (k + 1)
        small_a = small_a.add(Zono.from_symbol(0, s, ca), p)
        small_b = small_b.add(Zono.from_symbol(0, s, cb), p)
        exact_radius += abs(ca - cb)
        for _ in range(CAP // 2):
            small_a = small_a.add(Zono.from_symbol(0, p.fresh(), 5), p)
            exact_radius += 5
    assert small_a.condensations > 0, "capacity must have been exceeded"
    d = small_a.sub(small_b, p)
    assert d.radius() >= exact_radius, (
        f"condensed difference {d.radius()} is narrower than the exact "
        f"{exact_radius} — unsound")


def test_terms_stay_sorted_by_symbol_id():
    """`add`/`sub` pair shared symbols in one linear pass, which needs the order.

    Condensation mints a fresh id into the middle of the list, so the ordering
    has to be restored — a detail all three substrates must agree on, or the
    conformance stream diverges.
    """
    p = Symbols()
    z = Zono.exact(0)
    for k in range(3 * CAP):
        z = z.add(Zono.from_symbol(1, p.fresh(), k + 1), p)
        ids = [s for s, _ in z.terms]
        assert ids == sorted(ids), f"terms out of order after {k + 1} adds"


# ---- Fixed: the scaled form that stops dividing ---------------------------

from tminus_band.zono import Fixed  # noqa: E402


def test_div_pow2_is_exact_and_mints_nothing():
    p = Symbols()
    s = p.fresh()
    f = Fixed(Zono.from_symbol(1000, s, 12)).div_pow2(6)
    assert f.z.condensations == 0
    assert f.z.terms == [(s, 12)], "no coefficient is touched by a scale change"


def test_rescale_widens_and_is_the_only_place_tightness_is_lost():
    p = Symbols()
    f = Fixed(Zono.from_symbol(1000, p.fresh(), 12)).div_pow2(6)
    before = f.interval()
    after = f.rescale(0, p)
    assert after.interval()[0] <= before[0]
    assert after.interval()[1] >= before[1]
    assert after.z.condensations > 0


def test_only_a_zonotope_can_conclude_that_two_nodes_agree():
    """The claim this whole crate exists for, in the Python substrate.

    After consensus the true disagreement collapses to zero. Interval arithmetic
    cannot see it at any number of rounds, because it has no way to know that
    x0 and x1 are built from the same three readings.
    """
    n, rounds = 3, 10
    pool = Symbols()
    syms = [pool.fresh() for _ in range(n)]
    z = [Fixed(Zono.from_symbol(1000, syms[i], 12)) for i in range(n)]
    widths = []
    for _ in range(rounds + 1):
        d = z[0].sub(z[1], pool)
        widths.append(1000 * d.width_scaled() // (1 << d.shift))
        prev = list(z)
        for i in range(n):
            z[i] = (prev[i].scale(2)
                    .add(prev[(i + n - 1) % n], pool)
                    .add(prev[(i + 1) % n], pool)
                    .div_pow2(2))

    assert widths[0] == 48000
    assert widths[-1] == 0, "the zonotope must reach exact agreement"
    assert widths == sorted(widths, reverse=True), "consensus never un-converges"

    # The identical recurrence under interval arithmetic, carried exactly.
    lo = [988] * n
    hi = [1012] * n
    den = 1
    for _ in range(rounds):
        plo, phi = list(lo), list(hi)
        for i in range(n):
            lo[i] = 2 * plo[i] + plo[(i + n - 1) % n] + plo[(i + 1) % n]
            hi[i] = 2 * phi[i] + phi[(i + n - 1) % n] + phi[(i + 1) % n]
        den *= 4
    box = 1000 * ((hi[0] - lo[0]) + (hi[1] - lo[1])) // den
    assert box == 48000, "interval arithmetic never narrows, at any round count"
