# 02 — THE BALANCE OF THE BOOKS

*Memoir the second of the Kaldfjord Circle. Begun January 1904, read to the
Circle Thursday, 19 May 1904. Fair copy by M. Skavlan. The proofs were carried
through in triplicate by S. Undrum and J. Fosse, and proof-read by H. Grønn;
his certificate is printed at the close, as the Circle's rule requires.*

**Sigrun Undrum, chief bookkeeper, Strandsild**

*with a note on the snap entry by the Circle*

---

## §1. The bookkeeper's creed

In the beginning is the rule, and the rule is Pacioli's: **every entry sums to
nought.** A credit of 5 kroner posts against a debit of 5 kroner, or it does
not post. We do not prove this rule. We choose it — Standing Rule 1 of Memoir
I — and this memoir is the account of what the choice buys. Everything below is
conditional on that one choice, and I will say so at each theorem, because a
book that hides what it stands on is a book you cannot sleep on.

A **posting** is a pair (account, amount), amount positive for credit,
negative for debit, never nought. An **entry** (we say a *transaction*) is a
set of postings on distinct accounts carrying a **counter-mark** — a mark
unique to that entry, built, as the Circle later insisted (§6), from the
writer's name and his serial number. The entry is **balanced** when its
amounts sum to nought. A **ledger** is the append-only sequence of entries
applied, with the balances they leave; the balance of an account is the sum of
its postings since the account opened. Standing Rules 2–4 do the rest: one
clerk owns each account; the clerk's pen is single; a counter-mark already in
the book is passed over.

## §2. The cut

Call any set of accounts a **cut** — the cannery's accounts against the
fleet's, or the shore's against the strait's. Let Φ be the total of all the
cut's accounts. An entry **crosses** the cut if it posts on both sides; it is
**interior** if it posts only within. A posting of a crossing entry is **in
flight** from the moment its entry's first posting is made until its last.

The creed's first purchase is this: the interior of a set of books may churn
from Michaelmas to Michaelmas and not move Φ by one øre. Theorem 1 says so,
and proves it the only way worth proving — over the day's events, one at a
time, by hand.

## §3. Theorem 1 — the conservation of the cut (interior case)

**Theorem 1.** *Let a day's events be recorded in which no committed entry
crosses the cut. Then Φ does not change from the opening of the day to its
close.*

**Proof, by induction over the events of the day.** Write the day as its
sequence of events, e₁, e₂, e₃, …, each belonging to one box, in the order its
pen served it (Standing Rule 3). Three kinds of event touch nothing in the
books: the setting of dials, the heartbeat, the answering of views. One kind
touches the books: the application of an entry's postings.

*Base.* Before e₁ the books stand as they stood; Φ is the opening total.

*Step.* Suppose Φ unchanged through eₘ; consider e₍ₘ₊₁₎.

If e₍ₘ₊₁₎ is not an application — nothing posted; Φ unchanged.

If e₍ₘ₊₁₎ applies, at a box *outside* the cut, postings on accounts the box
owns — none of them in the cut (Rule 2: it owns them, the cut does not); Φ
unchanged.

If e₍ₘ₊₁₎ applies, at a box *inside* the cut, the postings it now makes on its
own accounts: the entry T either posts only inside the cut, or only outside
it, or crosses — and the theorem's hypothesis has excluded crossing. This
application being made inside, the entry's cut-side postings exist; the entry
being interior, *all* its postings are on the cut side. The change to Φ is the
sum of T's postings on the cut's accounts, which is the sum of all T's
postings, which is nought, by Rule 1. Φ unchanged. ∎

*What the theorem stands on: Rules 1, 2, 3, 4 — and Rule 1 alone is
load-bearing; the rest keep the books in the shape the induction walks.*
Eleven seasons of herring books say the same thing, but the seasons do not
prove; the induction does. The table in §7 was checked against it.

## §4. Theorem 2 — the in-flight identity

Theorem 1 assumed no crossing. Entries do cross — the fleet sells fish to the
cannery daily — and while a crossing entry is half-made, the books of the two
sides disagree, and an honest memoir must say by exactly how much, not wave at
it.

**Theorem 2.** *At every moment of the day:*

  Φ = Φ(opening) + F + I,

*where F is the sum, over entries fully applied on both sides, of their
cut-side flow (credit counted positive), and I is the sum of the cut-side
amounts of postings made but not yet matched by their entry's far side. In
particular, whenever nothing is in flight (I = 0), the cut's total is the
opening total plus the completed flow.*

**Proof, by induction over the events, carrying the identity as the
invariant.** At the opening F = I = 0 and the identity is Φ = Φ. Consider the
next application e, of postings summing on the cut side to P (P = 0 if e's box
is outside the cut).

*Case 1 — e does not complete its entry.* The books of e's side gain P: Φ
gains P. F is untouched (the entry is not complete). The postings now made and
unmatched join the in-flight: I gains P. Both sides of the identity gain P.
The identity holds.

*Case 2 — e completes its entry T.* Let Q be the cut-side postings of T made
before e (they stood in I). If e's box is inside the cut: Φ gains the rest,
net(T) − Q, where net(T) is T's whole cut-side flow; F gains net(T), for T is
now complete; I loses Q. The right side gains net(T) − Q: the identity holds.
If e's box is outside the cut: Φ gains nought; and Q = net(T) (all the cut-side
postings were made earlier, or there were none); F gains net(T); I loses Q =
net(T); the right side gains nought. The identity holds.

Non-applications change neither side. Rule 4 keeps a completed entry from ever
re-entering I: its mark is in the books, and its redelivery is passed over.
∎

**Corollary 1 (nothing is minted).** For a quantity carried only in accounts,
any rise of Φ requires a committed credit on a cut account; by Rule 1 that
credit is matched by a debit inside the cut (nought to Φ, by Theorem 1) or
crossing it (counted in F and I). *An unbacked credit is not forbidden. It is
unwritable.* There is a difference between a law and a discipline, and the
difference is that a discipline cannot be broken by a clerk in a hurry.

**Corollary 2 (the meter).** If the mail is cut and the fleet's half-entries
stand unmatched, the disagreement between the two sides' books is I — read off
the books, continuously, in kroner, not guessed at. The ledger is its own
error-gauge. (Memoir IV prices how long such a window may lawfully stay shut.)

**§4½. The two meters (a repair made before the fair copy).** *The first
draft of this memoir stated the cut-mail claim as one inequality — "the
staleness grows no faster than the in-flight postings, F(t) ≤ F₀ + I(t)"
— and Grønn's pencil struck it twice: F in days, I in kroner; you cannot
add days to kroner. The repair, printed here because the conflation is
instructive, splits the claim into two meters, each true in its own
units:*

- **the time meter:** from the last delivery to the mirror, its staleness
  in days grows at exactly one day per day — no faster, no slower; it is
  a clock, not a balance;
- **the value meter:** the deviation between the owner's books and the
  mirror's, in kroner, **equals the mirror's in-flight at every moment,
  exactly** — the sum of the postings of entries the owner has applied
  and the mirror has not, which grows entry by entry and never shrinks
  while the mail is cut (each entry's mark is in the owner's book and
  cannot leave it).

*The draft's single inequality was neither meter; the revision is both,
and the proof of the value meter is Theorem 3's argument run against the
cut instead of against a second clerk.* [Ed. margin: the corpus's own
history made this same repair — the conjecture's conflated clause,
"F(t) ≤ F₀ + I(t)," was split into time-staleness and value-deviation
with the mirror in-flight as the exact Lyapunov quantity, the wrong meter
named and replaced. — Ed.]

**A remark for the Academy.** The identity of Theorem 2 is pure bookkeeping;
Rule 1 is not needed for it. Rule 1 is what makes F and I *conservation*: an
entry completed everywhere posts nought to the total of *all* books, so the
whole world's Φ returns, at every quiescent moment, to its opening value. The
trial balance is this theorem with one cut.

## §5. Theorem 3 — two clerks, one truth

**Theorem 3 (the mirror).** *Let two clerks keep the same accounts from the
same invoices — the same entries, with the same counter-marks, delivered to
each at least once, in any order, with any repetition. When each has served
every invoice, their balances are equal. No agreement between them, on order
or on anything else, is used anywhere in the proof.*

**Proof.** Fix one clerk and walk her day. After n invoices served, her
balance on an account is the opening balance plus the sum of the postings of
the *distinct* entries among them: for if the (n+1)th invoice's mark is new,
its postings join the sum; if the mark is old, Rule 4 passes it over and the
sum is unchanged. The sum so written does not mention the order of service;
two clerks who have served the same set of invoices have written the same
sum. When both have served all, their sums are the same sum. ∎

The fleet's shore-copy and the cannery's own books have agreed for two seasons
by this theorem and for no other reason. Note what is *not* claimed: only what
travels in entries converges. Habit, draft notes, and a clerk's private tallies
are re-earned by re-playing the entries; the ledger, not the clerk, is the
truth. (Memoir V, §6, makes this an impossibility, not a preference.)

## §6. The shop within a shop

**Theorem 4 (consolidation).** *Let a firm of boxes hold interior accounts
(between its own members) and exposed accounts (with the world). Strike the
interior postings from every consolidated statement. Then: (a) the
consolidated balances depend only on entries touching the exposed accounts —
every interior entry vanishes identically; (b) flattening a firm within a firm
may be done inner-first or outer-first; the consolidated statement is the
same; (c) the trivial firm (one member, no interior accounts) consolidates to
itself.*

*Proof.* (a) Striking interior accounts is striking coordinates; striking
coordinates is additive (the strike of a sum is the sum of the strikes), and
an interior entry has nought in every exposed coordinate — it vanishes. (b)
striking the middle layer's accounts and then the inner layer's keeps, at the
end, exactly the outermost exposed accounts, whichever order the strikes are
taken in — strikes commute, being coordinate strikes; interior entries die in
either order. (c) there are no interior coordinates to strike. ∎

The reader who thinks this easy is right; it is easy the way a knot is easy
once named. Its use in Memoir V is not easy at all.

**The snap entry.** *A note by the whole Circle.* The tally-box's clockwork
compares a guessed value g against a sensed value s (the tide-gauge against
the almanac) at every heartbeat, within a deadband Δ. When the gauge exceeds
the deadband the guess is *snapped* to the reading — reality wins — and the
correction is booked. The naive snap entry has three legs:

    {(G:authority, −1), (T:authority, +1), (G:correction, +|g−s|)},

and **does not balance**: its legs sum to |g−s|, not nought. We confess this
here because the error was ours, found by J. Fosse at the second pass of the
proof sheets [the finding is dated 3 May 1904 in the minute-book; the printed
slip, which the school keeps with the drafts and pastes into every copy, was
the making of its errata rules — Ed.]. The entry that obeys Rule 1 has four
legs:

    {(G:authority, −1), (T:authority, +1),
     (G:correction, +|g−s|), (T:correction-issued, −|g−s|)},

which sums to nought: the correction is booked as a paired accrual, debit the
expense, credit the contra. With the four-legged form: custody of the
authority is conserved (exactly one of the pair holds it, always — Theorem 1
on the cut {G, T}); the divergence never exceeds Δ at any heartbeat (induction
over heartbeats: WITHIN leaves it within by the judge's own condition; SNAP
makes it nought); and between heartbeats it cannot exceed Δ + ρ, where ρ is
the most either side can move in one beat. The accumulated booked corrections
grow at most linearly: each snap books at most Δ + ρ, and after a snap the
divergence must re-walk the deadband at rate at most ρ, so snaps come at least
⌈Δ/ρ⌉ beats apart; over N beats the total booked is at most (Δ+ρ)(1 + Nρ/Δ),
which for a wide deadband grows at slope asymptotic to ρ. *The debt of
correcting a guess has a rate of interest, and the interest is the drift.*

## §7. A worked week

The table below is the cannery's books against the fleet's for the week of
17–22 April 1904, kept for this memoir, verified in triplicate (Fosse and
Undrum, two passes each; Grønn, the arithmetic of the in-flight column). The
cut is the cannery's four accounts {Fish, Cash, Oil, Repairs} against the
fleet's; amounts in kroner.

| Day | Entry (mark) | Cannery side | Fleet side | Effect on Φ | F | I |
|-----|--------------|--------------|------------|-------------|---|---|
| Mon | 1904/0417-a | Fish +120.00 | Fish −120.00 | (in flight) | 0 | +120.00 |
| Tue | 1904/0418-b | Cash −96.00 | Cash +96.00 | −96.00 | +24.00 | 0 |
| Wed | 1904/0419-c | Oil −15.00, Repairs +15.00 (interior) | — | 0 | +24.00 | 0 |
| Thu | 1904/0420-d | Fish +60.00 | Fish −60.00 | (in flight) | +24.00 | +60.00 |
| Fri | 1904/0421-e | Cash −48.00 | Cash +48.00 | −48.00 | +36.00 | 0 |
| Sat | — | (close) | (close) | — | +36.00 | 0 |

Φ(week's close) = Φ(opening) + 36.00; interior churn (Wed) moved it by nought;
each purchase was in flight exactly until the fleet's side posted; at no close
of day was anything unmatched except the entries marked so. **Erratum, found
by the second pass and printed as found:** in the first drawing of this table
the Tuesday row read Cash −69.00, the digits transposed from the day-book;
the third pass caught it; the fleet's half-entries never agreed with ours until it
was caught, which is Theorem 3 doing the office of a proof-reader.

## §8. What this memoir claims

That conservation is not assumed but *chosen* (Rule 1) and then *earned* by
induction (Theorems 1–2); that replication needs no agreement (Theorem 3);
that a firm's interior is silent at its boundary (Theorem 4); that a snap must
be booked in four legs or it is not booked at all. It does not claim the mail
never fails — Corollary 2 is the mail's failure made legible — nor that
clerks never misadd; see §7.

*Proof-read and certified, H. Grønn, pilot — the certificate follows.*

---

## Appendix — Grønn's certificate *(added in proof, 26 May 1904)*

I have carried the inductions of Theorems 1, 2, and 3 through on paper, at
full length, with the events written out one by one for a day of six events
and again for a day of nine, in both orders of service for Theorem 3, and I
find them sound. The load is where the author says it is: Rule 1 in Theorem 1's
last step and nowhere else; Rules 2–4 in keeping the day walkable. The snap
entry's four legs sum to nought, as claimed, and the three-legged form does
not, as confessed. Two small matters, printed here so the record holds them:
in §4, Case 2, the identity when e's box stands outside the cut wants the
remark that Q = net(T) *or net(T) = 0 = Q* — the author's text now carries it;
and in §7 the table's in-flight column was added at my insistence, the first
drawing having only the day's closes, which proved less than the theorem
states. With those two amendments, certified.

— H. Grønn
