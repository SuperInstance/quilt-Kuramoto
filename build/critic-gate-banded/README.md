# A finding in `quilt-esp32`'s critic gate

`SuperInstance/quilt-esp32`'s `firmware/critic_gate.c` is a 6-channel integer
band gate running on real ESP32-S3 hardware. It is good code — integer-only, no
floats on host or metal, host and firmware compiling the same file so the replay
compares what the board actually runs.

**First, a correction of my own.** I earlier suggested swapping `exact-band` into
it. That was wrong: the arithmetic there is already exact, so a swap would be a
refactor, not a fix. This is what I found instead, by running it.

## The finding

The gate raises a `dissent` flag for readings near a band edge — its header
calls this "the ambiguity embryo". Each channel has **four** severity
boundaries:

```
   lo−amb        lo              hi        hi+amb
  ────┼───────────┼───────────────┼───────────┼────
   bad │   warn    │      ok       │   warn    │ bad
```

`clamp_to_edge_dist` measures the distance to `lo` and `hi`. **It never measures
the distance to `lo−amb` or `hi+amb`.** So a reading sitting on the *warn|bad*
transition is committed to a severity without a dissent flag.

That matters as soon as a reading has any measurement tolerance. For a reading
known to within ±τ, a verdict is only supported if the whole interval
`[v−τ, v+τ]` lands in one severity band. Measured over 400,000 random bars using
the repo's own constants:

| τ (µ) | readings unresolvable | **unresolvable and NOT flagged** | bar verdicts that could flip |
|---|---|---|---|
| 1 000 | 1.18% | **0.292%** | 2.52% |
| 5 000 | 5.89% | **1.463%** | 11.91% |
| 20 000 | 23.59% | **5.898%** | 40.21% |
| 50 000 | 47.15% | **23.553%** | 82.66% |

The middle column is the one that matters: the board commits to a severity its
own measurement cannot support. Note it is nonzero even at τ = 1000, one
twentieth of `DISSENT_EPS` — the flag is not merely mis-tuned, it is measuring
the wrong distances.

`diagnose.c` locates them exactly rather than inferring: of **11,994** missed
readings at τ = 1000, **11,994 sit on an ambiguity edge and 0 on a band edge.**

## The fix, verified

Measure the distance to all four boundaries instead of two:

```c
const int32_t edges[4] = { lo - amb, lo, hi, hi + amb };
int32_t best = iabs(v - edges[0]);
for (int i = 1; i < 4; i++) {
    int32_t d = iabs(v - edges[i]);
    if (d < best) { best = d; }
}
*dissent = (best <= GATE_QM_DISSENT_EPS || *gray) ? 1 : 0;
```

`fix.c` checks this **exhaustively** — every integer value in every channel's
range, not a sample:

| τ (µ) | missed now | missed fixed |
|---|---|---|
| 1 000 | 11 994 | **0** |
| 5 000 | 59 994 | **0** |
| 10 000 | 119 994 | **0** |
| 20 000 | 239 994 | **0** |

**The honest cost:** the fix raises about 240,000 additional dissent flags across
the swept space (~4.6 percentage points). That is the correct direction — a flag
that fires more often is noisy; one that stays silent on an unsupported verdict
is unsound — but it is a real change in escalation volume and whoever owns the
ledger should expect it.

Two extra integer comparisons per channel. No change to the band data, the `.qm`
artefact, or its sha256 receipt.

## Running it

```sh
cc -std=c99 -O2 study.c    -o study    && ./study      # the sweep
cc -std=c99 -O2 diagnose.c -o diagnose && ./diagnose    # where they sit
cc -std=c99 -O2 fix.c      -o fix      && ./fix         # the fix, exhaustively
```

`vendored_gate_qm.h` is copied unchanged from
`quilt-esp32/firmware/src/reflex/gate_qm.h` so the numbers are the deployed ones.

## Scope

This is a finding about a repository this work does not own. **Nothing outside
`quilt-Kuramoto` has been modified**; the patch is offered, not applied.

It is also narrow. It says nothing about whether τ is ever large enough to
matter in the real audio pipeline — that depends on how the ear features are
measured, which is not in the mirror I have. If those features are exact by
construction, τ = 0 and the missed column is empty. The finding is that **the
code does not currently let you answer that question**, because it flags
proximity to two of its four boundaries regardless of what τ is.
