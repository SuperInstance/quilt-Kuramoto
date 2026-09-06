# exact-band-c

The C99 port of `exact-band`: exact integer tolerance bands, no floating point,
no allocation, no dependencies beyond `<stdint.h>`.

**1,553 bytes of text at `-Os`. Zero `data`, zero `bss`.** One `.c` file and one
header. This is the substrate the ESP32 firmware can link against.

```
$ make
./build/unit
checks: 4385501
PASS
./build/conformance tests/vectors.json
vectors: 471   checks: 1676   skipped (out of 64-bit range): 4
PASS: C substrate agrees with the Rust and Python substrates.
nofloat: no floating-point type in src/exact_band.c src/exact_band.h

exact-band-c: all checks pass.
```

## Why a third substrate

The Rust crate and the Python port already agree byte-for-byte on a shared
vector file. Two implementations agreeing is weaker evidence than it looks: they
were written by the same author, from the same understanding, days apart. A
third, in a language whose integer arithmetic has genuinely different rules —
no `u128`, undefined signed overflow, implementation-defined widths — is a real
test of whether the algebra was ever substrate-independent.

It found one thing, described below.

## What it does not have: 128 bits

The Rust crate computes every squared quantity in `u128`. C99 has no portable
128-bit integer, and the 32-bit targets this port exists for have none at all.
So it works in 64 bits and **states its limits instead of hiding them**:

| Limit | Value | Binding case |
|---|---|---|
| `EB_COORD_MAX` | 1 239 850 262 | hexagonal norm at `a = −b`, costing `3·(2C)²` |
| `EB_RADIUS_MAX` | 2³⁰ − 1 | two radii sum before squaring |
| `EB_SCALE_MAX` | 2³¹ − 1 | `4·ε²` in the covering test |

Each is the **largest** value that still fits, not a round number chosen for
comfort — and the test suite asserts both halves of that claim: that the limit
fits and that one more does not.

Inputs beyond a limit are **rejected, never wrapped**. Four of the 471 shared
vectors fall outside this substrate's reach — one `isqrt` case (`u128::MAX`) and
three `dist_sq` cases at the `i32` extremes. The conformance runner skips them,
prints the count, and **fails if the count changes**, so a quietly widening skip
set cannot erode coverage while the run still says PASS.

That is a real difference between the substrates. It is reported rather than
papered over.

## What the third substrate found

Writing the negative control for `Phase::offset_to` disproved the stated reason
for its own fix.

The [bug](../exact-band/src/circular.rs) was real: on an odd ring, `offset_to`
returned the *long* way round. The commit message and the Rust doc comment both
credit the fix to comparing `2·d > n` instead of `d > n/2`, on the grounds that
integer division truncates.

It does truncate — but that is not what was wrong. Once `d` is normalised into
`[0, n)`, the two comparisons are equivalent for **every** `n`, odd included:
for odd `n`, `d > (n−1)/2` iff `2d ≥ n` iff (`2d` even, `n` odd) `2d > n`.

The original had no normalisation. It left `d` in `(−n, n)` and folded it with
two truncating comparisons — and on an odd ring **the second undoes the first**:

```c
if (d >  n / 2) { d -= n; }    /* N=7, d=4:  4 > 3, so d = −3  */
if (d <= -n / 2) { d += n; }   /*           −3 ≤ −3, so d = +4 */
```

The fix was the **normalisation**. `2·d > n` is a clarity choice.

`test_phase_negative_control` now asserts this rather than asserting the story:
it runs both the original two-branch form and a single-truncating-comparison
form against the shipped one over eleven rings, and checks that the original
diverges on exactly `n` pairs of every odd ring and none of any even ring, while
the truncating form diverges **nowhere**. The last of those three is the claim
that had been asserted and never tested.

The Rust doc comment has been corrected to match.

## Tests

`make` runs three things, and all three can fail:

**`unit` — 4,385,501 checks.** Properties checked against their *definitions*,
not against a sibling implementation, because a shared mistake reproduces
perfectly across substrates. `isqrt` exhaustively over `[0, 100000)` plus the
top of the `uint64_t` range; the Eisenstein norm's positive-definiteness over a
81×81 block, and that the six units have norm exactly 1 — with `(−1, 1)`, the
non-unit an earlier version mistook for one, asserted to have norm 3;
`max_basis` maximality over 1200 `(dim, eps)` pairs, cross-checked against the
closed form `2ε` in one dimension; `Banded::narrow` soundness by *enumerating
every integer point* in both inputs and requiring the result to contain them
all; `IBox::narrow` exactness the same way — `p` in the result **iff** `p` in
both, since boxes, unlike balls, lose nothing to intersection.

**`conformance` — the same 471 vectors the other two substrates read.** Not a
transcription of them: the runner parses `vectors.json` itself, because a
hand-copied fixture is exactly where a conformance suite goes quietly wrong. It
also checks two invariants the file cannot express — that `|offset| == distance`
for every phase pair, and that `disagreement()` is zero exactly when `narrow()`
succeeds — which catch a substrate that satisfies each recorded field
independently while disagreeing about what the fields mean.

**`nofloat` — the central claim, checked.** The library says it contains no
floating point; the build verifies it, and the check itself has been tested
against a file with a `double` added, which it rejects.

## Portability

Verified here: **gcc and clang, `-std=c99`, `-std=c11`, `-std=c17`**, all with
`-Wall -Wextra -Werror -pedantic -Wshadow -Wconversion -Wsign-conversion
-Wcast-qual -Wstrict-prototypes -Wmissing-prototypes -Wold-style-definition`.
Clean under `-fsanitize=undefined,address` for both binaries.

Not verified here: a genuine 32-bit build. `-m32` needs multilib, which this
container lacks, so the claim that this suits a 32-bit target rests on the
source using only fixed-width types from `<stdint.h>` and on the sanitizers
finding no undefined behaviour — not on an actual 32-bit run. Worth doing on
real hardware before relying on it.

## Layout

```
src/exact_band.h    the interface, with every range limit derived in a comment
src/exact_band.c    the implementation -- 282 lines, no branches on width
tests/test_exact_band.c   property tests and negative controls
tests/conformance.c       runs the shared vectors
tests/json.[ch]           a minimal JSON reader, test-only on purpose:
                          the library depends on nothing, and that is worth
                          more than reusing a parser
tests/vectors.json        the shared golden vectors, byte-identical to the
                          copies under ../exact-band and ../tminus-band
```
