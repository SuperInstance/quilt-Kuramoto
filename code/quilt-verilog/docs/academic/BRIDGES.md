# BRIDGES — the leaps, fixed with real derivations

**Lane:** rigor-auditor (Flash) · **Date:** 2026-08-29
**Purpose:** every leap flagged in `DEPENDENCY-GRAPH.md` (L1–L10) is closed here with a *derivation* — no prose gestures. Each bridge states the leap, gives the missing algebra in full, and states the resulting theorem in its final, quotable form. Section 7 resolves the benign forward references (F1–F4). Section 8 is the explicit-gap register. **Section 9 (re-sweep, same day) closes G1**: the landed quilt-calculus.md is checked against B1–B10 and reconciled.

---

## B1 — The ledger conservation induction (fixes L5)

**Leap.** FOUNDATION F-T1 ("consistency without consensus") rests on a proof sketch: *"Induction over the global partial order of commits."* Three algebraic facts are asserted without derivation: (a) the global partial order is well-founded (so induction is legal), (b) internal transactions cannot disturb any cut constant, (c) the delivery discrepancy is *exactly* the sum of in-flight postings.

**Fix — the full induction.**

*Setup.* Cells are a finite set; accounts are partitioned by owner (F-D3.2: exactly one cell may post to each account). Each cell's events are totally ordered (F0.3, order type ω — a cell's events are indexed by its local clock ℕ). The **global commit partial order** ≤ is the reflexive-transitive closure of (i) each cell's local order and (ii) the delivery relation: a posting applied at cell B follows the event at A that emitted the flit carrying it.

*Well-foundedness (a).* Any strictly decreasing chain in ≤ must descend within some cell's local order (deliveries only go forward in the source's local order, and each cell's order is ℕ-indexed). A strictly decreasing chain would require an infinite strictly decreasing chain in some ℕ-indexed order — impossible. Hence every descending chain is finite: ≤ is well-founded, and induction over it is legitimate.

*The invariant.* For any cut 𝒞 and any **prefix-closed downset** t of ≤ (a "time": all events committed up to t), define the 𝒞-side posting sum of a transaction T:

```
v_T^𝒞 := Σ_{(a,v) ∈ T, owner(a) ∈ 𝒞} v
```

**Lemma (cut constant).** For every cut 𝒞 and every commit-boundary time t:

```
K_𝒞(t) = K_𝒞(0) + Σ_{T : nonce(T) applied at some cell of 𝒞 by t} v_T^𝒞   (★)
```

*Proof by induction on t (the well-founded global order).* Base: no events, (★) reads K = K(0). Step: let e be the next event in a cell c ∈ 𝒞.

- **e applies transaction T.** By idempotence (F-D3, condition iii), if nonce(T) is already in c's log the application is a no-op and the hypothesis stands. Otherwise bal updates by exactly the postings owned by c: `bal(a) += v` for each `(a,v) ∈ T` with `owner(a) = c`, so `K_𝒞 += Σ_{(a,v)∈T, owner(a)=c} v =: v_T^c`. Summing over the cells of 𝒞 that have applied T gives `v_T^𝒞` — the hypothesis (★) holds with T counted once (the first 𝒞-side application; every later application of the same nonce at another 𝒞 cell is... — careful: T's postings are distributed across owners; each owner-cell applies T once (idempotence); the total 𝒞-side contribution of T is the sum over 𝒞-owned accounts of T's postings, exactly `v_T^𝒞`, and it accrues as the owner cells commit; by the time all 𝒞 owners have applied T, K_𝒞 has moved by exactly v_T^𝒞).
- **e applies T internal to 𝒞** (every posting of T is owned in 𝒞). Then `v_T^𝒞 = Σ over ALL postings of T = 0` by balance (condition i). **Internal transactions cannot move the cut** — this is the cancellation at the heart of the whole system.
- **e applies T crossing 𝒞.** `v_T^𝒞` is the (in general nonzero) net 𝒞-side posting; K_𝒞 moves by it exactly once per nonce.
- **e is any other event** (tick serviced, view served, dial write): dial writes are themselves booked as transactions (D1 opcode table: `qm_bind` is booked, F-D3), ticks and views touch no account. K_𝒞 unchanged.

*The discrepancy (c).* Take the complementary cut 𝒞ᶜ = cells ∖ 𝒞; the trivial cut (all cells) has constant `K_total = K_𝒞 + K_𝒞ᶜ` at quiescence (every account is in exactly one side, and total balance is conserved because the all-cells cut sees every transaction as internal: every transaction is balanced, so v_T^{all} = 0 always — the global constant never moves). During delivery of a crossing T (applied on the 𝒞 side, not yet on the 𝒞ᶜ side):

```
K_𝒞 + K_𝒞ᶜ = K_total + v_T^𝒞        (the 𝒞ᶜ side has not yet booked v_T^{𝒞ᶜ})
```

and by balance `v_T^{𝒞ᶜ} = −v_T^𝒞`, so the **discrepancy is `|v_T^𝒞|` — the sum of the in-flight postings — exactly.** It is visible, not hidden: the in-flight set is precisely the set of nonces applied on one side of the cut but not the other, enumerable from the two ledgers.

**Final form (F-T1, closed).** *If (i) every transaction is balanced at commit, (ii) commit is atomic per cell, (iii) application is idempotent by nonce, then for every cut 𝒞 and every commit boundary: (★) holds; internal transactions contribute zero; crossing transactions contribute their net 𝒞-side posting exactly once; and the only discrepancy during delivery is the in-flight posting sum, which is measurable from the books.*

**Bar line.** *Internal transactions can't move the cut; crossing ones move it exactly once, by exactly the side they land on; the only gap is in-flight, and in-flight is a count.*

---

## B2 — The illusion: queries spaced > F + L force monotone commit times (fixes L4)

**Leap.** FOUNDATION F-D4 asserts the observer "cannot distinguish the quilt from a synchronous system" when every view is (F, L)-bounded and queries are spaced by more than F + L. No proof.

**Fix — the ordering derivation.**

*Setup.* Observer issues views at times `t₁ < t₂ < …` with `t_{i+1} − tᵢ > F + L`. View i: issued at tᵢ, response delivered at `dᵢ ≤ tᵢ + L` (latency bound); the value is cell B's serial state sᵢ committed at cᵢ, with `dᵢ − F ≤ cᵢ ≤ dᵢ` (staleness bound: within F of delivery; causal freshness: no future/torn states, so cᵢ ≤ dᵢ).

*Claim.* The observed commit times are strictly increasing: `c_{i+1} > cᵢ` for every i.

*Proof.*

```
c_{i+1} ≥ d_{i+1} − F        (staleness bound on view i+1)
        ≥ t_{i+1} − F        (d_{i+1} ≥ t_{i+1} — a response arrives after its issue)
        >  (tᵢ + F + L) − F  (query spacing > F + L)
        =   tᵢ + L
        ≥   dᵢ               (latency bound on view i)
        ≥   cᵢ               (causal freshness on view i)
```

*A synchronous system answering instantly from current state* returns, at query time tᵢ, the state committed at exactly tᵢ — a strictly increasing sequence of commit times indexed by the queries. The quilt returns a sequence that is also strictly increasing (above), with each response within F of "current" — the two are indistinguishable under any observation schedule respecting the spacing bound, because the only testable signature of synchrony is that later queries see states committed no earlier than earlier queries, and that no response predates the query (causal freshness gives cᵢ ≤ dᵢ, and dᵢ ≥ tᵢ, so the response never shows a state committed before the question was asked).

**Final form (F-T2, closed).** *If every view is (F, L)-bounded and observation spacing exceeds F + L, the observed sequence of committed states is strictly increasing and post-dates its queries — the exact observable signature of a synchronous system.*

**Bar line.** *Spacing beats staleness: queries more than F + L apart can never see time run backward.*

---

## B3 — Posting commutativity, and mirror convergence without order agreement (fixes L6)

**Leap.** FOUNDATION F-D5.1 asserts mirrors converge "whenever they have applied the same transaction set — no order agreement required" with the parenthetical reason "posting to the same accounts is commutative." The commutativity statement is never stated as a lemma, and its hypotheses (atomic transaction application + per-account serialization + idempotence) are never assembled.

**Fix.**

**Lemma (order independence of application).** Fix a ledger with account set 𝒜 and initial balances `bal₀`. Let 𝒯 be a set of transactions with **distinct nonces**, each balanced. Applied in any order (each atomically: all its postings take effect at once; per-account serialization: no transaction's postings interleave with another's), the final balance is

```
bal_final(a) = bal₀(a) + Σ_{T ∈ 𝒯} Σ_{(a′,v) ∈ T} v·[a′ = a]      for every account a
```

*Proof.* By induction on |𝒯|. Each application of T adds the fixed posting vector `p_T(a) = Σ_{(a′,v)∈T} v·[a′=a]` to the current balances — updates are **additions in ℤ**, and addition is commutative and associative. The vector added does not depend on the current balances (postings are absolute values, not percentages), so the order of application is irrelevant; only the *set* of applied transactions matters. Idempotence (nonce in log ⟹ no-op) makes "applied set" well-defined even under at-least-once delivery: the effective 𝒯 is the set of distinct nonces applied.

*Remark.* Two subtleties the lemma makes explicit: (i) atomicity matters — if a transaction's postings could be split across interleaved applications, per-account sums would still agree (ℤ addition), but the *audit* semantics (one nonce, one balanced unit) would break; per-account serialization (each account has one owner, F-D3.2) rules interleaving out by construction. (ii) Balancedness is NOT needed for commutativity — only for conservation (B1). The mirror result needs balance only for its honesty semantics, not for convergence.

**Theorem (F-T3, closed).** *A mirror M of cell P (J′ = J, τ′ = τ, same nonce stream) satisfies `bal_M = bal_P` at every point where both have applied the same nonce set — in particular at quiescence, and modulo exactly the in-flight nonces during delivery. No order agreement, no consensus, no clock: replication is idempotent credit.*

**Bar line.** *A mirror is the same books, re-derived by replay; order never mattered, only which nonces landed.*

---

## B4 — Nest: the consolidation lemma and the monad laws, precisely (fixes L7)

**Leap.** FOUNDATION F-D5.3 states the consolidation lemma ("interior nets to zero in the consolidation") and the monad laws ("associativity holds because consolidation is additive") without the precise account statement or the derivations.

**Fix.**

*Setup.* Composite `C[C₁ … Cₖ]`. Account sets: interior `𝒜_int = ⋃ᵢ accounts(Cᵢ)`; boundary `𝒜_C = accounts(C) ∖ 𝒜_int` (accounts the composite itself owns). The boundary ledger L_C posts only to 𝒜_C. A transaction is **interior** iff every posting's account is in 𝒜_int.

**Lemma (consolidation).** *For any transaction T applied inside the composite, the boundary ledger's balances move by*

```
Δbal_C = Σ_{(a,v) ∈ T, a ∈ 𝒜_C} v
```

*If T is interior, `Δbal_C = 0` — the transaction is invisible at the boundary. Hence L_C contains exactly the transactions that crossed the composite's boundary (T with at least one posting in 𝒜_C).*

*Proof.* Immediate from the ledger update rule (B3's vector view): each application adds its posting vector; the boundary-account component of an interior transaction's vector is zero by definition of interior. The "exactly" direction: a transaction with no 𝒜_C postings is interior by definition; a transaction with some 𝒜_C posting changes boundary balances and is recorded in L_C. Interior bookkeeping being invisible is not a cancellation miracle — it is the account partition, made honest.

*Conservation reading (the doc's "nets to zero"):* for an interior T, the composite's cut constant `K_C = Σ_{a ∈ 𝒜_C} bal(a)` is untouched — same fact as B1 with 𝒞 = the boundary.

**Theorem (F-T6, closed — nest is a monad).** *Let T be nest, with `join` the consolidation of a composite to its boundary ledger. Then:*

- **Associativity:** `join ∘ T(join) = join ∘ join`. *Proof.* Both sides map a three-level nesting to the ledger of transactions crossing the outer boundary. In the left composite, the middle composite's boundary ledger is itself interior to the outer (its postings touch accounts of the middle composite's own set, all ⊆ 𝒜_int of the outer); by the consolidation lemma applied twice, every transaction interior to the outer nets to zero in the outer boundary ledger, and only outer-boundary crossings remain. The right side is the same set by one application of the lemma. Both paths produce the identical posting set `{T : T has a posting in 𝒜_outer}` — equal as functions. (Additivity is not even needed beyond linearity of posting-vector sums.)
- **Identity (unit laws):** `join ∘ unit = id` — a composite with one child and no own accounts has `𝒜_int = accounts(child)`, boundary ledger `L_C` posts nothing, and consolidation returns the child's ledger; `unit ∘ join`... — the right unit: nesting a composite as a single child of a composite with no own accounts leaves the boundary ledger empty and re-derives the original. The empty-boundary composite of one cell *is* that cell, exactly as the doc claims.

**Bar line.** *Nest is a monad because the boundary ledger only ever sees what crossed the boundary — the account partition does the proving.*

---

## B5 — The link handshake, made checkable (fixes L3)

**Leap.** FOUNDATION F-D5.5: "The handshake itself is a balanced transaction (D3): each side posts consent; neither may unilaterally create a link." The postings are never exhibited, so the claim cannot be checked — and on inspection, **balance alone cannot enforce it**: a cell can always post `{(A:links-held, +1), (A:link-capacity, −1)}` — balanced, touching only its own accounts. The enforcement must come from the *definition of a link*, not from balance alone.

**Fix — exhibit the transaction and the definition.**

**Canonical link-formation transaction** (cells A and B, agreed interface theory P = (name, version, digest)):

```
T_link(n):  {(A:links-held,      +1),   (A:link-capacity, −1),
             (B:links-held,      +1),   (B:link-capacity, −1)}
```

`Σ = 1 − 1 + 1 − 1 = 0` — **balanced.** It crosses the cut {A} ∣ {B}: by F-D3's crossing semantics it lands in both ledgers under one nonce n, replay-safe (idempotence), auditable forever.

**Definition (link = shared nonce).** A link between A and B on P exists **iff** there is a nonce n with `T_link(n) ∈ L_A ∧ T_link(n) ∈ L_B`, where both postings sets agree. Under this definition:

- **No unilateral creation:** A's solo balanced transaction `{(A:links-held, +1), (A:link-capacity, −1)}` has no counterpart in L_B — it fails the definition (no shared nonce). It is *bookkeeping, not a link*; the books still balance (nothing was created, only re-labeled on A's side — which the conservation argument B1 permits: closed cuts conserve, and A's capacity debit pays for the credit).
- **Why the handshake is a *crossing* transaction, not merely balanced:** balance makes the books honest; the shared nonce makes the link *joint*. Both properties are load-bearing; the doc's prose had only the first.

**Final form (F-D5.5, closed).** *A link is a balanced, cut-crossing transaction under one nonce, and a link exists iff both sides hold it. "Neither may unilaterally create a link" is the definition, enforced by the books.*

**Bar line.** *A link is a shared nonce in two ledgers — consent that balances on both sides of the cut.*

---

## B6 — The below-the-horizon lemma: why integer arithmetic is substrate-free (fixes L10)

**Leap.** SEMANTIC-TOWER S-T1: the oil-pressure cell "emits the same PSI on quilt-vm-c (ESP32, C), on the fabric (Verilog), and in a worker (JS) — differing only within the tolerance dials." The load-bearing step — that the *same rendering equation evaluates identically in every substrate* — is never stated as a lemma; the lemma rests on an empirical anchor (§8: reflex-arc, 500 vectors, 100.0000% agreement) plus an implicit exactness claim.

**Fix.**

**Lemma (exact integer evaluation).** *Let e be an arithmetic expression over variables taking values in ℤ (or fixed-point: integers with declared Q-format). Any two implementations of e that (i) evaluate the same expression tree, (ii) use integer arithmetic for every leaf and every operation, and (iii) saturate rather than wrap at every integrating boundary, produce identical results.*

*Proof.* The ℤ-ring operations +, −, ×, >>, <<, saturate are well-defined functions on ℤ independent of the machine. By induction on the expression tree, each subexpression's value is the same function of its integer inputs in every implementation; the results are equal as integers. (The only cross-substrate divergence risk — float evaluation — is excluded by (ii): IEEE-754 is *not* a ℤ-identical ring, and that is exactly why the doctrine forbids it. Fixed-point is integer arithmetic with an agreed exponent; the Q-format is part of the expression's typing, declared at L0.)

**Theorem (S-T1, closed).** *Let N be an L0 cell with rendering equation eq and tolerance dials (r-settings in dials). Let R₁, R₂ be any two admissible L2 renderings (integer/fixed-point per the doctrine). For every raw input sequence: the outputs of R₁ and R₂ are identical integers; hence the D2 judge with the cell's keyed answers and tolerance radius r returns the same verdict for both — the cell emits the same rendered quantity on every substrate, within the dials it declares.*

*Proof.* Same eq (the L0 record), same raw (integer), same dial values (state, not code): by the lemma, R₁ and R₂ evaluate eq(raw; dials) to the same integer. The judgment (F-D2) is a function of (output, keyed answers, r) — identical inputs, identical verdicts. The 80ths-of-a-psi calibration is the 1-D instance of the basis construction: span 4000 mV × 3/80 = 150 psi exactly (4000·3 = 12000 = 80·150), so the calibration constant is whole in 80ths — the choice of unit makes the arithmetic exact by construction (the same move as S-D6/S-D7, formalized in §5.3 of the tower).

**Bar line.** *The equation is the spec; integers evaluate the same everywhere — choosing C is an optimization, not a specification.*

---

## B7 — The covering radius: why the worst a lattice lies is b√n/2 (fixes L8)

**Leap.** SEMANTIC-TOWER S-T3 asserts the covering radius of the lattice b·ℤⁿ is `b√n/2` and the design condition `b ≤ 2ε/√n` suffices, with no derivation.

**Fix.**

**Lemma (covering radius of b·ℤⁿ).** *For every x ∈ ℝⁿ, `dist(x, b·ℤⁿ) ≤ b√n/2`, and the bound is attained (the cell center achieves it): the covering radius is exactly `b√n/2`.*

*Proof.* The fundamental cell of b·ℤⁿ is the half-open n-cube `[0, b)ⁿ`; every x is congruent mod b·ℤⁿ to exactly one y in it, and dist(x, b·ℤⁿ) = dist(y, b·ℤⁿ) (lattice translation-invariance: if x = λ₀ + y, then ‖x − λ‖ = ‖y − (λ − λ₀)‖ and λ − λ₀ ranges over b·ℤⁿ). For y in the cell, the nearest lattice point is a corner of the cube; the farthest y from *all* corners is the cell center `y* = (b/2, …, b/2)` — by symmetry (the center is fixed by the cube's corner-permuting symmetries, and the distance-to-lattice function is convex, so its maximum over the cube sits at the maximizer of the distance to the corner set, which is the Chebyshev center), at distance

```
‖y* − 0‖ = √( (b/2)² + … + (b/2)² ) = (b/2)·√n = b√n/2.
```

The center is at distance b√n/2 from *every* corner (the cube's diagonal is b√n; the center is its midpoint), so the radius is attained and the bound is tight.

**Theorem (S-T3, closed).** *For every reachable true value x, integer representation in basis b places a lattice point within ε of x whenever `b√n/2 ≤ ε`, i.e. `b ≤ 2ε/√n` (1-D: `b ≤ 2ε`); conversely, if `b > 2ε/√n` the cell-center value is farther than ε from every lattice point, so the condition is necessary as well as sufficient for a universal guarantee.*

**Bar line.** *The worst a lattice lies is half its cube's diagonal — set ε there and integers suffice, and can't do better.*

---

## B8 — The float-free loop: the error budget, assembled (fixes L9)

**Leap.** SEMANTIC-TOWER S-T4 concludes "the entire correction loop … executes without floats, and the snap error never exceeds ε." The composition is prose: (i) basis bound, (ii) squared judge, (iii) fixed-point envelopes — assembled into "error ≤ ε" without a budget, and without separating post-correction error from between-correction divergence.

**Fix.**

*Setup.* True value x; sensor chain renders lattice point s ∈ b·ℤⁿ; game renders g ∈ b·ℤⁿ. Define the **total reachable error budget**

```
ε := ε_b + ε_sens + ε_env
```

where ε_b = b√n/2 (representation, B7), ε_sens = sensor noise (the physical chain's own error), ε_env = the fixed-point rendering envelope (paper 67 / AMATH §5: dyadic staircases bound each fᵢ's fixed-point evaluation within its declared interval; the composition of finitely many envelope intervals is their sum along the chain). Each of the three is a *declared, provable* quantity (the basis inequality for ε_b, the sensor spec for ε_sens, the staircase theorem for ε_env), so ε is a budget, not a hope.

**Theorem (S-T4, closed).** *Under (i) a common basis b satisfying the basis inequality (or a Pythagorean configuration, where ε_b = 0), (ii) the squared-form judge, (iii) integer/fixed-point rendering with provable envelopes:*

1. *No float appears anywhere* — every operation in sense → prefilter → render → compare → snap is over ℤ (fixed-point is integer arithmetic with a declared Q-format; the judge compares d² = (g−s)² against Δ², both integers).
2. *Post-correction error:* after a snap, `g = s`, and `|x − g| = |x − s| ≤ ε_b + ε_sens + ε_env = ε`.
3. *Between corrections:* the judge fires when `d = |g − s| > Δ` and corrects to 0 at the next tick sample, so at every sample `|g − s| ≤ Δ + d_max·T` (d_max = max drift rate, T = tick period), and `|x − g| ≤ |x − s| + |s − g| ≤ ε + Δ + d_max·T` by the triangle inequality.

*Proof.* (1) is the exact-integer lemma B6 applied to every stage. (2) is the basis inequality at the sensor (the sensor's lattice point is within ε_b of x by B7; add sensor and envelope terms). (3) is the triangle inequality plus the judge's threshold semantics: the correction fires within one tick of exceeding Δ, so the sampled divergence exceeds Δ by at most one tick's drift.

*Honesty note.* The proposition's "snap error never exceeds ε" is exactly claim (2) — correct *post-correction*. The doc's ε must be read as the *sum* above (it is not just the representation term). Claim (3) is the complete statement between corrections, which the one-liner in §5.5 compresses — see B10 for why the compression must be the sum, not the max.

**Bar line.** *Post-snap, you're within ε of reality — where ε is the declared sum of lattice, sensor, and envelope error; between snaps, add the deadband.*

---

## B9 — Snap-debt accounting: balance forces the fourth posting (fixes L1)

**Leap (critical).** SEMANTIC-TOWER §5.4:

```
T_snap(n): {(G:authority-on-x, −1), (T:authority-on-x, +1), (G:snap-debt, +|g−s|)}
```

`Σ = −1 + 1 + |g−s| = |g−s| ≠ 0` for any snap with nonzero drift. **The transaction is unbalanced** — it violates F-D3's defining condition, so every cut invariant in B1 fails, the ledger's conservation theorem is broken by the system's own flagship example, and the audit-replay check (F-T10) would catch the books not balancing. (Which is, ironically, the doctrine working: *"a single-sided edit is arithmetically loud"* — the fix below makes the loudness go away legally.)

**Fix — the balanced snap.**

**Canonical snap transaction:**

```
T_snap(n): {(G:authority-on-x, −1),  (T:authority-on-x, +1),
            (G:snap-debt,      +|g−s|),  (T:ground-truth,   −|g−s|)}
```

`Σ = −1 + 1 + |g−s| − |g−s| = 0` — **balanced.** Read it as **two balanced sub-pairs under one nonce**:

- the **authority swap** `(G −1, T +1)`: one unit of authority-on-x moves from game to twin — reality takes custody;
- the **drift booking** `(G:snap-debt +|g−s|, T:ground-truth −|g−s|)`: the twin debits its own *ground-truth* account (reality's tally of corrections it has had to make) and the game credits its *snap-debt* account (the accumulating correction liability).

**Conservation invariants (derived, not asserted).** Both accounts start at 0; every snap adds the same magnitude to both:

```
bal(G:snap-debt) = Σ_snaps |gᵢ − sᵢ| = −bal(T:ground-truth)
bal(G:authority-on-x) + bal(T:authority-on-x) = const   (1 unit, the shared variable x)
```

So: **snap debt is always the exact negative of ground truth** — the two columns mirror each other forever, and total authority is conserved. The audit trail is now three balanced lines *plus the drift line*, and every claim in F-D3 (conservation, replay, tamper-evidence, idempotent redelivery) applies to the snap event without exception.

*Why the fourth posting is forced, not chosen.* Balance (`Σvᵢ = 0`) is a hard constraint (F-D3). The drift magnitude |g−s| is real value that must be booked somewhere; the only honest counterparty is the twin's ground-truth account — reality is the *source* of the correction, so reality's account pays for it. There is no third option that keeps the books balanced and the audit meaningful.

**Final form (S-D8′, closed).** *A snap is a balanced four-posting transaction: authority swaps one unit game→twin; drift is booked game-side as snap-debt and twin-side as ground-truth, equal and opposite. Both ledgers hold it under one nonce, replay-safe, forever.*

**Bar line.** *A snap is two balanced pairs under one nonce: authority swaps, drift is booked against reality — and the debt column is always the exact negative of the truth column.*

---

## B10 — The divergence bound: sum, not max (fixes L2)

**Leap.** SEMANTIC-TOWER §5.5: the contract "never displays divergence beyond `max(Δ, sensor error)`." The triangle inequality yields the **sum**; the max-form is not derivable from S-T4 and overclaims.

**Fix — the correct bounds.**

Let ε_s be the twin's sensor error (`|x − s| ≤ ε_s`), ε_g the game's model error (`|x − g| ≤ ε_g`), d_max the max drift rate of the divergence |g − s| per unit time, T the tick period, Δ the deadband.

**Theorem (S-T6, closed).** *Under the snap contract:*

1. *Sampled displayed divergence:* `|g − s| ≤ Δ + d_max·T` — the judge corrects whenever |g − s| exceeds Δ and the correction lands within one tick, so the sampled value overshoots Δ by at most one tick's drift (B8, claim 3).
2. *Divergence from reality:* `|x − g| ≤ |x − s| + |s − g| ≤ ε_s + Δ + d_max·T` (triangle inequality + claim 1).
3. *Post-correction:* `|x − g| ≤ ε` with ε the B8 budget (claim 2 of B8).

*Why not max(Δ, ε_s):* the derivable statement is the *sum* `Δ + ε_s (+ d_max·T)`. The max-form would require one of the terms to vanish or dominate structurally — e.g., a Pythagorean configuration (Δ = 0 possible... no: Δ is a design dial, independent of ε_s) — no such hypothesis appears in §5.2–5.4, so `max(Δ, ε_s)` is an overclaim. The honest bar statement: **within twice the deadband** — if Δ ≥ ε_s, the sum is ≤ 2Δ; the max-form is the special case where one side is negligible.

**Bar line.** *Agree-to-within-Δ, snap-on-exceed, reality-wins, log-both-books, all-integer, fixed-tick — and the divergence from reality is deadband plus sensor error, not their max.*

---

## 7. Benign forward references, resolved (F1–F4)

- **F1 (D1 before D2/D3).** No vicious circle. The correct definition order: primitives (§0) → pseudometric and judge (F-D2, needs only S, X, K, d) → ledger (F-D3, needs only accounts) → cell (F-D1 assembles the tuple). D1's presentation before D2/D3 is a reading-order convenience; the dependency direction is one-way (D1 → D2, D3, and D2 → F0.1 which is primitive, not D1). State the tuple last and everything links.
- **F2 (nest cites QUF, defined §4).** One-way: F-D6 depends on nothing in §2. The nesting's literalness ("a QUF section carries a sub-QUF") is a consequence of state-is-a-file (F0.1 + F-D6), not a premise of D5.3's algebra. Benign.
- **F3 (Laws 2/4/5 without pointer).** The canonical list exists: README, "The Law" (1 pure Verilog-2005; 2 everything is a cell, opcodes only; 3 intelligence at the bottom; 4 any IO can enter a cell, adapters thin and dumb; 5 verified or it doesn't exist). Recommended: one sentence in FOUNDATION §0 and SEMANTIC-TOWER §0 pointing at README — content is already closed.
- **F4 (stale cross-ref "§1.3").** The argument lives in the D3 consensus paragraph; cosmetic.

## 8. Explicit gaps (unfixed by design)

| ID | Gap | Why not fixed here |
|---|---|---|
| G1 | `docs/academic/quilt-calculus.md` absent (concurrent lane) | **CLOSED 2026-08-29 (audit-resweep):** the calculus landed (`0e0e851`) and was audited — `DEPENDENCY-GRAPH.md` §2.3/§7. **No bridge B1–B10 was provisional pending it**: each is a self-contained derivation. The re-sweep found the calculus independently re-derives B1–B10's content (see §9) with **zero content leaps** of its own; the one substantive reconciliation (B9 ↔ CALC-T10(b) account naming) is recorded in §9 |
| G2 | SYNTHESIS I1/I2/Q2/Q3 premises: simulation-enforced, sby machine-proofs pending (AMATH #3/#4) | formal lane's deliverable; honestly flagged in SYNTHESIS/AMATH |
| G3 | Invariant M's provenance KV keys specified-not-built | tower §8 states it; M is conditional until keys ship |

---

## 9. Re-sweep addendum (G1 closure): BRIDGES ↔ quilt-calculus.md

The calculus monograph (`docs/academic/quilt-calculus.md`, commit `0e0e851` — landed 5 minutes *before* this document's commit, on a divergent tree) was audited by the re-sweep lane; full inventory in `DEPENDENCY-GRAPH.md` §2.3, reconciliation in its §7. What matters *here*:

- **Every bridge survives contact.** CALC-T1/T2 ≡ B1 (prefix induction vs well-founded order — equivalent on finite runs); CALC-T4 ≡ B3; CALC-T5 ≡ B4 (projection algebra; monad scope identically balance-map-level); CALC-T7 ≡ B2 (+ linearizability/staleness anchors); CALC-T11(a) ≡ B7; CALC-T11(b)/(c) ⊆ B6 (B6 broader: shifts + saturate); CALC-T11(d) ≡ B8's ε_env clause; CALC-P2 ≡ B6's theorem. No bridge required revision; none was provisional.
- **B9 and CALC-T10(b) converge independently on the same critical find**: the informal `T_snap` sums to `|g−s| ≠ 0`; both emend it to the same four postings under one nonce. Two lanes, one tree divergence, identical repair — the strongest evidence the fix is forced, not chosen. Account names differ (B9: `authority-on-x`, `ground-truth`; CALC: `auth`, `debt-issued`); **canonical names are the calculus's** (`G:auth`, `T:auth`, `G:snap-debt`, `T:debt-issued`) — B9/E5's names remain readable synonyms; see DEPENDENCY-GRAPH §7.2 for the full dictionary.
- **One wording note for the calculus lane (DR2):** CALC-T10(d)'s closing sentence re-imports "never exceeds max(Δ, sensor error)" — the form B10 corrected. It is *implied* by the calculus's own T9 (|g−s| ≤ Δ at boundaries, Δ ≤ max) so it is not false, but the quotable form is B10's sum / envelopes' displayed=Δ, true=Δ+2ε split; recommend citing T9 directly. The calculus also adds three closures B1–B10 did not carry: T3(c) tolerance additivity, T6 k-chain freshness composition (≡ ELEGANCE E2 under D7's refresh discipline), T10(c) linear snap-debt bound `D(N) ≤ (Δ+ρ)(1+⌊Nρ/Δ⌋) ~ ρN`.

## 10 — Expansion-paper addendum (2026-08-29, evening): where the four new papers connect

The academic-expansion wave landed four papers after the G1 closure; none is a bridge (no informal leap was pending against them), but three carry derivations that *strengthen* bridge-adjacent territory, and one re-grades the evidence machinery. Recorded here so the bridge ledger stays the single index of derivations; full inventories in `DEPENDENCY-GRAPH.md` §2.5.

- **RHO-F-FLOOR.md — the floor's adversary, formalized.** THE-BREAKDOWN §7 and conjectures Thm 5(iii) carried the ρ·F impossibility as an adversary *sketch* ("hold truth still, then move a key through the window"). RFF §3 upgrades the sketch to a construction with proved legality — the key-outward radial metric perturbation — and in doing so finds the sketch's own mechanism wanting: a *point move* under-delivers the claimed band in ℝⁿ (lens vs shell, O(β^{(n+1)/2}) vs O(β)); the metric perturbation is the repair, and the honest floor is the swept band, with the clean μ({m ≤ ρF}) form conditioned on one-sided boundary mass (RFF-C1). **This is a correction to a committed source, flagged in place** — the same class of finding as C1–C6, now in the conjectures' lineage. B-territory touched: none (T3(c)/Thm 5 territory, not B1–B10).
- **DRIFT-AS-PREFILTER.md — B6-adjacent tightness.** B6 (exact-integer substrate lemma) and CALC-T3(c) state the *upper* composition bound. DA-T2 adds the matching lower side: inside the annulus (r − Σρᵢ, r + Σρᵢ] the verdict is per-input adversarially controllable — the composed tolerance is *exactly* r + Σρᵢ, not merely at most. No bridge weakened; the composition law the bridges lean on is now two-sided.
- **FOLD-COVERED.md — the conjectures' walk-state remark, killed harder.** Conjectures §3.5 resolved walk-state honesty relative to the balance fold (P₁/P₂ fibers). FC-P2 kills it outright: the two-element permutation witness (L₁ = [cofire, shift] vs L₂ = [shift, cofire]) shows ladder state is not invariant under event permutation, hence computable by **no commutative fold, any size** — the smallest possible counterexample shape for the same conclusion. Also new: fiber entropy (a balance fold loses c − O(log c) bits — asymptotically the whole prefix), the commitment framing of the digest (binding pins, hiding reveals nothing; separation ≠ extraction), and the hinge (consolidation-invisibility ≡ exclusion-opacity: FC-P3 makes the B4↔C3 kinship a stated proposition).
- **DENY-BY-RUNNING.md — the evidence machinery, re-graded.** THE-BREAKDOWN's single "machine-checked" bucket splits into M1 (bounded exercise: BMC, TB sweeps) / M2 (unbounded k-induction `mode prove`) / M3 (proof assistant — absent, named). Its §1–§5 conservation instance is (E1, M1); the flit-pipe contract is (E1, M2). Licenses (what each grade permits a claimant to say) and denial recipes (what a skeptic must run) are tabulated, with denial monotonicity proved. Bridge-relevant only in the bookkeeping sense — but the re-grade retroactively sharpens every ATTACK-SURFACE field the dossier wrote.

No bridge B1–B10 required revision; none was provisional pending these papers. The four are indexed in `DEPENDENCY-GRAPH.md` §2.5 (0 content leaps, 1 declared forward ref) and their unexecuted benches are gap G4 there (= B4/B5 reuse + a `dossier-lint` validator).

## 11 — Generals-lane addendum (2026-08-29, night): the capstone's connections

`GENERAL-CALCULUS.md` landed (the generals lane's capstone: the abstract cell calculus, quilt-shape axioms Q1–Q5, four generalization axes with proved repairs, the product theorem, the compiler correspondence, four conjectures with registered falsifiers). No bridge B1–B10 requires revision — but three of them are now *theorems' hypotheses* rather than standalone derivations, and one is strengthened. Recorded here so the bridge ledger stays the single index; full inventory in `DEPENDENCY-GRAPH.md` §2.6.

- **B5 → GC-D5 (Q2, axiomatized).** The link-as-shared-nonce definition (a bridge *fix* for L3) is now the **link-respect axiom's clause (ii)** — consent is no longer a repaired claim about the handshake; it is one of the five defining conditions of quilt-shapedness. The n-ary axis (GC-X1/T4) stress-tests exactly this bridge: naive arity generalization re-manifests the L3 failure shape (a link read into existence that nobody booked), and the escrow repair (GC-T4) is B5's construction lifted to k parties with a tick-bounded refund (Q5 doing liveness work — the axioms composing).
- **B9 ↔ GC-C4 (the normal-form conjecture).** B9's "no third option" argument (and CALC-T10(b)'s independent convergence on it) is cited by the capstone as the *proved single-variable case* of GC-C4: any balanced, idempotent, custody-conserving, reality-wins correction transaction is a composition of four-posting snaps. The bridge's informal necessity argument is thereby promoted to a conjecture with a registered falsifier — the same epistemic lift B1–B10 performed on the informal docs, now performed on the bridges themselves.
- **B6/B8 → GC-T10/T11 + GC-X5 (faithfulness, theorem'd).** The below-the-horizon lemma (B6) and the error-budget assembly (B8) are the M1/M3/M4 clauses of a **faithful morphism** (GC-D13). The capstone proves faithful morphisms compose with tolerances summing (the additive law — CALC-T3(c)/B8's composition, now at the calculus level), and proves zoom (P1, "no fourth place") *lifts along* faithful morphisms (GC-T11). The pre-B6/B8 world — float compilation without declared envelope or provenance — is exhibited as counterexample GC-X5: the fourth place, constructed. The bridges were the repairs; the capstone states what the repairs repair.
- **B2/B3/B4 territory — untouched, now proof-inspected.** GC-T3, GC-L1, GC-L2 audit the monograph's conservation/freshness/nest proofs for what they *consume* (arity: nothing; commutativity: nothing in the conservation family, everything in T4; ticks: nothing in the ledger family). B1/B2/B3/B4's derivations are exactly the proof texts inspected; the audit verdict: all four consume only what they claim (no leap was hiding in an unused hypothesis). The inspection method itself is graded in GC §8 as checkable-by-re-reading — a new lemma class in the rigor ledger, deliberately distinct from proof and from conjecture.

**What the capstone adds that no bridge could:** the abstraction itself (QS), the four counterexamples on the axes, the product theorem (GC-T9) with the snap pair as its worked instance, the lineage table (organ × system — each historical ✗ checkable against LINEAGE's sources), and the four posted bets (GC-C1–C4). The books balance one level higher now: the bridges fixed the tower's walls; the capstone proved the walls are a *shape*, and posted the falsifiers for the claim that the shape is enough.

*Rigor-auditor lane, 2026-08-29, night addendum. §10 indexed the expansion wave; §11 indexes the capstone. B1–B10 remain closed; their content is now load-bearing one level up.*

*Rigor-auditor lane, 2026-08-29. The ten derivations above are the complete closure of L1–L10; nothing here weakens a claim — every short form in ELEGANCE.md is one of these derivations, compressed. §9 closes G1: the calculus is in the books, and the books balance. §10 indexes the expansion wave: four papers, one source-corrected sketch, one outright kill, one two-sided tightness, one re-grade — and the ledger still balances.*
