# Prior-art and state-of-the-art review: `exact-band` / `Zono<K>`

Scope: this reviews `build/exact-band/src/zono.rs` (integer affine arithmetic /
zonotopes, fixed inline capacity, `Fixed<K>` binary-scale variant) and the
consensus/agreement claim in `build/exact-band/README.md`. It does not
separately re-review `Banded`/`IBox`/`covering`/`lattice`/`circular`, which are
plain interval arithmetic and lattice-covering-radius bookkeeping and are not
where the novelty claim in the README concentrates.

Research method: web search only (no access to a citation index or the actual
PDFs of paywalled papers in most cases), September 2026. Claims below are
graded **CONFIRMED** (multiple independent sources agree), **LIKELY**
(one clear source, plausible, not cross-checked), or **UNVERIFIED** (could not
find a primary source, stated as an open question rather than a fact).

---

## 1. What already exists

**Affine arithmetic itself.** Founded by Comba & Stolfi (1993) and developed by
Luiz Henrique de Figueiredo and Jorge Stolfi through the 1990s–2000s
("Self-Validated Numerical Methods and Applications", IMPA/21st Brazilian Math
Colloquium 1997; "Affine Arithmetic: Concepts and Applications", *Numerical
Algorithms* 2004; "An Introduction to Affine Arithmetic", *TEMA* 2004). The
form is exactly the one `zono.rs` uses: `x = x0 + Σ xi·εi`, `εi ∈ [-1,1]`,
shared symbols express dependence, subtraction of a value from itself cancels
term-by-term. **CONFIRMED** — this is the textbook construction, correctly
cited in `zono.rs`'s own doc comments.

**Rounding error as a fresh noise symbol is the standard AA mechanism, not
new.** Classical affine arithmetic already handles every inexact operation
(floating-point roundoff, non-affine remainder of a multiplication) by folding
the discarded error into a *new* independent noise symbol — this is explicit
in the original AA literature and repeated in essentially every
implementation and survey found. **CONFIRMED.** `zono.rs`'s
`div_round`/`mul`/`absorb_spill` mechanism ("push the error into a fresh
symbol, rounded up") is this exact, decades-old pattern, applied to integer
remainders instead of floating-point rounding. The mechanism is not novel;
the substrate it's applied to (pure integers, never a float) is what differs.

**Term-count capping ("condensation") is a known technique, not new.**
The general problem — an affine/zonotope form accumulates one new generator
per inexact operation and needs to be kept small — is called **zonotope order
reduction** in the reachability-analysis literature, and is decades old:
Girard's reduction (bound the smallest generators by a box), and surveyed in
"Methods for Order Reduction of Zonotopes" (Kopetzki, Schürmann, Althoff, TUM,
2017/2018) and "A comparison of zonotope order reduction techniques"
(*ScienceDirect*/*Automatica* family). Independently, **Arpra** — "Arpra: An
Arbitrary Precision Range Analysis Library" (*Frontiers in Neuroinformatics*,
2021) — is a published, open-source C library doing mixed interval/affine
arithmetic with MPFR-backed arbitrary precision, and explicitly implements
"three novel affine term reduction strategies [that] improve memory efficiency
by merging affine terms of lesser significance" — i.e., condensation of the
smallest terms into fewer terms, the same idea `Zono::absorb_spill` implements
in the K=1-target special case. **CONFIRMED** as a known technique; `zono.rs`'s
version is a specific (simplest) instance of it, done in integers.

**Exact / rational zonotopes already exist in mainstream toolboxes.**
JuliaReach's `LazySets.jl` is explicitly generic over the coefficient type via
Julia's parametric `LazySet{N}`, and multiple sources describe switching `N`
to `Rational` for exact set computation "with no additional performance
penalty" via multiple dispatch (JuliaReach: a Toolbox for Set-Based
Reachability, arXiv:1901.10736, and JuliaReach docs). **LIKELY** (I could not
independently confirm from primary docs that every zonotope operation
JuliaReach ships is rational-clean end to end, e.g. that no operation silently
calls a `sqrt` or another operation that requires `Float64`, only that the
type parameter is designed to support it) — but this alone answers the
research question "does an exact/rational zonotope mode already exist in a
major toolbox" with **yes, in principle, in at least one widely used tool**.
CORA (TUM, MATLAB) supports the same *set representations* (intervals,
zonotopes, constrained/polynomial zonotopes) but the search did not turn up
an explicit "exact rational mode" for it — MATLAB's native numeric types bias
toward double by default, so this is **UNVERIFIED** either way for CORA
specifically.

**Non-real-valued zonotope generators already exist for exact discrete
computation.** "Logical Zonotopes: A Set Representation for the Formal
Verification of Boolean Functions" (Alanwar, Jiang, Amin, Johansson, IEEE CDC
2023, arXiv:2210.08596) builds zonotopes whose generators are binary vectors
combined by XOR over GF(2) specifically so that logical operations are
*exact* rather than approximate — extended by "Polynomial Logical Zonotope"
(arXiv:2306.12508, 2024) to make AND/OR/NAND/NOR exact too, not just
XOR/XNOR. This is a different algebraic ring (GF(2), not ℤ) and a different
motivating problem (Boolean circuit verification, not physical-quantity
uncertainty), but it is conceptually the closest published precedent for "swap
the real-valued generator ring for a discrete one so a family of operations
becomes exact instead of approximate" — which is the same move `zono.rs` makes
for ℤ. **CONFIRMED** as existing, and **worth citing as the nearest relative**
even though it does not overlap in domain.

**Exact multiplication for zonotope-like sets is an active 2024–2025 research
line, and it is more ambitious than what `zono.rs` does.** "Data-Driven
Nonconvex Reachability Analysis using Exact Multiplication" (arXiv:2504.02147,
2025) introduces constrained polynomial (matrix) zonotopes that are *closed
under multiplication* — i.e., multiplication needs no fresh-symbol
over-approximation at all, because the representation is richer than plain
affine forms. `zono.rs`'s `Zono::mul` still bounds the nonlinear cross term by
`rad(a)·rad(b)` in a fresh symbol, which is the classical (weaker) AA
multiplication rule this newer work is explicitly trying to beat.
**CONFIRMED**, and it means the state of the art in the reachability-analysis
community has already moved past plain affine-form multiplication toward
representations `zono.rs` does not use.

**The dependency problem, and zonotopes as its standard fix, are textbook
material, not a new observation.** "The dependency problem in interval
arithmetic occurs because multiple occurrences of a variable are decorrelated
and handled as distinct variables... `X - X` [is] not the degenerate interval
`[0,0]`" is stated identically across the interval-arithmetic literature; the
standard list of fixes given is "centered, slope and mean value forms, affine
arithmetic, Taylor models, and Bernstein polynomials." **CONFIRMED.**

**Zonotope-based distributed/networked estimation, including consensus-style
diffusion across nodes, is an established sub-field, going back years before
this work:**
- "A Distributed Set-membership Approach based on Zonotopes for Interconnected
  Systems" (IEEE CDC 2018, IRI-UPC group; PDF at iri.upc.edu) — each agent
  keeps a zonotope, exchanges it with neighbors, and a "set-based diffusion
  step... can be seen as a lightweight approach to achieve partial consensus
  between the distributed estimated sets." This is the same shape of problem
  (networked nodes, bounded uncertainty, zonotopes, a diffusion/consensus
  step) as the README's ring-consensus example. **CONFIRMED** as existing;
  full-text fetch of this specific PDF failed (503) so the exact claims about
  integer vs. floating-point arithmetic inside it are **UNVERIFIED** — the
  abstract-level description came from secondary sources (ResearchGate,
  IEEE Xplore listing), and it almost certainly uses real/floating-point
  zonotopes like the rest of that literature, not integers.
- Combastel-style zonotopic Kalman filtering and the broader "zonotopic
  set-membership estimation" literature (multiple ScienceDirect/IEEE
  results, e.g. "Zonotopic guaranteed state estimation for uncertain
  systems") repeatedly makes the point that zonotopes stay tighter than
  interval/box estimation specifically *because* they preserve correlation
  between shared noise sources across time or across sensors — the same
  reason `x0 - x1` collapses to zero here. This is the standard motivation
  given for using zonotopes over boxes in set-membership estimation, not a
  claim original to this crate.

**Formally verified interval/rounding-error tooling is mature and active
through 2025–2026.** CoqInterval + Flocq (renamed to the Rocq ecosystem in
2025) remain maintained (coq-interval 4.11.x on the Rocq package index);
Gappa compiles rigorous rounding-error bounds to Rocq proofs and — notably —
already uses "a new affine term captur[ing] all the floating-point rounding
errors" internally, i.e. the fresh-symbol-for-rounding idea again, at the
level of a formally checked tool. FPTaylor, Daisy, and PRECiSA continue to be
compared and extended in 2025 work (e.g. arXiv work from Cai et al., July
2025, combining FPTaylor-style differential error bounds with invariant
synthesis). **CONFIRMED** as an active, more rigorous adjacent field: these
tools produce machine-checked proofs, not just a Rust type that is exact by
construction.

Sources:
- [Self-Validated Numerical Methods and Applications — Stolfi & de Figueiredo](http://www.iri.upc.edu/people/thomas/Collection/details/45477.html)
- [Affine Arithmetic: Concepts and Applications (Numerical Algorithms, 2004)](https://link.springer.com/article/10.1023/B:NUMA.0000049462.70970.b6)
- [An Introduction to Affine Arithmetic (TEMA)](https://tema.sbmac.org.br/tema/article/download/352/291)
- [Methods for Order Reduction of Zonotopes (TUM)](https://mediatum.ub.tum.de/doc/1379661/document.pdf)
- [A comparison of zonotope order reduction techniques](https://www.sciencedirect.com/science/article/abs/pii/S000510981830298X)
- [Arpra: An Arbitrary Precision Range Analysis Library (Frontiers in Neuroinformatics, 2021)](https://www.frontiersin.org/journals/neuroinformatics/articles/10.3389/fninf.2021.632729/full)
- [Arpra GitHub](https://github.com/arpra-project/arpra)
- [JuliaReach: a Toolbox for Set-Based Reachability (arXiv:1901.10736)](https://arxiv.org/pdf/1901.10736)
- [LazySets.jl — Zonotope docs](https://juliareach.github.io/LazySets.jl/dev/lib/sets/Zonotope/)
- [Logical Zonotopes: A Set Representation for the Formal Verification of Boolean Functions (arXiv:2210.08596)](https://arxiv.org/abs/2210.08596)
- [Polynomial Logical Zonotope (arXiv:2306.12508)](https://arxiv.org/abs/2306.12508)
- [Data-Driven Nonconvex Reachability Analysis using Exact Multiplication (arXiv:2504.02147)](https://arxiv.org/abs/2504.02147)
- [Generalized Intervals and the Dependency Problem](https://www.researchgate.net/publication/227740151_Generalized_Intervals_and_the_Dependency_Problem)
- [A Distributed Set-membership Approach based on Zonotopes for Interconnected Systems (IEEE CDC 2018)](https://ieeexplore.ieee.org/document/8619018/)
- [Distributed Zonotopic Set-Membership State Estimation based on Optimization Methods with Partial Projection](https://www.sciencedirect.com/science/article/pii/S2405896317311692)
- [Zonotopic guaranteed state estimation for uncertain systems](https://www.sciencedirect.com/science/article/abs/pii/S0005109813004159)
- [coq-interval 4.11.3 (Rocq Package Index)](https://rocq-prover.org/p/coq-interval/4.11.3)
- [Certification of bounds on expressions involving rounded operators (Gappa, arXiv:cs/0701186)](https://arxiv.org/pdf/cs/0701186)

---

## 2. What of ours is NOT novel

This list is not empty, and should not be treated as a footnote.

1. **Affine arithmetic with shared noise symbols that cancel under
   subtraction** — this is the entire founding idea of AA (Comba & Stolfi
   1993), not something this crate contributes. `zono.rs`'s own doc comments
   already say as much and cite the source; good practice, but it means the
   headline "x − x collapses to zero" is the *oldest* selling point of affine
   arithmetic, presented in exactly the way de Figueiredo & Stolfi present it.

2. **"Push the error into a fresh, rounded-up symbol" for an inexact
   operation** — this is the standard way AA has always handled
   floating-point rounding. `div_round`/`mul`/`absorb_spill` are this pattern
   ported to integer remainders. The soundness argument
   (`|Σaᵢeᵢ| ≤ Σ|aᵢ|`, so lumping magnitude into one term only widens) is the
   same argument the classical literature and Arpra's "term reduction"
   already make.

3. **Bounding the smallest generators into one when capacity is exceeded**
   ("condensation") is zonotope order reduction, a named, surveyed technique
   (Girard's method and successors) that predates this crate by roughly two
   decades. `Zono::absorb_spill`'s "reduce everything past capacity to one
   fresh generator whose coefficient is the summed magnitude" is the coarsest
   possible instance of order reduction (target order 1), not a new method.

4. **Zonotopes beating interval/box arithmetic on chains that reuse a shared
   value, and being no better (sometimes worse due to the multiplication
   bound) on a single isolated nonlinear operation** — this exact tradeoff
   is the standard, textbook comparison between AA and IA, restated in nearly
   every affine-arithmetic paper and survey found.

5. **The general shape of "zonotopes let networked/distributed
   estimators converge tighter than interval estimators because they track
   correlated noise" is an established idea in set-membership estimation and
   zonotopic Kalman filtering**, and there is at least one paper doing
   zonotope diffusion across a network of agents toward "partial consensus"
   of their estimated sets (IRI-UPC, IEEE CDC 2018) — conceptually the same
   territory as the README's ring-consensus example, years earlier.

**Confidence**: high on items 1–4 (multiple independent, easily found
sources for each); medium-high on item 5 (found the right sub-field and a
directly on-point paper title/venue, but could not read that paper's full
text — the 503 on the IRI PDF meant the comparison to *this exact* claim
stayed at the abstract level, not a line-by-line check).

Sources: see §1 above (same citations apply).

---

## 3. What of ours may be genuinely novel

Graded conservatively — each item states the search run to check it and what
that search did and did not find.

- **An affine-arithmetic / zonotope implementation whose coefficients are
  integers *all the way down* — never a float, not even internally for a
  bound or a bookkeeping step — combined with `#![no_std]`, no allocator, and
  a fixed inline capacity `K` sized for a microcontroller.**
  Search run: `"integer affine arithmetic" exact zonotope`,
  `"integer-valued" OR "integer coefficients" affine arithmetic exact`,
  `crates.io rust "affine arithmetic" OR "zonotope" no_std embedded`,
  `github topic "affine-arithmetic"`. Result: every AA library found
  (libaffa, Pappus, AADD/jAADD, AffineArithmetic.jl, Arpra, NASA PVSlib's
  `affine_arith`) either explicitly uses floating point (IEEE-754, via MPFR
  in Arpra's case) or does not state its coefficient type in a way that rules
  out reals — none is stated to be integer-only. No Rust crate or GitHub
  project combining affine arithmetic/zonotopes with `no_std` + no-allocator
  + fixed capacity turned up. **This is the best candidate for a genuinely
  underexplored corner** — not because the *idea* of integer coefficients is
  hard (the algebra clearly works, as `zono.rs` demonstrates, and rational
  zonotopes already exist in JuliaReach per §1), but because nobody appears to
  have shipped it as a small, dependency-free, embedded-first package. Graded
  **plausible novelty, not proven** — absence of evidence in a web search is
  weak evidence of absence, especially for niche embedded/hobbyist code that
  may not be indexed well (e.g. private firmware, a paper behind a paywall
  this search could not reach, non-English work).

- **`Fixed<K>`: carrying the zonotope at a binary scale so that division by a
  power of two costs nothing (no rounding, no fresh symbol) and rounding
  happens once at an explicit `rescale`, rather than once per division.**
  Search run: `"affine arithmetic" "fixed point" division scale exponent
  exact no rounding`. Result: general fixed-point-arithmetic literature
  (P1368, embedded fixed-point libraries) discusses shifting to trade
  precision, but nothing combining that with affine-arithmetic noise-symbol
  bookkeeping was found. This looks like a genuine, if narrow,
  engineering contribution: applying "avoid rounding by working in a
  fixed binary scale" — itself an old fixed-point-arithmetic idea — to the
  specific problem of *when an affine form should mint a fresh symbol*.
  **Plausible novelty**, narrow in scope (it is one design decision applied
  to one operation), not independently verified against prior art beyond
  this search.

- **The specific ring-consensus/Kuramoto-style demonstration, measured
  identically across three independent language substrates (Rust, C,
  Python) with a negative control (breaking `div_pow2` stalls convergence at
  a nonzero width in exactly the substrate where it's broken).** Search run:
  covered by the consensus/distributed-zonotope searches in §1 and §2; no
  paper doing a matched multi-substrate conformance test of this kind was
  found (unsurprising — that is a software-engineering/testing practice, not
  usually a thing papers report). This is better understood as an
  **engineering-quality claim** (cross-substrate byte-identical
  reproducibility, mutation-tested condensation, a found-and-fixed soundness
  bug documented in the README) than a mathematical one, and is credible as
  novel in that narrower sense — it is not a new algorithm, it is unusually
  careful testing of a known algorithm.

- **The framing "interval arithmetic cannot conclude two consensus nodes
  agree, at any tolerance below the theoretical maximum, for any number of
  rounds; zonotopes can" as a clean worked example with numbers.** This is
  **not** a novel mathematical result (see §2, item 5 — it follows directly
  from the well-known dependency problem plus well-known zonotopic
  estimation tightness), but the specific packaging — a minimal, fully worked
  numeric table showing box stuck at 48000 forever while the zonotope reaches
  exactly 0 at round 8 — was not found pre-existing anywhere in this search.
  Treat this as **presentation/pedagogy, not discovery**.

---

## 4. What we should build on instead of beside

- **JuliaReach / LazySets.jl** already supports exact `Rational` zonotopes
  through the same codebase used for floating-point reachability analysis. If
  the goal is research-grade exact zonotope arithmetic (not an embedded
  target), building on LazySets and contributing an integer/rational-focused
  code path there would reach a far larger existing user base than a new
  crate, and would automatically inherit its other set operations
  (intersection, order reduction variants, conversions).
- **Arpra** already implements the "reduce excess affine terms" step this
  crate calls condensation, with several strategies, and is MPFR-backed
  arbitrary-precision C — worth reading its term-reduction code even if the
  eventual target stays integer-only, since it is the closest published
  implementation of the same bookkeeping problem.
- **Zonotope order reduction survey work** (Girard; Kopetzki/Schürmann/Althoff
  TUM 2017–2018; the *Automatica* comparison paper) should be the reference
  point for `absorb_spill`'s soundness argument rather than re-deriving it —
  the "replace least-significant generators by a box/single generator, never
  narrower" argument is already proven in that literature and citing it would
  strengthen the crate's own soundness commentary.
- **Logical Zonotopes / Polynomial Logical Zonotopes** (Alanwar et al.) are
  the closest existing example of "change the generator ring to make more
  operations exact" and are worth reading directly for design lessons even
  though the ring (GF(2) vs. ℤ) differs — in particular for how they handle
  operations that are *not* exact in their ring (AND/OR/NAND/NOR), which is
  structurally the same problem `zono.rs` has with multiplication.
- **Gappa**, for the rounding-to-Rocq pipeline: if a formally-checked
  soundness guarantee is ever wanted (rather than "tested and documented"),
  Gappa/Rocq is the existing, maintained toolchain that produces
  machine-checked proofs of exactly this kind of rounding-and-fresh-term
  bookkeeping, and it already understands the "new affine term captures the
  rounding error" pattern natively.
- **For the "distributed nodes converge" story specifically**, the
  IRI-UPC "Distributed Set-membership Approach based on Zonotopes for
  Interconnected Systems" line of work and the zonotopic-Kalman-filter
  literature (Combastel and successors) are the right prior work to cite and
  differentiate from, rather than presenting the consensus-agreement result
  as unprecedented.

Sources: as cited in §1.

---

## 5. Where the actual frontier is

Based on what turned up above, the open ground — beyond both this crate and
what already exists — looks like it clusters around three things:

1. **Exact multiplication, not just exact addition/subtraction.** The
   2024–2025 reachability-analysis literature (constrained polynomial
   zonotopes, matrix zonotopes closed under multiplication,
   arXiv:2504.02147 and related 2025 papers) is actively moving past
   classical affine arithmetic's "bound the nonlinear remainder in a fresh
   symbol" rule precisely because it is lossy on multiplication-heavy chains
   — which is the same weakness `zono.rs`'s own docs and `mul_vs_box`-style
   tests already admit for `x·x`. A genuinely frontier-pushing extension of
   this crate would be an integer/embedded analogue of a representation
   that is closed (or closer to closed) under multiplication, not another
   pass at plain affine forms.
2. **A formally checked (not merely tested) soundness proof of the integer
   bookkeeping**, in the Gappa/CoqInterval/Flocq tradition. This crate found
   and fixed a real soundness bug (`absorb_spill` merging into a *shared*
   symbol, which let disagreement come out too narrow) purely through a
   stress-test sweep; the formally-verified-arithmetic community's whole
   point is that this class of bug is exactly what a machine-checked proof
   is supposed to catch before it ships, rather than after a sweep happens
   to exercise it. Closing that gap — a Rocq or Lean proof that
   `Zono::sub`/`absorb_spill`/`div_round` are sound for all inputs, not just
   the cases in the test suite — is squarely the open problem this
   sub-field exists to solve, and it is unaddressed here.
3. **Sound (not probabilistic) set-based uncertainty running natively, in
   integers, on real MCU hardware, as opposed to either (a) reachability
   analysis done offline in MATLAB/Julia to verify an embedded system's
   design, or (b) on-device *probabilistic* uncertainty quantification for
   ML inference (e.g. QUTE, arXiv:2404.12599, which targets tinyML ensembles,
   not guaranteed bounds).** This search did not find an existing library
   occupying exactly that spot — sound, deterministic, integer, on-MCU,
   zonotope-based. That gap is real as far as this search could tell, but
   the honest caveat is that a from-scratch web search is a weak way to
   prove a negative in embedded/firmware work, where a lot of relevant prior
   art is proprietary, undocumented, or simply not indexed. This should be
   stated to the user as "the closest thing to open ground we found," not as
   a confirmed first.

Sources:
- [Data-Driven Nonconvex Reachability Analysis using Exact Multiplication (arXiv:2504.02147)](https://arxiv.org/abs/2504.02147)
- [Data-Driven Reachability Analysis Using Matrix Zonotopes](https://www.researchgate.net/publication/354527850_Data-Driven_Reachability_Analysis_Using_Matrix_Zonotopes)
- [coq-interval 4.11.3](https://rocq-prover.org/p/coq-interval/4.11.3)
- [Certification of bounds on expressions involving rounded operators (Gappa)](https://arxiv.org/pdf/cs/0701186)
- [QUTE: Quantifying Uncertainty in TinyML with Early-exit-assisted ensembles (arXiv:2404.12599)](https://arxiv.org/abs/2404.12599)
- [Verification of Uncertain Embedded Systems by Computing Reachable Sets based on Zonotopes](https://www.sciencedirect.com/science/article/pii/S1474667016397567)

---

## Notes on method and confidence

- This review is web-search-based only; several primary sources (the IRI-UPC
  distributed-zonotope PDF, some ResearchGate/paywalled items) could not be
  fully fetched, so claims resting on those are marked accordingly above
  rather than stated flatly.
- No claim above should be read as "we checked every possible prior
  publication" — a negative result here (e.g. "no integer-only affine
  arithmetic crate found") means exactly that: not found by this search, on
  this date, with these queries. It is not a patent-style clearance search.
- The one section required to be non-empty by the task brief — "what is not
  novel" — is populated with five items, each independently confirmed by at
  least one clear primary or secondary source, so there was no need to
  invoke the "found genuinely nothing" fallback.
