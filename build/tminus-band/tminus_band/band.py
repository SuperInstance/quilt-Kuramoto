"""Exact integer bands — the Python substrate of `exact-band`.

Stdlib only, matching `swarm-tminus`'s doctrine. Integers all the way down: no
`float`, no `math.sqrt`, no rounding. Python's arbitrary-precision integers make
the exactness free here — the discipline is about never *introducing* a float,
not about width.

This is a port, not an independent design. It is held to the Rust crate by
`tests/vectors.json`, 240 golden vectors emitted by
`exact-band/examples/emit_vectors.rs`. If the two ever disagree, one is wrong.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Sequence

__all__ = ["isqrt_floor", "isqrt_ceil", "basis_meets", "max_basis", "IBox", "Banded",
           "Tightened", "Contradiction"]


# --------------------------------------------------------------------------
# integer square root
# --------------------------------------------------------------------------

def isqrt_floor(n: int) -> int:
    """Exact floor of the square root. The unique r with r**2 <= n < (r+1)**2."""
    if n < 0:
        raise ValueError("isqrt of a negative number")
    if n < 2:
        return n
    x = 1 << ((n.bit_length() + 1) // 2)
    while True:
        y = (x + n // x) // 2
        if y >= x:
            return x
        x = y


def isqrt_ceil(n: int) -> int:
    """Exact ceiling of the square root. Rounds up, so a band never understates."""
    r = isqrt_floor(n)
    return r if r * r == n else r + 1


# --------------------------------------------------------------------------
# covering radius: choosing a basis from a tolerance, no roots
# --------------------------------------------------------------------------

def basis_meets(dim: int, basis: int, eps: int) -> bool:
    """Does basis `b` on a `dim`-dimensional lattice meet tolerance `eps`?

    The covering radius of `b*Z**n` is exactly `b*sqrt(n)/2`, so the condition
    `b*sqrt(n)/2 <= eps` squares to the exact integer test `n*b**2 <= 4*eps**2`.
    """
    return dim * basis * basis <= 4 * eps * eps


def max_basis(dim: int, eps: int) -> int:
    """Largest basis still meeting `eps`. Integer bisection, never a root."""
    if not basis_meets(dim, 1, eps):
        return 0
    lo, hi = 1, 1
    while basis_meets(dim, hi, eps):
        hi *= 2
    while hi - lo > 1:
        mid = lo + (hi - lo) // 2
        if basis_meets(dim, mid, eps):
            lo = mid
        else:
            hi = mid
    return lo


# --------------------------------------------------------------------------
# IBox — the band that genuinely narrows
# --------------------------------------------------------------------------

@dataclass(frozen=True)
class IBox:
    """An axis-aligned box on Z**n, inclusive on both bounds.

    Boxes are closed under intersection, so `narrow` is *exact* rather than an
    over-approximation, and the empty case is the contradiction test itself.
    """

    lo: tuple[int, ...]
    hi: tuple[int, ...]

    def __post_init__(self) -> None:
        if len(self.lo) != len(self.hi):
            raise ValueError("lo and hi must have the same dimension")

    @classmethod
    def point(cls, p: Sequence[int]) -> "IBox":
        """A value known exactly."""
        t = tuple(p)
        return cls(t, t)

    @classmethod
    def centered(cls, centre: Sequence[int], radius: int) -> "IBox":
        """A centre with a uniform integer half-width."""
        if radius < 0:
            raise ValueError("radius must be non-negative")
        return cls(tuple(c - radius for c in centre), tuple(c + radius for c in centre))

    @property
    def dim(self) -> int:
        return len(self.lo)

    def is_empty(self) -> bool:
        """Empty means contradictory."""
        return any(l > h for l, h in zip(self.lo, self.hi))

    def certain(self) -> bool:
        """Every bound tight: the value is known."""
        return not self.is_empty() and all(l == h for l, h in zip(self.lo, self.hi))

    def contains(self, p: Sequence[int]) -> bool:
        return all(l <= x <= h for l, x, h in zip(self.lo, p, self.hi))

    def width(self, axis: int = 0) -> Optional[int]:
        """Width along one axis, or None if empty there."""
        if self.lo[axis] > self.hi[axis]:
            return None
        return self.hi[axis] - self.lo[axis]

    def max_width(self) -> Optional[int]:
        """The widest axis — how much is still unknown, overall."""
        if self.is_empty():
            return None
        return max(h - l for l, h in zip(self.lo, self.hi))

    def narrow(self, other: "IBox") -> Optional["IBox"]:
        """Exact intersection. `None` means the two disagree."""
        lo = tuple(max(a, b) for a, b in zip(self.lo, other.lo))
        hi = tuple(min(a, b) for a, b in zip(self.hi, other.hi))
        if any(l > h for l, h in zip(lo, hi)):
            return None
        return IBox(lo, hi)

    def disagreement(self, other: "IBox") -> Optional[tuple[int, int]]:
        """Which axis disagrees and by how much, or None if they intersect."""
        worst: Optional[tuple[int, int]] = None
        for i in range(self.dim):
            lo = max(self.lo[i], other.lo[i])
            hi = min(self.hi[i], other.hi[i])
            if lo > hi:
                gap = lo - hi
                if worst is None or gap > worst[1]:
                    worst = (i, gap)
        return worst

    def widen(self, extra: int) -> "IBox":
        """Grow every bound outward. The inverse of confidence."""
        return IBox(tuple(l - extra for l in self.lo), tuple(h + extra for h in self.hi))

    def __add__(self, other: "IBox") -> "IBox":
        """Minkowski sum. Sound but not tight: correlated paths add twice."""
        return IBox(tuple(a + b for a, b in zip(self.lo, other.lo)),
                    tuple(a + b for a, b in zip(self.hi, other.hi)))


# --------------------------------------------------------------------------
# Banded — the Euclidean-ball form, matching the quilt-verilog snap judge
# --------------------------------------------------------------------------

@dataclass(frozen=True)
class Tightened:
    """The bands agreed; `band` is a sound enclosure of their intersection."""
    band: "Banded"


@dataclass(frozen=True)
class Contradiction:
    """The bands were disjoint, by this much. Information, not failure."""
    gap_sq: int

    @property
    def gap(self) -> int:
        """Exact magnitude, rounded up so it never understates."""
        return isqrt_ceil(self.gap_sq)


@dataclass(frozen=True)
class Banded:
    """An exact centre with an integer radius, stored linearly.

    Comparisons square on demand: `||c1-c2||**2 <= (r1+r2)**2`. Squaring an
    integer is exact; it is rooting that is lossy, which is why the radius is
    never stored squared.
    """

    value: tuple[int, ...]
    radius: int

    def certain(self) -> bool:
        return self.radius == 0

    def _dist_sq(self, other: "Banded") -> int:
        return sum((a - b) ** 2 for a, b in zip(self.value, other.value))

    def contains(self, p: Sequence[int]) -> bool:
        d = sum((a - b) ** 2 for a, b in zip(self.value, p))
        return d <= self.radius * self.radius

    def overlaps(self, other: "Banded") -> bool:
        reach = self.radius + other.radius
        return self._dist_sq(other) <= reach * reach

    def narrow(self, obs: "Banded"):
        """Ball narrowing.

        Balls are not closed under intersection, so this returns whichever input
        is tighter — always a valid superset of the true intersection, never an
        invented centre. Use `IBox` when you need exact narrowing.
        """
        gap_sq = self._dist_sq(obs)
        reach = self.radius + obs.radius
        if gap_sq > reach * reach:
            return Contradiction(gap_sq)
        return Tightened(obs if obs.radius < self.radius else self)

    def within(self, other: "Banded") -> bool:
        """Does this band lie wholly inside `other`?

        Exactly `||c1-c2|| + r1 <= r2`, rearranged to avoid a root: false unless
        `r1 <= r2`, then `||c1-c2||**2 <= (r2-r1)**2`. The `r1 <= r2` test comes
        first because it is what makes the subtraction meaningful -- reversing
        the two is the subtle way to get this wrong, which is why the shared
        vectors record both directions of every pair.
        """
        if self.radius > other.radius:
            return False
        slack = other.radius - self.radius
        return self._dist_sq(other) <= slack * slack

    def widen(self, extra: int) -> "Banded":
        return Banded(self.value, self.radius + extra)

    @classmethod
    def from_basis(cls, value: Sequence[int], basis: int, dim: int) -> "Banded":
        """The band a lattice of the given basis induces, in `dim` dimensions.

        The covering radius `b*sqrt(n)/2` is irrational in general, so this is
        the smallest INTEGER radius that still covers it -- the smallest `r` with
        `4r**2 >= n*b**2`, found by bisection, never by `sqrt`.

        Rounding up is the whole point: a band that rounded down would understate
        the uncertainty it exists to represent.
        """
        target_x4 = dim * basis * basis
        lo, hi = 0, max(1, basis) * max(1, dim)
        while 4 * hi * hi < target_x4:
            hi *= 2
        while lo < hi:
            mid = (lo + hi) // 2
            if 4 * mid * mid >= target_x4:
                hi = mid
            else:
                lo = mid + 1
        return cls(tuple(value), lo)
