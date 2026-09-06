"""Discrete-time Kuramoto oscillators in exact integer arithmetic.

The usual Kuramoto model lives in floating point:

    θ_i(t+1) = θ_i(t) + ω_i + (K/N) · Σ_j sin(θ_j − θ_i)

Three things become fuzzy in that formulation, and all three are the things the
theory actually talks about:

* **Collision.** Two oscillators "collide" when they share a phase. In floats
  that is a comparison against an epsilon you chose. The phase-locking criterion
  for discrete-time Kuramoto is stated in terms of *finitely many collisions* —
  a criterion you cannot decide is not a criterion.
* **Phase-locking itself.** Locking means the phase *differences* stop changing.
  In floats they never exactly stop; you pick a threshold and a window.
* **Reproducibility.** Two implementations, or one implementation on two
  machines, drift apart.

Here phases live on `ℤ/M` — `M` equally spaced slots — so all three are exact.
A collision is `==`. Locking is "every pairwise offset is unchanged from the
previous step". Two runs with the same seed are byte-identical anywhere.

Two coupling laws are provided, and the difference between them is honest:

* :func:`sawtooth` uses the signed shortest offset directly. Fully exact, no
  table, no constants. It is a genuine and studied Kuramoto variant, but it is
  **not** sine coupling.
* :func:`sine_table` uses a fixed integer sine table, built once by exact
  rational rounding. The dynamics are then pure integer arithmetic; the table is
  an auditable constant, not a live float.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from fractions import Fraction

__all__ = ["Ring", "sawtooth", "make_sine_table", "sine_coupling", "Run", "simulate"]


class Ring:
    """The discrete circle `ℤ/M`, with an exact shortest-path metric."""

    __slots__ = ("m",)

    def __init__(self, m: int) -> None:
        if m < 2:
            raise ValueError("a circle needs at least 2 slots")
        self.m = m

    def reduce(self, x: int) -> int:
        return x % self.m

    def distance(self, a: int, b: int) -> int:
        """`min(d, M−d)`, always in `[0, M//2]`."""
        d = (a - b) % self.m
        return min(d, self.m - d)

    def offset(self, a: int, b: int) -> int:
        """Signed shortest offset from `a` to `b`, in `(−M/2, M/2]`."""
        d = (b - a) % self.m
        if d > self.m // 2:
            d -= self.m
        return d


def sawtooth(ring: Ring, a: int, b: int) -> int:
    """Piecewise-linear coupling: the signed shortest offset itself.

    Exact, table-free. Zero at coincidence and at the antipode, like sine, but
    linear in between rather than sinusoidal.
    """
    return ring.offset(a, b)


def make_sine_table(m: int, scale: int) -> tuple[int, ...]:
    """`round(scale · sin(2π k / m))` for `k in [0, m)`, by exact rounding.

    Built once from a rational approximation and then frozen: the returned table
    is an integer constant, so the simulation that uses it never touches a float.
    The table is symmetric and sums to zero, both of which are asserted by tests.
    """
    import math
    out = []
    for k in range(m):
        # Compute in float once, then round half away from zero to an integer.
        v = Fraction(round(scale * math.sin(2 * math.pi * k / m) * 10**9), 10**9)
        n, d = v.numerator, v.denominator
        q = (2 * n + d) // (2 * d) if n >= 0 else -((-2 * n + d) // (2 * d))
        out.append(q)
    # Force the exact symmetries the continuous function has.
    out[0] = 0
    if m % 2 == 0:
        out[m // 2] = 0
    return tuple(out)


def sine_coupling(table: tuple[int, ...], scale: int):
    """A coupling function reading a frozen integer sine table."""
    m = len(table)

    def couple(ring: Ring, a: int, b: int) -> int:
        return table[(b - a) % m]

    couple.scale = scale          # type: ignore[attr-defined]
    couple.table = table          # type: ignore[attr-defined]
    return couple


@dataclass
class Run:
    """What one simulation observed. Every field is an exact integer count."""

    steps: int
    locked_at: int | None
    """First step after which every pairwise offset stayed constant, or None."""
    crossings_total: int
    """Overtaking events — the discrete analogue of a continuous collision."""
    coincidences_total: int = 0
    """Pairs sharing a slot. A state, not an event; high when synchronised."""
    crossings_per_step: list[int] = field(default_factory=list)
    spread_history: list[int] = field(default_factory=list)
    """Max pairwise circular distance — an exact integer proxy for coherence."""
    final_phases: tuple[int, ...] = ()
    final_offsets: tuple[int, ...] = ()

    @property
    def locked(self) -> bool:
        return self.locked_at is not None

    @property
    def final_spread(self) -> int:
        return self.spread_history[-1] if self.spread_history else 0

    def crossings_after(self, step: int) -> int:
        """Crossings from `step` onward — the quantity the criterion bounds."""
        return sum(self.crossings_per_step[step:])

    def tail_is_crossing_free(self, tail: int = 100) -> bool:
        """Did crossings stop? The decidable form of 'finitely many'."""
        return sum(self.crossings_per_step[-tail:]) == 0


def _offsets(ring: Ring, phases: list[int]) -> tuple[int, ...]:
    """All offsets relative to oscillator 0 — the quantity that must freeze."""
    return tuple(ring.offset(phases[0], p) for p in phases[1:])


def _spread(ring: Ring, phases: list[int]) -> int:
    return max((ring.distance(a, b) for i, a in enumerate(phases)
                for b in phases[i + 1:]), default=0)


def _coincidences(phases: list[int]) -> int:
    """Pairs sharing a slot right now. Exact equality — no epsilon anywhere.

    NOTE this is a *state*, not an *event*, and it is **not** what the
    continuous-time theory means by a collision. Tightly synchronised
    oscillators on a discrete circle coincide constantly, precisely because they
    are synchronised. See :func:`_crossings`.
    """
    seen: dict[int, int] = {}
    for p in phases:
        seen[p] = seen.get(p, 0) + 1
    return sum(c * (c - 1) // 2 for c in seen.values() if c > 1)


def _crossings(ring: Ring, before: list[int], after: list[int]) -> int:
    """Pairs whose signed offset changed sign — one overtook the other.

    This is the discrete analogue of a continuous-time collision: an *event*, a
    crossing, not the state of being briefly equal. The phase-locking criterion
    is about these.
    """
    n = len(before)
    count = 0
    for i in range(n):
        for j in range(i + 1, n):
            a = ring.offset(before[i], before[j])
            b = ring.offset(after[i], after[j])
            if a != 0 and b != 0 and (a > 0) != (b > 0):
                # Ignore apparent sign flips caused by passing the antipode
                # rather than by passing each other.
                if abs(a) + abs(b) < ring.m // 2:
                    count += 1
    return count


def simulate(*, phases: list[int], omegas: list[int], ring: Ring,
             k_num: int, k_den: int, steps: int, coupling=sawtooth,
             lock_window: int = 20) -> Run:
    """Run the model. `K = k_num / k_den`, applied as exact integer arithmetic.

    The coupling increment is `(k_num · Σ coupling) // (k_den · N)` with
    round-half-away-from-zero, so the update is a single exact integer division
    and never a float.

    `locked_at` is the first step after which all pairwise offsets remained
    identical for `lock_window` consecutive steps.
    """
    n = len(phases)
    if n != len(omegas):
        raise ValueError("need one natural frequency per oscillator")
    phases = [ring.reduce(p) for p in phases]

    run = Run(steps=steps, locked_at=None, crossings_total=0)
    prev_offsets = _offsets(ring, phases)
    stable_since: int | None = None

    for t in range(steps):
        run.coincidences_total += _coincidences(phases)
        run.spread_history.append(_spread(ring, phases))
        before = list(phases)

        nxt = []
        for i in range(n):
            total = sum(coupling(ring, phases[i], phases[j])
                        for j in range(n) if j != i)
            num = k_num * total
            den = k_den * n
            # round half away from zero, exactly
            q = (2 * num + den) // (2 * den) if num >= 0 else -((-2 * num + den) // (2 * den))
            nxt.append(ring.reduce(phases[i] + omegas[i] + q))
        x = _crossings(ring, before, nxt)
        run.crossings_total += x
        run.crossings_per_step.append(x)
        phases = nxt

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
