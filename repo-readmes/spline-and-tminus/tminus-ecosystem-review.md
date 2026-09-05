# T-Minus Ecosystem Review

> **Heavy architectural documentation of the SuperInstance T-Minus ecosystem**, prepared to inform the design of `swarm-tminus` (a Python tool that gives `swarm-anchor` the tminus capabilities).

> Synthesizer: MiniMax-M3 (lead agent)
> Date: 2026-07-15
> Method: parallel subagent deep-dives on each tminus repo, then synthesis

---

## What this repo is

Six tminus / T-Minus / tick-engine repos sit in the SuperInstance org, each contributing a piece of the "time-shaped coordination" puzzle. Before building the Python umbrella tool, we sent 6 parallel subagents to document each repo thoroughly, then synthesized their findings into a single design surface.

This repo preserves that work so the next agent has full context without re-deriving the design.

## Index

| File | Source repo | Words | Status |
|------|-------------|-------|--------|
| `BRIEF.md` | (the brief) | — | Shared review template |
| `SYNTHESIS.md` | (synthesis from lead) | — | Aggregates findings into design surface |
| `t-minus-DOCS.md` | `SuperInstance/t-minus` | ~495 lines | Landed (subagent doc) |
| `t-minus-rs-DOCS.md` | `SuperInstance/t-minus-rs` | ~436 lines | Landed (subagent doc) |
| `terax-fleet-modules-DOCS.md` | `SuperInstance/terax-fleet-modules` | ~399 lines | Landed (subagent doc) |
| `tminus-music-DOCS.md` | `SuperInstance/tminus-music` | ~265 lines | Landed (lead agent — 2026-07-16) |
| `lau-tminus-DOCS.md` | `SuperInstance/lau-tminus` | ~296 lines | Landed (lead agent — 2026-07-16) |
| `tick-engine-DOCS.md` | `SuperInstance/tick-engine` | ~279 lines | Landed (lead agent — 2026-07-16) |

The three subagents that originally failed were re-run after the swarm-tminus v0.2.0 audit. Rather than dispatch subagents again, the lead agent read each single-file Rust module directly (tminus-music: 352 lines, lau-tminus: 1033 lines, tick-engine: 274 lines) and wrote the docs in main session. Each file follows the same template as the original subagent docs: §0 repo at a glance, §1 purpose, §2 public API, §3 strengths/weaknesses, §4 swarm-anchor synergy, §5 cross-references, §6 reading order.

## The unifying pattern (from SYNTHESIS.md)

```
1. Declare the FUTURE (countdown event, predicted beat, deadline)
2. Subscribe agents confirm readiness → quorum fires
3. Time elapses via a SHARED CLOCK
4. Predictions match → precompiled script EXECUTES
5. Predictions miss → script is discarded, agent re-plans
```

This is the **predict-and-confirm** paradigm: subscribe once, get notified once. ~10× fewer messages than polling.

## Per-repo contributions (summary)

### t-minus (the core)
- CountdownEvent with quorum firing (confirmed / deferred / missed)
- DAG-ordered campaigns via Kahn's topological sort
- Subscriber state machine per participant

### t-minus-rs (the timer engine)
- Cron expression parsing (no external deps)
- Hierarchical deadline trees with cascade-cancel
- Dual rate limiters (token bucket + leaky bucket)
- TempoMap / EnsembleTempo for multi-agent tempo negotiation
- Backpressure-aware limiting

### tminus-music (single-file Rust, ~340 LOC)
- `TMinusPredictor::advance(beats)` — time-step, returns triggered events
- `predict_next()` — next-future lookup
- `countdown_beats()` / `countdown_seconds()` — time-to-event
- `confirm(id)` — subscribe-once confirmation
- `MessageSavings` — proves the polling-vs-prediction efficiency
- `ProgressionDB` — named patterns (ii-V-I, 12-bar blues)

### lau-tminus (single-file Rust, ~750 LOC)
- `PrecompiledScript` — script attached to predictions
- `PredictedEvent` vs `ActualEvent` — typed event matching via `matches_prediction()`
- `TMinusEngine` — predict() → observe() → execute() core
- `Timeline` — past / present / future rendering in 3 modes
- `TMinusSummary` — accuracy, active, scripts_ready, avg lead time

### tick-engine (single-file Rust, ~274 LOC, partial)
- `TickSchedule` — BPM-driven tick cadence, with swing
- `Tempo` — energy-adaptive BPM (clamped to min/max)
- `TMinusEvent` — countdown event with priority queueing

### terax-fleet-modules (TypeScript, 104 LOC)
- `selectModel()` — casting-call model router (10 curated models)
- `formatTilesAsContext()` — PLATO tile → AI context
- `fetchFleetContext()` — Promise.allSettled-style parallel fetch
- Patterns: `context priming at T-minus-zero` — spatial/contextual complement to t-minus-rs's temporal layer

## What swarm-tminus will gain from each

| Module in swarm-tminus | Source |
|----------------------|--------|
| `CountdownEvent`, `EventStore`, `Campaign` | t-minus |
| `CronParser`, `DeadlineTree`, `RatePair`, `TempoNegotiator` | t-minus-rs |
| `Predictor`, `Prediction`, `confirm()` | tminus-music |
| `EventMatcher`, `Timeline`, `Summary` | lau-tminus |
| `TickClock`, `BPM`, `swing()` | tick-engine |
| `casting_call.selectModel()`, `formatTilesAsContext()` | terax-fleet-modules (Python port) |

## Status

This is **design documentation**. Swarm-tminus itself (the Python implementation) was being built when the tool runtime jammed; the implementation was not pushed to GitHub. The next agent should resume from SYNTHESIS.md and build out the modules per the integration table.

---

*Heavy documentation for heavy lifting — the tminus ecosystem is the time-shaped substrate that swarm-anchor lacked.*
