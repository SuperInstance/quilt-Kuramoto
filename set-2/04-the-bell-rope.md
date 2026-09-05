# 04 — THE BELL-ROPE

*Memoir the fourth of the Kaldfjord Circle. Read Thursday, 16 February 1905.
Fair copy by M. Skavlan. Submitted to the Videnskabs-Selskab i Kristiania,
12 April 1905; refused 9 June 1905 (the refusal and its sequel are printed in
the correspondence and noted at §8). The verdict of the season followed in
October.*

**Marius Holt, bell-ringer**

---

## §1. The bell and the mail boat

I ring the bell on the hour, and the bell does not care what I believe. This
memoir is about what every ringer knows and no academy has yet written down:
**you cannot see through your own interval.**

The audit of the herring court [the fishery's reckoning of the shoals — Ed.]
comes by mail boat: whatever the court may wish to know of the truth, its
letters are F days old when they arrive. Meanwhile the truth — the shoal, the
weather, the price at Kristiania — drifts at some rate ρ per day. The court
re-sights its judgments when the letters tell it to. The question of this
memoir is: how good can those judgments be made, by any schedule of
re-sighting whatsoever, however clever, however costly?

The answer is a floor. Not a cost, not a difficulty — a floor.

## §2. The model, in six definitions

1. **The truth at an hour** is the whole frame of the judgment: the keyed
   answers and the gauge they are measured by (Memoir I, §4; Memoir III, B.2).
   The frame moves; the season is a sequence of frames.
2. **Drift budget and rate**, as in Memoir III: the answers may walk, the
   gauge may be redrafted; the combined budget γ grows at rate at most ρ per
   day.
3. **The letters.** The court's only knowledge of the truth at day t is the
   frames as they stood at days t−F and earlier. The letters are honest, full,
   and late. [The Circle's model takes the *fullest* letters F days stale; any
   thinner post strengthens every negative result below. — Ed.]
4. **A policy** is any rule whatever — fixed, looked-up, whimsical, thrown by
   dice — from letters received to acts of re-sighting. The act re-binds the
   judge to some frame the letters contain. Generality is the point: nothing
   below inspects the rule's cleverness, because nothing below needs to.
5. **Error** at day t: the fraction of questions (by their mass) on which the
   held judge's verdict differs from the true verdict that day.
6. **The dial's edge, margins, swept mass.** The margin of a question is its
   distance from the dial's edge (Memoir III, B.3). The **swept mass** at
   budget β is the mass of questions unambiguously answered that stand within
   β of *losing* that answer (or, counted the other way, of rejected ones
   within β of gaining one). The band swept by ρF is the currency of the
   theorem.

## §3. Three lemmas, proved

**Lemma 1 (the indistinguishability of agreeing seasons).** *Two seasons that
agree in every frame up to day τ send, for every day t ≤ τ + F, letters no
rule can tell apart; therefore every rule takes the same acts under both
seasons to day τ + F, and holds the same judge at τ + F.*

*Proof.* The letters at day t contain frames no later than t − F ≤ τ; the
letters are identical letter for letter; a rule is a function of its letters.
∎

This lemma is the memoir. Two seasons that agree on everything written down
are, to whoever reads the writing, *one season* — until the day the newer
season's truth finally reaches the post.

**Lemma 2 (every anchor is old).** *Whatever the rule, the frame it re-binds
to at day t stood at day t − F or earlier.* Proof: the letters at the day of
re-binding contain nothing newer. ∎

**Lemma 3 (drift since the anchor is error).** *Along any one season, at any
day, the held judge errs on every question whose verdict turns between its
anchor's frame and the true frame that day; and the budget accrued since the
anchor bounds how far from the dial's edge those questions can have stood.*
Proof: Memoir III, Lemma B3 and Theorem B3, read between the anchor's day and
today. ∎

## §4. The theorem

**Theorem (the floor).** *Fix a drift rate ρ and a staleness F. For every
rule whatsoever there is a season, drifting at rate at most ρ, on which the
rule's error at some day is at least the mass swept by a budget ρ·F at the
dial's edge — the band the world can cross inside one staleness window.*

*Proof (two seasons, one quiet, one quiet-then-moving).* Let the rule be
given; let the day of reckoning be t* and set τ = t* − F.

**Season A (quiet).** The frames stand still from the first day and never
move again.

**Season B (quiet-then-moving).** Identical to A through day τ — the same
frames, hence the same letters, hence by Lemma 1 the same acts by the rule,
whatever they are. Then, across the F dark days (τ, t*], the season moves the
gauge *outward from the answers*: every distance between a question and every
key grows by exactly ρ per day; distances between questions, and between
keys, stand still.

*The moved gauge is lawful.* Identity of a thing with itself and the symmetry
are kept by construction. The triangle rule: if the middle term of a triangle
is a plain question or a plain key, its two sides are unchanged and the rule
holds as before; if the middle term is a key, both sides grew by ρ, and the
third side grew by ρ or by nought — never by more than the two of them. The
perturbation per day is exactly ρ on the question–key distances and nought
elsewhere; the budget accrues to exactly ρF; the rate is ρ. [This
verification is printed at length in the appendix of the minute-book, at
Grønn's insistence; he was right to insist, and the reader who doubts the
middle-term case will find the three cases written out. — Ed.]

*The reckoning.* Under both seasons the letters to day t* are the same
letters, so the rule holds the same judge at t* (Lemma 1). Under Season A the
judge is right (the frames never moved; the rule's anchors, wherever they
fell, hold the standing truth). Under Season B, every question that was
unambiguously answered within r of the dial's edge at the last quiet frame
now stands ρF farther from its key — every one of them past the edge, every
verdict turned, every one in error. The mass so swept is the mass of
questions within ρF of losing an answer at the quiet frame: the swept mass
φ(0, ρF). The rule errs by at least that. ∎

**A remark on the adversary's mechanism (a repair of the first draft).**
*The draft's adversary moved the key itself across the boundary band. On the
plane this under-delivers: a key moved by β sweeps a lens of questions whose
mass grows as the three-halves power of β against the band's own first
power — the move cannot attain the theorem at its own bound. Vik's letter of
20 January 1905 supplied the repair, adopted here: do not move the key;
redraft the gauge itself outward, every question-to-key distance growing by
ρ a day. The swept band is then attained exactly, and the legality wants
only the three triangle cases written out (through a plain question,
through a key, and past both), which the minute-book appendix carries at
Grønn's insistence.* [Ed. margin: the corpus's own sketch first moved a
key; the machine-held paper replaced the move with the outward metric
perturbation and flagged the sketch's overclaim — the same fault, the same
repair, the same insistence on the legality cases. — Ed.]

**Corollary 1 (what the clean form says, and when it lies).** *If all the
mass near the dial's edge is on the answered side — the audit-of-traffic
case, and the usual one — the swept mass is simply the mass of margins within
ρF, and the floor reads: worst error ≥ (mass of margins within ρ·F). If the
mass stands on both sides, the adversary must choose a side for each key, and
quoting the clean form overclaims by up to half.* [Printed as a repair of my
own first draft, which quoted the clean form always. The two-sided case was
brought by Vik; the honest floor is the swept mass. — M.H.]

**Corollary 2 (infeasibility).** *If ρF ≥ ε₀ and the ε₀-band carries the
target mass of margins, no rule holds the band. Not expensively — not at
all.* The floor is not a price. It is a wall. Beyond it the repairs are
three and only three: shorten the mail (F), slow the world (ρ), or widen the
band (ε₀). Cleverness is not on the list.

**Two remarks.** *(i) The floor is not a trick of adversarial timing. A
season that drifts steadily against the best steady policy leaves the same
residue: the anchor is F stale at best, and ρF accrues inside the window
whatever the policy does. (ii) Dice do not help. The two seasons send the
same letters, so the dice fall the same under both, and the error, being an
average over the dice, keeps the floor. The adversary never reads the dice —
the seasons are built before the rule is even chosen.*

## §5. The schedule arithmetic (what the floor permits)

Below the wall, ρF < ε₀, one may as well be precise about cost. Write
T_w = ε₀/ρ − F, the **control window** — the most days an anchor may stand
and still leave the ε₀-band held.

**Lemma (equal spacing).** *n re-sightings spread over H days leave a largest
gap of at least H/(n+1), with equality exactly at equal spacing; and to hold
every gap within δ requires at least H/δ − 1 re-sightings.* Proof: the
largest of n+1 gaps that sum to H is at least their mean; equality forces all
gaps equal. ∎

**Theorem (the roster).** *(i) Aggregate trust — only the freshest anchor in
the room is consulted: the least cost is c/T_w per day, attained by any
interleaving of the roster with union-gap T_w, and it is independent of the
size of the roster. A relay of m re-sighters cycling at spacing T_w costs the
same as one man walking his own beat. (ii) Member trust — each member may be
consulted alone, and each must therefore be fresh on his own account: the
least cost is m·c/T_w. The factor m is the price of trusting each man
separately. (iii) The service floor δ_min (a man may not usefully re-sight
faster than his evidence settles) turns the roster arithmetic into a phase
rule: if δ_min > T_w, no single man can hold the band and the room is forced
into a relay of at least m_min = δ_min/T_w men; if δ_min < T_w, a room larger
than m_max = T_w/δ_min wastes itself, its members' anchors falling inside
their own settling. The same formula, read in two seasons.*

*Proof.* (i) Feasibility at union-gap T_w holds the bound of Memoir III,
Theorem B4(i), with T = T_w; no schedule can space looser than T_w and hold
the band, so no schedule can cost less than c/T_w; equal spacing attains it
by the lemma. The argument never counts the men. (ii) Each man's own gaps
must each be within T_w; the men's costs add. (iii) Arithmetic, printed in
the minute-book at length. ∎

## §6. The worked season (with its flags, as the Circle requires)

The court audits the herring band nightly by the season's custom. From last
season's charts [the rate read off one season's chart; the conversion from
the drift of the shoals to band-units per night is *not* registered, and the
Circle flags it here rather than launder it — Ed.]: ρ ≈ 0.748 band-units per
night; F = 1 night (nightly post); the band's upper edge ε₀ = 0.6.

**ρF = 0.748 > 0.6. The nightly audit cannot hold the band.** The control
window is negative: T_w = 0.6/0.748 − 1 = −0.198 of a night. Nothing is on
the menu. The season's indeterminacy, at this order of magnitude, is a
measurement of the staleness of the post, not of the herring.

Buy fresher post (the table, verified in triplicate, Fosse and Undrum, two
passes each; the comptometer ribbon is filed with the minute-book):

| F (nights) | ρ·F | T_w (nights) | control (kr/night) | post (kr/night) | whole (kr/night) |
|---|---|---|---|---|---|
| 1.00 | 0.748 | — | *infeasible* | — | — |
| 0.70 | 0.524 | 0.102 | 9.79 | 1.43 | 11.22 |
| 0.50 | 0.374 | 0.302 | 3.31 | 2.00 | 5.31 |
| 0.40 | 0.300 | 0.401 | 2.49 | 2.49 | 4.99 |
| 0.25 | 0.187 | 0.552 | 1.81 | 4.00 | 5.81 |

[The post is priced at 1 kr per night-equivalent of frequency — the linear
tariff; the second column of costs is the post's own price k/F. — Ed.]

The whole cost has a least: F* = ε₀√k / (ρ(√c + √k)), which for the court's
c = k = 1 sits at **F* = 0.401 nights, whole cost ≈ 4.99 kr/night** — never at
the freshest post one can buy, and never at the stalest one can afford. When
post is dear, settle for stale anchors and pay in band-headroom; when post is
cheap, buy down to the wall and no further. [The equilibrium's derivation is
one page of the differential calculus, printed in the minute-book appendix;
the curve is shallow near F*, which the table's middle already shows. — Ed.]
The ceiling itself stands at ε₀/ρ = 0.802 nights: past it every row of the
table is infeasible, and the divergence of the 0.70 row is the wall seen from
below.

## §7. The test for claims of re-sighting (the handbook)

Every claim of the form "our rule holds the band under drift" is tried as
follows; the first failure returns the verdict.

1. **Extract F** — the staleness, in service, of the evidence the rule acts
   on. Not the staleness in the trial-room: in service. Unstated F: the claim
   is ungraded and stops here.
2. **Extract ρ** — the *worst* rate the claim's horizon demands, not the
   season's average. The floor is a worst-case wall.
3. **Compare ρF with ε₀.** ρF ≥ ε₀: the claim is false as stated; the three
   repairs only. ρF < ε₀: continue.
4. **Check which side the mass is on** (Corollary 1): quote the clean form
   only if the traffic is all on the answered side; else quote the swept
   mass, and do not round it up.
5. **Price the roster** by the theorem of §5, and check the phase rule.
6. **Beware the closed book.** A rule tried against the completed log is
   tried at F = 0 — the whole season lies on the table — and a rule tuned
   there is tuned against a floor of nought. Try it again at the service F,
   or the trial proves nothing. [The trial-room is not the strait. — Ed.]
7. **Register the falsifier.** A claim without its falsifying trial
   specified is pending, not proved.

## §8. What this memoir does not say

The theorem prices ignorance. It does not cure it. It says where the edge of
the court's knowledge must lie — ρ·F inside the dial's edge, whatever the
court spends — and it promises nothing whatever beyond that edge. A theorem
that says *no*, with proof, is not a lesser theorem than one that says yes;
the rope is honest, and holds what it holds.

*Corrections from the first draft, larger than errata: the draft quoted the
clean form (the mass of margins within ρF) unconditionally — Corollary 1
above is the repair, and the repair was urged on the author by the same
letter that fixed his adversary; and the draft's key-moving adversary is
replaced by the gauge-redrafting construction, as the remark records. The
draft is kept among the drafts; the Circle's rule that a theorem's honesty
notes are part of the theorem dates from this memoir's revision.*

*[The Videnskabs-Selskab refused this memoir on 9 June 1905 with the words
"a theorem concerning our ignorance is not a theorem." The Circle records
the refusal without comment, and the Fisheries Directorate's October returns
— which could not hold the nightly band and did hold the half-nightly one,
at the costs the table above gives — record the rest. The editors print
both. — Ed.]*

*Errata to this fair copy: in §6 the table's 0.70 row was first computed
with ε₀ − ρF = 0.0764 mis-set as 0.0674 (the subtraction done before the
multiplication by ρ on a tired evening); caught by Fosse; the corrected
9.79/11.22 stands. The flags stand as first printed.*
