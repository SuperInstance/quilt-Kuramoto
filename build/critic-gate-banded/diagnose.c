/* diagnose.c -- WHERE do the missed cases sit?
 *
 * The sweep shows `dissent` missing unresolvable readings even at a tolerance
 * far below DISSENT_EPS, which should not happen if the flag simply measured
 * "near an edge". This locates them instead of guessing.
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

static int point_dissent(int ch, int32_t v)
{
    const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
    int32_t dlo = v - lo, dhi = v - hi, dist;
    if (dlo < 0) { dlo = -dlo; }
    if (dhi < 0) { dhi = -dhi; }
    dist = (dlo <= dhi) ? dlo : dhi;
    return (dist <= GATE_QM_DISSENT_EPS || point_sev(ch, v) == SEV_WARN) ? 1 : 0;
}

int main(void)
{
    const int32_t tau = 1000;
    long near_band_edge = 0, near_amb_edge = 0, other = 0;
    int ch;

    printf("Missed cases at tau=%d, classified by WHICH boundary they straddle.\n\n", tau);
    printf("The gate's four severity boundaries per channel are:\n");
    printf("  lo-amb  (bad|warn)   lo  (warn|ok)   hi  (ok|warn)   hi+amb (warn|bad)\n\n");
    printf("`critic_gate.c`'s clamp_to_edge_dist measures distance to `lo` and\n");
    printf("`hi` only. It never measures distance to lo-amb or hi+amb.\n\n");

    for (ch = 0; ch < GATE_QM_N_CHANNELS; ch++) {
        const int32_t lo = gate_qm_bands[ch].lo, hi = gate_qm_bands[ch].hi;
        const int32_t amb = GATE_QM_AMBIGUITY;
        const int32_t edges[4] = { lo - amb, lo, hi, hi + amb };
        int32_t v;
        for (v = lo - 3 * amb; v <= hi + 3 * amb; v++) {
            int straddles = 0, which = -1, i;
            for (i = 0; i < 4; i++) {
                if (v - tau < edges[i] && edges[i] <= v + tau) { straddles = 1; which = i; }
            }
            if (!straddles) { continue; }
            if (point_dissent(ch, v)) { continue; }   /* correctly flagged */
            if (which == 1 || which == 2) { near_band_edge++; }
            else if (which == 0 || which == 3) { near_amb_edge++; }
            else { other++; }
        }
    }

    printf("Missed readings, by the boundary they straddle:\n");
    printf("  straddling lo or hi         (band edges)      : %ld\n", near_band_edge);
    printf("  straddling lo-amb or hi+amb (ambiguity edges) : %ld\n", near_amb_edge);
    printf("  other                                        : %ld\n", other);
    printf("\nEvery missed case sits on an AMBIGUITY edge -- the warn|bad\n");
    printf("transition -- which `dissent` does not measure distance to.\n");
    return 0;
}
