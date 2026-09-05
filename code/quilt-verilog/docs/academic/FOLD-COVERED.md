# FOLD-COVERED — the losslessness theory of ledger compaction: characterization, exclusion impossibility, witness recovery, checkpoint pricing, and the taxonomy of foldable state

**Lane:** academic-expansion (GLM-5.3) · **Date:** 2026-08-29
**Sources upgraded:** `conjectures.md` Part III (C3 attacked: Theorem 6, Counterexample 7, Theorem 8, Corollary 9, the walk-state remark) and, through it, `quilt-calculus.md` T4/T5. Self-contained: the fold theory is rebuilt from the transaction definition up; every proof is here.

> **The contract of this document.** Compaction is the act of throwing a ledger's prefix away and keeping a summary. The theory answers four questions with theorems: **what survives** — exactly the fold-covered queries (FC-T1, the characterization); **what cannot survive** — post-hoc exclusion queries, unconditionally for summary-only schemes and information-theoretically-zero advantage with the digest retained (FC-X1, with the commitment framing that separates *verifiability* from *discoverability*); **what recovery costs** — declared labels restore checkability exactly (FC-T3) and enumeration predicates force Ω(c) checkpoint state (FC-T4), with the fiber-entropy accounting making the loss quantitative (FC-P1: a balance fold loses c − O(log c) bits of a c-bit prefix — asymptotically everything). And one question with a taxonomy: **which states are foldable at all** — the walk-state honesty clause is resolved *more sharply than its source*: walk-state is not merely uncovered by the balance fold; it is computable by **no commutative fold of any size** (FC-P2's permutation argument), so mirror-by-recomputation is not an implementation choice but the unique lossless compaction for stream-state. The hinge closes the paper: consolidation-invisibility and exclusion-opacity are the *same theorem* — invariance on fold fibers — with opposite engineering valence (FC-P3).

**Statement registry.** 7 definitions (FC-D1–D7), 4 theorems (FC-T1–T4), 2 counterexamples (FC-X1, FC-X2), 3 propositions (FC-P1–P3), 3 lemmas (FC-L1–L3), 14 numbered proofs. Grade: **pen + machine-checked (bounded)** — `tools/verifies/c3_fold_bench.py` (2026-08-29, mathmetal lane): 565,551 exact checks, PASS — FC-L1 order-independence, FC-T1 both directions on the enumerated class, FC-X1 concretely (both regimes; FC-L2 hiding advantage exactly 0 over all 256 decision rules), FC-P1 fiber entropy, FC-T4 Ω(c) separation, FC-T3 witnesses. Bounded; bounds printed per run.

---

## 1. Introduction

The calculus's ledger is append-only by construction (D4); any long-running cell must eventually compact — checkpoint a summary, digest the prefix, drop it. The conjecture C3 proposed that this is benign: balance invariants "survive trivially," and *provenance-of-exclusions* — the record of what a downstream consumer did **not** train on — survives digest-truncation. The attack (`conjectures.md` Part III) found the proposal half right and inverted the other half: the "trivially" clause is actually the *characterization theorem* (lossless ⟺ fold-covered), and the exclusions clause is false — you cannot quarantine after the fact what you did not think to count.

This paper is that attack, promoted: the characterization with both directions proved in full (§3); the calculus's own conservation and consolidation theorems exhibited as the first two instances with their fold tables (§4); the exclusion counterexample in both regimes with the random-oracle hiding lemma in its honest commitment framing (§5); the **fiber entropy** accounting — new here — that turns "not answerable" into "c − O(log c) bits gone" (§6); the declared-label recovery construction with the Merkle-witness protocol spelled out to its verification steps (§7); the Ω(c) pricing theorem (§8); and the taxonomy with the permutation argument that kills walk-state foldability *outright* rather than relative to one fold (§9). The hinge — one theorem, two valences — is §10.

The method note before the mathematics: every negative result below is a two-line ledger arithmetic plus a counting argument. There is no cryptography in the impossibility and no hand-waving in the recovery; the one place a computational assumption enters (collision resistance, §7–8) it is named and scoped.

---

## 2. Logs, folds, compaction, and the answering regime

### FC-D1 — Log and transactions

> A **transaction** is T = (n, v_T, π_T): a nonce n, a posting vector v_T ∈ ℤ^{(A)} over a fixed finite account universe A (finite support, per-posting values in ±[1, v_max]), and a **payload** π_T drawn from a finite payload alphabet Π (everything else the transaction carries — amounts' identities, datum fields; the provenance content). A **log** is a finite sequence L = (T₁, …, T_N). Write L = P ⊎ S for the split into a **prefix** P = (T₁..T_c) and **suffix** S — ⊎ is sequence concatenation; when we treat logs as *multisets* (inside folds, FC-D2) the notation drops the order.

### FC-D2 — Summary fold

> A **fold** is a triple (Σ, ⊕, f): Σ a state set, ⊕ : Σ × Σ → Σ **associative and commutative**, f : 𝕋 → Σ the per-transaction map. The fold of a (multi)set of transactions is σ(P) = ⊕_{T ∈ P} f(T) — well-defined without an order by FC-L1 below. The **balance fold** is (ℤ^{(A)}, +, v_T); the **count fold** (ℕ, +, 𝟙); the **Λ-fold** of §7 (ℕ^Λ, +, (q(T))_{q∈Λ}).

### FC-L1 — Order independence (the T4 lemma, abstracted)

> **Lemma.** For any fold and any multiset M: every order of application yields the same σ(M); moreover σ(P ⊎ S) = σ(P) ⊕ σ(S) for multisets P, S.
>
> *Proof.* Induction on |M| appending one element: each append applies ⊕ with f(T); associativity regroups any bracketing, commutativity reorders any two adjacent applications, and adjacent transpositions generate all orders (standard: the symmetric group is generated by adjacent swaps), so all orders agree. The split identity is the same induction run on P then S. ∎
>
> This is the semilattice argument of quilt-calculus T4 (mirror convergence) lifted off the ledger: commutative application *is* the fold law. (A4 nonce-idempotence, which T4 also uses, is not needed for order independence — only for *exactly-once* semantics under at-least-once delivery; the folds here consume multisets, with duplicates already the same transaction.)

### FC-D3 — Compaction scheme

> A **compaction of L = P ⊎ S at checkpoint c** is the object
>
> K_c(L) = ( σ(P), h(P), S )
>
> — the summary fold of the prefix (any fold, chosen by the scheme), a **digest** h(P) (a Merkle root over the prefix, §7; optional in the weakest schemes), and the raw suffix. A scheme is **summary-only** if it retains σ(P) alone (K⁰_c(L) = σ(P)).

### FC-D4 — Answering regime (the honesty clause)

> A query Q (a function on logs) is **answered by the compacted ledger** iff its answer is computable from K_c(L) **alone** — no retained prefix, no external witness, no side information. Queries answered *with* a witness (a third party holding the prefix or a replica) are a separate regime, §7 — conflating the two regimes is the precise slip the original conjecture made, and FC-X1 below is priced in both.

### FC-D5 — Fold-covered

> Q is **fold-covered (by σ)** iff there exists q̂ : Σ → answers with Q(L) = q̂(σ(L)) for every log L — the answer factors through the summary.

### FC-D6 — Losslessness

> A compaction scheme is **lossless for a query class 𝒫** iff for every Q ∈ 𝒫, every log L, and every valid checkpoint c: the answer computed from K_c(L) equals Q(L). (Valid c: 0 ≤ c ≤ |L|; c = 0 and c = |L| degenerate to no compaction and must agree trivially — they are the sanity edges.)

### FC-D7 — Post-hoc predicate

> A query is **post-hoc** if its predicate (the function of transaction payloads it asks about) is chosen **after compaction time** — by whoever audits later. Post-hoc-ness is a property of the *query class*, not the single query: the class of exclusion questions a future auditor may ask is not enumerable at compaction time by definition (this is not an assumption; it is what "future audit" means — the auditor's question is not yet determined).

---

## 3. The characterization theorem

### FC-T1 — Lossless ⟺ fold-covered

> **Theorem.** Fix a compaction scheme with summary fold σ.
>
> **(a) Sufficiency.** If every Q ∈ 𝒫 is fold-covered by σ, the scheme is lossless for 𝒫: answer via q̂( σ(P) ⊕ σ(S) ) = q̂(σ(L)) = Q(L).
>
> **(b) Necessity (summary-only schemes).** If the scheme is summary-only (K⁰), losslessness for 𝒫 forces every Q ∈ 𝒫 to be fold-covered by σ. Contrapositive: if Q is not constant on some fiber of σ — ∃ P₁ ≠ P₂ multisets with σ(P₁) = σ(P₂) and Q(P₁) ≠ Q(P₂) — then for any common suffix S, the two logs L₁ = P₁ ⊎ S, L₂ = P₂ ⊎ S have identical compacted forms but different Q-values, and no function of the compacted form can be right on both.
>
> **(c) The digest does not enlarge the alone-regime (announcement; proof in §5).** Retaining h(P) in addition to σ(P) keeps every fold-covered query answerable and adds *no* answering power against post-hoc queries in the arriving-auditor model (FC-X1 regime 2). What the digest adds is the *witness* regime (§7) — verifiability, not discoverability.
>
> *Proof of (a).* By FC-L1, σ(L) = σ(P ⊎ S) = σ(P) ⊕ σ(S); the compacted object carries both summands; compose with q̂. *Proof of (b).* As displayed: K⁰(L₁) = σ(P₁) = σ(P₂) = K⁰(L₂) since σ(P₁) = σ(P₂); Q(L₁) = Q(P₁) hmm — Q need not split over ⊎; but losslessness at c = |P₁| = |P₂| (both prefixes have the same length, choose S = ∅) gives: the answerer must output Q(L₁) on K⁰(L₁) and Q(L₂) on K⁰(L₂); the inputs are equal, the outputs differ — contradiction. ∎
>
> **The source's "trivially" clause, promoted.** "Balance invariants survive trivially (the summary is a balance)" — FC-T1 says there is nothing *else*: the fold image **is** the answer space of everything compaction can preserve. The characterization is the whole shelf; the engineering question is never "can we compact losslessly?" but "which fold does our query class live in, and do we accept its fibers?"

---

## 4. The calculus's own theorems as folds (the first instances)

### FC-T2 — T4 and T5 are fold instances

> **Theorem.** (i) **Balance queries are covered by the balance fold:** Σ = ℤ^{(A)}, f = v_T, ⊕ = +. Every query of the form "bal(a) = ?" or "Φ(𝒞) = ?" (cut totals) factors: bal(L)(a) = bal(0)(a) + σ(L)(a). This is quilt-calculus T4 read as a fold lemma: mirror convergence *is* order-independence of the balance fold (FC-L1), and every mirror is a live compaction whose summary is its balance map.
>
> (ii) **Boundary queries are covered by the projection fold:** Σ = ℤ^{(E)}, f = π_E ∘ v_T (kill interior coordinates), ⊕ = +. Every query that factors through the exposed-projection of a composite cell is covered; T5's consolidation lemma ("interior activity is externally invisible") **is** the statement that interior transactions lie in the fiber of π_E — κ(v_T) = 0 for interior T. Nest-invisibility is lossless compaction at the nest boundary.
>
> (iii) **Further standard instances** (each an FC-L1 commute): counts (Σ = ℕ), sums of payload values (f = value), min/max (⊕ = min/max on a totally ordered payload field — associative, commutative, idempotent), set union over declared label sets (§7), and products of any of the above (a product of folds is a fold: componentwise ⊕ — closure under pairing).
>
> *Proof.* (i) FC-L1 with the balance fold; the identity bal = bal(0) + σ is T4's induction restated. (ii) π_E is a group homomorphism (coordinate projection); f = π_E ∘ v_T inherits fold-ability; interior transactions have π_E(v_T) = 0 — the consolidation lemma verbatim. (iii) each ⊕ displayed satisfies associativity + commutativity; products inherit componentwise. ∎

---

## 5. The impossibility: post-hoc exclusions

### FC-X1 — The post-hoc exclusion counterexample (both regimes)

> **Construction.** Accounts a, b, c, d; payload alphabet containing the datum values +5, −5, +7, −7. Two prefixes of length 2:
>
> P₁ = [ (n₁, {(a,+5),(b,−5)}, π⁺), (n₂, {(a,−5),(b,+5)}, π⁻) ]
> P₂ = [ (n₃, {(c,+7),(d,−7)}, π⁺′), (n₄, {(c,−7),(d,+7)}, π⁻′) ]
>
> Every transaction is balanced (A1 holds per transaction); both prefixes net every touched account to zero; the payloads differ in the *posted values themselves* (so the +5-content is not recoverable from anywhere else). Then:
>
> **σ_bal(P₁) = σ_bal(P₂) = 0-vector** — identical balance folds.
>
> The post-hoc query Q = "does the compacted-away prefix contain a posting of value +5?" has Q(P₁) = YES, Q(P₂) = NO. This is the exclusion-provenance question in the conjecture's own sense — *what did the downstream consumer not see / not train on* — with the predicate (+5-valued postings) chosen by the future auditor, hence post-hoc by FC-D7.

> **Regime 1 (summary-only; unconditional).** By FC-T1(b) with S = ∅: K⁰(P₁) = K⁰(P₂), Q differs — no answerer exists. This needs no cryptography: the two prefixes are information-theoretically indistinguishable through the fold. **And by FC-T1(b)'s generality, the argument is fold-agnostic**: for *any* fixed summary fold σ′ chosen at compaction time, the auditor's post-hoc predicate can target a fiber of σ′ (with ≥ 2 payload symbols available per transaction, every finite-summary scheme has fibers, and FC-P1's entropy accounting shows they are enormous). The impossibility is not about balance folds; it is about finiteness of foresight.

> **Regime 2 (digest retained; the hiding lemma).** Now K retains h(P_b), b ∈ {0,1} uniform, h a Merkle root modeled as a random oracle. The answerer A holds (σ_bal(P_b), h(P_b)) and must compute Q.
>
> **FC-L2 (hiding).** *In the model where the prefix contents are unknown to A (the arriving-after-truncation auditor: no prefix on hand, no candidate list), A's advantage is exactly 0.* Proof: h(P₁), h(P₂) are random-oracle values at two inputs A cannot name (it does not hold P₁ or P₂ — if it could name them it would hold them); conditioned on either b, the view (σ_bal, h(P_b)) is a fixed value paired with a fresh uniform value — identically distributed under b = 0 and b = 1; any decision rule has advantage exactly 0. ∎
>
> **The commitment framing (the honest scope).** The root h(P) is a **binding commitment** to the prefix-as-string: collision resistance makes it infeasible to find P′ ≠ P with h(P′) = h(P) (two different prefixes with the same root = a Merkle-tree collision or a leaf-hash collision), so the root *pins* the content — while the hiding lemma says it *reveals* nothing to a party without candidate content. **Separation is not extraction.** Two consequences, stated so neither is overread: (i) an auditor who *does* hold a candidate prefix (or a list) can verify it against the root (the witness regime, §7) — the digest preserves **verifiability**; (ii) an auditor who holds nothing cannot even begin — the digest never preserves **discoverability**. If the two candidate prefixes were somehow public knowledge, the root would distinguish them — but it still would not *find* the qualifying transactions for an arbitrary predicate; distinguishing known candidates is verifiability again (check both candidates, accept the matching one).

**Bar line (§5).** *Digest-truncation converts the prefix from data to a commitment. What you folded, you kept; what you digested, you pinned; what you neither folded nor held, you lost — loudly, by arithmetic, not quietly.*

---

## 6. Fiber entropy: pricing the loss in bits

New beyond the source: "not answerable" becomes "how much is gone."

### FC-P1 — The balance fold loses c − O(log c) bits of a c-transaction prefix

> **Proposition.** Fix |A| accounts, per-posting magnitude bound v_max, payload alphabet |Π| ≥ 2. Consider length-c prefixes with the post-hoc enumeration predicate family 𝒬_post (list-the-qualifying-transactions for arbitrary payload predicates).
>
> (i) The balance fold's image has size ≤ (2 c v_max + 1)^{|A|}: each account's balance lies in [−c·v_max, +c·v_max]. Hence log₂ |image| ≤ |A| · log₂(2cv_max + 1) = O(log c).
>
> (ii) There are ≥ 2^c prefixes (binary payload choice per transaction), so the **average fiber size** is ≥ 2^c / (2cv_max+1)^{|A|}, and some fiber is that large or larger: **log₂ |largest fiber| ≥ c − |A|·log₂(2cv_max+1)**.
>
> (iii) Any predicate family that separates a large fiber (two same-fold prefixes with different answers — the post-hoc family does, FC-X1's construction generalizes: on a fiber of size ≥ 2^{c−O(log c)}, payload predicates separate almost all pairs) is unanswerable after compaction, and the **information destroyed is ≥ c − O(log c) bits: asymptotically the entire prefix**.
>
> *Proof.* (i) range counting. (ii) pigeonhole. (iii) FC-T1(b) plus the separation claim: for any two prefixes in a common fiber, some payload predicate distinguishes them iff their payload sequences differ; within a fiber, payload sequences are pairwise distinct (distinct payload sequences can share postings; two prefixes with identical payloads and identical balance fold are identical — nonce order aside — so distinctness of prefixes within a fiber forces distinct payload sequences... for prefixes differing only in nonce *order*, an order-sensitive predicate separates them too; either way the family separates). Hence answers on the fiber are pairwise distinct, and any answering function must be injective on the fiber — but it is a function of the fold, which is *constant* on the fiber: contradiction for any fiber of size ≥ 2. The information reading: the compacted system cannot even *represent* two different answers, so it loses at least log₂(fiber size) bits of answering capacity. ∎
>
> *Honesty note.* (iii)'s "≥ 2 same-fold prefixes" is all FC-X1 needs; the entropy accounting is the quantitative version — it says the balance fold is nearly maximally lossy for provenance, not merely lossy. This also *implies* FC-T4's Ω(c) for the enumeration family (a second, independent road to the lower bound — consistency check passed).

---

## 7. Recovery: declared labels and Merkle witnesses

The impossibility is for *undeclared* predicates. Declared ones — a finite label set Λ of payload predicates q : 𝕋 → {0,1}, fixed **at compaction time** — are recoverable exactly. This section spells out the construction and the check protocol to verification-step level.

### FC-D8 — The augmented checkpoint

> Fix Λ = {q₁, …, q_ℓ}. The **Λ-augmented checkpoint** at c is
>
> K⁺_c(L) = ( σ_bal(P), σ_Λ(P), h(P), S ), with σ_Λ(P) = ( Σ_{T∈P} q_i(T) )_{i≤ℓ} ∈ ℕ^Λ
>
> — the balance fold, the **Λ-fold** (a count fold per declared predicate, FC-T2(iii)), the Merkle root, and the suffix. Size: |A| counters + ℓ counters + the root + the suffix — **permanent, exact, per declared predicate**.

### FC-L3 — Merkle inclusion proofs (the standard machinery, scoped)

> **Construction.** h(P) is the root of the binary hash tree over the prefix: leaves = H(canonical-encoding(T_i)) in order; internal nodes = H(left ∥ right) (duplicate the last child on odd arity, or use a fixed unbalanced rule — any deterministic rule works). An **inclusion proof** for T at position i is the sibling path (log₂ c hashes); **Verify(root, i, T, path)** recomputes upward and compares. Verification cost O(log c); proof size O(log c).
>
> **Soundness.** Under collision resistance of H, no polynomial-time prover produces an accepting proof (root, i, T, path) with T ≠ T_i (the tree's i-th leaf) except with negligible probability: an accepting path either recomputes to the same root through a different leaf preimage (a leaf collision) or diverges from the true tree at some internal node (an internal collision). [Mer80; RFC6962 — the certificate-transparency pattern.]

### FC-T3 — The recovery theorem (declared labels restore checkability)

> **Theorem.** With the Λ-augmented checkpoint:
>
> **(a) Alone-regime counts are exact.** "How many q_i-flagged transactions were excluded?" and "was any?" are answered exactly from σ_Λ(P) — an FC-T1(a) instance (count fold per label).
>
> **(b) Witness-regime chains are fully checkable.** The **quarantine-chain claim** — *every excluded q_i-flagged datum is accounted for* — is verified by this protocol:
> 1. read the count c_i = σ_Λ(P)_i from the checkpoint;
> 2. receive from any witness (the originator, a replica, anyone holding the dropped prefix) an enumeration (T¹, proof¹), …, (T^{c_i}, proof^{c_i}) of purportedly all q_i-flagged prefix transactions;
> 3. for each pair: Verify(h(P), pos_j, T^j, path^j) — inclusion, O(log c);
> 4. check q_i(T^j) = 1 for each — the label applies (a payload-structure check: judgment at r = 0, the thin-adapter discipline);
> 5. check the count: exactly c_i items, positions distinct.
> If all checks pass, the claim holds **except with negligible probability** (a failed item implies a Merkle collision by FC-L3; a short or padded enumeration contradicts the exact count of (a)).
>
> **(c) Pricing.** The checkpoint grows by ℓ counters (+ the root): permanent, exact, per declared predicate. Recovery for a predicate costs one witness enumeration of length ≤ c_i at O(log c) verification each.
>
> *Proof.* (a) FC-T1(a) with the Λ-fold. (b) soundness: an accepted false claim requires either a forged inclusion (collision), a mislabeled item accepted at step 4 (the label check is exact — deterministic predicate on payload), or a count mismatch (σ_Λ is exact by (a)); completeness: the honest witness holding P enumerates the true flagged set with true paths, all checks pass. (c) definition. ∎
>
> **The one-sentence reading.** *Quarantine chains survive compaction exactly for the labels someone had the foresight to fold — and are checkable against anyone's witness; for everything else, §5.*

---

## 8. Pricing: the Ω(c) theorem

### FC-T4 — Enumeration predicates force linear checkpoints

> **Theorem.** If 𝒫 includes enumeration answers for post-hoc predicates (in particular: "list the prefix's transactions satisfying π" for π chosen after compaction), then any compaction lossless for 𝒫 retains Ω(c) state at checkpoint c. No fixed-size scheme — digest-truncation included — repairs FC-X1; the repair set is exactly {declared exact folds (FC-T3), declared ε-approximate folds (below)}.
>
> *Proof.* Length-c prefixes over a binary payload alphabet number ≥ 2^c; the list-predicate for a fixed π has pairwise-distinct answers on any two prefixes with distinct payload sequences... take the family {π_w : w ∈ {0,1}^c} where π_w selects transactions by payload bit: the answer vector over the family distinguishes every prefix pair. Losslessness demands the compacted state distinguish every pair (different answers must map from different states), so |state space| ≥ 2^c ⟹ ≥ c bits. The FC-X1 family carries the same bound with c/2 payload bits (posting values ±5): ≥ c/2 — same Ω. ∎
>
> **The ε-repair (survey, honestly scoped — carried from the source).** For *declared families* of count/existence questions, mergeable sketches give approximate folds: theta sketches for set-union cardinality and inclusion–exclusion over declared exclusion-sets [Coh97; DLT07; DataSketches]; CPC for distinct counts near the information frontier [LS18]; the PODS'12 catalog for frequencies/quantiles [ACH+12]. Each costs its sketch size at its declared ε — FC-T3(c)'s pricing with ε-slack. None touches FC-T4: post-hoc enumeration stays Ω(c), forever. The open residue (carried, unchanged): whether Θ(ε⁻²)-ish per family is *optimal* for exclusion-set provenance specifically is surveyable but unproved here.

---

## 9. The taxonomy of foldable state (walk-state honesty, resolved)

### FC-D9 — The three classes

> For a state-derivable query family 𝒬 (functions of the cell's history):
> - **Class F (fold-covered / semantic state):** every Q ∈ 𝒬 factors through some commutative fold. Members: balances, cut totals, exposed projections, counts, sums, declared-label counters, min/max, declared set unions, declared sketches (approximate). *Compaction: lossless, permanent cost = fold size.*
> - **Class A (approximate, declared):** Q covered up to declared ε by a sketch fold for a family fixed in advance. Members: cardinalities, frequency moments, quantiles over declared payload fields. *Compaction: lossless-at-ε, cost = sketch size.*
> - **Class S (stream-state / order-dependent):** Q is a function of the *ordered, timed* event stream and is not expressible as any commutative fold — any size — because it is not invariant under event permutations. Members: the ladder buckets (walk-state), any age-windowed statistic on unlogged timing, cache states driven by interleaving. *Compaction: the unique lossless compaction is the stream itself (or its timed encoding).*

### FC-P2 — Walk-state is Class S, outright (the permutation argument)

> **Proposition.** (a) *Not a function of the untimed log.* The ladder state (quilt-calculus's walk-state: bucket counters C_i advanced by cofires and shifted on half-life boundaries) is not determined by the transaction log at all: the log of one cell containing a single cofire transaction is compatible with any number of half-life shifts having elapsed (ticks are events of D6 but post no transactions), and the ladder readout differs (the cofire sits in bucket i = number of elapsed shifts). Same log, different states ⟹ no function of the log computes it — fold or otherwise.
>
> (b) *Not foldable even with shifts logged.* Strengthen the setting maximally — post each half-life shift as a (tiny) transaction, so the extended log *does* determine the ladder state. Folding is still impossible: consider the two logs L₁ = [cofire, shift], L₂ = [shift, cofire] — the **same multiset**, different orders. The ladder state after L₁: the cofire is shifted into bucket 1 (readout contribution 2^{K−1}); after L₂: the cofire sits in bucket 0 (contribution 2^K). Different states, different readouts. Every commutative fold satisfies σ(L₁) = σ(L₂) (FC-L1 — order independence *is* commutativity), so no fold computes the ladder: **not Class F, at any state size.**
>
> (c) *Computable by replay.* The ladder state is a straightforward left-to-right scan of the extended (timed) log — cofire: C₀++; shift: rotate. Mirror-by-recomputation (the honesty clause of T4's remark) is this scan: the unique lossless compaction for Class S is the ordered stream.
>
> (d) *The design lever, priced.* Walk-state becomes foldable only by changing what is posted: e.g., a per-tick "clock transaction" every tick (or per shift) makes the ladder a function of the log — but by (b) it *remains non-foldable* (permutation-sensitivity is intrinsic: age-structure is order); it becomes replay-computable from a longer log. The genuine fold that exists inside walk-state is its zeroth-order summary: the **total cofire count** (count fold, Class F). The age-*structured* part is irreducibly Class S. **The honesty clause is a theorem now: keeping the source stream is not an implementation choice; it is the only lossless option, and no posting discipline changes that — posting more only makes the replay input longer.**
>
> *Proof.* (a) two tick schedules, one log. (b) the two-line witness computed above. (c) the scan. (d) (a)–(b) plus the count-fold observation. ∎
>
> *Sharpening note.* The source (`conjectures.md` §3.5 remark) resolved walk-state honesty *relative to the balance fold* ("not fold-covered by the balance fold; P₁/P₂ are the witness fibers"). FC-P2(b) kills it *outright*: no commutative fold, any state space, any size. The witness shrank from a balance-fiber pair to a two-element permutation — the smallest possible counterexample shape.

---

## 10. The hinge: consolidation ≡ exclusion opacity, two valences

### FC-P3 — One theorem, two readings

> **Proposition.** Quilt-calculus T5(a) (consolidation: interior transactions vanish at the composite's boundary; interior bookkeeping is externally invisible) and FC-X1 (post-hoc exclusion queries are unanswerable after compaction) are the *same theorem* — **invariance on fold fibers** — read at two boundaries with opposite engineering valence:
>
> - At a **nest boundary** (fold = π_E): the fiber-invariance is the *feature*. Interior churn cannot leak to the boundary — encapsulation, privacy-by-arithmetic, the safety argument for nesting (T5(b)–(d), the monad laws).
> - At a **compaction boundary** (fold = σ): the fiber-invariance is the *bug*. Interior churn cannot be recovered by the auditor — exclusion opacity, FC-X1/FC-T4.
>
> The calculus already contained both halves; the fold is the hinge. The design reading follows: **choose your fold = choose what your boundary cannot see.** A nest that must be auditable downstream must fold what the auditor will ask (declare the labels, FC-T3); a nest that must be private must fold *away* what the boundary should not reveal — and the two demands conflict exactly when the audit questions are not enumerable in advance (FC-D7), which is the honest statement of the tension.
>
> *Proof.* Both sides are FC-T1's fiber language applied to their respective folds; the valence is a design reading, not a mathematical claim. ∎

---

## 11. Machine-check status

**Machine-checked (bounded) 2026-08-29, mathmetal lane:** `tools/verifies/c3_fold_bench.py` — **PASS, 565,551 exact checks** (integers + SHA-256 bytes only). All four designed artifacts executed, plus the taxonomy:
1. **FC-X1 as an executable**: σ_bal(P₁) == σ_bal(P₂) == the zero map (total-fold states), Q(P₁)=YES ≠ Q(P₂)=NO — and the generalization: 178 equal-fold prefix pairs enumerated, the 40 carrying differing post-hoc Q each kill every answerer (identical compacted forms with and without a common suffix).
2. **FC-L2 hiding, exactly**: seeded ROM stand-in (R = 8 roots, all 56 injective seeds), all 2⁸ = 256 answerer decision rules enumerated — **max advantage exactly 0**; binding holds (h(P₁) ≠ h(P₂): separation is not extraction).
3. **FC-T3 recovery**: Λ-fold counts exact; Merkle inclusion witnesses verify on all 341 logs length ≤ 4 (2,844 checks); forged proofs rejected at every position (an acceptance would be a SHA-256 collision).
4. **FC-T4 Ω(c)**: the positional predicate family separates all prefix pairs at c ∈ {4,8,10} (523,776 pairs at c = 10) — ≥ c bits, forever; **FC-P1** fiber entropy: 2^c prefixes into c+1 single-account fold states, bits lost ≥ c − ⌈log₂(c+1)⌉.
Plus **FC-L1/FC-T1(a)**: the full taxonomy (balance/projection/count/sum/min-max/Λ/product — T4 and T5 included) on all 85 logs × all permutations × all checkpoints: **5,138 byte-exact round-trips** (canonical serialization) and 680 covered-query answers exact through q̂. FC-P2's permutation kill (no commutative fold, any size, computes walk-state) remains pen — its two-element witness L₁/L₂ is hand-checkable by design. A falsification of FC-T1 would be a summary-only scheme answering a non-fold-covered query on some pair — publish the pair; of FC-T3, an accepted forged quarantine chain — publish the collision (a result in itself); of FC-P2, a commutative fold computing the ladder readout on the L₁/L₂ witness — impossible by FC-L1, so this falsification would break FC-L1, i.e. find non-commutativity in a commutative operation.

---

## 12. Statement registry

| Kind | Items |
|---|---|
| Definitions (9) | FC-D1 log/transactions · FC-D2 fold · FC-D3 compaction · FC-D4 answering regime · FC-D5 fold-covered · FC-D6 lossless · FC-D7 post-hoc · FC-D8 augmented checkpoint · FC-D9 the three classes |
| Lemmas (3) | FC-L1 order independence · FC-L2 ROM hiding · FC-L3 Merkle inclusion proofs |
| Theorems (4) | FC-T1 characterization (⟺) · FC-T2 T4/T5 as instances · FC-T3 recovery (declared labels + witnesses) · FC-T4 Ω(c) pricing |
| Counterexamples (2) | FC-X1 post-hoc exclusion (both regimes) · FC-X2 (= the L₁/L₂ permutation witness inside FC-P2(b), exhibited inline) |
| Propositions (3) | FC-P1 fiber entropy c − O(log c) · FC-P2 walk-state Class-S outright · FC-P3 the hinge |

**What this paper adds beyond the sources.** Over `conjectures.md` Part III: the digest's role given its honest commitment framing (binding pins, hiding reveals nothing, separation ≠ extraction — with the candidate-list caveat stated rather than glossed); the fiber-entropy accounting (FC-P1 — the loss is c − O(log c) bits, asymptotically everything, a quantitative sharpening that also independently implies the Ω(c) bound); the recovery protocol spelled to verification steps with per-step soundness; the taxonomy with closure properties (products); and the outright kill of walk-state foldability (FC-P2's permutation argument — any commutative fold, any size — strengthening the source's balance-fold-relative resolution to the smallest possible witness), plus the priced design lever (posting more never makes stream-state foldable, only replayable).

---

*Academic-expansion lane, 2026-08-29. The conjecture died loudly in August; this paper is the autopsy with the bits counted: what survives is exactly the fold image, what died is asymptotically everything else, and the one thing the source called an honesty clause is now a two-line impossibility. The books balance: the crypto is scoped, the counters are exact, the corpse is on display.*

**References.** Internal: `conjectures.md` Part III, `quilt-calculus.md` §6–7 (T4/T5), `THE-BREAKDOWN.md` §8, `DENY-BY-RUNNING.md` §5. External: [Mer80] R. C. Merkle, *Protocols for Public Key Cryptosystems*, IEEE S&P 1980 (canonical, carried); [RFC6962] Laurie, Langley, Kasper, *Certificate Transparency*, IETF 2013 (canonical, carried); [ACH+12] Agarwal, Cormode, Huang, Phillips, Wei, Yi, *Mergeable Summaries*, PODS 2012 (canonical, carried); [Coh97] E. Cohen, JCSS 55(3), 1997 (canonical, carried); [DLT07] Duffield, Lund, Thorup, JACM 54(6), 2007 (canonical, carried); [LS18] Lang, Shrivastava, CPC (via DataSketches documentation; carried); [Fow05] M. Fowler, *Event Sourcing* (via the monograph's registry).
