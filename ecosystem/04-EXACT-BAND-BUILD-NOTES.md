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

---

# P3 — `tower`: the spec→C generator, lifted and generalised

Built 2026-09-06, at `build/tower/`. Extracted from
`quilt-verilog/tools/tower/emith.py`, which had **zero coupling to Verilog** —
pure Python emitting C — but lived in an FPGA repo where nobody looking for a
code generator would find it.

## Compatibility is measured, not claimed

tower reproduces all **17 hand-computed golden anchors** from the original
`tools/tower/verify.py` — anchors computed independently of either generator —
and loads the original `oil-pressure-port.cell.yaml` unmodified, including its
unit-suffixed `range_psi:` key.

## What was generalised, and why it had to be

| | Original | tower |
|---|---|---|
| Units | psi only, hardcoded regex | any unit |
| Range | rejects non-zero minimum | any range, including negative |
| Equation | one shape | affine, optional offset and divisor |
| Exactness gate | ✓ | ✓ kept |

The 0-based restriction was not theoretical polish. A survey found real signed
quantities in the same ecosystem: `quilt-esp32/firmware/src/vessel_qm.h` carries
a generated geofence with `lon_lo = -152500000, lon_hi = -152350000`, entirely
negative; rudder angle, rate of turn and heading deviation are all signed by
physical convention.

## Direction matters — the fathoms lesson

Fathoms → metres is a *multiplication* (1 fathom = 1,828,800 µm exactly) and is
exact; `quilt-esp32`'s `nmea.c` already relies on it. Metres → fathoms *divides*
by 1.8288, giving `625/1143`, which never reduces. The same physical
relationship is exact one way and not the other, and the gate catches the
direction that fails. Shipped as a worked example that must be rejected.

## Two findings from the survey

**Only one cell spec exists in the entire org.** `oil-pressure-port.cell.yaml`
is it. The generalisation was therefore driven by real consumer code rather than
by a family of specs — which is worth stating plainly rather than implying a
broader mandate.

**A unit bug in shipped firmware.** `quilt-esp32/firmware/src/nmea/nmea.c`
converts km/h to knots with `* 5 / 18`. That is the km/h→**m/s** factor;
km/h→knots is `1000/1852 = 250/463`. Verified by exact rational arithmetic.
Worth an upstream issue alongside the `eisenstein` overflow one.

**Five independent NMEA parsers** exist across the org (`quilt-esp32`,
`nmea-quilt-cell`, `mudra-vessel-bridge`, `cocapn-python`, `cocapn-marine`),
none unified, only one integer-only. That is the clearest consumer case for this
generator.

## Honest limitations, recorded

- Affine only. No dyadic staircases for constants that refuse to be whole —
  SEMANTIC-TOWER §5.3's acknowledged fallback. Such specs are rejected rather
  than approximated, but rejection is not support.
- Circular quantities are not modelled. A squared difference judges 359° and 1°
  as 358 apart rather than 2. Both `quilt-esp32` and `cocapn-marine` handle this
  by hand today. It needs a different judge, not a different basis.

## A wart the tests caught

Adding `tower/__init__.py` with `from .emit_c import emit_c` made the exported
function shadow its own module, so `import tower.emit_c` returned a function.
The mutation test failed immediately on it. The emitter now lives in
`tower.emit`, and the collision is gone.

---

# The Kuramoto experiment — making the repo's name mean something

Built 2026-09-06, at `build/phase-lock/`.

This repository is called `quilt-Kuramoto`. The name came from **one analogy in
one research document** — nothing in the ecosystem implemented a Kuramoto model.
This is the experiment that closes that gap, and it corrected two things the
analogy had wrong.

## Why it needed exact integers first

The phase-locking criterion for discrete-time Kuramoto is stated in terms of
*finitely many collisions*. In floating point a collision is a comparison
against an epsilon you picked, and phase-locking is "offsets stop changing"
within a threshold over a window. Neither is decidable. On `ℤ/M` both are
equalities.

That required a new type — `exact_band::Phase<N>` — which also fixes the
circular-quantity gap recorded as a `tower` limitation: a squared difference
judges 359° and 1° as 358 apart. Both `quilt-esp32` and `cocapn-marine` work
around that by hand today.

## The result

**Frozen locking implies crossings stop: 2,600 runs, 1,069 locked, zero
counterexamples.** Exact, not statistical.

The converse fails, and the asymmetry is the interesting part: a tight cluster
stops overtaking long before its offsets stop jittering by one slot.
Crossing-free is strictly weaker than frozen.

## Two definitional errors the experiment caught

**A coincidence is not a collision.** My first run counted pairs *sharing a
slot* and produced a result that inverted the theory — coincidences were highest
when the system was most synchronised. Of course: a tight cluster on a discrete
circle shares slots constantly. The continuous theory means a *crossing* — an
overtaking event, a sign change in the signed offset. On one system: K=1.0 gave
16 crossings and 1592 coincidences; K=2.0 gave 20752 crossings and 398
coincidences. They invert. Anything reasoning about "collisions" in discrete
phase space must say which it means — and document 18's Kuramoto row does not.

**Phase-locked is not synchronised.** Four oscillators at 90° spacing with equal
frequencies sit in a splay state: coupling sums cancel exactly, offsets never
move, spread is maximal. Testing coherence as a proxy for locking disagreed on
116 of 480 runs, every disagreement one of these two cases.

## An upper critical coupling

Continuous Kuramoto has no upper bound; more coupling never hurts. The discrete
map overshoots. Locking collapses between K=1.0 (88.5%) and K=1.25 (19.5%) and
is gone by K=2.0. A reproducible non-monotonic dip at K=0.75 (64%) is
unexplained and recorded as such.

## What it does not show

It does not support the quantum-bridge argument. That document mapped Kuramoto
onto a multi-agent timing protocol as one of ten analogies; this tests the
oscillator model, not the analogy — and if anything complicates it, since the
criterion it cites needs the crossing/coincidence distinction to survive
translation into a discrete setting.
