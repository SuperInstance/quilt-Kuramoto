"""Band-coupled oscillators: predict, confirm, narrow, then commit.

Plain Kuramoto couples with a fixed gain `K`. Every oscillator steps by the same
fraction of its neighbours' pull whether it has good information or bad. That is
what breaks at high coupling: the map overshoots, and locking collapses.

Here each oscillator carries a **band** — an arc on `ℤ/M` recording where it
believes the ensemble is, plus how sure it is. Each step it observes some
neighbours, **narrows** the band by intersection when they agree and **widens**
it when they contradict, then steps toward the band's centre *scaled by its own
confidence*. Wide band, small step. Narrow band, commit.

The hypothesis this tests: adaptive confidence should widen the stable coupling
window, because an over-coupled oscillator with a wide band no longer takes a
full-size step into the overshoot.

Everything is integer. The band is an arc `(centre, half_width)` on the ring;
confidence is the integer ratio `(max_half − half) / max_half`.
"""

from __future__ import annotations

import random as _random
from dataclasses import dataclass, field

from .model import Ring, Run, _coincidences, _crossings, _offsets, _spread

__all__ = ["Band", "simulate_banded"]


@dataclass
class Band:
    """An arc on the ring: a centre and a half-width, both in slots."""

    centre: int
    half: int

    def contains(self, ring: Ring, slot: int) -> bool:
        return ring.distance(self.centre, slot) <= self.half

    def narrow_toward(self, ring: Ring, slot: int, step: int, max_half: int) -> bool:
        """Fold one observation in. Returns True if it agreed.

        Agreement pulls the centre a little and tightens the arc. Disagreement
        widens it — the honest response to being wrong is to become less sure,
        not to ignore the evidence.
        """
        if self.contains(ring, slot):
            off = ring.offset(self.centre, slot)
            # Move the centre a fraction of the way, TRUNCATING toward zero.
            # Python's `//` floors, which biases negative offsets downward and
            # would walk the centre in one direction over many ticks. The sign
            # must be carried out and back, exactly as in the render path.
            step_ = off // 4 if off >= 0 else -((-off) // 4)
            self.centre = ring.reduce(self.centre + step_)
            self.half = max(0, self.half - step)
            return True
        self.half = min(max_half, self.half + 2 * step)
        return False


def simulate_banded(*, phases: list[int], omegas: list[int], ring: Ring,
                    k_num: int, k_den: int, steps: int,
                    max_half: int | None = None, narrow_step: int = 1,
                    lock_window: int = 50, observe_every: int = 1,
                    observe_k: int | None = None, seed: int = 0,
                    stale_widen: int = 0) -> Run:
    """Kuramoto with confidence-scaled coupling.

    Identical bookkeeping to :func:`~phase_lock.model.simulate` so the two are
    directly comparable: same crossing counter, same lock test, same `Run`.
    """
    n = len(phases)
    if n != len(omegas):
        raise ValueError("need one natural frequency per oscillator")
    if max_half is None:
        max_half = ring.m // 4
    phases = [ring.reduce(p) for p in phases]
    bands = [Band(centre=p, half=max_half) for p in phases]
    rng = _random.Random(seed)

    run = Run(steps=steps, locked_at=None, crossings_total=0)
    prev_offsets = _offsets(ring, phases)
    stable_since: int | None = None

    for t in range(steps):
        run.coincidences_total += _coincidences(phases)
        run.spread_history.append(_spread(ring, phases))
        before = list(phases)

        nxt = []
        for i in range(n):
            # Observe some neighbours; agreement tightens, contradiction widens.
            # `observe_every` and `observe_k` make observation SPARSE, which is
            # the regime a carried estimate is supposed to earn its keep in.
            if t % observe_every != 0 and stale_widen:
                # Nothing was observed this tick, so the belief is staler than
                # it was. Forgetting at a fixed integer rate is the least
                # machinery that keeps confidence honest.
                bands[i].half = min(max_half, bands[i].half + stale_widen)
            if t % observe_every == 0:
                others = [j for j in range(n) if j != i]
                if observe_k is not None and observe_k < len(others):
                    rng.shuffle(others)
                    others = others[:observe_k]
                for j in others:
                    bands[i].narrow_toward(ring, phases[j], narrow_step, max_half)

            # Confidence is the integer complement of the band's width.
            conf_num = max_half - bands[i].half
            conf_den = max_half if max_half else 1

            pull = ring.offset(phases[i], bands[i].centre)
            num = k_num * pull * conf_num
            den = k_den * conf_den
            q = (2 * num + den) // (2 * den) if num >= 0 else -((-2 * num + den) // (2 * den))
            nxt.append(ring.reduce(phases[i] + omegas[i] + q))

        x = _crossings(ring, before, nxt)
        run.crossings_total += x
        run.crossings_per_step.append(x)
        phases = nxt
        for i in range(n):
            bands[i].centre = ring.reduce(bands[i].centre + omegas[i])

        offs = _offsets(ring, phases)
        if offs == prev_offsets:
            if stable_since is None:
                stable_since = t
            elif run.locked_at is None and t - stable_since >= lock_window:
                run.locked_at = stable_since
        else:
            stable_since = None
        prev_offsets = offs

    run.final_phases = tuple(phases)
    run.final_offsets = prev_offsets
    return run
