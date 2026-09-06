# Build notes — `exact-band`

Built 2026-09-06. Lives at `build/exact-band/`, ready to extract to its own repo.
This records the decisions and the things found along the way.

## The blocking question, answered

Two repos are *named* as if they already do this. Both were read at source:

- **`constraint-tminus-bridge`** (JS, ~1,700 lines) — a real AC-3/backtracking CSP
  solver. Its `ResonanceConstraint` has a `tolerance` field, but it pairs a
  **float frequency** with a **float epsilon**, set once in the constructor and
  never mutated. `grep narrow|intersect|interval` → zero hits.
- **`holonomy-48-bridge`** (Rust, 322 lines) — `Dir48(pub u8)`, a bare integer
  mod 48. `is_consistent()` is `self.0 == 0`. No band, no narrowing, no BPM.

Both are boolean threshold checkers. Neither narrows anything. A separate
org-wide sweep of 1000+ repos returned the same verdict: **no type anywhere
combines an exact value + a stored band + propagation + narrowing.** Three of the
four pieces exist in different places; they were never fused.

## The one design decision

**Store the radius linearly; square only at the point of comparison.**

Storing `r²` is the tempting choice, since every comparison is squared anyway.
It is wrong, and not for a rounding reason — for an algebraic one. Composition
needs `(r₁+r₂)² = r₁² + 2r₁r₂ + r₂²`, and the cross term `2√(r₁²)√(r₂²)` is
generically irrational even when both squares are integers (`r₁²=3, r₂²=5 →
r₁r₂=√15`). Squared storage has thrown away information composition needs back.

Linear storage keeps addition exact (`r₁+r₂`) *and* keeps comparison root-free,
because squaring an integer is always exact — it is *rooting* that is lossy:

```text
overlap  ⟺  ‖c₁ − c₂‖²  ≤  (r₁ + r₂)²
```

The irrational `b√n/2` never enters the type at all. It is a design-time quantity
used to *choose* an integer radius, exactly as `tb_judge_consistency.v` picks
ε=7 against computed bounds of 6.36 and 6.93.

## Balls don't intersect to balls — so there are two types

`Banded<T>` is a Euclidean ball. Two balls meet in a **lens**, not a ball, so
`narrow()` cannot return something tighter than both inputs. It returns whichever
input is tighter — always a valid superset of the true intersection.

A tempting alternative — smaller radius at the observation's centre — is
**unsound**: a point can be within `min(r₁,r₂)` of `obs` while lying outside
`pred`'s ball. There is a test (`narrow_result_encloses_the_true_intersection`)
that would catch it.

So `IBox<N>` was added: an axis-aligned integer box. Boxes **are** closed under
intersection — `lo = max(lo₁,lo₂)`, `hi = min(hi₁,hi₂)`, per axis, exact — and
the empty case *is* the contradiction test, free, with no separate predicate.
That is where genuine narrowing lives.

## Two real bugs found while building

1. **My own.** The six Eisenstein units were wrong: I had `(-1,1)`, whose norm is
   3, not 1. The units are `±1, ±ω, ±(1+ω)`. Caught by the test asserting every
   unit has norm exactly 1. Also worth noting: this crate's `UNITS` are in
   **angular** order (consecutive entries are adjacent, distance 1); upstream
   `eisenstein::directions()` is the same set in a different order and is *not*
   angularly sorted. A test pins that difference so nobody assumes the arrays are
   index-compatible.

2. **Upstream, in a crate advertised for safety-critical use.**
   `eisenstein 0.3.1`'s `E12::norm()` computes `a² − ab + b²` in `i64`. At
   `(i32::MIN, i32::MAX)` the true norm is `13,835,058,048,839,712,769`, beyond
   `i64::MAX`. In **release** the `i64` wrap lands on the correct `u64` bits by
   luck; in **debug** it panics at `lib.rs:79`. Reproduced both. A debug/release
   divergence in exact arithmetic is worth an upstream issue. This crate's `Hex`
   widens to `i128` and has a test at those corners.

   Also found: `eisenstein`'s `std` feature does not compile (`E0433`,
   `hex_room_map.rs:214`) — the crate is unconditionally `no_std` and never
   re-imports `std`. Hence `default-features = false` in our `Cargo.toml`.

## A gap this fills

The org-wide sweep found **no integer square root anywhere**: every crate
advertising exact arithmetic falls back to `f64::sqrt()` when it needs a
magnitude — including a function named `is_pythagorean` in
`constraint-theory-core`, which advertises exactness. `exact_band::isqrt` ships
a `const`, exact, full-`u128` implementation with an `isqrt_ceil` that rounds up
so a band never understates.

## Mutation testing

Five deliberate bugs, all caught:

| Mutation | Tests that failed |
|---|---|
| Covering bound off by one (`≤` → `<`) | 3 |
| Dropped the dimension factor (`n·b²` → `b²`) | 4 |
| `narrow()` keeps the wider band | 2 |
| Compared `r₁+r₂` unsquared | 3 |
| `isqrt_ceil` rounds down | 2 |

## Immediate consumers identified

Files currently doing float tolerance comparisons that this replaces:

- `flux-tensor-midi/deadband-rs/src/eisenstein.rs::snap()` — computes
  `((x-sx).powi(2)+(y-sy).powi(2)).sqrt()` purely to report a distance
- `flux-tensor-midi/snapkit-rust/src/eisenstein.rs::eisenstein_distance()` and its
  doc-tested `assert!(d < 0.58)` covering-radius check
- `constraint-theory-core/src/quantizer.rs::check_unit_norm(tolerance: f64)`, and
  `Rational::is_pythagorean()` which uses `f64::sqrt` inside code advertised exact
- `flux_tensor_midi/constraint_repair.py` — `epsilon: float` threaded through calls
- `flux-lucid`'s `DivergenceAwareTolerance` — the closest conceptual relative in
  the org: a tolerance that tightens and decays, but `f64` and decoupled from any
  value

## Not done yet

The `swarm-tminus` wiring (proposal P2). Its API is now documented precisely —
`CountdownEvent{fire_at_unix, quorum_required, ...}`, `Predictor.add_prediction/
advance/confirm`, `DeadlineTree` with cascade cancellation, and the
`.swarm/*.json` schema. That is what makes a band drive *when things fire*
rather than only what they mean.

---

# P2 — `tminus-band`: the band drives when things fire

Built 2026-09-06, at `build/tminus-band/`. This is the join the whole thread was
pointing at.

## What changed conceptually

`swarm-tminus` fires on `confirmed_count() >= quorum_required`. That is a
head-count, and it treats three vague confirmations as better than one precise
one. `BandedCountdown` fires when the accumulated band has narrowed past a
target width — knowledge, not attendance.

The divergence is a test, not a claim
(`test_the_divergence_this_exists_to_fix`): three subscribers each report a band
800 wide, upstream reaches quorum and fires, and the band says `band_too_wide`
because nobody actually knows when to fire.

## The firing rule, and why it has a count in it after all

Fire iff **width ≤ target** AND **distinct accepted reporters ≥ min_reporters**.

The reporter floor is quorum returning through the back door, deliberately. The
difference: upstream's quorum is necessary *and sufficient*; this floor is
necessary and **never sufficient**.

It is not optional politeness. Exact intersection makes one false-precision
report unusually dangerous — a subscriber reporting `IBox.point(p)` anywhere
inside the current band collapses the width to zero, and nothing in the geometry
can distinguish an exactly-correct claim from a lie that happens to be consistent
with what we already believed. A *contradiction* is caught for free by the
geometry; an over-confident consistent lie is invisible to it. Hence the floor.

## Contradiction is stronger than deferral

Upstream's `DEFERRED` only grants time, and only when quorum is not already met —
it can never block a firing that quorum earned. Contradiction does the opposite:
it vetoes firing even when width and reporter conditions pass. Firing on
knowledge you hold an exact proof is inconsistent is precisely the bug.

A contradicting observation is deliberately **not** intersected into the band —
that would empty it and destroy prior knowledge. It is recorded with its axis and
exact gap, and it blocks firing until the band can accommodate it.

## The over-confidence trap

Intersection only narrows, so a long-running band converges to a point and then
rejects a later correct observation. `stale_widen_per_tick` is the cure: a fixed
integer widening on ticks with no accepted report. No decay curve, no half-life,
no float. Off by default.

## Design convergence

An independent design consult, run in parallel and without sight of the
implementation, arrived at the same four decisions: conjunction of width and a
distinct-reporter floor; contradiction as a status strictly stronger than
`DEFERRED`; integer widening as the least-machinery decay; and `IBox` as the only
sound backend for the firing path, with the ball form kept out of it entirely
because ball-narrowing returns an enclosure rather than the true intersection.

It differed on one point — it argued for a new optional field on
`CountdownEvent` over a wrapper. That is the better long-term shape, so both
paths ship: the wrapper works today with zero upstream change (the band rides in
the existing free-form `payload`), and
`upstream/swarm-tminus-knowledge-gate.patch` proposes the field plus a one-line
`or self._has_knowledge_quorum()` in `tick()`, inert for all 301 existing tests.

## Cross-substrate conformance

`exact-band/examples/emit_vectors.rs` emits **240 golden vectors**; the Python
port must reproduce every one. Verified in sync with its generator as of this
commit. This mirrors the ecosystem's existing byte-exact discipline, where a cell
state hash agrees across five language ports — and it means a divergence between
the Rust and Python substrates is visible rather than latent.
