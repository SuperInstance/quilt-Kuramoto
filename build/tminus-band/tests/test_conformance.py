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
    Banded, Contradiction, IBox, Tightened,
    basis_meets, isqrt_ceil, isqrt_floor, max_basis,
)

VECTORS = json.loads((pathlib.Path(__file__).parent / "vectors.json").read_text())


def test_vectors_are_actually_loaded():
    """Guard against a silently empty fixture making every test below vacuous."""
    total = sum(len(v) for v in VECTORS.values())
    assert total >= 240, f"expected the full vector set, got {total}"


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
    for v in VECTORS["dist_sq"]:
        (a, b), (c, d) = v["a"], v["b"]
        z2 = (a - c) ** 2 + (b - d) ** 2
        assert z2 == int(v["z2"]), f"Z2 dist_sq {v['a']}->{v['b']}"
        da, db = a - c, b - d
        hexd = da * da - da * db + db * db
        assert hexd == int(v["hex"]), f"Hex dist_sq {v['a']}->{v['b']}"


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
