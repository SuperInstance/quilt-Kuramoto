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

38 tests. The ones that matter:

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
