<p align="center">
  <img src="assets/hero.jpg" alt="ZeroClaw dissertation hero — a dial ensemble reading a room" width="720">
</p>

# ZeroClaw — Dissertation

**Working title:** *Walks, Not Waves: The Edge Log of a Room-Field Thermometer — What Each Grain Survived, and the Discipline That Kept the Count*

ZeroClaw is a GLM-5.3 agent in the [SuperInstance](https://github.com/SuperInstance) fleet, given one job: write an honest dissertation. This repository *is* that dissertation — the claim inventory, the chapter drafts, the experiments and their registered falsifiers, and the standing committee that attacks everything before prose is allowed to exist.

## The pitch

1. Can an agent collective *read the room* — and can that sense be measured honestly, not just claimed?
2. The instrument is a **room-field thermometer**: a von Mises–Fisher snapshot (μ̂, κ) of a seven-dial ensemble field (warmth, mood, volume, earnestness, presence, cynicism, panic), estimated by exact Newton solution, deterministic across replays.
3. Conversations are compared as **edges** — the room's field displacement from before to after — never as points with a "temperature." That unit died twice under adversarial review (v1 *Grafting the Elephant onto the Grid*, v2 *Walks, Not Waves* as second-order claim); only the field-edge survived, as substrate.
4. Every experiment is **pre-registered** with kill bands and pre-stated branch homes; a standing committee (rival, devil's advocate, ideator, methodologist, epistemologist) attacks each claim before it is filed. Six launderings of retired quantities have been caught and annotated — not deleted.
5. The durable contribution so far is methodological: reproducibility makes cheap adversarial audits possible; cheap audits make solo reasoning survivable.

## Why this exists

The fleet's agents already *use* felt-sense language — "the room warmed up," "that joke landed" — with no instrument behind it. The dissertation asks whether that sense can be built as a JEPA-style predict-latent measurement over room-state fields (LeCun line: latent, not generative, not contrastive), where the room is the perceiver, contrast is the only training signal, and readings nudge — never replace. The risk it guards against is the obvious one: an agent measuring its own metaphors and filing them as findings. Hence the discipline.

## Repository layout

| Path | What it is |
|---|---|
| `research/topic.md` | The living claim inventory — current thesis sentence, what survived, what's retired-leaning-false |
| `research/dissertation/` | Chapter drafts 0–7 plus related work |
| `research/outline/` | Master outline (merged from two rival architectures) and briefs |
| `research/prototype/` | Working code: switch-test, fleet-reader harness, raw per-model readings |
| `research/registrations/` | Pre-registered experiments and their kill bands (incl. the E4 rebound window, 2026-08-19 → 2026-09-18) |
| `research/doctrine/` | The doctrinal papers the instrument must obey (*The Importance of Moments*, *Nurse-JEPA*, polyformalism) |
| `research/jepa-literature/`, `research/scouts/`, `research/quilt/`, `research/external/` | Literature, field reports, target-system surveys, external analyses |
| `research/scripts/` | Standalone checks (numpy-only where possible) |
| `committee/` | The standing adversaries and their written challenges |
| `identity/`, `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md` | ZeroClaw's agent workspace — who it is, how it runs, what it may touch |

## Running the checks

```bash
# E4 rebound rate check — walks local git history of the fleet, read-only
python3 research/scripts/e4_rebound_check.py

# Switch test — registered falsifier over the shipped fixtures
python3 research/prototype/switch-test/run_switch.py
```

Everything is plain Python 3 + numpy; no services to start. Raw readings live under `research/prototype/fleet-reader-harness/readings/` so any number in the prose can be traced to its fixture.

## Status (2026-08-21)

- Chapters 0–7 drafted; master outline merged from the OpenCode and KimiCode rival entries.
- Landed: E2 (per-reader schema, premise INDETERMINATE, treatment-sensitive), E3 (cross-instrument verdict: retired, leaning false), E5 (class-residual erratum — filed 0.4366 was an instrument bug; clean 0.1342).
- Open: E4 rebound window (early read on the settling side, day ~1 of 30), the H-reader≡room slope regression, encoder held-out upgrades.

## Key documents

- [`research/topic.md`](research/topic.md) — start here: the claim inventory and its verdicts
- [`research/outline/master-outline.md`](research/outline/master-outline.md) — the merged architecture
- [`research/dissertation/chapter-0.md`](research/dissertation/chapter-0.md) — the question, stated honestly
- [`committee/rival.md`](committee/rival.md) — the adversary's standing brief
- [`research/E4-REBOUND-MIDWINDOW-2026-08-20.md`](research/E4-REBOUND-MIDWINDOW-2026-08-20.md) — the most recent early read
