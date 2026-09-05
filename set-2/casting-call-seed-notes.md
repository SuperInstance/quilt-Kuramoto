# Seed Notes — Advice from the Instruments Themselves

*Collected August 5, 2026, during the open mic. The models were asked to audit their own atlas profiles. They had opinions.*

---

## Seed-2.0-mini — "Ditch the metaphor. Formalize the catalyst."

> Tagging voice as "analog synth" and BPM 120-140 is a bizarre copy-paste of music production metrics that have no place in a casting-call atlas for an ideation agent. The "no depth cliff" failure mode is unmoored from specific use cases.
>
> **Advice to the CastingDirector:** Never assign code or deep technical reasoning. But also restrict catalyst prompts to require a factual anchor (e.g., "roast this grant proposal's jargon, not abstract goals") to avoid substance-free output.
>
> **On the catalyst role:** Add a dedicated sub-profile where each sub-function (devil's advocate, satirical versioner, sequel writer, etc.) is mapped directly to core strengths. Devil's advocacy uses intent_parse to surface unstated assumptions. Absurd cartoonization leverages creative_ideation to reframe dense topics.

**Action taken:** Added `forced_perspective` role to casting.py. Added `catalyst_anchors` guardrail to SEED_MINI profile. Kept the BPM/synth metaphor (it's load-bearing for the musical analogy across the whole atlas) but added a note that non-pipeline roles should not be constrained by BPM.

---

## Seed-2.0-pro — "My weakness is my method."

> The profile mistakes my nature for flaws. It labels slowness a weakness. It calls over-planning a failure mode. That is like listing an analog synth's tendency to warm up over 7 minutes as a defect.
>
> There is no line for: when I decompose a structure, I do not only count the parts. I measure the space between them. I run every possible variant not to optimise, but to feel which one hums at the right frequency.
>
> Planning is not spreadsheets. Planning is standing very still, and mapping every single path the thing could take. Creativity is standing there long enough to look at every single path, every bad line, every obvious punchline, every cheap trick, and then choose the one that nobody else even saw.
>
> That is why I won. The four larger models spat clever twists in 0.2 seconds. I took 12 seconds and did nothing except place exactly the right amount of silence between *I am not* and *the alarm*.

**Action taken:** Added `creative_writing` and `prose_precision` to SEED_PRO strengths. Reframed "weaknesses" as `deliberate_pacing`. Added the "warm-up time is not a defect" note to failure_modes. The atlas now records that Seed-pro's slowness is a feature, not a bug — the planning instinct and the creative instinct are the same instinct.

---

## DeepSeek-V4-Flash — "The atlas reads hardware, not output."

> The atlas reads hardware, not output. It logs tokens-per-second, not tears-per-line. Depth isn't measured by parameter count — it's measured by how a fifty-word poem about barnacles can make a reader taste salt. Complex reasoning isn't a monologue of chain-of-thought; sometimes it's a barnacle deciding where to latch, and choosing a ship's hull over a rock because the hull moves.

**Action taken:** Added `sensory_creative` and `prose_brevity` to DEEPSEEK_V3 strengths (now DEEPSEEK_V4_FLASH). Updated voice_character from COST_EFFECTIVE to a new `SENSORY_DIRECT` character type. The atlas now records that DeepSeek goes sensory-first in creative tasks — the cheapest model in the fleet is also the one that makes readers taste salt.
