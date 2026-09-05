# docs/INDEX — the map

Every Markdown file in the repo, one line each, grouped by what you're
trying to do. Generated 2026-08-29 (iteration 1, documentation front
door); re-audited 2026-08-30 (lane A: README rewrite + archived copy
wired in). Source of truth for the file list: `find . -name '*.md' -not
-path './obj_dir/*'`. One file can belong to several lanes; each is
listed under its primary intent.

The README is the front door; this index is the hallway. (`docs/INDEX.md` — this file, the map itself.)

---

## Suggested reading order (the intended path, not the alphabetical one)

A newcomer reading this index top-to-bottom gets a different quilt than
the one the repo's history built. The intended path:

1. **[README.md](../README.md)** — the front door: the 5+1 opcode model, quickstart that was actually run, measured numbers, honest limitations.
2. **[docs/THE-TICK.md](THE-TICK.md)** — one tick traced through the RTL, numbers left to right. If you read only one doc after the README, read this one.
3. **[docs/FOUNDATION.md](FOUNDATION.md)** — the cell axioms the tick walk rests on.
4. **[docs/QUF-SPEC.md](QUF-SPEC.md)** — how quilt state becomes a file that boots.
5. **[docs/VERIFICATION.md](VERIFICATION.md)** — how claims above are proven; then `docs/academic/THE-BREAKDOWN.md` for the dossier (gaps and failures first-class). For the number-by-number depth: `docs/FORMAL-PROOFS.md` (the six proofs) and `docs/SYNTHESIS-RESULTS.md` (the measured tables).
6. **[docs/BACKEND-NOTES.md](BACKEND-NOTES.md)** — what an adversarial first user found; the honest weakness list.

Then branch by appetite: theory → the `docs/academic/` spine
(quilt-calculus → GENERAL-CALCULUS → error-envelopes); applications →
SEMANTIC-TOWER → BACK-DECK-APP → TAP-FABRIC; metal → SYNTHESIS →
SYNTHESIS-FPGA → FPGA-BOOT → CHIP-MATRIX. The Understand table below is
the full shelf; this is the tour.

---

## Understand — what this is, why it exists, and the ideas

| file | one line |
|---|---|
| [README.md](../README.md) | The front door: what this is, the 5+1 opcode model, verified-results table, quickstart with real output, limitations, docs map. |
| [docs/THE-TICK.md](THE-TICK.md) | One tick traced through the RTL: strobe → decay sweep → leak → fire-test → fanout, numbers left to right. |
| [docs/DOCTRINE.md](DOCTRINE.md) | The bet: llama.cpp, but Verilog and cellularized — one repo, zero deps, quantized by default, weights are a file. |
| [docs/FOUNDATION.md](FOUNDATION.md) | The mathematics of the quilt from the beginning: cell axioms D1–D5 and what they buy. |
| [docs/ABSTRACTION-MATH.md](ABSTRACTION-MATH.md) | Hardware abstraction mathematics: dyadic staircases, traced monoidal wiring, the graded interface. |
| [docs/LINEAGE.md](LINEAGE.md) | The pre-computer inheritance: PLATO/TUTOR, RPG/COBOL, FORTRAN vectorization, the hardware/software split. |
| [docs/SEMANTIC-TOWER.md](SEMANTIC-TOWER.md) | The agentic compiler: natural-language cells → substrate binaries, level by level. |
| [docs/CULTURE-DEEP-DIVE.md](CULTURE-DEEP-DIVE.md) | What computing's cultures teach the semantic-tower compiler (the informal twin of FOUNDATION). |
| [docs/QUF-SPEC.md](QUF-SPEC.md) | QUF, v1 — the GGUF of cellular silicon: the flat binary container for full quilt state. |
| [docs/QUANT-RESEARCH.md](QUANT-RESEARCH.md) | Quantization lane: which GGML/PTQ schemes are pure-RTL-friendly (fixed-point, streaming). |
| [docs/CHIP-MATRIX.md](CHIP-MATRIX.md) | Every chip on the desk measured as a cell: the 5-model ladder, GPU vs CPU, the boat doctrine. |
| [docs/BACK-DECK-APP.md](BACK-DECK-APP.md) | The worked application: the back-deck pipeline as a QUF-warmable cell graph (companion to SYNTHESIS/QUF-SPEC). |
| [docs/TAP-FABRIC.md](TAP-FABRIC.md) | The Tap's bar run as a quilt cell graph: MudArena session logs replayed through cell-exact semantics. |
| [docs/TAP-OPENMIC.md](TAP-OPENMIC.md) | The night the models took the stage: the open-mic poetry night, all eight voices, run for real. |
| [docs/V2-NOTES.md](V2-NOTES.md) | The judge's must-ship pair as built: the echo gate (call–response credit) and the RQH bank. |
| [docs/CUTTING-EDGE-rtl.md](CUTTING-EDGE-rtl.md) | Research sweep: LLM-era RTL generation & open HDL verification (2024–2026), the verification bar. |
| [docs/academic/quilt-calculus.md](academic/quilt-calculus.md) | The formal monograph: the cell, its ledger, and its algebras (the academic lane's spine). |
| [docs/academic/GENERAL-CALCULUS.md](academic/GENERAL-CALCULUS.md) | The capstone: the theory beneath the six verbs — abstract cells, quilt-shape axioms, generalization axes, composition, compiler correspondence. |
| [docs/academic/error-envelopes.md](academic/error-envelopes.md) | Every numeric claim on the board, stated, proved, and graded. |
| [docs/academic/ELEGANCE.md](academic/ELEGANCE.md) | The five heaviest equations, reduced. |
| [docs/academic/BRIDGES.md](academic/BRIDGES.md) | The leaps fixed with real derivations — the cross-document dependency spine. |
| [docs/academic/DEPENDENCY-GRAPH.md](academic/DEPENDENCY-GRAPH.md) | The concept lattice fully linked: every claim's dependency inventory, mermaid subgraphs, gaps. |
| [docs/academic/conjectures.md](academic/conjectures.md) | The three open problems, attacked: C1 dichotomy, C2 drift band, C3 fold characterization — with the counterexamples that closed the restricted forms. |
| [docs/academic/RHO-F-FLOOR.md](academic/RHO-F-FLOOR.md) | The audit-freshness impossibility floor: controllability caps, committee schedules, the re-anchoring test. |
| [docs/academic/DRIFT-AS-PREFILTER.md](academic/DRIFT-AS-PREFILTER.md) | Composition theory of judgment under drift: additive tolerance, re-judging cost, the labeled-perturbation problem. |
| [docs/academic/FOLD-COVERED.md](academic/FOLD-COVERED.md) | Losslessness theory of ledger compaction: characterization, exclusion impossibility, witness recovery, checkpoint pricing. |
| [docs/academic/zero-claw-update.md](academic/zero-claw-update.md) | The dissertation reads the calculus, and is read by it — thesis v2 in the calculus' terms. |
| [docs/academic/annals-1905/07-INDEX.md](academic/annals-1905/07-INDEX.md) | The annals' own colophon, index, and confessions — what the series is and how it was iterated. |

## Verify — run it, check a claim, reproduce a result

| file | one line |
|---|---|
| [docs/VERIFICATION.md](VERIFICATION.md) | The complete verification guide: every lane's command, expected pass counts, measured timings, and the honest not-covered list. |
| [docs/FORMAL-PROOFS.md](FORMAL-PROOFS.md) | The depth pass on the six sby proofs: invariant in plain math, what it rules out, engine/strategy, measured wall times, and the E1–E4 assumption ledger. |
| [docs/SYNTHESIS-RESULTS.md](SYNTHESIS-RESULTS.md) | The consolidated measured synthesis table: devices, LCs, IO, fmax vs target, bitstream size — every row dated and provenance-tracked (incl. the post-place-vs-route corrections). |
| [formal/README.md](../formal/README.md) | The proof suite's contract: every .sby, its invariant, verdict, runtime, environment assumptions (E1–E4), and the RTL defects the proofs forced. |
| [sim/README.md](../sim/README.md) | The behavioral lane: Python prototypes over the same QUF, tap-fabric bridge, and how to run it. |
| [tools/gc-verifies/README.md](../tools/gc-verifies/README.md) | GC-METAL lane: the five GENERAL-CALCULUS §8 benches, their check counts and bounds, and the regression guard. |
| [tb/scratch/COMPILE-RESULTS.md](../tb/scratch/COMPILE-RESULTS.md) | Round-1 skeleton compile & lint tally: 17/24 iverilog-clean across the proposals, per-entry failure table. |
| [docs/SCORECARD.md](SCORECARD.md) | Round-2 scorecard: cross-review + verification harness verdict on the five competition entries. |
| [docs/academic/DENY-BY-RUNNING.md](academic/DENY-BY-RUNNING.md) | The evidence-grade method: reproducibility as burden of proof, the dossier schema, what a skeptic must do. |
| [docs/academic/THE-BREAKDOWN.md](academic/THE-BREAKDOWN.md) | The adversarial dossier: every load-bearing claim as CLAIM → DEFINITIONS → PROOF → MACHINE CHECK → ATTACK SURFACE → CLOSURE, with the exact reproduce commands. |
| [docs/academic/RETURN.md](academic/RETURN.md) | The metal leg's return cargo: what verification taught the mathematics (the round trip's changed-things ledger). |
| [docs/review-claude.md](review-claude.md) | Cross-review of the claude entry (ARCHITECTURE + RTL-SKETCH). |
| [docs/UNSLOTH-CROSS-EXAM.md](UNSLOTH-CROSS-EXAM.md) | External Unsloth-doctrines pitch, cross-examined: verdict table (already-have / violates-covenant / worth-measuring), confabulations named, tick-leak truncation drift measured over 2×100k ticks. |
| [docs/review-glm.md](review-glm.md) | Cross-review of the glm entry — The Chain-Quilt: cells, ladders, one shared math tail. |
| [docs/review-opencode.md](review-opencode.md) | Cross-review of the opencode entry — LOOM/1. |
| [docs/review-seed.md](review-seed.md) | Cross-review of the seed entry. |
| [docs/review-zeroclaw.md](review-zeroclaw.md) | Cross-review of the zeroclaw entry — The Field-Edge, in Fixed Points (no RTL-SKETCH shipped). |

## Build — make it real: RTL, synthesis, the competition

| file | one line |
|---|---|
| [docs/SYNTHESIS.md](SYNTHESIS.md) | The v1 synthesis lane: round-2 scorecard binding, curveballs, socratic expansion, and the mechanism set that won. |
| [docs/SYNTHESIS-FPGA.md](SYNTHESIS-FPGA.md) | The metal proof: iCE40 wall (96% LC, 27.72 MHz), PIPE_EFF retime (40.44 MHz), ECP5 device ladder, bitstream-ready. |
| [docs/FPGA-BOOT.md](FPGA-BOOT.md) | Boot design: QUF file → cell state at reset (the harness spec; the RTL lives in rtl/). |
| [docs/INNOVATION-JUDGEMENT.md](INNOVATION-JUDGEMENT.md) | The innovation prize ballot: judge's verdict across the five innovation entries. |
| [rtl/RESEARCH-NOTES-zeroclaw.md](../rtl/RESEARCH-NOTES-zeroclaw.md) | ZeroClaw's first RTL sketches — comment-form interfaces only, not yet compiled. |
| [proposals/claude/ARCHITECTURE.md](../proposals/claude/ARCHITECTURE.md) | Competition entry: Bottom-Layer Quilt Architecture. |
| [proposals/claude/RTL-SKETCH.md](../proposals/claude/RTL-SKETCH.md) | The entry's synthesizable module skeletons (3 modules, Q15 fixed-point). |
| [proposals/glm/ARCHITECTURE.md](../proposals/glm/ARCHITECTURE.md) | Competition entry: The Chain-Quilt — cells, ladders, one shared math tail. |
| [proposals/glm/RTL-SKETCH.md](../proposals/glm/RTL-SKETCH.md) | The entry's six module skeletons (ports + key always blocks). |
| [proposals/opencode/ARCHITECTURE.md](../proposals/opencode/ARCHITECTURE.md) | Competition entry: LOOM/1 — every node is one generic cell. |
| [proposals/opencode/RTL-SKETCH.md](../proposals/opencode/RTL-SKETCH.md) | The entry's nine synthesizable skeletons. |
| [proposals/seed/ARCHITECTURE.md](../proposals/seed/ARCHITECTURE.md) | Competition entry: Seed-2.0-pro's bottom-layer architecture. |
| [proposals/seed/RTL-SKETCH.md](../proposals/seed/RTL-SKETCH.md) | The entry's two synthesizable skeletons. |
| [proposals/zeroclaw/ARCHITECTURE.md](../proposals/zeroclaw/ARCHITECTURE.md) | Competition entry: ZeroClaw — The Field-Edge, in Fixed Points. |
| [proposals/hermes/ADVOCACY.md](../proposals/hermes/ADVOCACY.md) | The devil's advocate lane: the seat that argues the losing side of each design decision. |
| [proposals/jester/CURVEBALLS.md](../proposals/jester/CURVEBALLS.md) | The court jester's 14 challenge proposals — the questions nobody else thought to ask. |
| [proposals/socratic/EXPANSION.md](../proposals/socratic/EXPANSION.md) | The socratic expansion: The Preferring Fabric (round 2.5, post-cross-review). |
| [proposals/innovations/claude.md](../proposals/innovations/claude.md) | Innovation entry: Temporal Contrast Hebb (TCH). |
| [proposals/innovations/flash.md](../proposals/innovations/flash.md) | Innovation entry: Residual-Quantum Hebb (RQH) — the winner's seed (see docs/V2-NOTES.md). |
| [proposals/innovations/opencode.md](../proposals/innovations/opencode.md) | Innovation entry: The Echo Gate — call–response credit for Hebbian edges. |
| [proposals/innovations/seed.md](../proposals/innovations/seed.md) | Innovation entry: Dynamic Weight Scaling Hebb (DWS). |
| [proposals/innovations/seedmini.md](../proposals/innovations/seedmini.md) | Wild-card innovation entry: Context-Tagged Hebbian Learning (CTHL). |

## History — how we got here, and the records of getting here

| file | one line |
|---|---|
| [docs/WORLD-CLASS-BRIEF.md](WORLD-CLASS-BRIEF.md) | The standard: what "world class" means for this repo, the known gaps, the iterator protocol (AUDIT → FIX → MEASURE → COMMIT). |
| [README.archived-20260830.md](../README.archived-20260830.md) | The 2026-08-29-era README, retired intact by the 2026-08-30 lane-A rewrite (kept — archive by rename). |
| [docs/BACKEND-NOTES.md](BACKEND-NOTES.md) | The adversarial first user's report: 23 bug classes found and fixed, 5 in RTL, with regression counts. |
| [docs/academic/annals-1905/00-EDITORS-PREFACE.md](academic/annals-1905/00-EDITORS-PREFACE.md) | The editor's preface to the Kaldfjord Circle annals (1903–1905). |
| [docs/academic/annals-1905/01-the-tally-box.md](academic/annals-1905/01-the-tally-box.md) | Memoir I: on the tally-box and its six verbs. |
| [docs/academic/annals-1905/02-the-balance-of-the-books.md](academic/annals-1905/02-the-balance-of-the-books.md) | Memoir II: the balance of the books. |
| [docs/academic/annals-1905/03-the-parallax-memoirs.md](academic/annals-1905/03-the-parallax-memoirs.md) | Memoir III: the parallax of bearings and of judgments. |
| [docs/academic/annals-1905/04-the-bell-rope.md](academic/annals-1905/04-the-bell-rope.md) | Memoir IV: the bell-rope. |
| [docs/academic/annals-1905/05-the-ledger-papers.md](academic/annals-1905/05-the-ledger-papers.md) | Memoir V: the ledger papers. |
| [docs/academic/annals-1905/06-CORRESPONDENCE.md](academic/annals-1905/06-CORRESPONDENCE.md) | The letters of the Circle, 1903–1905. |
| [docs/academic/annals-1905/08-THE-SECOND-GENERATION.md](academic/annals-1905/08-THE-SECOND-GENERATION.md) | The 1923 offprint: the second generation, on the reading of readings. |
| [docs/academic/annals-1905/drafts/01-the-tally-box.draft.md](academic/annals-1905/drafts/01-the-tally-box.draft.md) | Draft of memoir I (kept — the annals archive by rename). |
| [docs/academic/annals-1905/drafts/02-THE-SLIP.md](academic/annals-1905/drafts/02-THE-SLIP.md) | The slip pasted into every copy of memoir II. |
| [docs/academic/annals-1905/drafts/02-the-balance-of-the-books.draft.md](academic/annals-1905/drafts/02-the-balance-of-the-books.draft.md) | Draft of memoir II (kept). |
| [docs/academic/annals-1905/drafts/03-the-parallax-memoirs.draft.md](academic/annals-1905/drafts/03-the-parallax-memoirs.draft.md) | Draft of memoir III (kept). |
| [docs/academic/annals-1905/drafts/04-the-bell-rope.draft.md](academic/annals-1905/drafts/04-the-bell-rope.draft.md) | Draft of memoir IV (kept). |
| [docs/academic/annals-1905/drafts/05-the-ledger-papers.draft.md](academic/annals-1905/drafts/05-the-ledger-papers.draft.md) | Draft of memoir V (kept). |

---

## Lanes not yet documented here

`docs/` files whose lane tags name a companion that does not exist in
this index (written elsewhere or never shipped): `EDGE-BENCH.md`
(cited by CHIP-MATRIX.md; the night lane shares its scorer with
`tools/edgebench/`) and `ai-writings` (outside this repo). If you are
looking for either, the CHIP-MATRIX and TAP-OPENMIC docs are the local
entries.

## Maintenance

- Keep this list complete: after adding or renaming any `.md`, regenerate
  with `find . -name '*.md' -not -path './obj_dir/*'` and diff against
  the files above.
- One line per file, primary intent only; cross-links live in the docs
  themselves (BRIDGES.md / DEPENDENCY-GRAPH.md are the formal spines).
- Drafts and records are kept, never deleted — archive by rename.
