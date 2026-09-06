/* stream.c -- the conformance stream, C substrate.
 *
 * See ../CONFORMANCE-STREAM.md for the specification this implements. The short
 * version: walk a deterministic pseudo-random sequence, apply every operation in
 * the library, fold each answer into a 64-bit checksum. Three substrates that
 * produce the same checksum agreed on every case in the stream.
 *
 * The fixture pins cases someone thought of. This covers the ones nobody did.
 *
 * Usage: stream [iterations] [--print-first-divergence <expected-hex>]
 */

#include "../src/exact_band.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SEED   0x2545F4914F6CDD1DULL
#define H0     0xCBF29CE484222325ULL
#define FNV_P  0x100000001B3ULL

static uint64_t rng_state;

static uint64_t next_u64(void)
{
    uint64_t x = rng_state;
    x ^= x << 13;
    x ^= x >> 7;    /* uint64_t is unsigned, so this is a logical shift */
    x ^= x << 17;
    rng_state = x;
    return x;
}

static uint64_t mix(uint64_t h, uint64_t v)
{
    h ^= v;
    h *= FNV_P;
    return h;
}

/* Signed values are mixed by their two's-complement bit pattern, never by a
 * decimal rendering -- a checksum that depended on formatting would diverge
 * between substrates for reasons that have nothing to do with the arithmetic. */
static uint64_t bits_i64(int64_t v) { return (uint64_t)v; }

static const uint64_t SCALES[4] = { 16u, 1024u, 1000000u, 1239850262u };
static const uint32_t RINGS[8]  = { 2u, 3u, 5u, 7u, 12u, 360u, 361u, 1000u };

static int32_t draw_coord(uint64_t scale)
{
    uint64_t span = 2u * scale + 1u;
    uint64_t u = next_u64() % span;
    return (int32_t)((int64_t)u - (int64_t)scale);
}

/* One iteration of the stream. Kept in one function, in specification order,
 * because the order in which the generator is consumed IS part of the contract. */
static uint64_t step(uint64_t h)
{
    uint64_t scale;
    uint32_t dim, basis, eps, r1, r2, basis2, ring;
    int32_t ax, ay, az, bx, by, bz;
    eb_banded_t ba, bb;
    eb_narrowed_t nr;
    eb_ibox_t boxa[2], boxb[2], out[2];
    int64_t pa, pb;
    int k;

    /* 1. isqrt over the whole 64-bit range. */
    {
        uint64_t n = next_u64();
        h = mix(h, eb_isqrt(n));
        h = mix(h, eb_isqrt_ceil(n));
    }

    /* 2. covering. */
    dim   = (uint32_t)(1u + next_u64() % 3u);
    basis = (uint32_t)(next_u64() % 100000u);
    eps   = (uint32_t)(next_u64() % 100000u);
    h = mix(h, (uint64_t)(eb_basis_meets(dim, basis, eps) ? 1 : 0));
    h = mix(h, (uint64_t)eb_max_basis(dim, eps));

    /* 3. lattices, at a scale drawn per iteration so the stream spends time
     *    both where bands overlap and where they are nowhere near. */
    scale = SCALES[next_u64() % 4u];
    ax = draw_coord(scale); ay = draw_coord(scale); az = draw_coord(scale);
    bx = draw_coord(scale); by = draw_coord(scale); bz = draw_coord(scale);
    {
        int32_t a3[3], b3[3];
        a3[0] = ax; a3[1] = ay; a3[2] = az;
        b3[0] = bx; b3[1] = by; b3[2] = bz;
        h = mix(h, eb_dist_sq_z1(ax, bx));
        h = mix(h, eb_dist_sq_z2(ax, ay, bx, by));
        h = mix(h, eb_dist_sq_z3(a3, b3));
        h = mix(h, eb_dist_sq_hex(ax, ay, bx, by));
    }

    /* 4. bands, with radii on the same scale so overlap is not a foregone
     *    conclusion in either direction. */
    {
        uint64_t d1 = next_u64() % (scale + 1u);
        uint64_t d2_ = next_u64() % (scale + 1u);
        r1 = (uint32_t)(d1 > (uint64_t)EB_RADIUS_MAX ? (uint64_t)EB_RADIUS_MAX : d1);
        r2 = (uint32_t)(d2_ > (uint64_t)EB_RADIUS_MAX ? (uint64_t)EB_RADIUS_MAX : d2_);
    }
    ba.value = ax; ba.radius = r1;
    bb.value = bx; bb.radius = r2;
    h = mix(h, (uint64_t)(eb_banded_overlaps(ba, bb) ? 1 : 0));
    h = mix(h, (uint64_t)(eb_banded_within(ba, bb) ? 1 : 0));
    h = mix(h, (uint64_t)(eb_banded_within(bb, ba) ? 1 : 0));
    nr = eb_banded_narrow(ba, bb);
    h = mix(h, (uint64_t)nr.kind);
    if (nr.kind == EB_TIGHTENED) {
        h = mix(h, bits_i64((int64_t)nr.band.value));
        h = mix(h, (uint64_t)nr.band.radius);
    } else {
        h = mix(h, nr.gap_sq);
    }

    /* 5. from_basis, at all three dimensions. */
    basis2 = (uint32_t)(next_u64() % 65536u);
    for (dim = 1u; dim <= 3u; dim++) {
        h = mix(h, (uint64_t)eb_banded_from_basis(0, basis2, dim).radius);
    }

    /* 6. two-axis boxes. Bounds are sorted so every box is inhabited: an empty
     *    input makes narrow trivially fail and would waste most of the stream. */
    for (k = 0; k < 2; k++) {
        int64_t p = draw_coord(scale), q = draw_coord(scale);
        boxa[k].lo = p < q ? p : q;
        boxa[k].hi = p < q ? q : p;
        p = draw_coord(scale); q = draw_coord(scale);
        boxb[k].lo = p < q ? p : q;
        boxb[k].hi = p < q ? q : p;
    }
    if (eb_ibox_narrow_n(boxa, boxb, 2u, out)) {
        h = mix(h, 1u);
        for (k = 0; k < 2; k++) {
            h = mix(h, bits_i64(out[k].lo));
            h = mix(h, bits_i64(out[k].hi));
        }
    } else {
        uint32_t axis = 0u;
        uint64_t gap = 0u;
        h = mix(h, 0u);
        (void)eb_ibox_disagreement_n(boxa, boxb, 2u, &axis, &gap);
        h = mix(h, (uint64_t)axis);
        h = mix(h, gap);
    }

    /* 7. phase, on odd and even rings alike. Raw 64-bit slot values, so the
     *    reduction into [0, n) is exercised from both signs and far out. */
    ring = RINGS[next_u64() % 8u];
    pa = (int64_t)next_u64();
    pb = (int64_t)next_u64();
    h = mix(h, (uint64_t)eb_phase_distance(ring, pa, pb));
    h = mix(h, bits_i64(eb_phase_offset(ring, pa, pb)));

    return h;
}

int main(int argc, char **argv)
{
    unsigned long iters = 200000ul;
    uint64_t h = H0;
    unsigned long i;

    if (argc > 1) {
        iters = strtoul(argv[1], 0, 10);
    }
    rng_state = SEED;
    for (i = 0; i < iters; i++) {
        h = step(h);
    }
    printf("iterations=%lu checksum=%016llx\n", iters, (unsigned long long)h);
    return 0;
}
