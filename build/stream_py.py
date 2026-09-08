#!/usr/bin/env python3
"""The conformance stream, Python substrate.

See CONFORMANCE-STREAM.md for the specification. Lives at `build/` level rather
than inside one project because it spans two: the band algebra is `tminus-band`
and the discrete circle is `phase-lock`. That is the same reason `vectors.json`
is shared rather than owned.

Usage: python3 stream_py.py [iterations]
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "tminus-band"))
sys.path.insert(0, str(HERE / "phase-lock"))

from tminus_band.band import (  # noqa: E402
    Banded, Contradiction, IBox, basis_meets, dist_sq_hex, dist_sq_z1,
    dist_sq_z2, dist_sq_z3, isqrt_ceil, isqrt_floor, max_basis,
)
from tminus_band.zono import Symbols as ZSymbols, Zono  # noqa: E402
from phase_lock.model import Ring  # noqa: E402

MASK = (1 << 64) - 1
SEED = 0x2545F4914F6CDD1D
H0 = 0xCBF29CE484222325
FNV_P = 0x100000001B3

SCALES = (16, 1024, 1000000, 1239850262)
RINGS = (2, 3, 5, 7, 12, 360, 361, 1000)
R_MAX = 1073741823


class Rng:
    """xorshift64.

    Python integers are unbounded, so every step must be masked back to 64 bits
    explicitly — the one place this substrate can silently part company with the
    other two, since C and Rust wrap for free.
    """

    __slots__ = ("state",)

    def __init__(self, seed: int) -> None:
        self.state = seed

    def next(self) -> int:
        x = self.state
        x ^= (x << 13) & MASK
        x ^= x >> 7          # Python's >> on a non-negative int is logical
        x ^= (x << 17) & MASK
        self.state = x
        return x

    def coord(self, scale: int) -> int:
        span = 2 * scale + 1
        return self.next() % span - scale


def mix(h: int, v: int) -> int:
    """Fold one answer in. `v` must already be the unsigned 64-bit bit pattern."""
    return ((h ^ v) * FNV_P) & MASK


def bits(v: int) -> int:
    """Two's-complement bit pattern of a signed value, as an unsigned 64-bit int.

    Never a decimal rendering: a checksum that depended on formatting would
    diverge between substrates for reasons unrelated to the arithmetic.
    """
    return v & MASK


def from_basis_radius(basis: int, dim: int) -> int:
    return Banded.from_basis((0,) * dim, basis, dim).radius


def step(rng: Rng, h: int) -> int:
    # 1. isqrt over the whole 64-bit range.
    n = rng.next()
    h = mix(h, isqrt_floor(n))
    h = mix(h, isqrt_ceil(n))

    # 2. covering.
    dim = 1 + rng.next() % 3
    basis = rng.next() % 100000
    eps = rng.next() % 100000
    h = mix(h, 1 if basis_meets(dim, basis, eps) else 0)
    h = mix(h, max_basis(dim, eps))

    # 3. lattices, at a scale drawn per iteration.
    scale = SCALES[rng.next() % 4]
    ax, ay, az = rng.coord(scale), rng.coord(scale), rng.coord(scale)
    bx, by, bz = rng.coord(scale), rng.coord(scale), rng.coord(scale)
    h = mix(h, dist_sq_z1(ax, bx))
    h = mix(h, dist_sq_z2((ax, ay), (bx, by)))
    h = mix(h, dist_sq_z3((ax, ay, az), (bx, by, bz)))
    h = mix(h, dist_sq_hex((ax, ay), (bx, by)))

    # 4. bands, with radii on the same scale.
    r1 = min(rng.next() % (scale + 1), R_MAX)
    r2 = min(rng.next() % (scale + 1), R_MAX)
    ba, bb = Banded((ax,), r1), Banded((bx,), r2)
    h = mix(h, 1 if ba.overlaps(bb) else 0)
    h = mix(h, 1 if ba.within(bb) else 0)
    h = mix(h, 1 if bb.within(ba) else 0)
    res = ba.narrow(bb)
    if isinstance(res, Contradiction):
        h = mix(h, 1)
        h = mix(h, res.gap_sq)
    else:
        h = mix(h, 0)
        h = mix(h, bits(res.band.value[0]))
        h = mix(h, res.band.radius)

    # 5. from_basis, at all three dimensions.
    basis2 = rng.next() % 65536
    for d in (1, 2, 3):
        h = mix(h, from_basis_radius(basis2, d))

    # 6. two-axis boxes, bounds sorted so every input is inhabited.
    lo_a, hi_a, lo_b, hi_b = [], [], [], []
    for _ in range(2):
        p, q = rng.coord(scale), rng.coord(scale)
        lo_a.append(min(p, q))
        hi_a.append(max(p, q))
        p, q = rng.coord(scale), rng.coord(scale)
        lo_b.append(min(p, q))
        hi_b.append(max(p, q))
    box_a = IBox(tuple(lo_a), tuple(hi_a))
    box_b = IBox(tuple(lo_b), tuple(hi_b))
    narrowed = box_a.narrow(box_b)
    if narrowed is not None:
        h = mix(h, 1)
        for k in range(2):
            h = mix(h, bits(narrowed.lo[k]))
            h = mix(h, bits(narrowed.hi[k]))
    else:
        h = mix(h, 0)
        axis, gap = box_a.disagreement(box_b)
        h = mix(h, axis)
        h = mix(h, gap)

    # 7. phase, on odd and even rings alike.
    ring = Ring(RINGS[rng.next() % 8])
    pa = rng.next()
    pb = rng.next()
    # The generator yields unsigned; the specification says these are used as
    # signed 64-bit slot values, so reinterpret rather than reduce.
    pa = pa - (1 << 64) if pa >> 63 else pa
    pb = pb - (1 << 64) if pb >> 63 else pb
    h = mix(h, ring.distance(pa, pb))
    h = mix(h, bits(ring.offset(pa, pb)))

    return h


def run(iters: int) -> int:
    rng = Rng(SEED)
    h = H0
    for _ in range(iters):
        h = step(rng, h)
    return h


SHARED = 4


def run_zono(iters: int) -> int:
    """The zonotope conformance stream. See CONFORMANCE-STREAM.md.

    Separate from the main stream so that stream's committed checksums stay a
    stable record. One accumulator is carried across iterations over a small set
    of SHARED symbols plus fresh ones, so condensation actually happens -- which
    is the whole reason this section exists. The internal term list is folded in,
    not just the interval, because two substrates that condense differently can
    still agree on a width by coincidence.
    """
    rng = Rng(SEED)
    pool = ZSymbols()
    shared = [pool.fresh() for _ in range(SHARED)]
    acc = Zono.exact(0)
    h = H0

    for _ in range(iters):
        scale = SCALES[rng.next() % 4]
        op = rng.next() % 5
        pick = rng.next() % SHARED
        clamped = 1024 if scale > 1024 else scale
        coeff = rng.coord(clamped)
        cen = rng.coord(clamped)

        if op == 0:
            acc = acc.add(Zono.from_symbol(cen, shared[pick], coeff), pool)
        elif op == 1:
            acc = acc.sub(Zono.from_symbol(cen, shared[pick], coeff), pool)
        elif op == 2:
            # A fresh, independent source -- this is what fills the capacity.
            acc = acc.add(Zono.uncertain(cen, abs(coeff), pool), pool)
        elif op == 3:
            acc = acc.scale(1 + rng.next() % 3)
        else:
            acc = acc.div_round(1 + rng.next() % 7, pool)

        # Keep magnitudes bounded identically in every substrate, so none of
        # them reaches its saturation edge and they cannot diverge there.
        if acc.radius() > 1000000:
            acc = acc.div_round(16, pool)

        h = mix(h, bits(acc.center))
        h = mix(h, bits(acc.radius()))
        h = mix(h, len(acc.terms))
        h = mix(h, acc.condensations)
        for sid, c in acc.terms:
            h = mix(h, sid)
            h = mix(h, bits(c))
    return h


if __name__ == "__main__":
    args = sys.argv[1:]
    zono = "--zono" in args
    nums = [a for a in args if not a.startswith("--")]
    n = int(nums[0]) if nums else (50000 if zono else 200000)
    if zono:
        print(f"iterations={n} zono_checksum={run_zono(n):016x}")
    else:
        print(f"iterations={n} checksum={run(n):016x}")
