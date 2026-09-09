"""Integer zonotopes — bands that remember *why* they are uncertain.

`IBox` is interval arithmetic, so it cannot tell that two quantities share a
source: `x - x` comes out two wide instead of zero. A zonotope carries the
sources as noise symbols with integer coefficients, so shared terms cancel term
by term.

This is the Python substrate. The algebra is specified in
`build/exact-band/src/zono.rs`; this must agree with it and with the C port
byte-for-byte, which `build/CONFORMANCE-STREAM.md` checks.

Capacity is fixed at `CAP` terms. When a result would exceed it, the smallest
term is absorbed into a **fresh** symbol along with the overflow. Absorbing into
an *existing* symbol is unsound and subtly so: two forms that both dump error
into the same shared symbol will cancel it on subtraction, leaving a band that
is too **narrow** — which lets a caller conclude two values agree when they do
not. The Rust original shipped exactly that bug. Each port reproducing the
correct behaviour independently is the point of having three.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Tuple

__all__ = ["CAP", "Fixed", "Symbols", "Zono"]

#: Terms held inline. Matches EB_ZONO_CAP in the C port and the test types in Rust.
CAP = 16

INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1


def _sat(v: int) -> int:
    """Saturate to int64.

    Python integers are unbounded, so this is the one place the substrate can
    silently part company with C and Rust, which saturate for free.
    """
    if v > INT64_MAX:
        return INT64_MAX
    if v < INT64_MIN:
        return INT64_MIN
    return v


def div_nearest(n: int, d: int) -> int:
    """Round-half-away-from-zero. Symmetric: a sign flip in maps to a sign flip out.

    Python's `//` floors, which biases one direction over many steps — the bug
    this repository already fixed once in the phase-lock centre pull.
    """
    if n >= 0:
        return _sat((2 * n + d) // (2 * d))
    return _sat(-((-2 * n + d) // (2 * d)))


class Symbols:
    """Noise-symbol allocator, **namespaced by origin**.

    The namespacing is a soundness requirement, not a convenience. Two peers
    each constructing ``Symbols()`` both start at zero and both mint 1, 2, 3…
    for *unrelated* error sources. Merge their forms and the algebra sees
    matching ids, treats those unrelated errors as the same quantity, and
    **cancels them**. Measured: two forms of radius 3300 built from entirely
    independent measurements subtract to radius **0** — the library reporting
    exact agreement between peers that share nothing.

    A band too narrow is the one failure this algebra cannot tolerate, because
    it says "these agree" when they do not. Give each peer a distinct
    ``origin`` and the collision becomes impossible rather than documented.

    Ids are ``(origin << 32) | counter``: about four billion origins with four
    billion symbols each. A 16/16 split was tried first and was wrong — 65 536
    symbols per origin exhausted inside a single 200 000-iteration conformance
    run, since every inexact operation mints one. Ids are varint-encoded on the
    wire, so widening costs nothing for small values and leaves every existing
    encoding byte-identical.
    """

    __slots__ = ("origin", "counter")

    def __init__(self, origin: int = 0) -> None:
        if not 0 <= origin <= 0xFFFFFFFF:
            raise ValueError("origin must fit in 32 bits")
        self.origin = origin
        self.counter = 0

    def fresh(self) -> int:
        """Mint an id no pool with this origin has issued before.

        Raises on exhaustion rather than wrapping: wrapping would silently
        reissue a live id and reintroduce the very cancellation this exists to
        prevent.
        """
        if self.counter >= 0xFFFFFFFF:
            raise OverflowError(
                "symbol pool exhausted for this origin; wrapping would reissue a live id")
        self.counter += 1
        return (self.origin << 32) | self.counter

    def minted(self) -> int:
        return self.counter

    def advance_past(self, sid: int) -> None:
        """Never mint `sid` or below again — but only if it is ours.

        Ids from another origin cannot collide with ours by construction, so
        reacting to them would waste this origin's space for nothing.
        """
        if (sid >> 32) == self.origin:
            low = sid & 0xFFFFFFFF
            if low > self.counter:
                self.counter = low


@dataclass
class Zono:
    """An affine form over at most `CAP` noise symbols, coefficients integral.

    Denotes ``{ c + sum(x_i * e_i) : e_i in [-1, 1] }``. Terms stay sorted by
    symbol id, which is what lets `add`/`sub` pair shared symbols in one pass.
    """

    center: int = 0
    terms: List[Tuple[int, int]] = field(default_factory=list)  # (id, coeff), id-sorted
    condensations: int = 0

    # -- construction -------------------------------------------------------

    @classmethod
    def exact(cls, center: int) -> "Zono":
        return cls(center=_sat(center), terms=[], condensations=0)

    @classmethod
    def from_symbol(cls, center: int, sym: int, coeff: int) -> "Zono":
        z = cls.exact(center)
        if coeff != 0:
            z.terms = [(sym, _sat(coeff))]
        return z

    @classmethod
    def uncertain(cls, center: int, radius: int, pool: Symbols) -> "Zono":
        z = cls.exact(center)
        if radius > 0:
            z.terms = [(pool.fresh(), _sat(radius))]
        return z

    # -- inspection ---------------------------------------------------------

    def radius(self) -> int:
        """Total half-width, saturating exactly as the other two substrates do."""
        r = 0
        for _, c in self.terms:
            r = _sat(r + abs(c))
        return r

    def interval(self) -> Tuple[int, int]:
        r = self.radius()
        return (_sat(self.center - r), _sat(self.center + r))

    def is_exact(self) -> bool:
        return self.radius() == 0

    def coeff_of(self, sym: int) -> int:
        for s, c in self.terms:
            if s == sym:
                return c
        return 0

    # -- exact operations ---------------------------------------------------

    def shift(self, by: int) -> "Zono":
        return Zono(_sat(self.center + by), list(self.terms), self.condensations)

    def scale(self, k: int) -> "Zono":
        return Zono(_sat(self.center * k),
                    [(s, _sat(c * k)) for s, c in self.terms],
                    self.condensations)

    def add(self, other: "Zono", pool: Symbols) -> "Zono":
        return self._merge(other, 1, pool)

    def sub(self, other: "Zono", pool: Symbols) -> "Zono":
        return self._merge(other, -1, pool)

    def _merge(self, other: "Zono", sign: int, pool: Symbols) -> "Zono":
        out = Zono.exact(_sat(self.center + sign * other.center))
        out.condensations = self.condensations + other.condensations
        spilled = 0
        i = j = 0
        a, b = self.terms, other.terms
        while i < len(a) or j < len(b):
            if j >= len(b) or (i < len(a) and a[i][0] < b[j][0]):
                sid, c = a[i]
                i += 1
            elif i >= len(a) or b[j][0] < a[i][0]:
                sid, c = b[j][0], _sat(b[j][1] * sign)
                j += 1
            else:
                sid = a[i][0]
                c = _sat(a[i][1] + b[j][1] * sign)
                i += 1
                j += 1
            if c == 0:
                continue          # exact cancellation: the point of the module
            if len(out.terms) < CAP:
                out.terms.append((sid, c))
            else:
                spilled = _sat(spilled + abs(c))
        out._absorb_spill(spilled, pool)
        return out

    def div_round(self, d: int, pool: Symbols) -> "Zono":
        """Divide, rounding once with full remainder accounting."""
        if d <= 0:
            raise ValueError("divisor must be positive")
        q_c = div_nearest(self.center, d)
        out = Zono.exact(q_c)
        out.condensations = self.condensations
        rem = abs(self.center - q_c * d)
        for sid, c in self.terms:
            q = div_nearest(c, d)
            if q != 0 and len(out.terms) < CAP:
                out.terms.append((sid, q))
                rem = _sat(rem + abs(c - q * d))
            else:
                rem = _sat(rem + abs(c))
        out._absorb_spill((rem + d - 1) // d, pool)   # round the error UP
        return out

    # -- condensation -------------------------------------------------------

    def _absorb_spill(self, spilled: int, pool: Symbols) -> None:
        """Re-admit condensed magnitude as one FRESH, independent symbol.

        The full-capacity branch is the one that matters. Adding the spill to an
        *existing* term keeps that term's symbol id, and two forms that both do
        so cancel the error when subtracted — because cancelling shared symbols
        is exactly what subtraction is for — leaving a band too narrow. Freeing
        the slot into a fresh symbol discards correlation instead, which can
        only widen.
        """
        if spilled == 0:
            return
        self.condensations += 1
        if len(self.terms) < CAP:
            self.terms.append((pool.fresh(), spilled))
        else:
            min_i = min(range(len(self.terms)), key=lambda k: abs(self.terms[k][1]))
            absorbed = _sat(abs(self.terms[min_i][1]) + spilled)
            self.terms[min_i] = (pool.fresh(), absorbed)
        # A fresh id is the largest yet minted, so one upward pass carries it to
        # the end and restores the id ordering `_merge` depends on.
        for k in range(1, len(self.terms)):
            if self.terms[k - 1][0] > self.terms[k][0]:
                self.terms[k - 1], self.terms[k] = self.terms[k], self.terms[k - 1]


@dataclass
class Fixed:
    """A zonotope carried at a binary scale: the value is ``z / 2**shift``.

    :meth:`Zono.div_round` mints a fresh noise symbol on every call, because
    integer division genuinely loses information and affine arithmetic has no
    way to say "this error is a deterministic function of inputs I already
    track". In a loop that divides every step those charges never cancel and the
    band creeps — measurably: plain interval arithmetic beats a dividing
    zonotope outright on ring consensus.

    The fix is to stop dividing. Dividing by a power of two becomes a change of
    scale — :meth:`div_pow2` increments an exponent and touches no coefficient —
    so it is **exact and mints nothing**. Rounding happens once, at
    :meth:`rescale`, instead of once per step.
    """

    z: Zono
    shift: int = 0

    def div_pow2(self, k: int) -> "Fixed":
        """Divide by ``2**k``, exactly. No rounding, no new symbol."""
        return Fixed(self.z, self.shift + k)

    def scale(self, k: int) -> "Fixed":
        return Fixed(self.z.scale(k), self.shift)

    def _aligned(self, other: "Fixed") -> Tuple[Zono, Zono, int]:
        """Raise the smaller scale to meet the larger.

        Raising is a multiplication and therefore exact; it is lowering that
        would round, so this never rounds. Keeping magnitudes in range is the
        caller's job, via :meth:`rescale`.
        """
        s = max(self.shift, other.shift)
        a = self.z.scale(1 << (s - self.shift)) if self.shift < s else self.z
        b = other.z.scale(1 << (s - other.shift)) if other.shift < s else other.z
        return a, b, s

    def add(self, other: "Fixed", pool: Symbols) -> "Fixed":
        a, b, s = self._aligned(other)
        return Fixed(a.add(b, pool), s)

    def sub(self, other: "Fixed", pool: Symbols) -> "Fixed":
        """Exact difference — the operation that decides whether two estimates
        have converged, and the one interval arithmetic cannot answer."""
        a, b, s = self._aligned(other)
        return Fixed(a.sub(b, pool), s)

    def rescale(self, target: int, pool: Symbols) -> "Fixed":
        """Drop the scale to `target`, rounding once. The only place tightness
        is lost."""
        if target >= self.shift:
            return self
        return Fixed(self.z.div_round(1 << (self.shift - target), pool), target)

    def width_scaled(self) -> int:
        """Total width in units of ``2**-shift``."""
        return 2 * self.z.radius()

    def interval(self) -> Tuple[int, int]:
        """Rounded **outward** so it never understates."""
        r = self.z.radius()
        d = 1 << self.shift
        lo = self.z.center - r
        hi = self.z.center + r
        return (_floor_div(lo, d), _ceil_div(hi, d))


def _floor_div(n: int, d: int) -> int:
    return n // d


def _ceil_div(n: int, d: int) -> int:
    return -((-n) // d)
