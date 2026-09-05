# What to build — five proposals, ordered by ratio of value to effort

Every one of these composes things that already exist. None is a rewrite.
Each says what it depends on, what is genuinely new, and how you would know it works.

---

## P1 — `exact-band`: the join you described, and the one thing nobody built

**The gap.** Exact-angle sampling exists twice over. Predict-and-confirm timing
exists and is consolidated. **Nothing connects them**, and nothing carries a
tolerance as a first-class value.

Today the tolerance is always a float scalar computed *after* snapping — `noise`,
`err`, `tolerance`. It is a *result*, not a band you declare and then sample
within. There is no type like:

```rust
struct Banded<T> { value: T, band: (i64, i64) }   // exact centre, exact half-width
```

**What it is.** A small no_std crate with one idea: a value that is exact by
construction, carrying an integer tolerance band, with operations that
*propagate the band* rather than recomputing a residual.

```rust
impl Banded<E12> {
    fn certain(&self) -> bool;                  // band collapses to a point
    fn overlaps(&self, other: &Self) -> bool;   // squared-form, integer, no sqrt
    fn narrow(self, obs: Banded<E12>) -> Self;  // intersect: confirmation narrows
}
```

**Depends on (all real, all tested):**
- `eisenstein::E12 { a: i32, b: i32 }` — pure integer, `norm() = a²−ab+b²`, 226 tests, no_std
- `quilt-verilog` Theorem 4a — the covering-radius result `b√n/2` that tells you
  how to *choose* the band, plus the squared-form judge that compares without error
- `deadband-rs::div360` — exact integer angle arithmetic with explicit remainder

**Genuinely new:** band propagation through composition, and `narrow()` — a
confirmation shrinking a band instead of returning pass/fail. That is your
"tolerance around what is sure," made a type.

**How you'd know it works:** port `tb_judge_consistency.v`'s test — ~2,325
vectors, n ∈ {1,2,3}, error must equal `b√n/2` *exactly* at deep holes — and keep
its **negative control**, where `b+1` must break the guarantee. A test suite that
only passes proves nothing.

**Effort:** small. Days, not weeks.

---

## P2 — `tminus-banded`: exact bands drive when things fire

**The gap.** `CountdownEvent.has_quorum()` is a boolean gate on a *count*.
`Predictor.confirm()` returns bool. Neither carries a numeric tolerance that
could be intersected with a constraint-theory band. And nothing maps a
BPM/phase into an exact angle — every timing type is `f64`/`Duration`, every
exact type is `i32`/`u8`, and no trait connects them.

**What it is.** `swarm-tminus` with `Banded<E12>` as the phase type: a prediction
is a band, a confirmation narrows it, and an event fires when the band is tight
enough — not when a counter hits a magic number.

**Depends on:** P1, plus `swarm-tminus` (Python, stdlib-only, **301 tests**, the
canonical consolidation of six scattered implementations).

**Why it matters beyond elegance:** this is the fix for
`federated-tinyml-vessel`'s hardcoded `< 3` quorum, and for the band-sync problem
the Kuramoto thread was reaching for — phase-lock as band intersection, in exact
integers, instead of float phase comparison.

**Effort:** small-to-medium. The Python/Rust boundary is the awkward part;
`constraint-theory-python` (PyO3) already exists as a bridge pattern.

---

## P3 — `tower`: lift the spec→code generator out of the FPGA repo

**What exists.** `quilt-verilog/tools/tower/emith.py` compiles a YAML cell spec
into one dependency-free C file, and **refuses to emit code when the basis is
inexact**:

```python
if (span_psi * den) % num != 0:  raise CellError(...)
```

`verify.py` then checks 17 hand-computed golden vectors *and greps the output for
`float`/`double`*, printing `floats : none in generated C`. The float-free
property is **verified, not asserted.**

**Why lift it.** Its coupling to Verilog is *none* — it is pure Python emitting
C. It is buried in an FPGA repo where nobody looking for a codegen tool will find
it. It currently compiles exactly one shape (an affine sensor transform); the
grammar wants generalising.

**Effort:** near zero to extract, medium to generalise. Highest value-per-hour on
this list.

---

## P4 — `ternary`: collapse ~50 crates into one library

~50 separate repos — `ternary-graph`, `-regex`, `-hash`, `-sort`, `-paxos`,
`-quorum`, `-lattice`, `-zkp`, `-knn`, `-svm`, `-transformer` — each created
within minutes of the others in June 2026, all frozen since 2026-07-12, none
referencing another.

This is one crate with submodules. The work is mechanical: read each, keep what
has tests, delete the rest, one `ternary` crate with feature flags. Archive the
originals rather than deleting — your own doctrine says *"we archive, we don't
delete."*

**Effort:** medium and boring, but it converts 50 dead repos into one live
dependency. The same treatment applies to the 7 exocortex repos, the 5 sheaf
libraries, and the 4 competing Quilt "entry points" (`quilt-system`,
`quilt-foundation`, `quilt-core-os`, `quilt-base`).

---

## P5 — Fix the org's own index before adding to it

`SuperInstance/SuperInstance` is the front door and it is broken:

- `INDEX.md` contains a literal unsubstituted `$(date -u '+%Y-%m-%d %H:%M UTC')`
  and an HTML comment reading `<!-- Warning: gh repo list returned empty output -->`
- The repo count disagrees with itself three ways: README badge "4,000+";
  `STATUS_BOARD.md` (2026-07-12) "4,098"; `CATALOG.md` regenerated **today**,
  exactly **2,000**. Nothing reconciles them.
- "**6000+ tests**" is circular — it traces to a sentence in `CONTRIBUTING.md`,
  gets copied into the auto-generated catalog, and is then cited as evidence. No
  script anywhere sums tests across the org.
- ~25 top-level directories named after other repos are **all empty**.
- The doctrine says every new package must be registered in `PACKAGES.md`. The
  entire `federated-tinyml` family is not.

**Effort:** hours. It is the cheapest credibility repair available, and it is the
file everyone reads first.

---

## What I would not build

- **A new repo for anything in `quilt-Kuramoto/code/`.** It is byte-identical to
  live upstream repos and 9% complete. See `docs/UPSTREAM-DELTA.md`.
- **Anything justified by the quantum bridge.** Its own benchmark refuted its
  headline (α ≈ 0.1–0.2, "closer to linear than polylog"). The verification-asymmetry
  framing survives; the quantum framing costs credibility the engineering has earned.
- **Another metaphor system.** There are already four for the same problem
  (Working-Animal, Cocapn/crab, Fleet/vessel, PLATO/room).
