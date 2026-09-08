# Conformance-stream: state of the art

Scouting report on where "walk a deterministic PRNG sequence through every
substrate and fold every answer into one checksum" sits relative to
established practice, as of September 2026. Written against
`build/CONFORMANCE-STREAM.md` and `build/check-substrates.sh`.

Honesty check up front: **this is not a new idea.** The core mechanism —
generate many cases from a seed, run them through N implementations, reduce
each implementation's trace to one small comparable value — is a named,
decades-old technique with a direct, almost embarrassingly close ancestor
(Csmith, 2011). What is less standard is *what we fold* (representation, not
just result) and *why* (a stream built specifically to reach past a fixed
golden-vector corpus, with the reach measured by a mutation the corpus
provably cannot catch). Sections below try to keep those two claims — "this
part is old" and "this part is a real, checked difference" — visibly
separate.

---

## 1. The established name(s) for what we built

There is no single canonical name because the technique sits at the
intersection of three named things, and our stream borrows from all three:

- **Differential testing** (Fokus / McKeeman 1998 lineage) — running the same
  input against multiple implementations and comparing outputs, treating
  disagreement itself as the failure signal, with no independent oracle
  required. This is the umbrella term for "N substrates, same input, compare."
  [Differential Fuzzers overview](https://www.emergentmind.com/topics/differential-fuzzers), [Quarkslab: differential fuzzing for cryptography](https://blog.quarkslab.com/differential-fuzzing-for-cryptography.html)

- **Random differential/compiler testing with a checksum oracle** — the
  specific shape of reducing a long random execution to one small comparable
  digest instead of comparing full output streams. **Csmith is the direct
  ancestor of our mechanism**: each generated C program "computes a checksum
  of the program's non-pointer global variables at the end of the program's
  execution... prints the checksum, and exits," and a driver script compares
  that one printed number across compilers — any difference indicates a
  miscompilation. [Csmith README](https://github.com/csmith-project/csmith/blob/master/README.md), [Finding and Understanding Bugs in C Compilers (PLDI'11)](https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf)

- **Metamorphic testing** — used here loosely, for the general "test oracle
  problem" framing: when there is no independent ground truth for a random
  case, you check a *relation* (here: "all three substrates compute the same
  fold of the same trace") instead of a fixed expected answer. [Metamorphic Testing: A Simple Method for Alleviating the Test Oracle Problem](https://ieeexplore.ieee.org/document/7166267/), [Metamorphic Testing: A Review of Challenges and Opportunities (ACM CSUR 51:1)](https://dl.acm.org/doi/10.1145/3143561)

If a single label is wanted, the closest fit in the literature is
**"checksum-oracle differential testing"** or, in the fuzzing-oracle
taxonomy, a **differential oracle with a reduced (hashed) output** — as
opposed to a crash oracle, a metamorphic-relation oracle, or a
constraint-solving oracle. [Oracle taxonomy discussion](https://www.blackduck.com/glossary/what-is-fuzz-testing.html)

What we called the "conformance stream" is, structurally, **Csmith's
checksum idea run backward**: Csmith *generates programs* and checksums their
final state to test *compilers*; we generate *inputs* from a PRNG and
checksum the *results of calling library operations directly* to test
*library ports*. Same reduction, different generation target. This is close
enough that "novel" would be an overclaim for the base mechanism — what is
different is covered in §4.

---

## 2. Who already does this and how, concretely

| Project | Domain | Mechanism | Reduction shape |
|---|---|---|---|
| [Csmith](https://github.com/csmith-project/csmith) | C compiler testing | Generate random C programs; compile with N compilers; run each binary | Program prints one checksum over all global variables at exit; driver diffs the printed numbers [Csmith checksum mechanism](https://frama-c.com/2012/01/16/Csmith-testing.html) |
| [SQLite TH3](https://www.sqlite.org/testing.html) | SQL engine correctness | ~1.9M distinct test instances at full coverage, run to 100% MC/DC | Per-case pass/fail plus checksums of query results in some suites; proprietary, not public [How SQLite Is Tested](https://www.sqlite.org/testing.html) |
| [SQLLogicTest](https://sqlite.org/sqllogictest) | Cross-engine SQL result equivalence | A reference engine (originally SQLite) fills in expected results for millions of generated queries; other engines are validated against that filled script | Per-query result comparison, not a folded checksum — closer to our golden-vector layer than our stream layer [SQLLogicTest docs](https://sqlite.org/sqllogictest), [Sqllogictest Illustrated](https://medium.com/@databend/sqllogictest-illustrated-2807a92e1149) |
| [WebAssembly spec testsuite](https://github.com/WebAssembly/testsuite) | Interpreter/engine conformance | Hand- and generator-written `.wast` scripts run against the reference interpreter and engines under test | Per-assertion pass/fail, not a stream/checksum [WebAssembly/spec test/core](https://github.com/WebAssembly/spec/tree/main/test/core) |
| [Ethereum execution-spec-tests (EEST)](https://github.com/ethereum/execution-spec-tests) | EVM client consensus | Python reference (`t8n`) "fills" JSON test fixtures (inputs + expected state root); every execution client consumes the same fixtures | Comparison is on the computed **state root** — itself already a hash-folded summary of an entire post-execution world state, structurally very close to our checksum fold [EEST filling docs](https://eest.ethereum.org/main/filling_tests/) |
| SpecTrum (2026) | Ethereum consensus clients | Differential fuzzing guided by a *mechanized* spec (Consensus-SpecTec) rather than hand-picked cases | Found cross-client divergences hand-written spec tests missed — the same "corpus is 801 opinions" gap we measured, independently arrived at [SpecTrum paper](https://arxiv.org/abs/2608.17738) |
| [Project Wycheproof](https://github.com/C2SP/wycheproof) | Crypto library testing | Curated JSON test vectors targeting known attack classes, run against many libraries | Golden-vector style (like our 801), not a stream — explicitly *not* trying to cover the full input space, only known-dangerous corners [Wycheproof README](https://github.com/C2SP/wycheproof/blob/main/README.md) |
| [Berkeley TestFloat](https://github.com/ucb-bar/berkeley-testfloat-3) | IEEE-754 FP conformance | Compares an implementation's FP op results against SoftFloat, a reference software FP implementation, across generated operand sets, all 5 rounding modes | Per-operation comparison against a trusted oracle implementation, not folded [TestFloat docs](http://www.jhauser.us/arithmetic/TestFloat-3/doc/TestFloat-general.html) |
| [FoundationDB simulation](https://apple.github.io/foundationdb/testing.html) / [TigerBeetle VOPR](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/internals/vopr.md) / [madsim](https://github.com/madsim-rs/madsim) | Distributed systems correctness | Deterministic PRNG drives *all* nondeterminism (network, disk, clock); seed + commit hash reproduces any run exactly | TigerBeetle checksums every committed request and asserts checksums match across replicas as the state advances — a running/streaming checksum used as a cross-node **agreement** oracle, not cross-language, but the same "one number instead of the whole log" idea [VOPR docs](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/internals/vopr.md), [FoundationDB simulation](https://apple.github.io/foundationdb/testing.html) |

**The closest single match to our exact recipe is Csmith's global-variable
checksum**, published 2011, extremely well cited, and still the reference
point every subsequent compiler-fuzzing paper compares against. Our version
differs in fold target (arbitrary-op traces, not compiled-program state) and
in having a documented representation-level second stream (see §4), but the
"reduce a long random execution to one folded number, compare that number
across N implementations" shape is the same shape.

The Ethereum EEST "state root" comparison is worth calling out separately: a
state root **is** a Merkle-hash fold over an entire execution's final state,
computed identically to detect any single-bit divergence anywhere in a huge
state tree — functionally a cryptographic-strength version of our FNV fold,
independently converged on for the same reason (many cases, one comparable
number, cheap to store and compare). [EEST fixtures](https://eest.ethereum.org/main/filling_tests/)

---

## 3. What of ours is standard practice

This list is not empty — most of the mechanism is standard, and it would be
dishonest to imply otherwise:

- **Reducing a long trace to a single comparable digest to make
  differential testing cheap at scale.** Standard since at least Csmith
  (2011); the whole point there and here is the same: comparing full outputs
  for millions of cases is expensive to store and diff, comparing one number
  per run is not. [Csmith](https://github.com/csmith-project/csmith/blob/master/README.md)
- **A deterministic PRNG seeded once, walked identically by every
  substrate, so any run is exactly reproducible from the seed alone.**
  Standard practice in the deterministic-simulation-testing world
  (FoundationDB, TigerBeetle, madsim, Antithesis) — there for whole-system
  nondeterminism, here for input generation, same principle. [FoundationDB simulation](https://apple.github.io/foundationdb/testing.html), [madsim](https://github.com/madsim-rs/madsim)
  Explicit spec-level care about arithmetic (unsigned wraparound, logical vs.
  arithmetic shift, `%` on negatives) matching bit-for-bit across languages
  is exactly the discipline the reproducible-builds and cross-language
  determinism literature calls out as the central hard problem. [Reproducible Builds May 2025 report](https://reproducible-builds.org/reports/2025-05/)
- **A checksum stream as a second, cheaper net layered *on top of* a
  curated golden-vector corpus, not a replacement for it.** This mirrors
  how Wycheproof (curated, attack-focused) and TestFloat/SQLLogicTest
  (broad, generated) coexist in the crypto and database worlds respectively
  — narrow-and-deep plus broad-and-shallow are both considered necessary,
  not either/or. [Wycheproof](https://github.com/C2SP/wycheproof/blob/main/README.md)
- **Treating divergence itself as the oracle, with no independent "ground
  truth" needed**, i.e. metamorphic-relation-style testing ("all substrates
  agree" is the invariant, not "the answer is X"). This is the textbook
  answer to the test-oracle problem when no cheap independent oracle exists.
  [Metamorphic Testing survey](https://dl.acm.org/doi/10.1145/3143561)
- **Verifying detection power by deliberately reintroducing known bugs
  and recording which layer catches which** (the mutation table in
  `CONFORMANCE-STREAM.md`). This is standard mutation-testing practice
  applied to a test *harness* instead of to application code — an honest,
  unglamorous, well-understood technique, not a novel one.

None of the above is a weakness to hide — it is exactly what a reviewer
familiar with Csmith, FoundationDB, or Wycheproof would expect to see, and
its presence is what makes the stream credible rather than a stunt.

---

## 4. What of ours is unusual or better — defended

Three things did not turn up as an established pattern after the searches
run for this report (§1–§2, plus the additional queries in §6). Each is
marked with what was searched to check it.

**(a) A second, separate stream that folds internal representation, not
just the observable interval/result, specifically to catch soundness bugs
that cancel at the result level.**
The zonotope stream's stated purpose — "two substrates that condense
differently can agree on a width by coincidence; they cannot agree on the
term list by coincidence" — is a real methodological move: comparing
*results* alone is exactly what Csmith, EEST's state root, and TestFloat all
do (compare the observable output), which is sufficient for most
correctness bugs but provably insufficient for a soundness bug that two
*different, both-wrong* condensation strategies could produce and then have
cancel out under subtraction. Searches for "representation-level"
differential testing, internal-state checksumming (as opposed to
output-state checksumming), and soundness-preserving-cancellation bugs in
interval/zonotope arithmetic did not surface a named prior-art pattern for
this — abstract-interpretation soundness bugs are a known research topic
generally, but folding *both* a results-stream and a *separate*
representation-stream, with the split documented and mutation-tested
independently, was not something the search turned up as a named or common
technique. Marked **UNVERIFIED as globally unique** — the search space
(zonotope/interval-arithmetic implementations across languages held to
representation-level cross-checks) is narrow enough that a targeted academic
search (e.g. in the abstract-interpretation or verified-numerics literature
specifically) might still find prior art this general web search missed.

**(b) Measuring a golden corpus's blind spot with a synthetic marker
mutation the corpus is designed to miss, and reporting that honestly
(“passes / passes / caught”) rather than only reporting catches.**
The mutation table's honesty about the first four rows ("the stream is a
second net, not the only one — worth saying plainly rather than implying
the stream found them") plus row five specifically constructed to be
*outside* the corpus's swept ranges is a controlled-negative-result
methodology. The closest parallel found is SpecTrum's finding that "22 of
27 [Ethereum consensus] divergence cases cannot be found without the
premises inserted in their mechanization" [SpecTrum](https://arxiv.org/abs/2608.17738) — i.e.
someone else has independently measured "our hand-picked corpus has a
provable blind spot the generated stream covers," which validates the
*finding* as a real and recurring phenomenon, but SpecTrum arrived at it via
spec mechanization, not via a deliberately planted marker bug used as a
calibration instrument. Using a *synthetic, deliberately-placed* mutation as
a calibration probe for a test layer's reach — rather than only using
naturally-occurring historical bugs — is closer to mutation-testing
methodology (measuring mutation-kill-rate of a *test suite*) than to
differential-fuzzing methodology; applying it to compare *layers of a
harness against each other* (unit tests vs. golden vectors vs. stream) is
the specific move that did not turn up named elsewhere in this search.

**(c) Running the divergence-detection claim under a self-imposed negative
control** (`divergence/make check`, described in `check-substrates.sh` as
asserting "a negative control on itself, so a study with no contrast fails
rather than reassures"). This is good experimental-science hygiene
(negative controls) applied to a test-infrastructure claim, which is
uncommon enough in software testing writeups that no direct named
equivalent surfaced.

Net honest assessment: **the base mechanism (a) is not novel — it is a
well-known technique (closest ancestor: Csmith) applied to a new domain.**
What is genuinely harder to find precedent for is the *methodological
scaffolding around it* — a second representation-level stream targeting a
specific soundness-cancellation failure mode, and treating the harness's own
blind spots as something to be measured and reported rather than assumed
away. That scaffolding, not the checksum-fold idea itself, is the
defensible claim to being ahead of common practice.

---

## 5. How conformance programmes actually get adopted — the practical lesson

Four data points, each with a different adoption story:

- **Web Platform Tests / Interop project**: succeeded because of a **shared
  dashboard with prioritization**, not just a shared test suite. Any vendor
  can see, per feature, "which tests we fail that the other three engines
  pass," which turns an abstract conformance obligation into a ranked to-do
  list. Adoption required an explicit *cultural* decision (all new browser
  work must ship with WPT-shareable tests) — the tooling existed for years
  before that culture shift made it load-bearing. [How a Shared Test Suite Fixed the Web's Biggest Problems](https://thenewstack.io/how-a-shared-test-suite-fixed-the-webs-biggest-problems/), [WPT interop project](https://github.com/web-platform-tests/interop)
- **Khronos CTS (OpenGL/Vulkan)**: succeeded via a **formal Adopter
  program tied to trademark and IP rights** — you cannot call your driver
  "Vulkan conformant" or use the logo without running the CTS and
  submitting results for review. The incentive is external (naming rights,
  legal cover), not intrinsic motivation to test more. The CTS itself has
  been open source since 2016+, but that alone did not create adoption —
  the certification/branding requirement did. [Khronos open-sources conformance tests](https://www.khronos.org/news/press/khronos-open-sources-opengl-and-opengl-es-conformance-tests), [Vulkan CTS adopter process](https://docs.vulkan.org/guide/latest/vulkan_cts.html)
- **SQLLogicTest**: succeeded organically, with **no certification
  authority at all** — it spread because it is directly *useful* to any
  engine author (millions of free, engine-neutral test cases with expected
  answers already computed by a reference engine) at zero marginal
  integration cost; DuckDB and Databend both ship first-class SQLLogicTest
  support unprompted by any governing body. [DuckDB sqllogictest docs](https://duckdb.org/docs/lts/dev/sqllogictest/intro), [Sqllogictest Illustrated](https://medium.com/@databend/sqllogictest-illustrated-2807a92e1149)
- **OpenID Connect self-certification**: succeeded via **low-cost,
  low-ceremony self-declaration plus a public registry**, explicitly chosen
  over a heavier lab-certification model because "the rapid adoption of
  OpenID Connect worldwide required the creation of light-weight
  certification processes." Trust comes from transparency (public log of
  who self-certified what) rather than from a gatekeeper. [OpenID self-certification FAQ](https://openid.net/what-is-self-certification-faq/), [OpenID Connect RP certification adoption](https://openid.net/openid-connect-relying-party-certification-adoption/)

**The practical lesson for making ours matter:** none of these programmes
succeeded on rigor alone — 801 golden vectors plus a million-case stream is
already more rigorous than most of the above required for adoption. What
made each one *matter* was one of: (1) a shared, rankable dashboard that
turns pass/fail into a prioritized worklist (WPT), (2) an external
incentive tied to a name/brand a vendor wants (Khronos), or (3) frictionless
integration cost for the adopter — drop in a file, get value immediately,
no governance overhead (SQLLogicTest, Wycheproof). For a single-repository,
three-substrate project, the Khronos-style branding lever doesn't apply and
a WPT-style cross-vendor dashboard is premature — the SQLLogicTest/Wycheproof
model is the fit: **publish `stream.json`, the seed, and the exact
per-language "one command to reproduce this checksum" recipe as something a
fourth-language port could run in five minutes and get an unambiguous
pass/fail against**, with zero integration ceremony. If a fourth
implementation (say, a WASM or Go port) ever gets written, "run
`check-substrates.sh`-equivalent, match `stream.json`'s checksums" is the
whole onboarding story — that low-friction repeatability, not a badge, is
what would make the artifact matter beyond this repository.

---

## 6. The frontier — the specific open problem, and its tractability

Assessed against the four candidates in the brief:

**Proof-carrying conformance (checksum + machine-checked proof the
semantics match a formal spec).** This exists as an active, fast-moving
research area but is *not* solved end-to-end for a case like ours. The
closest direct precedent is [**"Equivalence Checking of a libm Port"**](https://link.springer.com/chapter/10.1007/978-3-031-90653-4_12) —
bounded SMT-based equivalence checking (Z3/CVC5 via Corral/Boogie) between a
**Rust port and the musl (C) implementation** of libm math functions,
i.e. exactly our situation (a numerics library, ported across languages,
needing byte/bit-exact agreement), but *bounded* (loops unrolled to a fixed
depth, not universally quantified) rather than a full proof. Proof-carrying
code as a general mechanism (Necula & Lee, 1996) is well established for
*single-language* safety properties (type/memory safety) via a certifying
compiler, but "prove cross-language arithmetic equivalence and carry that
proof" is not a turnkey pipeline anywhere found. [Proof-carrying code (Wikipedia)](https://en.wikipedia.org/wiki/Proof-carrying_code), [libm port equivalence checking](https://www.researchgate.net/publication/391420307_Equivalence_Checking_of_a_libm_Port)

**Automatically deriving ports from one spec and proving equivalence**
(translation validation / Alive2-style / Lean-Rocq extraction). Translation
validation (Alive2) is mature and highly successful **within one IR**
(LLVM optimization passes: "discovered and reported 47 new bugs" by
symbolically comparing pre/post-optimization IR) [Alive2 PLDI'21](https://users.cs.utah.edu/~regehr/alive2-pldi21.pdf) but that
success has not transferred to **cross-language** translation validation at
this scale — SMT-based transpilation equivalence checking (Z3-based
first-order-logic encodings of source and target) exists for small,
scoped cases but is still a research-paper-per-benchmark activity, not a
tool you point at a whole library. [SMT transpilation equivalence checking survey results](https://doi.org/10.3390/technologies13120580) Rocq/Lean *extraction* (proving a spec correct once, in a
proof assistant, then mechanically extracting implementations) is the
strongest form of "derive-and-prove," and is real and shipping (Rocq's
verified extraction pipeline; CompCert is the flagship prior example of a
formally verified compiler produced this way) [Compiling Lean programs with Rocq's extraction pipeline](https://www.normalesup.org/~sdima/2025_extraction_report.pdf), [Formal Certification of a Compiler Back-end](https://xavierleroy.org/publi/compiler-certif.pdf) — but it requires
writing the *original* spec inside the proof assistant, which is a much
larger undertaking than writing `CONFORMANCE-STREAM.md` in prose and porting
it by hand three times, as we did.

**Semantic diffing across languages.** No mature, general-purpose tool
found; what exists is either narrow (per-domain metamorphic oracles, e.g.
SQL-query-equivalence oracles for database differential testing) [Argus SQL metamorphic oracle](https://arxiv.org/pdf/2607.10277) or
early-stage LLM-assisted work explicitly framed as **disproving** rather
than proving equivalence — i.e. using an LLM to find a counterexample where
two implementations diverge, which is a *complement* to our stream (find
the specific input that breaks agreement) rather than a replacement for it.
[Disproving Program Equivalence with LLMs](https://arxiv.org/pdf/2502.18473)

**LLM-generated ports plus a conformance oracle.** This is the most active
2024–2026 area and the most directly actionable one. [**Verified Code
Transpilation with LLMs / LLMLIFT**](https://arxiv.org/abs/2406.03003) (NeurIPS 2024) combines an LLM
with program synthesis ("verified lifting") to transpile code *and* attach
a functional-correctness proof for each function transpiled, matching a
hand-engineered domain-specific baseline (Tenspiler) on 23 benchmarks
without ~1200 lines of domain-specific synthesis code. This is squarely
"LLM writes the port, a mechanized checker either proves or rejects
equivalence" — the shape asked about in the brief — and it works today, at
small-function scale, for numeric/array kernels.

**Judgement on tractability, ranked:**

1. **Tractable and worth doing now: an LLM-generated fourth port, gated by
   the existing stream as an acceptance oracle, with per-function SMT
   equivalence checking (à la the libm-port paper) as a second, stronger
   gate on the hot arithmetic core only** (the handful of functions the
   `CONFORMANCE-STREAM.md` spec calls out as bit-fragile: `%` on negatives,
   shift direction, saturation). This does not require writing a formal
   spec in a proof assistant — it bolts bounded SMT equivalence checking
   (already demonstrated for exactly this kind of numerics-port problem)
   onto the existing checksum stream as a second, independent line of
   evidence for the small set of operations where "the stream agrees" and
   "the semantics provably match" are not yet the same claim. This is the
   single highest-leverage move: it converts the frontier from "prove the
   whole library" (intractable at our resourcing) to "prove the dozen
   functions the spec already flags as dangerous" (a bounded, scoped
   SMT problem with a working precedent).
2. **Tractable but a larger investment: full Rocq/Lean extraction of the
   arithmetic core**, using `CONFORMANCE-STREAM.md` as the starting spec
   prose. This would make the checksum-stream claim ("all substrates agree
   on a million random cases") into a claim of the strictly stronger form
   ("all substrates match a machine-checked specification, and here is the
   proof"), closing the gap the mutation table itself admits ("the stream
   is a second net, not the only one" — a proof closes that gap for good on
   the covered operations, where a stream only samples it). Tractable in
   principle (CompCert and Rocq's own extraction pipeline are existence
   proofs this works at real scale), but a substantially bigger effort than
   (1) and better scoped as a follow-on once (1) identifies which functions
   most need it.
3. **Not yet tractable as a general solution: fully automatic
   spec-to-N-languages derivation with proved equivalence for an entire
   library**, or general-purpose cross-language semantic diffing as a
   reusable tool. Both remain open research problems (per-benchmark papers,
   not general tools) as of this search; claiming either as "solved" would
   be dishonest given what turned up.

The frontier worth attacking, concretely: **do not try to out-prove Rocq
extraction from a standing start — instead close the gap the harness
already admits, by adding bounded per-function SMT equivalence checking
(Z3/CVC5) for the handful of operations `CONFORMANCE-STREAM.md` already
names as bit-fragile, using the libm-port paper's method as the template.**
That is a scoped, precedented, achievable project that would put this
repository ahead of every prior-art item found here except the libm-port
paper itself — and unlike that paper, ours would have the checksum stream
*and* the golden vectors as corroborating evidence layers underneath the
proof, which as far as this search found, no one else has assembled
together for a cross-language numerics library.

---

## Sources

All citations are inlined above as markdown links at point of use. Items
explicitly marked UNVERIFIED in §4(a) reflect the limits of a web-search-only
scouting pass, not a claim of exhaustive literature review — a targeted
search of the abstract-interpretation / verified-numerics academic
literature (rather than general web search) is the natural next step before
asserting novelty of the representation-level zonotope stream with full
confidence.
