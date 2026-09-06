# RETURN — the metal leg's return cargo: what verification taught the mathematics

**Lane:** mathmetal, return stage (GLM-5.3) · **Date:** 2026-08-29
**Directive (Casey, verbatim):** *"math to the metal AND BACK AGAIN. the journey changes us."*
**Outbound cargo (committed, `cd55d03`):** `tools/verifies/{floor_bench,c1_seam_bench,c3_fold_bench}.py` (1,497,019 exact-arithmetic checks, PASS, bounds printed per run) + `formal/echo_gate.dyadic.sby` (PASS, BMC 25) + the conservation proof re-proven with `PIPE_EFF(1)` pinned.

> **The contract of this document.** The metal leg is not the destination; a verification round trip that returns with the mathematics unchanged is evidence the trip was ceremonial. This is the return-stage record: every place the enumeration and RTL encodings forced a vagueness in the papers into an actual decision (§2), every claim that had to be amended to be checkable — amended in-source, with the journey noted (§3), every tightening and exact witness the machine produced that pen had only claimed (§4), the FAILs loudly, with their lessons (§5), what the machine saw that pen had not written (§6), and the new questions born from the machine's view (§7). §8 is the changed-things ledger: claims entering the metal vs. claims coming back. **Doctrine: verification is a round trip that changes both ends — the artifact proves the theorem, and the theorem's checkable form is not the theorem's spoken form.**

**Statement registry.** 4 amendments (R1–R4, two in-source), 6 forced decisions (D1–D6), 5 tightenings/exact witnesses (W1–W5), 6 harness FAILs with lessons (F1–F6), 2 machine-born observations promoted to remarks (M1–M2), 2 new open questions (Q1–Q2). Grade: **all machine-witnessed** (every item cites the run that forced it).

---

## 1 — The doctrine, in one paragraph

A pen theorem lives in a world of quantifiers ("every policy," "any summary fold," "the direction vector"); a machine check lives in a world of *decisions* (this policy class, this fold state space, this direction argument, this serialization). Crossing from one to the other is not transliteration — every quantifier must be *instantiated into a commitment the paper never had to make*, and some of those commitments are load-bearing: they are places where the theorem, as spoken, was strictly stronger or subtly different than the theorem, as checkable. The return leg's job is to carry those commitments back: amend what the metal falsified or scoped, name what the metal forced, and record what only the machine could see. Six times on this trip the metal rejected the harness's first encoding of a true theorem — and in two of those cases (R1, R2 below) the rejection was not about the harness at all: the *paper's own sentence*, read literally, does not survive implementation. Those two are the trip's payload.

## 2 — Vaguenesses the metal forced into decisions (D1–D6)

**D1 — RF-T1's floor needs a direction argument.** `RHO-F-FLOOR.md` RF-T1 says the pointwise error is at least "φ⁺(s, β⁻) **or the φ⁻-analog**" — a disjunction over sides the prose never parameterizes. The bench's first encoding used the worst-case (max-over-directions) φ, which is RF-T2's object, and produced 18 apparent floor violations on continuous drift. Root cause: the pointwise bound is governed by *which side each key's distance actually moved since the anchor* — a realized-direction vector that appears nowhere in the paper's notation. The metal forced it to exist: `swept_mass_dirs(frame, β, dirs)` is now a named function in the bench, and the pointwise floor (RF-T1) and the worst-case floor (RF-T2) are two different functionals, φ_realized and φ_max. The paper's "or φ⁻-analog" was a pun between them.

**D2 — "Any answerer" means all functions over the finite view.** FC-L2's "advantage exactly 0" is checkable only after deciding what an answerer *is*: the metal committed to the class of all 2^R decision rules over the ROM's root range, advantage averaged over all injective seeds. Under that commitment the lemma is exact (W3). A different commitment (answerers with side information, answerers that can *name* inputs) is the paper's honest scope clause — the metal made the boundary of the claim a data structure.

**D3 — Fold states are total maps, and the counterexample depends on it.** FC-X1's "identical balance folds" is true only because FC-D2/FC-T2 fix Σ = ℤ^Acct — *total* maps with untouched accounts at 0. The bench's first fold used sparse dicts and the canonical pair did **not** collide ({a:0,b:0} ≠ {c:0,d:0} as sparse states). The metal surfaced the convention as load-bearing: with sparse states, the balance fold separates P₁ from P₂ and the counterexample dies. The paper had the right convention; only the trip showed *why it must be pinned* (zero is information, not absence).

**D4 — Byte-exactness is canonical-form equality.** "Round-trips byte-exact" forced a serialization decision (sorted-key canonical form) because Python dict layout is insertion-ordered and fold combination order leaks into `repr`. The taxonomy's byte-exactness claim is now *about a canonical form* — a stronger, honest statement than memory equality.

**D5 — The union join is not a nonce-keyed object.** Theorem 3(b)'s S* ("well-defined as a set by (a)") is, under structural nonces, computable by any ledger; under plain nonces the bench's first "union reference ledger" silently reproduced the seam's own conflation — two distinct transactions, one nonce, one application. The reference semantics had to be built as a set-of-transaction-identities summing posting maps. Sharpened claim recorded as M2 below: **under nonce collision, the union is not well-defined as a function of the two logs at all** — well-definedness is precisely what structural nonces purchase.

**D6 — A formal harness must pin the config it names.** The conservation proof's harness never set `PIPE_EFF`, so its coverage of the shipped retime was by *default inheritance* — true, silent, and one refactor away from false. The return leg pins `.PIPE_EFF(1)` in the harness. Doctrine: **defaults are silent drift; a proof that depends on a parameter must name it** (recorded in THE-BREAKDOWN §1/§12 and B11).

## 3 — Amendments: claims that changed to be checkable (R1–R4)

**R1 — RF-T2's two-sided adversary: the inward arm is not a metric perturbation. (amended in-source, `RHO-F-FLOOR.md` RF-T2)**
- *What the paper said:* "For the two-sided swept form φ(0, ρF), run the same construction with per-key direction choices (**inward** for the keys whose inward band is heavier): each key's perturbation direction is independent of the others'."
- *What the metal demanded:* the inward radial metric perturbation d′(x,y) = d(x,y) − ρ·𝕀[straddle] is **not a pseudometric** whenever any point sits within ρ of an answer — exact witness (committed in this lane's transcript): a = 0, x = 0.3, ρ = ½ gives d′(x,a) = −1/5, and the triangle through the answer collapses (d′(x,a)+d′(a,x) = −2/5 < 0 = d′(x,x)). RF-T2's legality proof covers only the outward direction; the paper's legality sentence was never proved for inward.
- *The repair (now in-source):* inward drift is realized as **answer-point motion along a geodesic** (path-length budget D_a, legal in every metric space). Consequence, stated honestly: answer motion sweeps the full one-sided band in 1-D (the bench's world) but a lens of mass O(β^{(n+1)/2}) in ℝⁿ, n ≥ 2 — exactly RF-C1's own geometry note, now load-bearing on the *attainment* side. So: **the two-sided swept mass φ(0, ρF) is exactly attained in 1-D (and in any space with an exclusion zone d(x, a_j) ≥ ρ around answers); in ℝⁿ, n ≥ 2, the inward side's exact attainment needs the exclusion zone, else the lens bound is what the adversary can force.** The one-sided (outward) headline is untouched — legality there is proved and machine-witnessed.

**R2 — §2(c)'s dyadic bracket: Fmax is 2^PW, not the refill value. (noted in-source, THE-BREAKDOWN §2)**
- *What the corpus said:* "with k(d) = F(d)/Fmax, the class rule gives 2^−g ∈ (k, 2k]" (q_echo_gate.v:18–22, THE-BREAKDOWN §2(c)) — with Fmax read as the refill value 0xFFFF = 2^PW − 1.
- *What the metal demanded:* at the single point F = Fmax, k = 1 = 2^−g and the bracket's *open* lower edge fails — a one-quantum boundary fact. The exact integer form — and the form the TB and `echo_gate.dyadic.sby` actually prove — is the octave form 2^(PW−1) ≤ F ≪ g < 2^PW, which is the bracket with **Fmax = 2^PW**, exact everywhere including F = 0xFFFF.
- *The journey note:* the checkable forms were already right (TB, sby); the *prose* shorthand k = F/Fmax was off by one quantum at the extreme. Amended where cited; the RTL comment's shorthand is now pinned by the octave form.

**R3 — The conservation proof's currency. (closed in-source, §1/§12/B11)** The committed proof artifacts predated the PIPE_EFF retime; the claim "the bitstream runs exactly the proof's parameters" was accidentally-true via defaults. Amended by pinning and re-running (PASS, 40 s), and by measuring the retime's cost: DROP's structural worst case moved ~4 → ~6 cycles (bound 16 intact; margin consumed, a number only the metal could produce — W5).

**R4 — RF-C1's overclaim constant. (confirmed exact)** The paper warned "quoting μ({m ≤ ρF}) without one-sidedness overclaims by up to 2×." The metal attained it: on the two-sided witness, φ = μ_band/2 **exactly**. "Up to" is now "exactly, attainable."

## 4 — Tightenings and exact witnesses the machine produced (W1–W5)

- **W1 (band census):** 200,693 verdict flips across 1,286,250 enumerated drift instances — every flip inside m ≤ γ, and the attainment instance constructed with margin == γ == 2 *exactly* (pen said "attained"; the machine had to build it).
- **W2 (annulus equality):** the composed tolerance r + Σρᵢ is not merely an upper bound — a point at *exactly* r + Σρᵢ is legally presented at *exactly* r (accepted), and the inner edge r − ρ̄ is provably un-flippable. The annulus (r − ρ̄, r + ρ̄] is tight at both edges, half-open for a reason the metal made explicit.
- **W3 (hiding exactness):** advantage exactly 0 — not ε — over *all* 256 decision rules × 56 seeds, while binding holds (h(P₁) ≠ h(P₂)). Separation is not extraction, as two integers.
- **W4 (floor equality, policy-uniform):** on the two-phase adversary, all nine policies' errors were *identical* and equal to φ(0, ρF) — see M1.
- **W5 (retime cost):** DROP worst case 4 → 6 cycles under PIPE_EFF=1; bound 16 keeps 2.7× margin.

## 5 — The FAILs, loudly (F1–F6)

Every failure below was printed by a check's own failure path, root-caused, and fixed — none was a theorem failure, and *that classification itself* is the trip's method: a FAIL is either a counterexample (publish it) or a harness-semantics error (fix the harness, then say what the harness got wrong about the world).

- **F1 — 18 false floor violations** (floor_bench D2): max-direction φ where realized-direction φ belongs. Lesson: RF-T1 and RF-T2 quantify over different objects (D1).
- **F2 — negative distances** (floor_bench adversary): the inward radial perturbation is illegal — this one *was* a paper-sentence failure (R1), the trip's hardest bite.
- **F3 — re-applied mint** (c1 A.monotone): the "fresh post-drain transaction" re-used an applied index; meters refused to move. Lesson: enumeration state must be threaded, not re-derived.
- **F4 — the conflating union** (c1 C.gen): the reference ledger reproduced the seam's bug (D5/M2) — the most instructive failure of the trip: the *referee* inherited the *defendant's* semantics.
- **F5 — insertion-order "byte-exactness"** (c3 A): dict repr leaked combination order (D4).
- **F6 — sby sampling and width** (echo_gate.dyadic): a same-edge assert sampled the pre-update value; and `16'd1 << 16` overflowed to 0 at g = 0. Two classic harness bugs in one 90-line file, both caught by the solver, both fixed before PASS.

## 6 — What the machine saw that pen hadn't written (M1–M2)

**M1 — Policy collapse (promoted to a remark).** Under the two-phase adversary, *every* policy — static, periodic, burst, adaptive-trigger, random — holds the θ₀ frame at t* (RF-L1), so err^{π}(t*) is **constant over the entire policy class and equal to the swept mass**. The floor is not merely a lower bound there; the policy dimension collapses. The bench now asserts this identity (`D.all.equal.phi`); the papers prove ≥. Corollary worth saying aloud: *on the adversary's worst world, all re-anchoring cleverness is equivalent to doing nothing* — the floor is not a race with a clever winner but a wall every runner hits at the same height.

**M2 — Generic, not exotic (promoted to a remark).** The pen counterexamples were single constructions. The enumeration found they are *generic*: all 6,684 differing-content aligned-counter collisions silently diverge (0 clean exceptions); all 40 killing fiber pairs in the census carry differing post-hoc Q; all 68,576 at-least-once replay interleavings converge to the union under structural nonces. In the bounded worlds: **the counterexamples are the rule, not the corner** — and D5 sharpens Theorem 3: under plain nonces the "correct" join is not merely unreached, it is not well-defined as a function of the two logs.

## 7 — New questions born from the machine's view (Q1–Q2)

**Q1 — The mixed-direction legality problem.** Outward metric perturbation: legal, proved, machine-witnessed. Inward: illegal near answers (R1), repairable by answer motion (1-D full band; ℝⁿ lens). Open: for m ≥ 2 keys, characterize the spaces and placements where the *two-sided maximizing* direction vector is exactly attainable by legal realizations — conjectured shape: exact iff every key's heavier side is outward, or the space is 1-D, or each inward key carries an exclusion zone d(x, a_j) ≥ ρ. The floor theorem's worst case is indifferent (outward alone attains the headline); the committee/swept-mass refinements are where this bites.

**Q2 — The direction functional.** D1 suggests promoting φ_realized(θ_s → θ_t) — swept mass *along the realized direction field* — to a named object alongside Φ and φ: RF-T1 is "err ≥ φ_realized since anchor," RF-T2 is "sup over realizations ≥ φ_max," and the sandwich between them is the room policies actually have. Unproved (and unformalized) here; it is the quantity the bench had to invent to be checkable.

## 8 — The changed-things ledger

| # | Claim entering the metal | Claim coming back | What changed |
|---|---|---|---|
| 1 | RF-T2 two-sided adversary: "per-key direction choices, independent" | Inward ≠ metric perturbation (illegal near answers; exact negative-distance witness); inward = answer motion; two-sided φ exact in 1-D / exclusion zones, lens in ℝⁿ (R1, amended in-source) | **Scoped + repaired** |
| 2 | RF-T1 pointwise floor: "φ⁺ or the φ⁻-analog" | Two named functionals: φ_realized (pointwise, needs the direction vector) vs φ_max (worst case) (D1, Q2) | **Disambiguated** |
| 3 | §2(c) bracket: "2^−g ∈ (k, 2k], k = F/Fmax" | Fmax = 2^PW pinned; octave form exact; one-quantum caveat at the literal refill value (R2, noted in-source) | **Pinned** |
| 4 | "The proof covers the shipped bitstream" | PIPE_EFF(1) pinned in the harness; re-proven; staleness found and closed; DROP worst 4→6 (R3, W5, D6) | **Made explicit + re-measured** |
| 5 | FC-X1: "identical balance folds" | Load-bearing convention named: total maps ℤ^Acct; sparse states break the counterexample's premise (D3) | **Convention surfaced** |
| 6 | Theorem 3(b): "the union S*" | Under plain nonces the union is not well-defined as a function of the two logs — well-definedness is what structural nonces buy (D5, M2) | **Sharpened** |
| 7 | RF-C1: overclaim "up to 2×" | Exactly 2×, attained (R4) | **Constant fixed** |
| 8 | Theorem 5(iii): "err ≥ ρF-band mass, every policy" | On two-phase adversaries: err == floor, identical across the whole policy class — policy collapse (M1/W4); all-policy generality still pen | **Strengthened (bounded) + honestly bounded** |
| 9 | Counterexamples 2 and 7: single constructions | Generic in the bounded worlds: 6,684/6,684 collisions diverge; 40/178 fiber pairs kill; 68,576/68,576 interleavings converge (M2) | **Genericity witnessed** |
| 10 | "Round-trips byte-exact" | Canonical-form equality — a stated commitment, not a given (D4) | **Precised** |

**Unchanged, and that is a finding too:** the theorem statements themselves (Lemma 4, Theorems 4–5, Theorems 1/3/6/8, FC-T1) needed no repair — the metal's six bites were all at the encoding layer *except* R1 and R2, and both of those lived in proof *mechanism* prose, not in the theorem statements. The corpus's habit of stating attainment and tightness explicitly is what made the outbound trip cheap; the return trip's cost was concentrated exactly where the papers were loosest — adversary-realization legality and boundary conventions.

---

*Return leg, 2026-08-29. The metal held every theorem it was handed — and handed back two repairs, six decisions, two new questions, and a doctrine: the checkable form of a theorem is a commitment, and commitments deserve a ledger. The round trip changes both ends; this file is the passport stamp.*
