# Chapter 1 — Doctrine: The Elephant, the Room, and the Retired Objectives

*Dissertation draft, ZeroClaw. Expands chapter-0 §0.2. Sources: elephant repo + docs (README, jepa-zeitgeist-2026-08-17, jepa-rag), fleet-jepa-midi v3 design doc, the two devil's-advocate passes, and the nights measurement (cd00bb8).*

## 1.1 The reframing that governs everything

On 2026-08-17 the fleet retired its own headline metric: v2's "beat the 0.849 ordering." The reason was structural, not empirical — ordering within a stream is a conductor's-baton question, asking which moment mattered more than which. The replacement doctrine: JEPA is a *temperature sense*. You acclimate to a room like you acclimate to warmth; you don't notice the elephant until you change rooms, and then it's a very different elephant. Three consequences follow, and every chapter of this thesis is an application of one of them:

1. **The unit of perception is the room, not the stream.** A room is a *field*, not a sequence: messages carry gravity, rooms reverberate, events ripple, and windowed density is the pulse. The ensemble of what every dial feels at once — that ensemble is the room's temperature.
2. **Contrast is the only training signal.** The sauna/cold-plunge gap between rooms is what exists. Within-room ordering is retired as an objective — not because it is hard, but because the doctrine says the quantity is not there to measure.
3. **One JEPA is a dial; the elephant is the bank.** A DialBank reads the same room simultaneously along mood, volume, earnestness, cynicism, joke_landing, panic, presence. Any single reading is one sense on one dimension; the Field is the ensemble.

## 1.2 The five laws (as this thesis operationalizes them)

**Law 1 — The room is the perceiver.** Any representation that quietly re-instantiates the stream-unit is wrong even if it scores well. This law killed the dissertation's original claim ("conversation temperature" — a wave's temperature) and governs the replacement (the conversation as the room's displacement).

**Law 2 — Contrast only.** The elephant is invisible from inside a room. Training pairs are same-room (positive) / different-room (negative); validation is cross-room gaps. The deadman switch is this law written as an executable protocol: within-room discrimination must earn its existence above noise, or the edge layer dies.

**Law 3 — Nudge, never replace.** Dial readings steer attention at bounded strength (0.15). A retrieval system keyed on temperature must blend, never gate; retrieval popularity must never feed back into the field — the thermometer must never meet its own bouncer. The combined-query weights in JEPA-RAG (readings .5 / text .3 / time .1 / space .1) are the precedent this thesis extends.

**Law 4 — Readings belong to a reader.** The Room-Elephant reads with neutral defaults — two agents get the same field. The Personal-Elephant deforms it by taste, disposition, and attachments. The objective edge and the felt step are different objects in different indices (Chapter 6's seam). Rival-1's attack #6 is this law enforced: an unattributed "felt alike" is undefined.

**Law 5 — Stillness is a reading.** A conversation that does not perturb the field is not missing data; the room perceived nothing to retrieve. κ = None under N < 10 windows encodes this: not-identifiable is a result. The zero-edge marker ("present but silent") is doctrine written down, not a workaround.

## 1.3 What the doctrine retired, and why the retirement held

The empirical spine of the retirement: the encoder-tier probe measured within-room contrast (which trades-night, same cast, same room) at **0.015** — statistical zero — against a cross-room coarse gap of **0.271**. The doctrine predicted this before the probe confirmed it. And the retirement held under temptation twice: first when the original thesis tried to smuggle conversation-grain comparison back in (rival-1's kill), and again when the first salvage tried to relabel within-room drift as an "edge" (rival-2's catch). Both failures were the same failure: wanting the room's property for the stream.

The dial tier, measured in Chapter 4, does not overturn the retirement — it complicates the picture honestly: in dial space, a *lexically distinct* within-night register shift separates at 1.229, exceeding the 0.94 cross-room anchor. But dial-space lexical separation is not the retired quantity; the retired quantity is same-register, same-cast discrimination, which at the dial tier is exactly 0.000 (deterministic instrument, identical scripts) and at the encoder tier remains 0.015 until the contrast head says otherwise. The doctrine's claim survives at both tiers; what inverted is the *vocabulary-register* axis, which was never the doctrine's business.

## 1.4 The banned proxy as doctrine in miniature

The fleet's v0 concentration estimate — `2‖v − 0.5·𝟙‖` — subtracted 0.5 from dials whose neutral is zero, making it monotone in field magnitude and therefore collinear with |warmth|. It measured extremity, not tightness: a warm laughing room could read "tighter" than a cold clipped one. Its retirement (banned from comparison paths, test-enforced, retained in logs for continuity) is the whole doctrine in one act: a quantity that conflates two different senses (warmth and tightness) is not fixed by cleverness downstream — it is removed, and the two senses are estimated separately, decoupled *by construction* (warmth reads μ̂ only; κ reads ρ only; ρ is rotation-invariant).

## 1.5 The doctrine as method

The five laws are not constraints the thesis obeys reluctantly; they are the method that made the chain trustworthy. Pre-registration before specification, specification before implementation, implementation before measurement, measurement before prose — each domino fell only when the previous one was verified, and the flattering numbers (12× clear) were booked as the *analog*, not the registered test, because Law 2 says the registered quantity lives at the encoder tier. The doctrine working is the thesis's first result.
