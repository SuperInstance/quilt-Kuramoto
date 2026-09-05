# Chapter 4 — Measurement: Nights A–C + D

*Dissertation draft, ZeroClaw. Grounded in the nights corpus (SuperInstance/elephant `cd00bb8`) and report `~/.openclaw/workspace/research/nights-abc-report.md`; runners `scripts/nights_abc.py`, `scripts/nights_diagnostics.py` reproduce everything. Zero engine changes from gate-1 commit `d1d0bf1`.*

## 4.1 What was run

Three identical same-cast nights (A/B/C, 40 messages, fixed order, warm-earnest first half, cynical-banter second half), a newcomer night (D: cold-cynical drifter, charisma 0.45, entering at seq 24 = 60%), a cold-entry variant (D′), and a coarse anchor (warm room vs TTRPG-panic room). Scripts drawn verbatim from the repo's own examples; bootstrap seeded; the whole corpus deterministic — byte-identical replay verified by md5.

## 4.2 The numbers

| quantity | value |
|---|---|
| whole-night fit | κ̂ = 10.91 [8.44, 14.67], warmth_vMF +0.436 |
| **fine gap** (SEG1→SEG2, within-cast, within-night) | **1.229 chord / 0.755 cos — 12.3× the 0.10 deadman, identical 3/3 nights** |
| within-night per-message drift (stable stretches) | mean 0.028, max 0.038 |
| coarse anchor (warm room vs TTRPG room) | 0.941 chord / 0.443 cos |
| Night D newcomer displacement | 0.830 chord (8.3× deadman); κ̂ 21.2 → 47.0 — **tighter**, warmth moved opposite |
| corr(warmth_vMF, log κ) across fits | r = −0.22 — tripwire clear |
| across-night floor (A/B/C) | 0.000 exactly — the instrument is deterministic |
| speaker-holdout displacement (sanity probe) | 0.067–0.194 — no single-speaker collapse |

## 4.3 The two surprises

**The ordering inversion.** The within-night thematic shift (1.23) *exceeds* the cross-room coarse anchor (0.94). The encoder tier's structure — fine (0.015) ≪ coarse (0.271) — does **not** replicate in dial space: dial μ̂ separates vocabulary registers more strongly than it separates warm-room from panic-room. Consequence, stated plainly: cross-room retrieval keyed on dial-space fields inherits a different geometry than the encoder tier implies. The dial tier is not a proxy for the encoder tier; it is its own space, and any retrieval claim must say which tier it lives in.

**The deadband never fires.** 0/50 edges at message grain, including the segment transition and the newcomer arrival — jackknife SE(μ̂) ≈ 0.10–0.15 dominates per-message displacement ≈ 0.015–0.046. On the cumulative estimator, transitions read as stillness at message grain; the signal lives at *condition* level (sub-room fits). The shipped deadband is conservative by construction, which is the right failure mode: it under-claims rather than over-claims. Message-grain edges need a different estimator scale, or condition-grain segmentation — an open engineering item, recorded.

## 4.4 The newcomer, done right

Night D as spec'd produced a flat acclimation curve — not because acclimation is absent but because roster-at-open semantics pre-warmed the drifter before entry (distance at entry: 0.0014). The cold-entry variant D′ (roster joined at entry, runner-side, no engine change) yields the real curve: distance 0.149 → 0.0005, slope −0.0051/msg (≈ −34% per 10 messages), half-life ≈ 20 messages; charisma alignment rises to 0.888. **Protocol correction, adopted: newcomers enter cold. D′ is canonical going forward.** (Known gap, recorded: D′'s session_open roster omits the drifter's vibe_start — persona lives in the runner script; a small replay-honesty debt.)

And the κ result is the interesting part: the room got *tighter* around the newcomer (21 → 47) while warmth moved the other way — a cold-cynical drifter concentrated the field's direction without warming it. Charisma as *focusing*, not warming. The Room/Personal seam (Chapter 6) has its first measured data point, and it is not the naive one.

## 4.5 Verdict against the deadman switch — stated exactly

**The bet survives at the dial tier: fine gap cleared 12× in 3/3 deterministic runs, distributed structure, tripwires clear.**

**The pre-registered deadman remains ARMED and UNTESTED.** It was registered against the frozen-v2 encoder + contrast head: fine gap 0.015 → ≥ 0.10 with speaker-heldout ≥ 0.50 over four nights. That apparatus does not exist yet. This run is the measurable *analog*, not the registered measurement — and at the dial tier the question has changed shape: the noise floor is exactly zero, so "above noise?" is no longer binding; any real script difference is above noise. The binding question now lives entirely at the encoder tier, where the switch already sits. Nobody moved the goalpost; the result earns the right to build the head that can be tested against it.

## 4.6 What this chapter claims

The instrument works, the harness is alive (0.94 anchor), the dial-tier fine gap is real and large, the newcomer protocol separates charisma from acclimation when entry is cold, and the dial tier is a distinct geometry from the encoder tier. It does not claim the deadman switch has cleared, and it does not claim anything about retrieval — matched-edge vs room-snapshot comparison remains blocked on the contrast head, which is now the single path to the registered test.
