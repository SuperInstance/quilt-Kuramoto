# 10 — ML Repos Scout Report: polln, elephant, thought-amplifier, CognitiveEngine, SuperInstance

Scout pass on the four largest AI/ML repos (plus the org root) that no previous
scout had opened. Inventory graded them SUBSTANTIVE by line count alone; that
grade is tested here against actual source content, running tests, and
evaluation evidence. All five were cloned fresh (`--depth 1`) and inspected
directly — nothing here is taken from READMEs without checking the code.

## 1. Summary table

| Repo | Real source LOC (method) | Vendored/data/generated LOC | Tests (n, pass?) | Evaluation present? | LLM provider/models |
|---|---|---|---|---|---|
| **polln** | ~522K code + ~111K project markdown (`cloc`, excluding `docs/`, `agent-messages/`, `dialogues/`, `white-papers/`, `test-output-loras/`, `playwright-report/`, `extracted/`, JSON/`.pyc`) | ~1.2M lines excluded: `docs/archive` + `docs/research` (25M of markdown/JSON), `agent-messages/` (3.1M of AI-agent chat logs), `test-output-loras/` + duplicate copies under `docs/archive/test-outputs/` (128K JSON blobs ×  dozens), lockfiles, Playwright HTML report, `extracted/` (byte-identical duplicate of `repos/`) | 142 Jest suites: **120 failed to compile, 22 passed**; 788 individual tests ran, 773 passed / 15 failed | **Yes, but simulated** — `src/benchmarking/baseline-comparison.ts` "compares SMP vs monolithic LLM calls" using a keyword-matching `simulateLLM()`, not a real model call | DeepSeek (`deepseek-chat`, current) for research simulations; internal LoRA pipeline defaults to OpenAI `gpt-4` and Anthropic **`claude-3-opus-20240229`** (stale dated snapshot) |
| **elephant** | ~30.4K code + ~13.9K markdown (`cloc`, excluding `data/`, `assets/`, `checkpoints/`) | ~76M of 131M repo size: `data/` (48M, JSONL wave-experiment logs), `assets/` (22M images), `checkpoints/` (6M real `.pt`/`.npy` model artifacts — legitimate but not source) | `pytest`: **364 passed, 12 skipped** (skips = missing `torch` + missing local fixture data), 0 failed | **Yes, real** — von Mises–Fisher κ estimation, OAS-shrinkage covariance, jackknife-SE drift alarms with a documented false-alarm postmortem | DeepInfra-routed: `anthropic/claude-haiku-4-5` (current), `deepseek-ai/DeepSeek-V4-*`, `zai-org/glm-4.7-flash` (all current) |
| **thought-amplifier** | ~13.6K code + ~10.6K markdown (`cloc`, excluding `experiments/`, `figures/`, `assets/`, `logos/` — which are legitimate result data, not noise) | None found to be junk; `experiments/` (1.9M) is real recorded experiment output, not vendored code | `pytest`: **622 passed, 0 failed** (444+37+70 claimed in README, actual today is higher); CI runs same suite on Python 3.10–3.12 | **Yes, real** — controlled experiment (baseline/conductor/random/sham arms, n=20/phase) with t-tests, p-values, Cohen's d, and an honest "scorer is an LLM, not human raters" caveat | Ollama-local `granite3.1-dense:2b`, `qwen2.5:0.5b`; cloud fallback GLM (Z.AI) and DeepSeek `deepseek-chat` (current). No Anthropic/OpenAI calls found. |
| **CognitiveEngine** | **226 lines** of hand-written product code (`src/`) + 2,333 lines in one of five "extracted tools" | 10,201 md lines (36 files) + 4,938 YAML lines (22 CI workflows) for a product with no working implementation; 4 of 5 `extracted-tools/` packages contain zero code files | CognitiveEngine itself: **0 tests** (no test files exist despite `"test": "vitest"`). `extracted-tools/provider-abstraction-layer`: tests **fail to collect** (broken relative imports) | **No** — no benchmark, no metric, nothing to evaluate; the entire "5-level abstraction" pipeline is a TODO stub | None functional in `src/`; the one real sub-package's test fixtures reference **`claude-3-5-haiku-20241022`** (dated snapshot, ~2 years old as of Sept 2026) |
| **SuperInstance** (org root) | ~5.4K code (Python/TS/Rust/JS/Shell/SQL/Dockerfile) + ~13.2K markdown, `cloc` excluding `assets/images/media/icons/INDEXES/docs/AI-Writings` | 25 git-submodule links (`agent-homeostasis-rs`, `categorical-agents-rs`, `hodge-consensus-rs`, `tropical-geometry-rs`, etc.) point to commits but ship **no `.gitmodules`** — all 25 are empty directories in any clone, content unverifiable | `tests/` (Python SDK): **141 passed, 0 failed** | **Mixed** — real `z_threshold: 2.0` anomaly code exists (`fleet-metrics/src/lib.rs`), but the flagship "live" report quotes numbers that contradict the code's own pass/fail rule (see §4) | DeepInfra `deepseek-ai/DeepSeek-V4-Flash` (current) in the SDK; example files reference generic `gpt-4o` / `claude-3-sonnet` (no dated snapshot, ambiguous freshness) |

Note on method: "real source LOC" = `cloc` run per repo with a first pass at the
full tree, then a second pass excluding directories confirmed by manual
inspection (`find`, `du -sh`, sampling files) to be docs/archive, AI-agent
chat transcripts, generated reports, data blobs, or lockfiles — never assumed
from directory names alone. Duplication (e.g. polln's `repos/` vs `extracted/`
holding near-identical copies of the same npm packages) is flagged where
found; full de-duplication was not performed everywhere due to time, and is
called out per-repo below.

---

## 2. Per-repo detail

### polln — "Pattern-Organized Large Language Network"

**What it actually does.** A TypeScript monorepo (`npm`, Jest, `tsc`)
implementing a multi-agent decision framework: a Gumbel-Softmax "Plinko
Layer" for stochastic agent selection (`README.md:11-13`), a DreamerV2-style
VAE world model for offline "dreaming" rollouts, a "Confidence Cascade"
hierarchical signal propagator with deadband hysteresis
(`repos/confidence-cascade/src/confidence-cascade.ts:38-40` —
`greenThreshold: 0.85`, `yellowThreshold: 0.60`), and a much larger
"spreadsheet" product (`src/spreadsheet/`, 503 TS files) that appears to be
the actual bulk of ongoing engineering effort, plus 302 Python research
scripts under `simulations/` that call DeepSeek's API for domain-specific
math/physics reasoning (e.g. `simulations/math/control-theory/deepseek_control.py:44-46`
hits `https://api.deepseek.com` with model `"deepseek-chat"`).

**Tests.** `npm install` succeeds (933 packages, no network issues). Running
the full Jest suite (142 suites) took over 3 minutes and produced:
```
Test Suites: 120 failed, 22 passed, 142 total
Tests:       15 failed, 773 passed, 788 total
```
The 120 failing suites overwhelmingly fail **to compile**, not to pass
assertions — e.g. `src/superinstance/__tests__/confidence-cascade.test.ts:219`
calls a private method (`TS2341: Property 'propagateConfidence' is private`),
and `src/spreadsheet/core/RateBasedChangeSystem.ts:523` has an unguarded
possibly-undefined access (`TS18048`) that breaks its own test file. Both of
these are in the exact deadband/confidence-cascade code most relevant to
exact-band. Where suites do compile, the 773/788 pass rate on individual
tests is real and includes meaningful assertions (`toBeCloseTo`,
state-graph checks), not smoke tests — see
`src/superinstance/__tests__/confidence-cascade.test.ts:40-44`. **Verdict:
tests exist and are meaningful where they run, but ~85% of the suite is
currently broken at the TypeScript level** — this is reproduced, not
inferred from a badge.

**Evaluation.** `src/benchmarking/baseline-comparison.ts` frames itself as
"Compare SMP tile chains vs monolithic LLM calls" (`:5-7`) with a full report
generator (latency/accuracy/confidence/energy, Pareto ranking). But:
```ts
// src/benchmarking/baseline-comparison.ts:118-120
private async simulateLLM(prompt, context) {
  // In production, this would call actual LLM
  ...
```
and
```ts
// src/benchmarking/baseline-comparison.ts:200-203
private calculateAccuracy(output: any, context): number {
  if (output.confidence) return output.confidence * 0.95;
  return 0.80;
}
```
`accuracy` is a fabricated function of `confidence`, and "monolithic LLM"
output is generated by keyword matching (`simulateSentimentAnalysis`,
`:138-149`), not a model call. `src/benchmarks/` (a separate, larger
benchmark CLI) shows the same pattern — GPU/federation "benchmarks" fill
arrays with `Math.random()` (`src/benchmarks/federation-benchmarks.ts:183-185`,
`src/benchmarks/gpu-benchmarks.ts:296,349,394-395`). **This is exactly the
"framework with no evaluation is a framework with no evidence" case the task
description warns about — polln has an elaborate benchmark *harness* with no
real evaluation running through it.**

**Numeric tolerance / thresholds.** Real and substantial. `src/spreadsheet/core/RateBasedChangeSystem.ts:47-60` defines `DeadbandConfig` with fixed,
statistical (k-sigma), and adaptive (EMA-smoothed) deadbands, a minimum-width
floor, and an anomaly detector (`:487-550`) returning `{isAnomaly, deviation,
deadband: {lower, upper}}`. `repos/confidence-cascade/src/confidence-cascade.ts:37-40`
hard-codes zone thresholds (green ≥0.85, yellow ≥0.60). This is directly the
shape of exact-band's problem — and it's also the code that currently fails
to compile in tests.

**Honest read:** polln is the largest, most feature-dense of the five, and
some of it (the deadband math, the confidence-cascade design) is genuinely
sophisticated. But the "benchmark" layer is decorative — every accuracy
number it would produce is synthetic — and the majority of its test suite
cannot currently run. Treat the 744K-line inventory figure as roughly 4x
inflated by docs/archive, chat logs, and data blobs; the real code is closer
to half a million lines, itself unusually large for a project with no
working evaluation loop.

### elephant — "the inter-model temperature"

**What it actually does.** A small (~30K LOC), unusually self-aware Python
research repo. It reads a chat/message stream as a "room" and computes a
vector of hand-crafted "dial" readings (mood, panic, presence, etc. —
keyword heuristics, explicitly labeled as such:
`README.md:26-28`, *"the dials are keyword heuristics, honestly labeled;
'JEPA' is the aspiration, not yet an implementation (the backbone is a
stub)"*). On top of the dial readings it fits a real von Mises–Fisher
distribution (`elephant/vmf.py`) to get a concentration κ and mean direction
μ̂, with Newton's-method estimation, an N<10 "not identifiable" guard, a
κ≤500 saturation cap, and a ρ≤0.999 clamp to avoid `sinh` overflow
(`elephant/vmf.py:60-65`). `elephant/fleetmath.py:293-340` implements OAS
(Oracle Approximating Shrinkage) covariance regularization for a "biomass
anchor." `elephant/probe.py` is a documented incident-response fix: a real
diagnosis (`DIAGNOSIS-2026-08-26.md`, quoted at `probe.py:3-9`) found three
false alarms caused by a banned metric, aliased windowing, and a
narrator-line leaking into the "coldest speaker" signal; the fix — persistent-
drift confirmation (`CONFIRM_PROBES = 2`, `probe.py:62`), time-based NPC-entrance
dedup, and narration-channel exclusion — is implemented and tested.

**Tests.** `pytest -q`: **364 passed, 12 skipped, 0 failed** in 84s. Skips
are accounted for: `torch` not installed here skips `test_contrast.py` and
`test_learned.py`'s torch-only paths, and 10 more skip on missing local
fixture data (`"fleet writings not present on this machine"`,
`tests/test_jepa_rag.py:181` etc.) — this is honest skip-gating, not hidden
failure. The repo's own latest commit message
(`git log -1`, 2026-09-04) independently claims "393/393 tests" with full
deps installed, consistent with our 364+12=376 partial run plus torch-gated
tests.

**Evaluation.** Real, in the sense of internally-consistent statistical
estimation with documented failure-mode fixes (the probe.py postmortem
above is itself a form of evaluation — a false-positive rate was measured,
diagnosed, and driven down with a specific, testable mechanism). There is
no external benchmark against a labeled dataset, but that is a fair scope
for what this repo claims to be (an internal sensing module, not a
leaderboard entry).

**Numeric tolerance / thresholds.** This is the strongest hit in the whole
scan. Direct quotes:
- `elephant/vmf.py:60-65`: `KMAX = 500.0  # κ saturation cap`, `NMIN = 10  # below this many windows, κ is not identifiable`, `RHOMAX = 0.999  # ρ clamp`.
- `elephant/probe.py:62-66`: `CONFIRM_PROBES = 2  # consecutive real edges required to alarm`, `MAX_GAP_MINUTES = 15  # larger inter-probe gap breaks the persistence chain`, `ENTRANCE_DEDUP_S = 15 * 60`.
- `elephant/probe.py:253-290`: `alarm_decision()` returns `{"alarm": False, "alarm_reason": "not_identifiable"}` / `"awaiting_confirmation"` / `"confirmed_persistent_drift"` — a real state machine gating on a jackknife-SE deadband, not a single threshold crossing.

**Honest read:** elephant is small and its README undersells nothing — it
explicitly flags what's a stub (the learned JEPA backbone) versus what's
real math (vMF, OAS shrinkage). The test suite passes clean, and the probe.py
incident writeup is the kind of self-correcting engineering discipline the
task's DISCIPLINE section asks scouts to recognize when present. This is
directly, concretely relevant to exact-band's threshold/tolerance work.

### thought-amplifier

**What it actually does.** A continuous "thinking loop": a small local model
(Ollama, e.g. `granite3.1-dense:2b`) generates a stream of thoughts every N
seconds; a `Supervisor` scores each thought on novelty/specificity/coherence/
engagement (heuristic, not ML — word-overlap and length-bucket scoring,
`core/supervisor.py:72-107`) and adjusts prompt/temperature; a `router/`
subsystem decides per-prompt whether a local model is confident enough or
whether to escalate to a cloud model, via a weighted geometric-mean ensemble
of four signals (`router/confidence.py:12-16`: capability 0.30, history 0.25,
complexity 0.20, novelty 0.25) gated at `LOCAL_CONFIDENCE = 0.40`
(`router/router.py:252`). A `scheduler/` handles fair-use cloud budgeting.

**Tests.** `pytest -q tests/ router/tests/ scheduler/tests/`: **622 passed, 0
failed** in 59s (README's own claim, 551, is stale/undercounted — actual is
higher). CI (`.github/workflows/tests.yml`) runs the identical command on
Python 3.10/3.11/3.12. Sampled assertions are genuinely behavioral
(`tests/test_router_confidence.py:35-38`: `assertLess(c.complexity, 0.5)` for
a trivial prompt, `assertGreater(...)` and `assertTrue(c.has_multi_step)` for
a complex one) — not smoke tests.

**Evaluation.** The strongest of the five. `experiments/final/RESULTS_SUMMARY.md`
documents a controlled experiment (EXP3) with four arms — Baseline,
Conductor-directed, Random, Sham — n=20 generations each, scored 0.0–1.0 by
an external model (Qwen3-14B via DeepInfra) on novelty/specificity/engagement:
```
Conductor vs Random: Δ +0.323, t=+3.25, p=0.001, Cohen's d=+1.03 (***)
Sham vs Baseline (placebo check): Δ -0.075, p=0.294, ns — "Sham arm is valid"
```
with explicit caveats it wrote against itself: *"Scorer is an LLM (Qwen3-
14B), not human raters... n=20 per phase is modest"*
(`experiments/final/RESULTS_SUMMARY.md`, Important Caveats §1-2). A prior
experiment (EXP2) is reported as flawed — binary rubric produced a ceiling
effect ("specificity was pinned at 1.000 with zero variance") — and EXP3 was
redesigned specifically to fix it. `experiments/SELF_REVIEW_FINDINGS.md` is a
devil's-advocate self-audit that scores its own 20 generated critiques for
depth (3/20 "genuinely insightful," 10/20 "surface-level or confused") rather
than accepting them uncritically.

**Numeric tolerance / thresholds.** Direct hit: `router/router.py:252,257`,
`LOCAL_CONFIDENCE = 0.40  # above this → KNOWN-UNKNOWN (local sufficient)`;
`router/router.py:145-146`, a separate `confidence_threshold: float = 0.85`
gate on cached routing entries; and cosine-similarity band thresholds quoted
in the experiment writeup itself: *"Thresholds: Exact (≥0.80), Similar
(0.55-0.80), Novel (<0.55)"* (`experiments/final/RESULTS_SUMMARY.md`, EXP1-R
section).

**Honest read:** small, honest, and the only one of the five with a real
statistical evaluation — control arms, significance tests, effect sizes, and
a documented instance of the team catching and fixing its own measurement
flaw (EXP2→EXP3). Its "quality" heuristics (novelty/coherence scoring) are
themselves unvalidated word-count heuristics, same caveat as elsewhere — but
the repo says so and builds an actual experiment to test whether the
mechanism built on top of them works.

### CognitiveEngine

**What it actually does, per the code (not the README).** `src/core/cognitive-
engine.ts` (108 lines) stands up an Express + WebSocket server with a
`/health` endpoint and a `/api/dream` endpoint that calls:
```ts
// src/core/cognitive-engine.ts:69-84
async dream(input: DreamInput): Promise<DreamResult> {
  const startTime = Date.now();
  // TODO: Implement actual cognitive processing
  const result: DreamResult = {
    insights: [], patterns: [], concepts: [], hypotheses: [],
    metadata: { processingTime: ..., levelsProcessed: 5, patternsFound: 0, insightsGenerated: 0 }
  };
  return result;
}
```
`/api/insights` (`:47-49`) hardcodes `res.json({ insights: [] })`.
`src/levels/levels.ts` is a static array of 5 level names/descriptions with
no processing logic attached. The README's "5-Level Abstraction, Pattern
Recognition, Insight Generation, Knowledge Synthesis, Dream Mode, Memory
Integration" feature list (`README.md:17-23`) has **zero corresponding
implementation** in this repo. `extracted-tools/` — meant to house 15
"production-ready" tools per `FINAL_STATUS.md` ("MISSION 100% COMPLETE",
"6 Production-Ready Python Packages") — contains 4 of 5 subdirectories with
**no code files at all** (only markdown), and the fifth
(`provider-abstraction-layer`, 2,333 Python lines) fails to even collect its
own test suite:
```
tests/conftest.py:15: ModuleNotFoundError: No module named 'models'
...
provider_abstraction_layer/base.py:11: ImportError: attempted relative import with no known parent package
```
`FINAL_STATUS.md` itself references package locations like
`/mnt/c/users/casey/hierarchical-memory/` — a path on the original
developer's machine, not present in this repository at all.

**Tests.** CognitiveEngine core: **0 test files exist** despite
`package.json` declaring `"test": "vitest"`. The one real sub-package's
tests error out on collection (2 errors, 0 tests run).

**Evaluation.** None. There is nothing running to evaluate.

**Numeric tolerance / thresholds.** None found in the active code path (the
stub has none). `tests/test_claude_provider.py:42` (in the one real
sub-package) asserts `model_name == "claude-3-5-haiku-20241022"` — a dated
snapshot from October 2024, ~2 years stale as of this scout (Sept 2026) and
a plausible candidate for having been retired by Anthropic in the interim
(not independently verified against the live API in this pass).

**Honest read:** this is the one clearly weak repo in the set. Its own
process documentation (36 status/summary markdown files, 22 CI workflow
files totaling nearly 5,000 YAML lines) vastly outweighs its ~2.5K lines of
actual code, and the process docs describe a "100% complete," "production-
ready" state that is contradicted by what ships in the repository: a stub
server with a `TODO` where the product is supposed to be, no tests, and a
broken import graph in the one sub-package that has real code. This is not
"could not verify" — it's a directly reproduced gap between claim and
artifact.

### SuperInstance (org root)

**What it actually does.** Not a single system — this is the org's meta-repo:
extensive narrative/architecture documentation (a "boat is a robot" framing
essay running thousands of words, `README.md`), a small Python SDK
(`superinstance/`, ~830 lines: `Agent`, `Fleet`, `AgentCache`, `Memory`
classes that call DeepInfra's OpenAI-compatible endpoint with
`deepseek-ai/DeepSeek-V4-Flash`, `superinstance/agent.py:114-119`), a small
Rust "fleet-metrics" HTTP service (696 lines total across 6 files) exposing
a toy "conservation law" (`γ + η = C`) over synthetic per-agent "energy"
values, and 25 git-submodule references to other org repos (Rust crates with
elaborate mathematical names — `hodge-consensus-rs`, `tropical-geometry-rs`,
`sheaf-coherence-rs`, `symplectic-opt-rs`, `wasserstein-agents-rs`, etc.)
that are **entirely absent from any clone of this repo**, because no
`.gitmodules` file exists to resolve them:
```
$ git ls-tree HEAD | awk '$1=="160000"' | wc -l
25
$ cat .gitmodules
[file does not exist]
```
Those 25 crates could not be assessed at all from this repo — "not present in
this clone," not "verified absent as projects."

**Tests.** The Python SDK's `tests/`: **141 passed, 0 failed**. Small but
real (agent caching, memory recall, semantic search stubs).

**Evaluation.** Mixed, and one concrete red flag. `fleet-metrics/src/lib.rs:67-74`
implements a real pass/fail rule:
```rust
pub fn verify_law(&self) -> bool {
  ...
  delta < 1e-6
}
```
But the checked-in "live" report (`fleet-metrics/reports/conservation_law_fleet_report_live.md:26-28`)
reads:
```
✅ γ + η ≈ C: Valid
Delta: 0.13, within acceptable threshold (1e-6)
```
**0.13 is not less than 1e-6.** Had this report actually been produced by
calling the code above, `verify_law()` would have returned `false` and the
✅ would be a ❌. This is a reproducible, quotable instance of a "live metrics
report" that does not match what the code it describes would actually
output — i.e., the report reads as hand-authored narrative dressed as a live
system capture, not an artifact of running the service.

**Numeric tolerance / thresholds.** `fleet-metrics/src/realtime.rs:230`:
`z_threshold: 2.0` for anomaly detection — small but real and independent of
the inconsistent report above.

**Honest read:** SuperInstance-the-repo is mostly a documentation and
narrative hub for the org, not a product. Its one piece of real,
independently-testable code (the SDK) is small and passes its tests cleanly.
Its one piece of quantitative "evaluation" content (the conservation-law
report) contains an internal contradiction that undermines trusting any of
its other numbers without independent verification. The 25 absent submodule
crates are the most mathematically interesting-sounding part of the org by
name (Hodge, tropical geometry, sheaves, symplectic optimization) and are
completely unverifiable from here — a future scout with time to spare could
usefully clone 2-3 of those by name to check whether they're real or, like
CognitiveEngine's `extracted-tools/`, mostly markdown.

---

## 3. Which of these is genuinely world-class, if any

**thought-amplifier**, with real qualification. Nothing here is "world-
class" in the sense of a competitive SOTA benchmark result — these are all
small, single- or few-developer research repos, not published systems being
compared against a leaderboard. But among the five, thought-amplifier is the
only one that (a) ran a real controlled experiment with a placebo arm and
got a statistically significant, plausible result (Cohen's d=1.03,
Conductor vs Random, p=0.001), (b) caught and openly documented its own
earlier experiment's methodological flaw (EXP2's ceiling effect) and fixed
it rather than hiding it, (c) has 622 passing tests with CI enforcing them
on every push across three Python versions, and (d) states its own scope
limits without prompting ("Not an agent framework... Not a RAG system...
Not a fine-tuned model," `README.md:15`). That combination — real
evaluation, honest caveats, passing CI — is the standard the task asks a
scout to hold an AI/ML repo to, and thought-amplifier is the only one of
the five that clears it end to end.

**elephant** is a close second and arguably more mathematically substantial
per line (real vMF MLE, real OAS shrinkage, a documented false-alarm
postmortem with a concrete fix) — it just doesn't have thought-amplifier's
controlled-experiment layer on top. If the bar is "rigorous, self-aware,
numerically careful code that does what it says," elephant matches or beats
thought-amplifier; if the bar includes "ran an actual evaluation with a
comparison against a baseline," thought-amplifier is ahead.

**polln** has the most total engineering (the deadband/confidence-cascade
math is real and non-trivial) but its evaluation layer is synthetic
end-to-end and 85% of its test suite doesn't compile — it cannot currently
back up its own scale with working proof.

**CognitiveEngine** and the bulk of **SuperInstance**'s root repo are the
opposite of world-class: process documentation substantially exceeds
working code, and in both cases a specific, quotable artifact (the `TODO`-
stubbed `dream()` method; the conservation-law report whose own numbers
fail its own threshold check) contradicts the project's self-description.

## 4. Where numeric tolerance appears

Sites found, in order of relevance to exact-band's problem shape (agreement
between components / confidence thresholds / hysteresis bands):

1. **elephant** — `elephant/vmf.py:60-65` (κ saturation cap 500, N<10
   identifiability guard, ρ≤0.999 clamp against `sinh` overflow) and
   `elephant/probe.py:62-66,253-290` (2-consecutive-edge confirmation gate,
   15-minute max inter-probe gap, jackknife-SE deadband) — the most directly
   relevant code in the whole scan: a real system that alarmed falsely,
   was diagnosed, and was fixed with an explicit persistence/confirmation
   threshold rather than a single crossing.
2. **thought-amplifier** — `router/router.py:145-146,252,257`
   (`LOCAL_CONFIDENCE = 0.40`, separate `confidence_threshold: float = 0.85`
   for cache-entry pruning) and the cosine-similarity bands quoted in
   `experiments/final/RESULTS_SUMMARY.md` (Exact ≥0.80, Similar 0.55–0.80,
   Novel <0.55) — a weighted geometric-mean ensemble gating a real
   local-vs-cloud routing decision, tested with `assertGreater`/`assertLess`
   style assertions in `tests/test_router_confidence.py`.
3. **polln** — `src/spreadsheet/core/RateBasedChangeSystem.ts:47-60,487-550`
   (fixed/statistical/adaptive deadbands, k-sigma bounds, minimum-width
   floor) and `repos/confidence-cascade/src/confidence-cascade.ts:37-40`
   (green ≥0.85 / yellow ≥0.60 zone thresholds) — real and on-topic, but
   currently **broken in its own test suite** (`RateBasedChangeSystem.ts:523`
   fails to compile under strict null checks; the confidence-cascade test
   file calls a now-private method). Anyone reusing this code should expect
   to have to fix it first.
4. **SuperInstance** — `fleet-metrics/src/lib.rs:67-74` (`delta < 1e-6` law
   check) and `fleet-metrics/src/realtime.rs:230` (`z_threshold: 2.0`) are
   real but small, and the one example "live" output of this exact
   threshold check (`conservation_law_fleet_report_live.md:26-28`) is
   internally inconsistent with the code (see §2 above) — worth treating
   any narrative "report" in this org's repos as unverified until checked
   against the code that supposedly produced it.
5. **CognitiveEngine** — **none**. No thresholds, no tolerance bands, no
   scoring cutoffs exist in the active code path; there is nothing to
   compare against exact-band.

**Bottom line for exact-band relevance:** elephant and thought-amplifier are
where actual, working, tested threshold/tolerance logic lives and would
likely benefit from or inform exact-band-style work. polln has the largest
volume of directly-on-topic code (deadbands, confidence zones) but it is
presently uncompilable in its test suite — usable as a design reference, not
as a dependency, without a fix pass first.
