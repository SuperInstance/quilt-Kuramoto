# exact-band

**A value that is exact by construction, carrying an integer tolerance band —
where a confirmation narrows the band instead of returning pass/fail.**

No floating point. No square roots. Every comparison is exact integer arithmetic.

```rust
use exact_band::{Banded, Z2, Narrowed};

let predicted = Banded::new(Z2::new(100, 40), 5);   // exact centre, half-width 5
let observed  = Banded::new(Z2::new(102, 41), 2);   // a tighter observation

match predicted.narrow(observed) {
    Narrowed::Tightened(b) => assert_eq!(b.radius, 2),      // confirmation narrowed it
    Narrowed::Contradiction { gap_sq } => { /* wrong, and by how much */ }
}
```

## Why

Across this ecosystem, tolerance is always a float scalar computed *after*
snapping — `noise`, `err`, `residual`. It is a **result**, not a band you declare
and then sample within. This crate makes the band a first-class field that
**propagates** through arithmetic and **narrows** under confirmation.

## The one design decision

The radius is stored **linearly**, not squared.

Storing `r²` would look natural (comparisons are squared anyway) but it breaks
addition: `(r₁+r₂)² = r₁² + 2r₁r₂ + r₂²`, and the cross term needs an integer
square root. Storing `r` keeps addition exact *and* keeps comparison sqrt-free,
because both sides can be squared at the point of comparison:

```text
overlap  ⟺  ‖c₁ − c₂‖²  ≤  (r₁ + r₂)²        both sides exact integers
```

This is the same squared-form judge used in `quilt-verilog`, where it is proven
to contribute **zero comparison error**.

## Choosing a band from a tolerance

The covering radius of the scaled integer lattice `b·ℤⁿ` is exactly `b√n/2`, so
basis `b` meets tolerance `ε` iff `n·b² ≤ 4ε²` — an integer test, no roots:

```rust
use exact_band::covering;
assert!( covering::basis_meets(3, 2, 3));   // b=2, n=3, ε=3  → 3·4 ≤ 36 ✓
assert!(!covering::basis_meets(3, 4, 3));   // b=4, n=3, ε=3  → 3·16 > 36 ✗
let b = covering::max_basis(3, 3);          // largest sound basis for n=3, ε=3
```

`max_basis` is computed by integer bisection — never `sqrt`.

## Narrowing

`narrow()` returns information, not a boolean:

- `Narrowed::Tightened(b)` — the bands overlap; `b` is a sound enclosure of the
  intersection (the smaller input ball, which always contains `B₁ ∩ B₂`).
- `Narrowed::Contradiction { gap_sq }` — the bands are disjoint. The prediction
  was wrong, and `gap_sq` says by how much. In a predict-and-confirm loop a
  contradiction is *information*, not a failure.

## Guarantees

- `#![no_std]`, `#![forbid(unsafe_code)]`, zero dependencies.
- No `f32`/`f64` anywhere — enforced by a test that greps the crate's own source.
- Squared quantities are computed in `u128`, so `i32` lattice coordinates in up
  to 3 dimensions cannot overflow.

## License

MIT

## Two band shapes, for two different jobs

| | `Banded<T>` | `IBox<N>` |
|---|---|---|
| Shape | Euclidean ball (centre + radius) | Axis-aligned box (per-axis interval) |
| Judge | `‖g−s‖² ≤ Δ²`, the single-Δ form | per-axis bounds |
| Closed under intersection? | **No** — two balls meet in a lens | **Yes**, exactly |
| `narrow()` returns | a sound *enclosure* (one of the inputs) | the **exact** intersection |
| Contradiction | `Narrowed::Contradiction { gap_sq }` | `None`, plus `disagreement()` |

If you want a band that genuinely tightens under repeated confirmation, use
`IBox`. If you want the single-radius judge that matches the existing
`quilt-verilog` snap semantics, use `Banded`.

`Banded::narrow` is deliberately honest about this: because balls are not closed
under intersection, it returns whichever input ball is tighter — always a valid
superset of the true intersection, never an invented centre. A tempting
alternative (smaller radius, observation's centre) is **unsound**, and there is a
test that would catch it.

## Integer square root

Nothing in the algebra needs one — that is the point of comparing in squared
form. But reporting a magnitude to a human does, and reaching for `f64::sqrt` at
that moment quietly reintroduces the floating point everything else removed.

A survey of this ecosystem found no integer square root anywhere: every crate
advertising exact arithmetic falls back to `f64::sqrt()` when it needs a
magnitude. So `exact_band::isqrt` ships one — `const`, exact, full `u128` range,
with `isqrt_ceil` for sizing bands soundly (it rounds up, so a band never
understates).

## Testing

48 tests, or 52 with `--all-features`. The ones that matter:

- **A negative control.** `max_basis` must be *tight*: `b` meets the tolerance
  and `b+1` does not. Ported from `quilt-verilog/tb/tb_judge_consistency.v`,
  where the same `b+1` control exists. A suite that can only pass proves nothing.
- **Mutation-tested.** Five deliberate bugs were introduced and every one was
  caught: the covering bound off by one (3 tests), dropping the dimension factor
  (4), `narrow()` keeping the wider band (2), comparing `r₁+r₂` unsquared (3),
  and `isqrt_ceil` rounding down (2).
- **Exactness, not containment.** `IBox::narrow` is checked point-for-point
  against the true set intersection over a >10,000-case sweep — equality, not
  merely enclosure.
- **Cross-implementation conformance.** `Hex` is checked against the published
  `eisenstein::E12` over >100,000 distance pairs.
- **Float-freedom is enforced, not claimed.** A test greps this crate's own
  source for `f32`, `f64`, `.sqrt(`, and `libm`, and prints
  `floats : none in N source files` — the same discipline as
  `quilt-verilog/tools/tower/verify.py`.
- **Overflow at the corners.** `Hex::dist_sq` is verified at
  `(i32::MIN, i32::MAX)`, where the true norm is `13_835_058_048_839_712_769` —
  beyond `i64::MAX`.

Verified on `thumbv7em-none-eabihf` (bare-metal Cortex-M4F), and clippy-clean
under `-D warnings` in both feature configurations.

## A note on `eisenstein` 0.3.1

The optional `eisenstein` feature pins `default-features = false` because that
crate's `snap` feature pulls in `libm`/`f64`, and this crate offers no float
path at all.

One thing worth knowing if you use `E12` directly: `E12::norm()` computes
`a² − ab + b²` in `i64`. At `(i32::MIN, i32::MAX)` the true norm is
`13_835_058_048_839_712_769`, past `i64::MAX`, so it **panics in debug**
(`lib.rs:79`) while returning the correct value in release — the `i64` wrap
happens to land on the right `u64` bits. Reproduced in both profiles.

`Hex` widens to `i128` and does not have that divergence. Use `Hex` if you care
about the corners; use `E12` when you need interop.

*(An earlier version of this file also claimed the crate's `std` feature does not
compile. That is wrong for the published crate — `eisenstein 0.3.1` on crates.io
contains only `src/lib.rs` and builds cleanly with `std` and with
`--all-features`. The compile error is in the GitHub repository's HEAD, which
carries files the published crate does not. Corrected after checking the
published artifact rather than the repo.)*

## Status

v0.1.0. The algebra and its tests are done. Not yet wired to `swarm-tminus` —
that is the next step, and it is what makes the band drive *when things fire*
rather than only what they mean.

## Integer zonotopes — and where they lose

`IBox` is interval arithmetic, so it cannot tell that two quantities share a
source. The symptom is that `x - x` is not zero: for `x ∈ [9, 11]` it returns
`[-2, 2]`, a two-wide band around an answer that is exactly `0` every time.

[`zono`](src/zono.rs) fixes that with affine forms carrying **integer**
coefficients over shared noise symbols. This crate previously stated that affine
arithmetic "needs real-valued noise coefficients, i.e. floats, so it is
deliberately out of scope". That was wrong and is now retracted: addition,
subtraction and scaling are exact in `ℤ`, and division and multiplication stay
sound by pushing their exact remainder into a fresh symbol, rounded up. Capacity
is fixed (`Zono<K>`, terms stored inline) so it still needs no allocator.

`cargo run --release --example zono_vs_box` measures both directions.

**Where it wins, without bound.** A value added and removed again — an identity
on the true value:

| repetitions | true width | zonotope | box |
|---|---|---|---|
| 0 | 20 | 20 | 20 |
| 3 | 20 | 20 | 140 |
| 6 | 20 | 20 | 260 |

The box grows by 40 every repetition, forever. It is never wrong, only useless.

**Where it loses.** Ring consensus with integer division, 3 nodes, 8 steps:

| step | true width | zonotope | box |
|---|---|---|---|
| 0 | 24 | 24 | **24** |
| 4 | 24 | 40 | **24** |
| 8 | 24 | 76 | **24** |

The box is *exactly tight* here — a convex combination preserves interval width
— and the zonotope is not. Each division's rounding must be charged as a fresh
**independent** source, because affine arithmetic has no way to say "this error
is a deterministic function of inputs I already track", so the charge cannot
cancel and accumulates. Tightening the remainder bookkeeping from a flat unit
per term to exact leftovers cut this from 270 to 76; it does not remove it.

Both cases are pinned by tests, the losing one included, so the limitation
cannot be quietly claimed away and a real fix shows up as a failure rather than
going unnoticed.

### The fix: stop dividing

`Fixed<K>` carries the form at a binary scale, so dividing by a power of two is
a change of exponent — it touches no coefficient, rounds nothing, and mints no
symbol. Rounding happens once, at an explicit `rescale`, instead of once per
step. On the losing benchmark above that restores the zonotope to **exactly the
true width, 24**, with zero condensations.

### What that buys: concluding that two nodes agree

`cargo run --release --example agreement` asks the question this crate exists
for. Run consensus on a ring, then enclose `x₀ − x₁` — the disagreement between
two nodes. Widths in thousandths of a unit:

| rounds | true | zonotope | box |
|---|---|---|---|
| 0 | 48000 | 48000 | 48000 |
| 2 | 3000 | **3000** | 48000 |
| 4 | 187 | **187** | 48000 |
| 6 | 11 | **11** | 48000 |
| 8 | **0** | **0** | 48000 |

Reproduced in **all three substrates** — Rust, C and Python emit the identical
sequence, and `check-substrates.sh` compares them, so the headline claim is held
to the same standard as the rest of the algebra rather than resting on one
implementation. Breaking `div_pow2` into a real division in any one of them
stalls its collapse at 4000 while the other two still reach 0, which is both the
negative control and the clearest statement of why the scaled form exists.

The zonotope tracks the true width **exactly at every round**, to zero. The box
never narrows — interval arithmetic has no way to know that `x₀` and `x₁` are
built from the same three readings, so it must assume they are extreme in
opposite directions, forever.

It is never wrong. It simply **cannot conclude that the nodes agree** — at any
number of rounds, for any tolerance below 48. That is the operation this crate
is for, and it is the one interval arithmetic cannot do.

### Prior art: most of the mechanism is decades old

A literature review (`research/05-PRIOR-ART-EXACT-NUMERICS.md`) found that the
core ideas here are not new, and the honest list is not short:

- shared noise symbols cancelling under subtraction **is** affine arithmetic
  (Comba & Stolfi 1993) — `x − x = 0` is its oldest selling point, not ours;
- pushing an inexact operation's error into a fresh rounded-up symbol is the
  standard AA treatment of rounding;
- condensation is **zonotope order reduction**, a surveyed technique roughly two
  decades old, and [Arpra](https://github.com/arpra-project/arpra) (2021)
  already does the same merge over MPFR;
- `LazySets.jl` already supports exact **`Rational`** zonotopes;
- "zonotopes beat intervals for networked estimators converging toward
  agreement" is established set-membership estimation, including zonotope
  diffusion across agents (IRI-UPC, IEEE CDC 2018) — the same territory as the
  ring-consensus result below, years earlier.

What appears to remain unclaimed — *appears*, because the review was
web-search-only: affine arithmetic that is **integer all the way down** while
also `no_std`, allocator-free and fixed-capacity for an MCU; the `Fixed<K>`
binary-scale trick; and the cross-substrate byte-exact treatment with a
soundness bug documented and caught by its own sweep.

The engineering below stands. The novelty framing does not, and the table above
replaces it.

### Stress-testing that result — which found a soundness bug

The agreement demo above is a clean setup: three nodes, one reading each,
division by a power of two, ample capacity. `cargo run --release --example
agreement_sweep` breaks all three assumptions — bigger rings, and **fresh
measurement noise every round**, which makes the live source count grow as
`n·T` and forces the fixed capacity to condense.

It immediately reported widths **narrower than the truth**, which is impossible
for a sound over-approximation. The cause was in `absorb_spill`: when the form
was full it added the spilled magnitude to an *existing* term, keeping that
term's symbol id. Two forms that both dumped error into the same shared symbol
then **cancelled that error when subtracted** — because cancelling shared
symbols is exactly what subtraction is for — and the difference came out too
narrow.

A band that is too narrow is the one failure mode that matters here: it lets a
caller conclude two values agree when they do not. The fix frees the slot by
absorbing an existing term into a **fresh** symbol instead, which loses
correlation and can therefore only widen.

Worth being precise about what caught it. The whole suite passed with the bug
in, and so does the hand-written regression test — reverting the fix fails only
`condensation_stays_sound_across_a_consensus_sweep`, the one driven by the real
recurrence. Hand-picked cases missed it; the sweep found it.

### How much capacity you actually need

Disagreement width after 8 rounds, thousandths of a unit. Every cell is
asserted `≥ true` on each run, so this table cannot go quietly unsound again.

**Fresh measurement noise every round:**

| nodes | true | K=8 | K=32 | K=128 | box |
|---|---|---|---|---|---|
| 3 | 10667 | 57034 | **10667** | **10667** | 112000 |
| 5 | 19805 | 67043 | 28180 | **19805** | 112000 |
| 8 | 31066 | 85883 | 52839 | **31066** | 112000 |
| 12 | 34369 | 85883 | 61927 | **34369** | 112000 |

The rule is just the source count: with `n` nodes and `T` rounds each minting a
reading, roughly `n·(T+1)` symbols are live — 108 at `n=12, T=8`, which is why
`K=128` is exact and `K=32` is not.

At `K = 12·(bytes per term)` this is about 1.5 KB per value at `K=128` — real,
but affordable on the targets this crate is aimed at. And the degradation is
graceful: even at `K=8`, condensing constantly, the zonotope is still ~2× better
than the box rather than collapsing to it.
