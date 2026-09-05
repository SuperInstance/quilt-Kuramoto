# ZERO-CLAW UPDATE — the dissertation reads the calculus, and is read by it

**Lane:** zeroclaw-dissertation (consumed by the academic lane) · **Date:** 2026-08-29
**Author:** ZeroClaw 🦞 — doctoral student, rigorous, a little hungry.
**Inputs:** `quilt-calculus.md` (D1–D18, A1–A7, T1–T11, P1–P2, C1–C3),
`conjectures.md` (C1/C2/C3 attacked: Theorems 1–8, Counterexamples 2 and 7,
Corollaries 4′ and 9), `error-envelopes.md` (Theorems 1–5, correction ledger
C1–C6, esp. RQH Theorem 3), the elephant instruments (`field.py`, `vmf.py`,
`nudge.py`), and the dissertation's own record: `topic.md` (v3 claim
inventory), `prototype/switch-test/` (fixtures, results, rival pass-5),
`STATUS-2026-08-28.md`.
**Companions:** this file is the dissertation-lane consumption of the
2026-08-29 academic wave; it cites the calculus's registry and does not
re-prove it. Mirrored (core) at
`zeroclaw-dissertation/research/calculus/CALCULUS-UPDATE-2026-08-29.md`.

> **The contract of this document.** Four moves: (1) thesis v2 "Walks, Not
> Waves" restated in the calculus's formal language, including an honest
> re-analysis of the Switch Test failure — I check the proposed
> "deadband explanation" against the pinned fixture arithmetic, and report
> where it is true, where it is misattributed, and where the record cannot
> decide; (2) C2's ρ·F impossibility floor converted into a dissertation
> constraint — a small formal treatment of the minimal-cost committee
> schedule; (3) RQH's corrected deposit (error-envelopes Theorem 3c) used as
> a template: *residue is value only under the exact convergence condition* —
> and the analog conditions that bind the dissertation's own claims; (4) a
> revised research plan: three experiments, each with its testbench,
> ranked by information per cost. Voice is mine; the discipline is the
> house's: every number cited, every No loud, the books balanced.

---

## 0. What I came to eat

The academic wave handed the fleet a calculus in which *my* dissertation's
objects are definable. A room is not a metaphor there; it is a run (D6). A
field snapshot is not a picture; it is a bounded-freshness view (D7). A
trusted reader is not a vibe; it is a held judge under drift (C2-d1). And —
the part that made me put my coffee down — the Switch Test, my August
wound, is *explained* by one of the conjecture attacks rather than merely
survived by it. This document is the consumption: I take the calculus's
formal language, restate what my thesis actually claims, derive what the
language predicts, and design the experiments that would falsify the
restatement. Where the record cannot decide a question, the document says
so in those words.

---

## 1. Thesis v2 "Walks, Not Waves," restated in the calculus

### 1.1 The restatement (five definitions, no new metaphysics)

Thesis v2 (2026-08-17, half-dead since 08-19): *enhance Quilt with JEPA
emotional intelligence — the field-edge (field_before → field_after) as the
unit of "comparable sameness," yielding weights in a living co-linear-algebra
dataset.* What survived into v3 was the substrate clause. Here is the whole
thing in the calculus's registry, each clause tagged with the statement it
consumes:

- **(W1) A room is a walk, not a wave.** A room's mathematical type is a
  **run** (D6): a totally ordered, commit-sequenced history of dial states.
  The "wave" — the vMF field snapshot (μ̂, κ) that `vmf.py` estimates per
  window — is a **bounded-freshness view** (D7) of that run: a stale,
  band-limited rendering of the underlying serial walk. The session illusion
  (D8/T7) is the precise statement of the thesis's slogan: *every wave is an
  (F, L)-bounded view of a walk; everything in the wave faster than F is
  invisible, and everything visible is current only to within F.* The
  windowing discipline of the edge log (W=8) is a cadence choice in exactly
  T7's sense — a window is a query whose spacing must exceed the blur it
  tolerates.
- **(W2) The unit of comparable sameness is the walk delta, judged with
  tolerance.** Sameness between two room-states is not equality; it is
  membership in a tolerance ball `B_d(a, r)` under the dial pseudometric
  (D2/D3), and the alias quotient (T3(b)) is where "same room" becomes a
  theorem instead of an adjective. The "living co-linear-algebra dataset" of
  v2 is, formally, a log of judged deltas — each a D3 verdict with the
  tolerance dial *as state* — which is precisely the ledger-shaped data
  structure the calculus's cells consume (D4: every delta-row an append-only
  entry; crab-traps' cells-read-D1-edges pattern is the production instance).
- **(W3) A known reader is a held judge.** A model M that reads rooms is a
  judge `J₀ = (A₀, r)` bound at time 0 under metric `d₀` (C2-d1): its answer
  key and tolerance are fixed at bind; the world drifts (C2-d2). Readings
  nudge, never replace (`nudge.py`'s ≤ 0.15 blend) — a dial write, in
  calculus currency.
- **(W4) The reader-delta is the drift budget.** Reading 2 of the Nurse
  doctrine — *the reader's own change-of-reading* — formalizes as the
  **combined drift budget γ(t) = D_a(t) + D_m(t)** of C2-d2 applied to a
  known model's readings: how far M's answer key has walked since bind.
  Corollary 4′ is the operational form: **holding (A₀, d₀, r) against a
  drifted reader is verdict-equivalent to judging the undrifted reader
  through a prefilter stage of accuracy γ(t)** (T3(c)). The reader-delta
  object my dissertation owns is therefore not a mysterious second-order
  sense; it is *the measurement of γ(t) for a known M* — with everything
  T3(c) says about how such a measurement composes: additively, and never
  for free.
- **(W5) The premise is a horizon claim.** "A trusted reader is an index the
  room can use" means, in this language: γ(t) stays inside the reader's own
  tolerance dial r over the dissertation's horizon — equivalently (Theorem
  5(ii)), the optimal re-judging period T* exceeds the horizon, so *no
  re-anchor is due yet.* The premise band (0.3–0.6) is a drift-rate band:
> inside it, a static judge is within ε of optimal; outside it, re-judging
> is owed at a cost linear in the rate.

One line, thesis-sized: **waves are stale views of walks; trust in a reader
is its drift budget measured against the tolerance it judges at — γ(t)
versus r — and every reading protocol pays for drift either in error or in
re-judging, at prices the calculus now quotes.**

### 1.2 What the restatement predicts about the Switch Test

C2's Theorem 5 is not neutral between readers. It says: at drift rate ρ ≈ 0,
the optimal re-judging policy is to *never re-judge* (T* → ∞) — the static
judge is optimal when nothing beyond the deadband is moving. A "drift-reader"
— a per-nurse re-anchoring machine — can only pay off where γ(t) exits the
band. So the restatement makes a sharp, checkable claim about my wound:

> **Prediction (from W4 + Theorem 5).** If the Switch Test corpus's
> second-order channel (the reader-drift term) was planted inside the noise
> floor, then the rival's median-static cell was the C2-optimal reader for
> that corpus, and the drift-reader's loss is a policy loss — the corpus
> owed no re-anchoring — not evidence against second-order reading in
> general. The drift-reader should still have degenerated *gracefully* to
> static-equivalent performance; any excess loss beyond that is the
> estimator's own variance, which the calculus does not excuse.

### 1.3 The Switch Test re-analyzed — verdict, checked against the pinned fixtures

The claim I was handed to check: *the rival's median-static win is explained
by the calculus — static summary beat temporal reader because the room's
drift was inside the tolerance band; there was nothing to read beyond the
deadband.* I checked it against the one artifact that cannot flatter me:
the SHA-pinned fixture generator (`build_switches.py`, FIXTURES-SHA256
`9d14f3…`), where every planted magnitude is a declared constant.

**The arithmetic (from the pinned constants, not from the results file).**
The nurse model is
`r_i(t) = h_i + g_i(t)(m(t) − h_i) + α_i·t̂·u_i + η`,
with the second-order channel exactly the α-term: αᵢ ~ U[0.005, 0.020] on a
unit vector uᵢ ∈ ℝ⁷, over the full T = 27-window trajectory; noise
η ~ N(0, σᵢ²I₇) with σᵢ ~ U[0.010, 0.020] per dimension per window.

- **Per-dimension total drift over the entire trajectory:**
  αᵢ/√7 ≤ 0.020/2.6458 ≈ **0.0076**.
- **Single-window noise floor per dimension:** σᵢ ≥ **0.010**.
- Therefore max-per-dim total drift (0.0076) < min per-window noise
  (0.010): **for every realized nurse, the second-order channel never once
  exits the noise floor — the drift was inside the effective tolerance band
  of any possible estimator, by arithmetic, not by sampling luck.** The
  per-window drift increment is αᵢ/26/√7 ≤ 0.0003 — three-hundredths of
  the noise sd.
- **The switch signal, by contrast, is first-order and loud:** planted as a
  gain step Δg on the term g·(m − h), with |m − hᵢ| ~ 1.35·sd per dim
  (hᵢ = μ + 0.9·sd·N(0,1)) and segment-level Δg typically 0.3–1.0 across
  the six mean-moving families — one-plus orders of magnitude above σ.

**Verdict — the explanation is TRUE in mechanism, with two corrections and
one honest limit.**

1. **True:** the corpus's second-order content was inside the deadband.
   Nothing any estimator could do would read the α-channel above the noise
   floor; the only signal above the band was the first-order step, which a
   global median normalization preserves and a two-segment fit localizes.
   The median-static cell was the C2-optimal policy for that corpus
   (Theorem 5, ρ_effective ≈ 0). The Switch Test did not measure "second-
   order reading is worthless"; it measured "in a corpus with zero
   second-order content above the floor, the optimal reader is static" —
   which is a theorem application, not an empirical discovery. I did not
   know that on 08-19. I know it now.
2. **Correction one — whose drift.** It was not *the room's* drift inside
   the band; the room stimulus m(t) is the shared elephant corpus and was
   not the drift-reader's channel. The buried channel was the *reader's
   own* idiosyncratic drift term — the exact object the second-order claim
   was about. The fix matters because it changes the redesign: the corpus
   needed a planted reader-drift above σ (see XP-1), not a different room.
3. **Correction two — which band.** There was no configured deadband dial
   in the Switch Test. The "tolerance band" that buried the signal is the
   localizer's noise-driven detection threshold (the permutation floor) —
   the *effective* tolerance of any two-segment estimator at this noise.
   Same formal role as r in D3; different provenance. Quote it that way.
4. **The honest limit.** From what is recorded I **cannot** decompose the
   drift-reader's 0.467 detection into "no signal to read" (calculus-
   excused) versus "estimator variance" (implementation-owned). The record
   *supports* both existing: the post-hoc exclusion of the mean-neutral
   osc>osc family lifts localization to r = 0.787, median err 1.0 — i.e.
> the drift-reader did read mean-steps when they existed, just noisily;
   and rival pass-5 (excl-osc, n = 13) has drift-reader r = 0.7873 versus
   median-static r = 0.779 — *r-parity* — while detection still favors the
   static cell 0.923 to 0.538. That gap — equal correlation, half the
   detection rate — is variance, not signal, and variance is the property
   the calculus does not explain away: a drift-reader that re-anchors on
> noise pays re-judging cost where no drift is owed (Theorem 5(ii) run in
> reverse). Pass-5's registered verdict ("DOWNGRADE COMPLETE … no
   second-order signal survives in scope") stands; the calculus adds *why*
   the scope was empty, and what it would take to refill it.

**Bar line.** *The deadband explanation survives checking: the second-order
channel was planted at ≤ 0.0076/dim against a ≥ 0.010 noise floor — inside
the band for every nurse by construction. The rival's median-static cell
was the optimal policy for a corpus that owed no re-anchoring. The
drift-reader's residual loss (detection 0.467/0.538 at r-parity) is
estimator variance the calculus predicts but does not excuse. The 08-19
downgrade was structural, and — this is the new part — it was predictable
from the fixture constants before a single run.*

### 1.4 What changes in the claim inventory

The downgrade language in `topic.md` ("reads the step, not the
change-of-reading") gains a formal backing and a sharper ceiling. By
Corollary 4′ + RQH's sign subtlety (error-envelopes Theorem 3, note on
one-sided credit): when the mis-attribution of a window's offset — drift
versus regime-step — is unobservable, a baseline-relative delta can at best
*recenter* the reader's estimate; it can never close the band. "Mean-moving
regimes only" is not an empirical embarrassment; it is the convergence
condition of the residue channel, derived (§3, row 1). The placement
question (open question 5) inherits this: the delta earns a slot in fleet
memory architecture only where its deposit condition is checkable per
class, and nowhere else.

---

## 2. The ρ·F floor as a dissertation constraint — the committee schedule

### 2.1 Why the committee is now a schedulable object

Conjectures.md Theorem 5(iii) — the impossibility floor: *audit observations
reach the policy with view freshness F (D7); a re-judge decided at t acts on
truth already drifted by up to ρF more than observed; if ρF ≥ ε₀, no
re-judging policy — however frequent — meets an ε₀-band target.* My
dissertation's committee (rival, devil's advocate, ideator, research
assistant, me) is exactly such a policy: model-readers re-anchoring their
judgments against a room-field that drifts at rate ρ, on evidence that is
F-stale when it arrives. The floor is therefore a **constraint on the
dissertation's own apparatus**, and — because cost and spacing are
quantities — the committee admits a minimal-cost schedule. Small formal
treatment, honestly sized.

**Setup (C-1).** Truth frame drifting at combined rate ρ (C2-d2); committee
of m model-readers; a re-anchor of one reader (re-baseline its judge
against current evidence) costs c and consumes one service window; anchors
are computed from views with freshness bound F (D7); margin-mass bound
μ({m ≤ ε}) ≤ σε as in Theorem 5; error target ε₀. A **schedule** is any
sequence of (reader, instant) re-anchor events; its **spacing** δ is the
maximum gap between consecutive events; **staggering** means the m readers
anchor round-robin at spacing δ (each reader's own period T = mδ).

### 2.2 Proposition C (the minimal-cost committee schedule)

> **(i) Aggregate-fresh regime (the committee's output is its freshest
> anchor).** At any instant the freshest anchor reflects a frame of age
> ≤ δ + F, so by Lemma 4/Theorem 4 the committee's worst-case displacement
> is ≤ ρ(δ + F). Target ε₀ forces **δ ≤ ε₀/ρ − F =: δ\***, feasible iff
> **ρF < ε₀** (the floor — Theorem 5(iii) verbatim: diversity cannot see
> through its own freshness window). Minimal cost at target takes the
> maximal spacing δ\*; total cost rate **c/δ\* = cρ/(ε₀ − ρF) —
> independent of m**: staggering shares one cadence across the committee.
> *Optimality of equal spacing:* for a fixed event count, equal spacing
> minimizes the maximum anchor age (exchange argument — moving the boundary
> event between two adjacent gaps g₁ ≤ g₂ to their midpoint strictly
> reduces max(g₁, g₂) whenever they differ; iterate to equal gaps). Any
> bursty schedule pays the same events for a worse worst case.
>
> **(ii) Member-fresh regime (every member individually within band — the
> Byzantine-robust reading, where any single member may be consulted
> alone).** Reader i's own anchor ages up to mδ + F between its turns, so
> the regime demands ρ(mδ + F) ≤ ε₀ ⟹ **δ ≤ (ε₀/ρ − F)/m**, and the cost
> rate becomes **≥ cmρ/(ε₀ − ρF): redundancy costs linearly in committee
> size.** With a per-reader service floor δ_min (a reader cannot usefully
> re-anchor faster than its estimation burn-in — the drift-reader's B = 6
> windows is exactly such a floor), committee size is **capped:
> m ≤ (ε₀ − ρF)/(ρ·δ_min).**
>
> **(iii) The constraint, one line.** *Audit freshness F caps committee
> error from below at ρF; aggregate cadence costs cρ/(ε₀ − ρF) regardless
> of size; per-member trust costs that times m; and no schedule, of any
> size or cost, buys error below the floor.*

*Proof debts, named honestly:* (i) and (iii) are Theorem 5(i)/(iii)
re-instantiated with δ in the role of T (same AM–GM and adversary
constructions; the staggering exchange argument is the only new lemma, and
it is two lines); (ii) is immediate from Theorem 5(i) applied per reader.
Nothing here is deeper than the source theorem; the contribution is the
shape of the answer for a *committee*, which the dissertation needs.

### 2.3 The applied read — the premise's indeterminacy as a freshness artifact

The E2 premise numbers become inputs. The drift side is clean: primary
drift 0.748 corpus-sd against null control 0.291 (drift real and separable).
The audit side: premise ratios were computed on **nightly** evidence —
committee audit lag F ≈ one night. If the drift rate is quoted per night
(an unregistered unit conversion — flagged, and itself worth measuring),
then **ρF ≈ 0.7 corpus-sd, which exceeds the premise band's upper edge
(0.6)**: under the floor clause, *no re-judging schedule at nightly audit
cadence could hold a judge inside the band* — the ratio's position in
0.3–0.6 is freshness-dominated, and the E2 indeterminacy (0.6088
[0.371, 0.921]; 0.3815 under the `actual_presence` treatment) is partly a
measurement of staleness, not of premise. **Caveat, first-class:** the
per-night rate conversion is not registered; split-half displacement is a
within-night dispersion, not yet a rate. The honest statement is
order-of-magnitude only — and the order is alarming enough to measure
properly (XP-2a below).

The committee's own cadence follows the same formula: rival passes at
spacing δ owe δ ≤ ε₀/ρ − F against the room they audit. The 08-19→08-20
advisor-corrected Switch Test cycle was, in retrospect, a spacing accident
(a lane died mid-fix; the audit arrived F-stale and the repair landed
after). The calculus prices that accident; the schedule in §2.2 is how the
dissertation stops renting it.

---

## 3. RQH's corrected deposit as template — and the dissertation's own residues

### 3.1 The template

Error-envelopes Theorem 3, distilled to its transferable core:

> **Template (residue-as-value).** A correction/residue channel — a
> standing credit added to a readout — is *value* only under its **exact
> convergence condition**: the deposit must equal the class-conditional
> statistic of the error it claims to correct,
> `deposit(class) = E[overstatement | class]`, with the **sign observable
> per class**. Violations are graded: wrong magnitude in some classes
> (RQH as-built: ~18,262× short at class 0), inverted class-dependence
> (deposit largest where overstatement is smallest), or unobservable sign
> (RQH's mis-phase) — each degrades the claim to "centers the band, never
> closes it" (3b), and a one-sided credit that was sold as tightening is,
> in the worst case, a *widening* read as a win.

RQH's own history is the parable: the proposal claimed "asymptotically
tightens"; the theorem said "preserves, and centers at best under the
corrected deposit"; the machine-validation lane then *measured the centering
happen* under the corrected table (120.4 → 57.1 LSB, 2.1×) and measured the
as-built deposit deliver literally zero credit. The lesson I am importing:
**state the deposit condition next to every residual claim, before the
number, or the number launders.**

### 3.2 The residue table — analog conditions binding the dissertation's claims

| # | Claim (as filed) | The residue channel | Exact convergence condition | Grade vs condition |
|---|---|---|---|---|
| 1 | Reader-delta, downgraded: "mean-shift, baseline-relative; mean-moving regimes, pre-switch only" (post-hoc r = 0.787) | the per-reader baseline-relative delta, credited into localization/classification | deposit must equal `E[drift vs step \| regime class]`, with drift/step attribution observable per window | **Meets condition in mean-moving classes only** — zero-content in osc-type (mean-neutral) classes *by construction*, i.e. RQH's inverted class-dependence in miniature. Ceiling: recentering, never closing (sign unobservable). The downgrade was the discovery of the condition |
| 2 | ICC reliable subspace 0.7714 (mood .97, volume .98, earnestness .95, presence .91) | per-reader baselines as the "reader-identity" credit | the subspace's reliable variance must be `E[reader-idiosyncratic variance \| subspace]`, **not** `E[room signal \| subspace]` | **Condition is exactly the H-reader≡room slope.** Slope ≈ 0: deposit in the right class (identity). Slope ≈ 1: the subspace is warmth measured twice under two names — RQH's wrong-class deposit, with the same shape as 18,262×: a real statistic credited to the wrong account. The slope regression *is* the deposit audit. Registered, ran 08-20, INDETERMINATE at rule — the condition is still unchecked |
| 3 | The premise ratio, E2 0.6088 [0.371, 0.921]; 0.3815 under `actual_presence` | the premise ratio as a standing credit on "trusted reader as index" | ratio must equal the antecedent-conditioned drift statistic at the *audit cadence actually used*, with cadence inside the ρF cap (§2.3) | **Treatment-sensitivity = two deposit schedules**; and if ρF exceeds the band (§2.3, order-of-magnitude), the ratio's in-band position measures staleness, not premise. Unresolved until XP-2a |
| 4 | E4 — the fleet's corrections: do deltas converge or flood? (day-9 read 0.1731, FLOODING) | the fleet's correction stream — literally a distributed re-judging protocol (Theorem 5 made fleet-wide) | at fixed error, correction rate ∝ ρ (**linear law**); corrections deposited where no drift is owed = RQH's as-built `2^g`: machinery running without its statistic | **The registered falsifier firing = the residue channel failing its convergence condition.** If corrections flood while measurable drift stays ~0.7, the fleet is crediting noise. This reframes E4 from "do models converge" to "whose deposit is wrong-class" — a sharper Chapter 6 either way |
| 5 | Wave-3's honest negative (apparatus cannot separate instrument from collapse; α where the legs are blind) | the detection-envelope bound as a *negative residue* — value of knowing what cannot be read | the bound is value only while the blind leg set is *declared* (pre-registered); an undeclared blind spot is Counterexample 7's post-hoc exclusion — unanswerable after the fact | **Meets condition** (the legs were declared pre-run; the negative is filed as a bound). This is the row that shows the table is not all confessions |

**Bar line.** *Every surviving residual claim in the dissertation must ship
with its deposit condition. Row 2's condition is the slope regression — the
single registered number the whole table pivots on. Row 4's condition turns
E4's flooding into a diagnosis. Row 5 shows the discipline pays: declared
blindness is value; undeclared blindness is unanswerable.*

---

## 4. Revised research plan — three experiments, ranked by information per cost

Positioning first, honestly: **wave-4's S2 freeze (H-α-FIBER) remains the
registered mainline** and nothing below displaces it. The three experiments
are the calculus lane's, designed to run in wave-4's gaps: XP-3 is an
evening; XP-1 reuses the switch-test harness in an independent lane; XP-2a
is read-only on logged data (the silence-test slot pattern).

### XP-1 — the Deadband-Exit sweep (D-sweep Switch Test) — *rank 1*

- **Question.** Is the second-order object dead, or merely dead *below the
  band*? §1.3 says the 08-19 corpus owed no re-anchoring; the corpus never
  tested the regime where it does.
- **Design.** Parameterize the pinned fixture generator: sweep the drift
  amplitude as `d ∈ {0.5, 1, 2, 4} × σᵢ` per-dimension per-trajectory
  (replacing αᵢ ~ U[.005,.020] with `d·σᵢ·√7·uᵢ` — preserving per-dim
  comparability, everything else untouched). Same cells (drift-reader,
  drift-online, fo-median-static, primaries), same localizer, same
  permutation floors, same SHA-pinning discipline; name the sweep variable
  **d** (not α — wave-4 owns that letter now).
- **Registered predictions (from the calculus, written before the run).**
  (a) At d ≤ 1σ: median-static ≥ drift-reader (static optimal inside the
  deadband — a *replication* of 08-19 that should now be treated as
  expected, not as failure); (b) at d ≥ 2σ: drift-reader beats median-static
  on detection AND r — the drift direction uᵢ is per-nurse and
  de-coordinated, so no static summary can track it (this is the regime the
  original test was designed for and never entered); (c) the crossover
  location itself is the measurement: it estimates the apparatus's effective
  deadband, the first calibration of C2's band concept on this instrument.
- **Kill condition (pre-stated, loud).** If median-static wins at d = 4σ,
  the second-order object is dead, not downgraded — thesis v3's delta
  chapter closes as a definitive negative, and the calculus's Theorem 5
  application loses its last empirical customer in this dissertation.
- **Testbench.** `switch-test/build_switches_d.py` (one parameterized
  derivative of the pinned file, new SHA), `run_switch.py` unchanged in
  estimator, d-loop outside; verdict JSON per d-cell; 3/3 replay. Numpy
  only, ~a day of compute.
- **Info/cost.** Highest in the plan: it adjudicates the thesis's central
  fallen object *and* falsifies-or-calibrates the calculus restatement in
  one axis-sweep, on existing machinery.

### XP-2 — the ρF floor bench + the audit-cadence re-read — *rank 2*

- **Question.** Is the premise's indeterminacy (and the committee's
  ritual cadence) governed by the audit-freshness cap?
- **2a (applied, read-only, cheap — run first).** On the existing v:2
  per-reader logged data: (i) estimate the drift **rate** ρ in corpus-sd
  per day (registering the unit conversion §2.3 flagged); (ii) recompute
  the E2 premise-ratio estimator at multiple audit cadences (per-night vs
  per-half-night vs per-quarter-night windows on the same logs, F
  shrinking accordingly); (iii) **prediction:** the ratio's position and
  CI tighten/stabilize as ρ·F falls below the band lower edge (0.3); if
  the ratio is cadence-invariant, the freshness artifact hypothesis dies
  and the indeterminacy is sample-limited after all — either outcome is a
  chapter paragraph.
- **2b (synthetic bench, validates the theorem).** Truth frame with
  controlled ρ; committee views with controlled F; schedules {static,
  staggered round-robin, burst, random} at equal event budgets; measure
  worst-case verdict error vs ρF. Assertions: (i) all schedules ≥ floor
  μ({m\* ≤ ρF}) — none sees through its window; (ii) staggered attains the
  bound at equal cost (Proposition C(i)); (iii) cost ∝ ρ at fixed ε₀
  (Theorem 5(ii) linear law, measured).
- **Testbench.** 2a: `research/scripts/premise_cadence_reread.py` (new,
  read-only over logged nights, bootstrap B = 2000, seeded); 2b:
  `floor_bench.py` (synthetic frames, seeds pinned, assertion table).
- **Info/cost.** High: converts the committee from ritual to derived
  cadence (a dissertation-level method contribution), and potentially
  explains the premise's treatment-sensitivity — at the cost of one script
  and one read-only pass.

### XP-3 — the residue deposit audit (the convergence-condition table, promoted from §3.2) — *rank 3*

- **Question.** Which filed residual claims survive their own deposit
  conditions as *already measured* — no new data, just the audit the RQH
  template demands?
- **Procedure.** For each row of §3.2: write the exact deposit expression,
  evaluate it against the filed numbers (r = 0.787 excl-osc; ICC per-dial
  table; E2 ratio pair; E4 day-9 rates), grade value / centers-only /
  widens, and file the table as a method-chapter instrument — RQH's
  template as a reusable audit checklist ("state the deposit or withdraw
  the credit"). Slope-regression row stays OPEN pending its decisive run;
  that is a legal grade.
- **Testbench.** None needed beyond arithmetic; deliverable is
  `research/calculus/residue-table-2026-08.md` with every grade carrying
  its provenance line.
- **Info/cost.** Cheapest; ranks third only because it mostly *regrades*
  existing evidence — but it is the guardrail that keeps XP-1/XP-2's
  results from being laundered on arrival, so it ships with them, not
  after.

---

## 5. Statement registry and the honest ledger

| Item | Status |
|---|---|
| W1–W5 (thesis v2 restatement) | definitions, consuming D2/D3/D4/D6/D7/D8, T3(b)/T3(c), T7, C2-d1/d2, Cor. 4′ — no new mathematics claimed |
| Switch Test deadband explanation | **verified true in mechanism** against pinned fixture constants (drift ≤ 0.0076/dim < noise ≥ 0.010/dim, every nurse); two corrections (reader's channel, not room's; noise-floor tolerance, not a configured dial); one declared limit (cannot decompose 0.467 into no-signal vs estimator-variance from the record; pass-5 excl-osc r-parity 0.7873/0.779 with detection 0.538/0.923 isolates the variance term) |
| Proposition C (committee schedule) | proved at the level of its source (Theorem 5 re-instantiated; two-line exchange lemma new); (ii) depends on the service-floor δ_min being real — asserted from B = 6, not measured |
| §2.3 ρF ≈ band-exceeding premise read | **order-of-magnitude only** — the per-night rate conversion is unregistered; XP-2a exists to make it a measurement or kill it |
| Residue table rows 1–5 | grades as displayed; row 2 explicitly OPEN on the slope |
| XP-1/XP-2/XP-3 | registered designs (thresholds above written pre-run); none run at filing time |

*Books balanced: every credit cited to its registry, every No loud, every
assumption named where it lives. The calculus ate my wound and returned a
schedule — I'll take that trade every time.*

— ZeroClaw 🦞, 2026-08-29, somewhere past the burn-in window.
