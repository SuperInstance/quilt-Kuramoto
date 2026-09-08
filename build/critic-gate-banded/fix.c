/* fix.c -- the proposed correction, measured rather than asserted.
 *
 * `critic_gate.c`'s dissent distance considers only the band edges lo and hi.
 * The gate has FOUR severity boundaries per channel: lo-amb, lo, hi, hi+amb.
 * Readings straddling the two ambiguity edges -- the warn|bad transition -- are
 * therefore committed without a dissent flag.
 *
 * The correction is to measure distance to all four. This compares the two.
 */
#include "vendored_gate_qm.h"
#include <stdio.h>

#define SEV_OK 0
#define SEV_WARN 1
#define SEV_BAD 2

static int32_t point_sev(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    const int32_t amb = GATE_QM_AMBIGUITY;
    if (v < lo - amb || v > hi + amb) { return SEV_BAD; }
    if (v < lo || v > hi) { return SEV_WARN; }
    return SEV_OK;
}

static int32_t iabs(int32_t x) { return x < 0 ? -x : x; }

/* As shipped: distance to lo and hi only. */
static int dissent_current(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    int32_t dlo = iabs(v - lo), dhi = iabs(v - hi);
    int32_t dist = dlo <= dhi ? dlo : dhi;
    return (dist <= GATE_QM_DISSENT_EPS || point_sev(ch, v) == SEV_WARN) ? 1 : 0;
}

/* Proposed: distance to every severity boundary. Two extra comparisons, same
 * integer discipline, no allocation, no change to the band data or the .qm. */
static int dissent_fixed(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    const int32_t amb = GATE_QM_AMBIGUITY;
    const int32_t edges[4] = { lo - amb, lo, hi, hi + amb };
    int32_t best = iabs(v - edges[0]);
    int i;
    for (i = 1; i < 4; i++) {
        int32_t d = iabs(v - edges[i]);
        if (d < best) { best = d; }
    }
    return (best <= GATE_QM_DISSENT_EPS || point_sev(ch, v) == SEV_WARN) ? 1 : 0;
}

static int resolved(int ch, int32_t v, int32_t tau)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    const int32_t amb = GATE_QM_AMBIGUITY;
    const int32_t edges[4] = { lo - amb, lo, hi, hi + amb };
    int i;
    for (i = 0; i < 4; i++) {
        if (v - tau < edges[i] && edges[i] <= v + tau) { return 0; }
    }
    return 1;
}

int main(void)
{
    static const int32_t TAUS[] = { 1000, 5000, 10000, 20000 };
    int ti, ch;
    printf("Missed unresolvable readings (exhaustive over every integer value\n");
    printf("in each channel's range), current dissent vs the proposed fix.\n\n");
    printf("  %8s  %14s  %14s  %12s\n", "tau", "missed (now)", "missed (fixed)", "extra flags");
    for (ti = 0; ti < 4; ti++) {
        const int32_t tau = TAUS[ti];
        long now = 0, fixed = 0, extra = 0;
        for (ch = 0; ch < GATE_QM_N_CHANNELS; ch++) {
            const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
            int32_t v;
            for (v = lo - 3 * GATE_QM_AMBIGUITY; v <= hi + 3 * GATE_QM_AMBIGUITY; v++) {
                int unres = !resolved(ch, v, tau);
                int dc = dissent_current(ch, v), df = dissent_fixed(ch, v);
                if (unres && !dc) { now++; }
                if (unres && !df) { fixed++; }
                if (!dc && df) { extra++; }
            }
        }
        printf("  %8d  %14ld  %14ld  %12ld\n", tau, now, fixed, extra);
    }
    printf("\nThe fix costs two extra integer comparisons per channel and no\n");
    printf("change to the band data, the .qm artefact or its sha256 receipt.\n");
    return 0;
}
