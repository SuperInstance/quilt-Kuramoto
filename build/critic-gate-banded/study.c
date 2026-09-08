/* study.c -- is `dissent` a sound proxy for "this reading cannot be judged"?
 *
 * SuperInstance/quilt-esp32's firmware/critic_gate.c is a 6-channel integer
 * band gate running on real ESP32-S3 hardware. It is good code: integer-only,
 * no floats on host or metal, host and firmware compiling the same file so the
 * replay compares what the board runs. An earlier note of mine suggested
 * swapping exact-band into it. That was wrong, and this study is the
 * correction: the arithmetic there is already exact, so a swap would be a
 * refactor, not a fix.
 *
 * The real gap is elsewhere. The gate judges a channel reading as a POINT
 * against a band [lo, hi]. Real readings carry measurement tolerance. The gate
 * acknowledges this with `dissent` -- a flag raised when a reading sits within
 * GATE_QM_DISSENT_EPS of an edge, or in the gray zone -- described in its own
 * header as "the ambiguity embryo".
 *
 * `dissent` is a FIXED proximity threshold (20000 micro-units) that does not
 * depend on how uncertain the reading actually is. So the question this study
 * asks is empirical, and its answer could well be "the heuristic is fine":
 *
 *   For a reading known to within +/- tau, how often is the point verdict
 *   confident where the true verdict is UNRESOLVABLE, and does `dissent`
 *   catch those cases?
 *
 * A proxy that MISSES unresolvable cases is unsound -- the board commits to a
 * verdict it cannot support. One that over-flags is merely noisy. This
 * measures both, across tau, using the vendored constants unchanged.
 */

#include "vendored_gate_qm.h"

#include <stdio.h>
#include <string.h>

#define SEV_OK 0
#define SEV_WARN 1
#define SEV_BAD 2

/* ---- the gate's own semantics, reproduced exactly ------------------------ */

static int32_t point_sev(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    const int32_t amb = GATE_QM_AMBIGUITY;
    if (v < lo - amb || v > hi + amb) { return SEV_BAD; }
    if (v < lo || v > hi) { return SEV_WARN; }
    return SEV_OK;
}

static int point_dissent(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    int32_t dlo = v - lo, dhi = v - hi;
    int32_t dist;
    if (dlo < 0) { dlo = -dlo; }
    if (dhi < 0) { dhi = -dhi; }
    dist = (dlo <= dhi) ? dlo : dhi;
    return (dist <= GATE_QM_DISSENT_EPS || point_sev(ch, v) == SEV_WARN) ? 1 : 0;
}

/* ---- the banded question ------------------------------------------------- */

/* A reading known to within +/- tau spans [v-tau, v+tau]. Its severity is
 * RESOLVED only if every point in that interval lands in the same severity
 * band; otherwise the reading does not determine the verdict, whatever the
 * point value happens to be. This is exact interval reasoning -- no
 * approximation, just the honest question. */
static int sev_resolved(int ch, int32_t v, int32_t tau, int32_t *sev_out)
{
    int32_t s_lo = point_sev(ch, v - tau);
    int32_t s_hi = point_sev(ch, v + tau);
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    const int32_t amb = GATE_QM_AMBIGUITY;
    /* Severity is not monotone in v -- it is BAD, WARN, OK, WARN, BAD as v
     * sweeps upward -- so equal endpoints are not sufficient. Check that no
     * boundary lies strictly inside the interval. */
    const int32_t edges[4] = { lo - amb, lo, hi, hi + amb };
    int i;
    for (i = 0; i < 4; i++) {
        if (v - tau < edges[i] && edges[i] <= v + tau) { return 0; }
    }
    if (s_lo != s_hi) { return 0; }
    *sev_out = s_lo;
    return 1;
}

/* ---- deterministic sweep ------------------------------------------------- */

static uint64_t rs;
static uint64_t nxt(void)
{
    uint64_t x = rs;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    rs = x;
    return x;
}

int main(void)
{
    static const int32_t TAUS[] = { 1000, 5000, 20000, 50000, 100000 };
    const long TRIALS = 400000;
    int ti;

    printf("Is `dissent` a sound proxy for \"this reading cannot be judged\"?\n\n");
    printf("Readings drawn uniformly across each channel's plausible range,\n");
    printf("%ld trials per tau, using quilt-esp32's own band constants.\n", TRIALS);
    printf("DISSENT_EPS is fixed at %d micro-units.\n\n", GATE_QM_DISSENT_EPS);
    printf("  %8s  %10s  %12s  %12s  %10s\n",
           "tau", "unresolved", "missed", "false alarms", "verdict");
    printf("  %8s  %10s  %12s  %12s  %10s\n",
           "", "(of all)", "(UNSOUND)", "(noise)", "flips");

    for (ti = 0; ti < (int)(sizeof TAUS / sizeof TAUS[0]); ti++) {
        const int32_t tau = TAUS[ti];
        long unresolved = 0, missed = 0, false_alarm = 0, verdict_flip = 0;
        long t;
        rs = 0x2545F4914F6CDD1DULL;

        for (t = 0; t < TRIALS; t++) {
            int32_t feats[GATE_QM_N_CHANNELS];
            int any_unresolved = 0;
            int i;
            long pen_lo = 0, pen_hi = 0;

            for (i = 0; i < GATE_QM_N_CHANNELS; i++) {
                /* Span the band plus a margin either side, so edges are hit. */
                int32_t lo = gate_qm_bands[i].lo, hi = gate_qm_bands[i].hi;
                int32_t span = (hi - lo) + 4 * GATE_QM_AMBIGUITY;
                int32_t base = lo - 2 * GATE_QM_AMBIGUITY;
                int32_t v = base + (int32_t)(nxt() % (uint64_t)span);
                int32_t sev = 0;
                int resolved = sev_resolved(i, v, tau, &sev);
                int diss = point_dissent(i, v);

                feats[i] = v;
                if (!resolved) {
                    unresolved++;
                    any_unresolved = 1;
                    if (!diss) { missed++; }        /* committed without support */
                } else if (diss && sev == SEV_OK) {
                    false_alarm++;                  /* flagged, but resolvable */
                }

                /* Penalty range over the interval, for the bar-level verdict. */
                {
                    int32_t s1 = point_sev(i, v - tau), s2 = point_sev(i, v + tau);
                    int32_t smin = s1 < s2 ? s1 : s2, smax = s1 > s2 ? s1 : s2;
                    if (!resolved) { smin = SEV_OK; smax = SEV_BAD; }
                    pen_lo += smin == SEV_BAD ? GATE_QM_PENALTY_BAD
                            : smin == SEV_WARN ? GATE_QM_PENALTY_WARN : 0;
                    pen_hi += smax == SEV_BAD ? GATE_QM_PENALTY_BAD
                            : smax == SEV_WARN ? GATE_QM_PENALTY_WARN : 0;
                }
            }
            (void)feats;
            (void)any_unresolved;
            /* The bar verdict is unresolvable when the penalty range straddles
             * the revise threshold: the same reading could accept or revise. */
            if (pen_lo < GATE_QM_REVISE_THRESHOLD && pen_hi >= GATE_QM_REVISE_THRESHOLD) {
                verdict_flip++;
            }
        }

        printf("  %8d  %9.2f%%  %11.3f%%  %11.2f%%  %9.2f%%\n", tau,
               100.0 * (double)unresolved / (double)(TRIALS * GATE_QM_N_CHANNELS),
               100.0 * (double)missed / (double)(TRIALS * GATE_QM_N_CHANNELS),
               100.0 * (double)false_alarm / (double)(TRIALS * GATE_QM_N_CHANNELS),
               100.0 * (double)verdict_flip / (double)TRIALS);
    }

    printf("\n`missed` is the column that matters: a reading the band says is\n");
    printf("unresolvable that `dissent` did NOT flag, so the gate committed to\n");
    printf("a severity its own measurement cannot support.\n");
    return 0;
}
