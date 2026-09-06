/* exact_band.h -- exact integer tolerance bands, in C99.
 *
 * The third substrate. The Rust crate and the Python port already agree
 * byte-for-byte on a shared vector set; this file is held to the same vectors,
 * so a disagreement between any two of the three is visible rather than latent.
 *
 * This is the substrate the ESP32 firmware can actually link against: no
 * allocation, no dependencies beyond <stdint.h>, and no floating-point type
 * appears anywhere in the implementation.
 *
 * WIDTH, STATED HONESTLY
 * ----------------------
 * The Rust crate computes squared quantities in `u128`. C99 has no portable
 * 128-bit integer, and the 32-bit targets this is meant for do not have one at
 * all. So this port works in 64 bits and states its limits rather than
 * pretending they are not there. Every limit below is the exact largest value
 * for which the corresponding squared quantity still fits in `uint64_t`:
 *
 *   EB_COORD_MAX   lattice coordinates
 *   EB_RADIUS_MAX  band radii
 *   EB_SCALE_MAX   covering-radius basis and tolerance
 *
 * Inputs outside these ranges are REJECTED, never silently wrapped: the
 * predicates return 0 and the "checked" entry points return a nonzero error.
 * The conformance runner skips the shared vectors that exceed them and reports
 * how many it skipped, so the substrate difference is reported rather than
 * papered over.
 */

#ifndef EXACT_BAND_H
#define EXACT_BAND_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- range limits ------------------------------------------------------- */

/* Coordinate limits, PER LATTICE, because they genuinely differ: the number of
 * squared terms summed is 1, 2 and 3 respectively, and quoting the tightest of
 * them everywhere would refuse inputs this port handles perfectly well.
 *
 * Each is the largest C with (number of terms) * (2C)^2 <= UINT64_MAX, and the
 * test suite asserts both halves: that C fits and that C+1 does not.
 *
 *   Z^1   one term, and (2^32 - 1)^2 < UINT64_MAX, so the WHOLE int32 range is
 *         safe -- no restriction at all.
 *   Z^2   two terms:  2*(2C)^2 <= UINT64_MAX
 *   Z^3   three terms, and the hexagonal norm a^2 - ab + b^2 costs the same
 *         3*(2C)^2 at its worst point a = -b. */
#define EB_COORD_MAX_Z1 ((int32_t)2147483647)   /* INT32_MAX: unrestricted */
#define EB_COORD_MAX_Z2 ((int32_t)1518500249)
#define EB_COORD_MAX_Z3 ((int32_t)1239850262)

/* The general-purpose name is the tightest of the three, so code that does not
 * know which lattice it will be used on stays safe by default. */
#define EB_COORD_MAX EB_COORD_MAX_Z3

/* Two radii are summed before squaring, so the sum must square cleanly:
 * (2R)^2 <= UINT64_MAX. Rounded down to a power of two minus one. */
#define EB_RADIUS_MAX ((uint32_t)1073741823)   /* 2^30 - 1 */

/* `basis_meets` compares dim*b^2 against 4*eps^2 with dim <= 3, so it needs
 * 3*S^2 <= UINT64_MAX and 4*S^2 <= UINT64_MAX; the latter binds. */
#define EB_SCALE_MAX ((uint32_t)2147483647)    /* 2^31 - 1 */

/* ---- integer square root ------------------------------------------------ */

/** Exact floor of the square root: the unique r with r*r <= n < (r+1)*(r+1).
 *  Newton's method in integers, over the whole uint64_t range. */
uint64_t eb_isqrt(uint64_t n);

/** Exact ceiling. Rounds up, so a band derived from it never understates. */
uint64_t eb_isqrt_ceil(uint64_t n);

/* ---- covering radius ---------------------------------------------------- */

/** Does basis `b` on a `dim`-dimensional lattice meet tolerance `eps`?
 *  Exactly `dim*b*b <= 4*eps*eps`. No roots, no floats.
 *  Returns 0 for dim == 0, or for basis/eps above EB_SCALE_MAX. */
int eb_basis_meets(uint32_t dim, uint32_t basis, uint32_t eps);

/** Largest basis still meeting `eps`, by integer bisection over
 *  [1, EB_SCALE_MAX]. 0 if none does. */
uint32_t eb_max_basis(uint32_t dim, uint32_t eps);

/* ---- lattices ----------------------------------------------------------- */

/** Is a coordinate inside the (conservative) EB_COORD_MAX? */
int eb_coord_ok(int32_t v);
/** Is a coordinate inside the limit for a `dim`-dimensional lattice?
 *  `dim` of 1, 2 or 3; anything else is rejected. */
int eb_coord_ok_dim(int32_t v, uint32_t dim);

/** Squared Euclidean distance on Z^1. Safe for the entire int32 range. */
uint64_t eb_dist_sq_z1(int32_t a, int32_t b);
/** Squared Euclidean distance on Z^2. Coordinates within EB_COORD_MAX_Z2. */
uint64_t eb_dist_sq_z2(int32_t ax, int32_t ay, int32_t bx, int32_t by);
/** Squared Euclidean distance on Z^3. Coordinates within EB_COORD_MAX_Z3. */
uint64_t eb_dist_sq_z3(const int32_t a[3], const int32_t b[3]);
/** Eisenstein norm distance on the hexagonal lattice: a^2 - ab + b^2.
 *  Coordinates within EB_COORD_MAX_Z3 -- the worst point a = -b costs the same
 *  three squared terms as three dimensions do. */
uint64_t eb_dist_sq_hex(int32_t aa, int32_t ab, int32_t ba, int32_t bb);

/* ---- Banded: a centre with a linear integer radius ---------------------- */

typedef struct {
    int32_t  value;   /**< exact centre, on Z^1 */
    uint32_t radius;  /**< half-width, stored LINEARLY (see the crate docs) */
} eb_banded_t;

/** Is the value known exactly? */
int eb_banded_certain(eb_banded_t b);
/** Does the band contain this point? Exactly `d*d <= r*r`. */
int eb_banded_contains(eb_banded_t b, int32_t point);
/** Do two bands overlap? Exactly `d*d <= (r1+r2)*(r1+r2)`. */
int eb_banded_overlaps(eb_banded_t a, eb_banded_t b);
/** Does `a` lie wholly inside `b`? Exactly `d*d <= (r2-r1)*(r2-r1)`,
 *  after the cheap `r1 <= r2` rejection that makes the subtraction safe. */
int eb_banded_within(eb_banded_t a, eb_banded_t b);
/** Widen by `extra`, saturating at EB_RADIUS_MAX rather than wrapping. */
eb_banded_t eb_banded_widen(eb_banded_t b, uint32_t extra);

/** The band a lattice of basis `b` induces in `dim` dimensions.
 *
 *  The covering radius `b*sqrt(dim)/2` is irrational in general, so this returns
 *  the smallest INTEGER radius that still covers it: the smallest r with
 *  `4*r^2 >= dim*b^2`, found by bisection, never by a root. Rounding UP is the
 *  whole point -- a band that rounded down would understate the uncertainty it
 *  exists to carry. Returns radius 0 for dim outside 1..3. */
eb_banded_t eb_banded_from_basis(int32_t value, uint32_t basis, uint32_t dim);

typedef enum { EB_TIGHTENED = 0, EB_CONTRADICTION = 1 } eb_narrow_kind_t;

typedef struct {
    eb_narrow_kind_t kind;
    eb_banded_t      band;    /**< valid when kind == EB_TIGHTENED */
    uint64_t         gap_sq;  /**< valid when kind == EB_CONTRADICTION */
} eb_narrowed_t;

/** Narrow by an observation. Returns the tighter input when they agree, or the
 *  squared gap when they do not -- a contradiction is information. */
eb_narrowed_t eb_banded_narrow(eb_banded_t self, eb_banded_t obs);

/** Magnitude of a contradiction, rounded UP so it is never understated.
 *  Returns 0 when the bands agreed. */
uint64_t eb_narrowed_gap(eb_narrowed_t n);

/* ---- IBox: an interval that narrows exactly ----------------------------- */

typedef struct { int64_t lo, hi; } eb_ibox_t;

/** Empty means contradictory. */
int eb_ibox_empty(eb_ibox_t b);
/** Every bound tight: the value is known. */
int eb_ibox_certain(eb_ibox_t b);
int eb_ibox_contains(eb_ibox_t b, int64_t p);
/** Exact intersection. Writes to `out` and returns 1, or returns 0 if disjoint.
 *  Unlike the ball form this loses nothing: boxes are closed under
 *  intersection, so the result is the intersection, not an enclosure of it. */
int eb_ibox_narrow(eb_ibox_t a, eb_ibox_t b, eb_ibox_t *out);
/** Gap when disjoint; 0 when they intersect. Computed in unsigned arithmetic,
 *  which is exact here: for int64 bounds the true gap always fits in uint64. */
uint64_t eb_ibox_disagreement(eb_ibox_t a, eb_ibox_t b);

/** Exact intersection of two `n`-axis boxes, one `eb_ibox_t` per axis.
 *  Writes `n` intervals to `out` and returns 1, or returns 0 if any axis is
 *  disjoint. `out` may be NULL, or may alias `a` or `b`. */
int eb_ibox_narrow_n(const eb_ibox_t *a, const eb_ibox_t *b, uint32_t n,
                     eb_ibox_t *out);

/** Which axis disagrees WORST, and by how much.
 *
 *  Returns 1 and writes `*axis` and `*gap` when the boxes are disjoint, 0 when
 *  they intersect. "Worst", not "first": with one axis there is no choice to
 *  make, which is why every one-dimensional vector passes a port that returns
 *  the first disagreeing axis instead. */
int eb_ibox_disagreement_n(const eb_ibox_t *a, const eb_ibox_t *b, uint32_t n,
                           uint32_t *axis, uint64_t *gap);

/* ---- Phase: exact position on a discrete circle -------------------------- */

/** Reduce a slot into [0, n). Exact for any int64 input; 0 when n == 0. */
uint32_t eb_phase_new(uint32_t n, int64_t slot);

/** Shortest distance around a circle of `n` slots: min(d, n-d). */
uint32_t eb_phase_distance(uint32_t n, int64_t a, int64_t b);

/** Signed shortest offset from `a` to `b`.
 *
 *  Compares `2*d > n` rather than `d > n/2`: integer division truncates, and on
 *  an ODD circle that rounds the half-way point down and flips offsets that
 *  were already shortest. That was a real bug in the Rust original, invisible
 *  to every vector until odd rings were added. */
int64_t eb_phase_offset(uint32_t n, int64_t a, int64_t b);

#ifdef __cplusplus
}
#endif
#endif /* EXACT_BAND_H */
