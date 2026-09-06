/* exact_band.c -- see exact_band.h.
 *
 * Every arithmetic step here is integer. There is no <math.h>, no float or
 * double type, and no division that discards a remainder silently: the two
 * places that divide (Newton's iteration and the bisections) are proved to
 * terminate on exact integer invariants, stated inline.
 */

#include "exact_band.h"

/* ---- integer square root ------------------------------------------------ */

uint64_t eb_isqrt(uint64_t n)
{
    uint64_t x, y;
    int bits;

    if (n < 2u) {
        return n;
    }

    /* Start at 2^ceil(bits(n)/2), which is >= sqrt(n), so the iteration
     * descends monotonically and therefore terminates. */
    bits = 0;
    for (x = n; x != 0u; x >>= 1) {
        bits++;
    }
    x = (uint64_t)1 << ((bits + 1) / 2);
    /* bits <= 64, so the shift is at most 32 -- always in range. */

    for (;;) {
        y = (x + n / x) / 2u;
        if (y >= x) {
            return x;
        }
        x = y;
    }
}

uint64_t eb_isqrt_ceil(uint64_t n)
{
    uint64_t r = eb_isqrt(n);
    return (r * r == n) ? r : r + 1u;
}

/* ---- covering radius ---------------------------------------------------- */

int eb_basis_meets(uint32_t dim, uint32_t basis, uint32_t eps)
{
    uint64_t b, e;

    if (dim == 0u || dim > 3u) {
        return 0;
    }
    if (basis > EB_SCALE_MAX || eps > EB_SCALE_MAX) {
        return 0;
    }
    b = (uint64_t)basis;
    e = (uint64_t)eps;
    /* dim*b^2 <= 4*eps^2. With both operands <= 2^31-1 and dim <= 3, neither
     * side exceeds UINT64_MAX -- that is exactly what EB_SCALE_MAX buys. */
    return (uint64_t)dim * b * b <= 4u * e * e;
}

uint32_t eb_max_basis(uint32_t dim, uint32_t eps)
{
    uint32_t lo, hi, mid;

    if (!eb_basis_meets(dim, 1u, eps)) {
        return 0u;
    }
    lo = 1u;
    hi = EB_SCALE_MAX;
    if (eb_basis_meets(dim, hi, eps)) {
        return hi;   /* saturated: a wider type would say more (see header) */
    }
    /* Invariant: lo always meets, hi never does. */
    while (hi - lo > 1u) {
        mid = lo + (hi - lo) / 2u;
        if (eb_basis_meets(dim, mid, eps)) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return lo;
}

/* ---- lattices ----------------------------------------------------------- */

int eb_coord_ok(int32_t v)
{
    return v >= -EB_COORD_MAX && v <= EB_COORD_MAX;
}

/* Squared difference of two in-range coordinates. */
static uint64_t d2(int32_t a, int32_t b)
{
    int64_t d = (int64_t)a - (int64_t)b;
    if (d < 0) {
        d = -d;
    }
    return (uint64_t)d * (uint64_t)d;
}

uint64_t eb_dist_sq_z1(int32_t a, int32_t b)
{
    return d2(a, b);
}

uint64_t eb_dist_sq_z2(int32_t ax, int32_t ay, int32_t bx, int32_t by)
{
    return d2(ax, bx) + d2(ay, by);
}

uint64_t eb_dist_sq_hex(int32_t aa, int32_t ab, int32_t ba, int32_t bb)
{
    int64_t a = (int64_t)aa - (int64_t)ba;
    int64_t b = (int64_t)ab - (int64_t)bb;
    /* a^2 - ab + b^2 is a positive-definite quadratic form -- the Eisenstein
     * norm -- so the result is never negative, but the middle term can be, and
     * signed overflow is undefined. Both differences are bounded by 2*
     * EB_COORD_MAX, so each product is at most (2C)^2 and the three-term sum is
     * at most 3*(2C)^2 <= UINT64_MAX. Regroup as a*(a-b) + b*b, which needs no
     * intermediate wider than that bound. */
    return (uint64_t)(a * (a - b)) + (uint64_t)(b * b);
}

/* ---- Banded ------------------------------------------------------------- */

int eb_banded_certain(eb_banded_t b)
{
    return b.radius == 0u;
}

int eb_banded_contains(eb_banded_t b, int32_t point)
{
    uint64_t r = (uint64_t)b.radius;
    return eb_dist_sq_z1(b.value, point) <= r * r;
}

int eb_banded_overlaps(eb_banded_t a, eb_banded_t b)
{
    uint64_t reach = (uint64_t)a.radius + (uint64_t)b.radius;
    return eb_dist_sq_z1(a.value, b.value) <= reach * reach;
}

int eb_banded_within(eb_banded_t a, eb_banded_t b)
{
    uint64_t slack;
    if (a.radius > b.radius) {
        return 0;
    }
    slack = (uint64_t)(b.radius - a.radius);
    return eb_dist_sq_z1(a.value, b.value) <= slack * slack;
}

eb_banded_t eb_banded_widen(eb_banded_t b, uint32_t extra)
{
    uint64_t r = (uint64_t)b.radius + (uint64_t)extra;
    b.radius = (r > (uint64_t)EB_RADIUS_MAX) ? EB_RADIUS_MAX : (uint32_t)r;
    return b;
}

eb_narrowed_t eb_banded_narrow(eb_banded_t self, eb_banded_t obs)
{
    eb_narrowed_t out;
    uint64_t gap_sq = eb_dist_sq_z1(self.value, obs.value);
    uint64_t reach  = (uint64_t)self.radius + (uint64_t)obs.radius;

    if (gap_sq > reach * reach) {
        out.kind   = EB_CONTRADICTION;
        out.gap_sq = gap_sq;
        out.band   = self;   /* unused; set so the struct is fully initialised */
        return out;
    }
    out.kind   = EB_TIGHTENED;
    out.gap_sq = 0u;
    /* Balls are not closed under intersection, so the tighter INPUT is the
     * tightest sound answer available. Ties keep `self`, matching Rust. */
    out.band   = (obs.radius < self.radius) ? obs : self;
    return out;
}

uint64_t eb_narrowed_gap(eb_narrowed_t n)
{
    return (n.kind == EB_CONTRADICTION) ? eb_isqrt_ceil(n.gap_sq) : 0u;
}

/* ---- IBox --------------------------------------------------------------- */

int eb_ibox_empty(eb_ibox_t b)
{
    return b.lo > b.hi;
}

int eb_ibox_certain(eb_ibox_t b)
{
    return b.lo == b.hi;
}

int eb_ibox_contains(eb_ibox_t b, int64_t p)
{
    return b.lo <= p && p <= b.hi;
}

int eb_ibox_narrow(eb_ibox_t a, eb_ibox_t b, eb_ibox_t *out)
{
    eb_ibox_t r;
    r.lo = (a.lo > b.lo) ? a.lo : b.lo;
    r.hi = (a.hi < b.hi) ? a.hi : b.hi;
    if (r.lo > r.hi) {
        return 0;
    }
    if (out != 0) {
        *out = r;
    }
    return 1;
}

uint64_t eb_ibox_disagreement(eb_ibox_t a, eb_ibox_t b)
{
    int64_t lo = (a.lo > b.lo) ? a.lo : b.lo;
    int64_t hi = (a.hi < b.hi) ? a.hi : b.hi;
    if (lo <= hi) {
        return 0u;
    }
    /* lo - hi can exceed INT64_MAX, but never UINT64_MAX, and unsigned
     * subtraction is defined modulo 2^64 -- which is the exact answer here. */
    return (uint64_t)lo - (uint64_t)hi;
}

/* ---- Phase -------------------------------------------------------------- */

uint32_t eb_phase_new(uint32_t n, int64_t slot)
{
    int64_t r;
    if (n == 0u) {
        return 0u;
    }
    r = slot % (int64_t)n;
    if (r < 0) {
        r += (int64_t)n;
    }
    return (uint32_t)r;
}

uint32_t eb_phase_distance(uint32_t n, int64_t a, int64_t b)
{
    uint32_t sa, sb, d, around;

    if (n == 0u) {
        return 0u;
    }
    sa = eb_phase_new(n, a);
    sb = eb_phase_new(n, b);
    d  = (sa > sb) ? sa - sb : sb - sa;
    around = n - d;
    return (d < around) ? d : around;
}

int64_t eb_phase_offset(uint32_t n, int64_t a, int64_t b)
{
    int64_t nn, d;

    if (n == 0u) {
        return 0;
    }
    nn = (int64_t)n;
    d = (int64_t)eb_phase_new(n, b) - (int64_t)eb_phase_new(n, a);
    if (d < 0) {
        d += nn;
    }
    /* `2*d > n`, NOT `d > n/2`: integer division truncates, and on an odd
     * circle that rounds the half-way point down and flips offsets that were
     * already shortest. `d` is in [0, n) and n <= UINT32_MAX, so `2*d` cannot
     * overflow int64. */
    if (2 * d > nn) {
        d -= nn;
    }
    return d;
}
