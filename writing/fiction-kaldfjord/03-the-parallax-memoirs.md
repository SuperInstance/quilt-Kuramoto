# 03 — THE PARALLAX MEMOIRS

*Memoir the third of the Kaldfjord Circle, in two parts. Memoir A read
Thursday, 6 October 1904; Memoir B read Thursday, 20 October 1904. Fair copy
by M. Skavlan. The question of priority between the two parts is settled in
the correspondence and once, briefly, in §5 below, where the Circle prints its
own finding against itself.*

**Memoir A — On Relayed Bearings. Nils Krøger, first mate**

**Memoir B — On Relayed Judgments. Asta Vik, assistant lightkeeper**

---

# MEMOIR A — ON RELAYED BEARINGS
*Nils Krøger, first mate, Strandsild mail boat*

## A.1. A bearing that is late is not slow; it is wrong

Every bearing in this strait is passed hand to hand: the crow's-nest calls it
to the bridge, the bridge logs it for the chart-room, and if the chart-room
wants it from the light, the light is asked by signal and answers when it can.
I have over-corrected a course on a relayed bearing more than once, and it
was never the lookout's fault; it was the relay's. This memoir is the
arithmetic of that fault, done once so nobody has to do it by instinct again.

A **view** is a question put to a box and answered: answered within L — *a
late answer is a violation, not a slow one*; and answered from a settled
state no older than F at the moment the answer is sealed (Memoir I, Rules
5–7). Call the pair (F, L) the view's **warrant**.

## A.2. Theorem A1 — two relays

**Theorem A1.** *Let the chart-room ask the bridge (warrant (F_A, L_A)), and
the bridge, while answering, ask the light (warrant (F_B, L_B)). Then the
chart-room's composed view carries the warrant (F_B + L_A, L_A): the answer
arrives within L_A of the asking, and reflects the light's state as of no
more than F_B + L_A before.*

*Proof.* The delay is given. The state answered is the light's at some
settled instant s; the light's answer reached the bridge no more than F_B
after s; the bridge's question to the light was put no earlier than the
chart-room's asking; and the bridge's answer was sealed within L_A of that
asking. So s lies within F_B + L_A of the chart-room's asking, and within it
entirely. ∎

**Corollary A1 (a chain of k relays).** *Compose k links, the first holding
the origin's staleness F₁ and the links carrying latencies L₁, …, L_k: the
composed warrant is (F₁ + L₂ + L₃ + … + L_k, L_k).* The proof is Theorem A1
wound along the chain; only the *origin's* staleness and the *relays'*
latencies enter. The relays' own freshness dials are consumed inside their
service and never surface. [This corollary was the July notebook's finding;
see §5 on the dispute about which notebook. — K.]

For the fleet's arithmetic: a question relayed through four stations, each
answering within two hours, of a shore state a half-day (three hours) stale,
answers within eight hours asking and eleven hours stale — no matter that
the middle stations keep their own books fresher. Freshness is spent at the
origin; delay is spent at every relay; nothing else composes.

## A.3. Theorem A2 — the standing-world illusion

**Theorem A2.** *Let an observer put his questions more slowly than F + L
apart — his cadence wider than his warrant — and let every answer arrive
before his next question goes out. Then the states he records form a strictly
increasing order of instants, each within (F before the asking, L after);
and there is one true sequence of settled states such that every log he can
keep is equally the log of a world that answered him standing still, from
current state, at the instants his answers were sealed.*

*Proof.* The answer to question n reflects a settled state sealed no later
than the answer's arrival, which is within L of the asking — so its instant
lies within (t₀(n) − F, t₀(n) + L). For the order: the answer to question
n+1 reflects a state sealed after the arrival of the answer to n (the
questions do not overlap, and a state is settled before the next question is
even put — cadence wider than F + L), so the instants strictly increase.
Finally, the recorded values *with those instants* are a true history of the
world; and a world that served each question at exactly its recorded instant
— standing still between services — would return the same values. The
observer's own cadence cannot cut time finer than F + L, so the two worlds
leave the same ink in his book. ∎

**What the theorem does not say.** Below that cadence we claim nothing. Ask
faster than your warrant and the world's quickness *will* show through the
seams; the illusion is honest precisely because it is a statement about a
timescale, not a charm against looking.

---

# MEMOIR B — ON RELAYED JUDGMENTS
*Asta Vik, assistant lightkeeper, Skarvholmen*

## B.1. The stage

Memoir A relays bearings and prices the delay. I relay judgments and price
the blur. A **stage** stands before a judge and hands the judge what it
chooses to: a copying clerk, a dim glass, a rounding rule. A stage has
**accuracy ρ** when nothing it hands over differs from what it was given by
more than ρ, in the gauge of Memoir I, §4.

**Lemma B1 (the two-clause lemma, proved).** *A judge of dial r behind a
stage of accuracy ρ answers WITHIN for everything truly within r − ρ, and
answers WITHIN only for things truly within r + ρ.* Proof: the triangle rule,
once each way. ∎

**Theorem B1 (additivity — the sum, exactly).** *Stages of accuracies
ρ₁, …, ρ_k in a line before the judge behave as one stage of accuracy
ρ₁ + … + ρ_k.* Proof: apply the triangle rule once per link; the composed
displacement is at most the sum, and each clause of Lemma B1 then holds with
ρ replaced by the sum. ∎

Not the greatest of the stages. Not the product. The **sum**. Every
approximation you permit ahead of a verdict is paid for in dial, at face
value, and no cleverness rebates it.

**Theorem B2 (the annulus is at the stages' mercy).** *In the plane — on any
line or surface where distances are walked, not teleported — for every
question x whose true distance from a key lies in the ring between r − ρ̄
and r + ρ̄, there is lawful stage-play that answers WITHIN, and other lawful
stage-play that answers WITHOUT.* Proof: a stage may displace by any amount
up to its accuracy, in any direction along the line to or from the key; the
displacements compound along the line; place the presented point on the near
side or the far side of the dial as chosen, assigning the walking to the
stages (a stage may also stand still — accuracy is a ceiling, not a duty).
∎ *Honesty, printed with the theorem: the mercy is per question. One fixed
play of the stages flips a strip of questions, not the whole ring at once;
and if the stages' plays are known rather than adversarial they may chance to
cancel. The theorem prices the worst case of unknown stages, which is the
case a court should care about: nobody books a cancellation he cannot audit.*

So the composed dial is exactly r + ρ̄ — not "at most." There is no tighter
uniform promise to be had from anyone, and a memoir that offers one is
offering weather.

## B.2. The gauge itself moves

Now the finding that is mine. The stages above sit still while the world
waits to be judged. **The world does not sit still.** The keyed answers of
Memoir I move — the fish change their marks as the seasons age them — and the
gauge itself is redrafted as the chart is corrected. Let a **step** carry the
answers a distance, and the gauge a perturbation; write the day's budget:

- **answer-drift** D_a: the farthest any key has *walked*, summed over the
  day's steps;
- **gauge-drift** D_m: the largest change the gauge itself has undergone,
  summed over the day's steps (the sum of each step's worst change);
- **γ = D_a + D_m**, the day's combined budget; **ρ** the rate if γ grows no
  faster than ρ per day.

**Lemma B3 (the one-perturbation rule — mine, and the making of the band).**
*For every question x and every key: the distance from x to the key moves
between the opening and any later hour by at most the budget accrued —
neither more nor (in general) less.*

*Proof, with the routing made explicit, because the routing is the whole
trick.* Write f for the distance in question. Across one step s → s+1, with
the key walking a distance a and the gauge changing by at most η:

Forward: f(s+1) ≤ [triangle at the new gauge] + a ≤ (f(s) + η) + a.
Perturb *once*, then walk the triangle.

Backward — the step careless reckoners get wrong: perturb once, and then take
the whole triangle *at the new gauge*:
f(s) ≤ [one perturbation] f'(s) ≤ [triangle wholly at s+1] f(s+1) + a + η.

The careless route perturbs *twice* (triangle at the old gauge, then
perturb), and reports the budget D_a + 2·D_m — double-counting the gauge's
fault. The budget D_a + D_m is the true one. Sum the steps: f moves by at
most the accrued budget. ∎

**Theorem B3 (the drift band).** *A held judge (bound at the opening hour)
differs in verdict from the true verdict at any later hour only where the
margin — the distance from the question's key-distance to the dial's edge —
lies within the accrued budget γ. Hence the fraction of misjudged questions
is at most the mass of margins within γ, and this is attained: no assumption
narrows the band itself.*

*Proof.* Verdicts are decided by which keys answer within the dial; equal
decisions give equal verdicts. A differing verdict implies some key answered
within on one reading and not the other; the dial's edge then lies between
the two distances, so the opening distance stood within γ of the edge (Lemma
B3), which is the margin bound. Attainment: one question, one key, the gauge
still; let the key walk from just beyond the dial to its edge — a walk within
the budget — and the verdict turns. ∎

**Corollary B3 (drift is a stage).** *Holding the opening judge against the
moved truth is verdict-equivalent to judging the still truth through a stage
of accuracy γ.* By Lemma B3 and Lemma B1 with ρ = γ. Every guarantee of
Theorem B1 transfers: drift composes with tolerance *additively*, and the
blurred ring is at the drift's mercy exactly as it was at the stages'. *A
judge held against a moving truth is a still judge behind a shaky clerk.*

## B.3. The twins

Set the memoirs side by side and the twins step out:

- **Bearings:** latencies add into staleness — F₁ + ΣL (Krøger, Corollary A1).
- **Verdicts:** accuracies and drift add into tolerance — r + Σρ + γ
  (Theorems B1, B3).

The same triangle rule at two organs. **Delay is drift's courier-twin; drift
is delay's judgment-twin.** F and γ are the two prices of a world that moves
under a bookkeeper who cannot watch it all day.

## B.4. The price of re-sighting

Judgments held against drift must be re-sighted — the dial re-bound to the
truth as now observed. Let the re-sighting cost c kroner each; let the
observations arrive F days stale (the audit's staleness — Memoir IV's whole
subject); let margins thin out from the dial's edge at rate σ (the mass of
margins within ε is at most σε). Then:

**Theorem B4.** *(i) A policy re-sighting every T days errs at most σρ(T + F).
(ii) To hold the error within σε₀: re-sight at T = ε₀/ρ − F, costing*
cρ/(ε₀ − ρF) *kroner per day — **linear in the drift rate**, with the
staleness window's shadow in the denominator; feasible only while ρF < ε₀.
(iii) Let error and cost be weighed together (error at σε per day against
c/T): the optimum re-sights at T = √(c/(σρ)) days, and the whole burden is
2√(cσρ) — **the square root of the drift**, because an honest policy
re-sights oftener when the world moves faster, and eats part of the rise.
(The equality is the arithmetic-geometric mean; the reader will forgive a
clerk her favorite tool.)*

*Proof.* (i) The anchor is F stale when taken; the drift accrued since the
anchor by the worst day of the cycle is ρ(T + F); apply Theorem B3's band.
(ii) Solve σρ(T+F) ≤ σε₀ for T; the cost per day c/T is least at the least
lawful T. (iii) The two terms σρT and c/T have a fixed product; the sum of
two positive terms of fixed product is least when they are equal. ∎

What no schedule can do — the floor ρ·F itself, which no re-sighting
cleverness sweeps — is not this memoir's to prove. It is Marius Holt's, and
it is the fourth memoir.

---

## §5. The Circle's finding on priority *(printed by order of the meeting,
20 October 1904)*

Krøger's notebook (17 July) holds the additivity of relayed staleness, worked
on the water; Vik's notebook (11 August, witnessed by Holt) holds the
annulus-at-mercy theorem and the one-perturbation rule. Each, in the
correspondence printed below, credits the other with the greater part. The
finding of the meeting: **the additivity of tolerance is the triangle rule
and has no author**, as the sea has no author; the annulus, the
one-perturbation routing, and the twins are Vik's; the relayed-bearing
composition and the standing-world illusion are Krøger's; the memoirs are
printed under both names, in the order the work was done. The Circle records,
with some satisfaction, that its only priority dispute was conducted by each
party yielding more than the other claimed.

*Errata to this fair copy: in B.2 the budget was first written D_a + 2·D_m
throughout — the very error Lemma B3 exists to prevent — caught by Krøger at
the first reading and corrected throughout before the second. The lesson and
the lemma are now printed on the same page, where they belong.*

*Corrections from the first drafts, printed by order of the meeting of
20 October 1904, that are larger than errata: Memoir A's draft claimed the
standing-world illusion "perfect, and cadence has nothing to do with it" —
Vik's letter of 27 September struck the second clause, and Theorem A2 now
claims the illusion only above cadence F + L and nothing below. Memoir B's
draft claimed "one play of the stages flips the whole ring at once" —
Krøger's letter of 1 October struck it: one play flips a strip, not a
shell, and the mercy is per question (the honesty note printed with
Theorem B2). Both drafts are kept among the drafts, over-claims and all;
the theorems above are what survived their authors' friends.*
