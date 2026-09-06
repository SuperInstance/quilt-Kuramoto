"""Cross-substrate conformance: this Python port must agree with the Rust crate.

`tests/vectors.json` is emitted by `exact-band/examples/emit_vectors.rs`. Every
assertion here compares this implementation against a value the Rust crate
actually produced. If the two disagree, one of them is wrong — and the point of
having two substrates is that the disagreement is visible.

This mirrors the ecosystem's existing byte-exact discipline, where a cell state
hash is required to agree across five language ports.
"""

import json
import pathlib

from tminus_band.band import (
    Banded, Contradiction, HEX_UNITS, IBox, Tightened,
    basis_meets, dist_sq_hex, dist_sq_z1, dist_sq_z2, dist_sq_z3,
    isqrt_ceil, isqrt_floor, max_basis,
)

VECTORS = json.loads((pathlib.Path(__file__).parent / "vectors.json").read_text())


def test_vectors_are_actually_loaded():
    """Guard against a silently empty fixture making every test below vacuous."""
    total = sum(len(v) for v in VECTORS.values())
    assert total >= 801, f"expected the full vector set, got {total}"


def test_covering_matches_rust():
    for v in VECTORS["covering"]:
        dim, eps = v["dim"], v["eps"]
        assert max_basis(dim, eps) == v["max_basis"], f"max_basis({dim},{eps})"
        assert basis_meets(dim, v["max_basis"], eps) is v["meets"]
        # The negative control, carried across the language boundary.
        assert basis_meets(dim, v["max_basis"] + 1, eps) is v["meets_plus_one"]


def test_isqrt_matches_rust_including_u128_extremes():
    for v in VECTORS["isqrt"]:
        n = int(v["n"])
        assert isqrt_floor(n) == int(v["floor"]), f"isqrt_floor({n})"
        assert isqrt_ceil(n) == int(v["ceil"]), f"isqrt_ceil({n})"


def test_hex_norm_matches_rust_at_i32_extremes():
    """Against this package's lattice functions, not against a formula re-typed here.

    This test previously recomputed `a**2 - a*b + b**2` in its own body and
    compared that to the fixture — which checks that the emitter agrees with
    three lines written directly above the assertion, and says nothing about
    whether `tminus_band` implements the norm at all. It now calls the library.
    """
    for v in VECTORS["dist_sq"]:
        assert dist_sq_z2(v["a"], v["b"]) == int(v["z2"]), f"Z2 {v}"
        assert dist_sq_hex(v["a"], v["b"]) == int(v["hex"]), f"Hex {v}"


def test_hex_units_have_norm_one():
    """The six units of Z[omega], and the non-unit that was once mistaken for one."""
    for i, u in enumerate(HEX_UNITS):
        assert dist_sq_hex(u, (0, 0)) == 1, f"unit {u} should have norm 1"
        opp = HEX_UNITS[(i + 3) % 6]
        assert (u[0], u[1]) == (-opp[0], -opp[1]), "units three apart are opposite"
    assert dist_sq_hex((-1, 1), (0, 0)) == 3, "(-1, 1) is not a unit"


def test_banded_narrow_matches_rust():
    for v in VECTORS["banded_narrow"]:
        a = Banded((v["a"]["v"],), v["a"]["r"])
        b = Banded((v["b"]["v"],), v["b"]["r"])
        assert a.overlaps(b) is v["overlaps"], f"overlaps {v}"
        got, want = a.narrow(b), v["result"]
        if want["kind"] == "tightened":
            assert isinstance(got, Tightened), f"expected agreement: {v}"
            assert got.band.value == (want["value"],)
            assert got.band.radius == want["radius"]
        else:
            assert isinstance(got, Contradiction), f"expected contradiction: {v}"
            assert got.gap_sq == int(want["gap_sq"])
            assert got.gap == int(want["gap"])


def test_ibox_narrow_matches_rust():
    for v in VECTORS["ibox_narrow"]:
        a = IBox((v["a"][0],), (v["a"][1],))
        b = IBox((v["b"][0],), (v["b"][1],))
        assert a.is_empty() is v["a_empty"]
        assert b.is_empty() is v["b_empty"]
        got, want = a.narrow(b), v["result"]
        if want["kind"] == "box":
            assert got is not None, f"expected a box: {v}"
            assert got.lo == (want["lo"],) and got.hi == (want["hi"],)
        else:
            assert got is None, f"expected disjoint: {v}"
            dis = a.disagreement(b)
            if want["axis"] is None:
                assert dis is None
            else:
                assert dis == (want["axis"], want["gap"])


def test_dist_sq_z1_matches_rust():
    """One dimension, including both i32 extremes.

    These were computed by the emitter and thrown away in its first version, so
    no substrate was ever held to them. The widest case here is
    `(i32::MAX - i32::MIN)**2 = (2**32 - 1)**2`, which is the largest squared
    distance any one-dimensional lattice can produce.
    """
    seen_extreme = False
    for v in VECTORS["dist_sq_z1"]:
        assert dist_sq_z1(v["a"], v["b"]) == int(v["d2"]), f"z1 {v}"
        if int(v["d2"]) == (2 ** 32 - 1) ** 2:
            seen_extreme = True
    assert seen_extreme, "the widest one-dimensional case should be in the fixture"


def test_dist_sq_z3_matches_rust():
    """Three dimensions -- the only case that sums three squared terms.

    That is precisely the shape a 64-bit port has to bound, so it is worth
    pinning across substrates rather than inferring from the two-dimensional
    vectors.
    """
    for v in VECTORS["dist_sq_z3"]:
        assert dist_sq_z3(v["a"], v["b"]) == int(v["d2"]), f"z3 {v}"


def test_banded_within_matches_rust():
    """Containment, in BOTH directions for every pair.

    `within` is neither symmetric nor the same as `overlaps`, and the natural
    way to get it wrong -- comparing the radii the other way round before
    subtracting -- produces an answer that is right for one direction of each
    pair and wrong for the other. Recording both directions is what makes that
    mistake visible.
    """
    both, neither, one_way = 0, 0, 0
    for v in VECTORS["banded_within"]:
        a = Banded((v["a"]["v"],), v["a"]["r"])
        b = Banded((v["b"]["v"],), v["b"]["r"])
        assert a.within(b) is v["a_within_b"], f"a within b: {v}"
        assert b.within(a) is v["b_within_a"], f"b within a: {v}"
        if v["a_within_b"] and v["b_within_a"]:
            both += 1
            assert a.value == b.value and a.radius == b.radius, \
                "mutual containment means the bands are equal"
        elif v["a_within_b"] or v["b_within_a"]:
            one_way += 1
        else:
            neither += 1
    assert both and one_way and neither, \
        f"fixture should cover all three cases, got {both}/{one_way}/{neither}"


def test_from_basis_matches_rust_and_never_understates():
    """The band a lattice basis induces, rounded UP.

    Soundness is the whole claim: `4r**2 >= n*b**2` must hold, and `r-1` must
    fail it, or the band would understate the uncertainty it exists to carry.
    Checked here directly, not just against the recorded number.
    """
    for v in VECTORS["from_basis"]:
        b = v["basis"]
        for dim, key in ((1, "radius_dim1"), (2, "radius_dim2"), (3, "radius_dim3")):
            r = Banded.from_basis((0,) * dim, b, dim).radius
            assert r == v[key], f"from_basis dim={dim} {v}"
            assert 4 * r * r >= dim * b * b, f"understated at dim={dim}: {v}"
            if r > 0:
                assert 4 * (r - 1) * (r - 1) < dim * b * b, \
                    f"not minimal at dim={dim}: {v}"


def test_ibox_two_dimensional_narrow_matches_rust():
    """Two axes, so `disagreement` finally has a choice to make.

    Every earlier ibox vector was one-dimensional, where the worst axis is the
    only axis. Here the fixture contains disjoint pairs whose gap is larger on
    axis 0 and pairs whose gap is larger on axis 1, so a port that returned the
    first disagreeing axis rather than the worst one now fails.
    """
    axes_seen = set()
    for v in VECTORS["ibox2_narrow"]:
        a = IBox(tuple(v["a"]["lo"]), tuple(v["a"]["hi"]))
        b = IBox(tuple(v["b"]["lo"]), tuple(v["b"]["hi"]))
        got, want = a.narrow(b), v["result"]
        if want["kind"] == "box":
            assert got is not None, f"expected a box: {v}"
            assert got.lo == tuple(want["lo"]) and got.hi == tuple(want["hi"])
            assert a.disagreement(b) is None
        else:
            assert got is None, f"expected disjoint: {v}"
            dis = a.disagreement(b)
            assert dis == (want["axis"], want["gap"]), f"axis choice: {v}"
            axes_seen.add(want["axis"])
    assert axes_seen == {0, 1}, \
        f"fixture must exercise both axes as the worst one, saw {axes_seen}"
