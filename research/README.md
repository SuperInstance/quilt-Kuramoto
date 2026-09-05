# Research

Three separate research efforts, none of them core Quilt implementation.

## `quantum-bridge/` — Quilt vs. quantum advantage

The most recently active work in the archive (dated 2026-09-05) and the reason
this repo is named "Kuramoto". Twenty numbered documents arguing that Quilt does
**not** do quantum computation but reaches the same *epistemic regime* — verifiable
outputs, forward-and-backward cross-checking, bounded by impossibility results —
through classical mathematics.

Read `10_EXECUTIVE_SUMMARY.md` first, then `13_RED_TEAM_BRIEF.md`.

What makes it worth keeping is that it argues against itself and loses in public:

- `13_RED_TEAM_BRIEF.md` states *"ZERO measured scaling laws … every claim is an
  assertion, not a result. The red team wins on this point."*
- `16_BENCHMARK_RESULTS.md` runs the benchmark and reports the headline
  hypothesis **failing**: measured scaling exponent α ≈ 0.1-0.2, "closer to linear
  than polylog". It keeps a smaller real finding (~2× at high coupling).
- `17_H4_RESULTS.md` reports the strongest number in the set (11.8× faster
  convergence for simulation-first agents) — from a **simulation**, not hardware.

Backing data is in `results/benchmarks/`. Kuramoto appears once, in
`18_FOUNDATIONAL_MATH_TO_APPLICATION.md`, as one of ten stated analogies.

## `zeroclaw-dissertation/` — a different project entirely

An LLM agent's dissertation modelling conversational "room emotional fields" via
von Mises-Fisher statistics over a 7-dial ensemble. It borrows Quilt's
conservation-law and ledger vocabulary as analogy but is not a Quilt
implementation. Unfinished: `THESIS-V3.md` supersedes the chapters and leaves core
theorem obligations open.

## `spline-thread/`

Spline interpolation as physical beam mechanics, and distance-weighted cascade
routing. Note this "phase coupling" is cubic-spline/optics phase, unrelated to the
oscillator phase of the Kuramoto analogy.
