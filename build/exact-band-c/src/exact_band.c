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

int eb_coord_ok_dim(int32_t v, uint32_t dim)
{
    int32_t lim;
    switch (dim) {
    case 1u: lim = EB_COORD_MAX_Z1; break;
    case 2u: lim = EB_COORD_MAX_Z2; break;
    case 3u: lim = EB_COORD_MAX_Z3; break;
    default: return 0;
    }
    /* -INT32_MIN is not representable, so compare against the limit's negation
     * only when it is not INT32_MAX -- at dim 1 the whole range is allowed. */
    if (lim == EB_COORD_MAX_Z1) {
        return 1;
    }
    return v >= -lim && v <= lim;
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

uint64_t eb_dist_sq_z3(const int32_t a[3], const int32_t b[3])
{
    return d2(a[0], b[0]) + d2(a[1], b[1]) + d2(a[2], b[2]);
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

eb_banded_t eb_banded_from_basis(int32_t value, uint32_t basis, uint32_t dim)
{
    eb_banded_t out;
    uint64_t target_x4;
    uint64_t lo, hi, mid;

    out.value = value;
    out.radius = 0u;
    if (dim == 0u || dim > 3u || basis == 0u) {
        return out;   /* a zero basis induces no uncertainty */
    }
    if (basis > EB_SCALE_MAX) {
        return out;   /* out of range: rejected, not wrapped */
    }
    target_x4 = (uint64_t)dim * basis * basis;

    /* Smallest r with 4*r^2 >= dim*b^2. Bisect on an interval known to contain
     * it: r <= dim*basis, because 4*(dim*b)^2 = 4*dim^2*b^2 >= dim*b^2 for any
     * dim >= 1. Never a square root. */
    lo = 0u;
    hi = (uint64_t)dim * basis;
    while (lo < hi) {
        mid = lo + (hi - lo) / 2u;
        if (4u * mid * mid >= target_x4) {
            hi = mid;
        } else {
            lo = mid + 1u;
        }
    }
    out.radius = (uint32_t)lo;
    return out;
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

int eb_ibox_narrow_n(const eb_ibox_t *a, const eb_ibox_t *b, uint32_t n,
                     eb_ibox_t *out)
{
    uint32_t i;
    /* Two passes: the disjointness test must complete before anything is
     * written, or a NULL result would leave `out` half-updated when `out`
     * aliases an input. */
    for (i = 0; i < n; i++) {
        int64_t lo = (a[i].lo > b[i].lo) ? a[i].lo : b[i].lo;
        int64_t hi = (a[i].hi < b[i].hi) ? a[i].hi : b[i].hi;
        if (lo > hi) {
            return 0;
        }
    }
    if (out != 0) {
        for (i = 0; i < n; i++) {
            int64_t lo = (a[i].lo > b[i].lo) ? a[i].lo : b[i].lo;
            int64_t hi = (a[i].hi < b[i].hi) ? a[i].hi : b[i].hi;
            out[i].lo = lo;
            out[i].hi = hi;
        }
    }
    return 1;
}

int eb_ibox_disagreement_n(const eb_ibox_t *a, const eb_ibox_t *b, uint32_t n,
                           uint32_t *axis, uint64_t *gap)
{
    uint32_t i, worst_axis = 0u;
    uint64_t worst_gap = 0u;
    int found = 0;

    for (i = 0; i < n; i++) {
        uint64_t g = eb_ibox_disagreement(a[i], b[i]);
        /* Strictly greater, so the FIRST axis wins a tie -- matching the Rust
         * original, which a later-wins comparison would silently diverge from
         * on any pair with equal gaps. */
        if (g > 0u && (!found || g > worst_gap)) {
            worst_gap = g;
            worst_axis = i;
            found = 1;
        }
    }
    if (found) {
        if (axis != 0) { *axis = worst_axis; }
        if (gap != 0)  { *gap = worst_gap; }
    }
    return found;
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

/* ---- Zonotopes ----------------------------------------------------------- */

/* Round-half-away-from-zero. Symmetric, so a sign flip in the input produces a
 * sign flip in the output. A floor would bias one direction over many steps --
 * the bug this repository already fixed once in the phase-lock centre pull. */
int64_t eb_div_nearest(int64_t n, int64_t d)
{
    int64_t q = n / d;
    int64_t r = n % d;      /* C99: same sign as n, and |r| < |d| */

    /* Round half away from zero WITHOUT doubling anything.
     *
     * The obvious form, `(2*n + d) / (2*d)`, overflows for |n| beyond
     * i64::MAX/2 -- and signed overflow in C is undefined, not merely
     * wrapping. Compiled with gcc -O2 it returned 0 for n = i64::MAX and the
     * WRONG SIGN for n = 2^62, where the Rust port (which widens to i128)
     * returned the right answers. UBSan names it exactly:
     *
     *   signed integer overflow: 9223372036854775807 * 2 cannot be
     *   represented in type 'long int'
     *
     * A bounded SMT equivalence check found this; the million-case
     * conformance stream never could, because its inputs are bounded well
     * inside the safe range. See ../smt-equivalence/.
     *
     * Comparing `|r| >= d - |r|` instead of `2*|r| >= d` is the same test with
     * no doubling: both sides are non-negative and below d, so neither can
     * overflow. */
    if (r > 0) {
        if (r >= d - r) { q += 1; }
    } else if (r < 0) {
        int64_t ar = -r;    /* safe: |r| < |d| <= INT64_MAX, so never INT64_MIN */
        if (ar >= d - ar) { q -= 1; }
    }
    return q;
}


void eb_symbols_init(eb_symbols_t *p) { p->next = 0u; }

uint32_t eb_symbols_fresh(eb_symbols_t *p)
{
    p->next += 1u;
    return p->next;
}

void eb_zono_exact(eb_zono_t *z, int64_t center)
{
    z->center = center;
    z->len = 0u;
    z->condensations = 0u;
}

void eb_zono_from_symbol(eb_zono_t *z, int64_t center, uint32_t sym, int64_t coeff)
{
    eb_zono_exact(z, center);
    if (coeff != 0) {
        z->ids[0] = sym;
        z->coeffs[0] = coeff;
        z->len = 1u;
    }
}

void eb_zono_uncertain(eb_zono_t *z, int64_t center, uint32_t radius,
                       eb_symbols_t *pool)
{
    eb_zono_exact(z, center);
    if (radius > 0u) {
        z->ids[0] = eb_symbols_fresh(pool);
        z->coeffs[0] = (int64_t)radius;
        z->len = 1u;
    }
}

static int64_t sat_add(int64_t a, int64_t b)
{
    if (b > 0 && a > INT64_MAX - b) { return INT64_MAX; }
    if (b < 0 && a < INT64_MIN - b) { return INT64_MIN; }
    return a + b;
}

static int64_t sat_mul(int64_t a, int64_t b)
{
    if (a == 0 || b == 0) { return 0; }
    if (a > 0) {
        if (b > 0) { if (a > INT64_MAX / b) { return INT64_MAX; } }
        else       { if (b < INT64_MIN / a) { return INT64_MIN; } }
    } else {
        if (b > 0) { if (a < INT64_MIN / b) { return INT64_MIN; } }
        else       { if (a < INT64_MAX / b) { return INT64_MAX; } }
    }
    return a * b;
}

static int64_t sat_neg(int64_t a) { return (a == INT64_MIN) ? INT64_MAX : -a; }
static int64_t iabs64(int64_t a)  { return (a < 0) ? sat_neg(a) : a; }

int64_t eb_zono_radius(const eb_zono_t *z)
{
    int64_t r = 0;
    uint32_t i;
    for (i = 0u; i < z->len; i++) {
        r = sat_add(r, iabs64(z->coeffs[i]));
    }
    return r;
}

void eb_zono_interval(const eb_zono_t *z, int64_t *lo, int64_t *hi)
{
    int64_t r = eb_zono_radius(z);
    if (lo != 0) { *lo = sat_add(z->center, sat_neg(r)); }
    if (hi != 0) { *hi = sat_add(z->center, r); }
}

int64_t eb_zono_coeff_of(const eb_zono_t *z, uint32_t sym)
{
    uint32_t i;
    for (i = 0u; i < z->len; i++) {
        if (z->ids[i] == sym) { return z->coeffs[i]; }
    }
    return 0;
}

void eb_zono_shift(eb_zono_t *z, int64_t by) { z->center = sat_add(z->center, by); }

void eb_zono_scale(eb_zono_t *z, int64_t k)
{
    uint32_t i;
    z->center = sat_mul(z->center, k);
    for (i = 0u; i < z->len; i++) {
        z->coeffs[i] = sat_mul(z->coeffs[i], k);
    }
}

/* Re-admit condensed magnitude as one FRESH, independent symbol.
 *
 * The `else` branch is the one that matters. Adding the spill to an EXISTING
 * term keeps that term's symbol id, and two forms that both do so will CANCEL
 * the error when subtracted -- because cancelling shared symbols is exactly
 * what subtraction is for -- leaving a band that is too NARROW. That is the one
 * failure mode that matters here: it lets a caller conclude two values agree
 * when they do not. The Rust original shipped that bug; this port must not
 * reproduce it, and the conformance stream is what checks that it does not. */
static void absorb_spill(eb_zono_t *z, int64_t spilled, eb_symbols_t *pool)
{
    uint32_t min_i, k;
    int64_t absorbed;

    if (spilled == 0) { return; }
    z->condensations += 1u;

    if (z->len < (uint32_t)EB_ZONO_CAP) {
        z->ids[z->len] = eb_symbols_fresh(pool);
        z->coeffs[z->len] = spilled;
        z->len += 1u;
    } else {
        min_i = 0u;
        for (k = 1u; k < z->len; k++) {
            if (iabs64(z->coeffs[k]) < iabs64(z->coeffs[min_i])) { min_i = k; }
        }
        absorbed = sat_add(iabs64(z->coeffs[min_i]), spilled);
        z->ids[min_i] = eb_symbols_fresh(pool);
        z->coeffs[min_i] = absorbed;
    }
    /* Terms must stay sorted by id so the merge pairs shared symbols. A fresh
     * id is the largest yet minted, so one upward pass carries it to the end. */
    for (k = 1u; k < z->len; k++) {
        if (z->ids[k - 1u] > z->ids[k]) {
            uint32_t ti = z->ids[k - 1u];
            int64_t  tc = z->coeffs[k - 1u];
            z->ids[k - 1u] = z->ids[k];
            z->coeffs[k - 1u] = z->coeffs[k];
            z->ids[k] = ti;
            z->coeffs[k] = tc;
        }
    }
}

/* out = a + sign*b, merging two id-sorted lists in one pass. */
static void merge(eb_zono_t *out, const eb_zono_t *a, const eb_zono_t *b,
                  int64_t sign, eb_symbols_t *pool)
{
    eb_zono_t tmp;
    int64_t spilled = 0;
    uint32_t i = 0u, j = 0u;

    eb_zono_exact(&tmp, sat_add(a->center,
                                (sign < 0) ? sat_neg(b->center) : b->center));
    tmp.condensations = a->condensations + b->condensations;

    while (i < a->len || j < b->len) {
        uint32_t id;
        int64_t c;
        if (j >= b->len || (i < a->len && a->ids[i] < b->ids[j])) {
            id = a->ids[i]; c = a->coeffs[i]; i++;
        } else if (i >= a->len || b->ids[j] < a->ids[i]) {
            id = b->ids[j]; c = sat_mul(b->coeffs[j], sign); j++;
        } else {
            id = a->ids[i];
            c = sat_add(a->coeffs[i], sat_mul(b->coeffs[j], sign));
            i++; j++;
        }
        if (c == 0) { continue; }          /* exact cancellation */
        if (tmp.len < (uint32_t)EB_ZONO_CAP) {
            tmp.ids[tmp.len] = id;
            tmp.coeffs[tmp.len] = c;
            tmp.len += 1u;
        } else {
            spilled = sat_add(spilled, iabs64(c));
        }
    }
    absorb_spill(&tmp, spilled, pool);
    *out = tmp;
}

void eb_zono_add(eb_zono_t *out, const eb_zono_t *a, const eb_zono_t *b,
                 eb_symbols_t *pool)
{
    merge(out, a, b, 1, pool);
}

void eb_zono_sub(eb_zono_t *out, const eb_zono_t *a, const eb_zono_t *b,
                 eb_symbols_t *pool)
{
    merge(out, a, b, -1, pool);
}

void eb_zono_div_round(eb_zono_t *out, const eb_zono_t *a, int64_t d,
                       eb_symbols_t *pool)
{
    eb_zono_t tmp;
    int64_t q_c, rem, err;
    uint32_t i;

    q_c = eb_div_nearest(a->center, d);
    eb_zono_exact(&tmp, q_c);
    tmp.condensations = a->condensations;

    /* Exact remainder bookkeeping: accumulate true leftovers, divide once. */
    rem = iabs64(sat_add(a->center, sat_neg(sat_mul(q_c, d))));

    for (i = 0u; i < a->len; i++) {
        int64_t q = eb_div_nearest(a->coeffs[i], d);
        if (q != 0 && tmp.len < (uint32_t)EB_ZONO_CAP) {
            tmp.ids[tmp.len] = a->ids[i];
            tmp.coeffs[tmp.len] = q;
            tmp.len += 1u;
            rem = sat_add(rem, iabs64(sat_add(a->coeffs[i],
                                              sat_neg(sat_mul(q, d)))));
        } else {
            rem = sat_add(rem, iabs64(a->coeffs[i]));
        }
    }
    err = (rem + d - 1) / d;    /* round the accumulated error UP */
    absorb_spill(&tmp, err, pool);
    *out = tmp;
}

/* ---- Fixed --------------------------------------------------------------- */

void eb_fixed_new(eb_fixed_t *f, const eb_zono_t *z)
{
    f->z = *z;
    f->shift = 0u;
}

void eb_fixed_div_pow2(eb_fixed_t *f, uint32_t k) { f->shift += k; }

void eb_fixed_scale(eb_fixed_t *f, int64_t k) { eb_zono_scale(&f->z, k); }

int64_t eb_fixed_width_scaled(const eb_fixed_t *f)
{
    return sat_mul(2, eb_zono_radius(&f->z));
}

/* Bring both operands to a common scale by RAISING the smaller.
 *
 * Raising is a multiplication and therefore exact; it is lowering that would
 * round, so this never rounds. Keeping magnitudes in range is the caller's job,
 * via eb_fixed_rescale. */
static void align(const eb_fixed_t *a, const eb_fixed_t *b,
                  eb_zono_t *za, eb_zono_t *zb, uint32_t *shift)
{
    uint32_t s = (a->shift > b->shift) ? a->shift : b->shift;
    *za = a->z;
    *zb = b->z;
    if (a->shift < s) { eb_zono_scale(za, (int64_t)1 << (s - a->shift)); }
    if (b->shift < s) { eb_zono_scale(zb, (int64_t)1 << (s - b->shift)); }
    *shift = s;
}

void eb_fixed_add(eb_fixed_t *out, const eb_fixed_t *a, const eb_fixed_t *b,
                  eb_symbols_t *pool)
{
    eb_zono_t za, zb, r;
    uint32_t s;
    align(a, b, &za, &zb, &s);
    eb_zono_add(&r, &za, &zb, pool);
    out->z = r;
    out->shift = s;
}

void eb_fixed_sub(eb_fixed_t *out, const eb_fixed_t *a, const eb_fixed_t *b,
                  eb_symbols_t *pool)
{
    eb_zono_t za, zb, r;
    uint32_t s;
    align(a, b, &za, &zb, &s);
    eb_zono_sub(&r, &za, &zb, pool);
    out->z = r;
    out->shift = s;
}

void eb_fixed_rescale(eb_fixed_t *out, const eb_fixed_t *a, uint32_t target,
                      eb_symbols_t *pool)
{
    eb_zono_t r;
    if (target >= a->shift) { *out = *a; return; }
    eb_zono_div_round(&r, &a->z, (int64_t)1 << (a->shift - target), pool);
    out->z = r;
    out->shift = target;
}

/* ---- Canonical wire encoding --------------------------------------------- */

#define EB_TAG_BANDED 0x01
#define EB_TAG_ZONO   0x10

void eb_writer_init(eb_writer_t *w, uint8_t *buf, size_t cap)
{
    w->buf = buf; w->cap = cap; w->len = 0u;
}

void eb_reader_init(eb_reader_t *r, const uint8_t *buf, size_t len)
{
    r->buf = buf; r->len = len; r->pos = 0u;
}

eb_wire_err_t eb_reader_finish(const eb_reader_t *r)
{
    return (r->pos == r->len) ? EB_WIRE_OK : EB_WIRE_TRAILING_BYTES;
}

static eb_wire_err_t w_byte(eb_writer_t *w, uint8_t b)
{
    if (w->len >= w->cap) { return EB_WIRE_TRUNCATED; }
    w->buf[w->len++] = b;
    return EB_WIRE_OK;
}

/* LEB128, minimally encoded by construction. */
static eb_wire_err_t w_varint(eb_writer_t *w, uint64_t v)
{
    for (;;) {
        uint8_t byte = (uint8_t)(v & 0x7Fu);
        eb_wire_err_t e;
        v >>= 7;
        if (v == 0u) { return w_byte(w, byte); }
        e = w_byte(w, (uint8_t)(byte | 0x80u));
        if (e != EB_WIRE_OK) { return e; }
    }
}

/* Zigzag, so -1 costs one byte rather than ten. The arithmetic shift of a
 * negative value is implementation-defined in C89 but well-defined as sign
 * extension in every compiler this targets; written via a division-free form
 * so the intent is explicit. */
static eb_wire_err_t w_signed(eb_writer_t *w, int64_t v)
{
    uint64_t z = ((uint64_t)v << 1) ^ (uint64_t)(v >> 63);
    return w_varint(w, z);
}

static eb_wire_err_t r_byte(eb_reader_t *r, uint8_t *out)
{
    if (r->pos >= r->len) { return EB_WIRE_TRUNCATED; }
    *out = r->buf[r->pos++];
    return EB_WIRE_OK;
}

static eb_wire_err_t r_varint(eb_reader_t *r, uint64_t *out)
{
    uint64_t acc = 0u;
    unsigned shift = 0u;
    for (;;) {
        uint8_t b;
        uint64_t payload;
        eb_wire_err_t e = r_byte(r, &b);
        if (e != EB_WIRE_OK) { return e; }
        if (shift >= 64u) { return EB_WIRE_OVERFLOW; }
        payload = (uint64_t)(b & 0x7Fu);
        if (shift == 63u && payload > 1u) { return EB_WIRE_OVERFLOW; }
        acc |= payload << shift;
        if ((b & 0x80u) == 0u) {
            /* A continuation contributing nothing means a shorter encoding
             * existed, so this one is not canonical. */
            if (b == 0u && shift != 0u) { return EB_WIRE_NON_MINIMAL_VARINT; }
            *out = acc;
            return EB_WIRE_OK;
        }
        shift += 7u;
    }
}

static eb_wire_err_t r_signed(eb_reader_t *r, int64_t *out)
{
    uint64_t u;
    eb_wire_err_t e = r_varint(r, &u);
    if (e != EB_WIRE_OK) { return e; }
    *out = (int64_t)(u >> 1) ^ -(int64_t)(u & 1u);
    return EB_WIRE_OK;
}

eb_wire_err_t eb_wire_write_banded(eb_writer_t *w, eb_banded_t b)
{
    eb_wire_err_t e = w_byte(w, EB_TAG_BANDED);
    if (e != EB_WIRE_OK) { return e; }
    e = w_signed(w, (int64_t)b.value);
    if (e != EB_WIRE_OK) { return e; }
    return w_varint(w, (uint64_t)b.radius);
}

eb_wire_err_t eb_wire_read_banded(eb_reader_t *r, eb_banded_t *out)
{
    uint8_t tag;
    int64_t value;
    uint64_t radius;
    eb_wire_err_t e = r_byte(r, &tag);
    if (e != EB_WIRE_OK) { return e; }
    if (tag != EB_TAG_BANDED) { return EB_WIRE_BAD_TAG; }
    e = r_signed(r, &value);
    if (e != EB_WIRE_OK) { return e; }
    e = r_varint(r, &radius);
    if (e != EB_WIRE_OK) { return e; }
    if (radius > 0xFFFFFFFFu) { return EB_WIRE_OVERFLOW; }
    if (value < (-2147483647LL - 1) || value > 2147483647LL) {
        return EB_WIRE_OVERFLOW;
    }
    out->value = (int32_t)value;
    out->radius = (uint32_t)radius;
    return EB_WIRE_OK;
}

eb_wire_err_t eb_wire_write_zono(eb_writer_t *w, const eb_zono_t *z)
{
    uint64_t prev = 0u;
    uint32_t i;
    eb_wire_err_t e = w_byte(w, EB_TAG_ZONO);
    if (e != EB_WIRE_OK) { return e; }
    e = w_signed(w, z->center);
    if (e != EB_WIRE_OK) { return e; }
    e = w_varint(w, (uint64_t)z->len);
    if (e != EB_WIRE_OK) { return e; }
    for (i = 0u; i < z->len; i++) {
        uint64_t id = (uint64_t)z->ids[i];
        if (z->coeffs[i] == 0) { return EB_WIRE_ZERO_COEFFICIENT; }
        if (i > 0u && id <= prev) { return EB_WIRE_TERMS_NOT_ASCENDING; }
        e = w_varint(w, (i == 0u) ? id : (id - prev - 1u));
        if (e != EB_WIRE_OK) { return e; }
        e = w_signed(w, z->coeffs[i]);
        if (e != EB_WIRE_OK) { return e; }
        prev = id;
    }
    return EB_WIRE_OK;
}

eb_wire_err_t eb_wire_read_zono(eb_reader_t *r, eb_zono_t *out,
                                eb_symbols_t *pool)
{
    uint8_t tag;
    int64_t center;
    uint64_t n, prev = 0u, i;
    eb_wire_err_t e = r_byte(r, &tag);
    if (e != EB_WIRE_OK) { return e; }
    if (tag != EB_TAG_ZONO) { return EB_WIRE_BAD_TAG; }
    e = r_signed(r, &center);
    if (e != EB_WIRE_OK) { return e; }
    e = r_varint(r, &n);
    if (e != EB_WIRE_OK) { return e; }
    if (n > (uint64_t)EB_ZONO_CAP) { return EB_WIRE_TOO_MANY_TERMS; }

    eb_zono_exact(out, center);
    for (i = 0u; i < n; i++) {
        uint64_t raw, id;
        int64_t c;
        e = r_varint(r, &raw);
        if (e != EB_WIRE_OK) { return e; }
        if (i == 0u) {
            id = raw;
        } else {
            if (raw > UINT64_MAX - prev - 1u) { return EB_WIRE_OVERFLOW; }
            id = raw + prev + 1u;
        }
        if (id > 0xFFFFFFFFu) { return EB_WIRE_OVERFLOW; }
        e = r_signed(r, &c);
        if (e != EB_WIRE_OK) { return e; }
        if (c == 0) { return EB_WIRE_ZERO_COEFFICIENT; }
        out->ids[out->len] = (uint32_t)id;
        out->coeffs[out->len] = c;
        out->len++;
        prev = id;
    }
    /* Any id seen here must never be minted again: a collision would assert a
     * dependency that does not exist and could make a later band too narrow. */
    while (pool->next < (uint32_t)prev) { (void)eb_symbols_fresh(pool); }
    return EB_WIRE_OK;
}
