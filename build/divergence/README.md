# divergence — what does exact integer arithmetic actually buy?

Everything else in `build/` verifies that these libraries are *correct*. Nothing
in it establishes that they are *worth using*. This does — by measurement, and
including the measurements that do not flatter them.

```
$ make
divergence study: banded never wrong (771538 float disagreements observed,
so the contrast is real)
```

## The question

A specification says: **"the ensemble agrees if the mean pairwise phase offset is
within tolerance."**

Summing a set has no canonical order. Index order, reverse order, pairwise
reduction and a single-precision accumulator are all faithful readings of that
sentence — and so is whatever order a hash map, a work-stealing scheduler, or a
SIMD reduction happens to produce. Floating-point addition is not associative, so
these give different values.

The interesting question is not whether the *values* differ. They always do. It
is whether the **answer** differs, and how close to the tolerance you have to be
before it does.

Inputs are generated as exact integers in nanodegrees and the reference answer is
their exact sum in exact integer arithmetic, so "correct" is not a vote among the
candidates. 200,000 trials per cell, 5.4 million total.

## What was measured

| distance from the boundary | 4 float impls disagree | worst float wrong | µdeg integers wrong | **banded wrong** | banded declines |
|---|---|---|---|---|---|
| 1 ndeg | 48.9% | 48.9% | 48.9% | **0.000%** | 100% |
| 10 ndeg | 38.9% | 38.9% | 39.0% | **0.000%** | 100% |
| 100 ndeg | 0.49% | 0.49% | 0.34% | **0.000%** | 100% |
| 1 µdeg | 0.000% | 0.000% | 0.000% | **0.000%** | 0.000% |
| ≥ 10 µdeg | 0.000% | 0.000% | 0.000% | **0.000%** | 0.000% |

*(64 readings per ensemble; the 4- and 16-reading tables are in `results.json`
and show the same shape.)*

## Three findings, two of which cut against this repo

**1. Double precision is accurate. The usual story is wrong.**

Beyond one nanodegree from the threshold, every float implementation gets the
right answer, every time. Not "usually" — 0.000% wrong across millions of trials.
Anyone selling exact arithmetic on the grounds that doubles give wrong answers is
selling something that is not true at these scales, and this repo should not.

**2. Naive integers are *worse* than doubles.**

Quantising to microdegrees and summing exactly is reproducible, but it is *less
accurate* than double precision — the µdeg column is wrong at least as often as
the float one, sometimes more (48.1% vs 39.4% at 10 ndeg with 4 readings). "Just
use integers" makes the accuracy worse. That is a real cost and it is the reason
plain fixed-point is not the answer either.

**3. What doubles lack is not accuracy. It is agreement.**

Within ~100 nanodegrees of the threshold, four faithful implementations of one
sentence return different booleans on up to **49%** of cases. Each is individually
confident. None is flagged. Which one you get depends on compiler version,
iteration order, `-ffast-math`, whether the reduction was vectorised, whether the
container was a vector or a map — things that change without your source changing.

That is the actual failure mode: not a wrong answer, but **two correct systems
that disagree, silently, and only near the boundary** — which is exactly where a
well-tuned tolerance puts you, because a tolerance far from your operating point
is a tolerance you set wrong.

## What the band does

`exact-band`'s answer is not "use integers". It is **quantise, then carry the
quantisation error as an explicit band**, and let the comparison return three
values instead of two:

```
   whole band below the threshold  ->  AGREE
   whole band above it             ->  DISAGREE
   band straddles it               ->  SAY SO
```

Quantising to microdegrees costs at most half a microdegree per reading, so the
true sum lies in `[s − n/2, s + n/2]`. That bound is *known*. Carrying it instead
of pretending it is zero gives, in the table above:

- **wrong: 0.000%.** Everywhere. The band cannot commit to a wrong answer, because
  it only commits when the entire interval is on one side.
- **declines: 100% inside 100 ndeg, 0.000% at 1 µdeg and beyond.** It abstains
  precisely in the zone where the other two are unreliable, and nowhere else.

The third row is the point. The uncertain zone is **±half the quantisation step —
a number you choose when you pick your units**, not a property you have to
discover with a five-million-trial experiment. With doubles the unreliable zone is
about 100 nanodegrees wide and there is no way to know that from the source code.

So the trade is: a **larger** error, in exchange for one that is bounded, identical
on every platform, and *reported when it matters*. Whether that is a good trade
depends on whether your failures are loud or quiet. Silent disagreement between a
firmware node and a gateway is the quiet kind.

## What this does not show

- **Not a claim about float accuracy in general.** Only about a sum-then-compare
  decision at these magnitudes. Ill-conditioned problems are a different subject.
- **Not a claim that 49% of real systems are broken.** It is 49% *conditioned on
  sitting within 10 nanodegrees of the threshold*. How often a real system sits
  there is a property of that system, which this cannot measure.
- **Not a benchmark.** Nothing here is timed.
- **Single platform.** One x86-64 box, one libc, gcc and clang. Cross-platform
  divergence — different libm, different word size — is the stronger version of
  finding 3 and is *not* measured here. Claiming it would be asserting the thing
  this directory exists to stop asserting.

## Running it

```sh
make          # run the assertions
make table    # the human-readable sweep above
make json     # regenerate results.json
```

`make` asserts three things, and all three can fail:

1. the banded answer never commits to a wrong answer;
2. the three integer traversals never disagree — integer addition is associative,
   so a disagreement would mean an overflow;
3. **the float implementations *do* disagree** — a negative control on the
   experiment itself. If they never diverged, this study would have no contrast
   and every conclusion drawn from it would be vacuous.
