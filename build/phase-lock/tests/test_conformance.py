"""`Ring` must agree with `exact_band::Phase<N>` on every vector.

`tests/vectors.json` is emitted by `exact-band/examples/emit_vectors.rs`. The
`phase` section covers N = 2, 3, 5, 7 and 12 — **odd rings included, deliberately**.

An earlier version of the Rust `offset_to` compared `d > n / 2`, and integer
division truncates, so on an odd circle the half-way point rounded down and
offsets that were already shortest got flipped the long way round. Every vector
at the time used N=360, so nothing caught it. These vectors exist so that class
of bug cannot recur silently.
"""

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from phase_lock.model import Ring  # noqa: E402

VECTORS = json.loads((pathlib.Path(__file__).parent / "vectors.json").read_text())


def test_phase_vectors_are_present_and_cover_odd_rings():
    """Guard against an empty or even-only fixture making the tests vacuous."""
    phase = VECTORS["phase"]
    assert len(phase) > 200, f"expected the full phase sweep, got {len(phase)}"
    rings = {r["n"] for r in phase}
    assert {3, 5, 7} <= rings, f"odd rings must be covered, got {sorted(rings)}"


def test_ring_distance_matches_rust():
    for v in VECTORS["phase"]:
        r = Ring(v["n"])
        assert r.distance(v["a"], v["b"]) == v["distance"], \
            f"distance mismatch on N={v['n']} {v['a']}->{v['b']}"


def test_ring_offset_matches_rust_including_odd_rings():
    for v in VECTORS["phase"]:
        r = Ring(v["n"])
        assert r.offset(v["a"], v["b"]) == v["offset"], \
            f"offset mismatch on N={v['n']} {v['a']}->{v['b']}"


def test_the_specific_case_that_was_wrong():
    """N=7, slot 0 to slot 4: back by 3, not forward by 4."""
    r = Ring(7)
    assert r.offset(0, 4) == -3
    assert r.distance(0, 4) == 3
    got = [v for v in VECTORS["phase"] if v["n"] == 7 and v["a"] == 0 and v["b"] == 4]
    assert got and got[0]["offset"] == -3, "the Rust side must agree"


def test_offset_magnitude_equals_distance_everywhere_in_the_fixture():
    for v in VECTORS["phase"]:
        assert abs(v["offset"]) == v["distance"], \
            f"Rust itself is inconsistent on N={v['n']} {v['a']}->{v['b']}"
