# 05 — THE LEDGER PAPERS

*Memoir the fifth of the Kaldfjord Circle, in two parts. Part the first read
Thursday, 20 July 1905; part the second (the refutation and the erratum)
completed 9 August 1905 and read Thursday, 17 August 1905. Fair copy by
M. Skavlan from the author's comptometer-verified draft.*

**Johanne Fosse, second bookkeeper, Strandsild**

---

# PART THE FIRST — WHAT SURVIVES THE CLOSING OF A VOLUME

## §1. The question every bookkeeper asks and none has written down

At season's end I close the volume: I strike a summary, the notary sets his
seal on the closed leaves, and the volume goes to the loft. The tail of the
season stays on my desk. The question is: **what may be asked of the closed
volume afterwards — and what may not?** Everyone in this trade knows in
their bones that *something* is lost; nobody, to my knowledge, has said
exactly what, and I have the winter and the comptometer, so here it is.

The closing is this: a **summary**, a **seal**, and the **kept tail**.

## §2. Summaries that commute

A **summary rule** (I shall say a *fold*) is a way of reducing any set of
entries to one figure — or one small set of figures — that combines entries
by an operation which is associative and commutative: combine in any order,
in any grouping, the result is the same. The balance of an account is the
plain example (sum of postings); the count of entries; the count of entries
of a named kind; the greatest of a field; all combine so. Formally: a fold
is (Σ, ⊕, f), ⊕ associative and commutative, f the figure carried per entry,
and the fold of a volume is ⊕ over its entries' f.

**Lemma 1 (order-independence).** *The fold of a volume does not depend on
the order of its entries, and the fold of a concatenation is the ⊕ of the
folds.* Proof: one entry more at a time — associativity regroups any
bracketing, commutativity swaps any two neighbors, and any order of a list
is reached from any other by swaps of neighbors. ∎

The reader who yawns here should not: Undrum's Theorem 3 (two clerks, one
truth) *is* this lemma in a clerk's clothing, and Grønn's Theorem 4 (the shop
within the shop) is its shadow — the interior entries lie in the fold's
nothing, and vanish at the boundary. [The Circle asks me to record that this
is the same fact wearing three coats, and that noticing so was Holt's. — J.F.]

## §3. The characterization

A question is **answerable from the closing** when its answer is computable
from (summary, seal, tail) alone — no loft, no notary's copy, no memory. Say
a question is **covered by the fold** when its answer depends on the volume
only through the fold's figure.

**Theorem 1 (what survives).** *(a) Every question covered by the fold is
answerable from the closing: fold the tail, ⊕ it to the summary, read off
the answer. (b) And this is all: for a closing that keeps only the summary,
any question answerable from the closing is covered by the fold. Every
uncovered question is lost — provably, not possibly.*

*Proof.* (a) is Lemma 1. (b): suppose some question Q is not covered — then
two volumes, P₁ and P₂, stand with the same fold and different answers. Close
them: the closings are identical (same summary, same kind of tail — take
both tails empty). The answering clerk faces two identical closings and must
give one answer; Q distinguishes the volumes; whichever answer he gives is
wrong for one of them. No such clerk exists; no answer exists. ∎

*[The reader of the drafts will notice that this section is a refutation of
this memoir's own first draft, which claimed — and believed — that "the
seal preserves the quarantine chain, for whatever predicate the inspecting
officer may later name." Undrum's letter of 30 June ("write what does NOT
survive with the same pen") and Skavlan's of 19 July ("strike the claim")
forced the counterexample out; the draft is kept among the drafts, claim
and all. — J.F.]*

So the shelf of what survives is exactly the shelf of folds: balances, cut
totals, the exposed face of a firm within a firm, counts, sums, maxima,
minima, products of these. There is nothing else on the shelf. The engineering
question is never "can we close losslessly?" — it is "**which fold do we
live in, and do we accept what its nothing swallows?**"

## §4. The exclusion question (the counterexample, printed in full)

The question the trade actually asks at the turn of the year is not "what is
the balance?" — the summary answers that — but "**what did we never write
down?**": was such-and-such a posting ever made and struck into the closed
volume? The fishery's quarantine of tainted barrels is exactly this question,
and the predicate of the taint is chosen by the inspecting officer *after
the volume is closed*. Here is the counterexample that no summary survives.
Four accounts, a, b, c, d. Two closed volumes of two entries each:

    P₁:  {(a, +5), (b, −5)};  {(a, −5), (b, +5)}
    P₂:  {(c, +7), (d, −7)};  {(c, −7), (d, +7)}

Every entry balances (Undrum's Rule 1 holds in both volumes); every touched
account nets to nought; **the balance-fold of P₁ equals the balance-fold of
P₂** — both are the plain nothing. Now ask, after the closing: *did the
closed volume contain a posting of 5 kroner?* P₁ answers YES. P₂ answers NO.
By Theorem 1(b) no closing — no summary of any kind fixed at closing time —
answers it, and the argument is not about balance-folds: any summary fixed
in advance has volumes it cannot tell apart, and the after-the-fact question
hunts exactly those pairs.

**You cannot quarantine after the fact what you did not think to count.**
They who close a volume choose, on that day, the whole of what the future
may ask of it without the loft.

## §5. The seal, honestly scoped

The notary's seal is not a summary and the Circle will not let me wave at
it. What the seal does — *assumed*, for the Circle models the notary as a
man who never seals two different volumes alike [an idealization, flagged —
the Circle knows no notary is perfect, and the assumption is the seam —
Ed.] — is **bind**: no second volume exists carrying the same seal. What the
seal does *not* do is **reveal**: to an officer who holds a closed summary
and a seal and no candidate volume, the seal is a face with no writing on
it. [The Circle's argument, in the minute-book appendix, is by ignorance:
with no candidate to name, every seal is as every other; no rule of the
officer's can do better than chance, and chance is no answer at all. — Ed.]
Separation is not extraction. What the seal buys is the *witness* regime:
anyone who kept a copy of the closed volume — the originator, a replica, a
rival — can prove an entry stood in it: the notary's tree of half-seals over
the volume's parts is recomputed upward to the root, and the recomputation
either matches the seal or does not, in a number of steps proportional to
the volume's depth. The count of a *declared* kind of entry — one counted
into a fold at closing — plus the witnessed enumeration of the held copy,
checks the whole quarantine chain: every counted-and-excluded entry
accounted for, by seal. **Declared folds recover; undeclared questions never
do.**

## §6. The pricing: no small summary answers the after-the-fact list

**Theorem 2.** *If the questions include, for predicates chosen after the
closing, "list the closed volume's entries answering the predicate," then
any closing that answers them all keeps a summary as long as the volume
itself (to the nearest entry).* Proof: volumes of c entries over a two-valued
datum number 2^c; the list-questions distinguish every pair of them; answers
that distinguish must arise from distinguishable closings; a closing that
distinguishes 2^c volumes carries at least c entries' worth of figure. ∎ The
traders' folklore — "summaries lose the audit detail" — is this theorem in
an apron.

## §7. The wear-rungs: what no fold of any size can hold

The tally-rails of the fishery keep a **wear-ladder**: each cofire of a net
falls into a rung by its age, and every H days the ladder shifts a rung —
age never stands still. Halvard asked me last winter whether the ladder is
a fold, and the answer is no, and the no is short enough to print whole:

**Theorem 3 (the rungs admit no fold).** *No commutative summary of any size
whatever computes the rungs.* Take two one-entry volumes, same in every part
except order: V₁ = [cofire, shift]; V₂ = [shift, cofire]. The same multiset
— every fold gives the same figure (Lemma 1). But in V₁ the cofire is
shifted into the first rung, and in V₂ it sits in the noughtth. Different
read-outs. The fold cannot have both. ∎

Two entries. The smallest counterexample in these annals, and the one I am
proudest of — and the sharpening of a weaker first draft, which resolved
the rungs only against the balance fold (the volumes P₁ and P₂ of §4 as
witnesses); the two-entry permutation kills every fold outright, and
Krøger asked at the reading why the larger witness was ever wanted. **The replay is the only lossless compaction of the rungs**: the
ordered stream itself, or nothing. This is not a preference of ours; it is a
theorem. Posting more into the books does not help — it only lengthens the
replay. [The one fold that lives inside the rungs is the plain count of
cofires. The age-shaped part is irreducibly ordered. — J.F.]

# PART THE SECOND — THE WEAR-RUNG BAND, THE BANK, AND THE REFUTATION

## §8. The rung staircase's honest error

Read the ladder as a forgetting-law: an event of age a carries the true
weight 2^(−a/H) (halving every H days), and the rung that holds it carries
the weight 2^(−i) for its rung i. The rung overstates — the event aged
within the rung — and by how much:

**Theorem 4 (the two-fold band).** *For any arrivals whatever — adversarial,
clustered, capricious; no assumption is made or used — the rung read-out Ŵ
stands between the true total W and 2W: W ≤ Ŵ < 2W. With the phase of the
shifting rule as built, honestly: W/2 − 1 ≤ Ŵ ≤ 2W + 1.*

*Proof.* An event of age a in rung i has a between iH and (i+1)H, so its
true weight lies in (2^(−i−1), 2^−i]; the rung assigns 2^−i, over by a
factor in [1, 2). Sum over events. The phase-clause is the shift-boundary
ambiguity the rails cannot see, one rung either way, and the ±1 is the
integer slack of the rails themselves. ∎

The band is tight at both ends (events aged just under a boundary nearly
double; just past one, nearly halve). And the *expected* overstatement, for
ages spread evenly within their rungs, is not two-fold but 2·ln 2 ≈ **1.386**
— the rung overstates by two-fifths on the average day, twice on the worst.
Keep both numbers; the season charges both.

A worked row for the table, read at ages 1, 5, 9, 16 days with H = 8
(verified in triplicate):

| age | rung | true 2^(−a/H) | rung weight |
|----:|:----:|--------------:|------------:|
| 1   | 0    | 0.9170        | 1           |
| 5   | 0    | 0.6484        | 1           |
| 9   | 1    | 0.4585        | 0.5         |
| 16  | 2    | 0.2500        | 0.25        |
|     |      | **W = 2.2739**| **Ŵ = 2.75**|

The read-out stands at 2.75 against the truth 2.2739 — a ratio of 1.209, and
the theorem permits anything up to (but never reaching) 2.

## §9. The bank, and Maren Skavlan's conjecture

Mrs. Skavlan proposed, in April, the residue bank: every cofire deposits into
a reservoir; the reservoir leaks slowly; the read-out takes back a credit of
the reservoir's high end. Her conjecture, in her own words from her letter of
20 April 1905 [printed whole in the correspondence — Ed.]: the bank "will,
with patience, draw the read-out to the true law, closing the two-fold band."

**It will not.** The first draft of this memoir endorsed her conjecture on
her say-so; her own letter of 19 July handed it back to me: *endorse it on
your arithmetic.* The arithmetic follows, and it is the refutation, which I
write with more pleasure than I can decently say, because the conjecture *earned* it: refuting her forced out
into the open the exact condition any bank must meet, and now we know it to
the øre.

**Theorem 5 (the refutation, in two parts).**

**(i) The band is preserved, never closed.** *The credit is never negative.
So the credited read-out Ŵ + C stands in [W/2 − 1, 2W + 1 + C]: the upper
ratio is* **widened** *by C/W and never narrowed, for any W whatever. A
one-sided credit cannot close a band; it can at most stand in the middle of
one.* Proof: add a non-negative number to both sides of Theorem 4's band.
∎

**(ii) What a bank can do is center — and the exact deposit is computable.**
*For the credit to track the staircase's overstatement in the long run — to
hold the read-out at the band's middle, the strongest any one-sided credit
achieves — the deposit per rung must equal, to the quantum, the rung's
expected overstatement:*

    deposit(g) = 2^(K+Q−g) · (1 − 1/(2·ln 2)),

*with K the read-out's bits and Q the quanta per credit-unit. The as-built
deposit 2^g meets this nowhere but near the top rung (g ≈ 7.1 by the
formula for K = Q = 8); its rung-dependence is inverted — largest where the
overstatement is smallest — and at the noughtth rung it is ~18,262 times too
small.*

*Proof of (ii).* In the aligned phase the rung overstates; the credit can
only push up; so the attainable target is the middle: the credit's long-run
rate must equal the overstatement's long-run rate, rung by rung, for every
mixture of rungs the season sends — which forces the deposit per rung to the
displayed value (the expectation over ages even within the rung is
2^(K−g)(1 − 1/(2 ln 2)); carry it through the Q quanta). Solve 2^g against
it: equality at g ≈ 7.1 for K = Q = 8; below that the deficit runs by
2^(K+Q−2g)(1 − 1/(2 ln 2)). ∎

**ERRATUM, printed as the Circle prints errata.** *My first note on this
matter, circulated 30 July 1905, gave the noughtth-rung deficit as ~9,100
times. It is ~18,262 times. The slip is a lost factor of two in the octaves —
the 2¹⁵ against 2¹⁶ — found by my own third pass and confirmed by Undrum's.
The corrected deposit table, in quanta, rung for rung (K = Q = 8):*

| rung g | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| deposit | 18,260 | 9,130 | 4,565 | 2,283 | 1,141 | 571 | 285 | 143 |

**Erratum to the erratum, and here I stop:** the two top rungs want 18,262
and 9,131 by the strict rule; the table was set from the first corrected
note and rounds to the ten below; we leave it, corrected in the margin, as
it stood — a table that hides its corrections is a false table, and a
bookkeeper who cannot show her own slips cannot be trusted with yours.

**What survives of the bank (and it is not nothing):** the credit is bounded
(never more than 255 of the read-out's least units; the reservoir saturates
and never wraps); the anticipation cadence is exact (the reservoir pulses
once per 2^(Q−g) cofires of rung g — 256 at the fresh rung, 32 at the third —
a deterministic countdown the rails may run for nothing); and the credit
tracks the *recent rate* of cofires honestly — a low-pass of the week's
work, not a memory of the year's. Refuted as a closer of bands; kept as a
pulse and a gauge. Maren gave us the question; the season keeps the answer.

## §10. The hinge

One more thing, and it is Grønn's, and it closes the annals' circle: the
shop-within-a-shop (Memoir II, Theorem 4 — interior entries vanish at the
boundary, and this is *good*, for privacy and for peace) and the closed
volume (§4 here — excluded entries cannot be recovered at the boundary, and
this is *bad*, for quarantine and for audit) are **the same theorem**. Both
say: the summary is blind to its fold's nothing. At a firm's boundary the
blindness is the safety; at a compaction's boundary the blindness is the
loss. **Choose your fold, and you have chosen what your boundary cannot
see.** A firm that must be auditable downstream must fold what the auditor
will ask (declare the counts, §5); a firm that must be private must fold
away what the boundary should not tell; and the two demands quarrel exactly
when the audit's questions are not enumerable in advance — which is to say,
always, and the quarrel is the trade's oldest fact of life, now with a proof
attached.

*Verified in triplicate throughout; the comptometer ribbon is filed with the
minute-book. — J.F.*
