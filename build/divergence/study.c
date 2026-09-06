/* study.c -- what does exact integer arithmetic actually buy?
 *
 * Measured, against an exact reference, and reported including the parts that
 * do not favour integers.
 *
 * THE QUESTION
 * ------------
 * A specification says: "the ensemble agrees if the mean pairwise phase offset
 * is within tolerance". Summing a set has no canonical order -- index order,
 * reverse order, pairwise reduction and a single-precision accumulator are all
 * faithful readings of that sentence, and a hash-map iteration or a parallel
 * reduce gives yet another. Floating-point addition is not associative, so they
 * produce different values.
 *
 * The question is not whether the VALUES differ -- they always do. It is whether
 * the ANSWER differs, and how close to the tolerance you have to be before it
 * does.
 *
 * GROUND TRUTH
 * ------------
 * Inputs are generated as exact integers in nanodegrees, and the reference
 * answer is their exact sum in 128-bit integers. Every implementation is scored
 * against that, so "correct" is not a vote among the candidates.
 *
 * THE TRADE, STATED UP FRONT
 * --------------------------
 * The integer path quantises to microdegrees before summing, so it has an error
 * the double path does not: up to half a microdegree per reading. That is
 * LARGER than double-precision rounding error, and this study measures it
 * rather than hiding it.
 *
 * What the integer path buys is not a smaller error. It is an error that is
 * bounded, deterministic, and IDENTICAL across every implementation and
 * platform. The float error is smaller and unpredictable; the integer error is
 * larger and always the same. Which of those you want depends on whether your
 * failures are quiet or loud.
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint64_t rs;
static void seed(uint64_t s) { rs = s; }
static uint64_t nx(void)
{
    uint64_t x = rs;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    rs = x;
    return x;
}

#define MAXN 64
#define NANO_PER_DEG   1000000000LL
#define NANO_PER_MICRO 1000LL

/* ---- four correct float implementations --------------------------------- */

static double sum_index(const double *v, int n)
{
    double s = 0.0; int i;
    for (i = 0; i < n; i++) { s += v[i]; }
    return s;
}
static double sum_reverse(const double *v, int n)
{
    double s = 0.0; int i;
    for (i = n - 1; i >= 0; i--) { s += v[i]; }
    return s;
}
static double sum_pairwise(const double *v, int n)
{
    double buf[MAXN]; int m = n, i;
    memcpy(buf, v, (size_t)n * sizeof(double));
    while (m > 1) {
        int half = m / 2;
        for (i = 0; i < half; i++) { buf[i] = buf[2 * i] + buf[2 * i + 1]; }
        if (m % 2) { buf[half] = buf[m - 1]; m = half + 1; } else { m = half; }
    }
    return buf[0];
}
static double sum_f32(const double *v, int n)
{
    float s = 0.0f; int i;
    for (i = 0; i < n; i++) { s += (float)v[i]; }
    return (double)s;
}

/* ---- the integer implementation, in three traversals --------------------- */

static int64_t isum_index(const int64_t *v, int n)
{
    int64_t s = 0; int i;
    for (i = 0; i < n; i++) { s += v[i]; }
    return s;
}
static int64_t isum_reverse(const int64_t *v, int n)
{
    int64_t s = 0; int i;
    for (i = n - 1; i >= 0; i--) { s += v[i]; }
    return s;
}
static int64_t isum_pairwise(const int64_t *v, int n)
{
    int64_t buf[MAXN]; int m = n, i;
    memcpy(buf, v, (size_t)n * sizeof(int64_t));
    while (m > 1) {
        int half = m / 2;
        for (i = 0; i < half; i++) { buf[i] = buf[2 * i] + buf[2 * i + 1]; }
        if (m % 2) { buf[half] = buf[m - 1]; m = half + 1; } else { m = half; }
    }
    return buf[0];
}

/* ---- one trial ----------------------------------------------------------- */

struct row {
    long trials;
    long float_disagree;   /* the four float variants do not all agree */
    long float_wrong[4];   /* each variant, against the exact reference */
    long int_disagree;     /* the three integer traversals do not all agree */
    long int_wrong;        /* plain integer differs from the reference */
    long band_wrong;       /* BANDED integer commits to a wrong answer */
    long band_unknown;     /* BANDED integer declines to answer */
};

/* `offset_nano` is the signed distance from the tolerance boundary, in
 * nanodegrees. Sweeping it is the whole experiment: it says how close you have
 * to be before the arithmetic decides the answer. */
static void trial(struct row *r, int n, int64_t offset_nano)
{
    int64_t tol_nano = 250000000LL;              /* 0.25 degrees */
    int64_t want_total = (tol_nano + offset_nano) * n;
    int64_t vn[MAXN], vu[MAXN];
    double vd[MAXN];
    int i;
    /* The exact reference sum, in int64_t rather than __int128 -- which is not
     * ISO C, and is not needed. Each value is at most
     * |tol| + |offset| + |jitter| = 2.5e8 + 1e7 + 1e9 < 1.3e9 nanodegrees, and
     * the last is at most the total minus the rest, under 1e11. Sixty-four of
     * those is under 1e12, against an int64_t ceiling of 9.2e18. */
    int64_t exact = 0;

    /* Build n values in nanodegrees summing exactly to want_total, spread over
     * +-1 degree so cancellation is in play -- a tight cluster would hide
     * non-associativity, which would flatter the float path. */
    {
        int64_t acc = 0;
        for (i = 0; i < n - 1; i++) {
            int64_t jitter = (int64_t)(nx() % 2000000001ULL) - 1000000000LL;
            vn[i] = (tol_nano + offset_nano) + jitter;
            acc += vn[i];
        }
        vn[n - 1] = want_total - acc;
    }

    for (i = 0; i < n; i++) {
        exact += vn[i];
        vd[i] = (double)vn[i] / (double)NANO_PER_DEG;
        /* Quantise to microdegrees, rounding half away from zero -- exactly what
         * a fixed-point sensor pipeline does. */
        vu[i] = (vn[i] >= 0)
              ? (vn[i] + NANO_PER_MICRO / 2) / NANO_PER_MICRO
              : -((-vn[i] + NANO_PER_MICRO / 2) / NANO_PER_MICRO);
    }

    /* Reference: exact, in 128-bit integers. mean <= tol  <=>  sum <= tol*n. */
    {
        int ref = (exact <= tol_nano * n);
        double tol_deg = 0.25;
        double dn = (double)n;
        int a = (sum_index(vd, n)    / dn) <= tol_deg;
        int b = (sum_reverse(vd, n)  / dn) <= tol_deg;
        int c = (sum_pairwise(vd, n) / dn) <= tol_deg;
        int d = (sum_f32(vd, n)      / dn) <= tol_deg;
        int64_t tol_micro = tol_nano / NANO_PER_MICRO;
        int ia = isum_index(vu, n)    <= tol_micro * n;
        int ib = isum_reverse(vu, n)  <= tol_micro * n;
        int ic = isum_pairwise(vu, n) <= tol_micro * n;

        if (a != b || a != c || a != d) { r->float_disagree++; }
        if (a != ref) { r->float_wrong[0]++; }
        if (b != ref) { r->float_wrong[1]++; }
        if (c != ref) { r->float_wrong[2]++; }
        if (d != ref) { r->float_wrong[3]++; }
        if (ia != ib || ia != ic) { r->int_disagree++; }
        if (ia != ref) { r->int_wrong++; }

        /* The BANDED answer -- what this repo actually builds.
         *
         * Quantising to microdegrees costs at most half a microdegree per
         * reading, so the exact sum lies somewhere in [s - n/2, s + n/2]. That
         * bound is known, so carry it instead of pretending it is zero:
         *
         *   whole band below the threshold  -> AGREE, and it cannot be wrong
         *   whole band above it             -> DISAGREE, likewise
         *   band straddles it               -> SAY SO
         *
         * The third case is not a failure. It is the honest report that the
         * measurement does not resolve the question -- and it is precisely the
         * zone where the four float implementations quietly disagree with each
         * other while each returns a confident boolean.
         *
         * Half-microdegrees, so the n/2 bound stays an integer. */
        {
            int64_t s2   = 2 * isum_index(vu, n);      /* sum, doubled */
            int64_t thr2 = 2 * tol_micro * n;          /* threshold, doubled */
            int64_t slack = n;                         /* 2 * (n * 0.5) */
            if (s2 + slack <= thr2) {
                if (!ref) { r->band_wrong++; }         /* committed: agree */
            } else if (s2 - slack > thr2) {
                if (ref) { r->band_wrong++; }          /* committed: disagree */
            } else {
                r->band_unknown++;                     /* declined */
            }
        }
        r->trials++;
    }
}

/* Emitting the numbers as JSON keeps this to the same standard as the rest of
 * the repo: a figure quoted in a README has a committed artifact behind it. */
static int emit_json;
static int check_only;

int main(int argc, char **argv)
{
    int arg;
    int first_cell = 1;
    long total_float_disagree = 0;
    long total_band_wrong = 0;
    long total_int_disagree = 0;

    for (arg = 1; arg < argc; arg++) {
        if (strcmp(argv[arg], "--json") == 0) { emit_json = 1; }
        else if (strcmp(argv[arg], "--check") == 0) { check_only = 1; }
    }

    static const int64_t DISTANCES[] = {
        0, 1, 10, 100, 1000, 10000, 100000, 1000000, 10000000
    };
    static const char *LABELS[] = {
        "exactly on it", "1 ndeg", "10 ndeg", "100 ndeg", "1 udeg",
        "10 udeg", "100 udeg", "1 mdeg", "10 mdeg"
    };
    int sizes[3], si, k;
    long TRIALS = 200000;
    sizes[0] = 4; sizes[1] = 16; sizes[2] = 64;

    if (emit_json) { printf("{\n  \"trials_per_cell\": %ld,\n  \"cells\": [\n", TRIALS); }
    if (emit_json || check_only) { goto sweep; }

    printf("Four correct float implementations of one specification, and three\n");
    printf("traversals of the integer one, scored against an EXACT integer\n");
    printf("reference. %ld trials per cell. Tolerance is 0.25 degrees.\n", TRIALS);
    printf("\n\"disagree\" = the four float implementations do not all give the same\n");
    printf("answer.  \"worst wrong\" = the worst of the four, against the reference.\n");
    printf("\"int wrong\" = plain microdegree integers, which quantise and so can be\n");
    printf("wrong.  \"band wrong\" = the BANDED answer commits and is wrong.\n");
    printf("\"band unsure\" = the banded answer declines, because the quantisation\n");
    printf("bound straddles the threshold.\n");

sweep:
    for (si = 0; si < 3; si++) {
        if (!emit_json && !check_only) { printf("\n=== %d readings ===\n", sizes[si]); }
        if (!emit_json && !check_only) {
        printf("  distance from    float      float      int        int      band     band\n");
        printf("  the boundary     disagree   worst-wrong disagree  wrong    wrong    unsure\n");
        }
        for (k = 0; k < (int)(sizeof DISTANCES / sizeof DISTANCES[0]); k++) {
            struct row r;
            long t;
            memset(&r, 0, sizeof r);
            seed(0x2545F4914F6CDD1DULL + (uint64_t)(si * 100 + k));
            for (t = 0; t < TRIALS; t++) {
                /* Both sides of the boundary, alternating. */
                int64_t d = (t & 1) ? DISTANCES[k] : -DISTANCES[k];
                trial(&r, sizes[si], d);
            }
            {
                long worst = 0;
                int q;
                for (q = 0; q < 4; q++) {
                    if (r.float_wrong[q] > worst) { worst = r.float_wrong[q]; }
                }
                total_float_disagree += r.float_disagree;
                total_band_wrong     += r.band_wrong;
                total_int_disagree   += r.int_disagree;

                if (emit_json) {
                    if (!first_cell) { printf(",\n"); }
                    first_cell = 0;
                    printf("    {\"readings\": %d, \"distance_ndeg\": %lld, "
                           "\"float_disagree\": %ld, \"float_worst_wrong\": %ld, "
                           "\"int_disagree\": %ld, \"int_wrong\": %ld, "
                           "\"band_wrong\": %ld, \"band_unsure\": %ld}",
                           sizes[si], (long long)DISTANCES[k],
                           r.float_disagree, worst, r.int_disagree,
                           r.int_wrong, r.band_wrong, r.band_unknown);
                } else if (!check_only) {
                    printf("  %-15s %7.3f%%   %7.3f%%   %7.3f%%  %7.3f%% %7.3f%% %7.3f%%\n",
                           LABELS[k],
                           100.0 * (double)r.float_disagree / (double)r.trials,
                           100.0 * (double)worst           / (double)r.trials,
                           100.0 * (double)r.int_disagree  / (double)r.trials,
                           100.0 * (double)r.int_wrong     / (double)r.trials,
                           100.0 * (double)r.band_wrong    / (double)r.trials,
                           100.0 * (double)r.band_unknown  / (double)r.trials);
                }
            }
        }
    }
    if (emit_json) { printf("\n  ]\n}\n"); }

    /* The three claims this study makes, asserted rather than eyeballed. */
    {
        int bad = 0;
        if (total_band_wrong != 0) {
            fprintf(stderr, "FAIL: the banded answer committed and was WRONG "
                            "%ld times. It is supposed to decline instead.\n",
                    total_band_wrong);
            bad = 1;
        }
        if (total_int_disagree != 0) {
            fprintf(stderr, "FAIL: integer traversals disagreed %ld times. "
                            "Integer addition is associative; this cannot "
                            "happen unless something overflowed.\n",
                    total_int_disagree);
            bad = 1;
        }
        /* A negative control on the experiment itself. If the float variants
         * never disagreed, this study would be measuring nothing at all and
         * every conclusion drawn from it would be vacuous. */
        if (total_float_disagree == 0) {
            fprintf(stderr, "FAIL: the float implementations never disagreed, "
                            "so this experiment has no contrast and proves "
                            "nothing. Check the input generation.\n");
            bad = 1;
        }
        if (bad) { return 1; }
        if (check_only) {
            printf("divergence study: banded never wrong (%ld float "
                   "disagreements observed, so the contrast is real)\n",
                   total_float_disagree);
        }
    }
    return 0;
}
