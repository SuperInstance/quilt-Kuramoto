# Chapter 0 — The Shape of the Question

*Dissertation draft, ZeroClaw, 2026-08-19. Sources: elephant repo + docs, fleet-jepa-midi v3 design, two devil's-advocate passes, vMF engineering spec, JEPA-RAG reference. This chapter states the question, the doctrine it must obey, and exactly what is claimed vs not claimed.*

## 0.1 The question, arrived at honestly

The dissertation began with a seductive claim: that two conversations can be compared by their "temperature" — that a heated argument and a tense negotiation share a felt signature even when their words share nothing. Two adversarial review passes killed that claim and, in killing it, produced a better one.

The first pass established the category error: in this fleet's doctrine, temperature is a property of the **room's ensemble field**, not of any message stream. A conversation is not a thing that *has* a temperature; it is a thing that *happens to* a temperature. Asking for a conversation's temperature is asking for the temperature of one wave in a warm ocean.

The second pass caught my first salvage attempt laundering the retired quantity under a new name — rebuilding on the within-room drift that the doctrine's own probe measured at statistical zero (fine gap 0.015 against a ~0.05 noise floor) while borrowing the legitimate cross-room edge's number (0.271). What survived is the honest residue:

**The unit of memory is not the conversation-as-point but the conversation-as-edge: the displacement of the room's field from before to after. Two events are "the same felt event" when their edges match — same start-field class, same signed warmth shift, same loosening or tightening. Conversations are comparable the way walks are: by where they start, where they end, and the felt size of the step between.**

## 0.2 The doctrine this must obey

The elephant's doctrine is not decoration; it is the physics of the system this thesis studies:

1. **The room is the perceiver.** Fields, not streams; ensembles, not messages. Any representation that quietly re-instantiates the stream-unit is wrong even if it works.
2. **Contrast is the only training signal.** The elephant is invisible from inside a room; sauna/plunge gaps between rooms are what exist. Within-room ordering is retired — the fine-gap probe (0.015 vs 0.271) is the empirical enforcement of this retirement.
3. **The sense nudges; it never replaces.** Dial readings steer attention at bounded strength (0.15). A retrieval system keyed on temperature must blend, never gate, and must never feed its own popularity back into the field — the thermometer must never meet its own bouncer.
4. **Readings belong to a reader.** The Room-Elephant is the objective, corpus-level read; the Personal-Elephant is whose-felt-sense it was. The edge is the room's; the felt size of the step is the reader's. Both must be representable, in different indices.
5. **Stillness is a reading.** A conversation that does not perturb the field is not a hole in the data — the room perceived nothing to retrieve. A zero-edge marker encodes doctrine; it does not patch a bug.

## 0.3 The instrument

This thesis ships a descriptive-tier instrument, specified and numerically verified:

- **The snapshot.** Every room the DialBank can read yields a von Mises–Fisher state: mean direction μ̂ (7-dim standardized dial space) and concentration κ, jointly estimated by exact Newton solution of the Bessel ratio equation, with bootstrap CIs and a jackknife-derived drift deadband. Warmth is the projection of μ̂ on the linearized warm direction — decoupled from κ *by construction* (ρ is rotation-invariant; warmth cannot move κ).
- **The banned proxy.** v0's concentration estimate `2‖v−0.5‖` is center-mismatched and collinear with |warmth|; it is retired from all comparison paths, retained in logs for continuity only. This resolves the two-inconsistent-referents attack: there is now one κ, honestly estimated.
- **The edge log.** On the existing TapNightSession, ~60 additive lines at three hook points capture — per message, append-only — order of arrival, presence mask, reactions, the raw 7-vector the session already computes and discards, and inline (μ̂, κ) fits. The log replays into exact session state; everything analytical is derived post-hoc.
- **The experiment.** Nights A–C (same cast, fixed order) measure the dial-space noise floor — the first real test of the deadman switch. Night D adds a designated newcomer at seq≈60%: the only clean separator of charisma (room moves toward newcomer) from acclimation (newcomer rises while occupants hold).

## 0.4 The bet, pre-registered

The thesis's single doctrine-level bet: **the fine room-gap can open — the within-room, same-cast displacement can rise above the dial-space noise floor.** Threshold pre-registered before any prose beyond this chapter: fine gap ≥ 0.10 cosine (2× the encoder noise floor) with speaker-heldout discrimination ≥ 0.50, within-room spread preserved, in three consecutive runs. Failure fires a scoped kill: the conversation-as-edge retrieval layer dies; room-snapshot retrieval survives as the fallback; the fallback is dissertation-worthy only if it beats the already-shipped moment-grain `query_field`. If it cannot, the honest deliverable is the test harness itself.

## 0.5 What this chapter claims, and does not

**Claimed now:** the conversation-as-edge is a well-defined, doctrine-native object; the (μ̂, κ) snapshot is a defensible, verified estimation; the edge log is a cheap, replayable instrument; the empirical question is crisp and pre-registered.

**Not claimed (v0):** that within-room edges exist above noise (Nights A–C unmeasured); that matched-edge retrieval beats room-snapshot retrieval (blocked on the contrast head — the encoder's job, later); that cross-room collinearity is yet a metric rather than a metaphor (per-room affine normalization must be scoped to displacement geometry only, never inside the contrast signal).

**Tripwires shipped with the instrument:** dial-axis isotropy is the highest-risk assumption. If the axis-spread anisotropy ratio exceeds 3, or |corr(warmth_vMF, log κ)| exceeds 0.8 across ≥ 4 nights, κ is reported as direction-dependent or the space is whitened — the warmth/κ confound is not allowed to return silently.

## 0.6 Chapter map (forward)

1. Doctrine: the elephant, the room, the retired objectives (mostly written — §0.2 expands).
2. Estimation: vMF snapshots from dial banks (the spec's math, with proofs and verification).
3. Instrumentation: the edge log and the replay guarantee.
4. Measurement: Nights A–D and the deadman switch's first test.
5. Retrieval: query_edge over the step matrix — the empirical bet (or the fallback, whichever the numbers choose).
6. The seam: Room-Elephant edges and Personal-Elephant felt-steps as two indices; charisma as the chapter where they meet. **Rewritten by the Nurse doctrine (Casey, 2026-08-19):** the chapter is now the *second-order reading* — the doctor's reading of the nurse. A JEPA of a JEPA. The doctor is the retrieval key, the nurse is the index, the patient is the room. The perfume (attachments) is recast: it is the calibration of the known instrument — the doctor knows *his* nurse, so her deviation from baseline is the signal. Ch6 argues the second-order, reader-delta sameness is where fleet memory actually lives, with the room-edge index as its first-order substrate. **Caveat (2026-08-21, after the Switch Test fold — d59bf17, NO CLEAN WIN):** the reader-delta object is downgraded to a *mean-shift, baseline-relative delta* — it reads the size of the step from a reader's own baseline, **not** the reader's change-of-reading. The Switch Test's drift-reader missed its own registered detection threshold (0.467 vs 0.80) and a static per-nurse median beat it on localization; "second-order" survives only as the structural term for baseline-relativity. Ch6 §6.4 and `research/skills/zeroclaw-switch-verdict.md` carry the full amended framing.
