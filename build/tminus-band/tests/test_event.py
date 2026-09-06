"""Firing semantics: knowledge gates, reporter floors, contradictions, decay."""

import pytest

from tminus_band import BandedCountdown, FireReason, IBox


def ev(**kw):
    base = dict(name="haul", band=IBox.centered([1000], 200),
                target_width=20, min_reporters=2)
    base.update(kw)
    return BandedCountdown(**base)


def test_starts_not_ready_with_nobody_reporting():
    assert ev().ready() == (False, FireReason.TOO_FEW_REPORTERS)


def test_agreement_narrows_and_eventually_fires():
    e = ev()
    e.confirm("a", IBox.centered([1005], 60))
    assert e.band.width(0) == 120
    e.confirm("b", IBox.centered([998], 8))
    assert e.band.width(0) == 16
    assert e.ready() == (True, FireReason.KNOWN_ENOUGH)


def test_narrowing_is_monotone_confirmation_never_widens():
    e = ev(target_width=0)
    last = e.band.width(0)
    for i, r in enumerate([80, 40, 20, 9, 3]):
        e.confirm(f"s{i}", IBox.centered([1000], r))
        w = e.band.width(0)
        assert w <= last, f"report {i} widened the band: {w} > {last}"
        last = w


def test_one_confident_reporter_cannot_fire_alone():
    """The Byzantine floor. A single implausibly-narrow claim must not fire."""
    e = ev(min_reporters=2)
    e.confirm("liar", IBox.point([1000]))
    assert e.band.certain(), "the band did narrow to a point"
    ready, why = e.ready()
    assert not ready and why == FireReason.TOO_FEW_REPORTERS, \
        "knowledge is the gate, but reporter count is the guard rail"


def test_min_reporters_one_permits_a_solo_fire_when_asked_for():
    e = ev(min_reporters=1)
    e.confirm("solo", IBox.centered([1000], 5))
    assert e.ready() == (True, FireReason.KNOWN_ENOUGH)


def test_contradiction_blocks_firing_even_when_band_is_tight():
    e = ev()
    e.confirm("a", IBox.centered([1000], 8))
    e.confirm("b", IBox.centered([1001], 6))
    assert e.ready()[0], "tight and well-reported before the contradiction"
    rep = e.confirm("c", IBox.centered([1400], 5))
    assert not rep.accepted
    # band is [995, 1007]; c claims [1395, 1405]; the gap is 1395 - 1007.
    assert e.band.hi == (1007,)
    assert rep.disagreement == (0, 1395 - 1007)
    assert e.ready() == (False, FireReason.CONTRADICTED), \
        "firing on knowledge you know is inconsistent is exactly the bug"


def test_contradicting_observation_does_not_destroy_the_band():
    """Intersecting a disjoint box would empty the band and lose what we knew."""
    e = ev()
    e.confirm("a", IBox.centered([1000], 10))
    before = e.band
    e.confirm("c", IBox.centered([9999], 1))
    assert e.band == before, "a contradiction must not erase prior knowledge"
    assert not e.band.is_empty()


def test_contradiction_records_where_and_by_how_much():
    e = ev(band=IBox((0, 0), (10, 10)), target_width=100)
    e.confirm("a", IBox((0, 0), (10, 10)))
    e.confirm("b", IBox((2, 40), (8, 50)))       # agrees on axis 0, not axis 1
    (c,) = e.contradictions()
    assert c.disagreement == (1, 30), "axis 1, gap of 30"


def test_decay_reopens_an_over_confident_band():
    """The over-confidence trap, and the least-machinery cure."""
    e = ev(stale_widen_per_tick=5)
    e.confirm("a", IBox.point([1000]))
    e.confirm("b", IBox.point([1000]))
    assert e.band.certain()
    # A later, correct observation the point-band cannot accept.
    e.confirm("c", IBox.centered([1012], 2))
    assert e.ready() == (False, FireReason.CONTRADICTED)
    # Forgetting lets it back in, without any float or special case.
    for _ in range(3):
        e.tick()
    assert not e.contradicted, "decay should have resolved the contradiction"
    assert e.band.width(0) == 30


def test_decay_is_off_by_default():
    e = ev()
    w = e.band.width(0)
    e.tick()
    assert e.band.width(0) == w, "no decay unless asked for"


def test_payload_round_trip_is_lossless():
    e = ev(stale_widen_per_tick=3)
    e.confirm("a", IBox.centered([1002], 40))
    e.confirm("bad", IBox.centered([5000], 1))
    back = BandedCountdown.from_payload("haul", e.to_payload())
    assert back.band == e.band
    assert back.contradicted == e.contradicted
    assert back.target_width == e.target_width
    assert back.min_reporters == e.min_reporters
    assert back.stale_widen_per_tick == e.stale_widen_per_tick
    assert len(back.reports) == len(e.reports)
    assert back.contradictions()[0].disagreement == e.contradictions()[0].disagreement
    assert back.ready() == e.ready()


def test_no_floats_anywhere_in_the_state():
    """Every number that survives into the payload must be an integer."""
    e = ev()
    e.confirm("a", IBox.centered([1000], 7))
    e.confirm("b", IBox.centered([1001], 3))

    def check(x, path="payload"):
        if isinstance(x, float):
            pytest.fail(f"float reached {path}: {x!r}")
        if isinstance(x, dict):
            for k, v in x.items():
                check(v, f"{path}.{k}")
        elif isinstance(x, (list, tuple)):
            for i, v in enumerate(x):
                check(v, f"{path}[{i}]")

    check(e.to_payload())
