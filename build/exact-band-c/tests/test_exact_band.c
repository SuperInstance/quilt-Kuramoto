/* test_exact_band.c -- properties the shared vectors cannot reach.
 *
 * The conformance runner proves this substrate AGREES with the other two. It
 * cannot prove all three are right: a shared mistake reproduces perfectly. So
 * these tests check the algebra against its definitions instead of against a
 * sibling, and include negative controls -- deliberately wrong variants,
 * asserted to FAIL the same checks -- because a test that cannot fail proves
 * nothing about the code it covers.
 */

#include "../src/exact_band.h"

#include <stdio.h>

static int failures = 0;
static int checks = 0;

#define CHECK(cond) do {                                                      \
        checks++;                                                             \
        if (!(cond)) {                                                        \
            failures++;                                                       \
            if (failures <= 20) {                                             \
                fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
            }                                                                 \
        }                                                                     \
    } while (0)

/* ---- isqrt -------------------------------------------------------------- */

static void test_isqrt_definition(void)
{
    uint64_t n;
    /* The defining property, checked directly: r^2 <= n < (r+1)^2. Exhaustive
     * over a dense low range, where the Newton start value changes shape most. */
    for (n = 0; n < 100000u; n++) {
        uint64_t r = eb_isqrt(n);
        CHECK(r * r <= n);
        CHECK((r + 1u) * (r + 1u) > n);
    }
}

static void test_isqrt_boundaries(void)
{
    /* Perfect squares, their neighbours, and the top of the range -- the three
     * places an off-by-one hides. */
    uint64_t k;
    for (k = 2; k < 4000000000u; k = k * 3u + 1u) {
        uint64_t sq = k * k;
        CHECK(eb_isqrt(sq) == k);
        CHECK(eb_isqrt(sq - 1u) == k - 1u);
        CHECK(eb_isqrt(sq + 1u) == k);
        CHECK(eb_isqrt_ceil(sq) == k);
        CHECK(eb_isqrt_ceil(sq - 1u) == k);
        CHECK(eb_isqrt_ceil(sq + 1u) == k + 1u);
    }
    /* k = 1 is the one case where `sq - 1` is 0 rather than (k-1)^2. */
    CHECK(eb_isqrt_ceil(0) == 0u);
    CHECK(eb_isqrt_ceil(1) == 1u);
    CHECK(eb_isqrt(0) == 0u);
    CHECK(eb_isqrt(1) == 1u);
    CHECK(eb_isqrt(UINT64_MAX) == 4294967295u);
    CHECK(eb_isqrt_ceil(UINT64_MAX) == 4294967296u);
    /* 4294967295^2 <= UINT64_MAX < 4294967296^2 -- the widest input there is. */
    CHECK(4294967295u * (uint64_t)4294967295u <= UINT64_MAX);
}

/* ---- range limits are TIGHT, not merely safe ---------------------------- */

static void test_coord_max_is_exact(void)
{
    /* EB_COORD_MAX is claimed to be the LARGEST coordinate for which no
     * squared distance overflows. "Largest" is a falsifiable claim, so test
     * both halves of it. */
    uint64_t c = (uint64_t)EB_COORD_MAX;
    uint64_t span = 2u * c;               /* widest coordinate difference */
    /* Fits: the hexagonal worst case a = -b costs 3*span^2. */
    CHECK(span <= UINT64_MAX / span);
    CHECK(3u * span * span <= UINT64_MAX);
    CHECK(3u * span * span / span / span == 3u);   /* no wraparound happened */
    /* One larger does not fit -- checked by division, which cannot overflow. */
    {
        uint64_t span1 = 2u * (c + 1u);
        CHECK(span1 * span1 > UINT64_MAX / 3u);
    }
    CHECK(eb_coord_ok(EB_COORD_MAX));
    CHECK(eb_coord_ok(-EB_COORD_MAX));
    CHECK(!eb_coord_ok(EB_COORD_MAX + 1));
    CHECK(!eb_coord_ok(-EB_COORD_MAX - 1));

    /* And the extreme is actually computed correctly, not just permitted. */
    {
        uint64_t got = eb_dist_sq_hex(EB_COORD_MAX, -EB_COORD_MAX, 0, 0);
        CHECK(got == 3u * c * c);
    }
    {
        uint64_t got = eb_dist_sq_z2(EB_COORD_MAX, EB_COORD_MAX,
                                     -EB_COORD_MAX, -EB_COORD_MAX);
        CHECK(got == 2u * span * span);   /* = 2*(2c)^2, the Z^2 worst case */
    }
}

/* ---- Eisenstein norm ---------------------------------------------------- */

static void test_hex_units_have_norm_one(void)
{
    /* The six units of Z[omega]: +-1, +-omega, +-(1 + omega). Each has norm
     * exactly 1. Note (-1, 1) is NOT among them -- its norm is 3 -- and an
     * earlier version of the Rust table got exactly that wrong. */
    static const int32_t units[6][2] = {
        { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }
    };
    int i;
    for (i = 0; i < 6; i++) {
        CHECK(eb_dist_sq_hex(units[i][0], units[i][1], 0, 0) == 1u);
        /* Opposite pairs sit three apart in the ordering. */
        CHECK(units[i][0] == -units[(i + 3) % 6][0]);
        CHECK(units[i][1] == -units[(i + 3) % 6][1]);
    }
    /* Negative control: the non-unit that was mistaken for one. */
    CHECK(eb_dist_sq_hex(-1, 1, 0, 0) == 3u);
}

static void test_hex_norm_is_positive_definite(void)
{
    int32_t a, b;
    for (a = -40; a <= 40; a++) {
        for (b = -40; b <= 40; b++) {
            uint64_t n = eb_dist_sq_hex(a, b, 0, 0);
            /* a^2 - ab + b^2 >= 0, and == 0 only at the origin. */
            if (a == 0 && b == 0) { CHECK(n == 0u); }
            else { CHECK(n > 0u); }
            /* Symmetric, and translation-invariant. */
            CHECK(eb_dist_sq_hex(0, 0, a, b) == n);
            CHECK(eb_dist_sq_hex(a + 7, b - 5, 7, -5) == n);
        }
    }
}

/* ---- covering ----------------------------------------------------------- */

static void test_max_basis_is_tight(void)
{
    uint32_t dim, eps;
    for (dim = 1; dim <= 3; dim++) {
        for (eps = 0; eps < 400u; eps++) {
            uint32_t b = eb_max_basis(dim, eps);
            if (b == 0u) {
                /* Claimed: nothing meets it. Check the smallest candidate. */
                CHECK(!eb_basis_meets(dim, 1u, eps));
            } else {
                CHECK(eb_basis_meets(dim, b, eps));        /* it meets */
                CHECK(!eb_basis_meets(dim, b + 1u, eps));  /* and is maximal */
            }
        }
    }
    /* The one-dimensional case is closed-form: b <= 2*eps exactly. */
    for (eps = 0; eps < 1000u; eps++) {
        CHECK(eb_max_basis(1u, eps) == 2u * eps);
    }
}

static void test_covering_matches_the_geometry(void)
{
    /* The deep hole of b*Z^n sits at the cube centre, at distance b*sqrt(n)/2
     * from every corner. Verified against the squared form, in integers:
     * the squared distance from (b/2,...) to the origin, scaled by 4, is n*b^2. */
    uint32_t b, dim;
    for (b = 1; b <= 50u; b++) {
        for (dim = 1; dim <= 3u; dim++) {
            uint64_t hole_sq_x4 = (uint64_t)dim * b * b;
            uint32_t eps;
            for (eps = 0; eps < 100u; eps++) {
                int meets = eb_basis_meets(dim, b, eps);
                CHECK(meets == (hole_sq_x4 <= 4u * (uint64_t)eps * eps));
            }
        }
    }
}

/* ---- Banded ------------------------------------------------------------- */

static void test_banded_narrow_is_sound(void)
{
    int32_t cx;
    uint32_t r1, r2;
    for (cx = -25; cx <= 25; cx++) {
        for (r1 = 0; r1 <= 12u; r1++) {
            for (r2 = 0; r2 <= 12u; r2++) {
                eb_banded_t a, b;
                eb_narrowed_t n;
                a.value = 0;  a.radius = r1;
                b.value = cx; b.radius = r2;
                n = eb_banded_narrow(a, b);

                CHECK((n.kind == EB_TIGHTENED) == (eb_banded_overlaps(a, b) != 0));

                if (n.kind == EB_TIGHTENED) {
                    /* Soundness: the result must ENCLOSE the intersection, so
                     * every integer point in both inputs must be in it. */
                    int32_t p;
                    for (p = -60; p <= 60; p++) {
                        if (eb_banded_contains(a, p) && eb_banded_contains(b, p)) {
                            CHECK(eb_banded_contains(n.band, p));
                        }
                    }
                    /* And it must be one of the inputs -- balls are not closed
                     * under intersection, so nothing tighter is available. */
                    CHECK((n.band.value == a.value && n.band.radius == a.radius) ||
                          (n.band.value == b.value && n.band.radius == b.radius));
                    /* Tightest of the two. */
                    CHECK(n.band.radius == (r1 < r2 ? r1 : r2));
                } else {
                    /* A contradiction reports its size, rounded UP. */
                    uint64_t gap = eb_narrowed_gap(n);
                    CHECK(n.gap_sq == (uint64_t)((int64_t)cx * (int64_t)cx));
                    CHECK(gap * gap >= n.gap_sq);              /* never understates */
                    CHECK((gap - 1u) * (gap - 1u) < n.gap_sq); /* and is minimal */
                    /* Disjoint means no shared point. */
                    {
                        int32_t p;
                        for (p = -60; p <= 60; p++) {
                            CHECK(!(eb_banded_contains(a, p) && eb_banded_contains(b, p)));
                        }
                    }
                }
            }
        }
    }
}

static void test_banded_within_and_widen(void)
{
    eb_banded_t a, b;
    a.value = 5; a.radius = 2;
    b.value = 5; b.radius = 9;
    CHECK(eb_banded_within(a, b));
    CHECK(!eb_banded_within(b, a));
    /* a spans [c-2, c+2]; b spans [-4, 14]. Containment holds up to c = 12. */
    a.value = 12;
    CHECK(eb_banded_within(a, b));
    a.value = 13;                    /* [11, 15] escapes b's right edge */
    CHECK(!eb_banded_within(a, b));

    /* Widening saturates rather than wrapping -- a band that wrapped to zero
     * would silently claim certainty it does not have. */
    a.radius = EB_RADIUS_MAX;
    CHECK(eb_banded_widen(a, 1000u).radius == EB_RADIUS_MAX);
    a.radius = 3;
    CHECK(eb_banded_widen(a, 4u).radius == 7u);
}

/* ---- IBox --------------------------------------------------------------- */

static void test_ibox_narrow_is_exact(void)
{
    int64_t l1, h1, l2, h2;
    for (l1 = -6; l1 <= 6; l1++) {
    for (h1 = -6; h1 <= 6; h1++) {
    for (l2 = -6; l2 <= 6; l2++) {
    for (h2 = -6; h2 <= 6; h2++) {
        eb_ibox_t a, b, out;
        int ok;
        int64_t p;
        a.lo = l1; a.hi = h1;
        b.lo = l2; b.hi = h2;
        out.lo = 0; out.hi = 0;
        ok = eb_ibox_narrow(a, b, &out);

        /* EXACT, not an enclosure: p is in the result iff it is in both. */
        for (p = -12; p <= 12; p++) {
            int both = eb_ibox_contains(a, p) && eb_ibox_contains(b, p);
            int got  = ok && eb_ibox_contains(out, p);
            CHECK(both == got);
        }
        /* Disjoint iff there is a gap, and the gap is the true distance. */
        if (!ok) {
            CHECK(eb_ibox_disagreement(a, b) > 0u);
        } else {
            CHECK(eb_ibox_disagreement(a, b) == 0u);
        }
    }}}}
}

static void test_ibox_disagreement_at_the_extremes(void)
{
    /* The gap between INT64_MIN and INT64_MAX exceeds INT64_MAX but fits in
     * uint64_t. Signed arithmetic would be undefined here; unsigned is exact. */
    eb_ibox_t a, b;
    a.lo = INT64_MAX; a.hi = INT64_MAX;
    b.lo = INT64_MIN; b.hi = INT64_MIN;
    CHECK(eb_ibox_narrow(a, b, 0) == 0);
    CHECK(eb_ibox_disagreement(a, b) == UINT64_MAX);
    CHECK(eb_ibox_disagreement(b, a) == UINT64_MAX);
}

/* ---- Phase -------------------------------------------------------------- */

/* The bug this substrate inherited a fix for, reproduced EXACTLY as it was.
 *
 * The original normalised nothing: `d` stayed in (-n, n) and two truncating
 * comparisons tried to fold it. On an odd ring the second branch UNDOES the
 * first -- `n / 2` and `-n / 2` both truncate toward zero, so a value just past
 * the half-way point is pushed negative and then pulled straight back. Kept as
 * a NEGATIVE CONTROL: a test suite that cannot fail proves nothing. */
static int64_t phase_offset_original(uint32_t n, int64_t a, int64_t b)
{
    int64_t nn = (int64_t)n;
    int64_t d = (int64_t)eb_phase_new(n, b) - (int64_t)eb_phase_new(n, a);
    if (d > nn / 2) { d -= nn; }
    if (d <= -nn / 2) { d += nn; }
    return d;
}

/* The fix is the NORMALISATION into [0, n), not the doubling.
 *
 * Worth pinning down, because the commit message and the Rust doc comment both
 * credit `2*d > n` over `d > n/2` -- and on a `d` already reduced into [0, n)
 * those two are equivalent for every n, odd included: for odd n,
 * `d > (n-1)/2` iff `2d >= n` iff (2d is even, n is odd) `2d > n`. So the
 * doubled form is a clarity choice, not the correction. This control asserts
 * that equivalence rather than leaving the claim untested. */
static int64_t phase_offset_single_trunc(uint32_t n, int64_t a, int64_t b)
{
    int64_t nn = (int64_t)n;
    int64_t d = (int64_t)eb_phase_new(n, b) - (int64_t)eb_phase_new(n, a);
    if (d < 0) { d += nn; }
    if (d > nn / 2) { d -= nn; }
    return d;
}

static void test_phase_invariants(void)
{
    static const uint32_t rings[] = { 1, 2, 3, 4, 5, 7, 8, 12, 13, 60, 96, 359, 360, 361 };
    size_t k;
    for (k = 0; k < sizeof rings / sizeof rings[0]; k++) {
        uint32_t n = rings[k];
        int64_t a, b;
        for (a = 0; a < (int64_t)n; a++) {
            for (b = 0; b < (int64_t)n; b++) {
                uint32_t dist = eb_phase_distance(n, a, b);
                int64_t off = eb_phase_offset(n, a, b);
                int64_t mag = off < 0 ? -off : off;

                CHECK((uint64_t)mag == (uint64_t)dist);      /* magnitudes agree */
                CHECK(dist <= n / 2u);                       /* it is the SHORT way */
                CHECK(eb_phase_distance(n, b, a) == dist);   /* symmetric */
                /* Following the offset lands exactly on b. */
                CHECK(eb_phase_new(n, a + off) == eb_phase_new(n, b));
                /* Reversing negates it (except at the antipode of an even
                 * circle, where both directions are equally short and the
                 * convention picks +n/2 both ways). */
                if (!(n % 2u == 0u && mag == (int64_t)(n / 2u))) {
                    CHECK(eb_phase_offset(n, b, a) == -off);
                }
                /* Wrapping the inputs by whole turns changes nothing. */
                CHECK(eb_phase_offset(n, a + 5 * (int64_t)n, b - 3 * (int64_t)n) == off);
                CHECK(eb_phase_distance(n, a - 7 * (int64_t)n, b) == dist);
            }
        }
    }
}

static void test_phase_negative_control(void)
{
    static const uint32_t rings[] = { 2, 3, 4, 5, 7, 9, 12, 359, 360, 361, 1000 };
    size_t k;
    int64_t a, b;

    for (k = 0; k < sizeof rings / sizeof rings[0]; k++) {
        uint32_t n = rings[k];
        int orig_diffs = 0, trunc_diffs = 0;
        for (a = 0; a < (int64_t)n; a++) {
            for (b = 0; b < (int64_t)n; b++) {
                if (eb_phase_offset(n, a, b) != phase_offset_original(n, a, b)) {
                    orig_diffs++;
                }
                if (eb_phase_offset(n, a, b) != phase_offset_single_trunc(n, a, b)) {
                    trunc_diffs++;
                }
            }
        }
        /* The doubled comparison is equivalent once `d` is normalised -- on
         * every ring, odd and even alike. */
        CHECK(trunc_diffs == 0);

        if (n % 2u == 0u) {
            /* Even rings: the original was already right, which is exactly why
             * the bug survived -- every vector used N=360. */
            CHECK(orig_diffs == 0);
        } else {
            /* Odd rings: wrong on precisely the n pairs at d = (n+1)/2, the
             * first slot past the half-way point, where the second branch
             * cancels the first. */
            CHECK(orig_diffs == (int)n);
        }
    }

    /* The concrete case from the fix: on N=7, 0 -> 4 is 3 slots backwards. */
    CHECK(eb_phase_offset(7u, 0, 4) == -3);
    CHECK(phase_offset_original(7u, 0, 4) == 4);
    CHECK(eb_phase_distance(7u, 0, 4) == 3u);
    /* The original's answer exceeds half the circle -- outside the range its
     * own documentation promised. */
    CHECK(phase_offset_original(7u, 0, 4) > 7 / 2);
}

static void test_phase_degenerate(void)
{
    /* A zero-slot circle has no positions; answering 0 beats dividing by it. */
    CHECK(eb_phase_new(0u, 5) == 0u);
    CHECK(eb_phase_distance(0u, 1, 2) == 0u);
    CHECK(eb_phase_offset(0u, 1, 2) == 0);
    /* A one-slot circle: everything collides, nothing is ever offset. */
    CHECK(eb_phase_distance(1u, 0, 0) == 0u);
    CHECK(eb_phase_offset(1u, 99, -99) == 0);
    /* Large negative inputs reduce correctly. */
    CHECK(eb_phase_new(12u, -1) == 11u);
    CHECK(eb_phase_new(12u, -13) == 11u);
}

/* ---- per-lattice limits ------------------------------------------------- */

static void test_per_dimension_limits_are_each_tight(void)
{
    /* Three limits, because the number of squared terms summed is 1, 2 and 3.
     * Each is claimed to be the largest that fits, and "largest" is falsifiable:
     * check that C fits and C+1 does not, per dimension. Division is used for
     * the negative half, since the whole point is that multiplying would
     * overflow. */
    struct { uint64_t terms; uint64_t c; } cases[3];
    size_t i;
    cases[0].terms = 1u; cases[0].c = (uint64_t)EB_COORD_MAX_Z1;
    cases[1].terms = 2u; cases[1].c = (uint64_t)EB_COORD_MAX_Z2;
    cases[2].terms = 3u; cases[2].c = (uint64_t)EB_COORD_MAX_Z3;

    for (i = 0; i < 3u; i++) {
        uint64_t span = 2u * cases[i].c;
        uint64_t terms = cases[i].terms;
        CHECK(span <= UINT64_MAX / span);                  /* span^2 fits */
        CHECK(span * span <= UINT64_MAX / terms);          /* and so does k*span^2 */
        if (cases[i].c < (uint64_t)INT32_MAX) {
            uint64_t span1 = 2u * (cases[i].c + 1u);
            CHECK(span1 * span1 > UINT64_MAX / terms);     /* one more does not */
        }
    }
    /* Z^1 is unrestricted -- every int32 is in reach, including both extremes,
     * because a single squared int32 difference is at most (2^32-1)^2. */
    CHECK(eb_coord_ok_dim(INT32_MAX, 1u));
    CHECK(eb_coord_ok_dim(INT32_MIN, 1u));
    CHECK(eb_dist_sq_z1(INT32_MAX, INT32_MIN) == 4294967295u * (uint64_t)4294967295u);
    /* Z^2 and Z^3 are not, and the tighter limit really is tighter. */
    CHECK(!eb_coord_ok_dim(INT32_MAX, 2u));
    CHECK(!eb_coord_ok_dim(INT32_MAX, 3u));
    CHECK(eb_coord_ok_dim(EB_COORD_MAX_Z2, 2u));
    CHECK(!eb_coord_ok_dim(EB_COORD_MAX_Z2, 3u));
    CHECK(eb_coord_ok_dim(EB_COORD_MAX_Z3, 3u));
    CHECK(!eb_coord_ok_dim(0, 0u));   /* an unknown dimension is refused */
    CHECK(!eb_coord_ok_dim(0, 4u));

    /* The Z^3 worst case is computed, not merely permitted. */
    {
        int32_t a[3], b[3];
        uint64_t c = (uint64_t)EB_COORD_MAX_Z3, span;
        a[0] = EB_COORD_MAX_Z3; a[1] = EB_COORD_MAX_Z3; a[2] = EB_COORD_MAX_Z3;
        b[0] = -EB_COORD_MAX_Z3; b[1] = -EB_COORD_MAX_Z3; b[2] = -EB_COORD_MAX_Z3;
        span = 2u * c;
        CHECK(eb_dist_sq_z3(a, b) == 3u * span * span);
    }
}

/* ---- from_basis --------------------------------------------------------- */

static void test_from_basis_rounds_up_and_is_minimal(void)
{
    uint32_t basis, dim;
    for (dim = 1u; dim <= 3u; dim++) {
        for (basis = 0u; basis <= 300u; basis++) {
            uint64_t target = (uint64_t)dim * basis * basis;
            uint64_t r = eb_banded_from_basis(0, basis, dim).radius;
            /* Sound: the band covers the deep hole. */
            CHECK(4u * r * r >= target);
            /* Tight: one smaller does not. Rounding down here would understate
             * every band the function produces, which is the failure mode this
             * check exists for. */
            if (r > 0u) { CHECK(4u * (r - 1u) * (r - 1u) < target); }
            /* Consistent with the covering predicate: r is a tolerance the
             * basis meets, and r-1 is one it does not. */
            if (r <= EB_SCALE_MAX) {
                CHECK(eb_basis_meets(dim, basis, (uint32_t)r));
                if (r > 0u) { CHECK(!eb_basis_meets(dim, basis, (uint32_t)(r - 1u))); }
            }
        }
    }
    /* A zero basis is a lattice of exact points -- no uncertainty at all. */
    CHECK(eb_banded_from_basis(7, 0u, 3u).radius == 0u);
    CHECK(eb_banded_from_basis(7, 0u, 3u).value == 7);
    /* An unknown dimension is refused rather than guessed at. */
    CHECK(eb_banded_from_basis(0, 10u, 0u).radius == 0u);
    CHECK(eb_banded_from_basis(0, 10u, 4u).radius == 0u);
}

/* ---- n-dimensional boxes ------------------------------------------------ */

static void test_ibox_n_narrow_and_worst_axis(void)
{
    /* Two axes, so `disagreement` has a choice. The scalar case cannot test
     * this at all: with one axis, "worst" and "first" are the same answer. */
    eb_ibox_t a[2], b[2], out[2];
    uint32_t axis = 99u;
    uint64_t gap = 0u;

    /* Disjoint on axis 1 only. */
    a[0].lo = 0;  a[0].hi = 10; a[1].lo = 0;  a[1].hi = 10;
    b[0].lo = 5;  b[0].hi = 15; b[1].lo = 40; b[1].hi = 50;
    CHECK(eb_ibox_narrow_n(a, b, 2u, out) == 0);
    CHECK(eb_ibox_disagreement_n(a, b, 2u, &axis, &gap) == 1);
    CHECK(axis == 1u);
    CHECK(gap == 30u);

    /* Disjoint on both, worse on axis 0 -- so the worst-axis rule must pick 0
     * even though axis 1 disagrees too. A port returning the first disagreeing
     * axis passes this one by luck, which is why the mirror case follows. */
    a[0].lo = 0;   a[0].hi = 1;  a[1].lo = 0;  a[1].hi = 1;
    b[0].lo = 100; b[0].hi = 101; b[1].lo = 5; b[1].hi = 6;
    CHECK(eb_ibox_disagreement_n(a, b, 2u, &axis, &gap) == 1);
    CHECK(axis == 0u);
    CHECK(gap == 99u);

    /* Mirror: worse on axis 1. A first-disagreeing-axis port fails here. */
    a[0].lo = 0;  a[0].hi = 1;   a[1].lo = 0;   a[1].hi = 1;
    b[0].lo = 5;  b[0].hi = 6;   b[1].lo = 100; b[1].hi = 101;
    CHECK(eb_ibox_disagreement_n(a, b, 2u, &axis, &gap) == 1);
    CHECK(axis == 1u);
    CHECK(gap == 99u);

    /* Equal gaps: the first axis wins the tie, matching the Rust original. */
    a[0].lo = 0;  a[0].hi = 1;   a[1].lo = 0;  a[1].hi = 1;
    b[0].lo = 10; b[0].hi = 11;  b[1].lo = 10; b[1].hi = 11;
    CHECK(eb_ibox_disagreement_n(a, b, 2u, &axis, &gap) == 1);
    CHECK(axis == 0u);

    /* Overlapping: no disagreement, and the intersection is exact per axis. */
    a[0].lo = 0; a[0].hi = 10; a[1].lo = -5; a[1].hi = 5;
    b[0].lo = 3; b[0].hi = 20; b[1].lo = 0;  b[1].hi = 2;
    CHECK(eb_ibox_narrow_n(a, b, 2u, out) == 1);
    CHECK(out[0].lo == 3 && out[0].hi == 10);
    CHECK(out[1].lo == 0 && out[1].hi == 2);
    CHECK(eb_ibox_disagreement_n(a, b, 2u, &axis, &gap) == 0);

    /* Aliasing the output onto an input must not corrupt a rejected narrow:
     * the disjointness test completes before anything is written. */
    a[0].lo = 0;  a[0].hi = 10; a[1].lo = 0;  a[1].hi = 10;
    b[0].lo = 3;  b[0].hi = 6;  b[1].lo = 40; b[1].hi = 50;
    CHECK(eb_ibox_narrow_n(a, b, 2u, a) == 0);
    CHECK(a[0].lo == 0 && a[0].hi == 10);   /* untouched, not half-updated */

    /* Zero axes: nothing can disagree, so the empty intersection succeeds. */
    CHECK(eb_ibox_narrow_n(a, b, 0u, 0) == 1);
    CHECK(eb_ibox_disagreement_n(a, b, 0u, 0, 0) == 0);
}

/* ---- driver ------------------------------------------------------------- */

int main(void)
{
    test_isqrt_definition();
    test_isqrt_boundaries();
    test_coord_max_is_exact();
    test_per_dimension_limits_are_each_tight();
    test_from_basis_rounds_up_and_is_minimal();
    test_ibox_n_narrow_and_worst_axis();
    test_hex_units_have_norm_one();
    test_hex_norm_is_positive_definite();
    test_max_basis_is_tight();
    test_covering_matches_the_geometry();
    test_banded_narrow_is_sound();
    test_banded_within_and_widen();
    test_ibox_narrow_is_exact();
    test_ibox_disagreement_at_the_extremes();
    test_phase_invariants();
    test_phase_negative_control();
    test_phase_degenerate();

    printf("checks: %d\n", checks);
    if (failures) {
        fprintf(stderr, "%d FAILURE(S)\n", failures);
        return 1;
    }
    printf("PASS\n");
    return 0;
}
