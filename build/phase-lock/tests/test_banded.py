"""The band-coupling experiment — a recorded NEGATIVE result.

These tests pin a finding that did not go the way the hypothesis predicted, so
that a later change cannot quietly "fix" it without someone noticing the claim
has moved.
"""

import pathlib
import random
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from phase_lock.banded import Band, simulate_banded  # noqa: E402
from phase_lock.model import Ring, sawtooth, simulate  # noqa: E402


def _rate(fn, n_systems=60, **kw):
    hits = 0
    for seed in range(n_systems):
        random.seed(3000 + seed)
        n = random.randint(4, 10)
        om = [random.randint(-6, 6) for _ in range(n)]
        ph = [random.randrange(360) for _ in range(n)]
        hits += fn(phases=ph, omegas=om, ring=Ring(360), steps=400,
                   lock_window=50, **kw).locked
    return hits / n_systems


def test_band_narrows_on_agreement_and_widens_on_contradiction():
    ring = Ring(360)
    b = Band(centre=100, half=20)
    assert b.narrow_toward(ring, 105, step=2, max_half=90) is True
    assert b.half == 18, "agreement tightens"
    wide_before = b.half
    assert b.narrow_toward(ring, 300, step=2, max_half=90) is False
    assert b.half > wide_before, "contradiction widens -- being wrong costs confidence"


def test_band_widening_saturates_at_max():
    ring = Ring(360)
    b = Band(centre=0, half=88)
    for _ in range(20):
        b.narrow_toward(ring, 180, step=2, max_half=90)
    assert b.half == 90


def test_band_coupling_is_worse_than_plain_coupling():
    """The headline negative result.

    Hypothesis was that confidence-scaled coupling would widen the stable
    window by damping the over-coupling overshoot. It does not. Plain
    proportional coupling wins by a wide margin at every coupling strength
    tested.
    """
    plain = _rate(simulate, k_num=1, k_den=8, coupling=sawtooth)
    banded = _rate(simulate_banded, k_num=2, k_den=8)
    assert plain > 0.7, f"plain coupling should lock most systems, got {plain:.0%}"
    assert banded < plain / 2, \
        f"banded ({banded:.0%}) is expected to lose badly to plain ({plain:.0%})"


def test_starting_more_confident_makes_it_worse_not_better():
    """The over-confidence trap, measured.

    A narrow initial band resists correction, so oscillators commit hard to
    beliefs that are wrong. Less prior certainty does better.
    """
    uncertain = _rate(simulate_banded, k_num=8, k_den=8, max_half=90)
    confident = _rate(simulate_banded, k_num=8, k_den=8, max_half=5)
    assert confident < uncertain, \
        f"confident start ({confident:.0%}) should do worse than uncertain ({uncertain:.0%})"


def test_sparse_observation_does_not_rescue_it():
    """The second rescue attempt, also refuted.

    A carried estimate is supposed to earn its keep when looking is expensive.
    Here it collapses instead: the belief goes stale while confidence stays high.
    """
    dense = _rate(simulate_banded, k_num=2, k_den=8, observe_every=1, seed=0)
    sparse = _rate(simulate_banded, k_num=2, k_den=8, observe_every=8, seed=0)
    assert sparse <= dense, "sparsity should not help a filter that already lags"
    assert sparse < 0.1, f"expected near-total collapse under sparsity, got {sparse:.0%}"


def test_decay_does_not_rescue_it_either():
    """The third rescue attempt. Widening on unobserved ticks does not help.

    Recorded because `tminus-band`'s `stale_widen_per_tick` is the right fix for
    the over-confidence trap in a predict-and-confirm *event* loop -- and it is
    still not enough to make band coupling competitive in a *control* loop.
    """
    no_decay = _rate(simulate_banded, k_num=2, k_den=8, observe_every=4, seed=0,
                     stale_widen=0)
    decayed = _rate(simulate_banded, k_num=2, k_den=8, observe_every=4, seed=0,
                    stale_widen=3)
    assert decayed <= no_decay + 0.05, "decay should not materially rescue it"


def test_centre_pull_is_symmetric_about_zero():
    """Regression: Python's `//` floors, which biased the centre one way.

    A review caught `off // 4` moving a negative offset further than a positive
    one of the same size, walking the band centre in one direction over many
    ticks. The pull must be symmetric.
    """
    ring = Ring(360)
    for mag in range(1, 60):
        up = Band(centre=180, half=90)
        down = Band(centre=180, half=90)
        up.narrow_toward(ring, ring.reduce(180 + mag), step=0, max_half=90)
        down.narrow_toward(ring, ring.reduce(180 - mag), step=0, max_half=90)
        moved_up = ring.offset(180, up.centre)
        moved_down = ring.offset(180, down.centre)
        assert moved_up == -moved_down, (
            f"asymmetric pull at offset {mag}: +{moved_up} vs {moved_down}")
