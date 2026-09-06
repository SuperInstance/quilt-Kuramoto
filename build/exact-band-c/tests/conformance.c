/* conformance.c -- hold the C substrate to the shared golden vectors.
 *
 * The Rust crate emits vectors.json; the Python port already reproduces it.
 * This runner reads THE SAME FILE and checks every record against the C
 * implementation. A disagreement between any two of the three substrates
 * therefore fails a build rather than waiting to be noticed.
 *
 * Vectors outside this substrate's 64-bit range (see EB_COORD_MAX and friends
 * in exact_band.h) are SKIPPED and counted. The count is printed and asserted
 * against an expected figure: a skip that appears or disappears is itself a
 * change in the substrate's reach, and silently drifting skips would let real
 * coverage evaporate while the run still said PASS.
 *
 * Usage: conformance <path/to/vectors.json>
 */

#include "../src/exact_band.h"
#include "json.h"

#include <stdio.h>
#include <string.h>

static int failures = 0;
static int checks   = 0;
static int skipped  = 0;

static void fail(const char *section, int idx, const char *what,
                 long long got, long long want)
{
    failures++;
    if (failures <= 20) {
        fprintf(stderr, "FAIL %s[%d] %s: got %lld, want %lld\n",
                section, idx, what, got, want);
    }
}

static void expect(const char *section, int idx, const char *what,
                   long long got, long long want)
{
    checks++;
    if (got != want) { fail(section, idx, what, got, want); }
}

/* Fetch a required member, reporting a schema mismatch rather than guessing. */
static int need(const js_doc_t *d, int obj, const char *key,
                const char *section, int idx)
{
    int v = js_get(d, obj, key);
    if (v < 0) {
        failures++;
        fprintf(stderr, "FAIL %s[%d]: missing key \"%s\"\n", section, idx, key);
    }
    return v;
}

static int64_t i64_of(const js_doc_t *d, int v)
{
    int64_t x = 0;
    (void)js_i64(d, v, &x);
    return x;
}

/* ---- sections ----------------------------------------------------------- */

static void run_covering(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r = js_at(d, arr, i);
        int64_t dim = i64_of(d, need(d, r, "dim", "covering", i));
        int64_t eps = i64_of(d, need(d, r, "eps", "covering", i));
        int64_t mb  = i64_of(d, need(d, r, "max_basis", "covering", i));
        int want_meets = js_bool(d, need(d, r, "meets", "covering", i));
        int want_plus  = js_bool(d, need(d, r, "meets_plus_one", "covering", i));

        expect("covering", i, "max_basis",
               (long long)eb_max_basis((uint32_t)dim, (uint32_t)eps), (long long)mb);
        expect("covering", i, "meets",
               eb_basis_meets((uint32_t)dim, (uint32_t)mb, (uint32_t)eps) ? 1 : 0,
               want_meets ? 1 : 0);
        expect("covering", i, "meets_plus_one",
               eb_basis_meets((uint32_t)dim, (uint32_t)mb + 1u, (uint32_t)eps) ? 1 : 0,
               want_plus ? 1 : 0);
    }
}

static void run_isqrt(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r = js_at(d, arr, i);
        uint64_t nn, fl, ce;
        /* js_u64 fails on anything wider than uint64_t -- vectors.json carries
         * u128::MAX, which this substrate cannot represent. Skip, don't lie. */
        if (!js_u64(d, need(d, r, "n", "isqrt", i), &nn)) { skipped++; continue; }
        if (!js_u64(d, need(d, r, "floor", "isqrt", i), &fl)) { skipped++; continue; }
        if (!js_u64(d, need(d, r, "ceil",  "isqrt", i), &ce)) { skipped++; continue; }
        expect("isqrt", i, "floor", (long long)eb_isqrt(nn), (long long)fl);
        expect("isqrt", i, "ceil",  (long long)eb_isqrt_ceil(nn), (long long)ce);
    }
}

static void run_dist_sq(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r  = js_at(d, arr, i);
        int aa = need(d, r, "a", "dist_sq", i);
        int bb = need(d, r, "b", "dist_sq", i);
        int64_t ax, ay, bx, by;
        uint64_t z2, hex;

        if (aa < 0 || bb < 0) { continue; }
        ax = i64_of(d, js_at(d, aa, 0));
        ay = i64_of(d, js_at(d, aa, 1));
        bx = i64_of(d, js_at(d, bb, 0));
        by = i64_of(d, js_at(d, bb, 1));

        /* i32::MIN / i32::MAX appear here; they exceed EB_COORD_MAX, so the
         * hexagonal norm would overflow uint64_t. Out of reach, not wrong. */
        if (!eb_coord_ok((int32_t)ax) || !eb_coord_ok((int32_t)ay) ||
            !eb_coord_ok((int32_t)bx) || !eb_coord_ok((int32_t)by)) {
            skipped++;
            continue;
        }
        if (!js_u64(d, need(d, r, "z2",  "dist_sq", i), &z2))  { skipped++; continue; }
        if (!js_u64(d, need(d, r, "hex", "dist_sq", i), &hex)) { skipped++; continue; }

        expect("dist_sq", i, "z2",
               (long long)eb_dist_sq_z2((int32_t)ax, (int32_t)ay, (int32_t)bx, (int32_t)by),
               (long long)z2);
        expect("dist_sq", i, "hex",
               (long long)eb_dist_sq_hex((int32_t)ax, (int32_t)ay, (int32_t)bx, (int32_t)by),
               (long long)hex);
        /* Z^1 is not in the file (the Rust generator only exercises it), so
         * check it against the definition the same record already pins down. */
        expect("dist_sq", i, "z1_component",
               (long long)eb_dist_sq_z1((int32_t)ax, (int32_t)bx),
               (long long)((ax - bx) * (ax - bx)));
    }
}

static void run_banded(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r   = js_at(d, arr, i);
        int aj  = need(d, r, "a", "banded_narrow", i);
        int bj  = need(d, r, "b", "banded_narrow", i);
        int res = need(d, r, "result", "banded_narrow", i);
        int want_overlaps;
        eb_banded_t a, b;
        eb_narrowed_t got;
        const char *kind;

        if (aj < 0 || bj < 0 || res < 0) { continue; }
        a.value  = (int32_t)i64_of(d, need(d, aj, "v", "banded_narrow", i));
        a.radius = (uint32_t)i64_of(d, need(d, aj, "r", "banded_narrow", i));
        b.value  = (int32_t)i64_of(d, need(d, bj, "v", "banded_narrow", i));
        b.radius = (uint32_t)i64_of(d, need(d, bj, "r", "banded_narrow", i));

        want_overlaps = js_bool(d, need(d, r, "overlaps", "banded_narrow", i));
        expect("banded_narrow", i, "overlaps",
               eb_banded_overlaps(a, b) ? 1 : 0, want_overlaps ? 1 : 0);

        got  = eb_banded_narrow(a, b);
        kind = js_text(d, need(d, res, "kind", "banded_narrow", i));
        if (!kind) { failures++; continue; }

        if (strcmp(kind, "tightened") == 0) {
            expect("banded_narrow", i, "kind", got.kind, EB_TIGHTENED);
            if (got.kind == EB_TIGHTENED) {
                expect("banded_narrow", i, "value", got.band.value,
                       i64_of(d, need(d, res, "value", "banded_narrow", i)));
                expect("banded_narrow", i, "radius", got.band.radius,
                       i64_of(d, need(d, res, "radius", "banded_narrow", i)));
            }
        } else if (strcmp(kind, "contradiction") == 0) {
            uint64_t gap_sq = 0, gap = 0;
            expect("banded_narrow", i, "kind", got.kind, EB_CONTRADICTION);
            if (!js_u64(d, need(d, res, "gap_sq", "banded_narrow", i), &gap_sq) ||
                !js_u64(d, need(d, res, "gap",    "banded_narrow", i), &gap)) {
                skipped++;
                continue;
            }
            expect("banded_narrow", i, "gap_sq", (long long)got.gap_sq, (long long)gap_sq);
            expect("banded_narrow", i, "gap",
                   (long long)eb_narrowed_gap(got), (long long)gap);
        } else {
            failures++;
            fprintf(stderr, "FAIL banded_narrow[%d]: unknown kind \"%s\"\n", i, kind);
        }
    }
}

static void run_ibox(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r   = js_at(d, arr, i);
        int aj  = need(d, r, "a", "ibox_narrow", i);
        int bj  = need(d, r, "b", "ibox_narrow", i);
        int res = need(d, r, "result", "ibox_narrow", i);
        eb_ibox_t a, b, out;
        int ok;
        const char *kind;

        if (aj < 0 || bj < 0 || res < 0) { continue; }
        a.lo = i64_of(d, js_at(d, aj, 0));
        a.hi = i64_of(d, js_at(d, aj, 1));
        b.lo = i64_of(d, js_at(d, bj, 0));
        b.hi = i64_of(d, js_at(d, bj, 1));

        expect("ibox_narrow", i, "a_empty", eb_ibox_empty(a) ? 1 : 0,
               js_bool(d, need(d, r, "a_empty", "ibox_narrow", i)) ? 1 : 0);
        expect("ibox_narrow", i, "b_empty", eb_ibox_empty(b) ? 1 : 0,
               js_bool(d, need(d, r, "b_empty", "ibox_narrow", i)) ? 1 : 0);

        out.lo = 0; out.hi = 0;
        ok   = eb_ibox_narrow(a, b, &out);
        kind = js_text(d, need(d, res, "kind", "ibox_narrow", i));
        if (!kind) { failures++; continue; }

        if (strcmp(kind, "box") == 0) {
            expect("ibox_narrow", i, "narrowed", ok, 1);
            if (ok) {
                expect("ibox_narrow", i, "lo", (long long)out.lo,
                       i64_of(d, need(d, res, "lo", "ibox_narrow", i)));
                expect("ibox_narrow", i, "hi", (long long)out.hi,
                       i64_of(d, need(d, res, "hi", "ibox_narrow", i)));
            }
            expect("ibox_narrow", i, "disagreement_zero",
                   (long long)eb_ibox_disagreement(a, b), 0);
        } else if (strcmp(kind, "disjoint") == 0) {
            int axis = js_get(d, res, "axis");
            int gapj = js_get(d, res, "gap");
            expect("ibox_narrow", i, "narrowed", ok, 0);
            /* One axis, so the generator's axis index is always 0 when set. */
            if (axis >= 0 && js_kind(d, axis) == JS_NUM) {
                expect("ibox_narrow", i, "axis", i64_of(d, axis), 0);
            }
            if (gapj >= 0 && js_kind(d, gapj) == JS_NUM) {
                expect("ibox_narrow", i, "gap",
                       (long long)eb_ibox_disagreement(a, b), i64_of(d, gapj));
            }
        } else {
            failures++;
            fprintf(stderr, "FAIL ibox_narrow[%d]: unknown kind \"%s\"\n", i, kind);
        }
    }
}

static void run_dist_sq_z1(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r = js_at(d, arr, i);
        int64_t a = i64_of(d, need(d, r, "a", "dist_sq_z1", i));
        int64_t b = i64_of(d, need(d, r, "b", "dist_sq_z1", i));
        uint64_t want;
        /* No skip here, deliberately: one squared term of an int32 difference
         * is at most (2^32-1)^2, which fits uint64_t with room to spare. The
         * whole int32 range is in reach for Z^1, and quoting the hexagonal
         * limit here would refuse inputs this port handles exactly. */
        if (!js_u64(d, need(d, r, "d2", "dist_sq_z1", i), &want)) { skipped++; continue; }
        expect("dist_sq_z1", i, "d2",
               (long long)eb_dist_sq_z1((int32_t)a, (int32_t)b), (long long)want);
        expect("dist_sq_z1", i, "coord_ok_dim1",
               eb_coord_ok_dim((int32_t)a, 1u), 1);
    }
}

static void run_dist_sq_z3(const js_doc_t *d, int arr)
{
    int i, k, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r  = js_at(d, arr, i);
        int aj = need(d, r, "a", "dist_sq_z3", i);
        int bj = need(d, r, "b", "dist_sq_z3", i);
        int32_t a[3], b[3];
        uint64_t want;
        int in_range = 1;

        if (aj < 0 || bj < 0) { continue; }
        for (k = 0; k < 3; k++) {
            a[k] = (int32_t)i64_of(d, js_at(d, aj, k));
            b[k] = (int32_t)i64_of(d, js_at(d, bj, k));
            if (!eb_coord_ok_dim(a[k], 3u) || !eb_coord_ok_dim(b[k], 3u)) {
                in_range = 0;
            }
        }
        if (!in_range) { skipped++; continue; }
        if (!js_u64(d, need(d, r, "d2", "dist_sq_z3", i), &want)) { skipped++; continue; }
        expect("dist_sq_z3", i, "d2", (long long)eb_dist_sq_z3(a, b), (long long)want);
    }
}

static void run_banded_within(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r  = js_at(d, arr, i);
        int aj = need(d, r, "a", "banded_within", i);
        int bj = need(d, r, "b", "banded_within", i);
        eb_banded_t a, b;

        if (aj < 0 || bj < 0) { continue; }
        a.value  = (int32_t)i64_of(d, need(d, aj, "v", "banded_within", i));
        a.radius = (uint32_t)i64_of(d, need(d, aj, "r", "banded_within", i));
        b.value  = (int32_t)i64_of(d, need(d, bj, "v", "banded_within", i));
        b.radius = (uint32_t)i64_of(d, need(d, bj, "r", "banded_within", i));

        expect("banded_within", i, "a_within_b", eb_banded_within(a, b) ? 1 : 0,
               js_bool(d, need(d, r, "a_within_b", "banded_within", i)) ? 1 : 0);
        expect("banded_within", i, "b_within_a", eb_banded_within(b, a) ? 1 : 0,
               js_bool(d, need(d, r, "b_within_a", "banded_within", i)) ? 1 : 0);
        /* Containment implies overlap, in both directions. A port that mixed up
         * the two predicates satisfies neither field on its own but breaks this. */
        if (eb_banded_within(a, b) || eb_banded_within(b, a)) {
            expect("banded_within", i, "within_implies_overlap",
                   eb_banded_overlaps(a, b) ? 1 : 0, 1);
        }
    }
}

static void run_from_basis(const js_doc_t *d, int arr)
{
    static const char *keys[3] = { "radius_dim1", "radius_dim2", "radius_dim3" };
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r = js_at(d, arr, i);
        int64_t basis = i64_of(d, need(d, r, "basis", "from_basis", i));
        uint32_t dim;
        for (dim = 1u; dim <= 3u; dim++) {
            int64_t want = i64_of(d, need(d, r, keys[dim - 1u], "from_basis", i));
            uint32_t got = eb_banded_from_basis(0, (uint32_t)basis, dim).radius;
            uint64_t target, g;
            expect("from_basis", i, keys[dim - 1u], (long long)got, (long long)want);
            /* Soundness and minimality, checked directly rather than only
             * against the recorded number: a band that rounded DOWN would
             * understate the very uncertainty it exists to carry. */
            target = (uint64_t)dim * (uint64_t)basis * (uint64_t)basis;
            g = (uint64_t)got;
            expect("from_basis", i, "covers", 4u * g * g >= target, 1);
            if (got > 0u) {
                expect("from_basis", i, "minimal",
                       4u * (g - 1u) * (g - 1u) < target, 1);
            }
        }
    }
}

static void run_ibox2(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    int saw_axis0 = 0, saw_axis1 = 0;
    for (i = 0; i < n; i++) {
        int r   = js_at(d, arr, i);
        int aj  = need(d, r, "a", "ibox2_narrow", i);
        int bj  = need(d, r, "b", "ibox2_narrow", i);
        int res = need(d, r, "result", "ibox2_narrow", i);
        eb_ibox_t a[2], b[2], out[2];
        int ok, k;
        const char *kind;

        if (aj < 0 || bj < 0 || res < 0) { continue; }
        for (k = 0; k < 2; k++) {
            a[k].lo = i64_of(d, js_at(d, js_get(d, aj, "lo"), k));
            a[k].hi = i64_of(d, js_at(d, js_get(d, aj, "hi"), k));
            b[k].lo = i64_of(d, js_at(d, js_get(d, bj, "lo"), k));
            b[k].hi = i64_of(d, js_at(d, js_get(d, bj, "hi"), k));
        }
        ok   = eb_ibox_narrow_n(a, b, 2u, out);
        kind = js_text(d, need(d, res, "kind", "ibox2_narrow", i));
        if (!kind) { failures++; continue; }

        if (strcmp(kind, "box") == 0) {
            expect("ibox2_narrow", i, "narrowed", ok, 1);
            if (ok) {
                int lo = js_get(d, res, "lo"), hi = js_get(d, res, "hi");
                for (k = 0; k < 2; k++) {
                    expect("ibox2_narrow", i, "lo", (long long)out[k].lo,
                           i64_of(d, js_at(d, lo, k)));
                    expect("ibox2_narrow", i, "hi", (long long)out[k].hi,
                           i64_of(d, js_at(d, hi, k)));
                }
            }
            expect("ibox2_narrow", i, "no_disagreement",
                   eb_ibox_disagreement_n(a, b, 2u, 0, 0), 0);
        } else if (strcmp(kind, "disjoint") == 0) {
            uint32_t axis = 0u;
            uint64_t gap = 0u;
            expect("ibox2_narrow", i, "narrowed", ok, 0);
            expect("ibox2_narrow", i, "disagrees",
                   eb_ibox_disagreement_n(a, b, 2u, &axis, &gap), 1);
            expect("ibox2_narrow", i, "axis", (long long)axis,
                   i64_of(d, need(d, res, "axis", "ibox2_narrow", i)));
            expect("ibox2_narrow", i, "gap", (long long)gap,
                   i64_of(d, need(d, res, "gap", "ibox2_narrow", i)));
            if (axis == 0u) { saw_axis0 = 1; } else { saw_axis1 = 1; }
        } else {
            failures++;
            fprintf(stderr, "FAIL ibox2_narrow[%d]: unknown kind \"%s\"\n", i, kind);
        }
    }
    /* The point of the two-dimensional section is that `disagreement` has a
     * choice to make. If every disjoint case were worst on the same axis, a
     * port returning the FIRST disagreeing axis would still pass. */
    if (!saw_axis0 || !saw_axis1) {
        failures++;
        fprintf(stderr, "FAIL ibox2_narrow: fixture never makes both axes the "
                        "worst one, so the axis choice is not being tested\n");
    }
}

static void run_phase(const js_doc_t *d, int arr)
{
    int i, n = js_len(d, arr);
    for (i = 0; i < n; i++) {
        int r = js_at(d, arr, i);
        int64_t nn   = i64_of(d, need(d, r, "n", "phase", i));
        int64_t a    = i64_of(d, need(d, r, "a", "phase", i));
        int64_t b    = i64_of(d, need(d, r, "b", "phase", i));
        int64_t dist = i64_of(d, need(d, r, "distance", "phase", i));
        int64_t off  = i64_of(d, need(d, r, "offset", "phase", i));

        expect("phase", i, "distance",
               (long long)eb_phase_distance((uint32_t)nn, a, b), (long long)dist);
        expect("phase", i, "offset",
               (long long)eb_phase_offset((uint32_t)nn, a, b), (long long)off);
        /* |offset| == distance is the invariant the two functions must share;
         * checking it here catches a substrate that satisfies each vector
         * field independently while disagreeing about what they mean. */
        {
            int64_t got = eb_phase_offset((uint32_t)nn, a, b);
            int64_t mag = got < 0 ? -got : got;
            expect("phase", i, "|offset|==distance", (long long)mag,
                   (long long)eb_phase_distance((uint32_t)nn, a, b));
        }
    }
}

/* ---- driver ------------------------------------------------------------- */

/* Every vector this substrate cannot represent, enumerated. Asserting the
 * total keeps a widening skip set from quietly eroding coverage. */
#define EXPECTED_SKIPS 13
/* 1 isqrt (u128::MAX)
 * 3 dist_sq  (i32 extremes, on the hexagonal norm's 3-term budget)
 * 9 dist_sq_z3 (the three i32-extreme triples, against each of three partners)
 * 0 dist_sq_z1 -- the whole int32 range is in reach for one squared term */

int main(int argc, char **argv)
{
    const char *path = (argc > 1) ? argv[1] : "tests/vectors.json";
    const char *err = NULL;
    js_doc_t *d;
    int root, sec, i;
    static const char *sections[] = {
        "covering", "isqrt", "dist_sq", "dist_sq_z1", "dist_sq_z3",
        "banded_narrow", "banded_within", "from_basis",
        "ibox_narrow", "ibox2_narrow", "phase"
    };
    int total = 0;

    d = js_parse_file(path, &err);
    if (!d) {
        fprintf(stderr, "cannot read %s: %s\n", path, err ? err : "unknown error");
        return 2;
    }
    root = js_root(d);
    if (js_kind(d, root) != JS_OBJ) {
        fprintf(stderr, "%s: root is not an object\n", path);
        js_free(d);
        return 2;
    }

    /* Every section must be present: a renamed or dropped section would
     * otherwise pass as vacuously green. */
    for (i = 0; i < (int)(sizeof sections / sizeof sections[0]); i++) {
        sec = js_get(d, root, sections[i]);
        if (sec < 0 || js_kind(d, sec) != JS_ARR || js_len(d, sec) == 0) {
            fprintf(stderr, "FAIL: section \"%s\" missing or empty\n", sections[i]);
            failures++;
            continue;
        }
        total += js_len(d, sec);
    }
    if (failures) { js_free(d); return 1; }

    run_covering(d, js_get(d, root, "covering"));
    run_isqrt   (d, js_get(d, root, "isqrt"));
    run_dist_sq (d, js_get(d, root, "dist_sq"));
    run_dist_sq_z1(d, js_get(d, root, "dist_sq_z1"));
    run_dist_sq_z3(d, js_get(d, root, "dist_sq_z3"));
    run_banded  (d, js_get(d, root, "banded_narrow"));
    run_banded_within(d, js_get(d, root, "banded_within"));
    run_from_basis   (d, js_get(d, root, "from_basis"));
    run_ibox    (d, js_get(d, root, "ibox_narrow"));
    run_ibox2   (d, js_get(d, root, "ibox2_narrow"));
    run_phase   (d, js_get(d, root, "phase"));

    printf("vectors: %d   checks: %d   skipped (out of 64-bit range): %d\n",
           total, checks, skipped);

    if (skipped != EXPECTED_SKIPS) {
        fprintf(stderr,
                "FAIL: skipped %d vectors, expected exactly %d. The set of "
                "vectors this substrate cannot represent changed -- update "
                "EXPECTED_SKIPS deliberately, with the reason.\n",
                skipped, EXPECTED_SKIPS);
        failures++;
    }

    js_free(d);
    if (failures) {
        fprintf(stderr, "\n%d FAILURE(S)\n", failures);
        return 1;
    }
    printf("PASS: C substrate agrees with the Rust and Python substrates.\n");
    return 0;
}
