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

__all__ = ["CAP", "Symbols", "Zono"]

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
    """Noise-symbol allocator. Symbol 0 is never issued, so it can mean 'none'."""

    __slots__ = ("next",)

    def __init__(self) -> None:
        self.next = 0

    def fresh(self) -> int:
        self.next += 1
        return self.next

    def minted(self) -> int:
        return self.next


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
