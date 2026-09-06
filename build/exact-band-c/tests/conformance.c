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
#define EXPECTED_SKIPS 4   /* 1 isqrt (u128::MAX) + 3 dist_sq (i32 extremes) */

int main(int argc, char **argv)
{
    const char *path = (argc > 1) ? argv[1] : "tests/vectors.json";
    const char *err = NULL;
    js_doc_t *d;
    int root, sec, i;
    static const char *sections[] = {
        "covering", "isqrt", "dist_sq", "banded_narrow", "ibox_narrow", "phase"
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
    run_banded  (d, js_get(d, root, "banded_narrow"));
    run_ibox    (d, js_get(d, root, "ibox_narrow"));
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
