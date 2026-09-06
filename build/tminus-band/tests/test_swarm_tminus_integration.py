"""Live integration with the real `swarm-tminus` package.

Skipped if it isn't installed. These tests assert the wrapper genuinely composes
with upstream rather than reimplementing it: an existing `CountdownEvent` keeps
working, its JSON stays loadable by upstream's own `from_dict`, and count-based
tooling still sees a sensible picture.
"""

import pytest

swarm = pytest.importorskip("swarm_tminus.events")
from tminus_band import BandedCountdown, IBox  # noqa: E402


def make_upstream(name="haul", quorum=2):
    return swarm.CountdownEvent(name=name, fire_at_unix=1_000_000.0,
                                quorum_required=quorum)


def test_band_rides_in_the_existing_payload_field():
    up = make_upstream()
    bc = BandedCountdown("haul", IBox.centered([1000], 100), target_width=20)
    bc.confirm("a", IBox.centered([1000], 40))
    bc.confirm("b", IBox.centered([1002], 9))
    bc.attach_to(up)
    assert "banded" in up.payload
    # Upstream's own serialiser must still round-trip the event unharmed.
    revived = swarm.CountdownEvent.from_dict(up.to_dict())
    assert revived.payload["banded"]["band"] == {"lo": [993], "hi": [1011]}
    back = BandedCountdown.from_payload("haul", revived.payload["banded"])
    assert back.band == bc.band
    assert back.ready() == bc.ready()


def test_accepted_reporters_become_upstream_confirmations():
    up = make_upstream(quorum=2)
    bc = BandedCountdown("haul", IBox.centered([1000], 100), target_width=50)
    bc.confirm("a", IBox.centered([1000], 30))
    bc.confirm("b", IBox.centered([1001], 20))
    bc.attach_to(up)
    assert up.confirmed_count() == 2
    assert up.has_quorum(), "count-based tooling still sees a quorum"
    assert bc.ready()[0], "and the band agrees"


def test_a_contradicting_reporter_defers_upstream_rather_than_confirming():
    """Upstream has no 'contradicted' concept; DEFERRED is its hold-open state."""
    up = make_upstream(quorum=2)
    bc = BandedCountdown("haul", IBox.centered([1000], 50), target_width=100)
    bc.confirm("a", IBox.centered([1000], 20))
    bc.confirm("liar", IBox.centered([9000], 1))
    bc.attach_to(up)
    assert up.confirmed_count() == 1
    assert up.deferred_count() == 1
    assert not up.has_quorum()
    assert not bc.ready()[0]


def test_upstream_tick_still_behaves_normally_underneath():
    up = make_upstream(quorum=1)
    bc = BandedCountdown("haul", IBox.centered([1000], 10), target_width=5,
                         min_reporters=1)
    bc.confirm("a", IBox.centered([1000], 2))
    bc.attach_to(up)
    assert up.tick(now_unix=0.0) == swarm.EventStatus.FIRED
    assert bc.ready()[0]


def test_the_divergence_this_exists_to_fix():
    """Upstream fires on a head-count; the band knows the reports are useless."""
    up = make_upstream(quorum=3)
    bc = BandedCountdown("haul", IBox.centered([1000], 500), target_width=10)
    # Three subscribers all confirm, but every one of them is nearly clueless.
    for who in ("a", "b", "c"):
        bc.confirm(who, IBox.centered([1000], 400))
    bc.attach_to(up)

    assert up.has_quorum(), "three confirmations: upstream is satisfied"
    assert up.tick(now_unix=0.0) == swarm.EventStatus.FIRED

    ready, why = bc.ready()
    assert not ready and why == "band_too_wide", \
        "the band is 800 wide - nobody actually knows when to fire"
    assert bc.band.max_width() == 800
