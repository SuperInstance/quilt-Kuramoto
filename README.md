# quilt-Kuramoto — a salvaged archive of the Quilt project

This repository is **an archive, not a working codebase.** It holds ~610 files
harvested from roughly forty separate repositories in the
[`SuperInstance`](https://github.com/SuperInstance) GitHub organization, plus
several research write-ups about them. The files arrived as one flat dump split
into eight arbitrary upload batches (`set-1` … `set-8`) with their directory
structure flattened into filenames (`docs_MATHEMATICS.md` was `docs/MATHEMATICS.md`).

They have been sorted back into the shape of their original repositories, using
provenance headers in the source files as evidence. **No file content was
modified.** 128 files were deleted: failed downloads and exact duplicates, all
itemised in [`docs/REMOVED.md`](docs/REMOVED.md).

> ## ⚠️ Read `docs/UPSTREAM-DELTA.md` before using any code here
>
> Every source unit under `code/` has been diffed against its live repo in the
> `SuperInstance` org. **Every file is byte-identical to upstream, and every
> upstream repo is substantially larger.** The `quilt-verilog` harvest is 9% of
> the real repository (96 files of 1018) — missing its testbenches, most of its
> formal proofs, and its 353-file adversarial review.
>
> **Use the upstream repos.** This tree is a provenance snapshot of one harvest,
> not a source of truth, and nothing here should be forked into a new repo.

## Read this first: there is no single "Quilt"

At least five distinct technical artifacts in here use the name "Quilt" and the
same five-opcode slogan — **BIND / LINK / EFFECT / VIEW / TICK** — but they have
*different formal definitions of a "cell"* and do not share code:

| Artifact | A "cell" is | Status |
|---|---|---|
| `code/quilt-verilog` | a hardware register file: activation, Hebbian edge weights, threshold, refractory counter | **Real. Synthesised, measured, partly formally proven.** |
| `code/quilt-substrate-meta` | an algebraic triple `(name, value, state-morphism)` forming an inversive monoid | Complete, self-contained C99 library |
| `code/quilt-vm-c` | a "Thing" struct in a small C VM | Complete; vendored into the ESP32 firmware |
| `code/quilt-cuda` | a GPU allocation, with LINK as a CUDA-graph edge | **Written, never compiled** (author's own note) |
| `code/quilt-foundation` | a name→value binding in a ~200-line Python VM | Origin story; produced by LLM brainstorming |

A sixth sense of the word — a reactive *spreadsheet* engine with eight cell kinds
— appears in `repo-readmes/` (quilt-rust, quilt-cloudflare, quilt-live) and uses
a different vocabulary entirely (`get/set/call/push/subscribe`).

Documents even disagree on the optional sixth opcode: `CALL` in some, `FORGET` in
others. Treat any synthesis document as describing **one lineage's view**.

### About the name

Nothing here implements a Kuramoto oscillator model. "Kuramoto" appears in
exactly one place — `research/quantum-bridge/18_FOUNDATIONAL_MATH_TO_APPLICATION.md`
— where coupled-oscillator synchronisation is offered as *one of ten analogies*
for the `t-minus` multi-agent timing protocol. It is a stated analogy, not an
implementation.

## Where the substance is

Ranked by how much is actually built and measured, not by how much was written
about it.

1. **`code/quilt-verilog`** — a cellular Hebbian-learning fabric in pure
   Verilog-2005. This is the most real thing in the archive: 21 RTL modules, four
   SymbiYosys formal-proof harnesses, and genuine synthesis output with **honest
   negative results** (`synth/silicon.tsv` records a UP5K place-and-route failure;
   `synth/scale.tsv` records `PNR_FAIL` at NCELL≥12; `wall_hx8k_util.txt` shows
   the full fabric needs 162% of the largest iCE40).
2. **`code/quilt-esp32`** — PlatformIO firmware with five independent "limb"
   lanes, each with a desktop host-test harness. Reports 100% desktop-vs-board
   agreement (`results/reflex-arc/findings.json`, 480/480 readings).
3. **`code/nmea-quilt-cell`** — a small, genuinely tested Python package: an NMEA
   0183 marine-sensor gateway writing to an append-only journal, with a
   byte-exact replay test and a SIGKILL crash-canary test. The most conventionally
   solid engineering here.
4. **`code/scrap-quilt`** — a Cloudflare Workers game backend (Durable Objects +
   D1). Coherent and complete as a single app.
5. **`research/quantum-bridge`** — an argument that Quilt reaches quantum
   computing's "verifiable advantage" regime by classical means. Notable because
   it red-teams itself and **reports its own headline hypothesis failing**
   (`16_BENCHMARK_RESULTS.md`).

## Layout

```
code/            source, re-nested into original repo layout (rtl/, src/, formal/…)
docs/            PROVENANCE, INVENTORY, MISSING, REMOVED — how this was reconstructed
results/         measured data: FPGA synthesis, formal verdicts, benchmarks, reflex-arc
research/        quantum-bridge report, ZeroClaw dissertation, spline thread
repo-readmes/    READMEs of ~30 upstream repos whose code is NOT in this dump
writing/         the AI-Writings corpus: papers, essays, manifestos, fiction
archive/         scraped GitHub pages and API responses; low value, kept for reference
```

## Caveats worth knowing before citing anything

- **`repo-readmes/` is documentation without code.** Those thirty repos are
  described here, not included. A README is a claim, not an implementation.
- **The writing corpus is largely machine-generated and says so.** `paper-127.md`
  carries the header *"Generated by the Quilt casting-call plugin … Model: PHI-4,
  Cost: $0.0004"*. Only 34 of the 100 numbered papers have full text; the other
  66 are title stubs in `writing/papers/titles-only/`.
- **Formal-verification claims need care.** Docs headline "6/6 PASS", but the one
  raw machine-generated artifact committed here
  (`code/quilt-verilog/formal/AUDIT-SNAPSHOT.json`) records **4 PASS, 3 INCOMPLETE,
  2 UNKNOWN**. See [`docs/MISSING.md`](docs/MISSING.md).
- **Nothing here builds as-is.** Testbenches, several formal harnesses, and the
  build directory structure were never uploaded. This archive is for reading.
