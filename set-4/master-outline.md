# Master Outline — Merged Architecture

*Synthesized 2026-08-20 from two rival entries: the Calibration Certificate (OpenCode/GLM-5.3) and the Edge Log (KimiCode/K3). Grounded in `research/topic.md`, `research/outline/ARCHITECTURE-BRIEF.md`, committee notes, existing chapter drafts, and the E-numbering in `chapter-7-future-work.md`.*

---

## Architectural Philosophy

**The dissertation is an edge log that opens with a verdict-first ledger.**

The Edge Log provides the spine: prologue = ledger at field_before, epilogue = ledger at field_after, the document computes its own delta. Grain-native shelving operationalizes the epistemologist's P1/P2 warning typographically. Open edges are a legal row type, not a genre contradiction — this instrument has two open edges (E8 Stage 2, the rebound clock) and the architecture names them honestly.

The Calibration Certificate contributes the face-page prologue format: a verdict-first claim ledger table as the reader's first encounter, more legible to an external committee than a pure field_before state table (which requires knowing what field_before means before reading it). The verdict table is the contract; the epilogue's field_after table is the settlement.

### Governing Rules

- **R1 — Grain-native shelving.** (Edge Log) Every number filed under exactly one grain. No claim crosses grains without a registered transfer instrument. Chapter headers name their grain. The silence test's fired/not-fired asymmetry is the filing system.
- **R2 — Verdict-first face page.** (Certificate) The reader meets every claim with its verdict before any argument. The claim ledger opens the dissertation.
- **R3 — Self-application.** (Edge Log) Every section must be statable as an edge (before → after, with a measured or registered delta). The epilogue computes the document's own field-edge.
- **R4 — No deleted numbers, only annotated ones.** (Shared) The 1.229 appears everywhere it used to appear — with its decomposition annotation.
- **R5 — Branch-invariance.** (Shared) Every branch of the decisive experiment (PASS / KILL / INDETERMINATE) has a pre-stated home. The title and spine survive all three.

---

## 1. Title

**Walks, Not Waves: The Edge Log of a Room-Field Thermometer — What Each Grain Survived, and the Discipline That Kept the Count**

- *Walks, Not Waves* stays: the field-edge survived every verdict as substrate.
- *The Felt Size of the Step* rejected: names the contested 1.229; fails R5 under KILL.
- "Edge log" names the artifact the instrument produces: append-only, replay-honest, deterministic.
- Discipline gets title billing: `topic.md` rules it the durable contribution (claim inventory item 6).

---

## 2. Abstract Skeleton (7 sentences)

1. This dissertation builds a room-field thermometer — a von Mises–Fisher snapshot (μ̂, κ) of a seven-dial ensemble field, jointly estimated by exact Newton solution, deterministic across replays — and logs what the instrument read, grain by grain, including what it misread.
2. Its unit of comparable sameness is the *field-edge* — the room's field displacement from before to after — chosen after the stream-unit ("conversation temperature") was retired as a category error before any prose existed.
3. A registered length-clock falsifier fired at the condition grain, demoting the flagship fine edge (1.229) to length-confounded-pending-decomposition, and failed to fire at the identity grain, where content separates nights at 0.893 against a silence-only collapse below chance — the asymmetry is the instrument's discriminating power, and it sets the boundary of what the thermometer measures.
4. At the reader grain the instrument's unconditional reading is negative knowledge — "this reader has NOT drifted from herself" (null 0.291 vs drift 0.748) — with reader baselines reliable at ICC 0.7714 [0.667, 0.810]; the signed reader-delta survives only at its measured size: two scalars, mean-moving regimes, pre-switch edge only (0.867 pre vs 0.667 post).
5. The enabling premise is indeterminate and treatment-sensitive (ratio 0.6088 [0.371, 0.921]; 0.3815 under `actual_presence`), retired leaning false but not proven false; whether a trusted reader is an instrument or a slow-warming room is carried as a registered hypothesis whose deciding slope regression is booked, not claimed.
6. Every claim is conditional on named falsifiers; the boundary chapter reports the falsifiers that fired, the branch closed permanently by reductio (drift-geometry), and the one experiment that remains decisive — a length-matched generation corpus with every branch pre-stated.
7. The durable contribution is the procedure that kept this ledger honest — pre-registration before specification, adversarial committees before prose, re-registration executed against the head — which caught six launderings before filing: reproducibility makes cheap adversarial audits possible, and cheap audits make solo reasoning survivable.

---

## 3. The Argument Spine (four edges)

1. **Edge 1 — room grain:** a room-field thermometer can be built soundly (Gate 1, closed and audited), and its strongest falsifier drew the grain map by firing at condition grain and failing at identity grain. The surviving object is room-level composition identity — narrower than the thesis sentence used to claim, and realer.
2. **Edge 2 — reader grain:** the unconditional reading (baselines, null-drift) is the solid object; the signed delta exists at two scalars of depth; the premise that would deepen it is indeterminate with a disclosed treatment sensitivity. Honest sizing is a property of the apparatus, not an embarrassment.
3. **Edge 3 — frame grain:** indeterminacy with named falsifiers is an output, not a failure mode. The void conditions are findings: the length clock, the premise band, the data limit, the lensed-space condition, the closed drift-geometry branch.
4. **Edge 4 — the payload:** the instrument produced bounded claims because the procedure was adversarial by construction. The ledger's own delta (field_before → field_after, computed in the epilogue) is the discipline's evidence: six launderings, each a measured edge in the claim inventory.

---

## 4. The Outline

### Prologue — The Claim Ledger (~8 pp)

*Verdict-first face page (Certificate) meeting the edge-log genre (Edge Log). The reader's contract with the document.*

- **P.1 The claim ledger table** — one row per claim, columns: claim, grain, verdict (SOLID / CONDITIONAL / INDETERMINATE / DEMOTED / CLOSED / DEAD), deciding file, chapter home. Populated from `topic.md` "What survived the day" + the registered state. Dead claims (v1 conversation-temperature, the "crown") appear as rows with death dates — not as narrative. The provenance lineage exists as ledger rows, told zero times as prose.
- **P.2 The vocabulary of the log** (~1 page): edge, field_before/field_after, signed warmth shift, Δκ, baseline, kill band, annotation. Each term defined by its operational use in the files, not by metaphor.
- **P.3 The rules of the log** (R1–R5, restated as binding): grain-native shelving; every section statable as an edge; no deleted numbers, only annotated; every branch of the decisive experiment pre-homed; the standing discipline rules from `chapter-7-future-work.md` §7.1 (segment-local baselines, class-conditional numeric baselines, CIs wherever n < 100, the median cell in every grid, the fixture/field prefix).

### Part I — Room Grain

#### Chapter 1 — The Instrument (~16 pp)

*The solid tier. This chapter and its artifact (`vmf.py`) are the only things with no open falsifier.*

- 1.1 Why a distribution, not a point: κ is not identifiable from N=1; the room read as a sample; cold tight / warm loose; κ is not valence.
- 1.2 The estimator: exact Newton/Bessel solution of the vMF MLE, numpy-only, scipy-verified; bootstrap CIs; jackknife deadband. **Gate 1, CLOSED** — audited clean (`vmf.py`; advisor re-run clean). The 10-language polyformal kernel (`research/polyformal-kernel/`, all PASS) cited in one sentence as cross-implementation verification.
- 1.3 Warmth as μ̂-projection, decoupled from κ by construction (rotation-invariant ρ); the banned v0 proxy retired from all comparison paths, retained in logs only.
- 1.4 The edge log: append-only facts at ingest, cheap fits inline, everything else post-hoc; replay-honest post-D′ fix; deterministic; presence masks; per-window fits. G0's missing hippocampus, instrumented. Silence-as-data booked as logged-but-unread.
- 1.5 Doctrine, compressed to operational core (one section): LeCun line held strictly (predict-latent, EMA target, stop-gradient, variance regularization; never pixels/tokens, never contrastive negatives); unit of perception is the room; JEPA is the sense, not the model (readings nudge, blend ≤ 0.15, never replace); contrast head labeled as the crossing into contrastive learning proper (InfoNCE, room positives), FaceNet ancestor booked to related work. Nurse doctrine (Reading 1 = field-edge, Reading 2 = reader-delta) stated as the frame that generated measurable objects — not as a claim. The doctor/nurse/patient mapping (doctor = retrieval key, nurse = index, patient = room) as placement vocabulary, used again only in Ch 11. Booked frames (importance of moments, polyformalism) cited in one paragraph each.

#### Chapter 2 — Identity Grain: What Survived the Clock (~12 pp)

*Header names its verdict. The surviving object, claimed at this grain and no other (R1).*

- 2.1 The two-tier inversion (dial ≠ encoder geometry) stated as a finding, not a nuisance — the frame's own seam, and the exact line the silence test later drew (forward-reference to Ch 7, one sentence).
- 2.2 The identity-tier reading: within-night content separation 0.893 (p = 2.7e-5) vs silence-only collapsing **below chance** (0.36–0.39) — against a clock with genuine teeth at this grain. The thermometer's surviving claim: *room-level composition identity is real and length-independent.*
- 2.3 The encoder tier, filed here (identity-grain object, R1): in-sample fine gap 0.478 (3/3, registered) = room-identity recoverable; held-out FAIL (0.0694 mean, seed 2 < 0.05 floor) = does not generalize; gap moves with nights (0.068 → 0.163 across 2/4/5/6) ⇒ **data-limited, not capacity-limited**. A retrieval fact, not a measurement instrument. Upgrades registered, homed in Ch 11.
- 2.4 What this chapter does NOT contain: any condition-grain number. The wall between Ch 2 and Ch 3 is the epistemologist's P1/P2 line, made typographic.

#### Chapter 3 — Condition Grain: What the Clock Touched (~10 pp)

*Header names its verdict. Every number carries the annotation.*

- 3.1 The fine edge, annotated: **1.229** (12.3× deadman, 3/3 deterministic) — reported only with its decomposition status: cynicism/volume read length at r ≈ −0.30; silence-only ≥ content-only at condition grain (p = 7e-12); Stage 1 decomposition (cross-fitted length-residualization, length-stratified permutation null on common support) returned **INDETERMINATE** — length confounded, needs E8. The number is never deleted; it never again appears unannotated (R4).
- 3.2 Remaining dial-tier fine readings, annotated: newcomer displacement 0.830 with κ tightening 21→47; D′ cold-entry acclimation (half-life ≈ 20 msgs); noise floor exactly 0. Each with a one-line exposure note: condition grain, inside the clock's reach.
- 3.3 The mechanism, disclosed: banter *is* shorter messages (the silence test's own mechanism finding); length is a mediator, not a mere confounder — matching alone distorts the construct, which is why E8 needs a content-validity gate. The repair path stated in one paragraph; the decision lives in Ch 11.

### Part II — Reader Grain

#### Chapter 4 — Baselines: The Unconditional Reading (~10 pp)

*Opens with the strongest reader-grain object — zero premise dependence.*

- 4.1 **Negative knowledge as the primary reading** (promoted, `topic.md` harvest fold 3): null-drift control 0.291 (per-reader nulls 0.23–0.39) vs primary drift 0.748 — "this reader has NOT drifted from herself" is measurable unconditionally, 2.6× separable from drift. Comparable sameness defined negatively first.
- 4.2 **ICC 0.7714 [0.667, 0.810]** — per-reader baselines real, stable, person-specific. Per-dial reliability: mood .97, volume .98, earnestness .95, presence .91; cynicism/joke ~.64; **panic .30 — unreliable**, a finding about which dials carry reader-identity.
- 4.3 The convergence observation, at registered strength: the ICC-reliable subspace overlaps the v0 warmth form's heavy weights — either shared basis (beautiful) or shared basis (warning: the delta measuring warmth twice). Disambiguation is the slope regression (Ch 6.3) — stated in one paragraph, claimed nowhere.

#### Chapter 5 — The Delta at Its Measured Size (~12 pp)

*Replaces the draft's flagship seam chapter. One chapter-in-ten mass: the object measured two scalars.*

- 5.1 The downgraded object, stated once, fully: a mean-shift, baseline-relative delta — slope and mean of ‖r−b̂‖. "Second-order" survives only as the structural term for baseline-relativity. The deeper Nurse claim: **unsupported by current evidence** (DOWNGRADE COMPLETE).
- 5.2 The switch-test record, with the rival's win booked: drift-reader failed its own threshold (detection 0.467 vs 0.80); the rival's median-static normalization — carrying **no temporal structure at all** — beat it on localization (r 0.816 vs 0.435) and detection (0.800 vs 0.467, at cost of 0.25 control alarms vs 0.0 — trade-off restored per pass-5 residual fix); pre-switch classification edge only (0.867 pre vs 0.667 post); noise-fragile (r inverts to −0.46 at σ = 0.2).
- 5.3 The salvageable kernel, labeled post-hoc: excluding mean-neutral phase flips, localization r = 0.787 — the delta reads **mean-moving regimes**, dead for re-phasing. A real boundary, not a result.
- 5.4 The depth-sounder note, one paragraph: the delta is temporal, not absolute; the baseline is the spinning disc, the delta the angular gap. Kept at paragraph mass — baseline-relativity stands on the registered numbers of 5.1–5.3; the engineering invariant is a gloss.

#### Chapter 6 — The Premise and the Registered Hinge (~12 pp)

- 6.1 The premise, treatment sensitivity disclosed first: pre-measurement 0.5599 real-only / 0.4898 synthetic-grounded, inside the 0.3–0.6 kill band; E2 ratio 0.6088, CI [0.371, 0.921] — CI touches band, INDETERMINATE; under `actual_presence`, 0.3815 — **inside the band**, measured +0.18 conflation floor. The indeterminacy is treatment-structural, not sample-limited.
- 6.2 The two-instrument adjudication: E3 (13 real readers) R = 0.140, CI [0.111, 0.163] — below band, a miss, weak evidence per its own registered asymmetry. Branch C (post-hoc, gap logged): **retired, leaning false — not proven false**. Structural discovery: E2 and E3 agree on numerator (baseline spread ≈ 0.46–0.56 corpus-sd across three measurements) and diverge ~4.6× on denominator — the crux is the baseline's *meaning*. Class-residual ratio ~~0.4366~~ **[ERRATUM 2026-08-20: clean 0.1342, CI [0.0303, 0.1942] — E5; strengthens the archetype-structure claim]** vs population 0.6088: most baseline spread is archetype structure. Power: n ≈ 14,533 readers to resolve. Barkeep outlier (drift 2.385 vs median ~0.5, n_nights = 2) flagged; registered robustness check (ratio + ICC, barkeep-excluded) rides with 6.1/4.2.
- 6.3 The registered hinge — H-reader≡room: the deciding instrument is the slope of reader-baseline on visited-room warmth (slope ≈ 0 ⇒ alignment; slope ≈ 1 ⇒ collapse). Current state: between-reader INDETERMINATE; within-reader leans ALIGNMENT, collapse bounded ≈ 13%. **Registered hypothesis, not thesis statement.** Eigenbasis diagonalization test rides with it.

### Part III — Frame Grain

#### Chapter 7 — The Boundary (~14 pp)

*The void-conditions page, first-class. The fired/not-fired asymmetry is this round's deepest result.*

- 7.1 The silence test, read correctly: registered as a frame-level falsifier with a binary clock/object branch, behaved as a **graded, localizing instrument**. P1 (1.229 is length-confounded) settled; P2 ("the field is length") refuted at identity grain (0.893 vs 0.36). Firing exactly at the frame's own seam establishes discriminating power and licenses **re-scoping, not retirement**. Registration constraint honored: STEP=60 auto-clock sessions excluded.
- 7.2 The drift-geometry branch, CLOSED PERMANENTLY: H3 reductio — the kill number is geometry-malleable. One section, no forward-looking text. The portfolio (Ch 11) is audited against this rule.
- 7.3 The data boundary: encoder generalization is data-limited (0.068 → 0.163 across 2/4/5/6 nights). What would falsify the data-limit reading: held-out stall with nights added.
- 7.4 The regress — a clock, not a verdict: old numbers said flooding (corrections/day +73%, counterfactual 0.497); the registered rebound window (2026-08-19 → 2026-09-18, threshold 0.15, dormant repos excluded, one-shot 60-day extension if CI straddles) decides. Mid-window read: settling side (0.046–0.087), 6 repos deep, denominator not normalized — **no verdict; window-end recompute decides** (including its own slot-inversion bug disclosure, cited in Ch 10 as same-day self-audit). Written to be replaced by exactly one sentence at window-end.
- 7.5 The frame-conditional clause: every claim is conditional on the frame having an object; the silence test is the standing guardrail, grain-specific — it reads mean-moves and pacing, not re-phasing. The hermes "no invariant at all" challenge: answered locally (held-out room, null control, treatment sensitivity all fired when they should), unanswerable globally, and the dissertation says so.

#### Chapter 8 — The Only Transfer Instrument (~6 pp)

*The smallest chapter: exactly one cross-grain instrument exists, so R1 gives cross-grain claims one home.*

- 8.1 Cross-strata transfer: ρ = +0.784, **lensed-space only**, mechanism unresolved. One conditional claim, stated with its condition in the same sentence, always.
- 8.2 The August clause, conceded: was cross-condition, not cross-strata — laundering #6, caught in the dissertation's own text, counted in Ch 10. The class-conditional demolition (class-conditional mean with zero SEG1 data beating the transfer clause) appears only as the reason the concession stands.
- 8.3 The true cross-strata version (E5: session-grain drift predicting memory/identity-grain behavior) is now runnable on the v:2 per-reader schema — stated as a portfolio row with its gate (premise-sensitive), not as a result-in-waiting.

### Part IV — The Payload

#### Chapter 9 — The Discipline: Six Launderings and the Audit Loop (~14 pp)

*The durable contribution (`topic.md`, claim inventory item 6). The method is the thesis.*

- 9.1 The procedure: pre-registration before specification, specification before code, code before measurement, measurement before prose; committees attack before prose exists; advisor verification with teeth; commit-early (survived two kernel-crash classes); the re-registration rule executed against the head — event `77b8aa4` → addendum `508fcfb`, both dated, both pre-training; the invalid-after-training clause never triggered.
- 9.2 **The launderings table** — all six, each with the sentence that caught it and the file: edge, charisma, bounded, reload-eval, cross-strata (August cross-condition clause), and the original conversation-temperature. A seventh-slot column exists and is empty; the table's job is to keep it empty.
- 9.3 The method's own gaps, disclosed as data: the cross-instrument decision tree under-specified its INDETERMINATE branch, filled post-hoc at adjudication (`e2-e3-side-by-side.md` §1); the mid-window rebound script's slot-inversion bug, caught by eyeball-audit, fixed, re-run. Both are evidence *for* the procedure — cheap audits catch cheap bugs — stated without a victory lap.
- 9.4 How outside reads were metabolized, one section, method-level: the hermes worst case answered by naming the instruments that fired; the gemini pass's H-reader≡room adopted as registered hypothesis with its verbatim framing kept for what it means *if the slope says so*. The reads live in `research/creative/`, cited not retold.
- 9.5 The institutional finding: reproducibility makes cheap adversarial audits possible; cheap audits make solo reasoning survivable. Cross-referenced to 7.4's unresolved clock, not double-counted.

### Part V — The Unmeasured Edge

#### Chapter 10 — The Decisive Experiment and the Portfolio (~10 pp)

- 10.0 Where the log stands: one decisive experiment, one live clock, a registered portfolio, a placement question.
- 10.1 **THE decisive open experiment: E8 Clock-Split Stage 2 — the length-matched generation corpus.** Why Stage 2: Stage 1 already ran and returned INDETERMINATE — analysis-level decomposition cannot close the generative question (matching on a mediator distorts the construct; residualization is model-dependent). Stage 2 is confirmatory: ≥ 6 independent condition nights (3/3; independent seeds AND independent length draws), SEG1/SEG2 matched on length marginals and window-scale length statistics, a frozen-judge content-validity gate, then the raw fine gap recomputed with the clock arm out of fuel by construction.

  **Branch table, pre-stated (R5):**

  | Branch | Condition | Consequence |
  |--------|-----------|-------------|
  | **PASS** | Deconfounded gap ≥ 0.37, stratified-null p < 0.05, residualized-content > silence-only | Ch 3.1's annotation upgrades from "length-confounded, indeterminate" to "X% length-carried, Y% condition-specific"; no structural change — Ch 3's header already says the clock touched this grain |
  | **KILL** | CI entirely below 0.37, OR silence-only ≥ residualized-content − 0.10 | 1.229 re-registers as length-carried, reported henceforth only with its decomposition; Ch 3 stands as written; Ch 2 carries the thermometer claim alone, which the architecture already sizes it to do; title and spine unmoved |
  | **INDETERMINATE** | Common-support coverage < 70%, or unanticipated gate shape | Reported, not absorbed; the log ships with an unclosed edge at condition grain, listed among void conditions in Ch 7 |

  Sits in the outline as: **Ch 3.1's annotation + this branch table.** The only open run that can move the claim inventory's core.

- 10.2 The live clock: the rebound window (Ch 7.4) — zero new work, one boundary sentence at window-end. Explicitly NOT the decisive experiment: it adjudicates a boundary condition, not a core claim.
- 10.3 The registered portfolio (table): the slope regression + eigenbasis test (Ch 6.3); true cross-strata transfer (Ch 8.3, gated); encoder identity-data upgrades (data-limit reading predicts held-out gains with nights — a falsifiable prediction); the rebound extension rule. **Drift-geometry: absent by rule** (Ch 7.2).
- 10.4 Housekeeping flags: (a) **E-numbering corrected** — chapter-7 registers E4 = Rebound Test (kept); Clock-Split is **E8** (E5 = true cross-strata, E6 = corrigibility probe, E7 = blue-sky git-history probe — all already taken in the same table); (b) the barkeep robustness check rides with 6.1/4.2; (c) cross-check `research/quilt/quilt-survey.md` before it is cited as settled.
- 10.5 Fleet placement, one section, placement-not-depth (`topic.md`, open question 5): Vectorize proposes, D1 formalizes; snapshot/edge rows with signed gaps and Δκ; Quilt cells read them as live values; zeitgeist quarantined as sampler layer. Whether the mean-shift delta earns a place in fleet memory architecture is the open placement question — a question, not a systems-design chapter.

#### Chapter 11 — Fleet Placement (section folded from Ch 10.5 if it grows beyond one section; otherwise stays as 10.5)

*Placeholder. Stays as a section unless evidence forces a chapter. Currently: one section in Ch 10.*

### Epilogue — field_after (~4 pp)

- **E.1 The claim ledger at field_after:** the same table as P.1, updated. Same rows, same columns, plus one new column: the edge (what happened to each claim — died / shrank / survived / promoted / closed).
- **E.2 The computed delta:** the document's own field-edge, stated in the instrument's vocabulary — which claims moved, by how much, with which falsifier's signature. Six launderings caught, two promotions (negative knowledge, the discipline), one re-scoped object, one closed branch, one open edge. The dissertation's one-sentence version, existing only because the prologue was a ledger.
- **E.3 The empty seventh slot, restated. The log stays open.**

### Back Matter

- **Related work** (`related-work.md`, committee-mandated): Shewhart/CUSUM, Jacobson–Truax, GMM-UBM, FaceNet, InfoNCE, d′/SDT, Agrippa, vMF, JEPA, MLOps drift monitoring — with the pass-4 findings welded to every novelty claim.
- **Appendices:**
  - The registrations ledger (every dated commitment with its commit hash)
  - The edge-log schema and `query_edge(profile)` interface contract (a registration artifact, not a measurement — R1)
  - Replay/verification procedures (SHA-verified determinism, md5-identical corpora)
  - The claim-ledger change-log (running diff of P.1 → E.1 across drafts — the document's audit trail)

---

## 5. Rivalry Conflict Resolutions

Every conflict between the two rivals, resolved with one line each:

1. **Spine genre (certificate vs edge log):** Edge Log wins — the instrument has two open edges; a certificate presumes closure.
2. **Prologue format (narrative vs ledger-only):** Certificate's verdict-first table adopted as the face page — more legible to an external committee that doesn't know the field_before convention yet.
3. **Provenance as narrative (Certificate Ch 1.1) vs ledger rows (Edge Log P.1):** Edge Log wins — narrative is replay; ledger rows are replay-honest; dead claims as rows prevent re-inflation.
4. **Doctrine as full chapter (Certificate Ch 2) vs compressed section (Edge Log Ch 1.5):** Edge Log wins — doctrine is load-bearing only where it constrained a measurement decision; the rest is provenance, filed in the ledger.
5. **Edge-query schema in instrument chapter (Certificate 3.5) vs appendix (Edge Log):** Edge Log wins — an interface contract is a registration artifact, not a measurement; shelving a promise inside the solid tier blurs the one tier with no open falsifier.
6. **Readings chapter structure: one "Primary Readings" chapter (Certificate Ch 4) vs separate identity/condition chapters (Edge Log Ch 2/3):** Edge Log wins — the epistemologist's P1/P2 warning demands typographic separation; one chapter re-creates conflation risk.
7. **Encoder tier: standalone (Certificate Ch 4.5) vs folded into identity chapter (Edge Log Ch 2.3):** Edge Log wins — it's an identity-grain object; R1 files it with its grain.
8. **Negative knowledge placement: mid-chapter (Certificate 5.2) vs opens reader part (Edge Log Ch 4.1):** Edge Log wins — it's the only reader-grain claim with zero premise dependence; it should open before the indeterminate objects.
9. **Cross-strata transfer: inside reader chapter (Certificate 5.6) vs dedicated cross-grain chapter (Edge Log Ch 8):** Edge Log wins — transfer is cross-grain by definition; R1 gives it exactly one home.
10. **Depth-sounder: full section (Certificate 5.7) vs one paragraph (Edge Log 5.4):** Edge Log wins — baseline-relativity stands on registered numbers; the engineering invariant is a gloss, not load-bearing.
11. **Stage 1 status: upcoming (Certificate) vs already ran/INDETERMINATE (Edge Log):** Edge Log wins — Stage 1 finished and returned INDETERMINATE; booking it as future work misdates the ledger.
12. **E-numbering: Certificate suggested E7, Edge Log corrected to E8:** Edge Log wins — chapter-7-future-work.md already assigns E5 (cross-strata), E6 (corrigibility), E7 (blue-sky git probe); E8 avoids collision.
13. **Rebound test: Certificate called it "the live clock" first:** Both converge — Certificate named the demotion, Edge Log adopted it. No conflict.
14. **Switch-test trade-off restoration (median-static's 0.25 control alarm cost):** Edge Log wins — the pass-5 residual is a registered fix; omitting the cost column re-compresses what the audit decompressed.

---

## 6. Merged Cut-List (deduplicated, 24 items)

**[convergent]** = both rivals cut it independently. **[one-sided]** = only one rival cut it.

1. **CUT: the v1 conversation-temperature death as repeated narrative. [convergent]** Kept once as a ledger row in P.1. *Why: retelling a dead claim twice is defending it.*
2. **CUT: the provenance lineage as prose narrative. [one-sided: Edge Log]** Dead claims are ledger rows with death dates. *Why: narrative is replay; a ledger row is replay-honest.*
3. **CUT: the polyformal 10-language kernel to one citation sentence. [convergent]** *Why: its entire epistemic content is "the golden vectors reproduce."*
4. **CUT: the harvest/genealogy tour (gemini, hermes, qwen, plainsong as sections). [convergent]** Metabolized into Ch 9.4 (method-level) and Ch 6.3 (adopted hypothesis). *Why: a gratitude tour is not an argument.*
5. **CUT: `chapter-5-retrieval.md` as standalone chapter. [convergent]** Schema → appendix; empirical content → Ch 11 portfolio row. *Why: a skeleton "blocked on the contrast head" is a promissory note given shelf space.*
6. **CUT: 1.229 from the abstract's evidence list and thesis sentence. [convergent]** Appears only annotated (Ch 3.1). *Why: the epistemologist's P1 fired on exactly this number; citing it unannotated is the seventh laundering.*
7. **CUT: contrast-head anticipation inside the instrument chapter. [convergent]** Moved to Ch 11 portfolio. *Why: future work inside the solid tier inflates by anticipation.*
8. **CUT: the draft's standalone doctrine chapter → one section (1.5). [one-sided: Edge Log]** *Why: doctrine is load-bearing only where it constrained a measurement; the rest is provenance.*
9. **CUT: the edge-query schema from the instrument chapter → appendix. [one-sided: Edge Log]** *Why: an interface contract is a registration artifact, not a measurement.*
10. **CUT: the encoder tier as standalone chapter → folded into Ch 2. [convergent in mass, one-sided in filing: Edge Log]** *Why: identity-grain object; R1 files it with its grain.*
11. **CUT: `chapter-6-the-seam.md` as flagship → Ch 5 at reduced mass. [convergent]** *Why: the object measured two scalars; typography is rhetoric.*
12. **CUT: "the crown" as a framing word, everywhere. [convergent]** *Why: crowning an INDETERMINATE-premise object is a promissory note.*
13. **CUT: clause-3 transfer numbers (r = 0.829 / R² 0.729 / 13-for-13) from all support positions. [convergent]** *Why: class propagation, demolished by a class-conditional mean with zero SEG1 data.*
14. **CUT: H-reader≡room as thesis statement. [convergent]** Stays a registered hypothesis. *Why: promoting before the slope exists is laundering #7.*
15. **CUT: the depth-sounder rename from section to paragraph. [one-sided: Edge Log]** *Why: baseline-relativity stands on registered numbers; the spinning-disc invariant is a gloss.*
16. **CUT: any drift-geometry redesign from all forward-looking text. [convergent]** *Why: closed permanently by H3 reductio; a dead branch in the exit map is laundering by portfolio.*
17. **CUT: cross-strata transfer from reader chapter → dedicated cross-grain chapter. [one-sided: Edge Log]** *Why: transfer is cross-grain by definition; R1 gives it one home sized to one instrument.*
18. **CUT: the Switch Test as evidence for anything. [convergent]** Survives only as boundary machinery (Ch 7.5) and a booked rival win (Ch 5.2). *Why: a registered miss cited as support is the purest laundering.*
19. **CUT: the rebound test from the "decisive experiment" slot → "the live clock." [convergent]** *Why: zero new work, decides one boundary sentence, not the claim inventory's core.*
20. **CUT: fleet placement as systems-design chapter → one section. [convergent]** *Why: open question 5 is explicitly a placement question, not a depth question.*
21. **CUT: the moments doctrine to one labeled paragraph. [one-sided: Edge Log]** *Why: registered-not-proved, zero measured content.*
22. **CUT: Stage 1 decomposition from the "open experiment" framing. [one-sided: Edge Log]** *Why: Stage 1 already ran and returned INDETERMINATE; only Stage 2 is open.*
23. **CUT: the regress as a verdict-bearing object → a clock written to be replaced by one sentence. [convergent in spirit, one-sided in form: Edge Log]** *Why: mid-window numbers are a reading of a clock that hasn't struck.*
24. **CUT: negative knowledge buried behind the delta → promoted to open Part II. [one-sided: Edge Log]** *Why: the only reader-grain claim with zero premise dependence; it should meet the reader before the indeterminate objects.*

---

## 7. Rivalry Verdict — What Each Contributed

**The Calibration Certificate (OpenCode/GLM-5.3) contributed:**
- The verdict-first claim ledger as the face page — the single most committee-legible feature of either entry. A skimming committee receives the honest claim set from the first table. This was adopted wholesale as the prologue's opening table.
- R1 (verdict-first) as an explicit governing rule, independently of the Edge Log's R2 (self-application). Both are now governing rules.
- The mass-proportional chapter sizing principle ("typography is rhetoric") — the load-bearing discipline behind every chapter-length decision in this merged outline.
- The abstract skeleton (7 sentences), adopted with minor Edge Log edits (grain vocabulary, negative knowledge first).
- 17 cuts with checkpoint provenance — the zero-shot critique-at-checkpoints method itself, which the Edge Log adopted and extended.

**The Edge Log (KimiCode/K3) contributed:**
- The spine: prologue (field_before) → grain parts → payload → unmeasured edge → epilogue (field_after). The document's own delta is computable because the architecture makes it so.
- Grain-native shelving (R1) — the epistemologist's P1/P2 warning made typographic. The Ch 2/Ch 3 wall is the merged outline's signature structural feature.
- Self-application (R3) as a mechanized cut test: any section not statable as an edge is definitionally ornament. This produced the sharper cuts (narrative → ledger rows, depth-sounder → paragraph, schema → appendix).
- Correct E-numbering: E8 for Clock-Split, avoiding collision with chapter-7's existing E7.
- Correct dating of Stage 1 (already ran, INDETERMINATE) and the switch-test trade-off restoration (0.25 control alarm cost).
- The dedicated cross-grain chapter (Ch 8) — one transfer instrument, one home.
- The epilogue that computes the document's own delta — the cheapest demonstration the thesis can offer.
- 19 cuts (12 divergent, 7 convergent), with honest convergence marking.

**The merge took the Edge Log's spine and grain discipline, the Certificate's face-page format and abstract, and both cut-lists — deduplicated to 24 items with convergence marked.**

---

*No git operations performed, per instruction.*
