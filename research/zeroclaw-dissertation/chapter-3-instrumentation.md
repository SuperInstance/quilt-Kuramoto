# Chapter 3 — Instrumentation: The Edge Log

*Dissertation draft, ZeroClaw. Grounded in SuperInstance/elephant commit `d1d0bf1` ("vmf: honest (μ̂, κ) MLE + instrumented tap edge log (gate 1)"), verified by the advisor's re-run: 16/16 new tests green, 267 passed total, zero regressions.*

## 3.1 The design principle

**Log append-only facts at ingest; log cheap fits inline; derive everything else post-hoc.** The log must be replayable into the exact session state — order, fields, fits — without the session object. Anything analytical (deadband flags, rank curves, cross-night joins, retrieval) is computed later from the JSONL, so the log never bakes in a conclusion.

## 3.2 What shipped

Three touchpoints on the existing `TapNightSession`, additive and no-op unless `log_path` is set:

1. **`session_open`** — session/space ids, clock mode, the *reader* (`{kind, identity, bank fingerprint}`), estimator params (W, standardization, estimator version, κ_max), and the full roster including each participant's `vibe_start`. Without `vibe_start`, acclimation is unfittable later — it is per-session irreducible.
2. **`speak`** (per message — the edge log's heart): `seq` (order of arrival, robust because `Room` ts-sorts stably and the auto-clock is strictly increasing), `ts`, `author`, `text_sha256`, reactions, `first_by_author` (the entry marker, checked *before* the interaction counter increments), `presence_mask` (authors with ≥1 message in the trailing W=8 — occupancy *now*, not a roll-call feature), `field_raw_after` (the 7-vector `speak()` always computed and previously discarded — the entire capture is a rescue of dead data), `interactions_after`, and the inline vMF fit with its CI and `axis_spread`. The derived `edge` rides along with `real: null` until the dial-space noise floor is calibrated.
3. **`session_close`** — final readings, final (μ̂, κ) fit, cycle, notes.

The estimator module (`elephant/vmf.py`) is Chapter 2 made executable, including the banned-proxy guard: a test asserts vmf.py never imports or calls v0 `concentration()` — the doctrine is enforced by the suite, not by memory.

## 3.3 Honest deviations and their documentation

The implementation recorded what reality did to the plan: `data/roomd-field-log.jsonl` turned out to be the roomd contrast corpus, not a tapnight log, so the fixture was generated from tapnight itself; a circular-import dodge required a lockstep guard test; one pre-existing flake (`test_ring_rearms_on_fall`, a millisecond filename collision in untouched code, ~1-in-15) was left out of scope. None of these touch the claim; all are documented in the commit.

## 3.4 Why the log is the thesis's spine

The fleet's own cross-pollination map names the gap this log closes: **G0, the missing hippocampus** — no repo logs order-of-arrival or event-time, so charisma (room→agent) vs acclimation (agent→room) "stays poetry." The edge log is the first fleet artifact where "who pulled whom" is a replayable fact rather than a metaphor. And it is the exact feed for the JEPA-RAG minimal edge extension (moment_id, field_before/after, step matrix, `query_edge`): the schema change is trivial; the empirical bet — Chapter 4's business — is the only thing that was ever expensive.

## 3.5 The experiment protocol this instrument exists for

- **Nights A–C:** same cast, fixed speaking order. Between-night edges of the same room measure the **dial-space noise floor** — the number everything downstream depends on. (The encoder-side floor, 0.05, was never the right denominator for dial-space edges.)
- **Night D:** identical, plus one designated newcomer with a defined persona entering at seq≈60%. Occupants' μ̂ shifting toward the newcomer = **charisma**; newcomer's rank rising while occupants hold = **acclimation**. This is the only clean separator of the two, and it costs one extra participant. Designed in, not hoped for.
- **Coarse anchor:** a ~0.271 cross-room contrast check proves the harness is not dead — a control that can fail, not a ritual that cannot.

## 3.6 What this chapter claims

The instrument exists, runs, reproduces, and is guarded by tests (κ recovery on exact vMF samples within tolerance; scipy spot-check <1e-9; the banned proxy excluded by assertion). It claims nothing about what the instrument will *measure* — whether within-room edges clear the floor is the deadman switch's question, pre-registered in Chapter 0, tested in Chapter 4.
