# smt-equivalence — proving, where sampling only samples

The conformance streams (`../CONFORMANCE-STREAM.md`) run millions of random
cases and fold them into one checksum. That is **differential testing**: it
samples. This asks a different question — *can these two implementations differ
on **any** input in a stated range?* — and hands it to a solver.

```sh
make          # all nine checks, ~30s
```

It has already paid for itself once.

## The bug it found

`eb_div_nearest` computed `(2 * n + d) / (2 * d)`. Past `i64::MAX/2` the
doubling overflows, and signed overflow in C is **undefined**, not wrapping.
Confirmed against real binaries, not solver models:

| | `n = 2^62`, `d = 3` |
|---|---|
| `gcc -O2` | `-1537228672809129300` |
| `rustc -O` | `1537228672809129301` |

Different **sign**. UBSan names it: *"signed integer overflow: 9223372036854775807
\* 2 cannot be represented in type 'long int'"*. The Rust port widens to `i128`
and was never affected. Fixed by comparing `|r|` against `d − |r|` instead of
doubling — same test, nothing can leave `int64`.

**The streams could not have found this.** They draw inputs well inside the safe
range, so a million cases exercise the function only where both agree. After the
fix, every committed checksum is *unchanged*. That is the proof they were blind
to it, and the reason this directory exists.

## What is actually proved

Each row is a solver run, with its real domain and time. Nothing here is
extrapolated.

| check | domain | result | time |
|---|---|---|---|
| `phase_offset` ≡ | **full**: all `u32 n`, all `i64 a,b` | **UNSAT** | 0.2s |
| `basis_meets` ≡ | documented shared domain (`dim∈1..3`, `≤ EB_SCALE_MAX`) | **UNSAT** | 1.4s |
| `isqrt` ≡ | `u16` proxy, all `n < 2^16`, 10-step unroll | **UNSAT** | 11.7s |
| `div_nearest` ≡ | `d > 0`, full `i64` | **UNKNOWN (timeout)** | 60s |

Plus four **fail-first controls**: each reintroduces a historical bug and
confirms the solver catches it. A checker that has never failed proves nothing.

## The asymmetry, which is the practical lesson

**Finding a bug was fast. Proving absence often does not finish.**

The overflow divergence came back SAT in **4.4s**. Proving the *fixed* version
has no counterexample times out at 60s on the full domain — and still times out
bounded to `|n|,|d| < 2^31` after **153s**. Division is hard for bitvector
solvers. `phase_offset`, which is all comparisons and one modulo, proves over
its entire domain in 0.2 seconds.

So the honest positioning is not "we now prove our code correct". It is: *for
some small functions this proves equivalence outright; for others it is a very
good bug-finder and not a proof.* Both are useful; conflating them would not be.

## What this does NOT prove

**It compares models, not binaries.** Each checker encodes what the C says and
what the Rust says into SMT. If a model is wrong, the result is wrong. Real
compilers, optimisation levels and UB are outside the model — which matters
especially here, since the bug found *was* UB, where the C standard grants the
compiler latitude a bitvector model does not represent. That is why the finding
was confirmed against `gcc -O2`, `clang -O2` and `rustc -O` before it was
believed.

`isqrt` is checked at `u16`/`u32` as a **scaled proxy**; the real `u64`/`u128`
widths do not finish. A proxy that holds is evidence, not a proof about the
shipped widths.

## A false positive, recorded before it was believed

`HARNESS-NOTE.md` documents a divergence this harness reported mid-development
that **was not a bug** — a width mismatch in the checker's own models. It is
kept because a tool that only ever shows its successes cannot be calibrated.

## Layout

```
common.py              shared z3 helpers
check_div_nearest.py   the one that found a real bug
check_phase_offset.py  the historical odd-ring bug, as a control
check_basis_meets.py   guard-clause differences and the shared domain
check_isqrt.py         Newton iteration, unrolled, scaled proxy
run_all.py             all nine, each with its expected result
HARNESS-NOTE.md        a false positive, kept deliberately
```

Requires `z3-solver` (`pip install z3-solver`); every check skips with a clear
message if it is absent.
