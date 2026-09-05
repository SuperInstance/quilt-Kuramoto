# THE QUILT CALCULUS — a formal monograph on the cell, its ledger, and its algebras

**Lane:** academic (GLM-5.3) · **Date:** 2026-08-29
**Sources upgraded:** the informal theory of `FOUNDATION.md`, `SEMANTIC-TOWER.md`,
`LINEAGE.md`, `CULTURE-DEEP-DIVE.md`, `QUF-SPEC.md`. This document is
self-contained: every definition below stands alone; no other quilt document is
a prerequisite for any proof.

---

## Abstract

A *cell* is an asynchronous agent defined by five organs — state, judgment,
ledger, tick discipline, and transition relation — formalized here as a
5-tuple `(S, J, L, τ, δ)`. We develop the quilt calculus: a mathematical theory
in which (i) intercell communication *is* double-entry bookkeeping — every
message a balanced transaction over integer accounts — so that conservation of
tracked quantities is a theorem obtained by induction over commit sequences,
given balance as an explicit axiom; (ii) approximate matching is a
pseudometric-space operation whose tolerance is state, giving additive
tolerance-composition under serial judgment (a triangle-inequality theorem) and
a canonical alias quotient; (iii) replication converges without consensus by
nonce-idempotent commutative application (an operation-based CRDT argument);
(iv) asynchronous composition presents a synchronous *illusion* to any observer
whose query cadence exceeds F + L, where F is a staleness bound and L a latency
bound — and chained bounded-freshness views compose with composite staleness
F₁ + Σ Lᵢ (origin staleness plus relay latencies); (v) nesting of cells admits
a consolidation operation under which interior transactions vanish and
flattening is associative and unital — the monad laws for nest, proved at the
level of balance maps; (vi) the sim–twin snap contract is sound: post-snap
states satisfy the deadband invariant, custody of authority is conserved, and
accumulated snap debt grows at most linearly in time at slope asymptotic to the
drift rate. We also prove a covering-radius theorem for integer measurement
bases (b√n/2) grounding float-free cross-substrate agreement, and a
maintenance-zoom localization theorem ("no fourth place for error to hide").
Three conjectures are stated honestly where proofs are out of reach:
the freshness–partition dichotomy, the judgment-drift error bound, and lossless
ledger compaction. The theory connects to place invariants of Petri nets,
linearizability, bounded-staleness consistency models, CRDTs, synchronous
languages, and five centuries of double-entry accounting practice.

**Statement registry.** 18 definitions, 7 axioms, 11 theorems, 2 propositions,
13 proofs, 3 conjectures (§14).

---

## 1. Introduction and scope

The quilt project's informal documents carry a load-bearing thesis: that four
primitives — judgment with tolerance, balanced-book transactions, asynchronous
sessions that feel synchronous, and a fixed tick — already constituted a
complete computing substrate in 1960s–70s practice (PLATO's judge fields, the
COBOL/RPG ledger batch, PLATO's thousand-terminal session illusion, RPG's
program cycle), and that a *cellular* restatement of those primitives is "the
ultimate backend under any OS." This monograph converts that thesis into
mathematics. The conversion is not cosmetic: where the informal docs say
"conservation by induction," we write the induction; where they say "the monad
laws are the safety argument," we prove the laws; where they say "the snap
transaction is balanced," we check the arithmetic — and report that the
three-legged form as informally written does **not** balance, and give the
four-legged emendation that restores the balance axiom (Theorem 10.5).

Method. Every theorem below rests on explicitly listed axioms (§3), and each
proof notes which axioms it consumes. Where the informal theory asserts
something we cannot prove, it is filed as a conjecture (§13), not smuggled in
as a lemma. The debt is as informative as the credit.

---

## 2. Notation

| Symbol | Meaning |
|---|---|
| `ℤ`, `ℕ`, `ℝ≥0` | integers; naturals; non-negative reals |
| `ℤ^{(A)}` | the free abelian group on set `A` (finite-support integer vectors) |
| `X × Y`, `X → Y`, `𝒫(X)` | product; function set; power set |
| `‖v‖`, `v·w` | Euclidean norm; inner product (used only in §12) |
| `d(x,y)` | a (pseudo)metric on an answer space |
| `B_d(x,r)` | the closed ball `{y : d(x,y) ≤ r}` |
| `bal : Acct → ℤ` | a balance map (partial; total on owned accounts) |
| `Φ(𝒞)` | total balance over the accounts of a cell set `𝒞` |
| `(F, L)` | freshness bound, latency bound of a view |
| `t₀`, `t_r` | view issue time, response time (wall-clock instants) |
| `commit(s)` | the instant a serial state `s` was committed |
| `κ`, `π` | consolidation map; coordinate projection |
| `Δ`, `ρ` | deadband; per-tick divergence bound |
| `T`, `v_T` | a transaction; its posting vector in `ℤ^{(Acct)}` |
| `D1…D18, A1…A7, T1…T11, P1…P2, C1…C3` | definitions, axioms, theorems, propositions, conjectures |

Wall time is used only where freshness is discussed (§8); the ledger theory
(§6) and distribution algebra (§7) are time-free, using only per-cell event
orders.

---

## 3. Axioms

The calculus assumes a fixed universe of **accounts** (named integer counters,
D4) and **cells** (D1). The following are *assumed*, not derived. For each
axiom we state what would falsify it.

**A1 (Balance).** Every transaction committed anywhere satisfies
`Σᵢ vᵢ = 0` over all its postings. *This is the discipline quilt chooses as
axiom:* the cell core refuses to commit an unbalanced transaction. Balance is
therefore never a theorem; every conservation result below is conditional on
A1. (Falsified by a core that posts one-sided entries.)

**A2 (Single-writer ownership).** Every account is owned by exactly one cell;
only the owner may post to it. The definition of an account *is* "the thing
exactly one cell may post to." (Falsified by shared write access.)

**A3 (Per-cell serialization).** The events of each cell are totally ordered
by service: one interpreter, one event at a time, one event = one commit
boundary. (Falsified by a cell with concurrent interior actors.)

**A4 (Nonce idempotence).** Applying a transaction whose nonce already appears
in the applying cell's log is a no-op. (Falsified by replay double-counting.)

**A5 (Bounded operation).** Each opcode service completes within a bounded
number of cycles, `MAX_OP_CYCLES` (an RTL-enforced run-to-completion bound;
assumed here at the abstraction level of runs).

**A6 (Tick deadline).** A pending tick is serviced within a bounded window and
cannot be starved by ingress traffic. (This is what keeps the freshness bound
a function of topology rather than of traffic mercy; used in §8 remarks only.)

**A7 (View seriality).** A view returns the value of a *committed serial
state* of the viewed cell: no torn states (A3), no states committed after the
response is formed.

Axiom status is honest engineering: A1, A4 are mechanisms a fabric can enforce
exactly; A2 is an architectural invariant; A3 is definitional; A5, A6 are
silicon-theoretic bounds verified by testbench in the v1 ring; A7 is the
observability contract.

---

## 4. Cells, runs, and the shared word

### D1 — Cell

> **Intent.** One asynchronous agent whose entire being is five organs; there
> is no other ontology in the calculus (no scheduler, no broker, no registry).
>
> **Statement.** A **cell** is a 5-tuple `C = (S, J, L, τ, δ)`:
> - `S` — a set of **states** (each state is serializable; see D18);
> - `J : X → {ACCEPT, REJECT, AMBIGUOUS} × note` — a **judgment function**
>   (D3) on a fixed input space `X`;
> - `L` — a **ledger** (D4): an append-only log of balanced transactions over
>   the cell's owned accounts, together with the induced balance map;
> - `τ : S → ℕ` — the **tick discipline**: a pure function from state to next
>   tick period;
> - `δ ⊆ (E × S) → S` — a **transition relation** on event alphabet `E`
>   (ingress flits, tick strobes, egress grants); by A3 each run selects a
>   function.

The five verbs `qm_bind` (dials ⊂ S), `qm_link` (wiring, D9), `qm_effect`
(δ + L, as a transaction, D4), `qm_view` (J + S, bounded-freshness, D7),
`qm_tick` (τ, then δ) are the only operations that touch the tuple.

### D2 — Pseudometric space

> **Intent.** Tolerance requires distance; aliases require the distance to be
> a *pseudo*metric.
>
> **Statement.** A **pseudometric** on a set `X` is `d : X × X → ℝ≥0` with,
> for all `x, y, z ∈ X`: (i) `d(x,x) = 0`; (ii) symmetry `d(x,y) = d(y,x)`;
> (iii) triangle inequality `d(x,z) ≤ d(x,y) + d(y,z)`. A **metric**
> additionally has `d(x,y) = 0 ⟹ x = y`. Standard examples: edit distance
> (metric); `d(x,y) = |log x − log y|` on `ℝ>0` (pseudometric after
> quotienting scale — in fact a metric on `ℝ>0`, see T3(d)); the discrete
> metric `d(x,y) = 0 iff x = y, else 1`. See [BBI01] for the metric-space
> background.

### D18 — Canonical state encoding (QUF)

> **Intent.** "State is a file" made mathematical: two interpreters — a
> software decoder and a hardware decoder — must agree on state.
>
> **Statement.** A **canonical encoding** for cell `C` is a pair
> `enc : S → {0,1}*`, `dec : {0,1}* ⇀ S` with `dec ∘ enc = id_S`, such that
> every admissible decoder (simulator, silicon loader) implements `dec`
> identically on the image of `enc`. **Tolerance-bounded decoding** replaces
> equality by: for the quantity-bearing projections `q : S → ℝⁿ` of interest,
> `‖q(dec′(enc(s))) − q(s)‖ ≤ ε` for every admissible decoder `dec′`, with
> `ε` itself subject to judgment (D3). Verification that two decoders agree
> within `ε` is a judgment on the *encoding*, not a property of the cell.

---

## 5. Judgment: matching with tolerance

### D3 — Judgment function

> **Intent.** PLATO's judge fields, generalized: match-with-tolerance as a
> first-class organ, tolerance as *state* (a dial), verdicts that never guess.
>
> **Statement.** Let `(X, d)` be an answer space (D2) and `K` a finite set of
> candidate classes. A **judge** is a pair `J = (A, r)` with `A ⊆ X × K` a
> finite set of **keyed answers** and `r : S → ℝ≥0` a **tolerance dial**
> (a state component). For input `x ∈ X` the **verdict set** is
>
> `V(x) = { k : ∃(a, k′) ∈ A, d(x, a) ≤ r ∧ k = k′ }`
>
> and the judgment is: `ACCEPT(k)` if `V(x) = {k}`; `AMBIGUOUS` if
> `|V(x)| > 1`; `REJECT` if `V(x) = ∅`. We write `V_r(x)` when the dial value
> must be explicit.

Note `AMBIGUOUS` is a verdict about the verdict set, not a failure: the output
is the set, and the judge refuses to collapse it.

### T3 — Structure of judgments

**(a) Monotonicity in the dial.** *For all `r ≤ r′` and all `x`:
`V_r(x) ⊆ V_{r′}(x)`; widening tolerance can only enlarge acceptance.*

*Proof.* If `k ∈ V_r(x)` there is `(a, k′) ∈ A` with `d(x,a) ≤ r ≤ r′`, so
`k ∈ V_{r′}(x)`. ∎ *(Uses nothing but D3.)*

**(b) Aliases are zero-distance classes.** *On any answer space, define
`x ~ y ⟺ d(x,y) = 0`. Then `~` is an equivalence relation, and
`d̄([x],[y]) := d(x,y)` is a well-defined **metric** on the quotient `X/~`,
the **alias quotient**. A pseudometric answer space is thus exactly a metric
space whose points have been split into aliases.*

*Proof.* Reflexivity: `d(x,x) = 0`. Symmetry: `d(x,y) = 0 ⟹ d(y,x) = 0` by D2(ii).
Transitivity: `d(x,z) ≤ d(x,y) + d(y,z) = 0 + 0 = 0`. Well-definedness: if
`x ~ x′`, `y ~ y′`, then `d(x,y) ≤ d(x,x′) + d(x′,y′) + d(y′,y) = d(x′,y′)`
and symmetrically, so `d(x,y) = d(x′,y′)`; the value of `d̄` is independent of
representatives. `d̄` inherits D2(i)–(iii) from `d`, and
`d̄([x],[y]) = 0 ⟹ d(x,y) = 0 ⟹ x ~ y ⟹ [x] = [y]`: identity of
indiscernibles holds. ∎

Engineering reading: the species alias table (`pink ≡ humpy`) is the statement
that the answer space's distance is a pseudometric, and the canonical species
identifier is membership in a zero-distance class — *aliases are data*.

**(c) Additivity of tolerance under composition (the triangle theorem).**
*Let `p : X* → X` be a prefilter stage with accuracy `ρ`, i.e.
`d(p(z), z) ≤ ρ` for all ideal inputs `z ∈ X* ⊆ X`, and let `J = (A, r)` be a
judge downstream of `p`. Then for every keyed answer `a` and every ideal
input `z`:*
- *(certainty) `d(z, a) ≤ r − ρ ⟹ d(p(z), a) ≤ r`;*
- *(soundness) `d(p(z), a) ≤ r ⟹ d(z, a) ≤ r + ρ`.*

*Consequently the composed system (prefilter then judge) accepts every input
in `B_d(a, r − ρ)` and no input outside `B_d(a, r + ρ)`: the effective
acceptance ball is `B_d(a, r + ρ)`, and the verdict boundary blurs by exactly
`ρ`. Chaining `k` stages of accuracies `ρ₁, …, ρ_k` ahead of a judge of
tolerance `r` yields effective tolerance `r + Σᵢ ρᵢ`.*

*Proof.* Certainty: `d(p(z), a) ≤ d(p(z), z) + d(z, a) ≤ ρ + (r − ρ) = r`, by
D2(iii). Soundness: `d(z, a) ≤ d(z, p(z)) + d(p(z), a) ≤ ρ + r`. The ball
statements are the two clauses contraposed. Chaining: apply the two-link
result inductively; each stage's accuracy adds to the effective radius by the
same triangle argument, or directly: for stages `p₁, …, p_k` composed,
`d(p_k∘…∘p₁(z), z) ≤ Σρᵢ` by induction on `k` using D2(iii) once per link. ∎

This is the formal content of "verification is judgment at log-2 tolerance"
and of the culture-lane claim that approximate stages compose: a numeric
acceptance gate `W_exact/2 − 1 ≤ Ŵ ≤ 2·W_exact + 1` is a judge on the
multiplicative pseudometric (part (d)) with `r = log 2`, and every approximate
stage in front of it widens the gate by its own accuracy, additively.

**(d) The multiplicative pseudometric.** *`d_log(x, y) = |log x − log y|` on
`ℝ>0` is a metric, and `d_log(x, y) ≤ log 2 ⟺ x/2 ≤ y ≤ 2x`.*

*Proof.* `d_log` inherits all three properties from the metric on `ℝ`
(`|u − v|`) via the bijection `log : ℝ>0 → ℝ` and the triangle inequality on
`ℝ`. The equivalence: `|log x − log y| ≤ log 2` unfolds to
`−log 2 ≤ log(x/y) ≤ log 2`, i.e. `1/2 ≤ x/y ≤ 2`. ∎

### Conjecture-adjacent remark (drift)

D3 fixes `(X, d, A, r)` at bind time; the world drifts. The open problem —
bounding the label error of a fixed judge under a drifting true metric, and
finding the optimal re-judging policy — is C2 (§13), not a theorem.

---

## 6. The ledger: conservation by induction

### D4 — Postings, transactions, ledgers

> **Intent.** Double-entry bookkeeping as the *wire format*: no value moves
> without two entries.
>
> **Statement.** Fix a universe of accounts. A **posting** is a pair
> `(a, v)` with `a` an account and `v ∈ ℤ \ {0}` (`v > 0` credit, `v < 0`
> debit). A **transaction** is `T = (n, {(a₁,v₁), …, (a_k,v_k)})` with `n` a
> unique **nonce** and postings on distinct accounts; `T` is **balanced**
> when `Σᵢ vᵢ = 0` (A1). Write `v_T ∈ ℤ^{(Acct)}` for the transaction's
> posting vector (`v_T(a) = v` if `(a,v)` is posted, else `0`); `supp(v_T)` is
> its support. A **ledger** of cell `c` is a pair `(log, bal)`: `log` an
> append-only sequence of transactions whose postings on `c`'s owned accounts
> (A2) have been applied by `c`; `bal : Acct_c → ℤ` the balance map with
> `bal = Σ_{T ∈ log} (v_T restricted to Acct_c)` (see D6 for application
> events). By A4, application is a partial function of the nonce: fresh ⇒
> apply and append; seen ⇒ no-op.

### D5 — Cuts, crossing, in-flight

> **Statement.** For a set of cells `𝒞`, `Acct(𝒞) := ⋃_{c∈𝒞} Acct_c`
> (disjoint by A2) and `Φ(𝒞) := Σ_{a ∈ Acct(𝒞)} bal(a)`. A transaction
> **crosses the cut** `𝒞` if `supp(v_T)` meets both `Acct(𝒞)` and its
> complement; it is **interior** (non-crossing, 𝒞-side) if `supp(v_T) ⊆
> Acct(𝒞)`. A posting of a crossing transaction is **in flight** (w.r.t.
> `𝒞`) from the commit of the first of its postings until the commit of the
> last.

### D6 — Runs, events, commit boundaries

> **Statement.** A **run** is a finite or infinite sequence
> `R = (e₁, e₂, …)` of **events**, each event `e = (c, kind, payload)`
> belonging to a cell `c`, such that the subsequence of events of each cell
> is its total service order (A3). **Commit events** are: *apply* (cell `c`
> applies the postings of transaction `T` on `Acct_c`, appending `T` to
> `log_c` if its nonce is fresh, else no-op by A4); all other events (dials,
> ticks, views) leave `bal` unchanged. A **tick sequence** is the subsequence
> of tick events of one cell. The state observed by other cells changes only
> at commit events: *one event = one commit boundary.*

### T1 — Cut conservation (interior case)

> **Theorem.** *Let `R` be a run in which no committed transaction crosses
> the cut `𝒞` (every applied transaction is interior to `𝒞` or interior to
> the complement). Then `Φ(𝒞)` is constant along `R`.*
>
> *Proof.* Induction over the length of `R`. Base: at length 0, `Φ(𝒞)` is its
> initial value. Step: extend a run `R` of length `m` with event `e_{m+1}`.
> If `e_{m+1}` is not an apply event, `bal` is unchanged (D6) and neither is
> `Φ(𝒞)`. If `e_{m+1}` is an apply event at cell `c ∉ 𝒞`, no posting touches
> `Acct(𝒞)` (A2), so `Φ(𝒞)` is unchanged. If `e_{m+1}` is an apply event at
> `c ∈ 𝒞` applying the `c`-owned postings of transaction `T`: since no
> crossing transaction is committed in `R`, all of `T`'s postings lie on
> `Acct(𝒞)`-side accounts or none do; the `c`-postings applying now lie on
> the 𝒞 side, so **all** of `T`'s postings lie on the 𝒞 side, i.e.
> `supp(v_T) ⊆ Acct(𝒞)`. By A1, `Σ_{a} v_T(a) = 0`, hence the induced change
> to `Φ(𝒞)` is `Σ_{a ∈ Acct(𝒞)} v_T(a) = Σ_{a} v_T(a) = 0`. ∎
>
> *Axioms used: A1 (balance — the load-bearing axiom), A2, A3, A4.*

This is the induction the informal docs promised: *conservation is not
assumed; balance is.* Interior activity — an entire subgraph churning —
cannot move the cut total by a single unit.

### T2 — Crossing flow and the in-flight identity

> **Theorem.** *Fix a run `R` and a cut `𝒞`. Define*
> - `F(t)` = *sum over transactions **fully applied w.r.t. the cut** by time
>   `t` (all their postings committed) of their net 𝒞-side flow
>   `net𝒞(T) := Σ_{a ∈ Acct(𝒞)} v_T(a)`;*
> - `I(t)` = *sum over **in-flight** postings (committed postings of
>   transactions not yet fully applied) of their 𝒞-side values.*
>
> *Then at every point `t` of the run:*
>
> `Φ(𝒞)(t) = Φ(𝒞)(0) + F(t) + I(t)`  **(in-flight identity)**
>
> *In particular at any quiescent point (`I = 0`): `Φ(𝒞) = Φ(𝒞)(0) + F`.*
>
> *Proof.* Induction over run length. Invariant: the displayed equation.
> Base: `F = I = 0`, `Φ(0) = Φ(0)`. Step: append apply event `e` at `c`,
> applying 𝒞-side postings summing to `P` (if `c ∈ 𝒞`; else `P = 0`).
> - If `e` does not complete `T` w.r.t. the cut: `Φ += P`, `F` unchanged,
>   `I += P` (the just-committed postings are in flight). ΔΦ = P = ΔF + ΔI.
>   Invariant preserved.
> - If `e` completes `T` (its last outstanding posting commits now): let
>   `Q` = 𝒞-side postings of `T` committed *before* `e` (these were counted
>   in `I`). Case `c ∈ 𝒞`: ΔΦ = `net𝒞(T) − Q` (the just-applied postings);
>   ΔF = `net𝒞(T)`; ΔI = `−Q`. Then ΔF + ΔI = `net𝒞(T) − Q` = ΔΦ. Equal. ∎
>   Case `c ∉ 𝒞`: ΔΦ = 0; and `Q = net𝒞(T)` (all 𝒞-side postings were
>   committed earlier — or none ever were, `net𝒞(T) = 0 = Q`), so
>   ΔF + ΔI = `net𝒞(T) − Q` = 0 = ΔΦ. Equal. ∎
> - Non-apply events change nothing. A4 guarantees a completed transaction
>   never re-enters `I`. ∎
>
> *Axioms used: A1 not needed for the identity itself (it is pure
> bookkeeping); A1 is what makes F, I *observable as conservation*: for a
> transaction fully applied *globally*, the two sides' flows are opposite, so
> the total `Φ(𝒔ystem)` over all cells returns to its initial value — global
> conservation at quiescence. A2, A3, A4 as in T1.*

> **Corollary T2.1 (no fabrication).** *For a quantity carried only in
> accounts (custody, labels, tokens), any increase of `Φ(𝒞)` requires a
> committed credit posting on an `Acct(𝒞)` account; by A1 that credit is
> paired with a debit either inside `𝒞` (net zero by T1/T2) or crossing the
> cut (counted in `F`/`I`). A minted label with no emitting debit is not
> forbidden — it is **unrepresentable**.*
>
> *Proof.* From T2, `ΔΦ(𝒞) = ΔF + ΔI` always; both terms are sums of
> committed postings of crossing transactions. ∎

> **Corollary T2.2 (partition observability).** *Under a network partition,
> the cut discrepancy `I(t)` is exactly the ledger-measured in-flight flow:
> the system's deviation from conservation is not hidden but read out
> continuously by the books.* (Direct from T2; this is the "meter" in the
> freshness-for-availability trade, C1.)

**Remark (Petri-net kinship).** A1 says every transition's incidence column
sums to zero under the all-ones place-weighting; `Φ` is thus a *place
invariant* in the sense of Petri-net theory [Mur89, §place invariants], with
per-transition firings playing the role of our apply events and the
additional structure (A2 ownership, A4 nonces) giving per-account
serialization and safe retry that plain nets do not carry. The tick discipline
(D1 `τ`) plays the role synchronous languages assign to the logical clock
[BB91]: an endochronous heartbeat that makes progress observation-free.

**Remark (accounting theory).** The construction is the five-century-old
discipline of double entry [Pac94]: each transaction a set of postings summing
to zero, the trial balance the invariant `Φ = const`, closing entries
(balanced reversals) the quarantine mechanism. What the calculus adds over
the accounting tradition is A4 (nonce idempotence as a *mechanism*), making
at-least-once delivery safe — the property mirrors (D10/T6) and the flaky
boat link both consume it. What double entry *cannot* buy — truth of entries,
confidentiality, collusion-resistance, delivery — is precisely the informal
docs' honesty ledger, and each gap maps to an organ: truth to judgment (D3),
delivery to freshness (§8), collusion to cross-checking judges.

---

## 7. The distribution algebra

### D9 — Quilts, wiring, the category CELLS

> **Statement.** A **quilt** is a finite set of cells together with a set of
> **links**: ordered pairs (egress of one cell, ingress of another), each link
> carrying a flit contract `{op, src, dst, a0, a1, a2, dat}`. The category
> **CELLS** has cells as objects and **wirings** `f : A → B` (one or more
> links from `A`'s egress to `B`'s ingress) as morphisms; composition
> `g ∘ f` is wiring end-to-end. The functor laws — identity wiring changes
> nothing; `(A→B→C)` wired as one equals `A→B` then `B→C` — are the formal
> content of *composition is wiring, not scheduling*: no middle tier reorders,
> buffers by policy, or interprets. (The traced-monoidal grounding of the
> underlying ring is outside this document's scope; we need only plain
> composition.)

### D10 — Mirror

> **Statement.** A **mirror** of cell `C` is a cell `C′` with `J′ = J`,
> `τ′ = τ`, and a ledger that receives the **same transactions** (same
> nonces) as `L`, under at-least-once delivery. Replication = idempotent
> credit.

### T4 — Mirror convergence (consistency without consensus)

> **Theorem.** *Let replicas `C₁, …, C_m` of `C` (D10) receive at-least-once
> deliveries drawn from a common transaction set `S` (every `T ∈ S` is
> delivered at least once to every replica; orders may differ arbitrarily;
> duplicates are arbitrary). Then when replica `Cᵢ` has processed deliveries
> covering `S ⊆ Sᵢ`,*
>
> `balᵢ = bal(0) + Σ_{T ∈ Sᵢ} v_T|_{Acct}`,
>
> *independent of delivery order and duplication count. In particular, once
> all replicas have covered `S`, all balance maps are equal (**convergence,
> modulo in-flight**). No ordering agreement is used anywhere in the proof.*
>
> *Proof.* Fix replica `Cᵢ` and induct over its delivery sequence
> `σ = (T₁, T₂, …)`. Claim: after processing the prefix of length `n`,
> `balᵢ = bal(0) + Σ_{T ∈ set(σ₁..ₙ)} v_T`. Base `n = 0`: empty sum. Step: if
> the nonce of `T_{n+1}` is fresh, application adds `v_T` (D4) and
> `set(σ₁..ₙ₊₁) = set(σ₁..ₙ) ∪ {T}`; if it is a replay, A4 makes the step a
> no-op and the set is unchanged. This proves the claim for every `n`.
> Order-independence: the right side depends only on `set(σ)`, and any two
> delivery sequences covering the same `S` have the same set-sum. Hence all
> replicas converge once covered. (Equivalently: application is an
> idempotent, commutative, associative operation on `(bal, log)` — a
> semilattice — so the delivered set has a unique join independent of
> presentation order.) ∎
>
> *Axioms used: A2 (per-account writes live at one owner), A4 (idempotence).*

**Remark (CRDT kinship).** T4 is precisely the strong-eventual-consistency
argument for *operation-based* CRDTs with commutative operations and
idempotent delivery [SPBZ11]; quilt's posting addition is the commutative
operation, the nonce is the delivery-idempotence tag, and the single-writer
rule (A2) supplies the per-key causal lane. The honesty clause from the
informal theory is retained: only **transaction-carried** state converges —
walk-state not carried by postings (ladder buckets) is re-earned by replay,
i.e. mirror-by-recomputation with the ledger as source of truth.

### D11 — Placement and stripe

> **Statement.** A **site** is any substrate that can host a cell (fabric,
> soft core, OS process). A **placement** is a function `σ : cells → sites`.
> **Striping** is the induced map `S_σ` on quilts: each cell to its placed
> copy, each wiring to a **route** forwarding the same flit contract across
> sites. The correctness claim is the preservation of composition:
>
> `S_σ(g ∘ f) = S_σ(g) ∘ S_σ(f)`,
>
> *provided* every cut crossed by a route respects the flit contract. The
> provision is exactly the seam risk (C1 territory): where a route's cuts
> break the contract, the functor law fails by hardware, not by algebra.

Compute-striping partitions *who judges what* (many judges in parallel);
retrieval-striping partitions *who holds which accounts* — sound by A2, since
each account has exactly one owner site, so every `qm_view` of an account
lands at exactly one place and no coherence protocol is needed.

### D12 — Composite cell and consolidation

> **Intent.** Nesting must be *invisible from outside*: interior bookkeeping
> nets to zero at the boundary.
>
> **Statement.** A **composite cell** `C[C₁, …, C_k]` has account set
> `Acct_C = E ⊔ I` (disjoint): **exposed** accounts `E` (the boundary; owned
> by the composite) and **interior** accounts `I = ⊔ᵢ Acct_{Cᵢ}` (owned by
> the children; disjointness by A2). Its ledger `L` is the merged log of all
> transactions applied anywhere inside. The **consolidation**
> `κ : ℤ^{(E⊔I)} → ℤ^{(E)}` is the coordinate projection `π_E` (kill interior
> coordinates), applied to balance maps, and transaction-wise to logs:
> `κ(v_T) = π_E(v_T)`; a transaction with `κ(v_T) = 0` **vanishes** from the
> consolidated ledger. Call a transaction **interior (w.r.t. the composite)**
> when `supp(v_T) ⊆ I`.

### T5 — Consolidation lemma and the nest laws

**(a) Consolidation lemma.** *`κ` is a surjective homomorphism of balance
maps (`κ(x + y) = κ(x) + κ(y)`). Interior transactions vanish: `κ(v_T) = 0`.
Hence the consolidated balance `κ(bal) = π_E(bal)` depends only on
transactions touching `E`, and — by the semilattice argument of T4 — not on
their interleaving with interior activity. Interior bookkeeping is externally
invisible.*

*Proof.* `π_E` is linear (coordinate projections are group homomorphisms);
surjectivity is immediate (restrict to `E`-coordinate vectors). If
`supp(v_T) ⊆ I` then all `E`-coordinates are zero, so `π_E(v_T) = 0`. The
balance decomposition `bal = Σ_{T ∈ log} v_T` (D4) gives
`κ(bal) = Σ_T κ(v_T) = Σ_{T: supp∩E ≠ ∅} π_E(v_T)`. ∎

**(b) Associativity of flattening.** *A depth-3 nest `C[B[C₁,…], …]`
(outer, middle, innermost) may be flattened inner-first or outer-first; both
bracketings yield the same consolidated (external) ledger.*
Formally, with exposed layers `E₀ ⊔ E₁ ⊔ E₂` (outermost, middle, innermost
exposed sets) and flattening maps `κ_out : π_{E₀⊔E₂}` after
`κ_in : π_{E₁⊔E₂}`, and conversely:
`π_{E₀} ∘ π_{E₀⊔E₂} = π_{E₀} = π_{E₀} ∘ π_{E₀⊔E₁}` **as maps on the fully
flattened target `E₀`** — both bracketings compute the projection onto the
*global* exposed set `E₀`, killing `E₁ ⊔ E₂`.
*Proof.* Coordinate projections onto nested coordinate subsets compose to the
projection onto the intersection of the kept sets; both bracketings keep
exactly `E₀` at the end. At the ledger level, κ's are homomorphisms (part a),
so the projections lift to log maps, and interior transactions die in either
order: if `supp(v_T) ⊆ E₁ ⊔ E₂` (interior to both bracketings) then both
flattening orders send `v_T ↦ 0`; if `supp(v_T)` meets `E₀` the projection
keeps the same `E₀`-coordinates under either order (projections commute:
`π_A π_B = π_B π_A = π_{A∩B}` for kept-sets `A, B`). ∎

**(c) Unit law.** *The trivial composite — no exposed accounts of its own,
one child whose exposed accounts are the composite's — consolidates by the
identity: `κ = id`, and its consolidated ledger equals the child's.*
*Proof.* There are no interior coordinates beyond the child's own-internal
ones; `π_E = id` when `E` is all coordinates. ∎

**(d) External balance of the composite.** *Assume every transaction pairing
an exposed account with an account outside the composite is balanced at
composite granularity (the well-formedness condition on its wiring). Then the
composite, viewed externally as one cell with account set `E`, satisfies A1:
its external books balance. Interior activity cannot produce an external
imbalance, since interior transactions never touch `E` (part a), and by A2 no
outside cell can post to `E`.*
*Proof.* External transactions are balanced by assumption; every other
transaction in the consolidated ledger vanishes. ∎

**Remark (monad shape).** (b) and (c) are the associativity and unit laws of
`join` for the nesting construction — `nest = T(·)`, `consolidation = join` —
verified here as equations of balance maps and log homomorphisms, which is
the level at which the safety argument lives (what the outside can observe).
The full categorical statement (a monad on a category of cells, with
naturality squares) requires machinery this document does not develop; we
claim the laws, not the 2-categorical packaging. See [ML71] for the monad
formalism. What balance (A1) buys here beyond the projection identities:
each killed layer's internal transactions are *balanced within the layer*
(T1), so dissolving the layer cannot create a leak at any surviving
boundary — interior flows sum to zero *wherever they are summed*.

### D13 — Embedding (adapters)

> **Statement.** A **foreign protocol** `P` is a theory: message schemas plus
> progress obligations. An **embedding** is a map `E : P → CELLS` assigning
> each foreign message type an effect/dial-write at exactly one **adapter
> cell**, and each progress obligation a tick discipline at that cell.
> **Thinness** (the honesty condition): the adapter's judge is the discrete
> metric at zero tolerance (structure checks only — a checksum test is D3 at
> `r = 0`); the adapter adds **no judgment** of the carried content: for any
> two foreign messages with identical schema-decodable structure, the adapter
> emits identical effects. All intelligence sits in the cells downstream.

### D14 — Interface agreement (nominal typing)

> **Statement.** An **interface theory** is a triple
> `(protocol-name, version, schema-digest)`. A link forms only when both
> endpoints hold equal theories: `agree(P, P′) ⟺ P = P′`. Compatibility is by
> name, never by structural resemblance. The handshake itself is a balanced
> transaction: each side posts consent; neither may unilaterally create a
> link, exactly as neither may unilaterally create a credit (A1). Two
> structurally identical but semantically different streams (depth-feet vs
> depth-fathoms) carry different names and refuse to wire.

---

## 8. Freshness and the session illusion

### D7 — Bounded-freshness view; view chains

> **Statement.** Cell `A` **views** cell `B` when `A` issues a `qm_view` at
> wall time `t₀` and receives a value `v` at time `t_r`. The view is
> **(F, L)-bounded** if:
> (i) **latency**: `t_r − t₀ ≤ L` (a late answer is a *violation*, not
> "slow"); (ii) **seriality** (A7): `v = B@s` for a serial state `s` of `B`
> with `commit(s) ≤ t_r`; (iii) **staleness**: `t_r − commit(s) ≤ F`.
> A **relay chain of length `k`** is `C₁ ← C₂ ← … ← C_k ← O`: the observer
> `O` views `C_k`; while servicing any query, each `Cᵢ` obtains its value by
> viewing `C_{i−1}`; link `i` (from `Cᵢ` to `C_{i−1}`, `C₀ = O`) is
> `(Fᵢ, Lᵢ)`-bounded, and each layer's servicing window (its own sub-query
> issue through response) fits inside its caller's latency budget.

### T6 — Composition of bounded-freshness views

> **Theorem (two views in sequence).** *Let `O` view `A` at `t₀`, `A`
> responding at `t_r ≤ t₀ + L_A` with a value `v = B@s` relayed from a view
> of `B` that `A` made while servicing (sub-query issued at `t₁ ∈ [t₀, t_r]`,
> `(F_B, L_B)`-bounded). Then the composite view of `O` is
> `(F_B + L_A, L_A)`-bounded:*
>
> `t_r − t₀ ≤ L_A  and  t_r − commit_B(s) ≤ F_B + L_A,  commit_B(s) ≤ t_r.`
>
> *Proof.* Latency is given. Seriality: `commit_B(s) ≤ t₁ ≤ t_r` (A7 on the
> inner view; `t₁ ≤ t_r` because the sub-view completes within servicing).
> Staleness: by the inner bound, `commit_B(s) ≥ t₂ − F_B` where `t₂` is the
> inner response time; `t₂ ≥ t₁ ≥ t₀` (the inner query is issued no earlier
> than the outer one — sequential servicing), so
>
> `t_r − commit_B(s) ≤ t_r − t₂ + F_B ≤ t_r − t₀ + F_B ≤ L_A + F_B. ∎`
>
> **Corollary (chains of length `k`).** *In a relay chain (D7) the composite
> view of `O` is `(F₁ + Σ_{i=2}^{k} Lᵢ, L_k)`-bounded.*
>
> *Proof.* Induction on `k`. `k = 1`: the bound is `(F₁, L₁)` by D7 (relative
> to issue, staleness `t_r − commit ≤ F₁`; note `t₀ ≤ t_r`). Step: a chain of
> length `k+1` is a 2-chain whose inner value is delivered by a `k`-chain
> with composite bound `(F′, L′) = (F₁ + Σ_{i=2}^{k} Lᵢ, L_k)`; the two-view
> theorem composes `(F′ + L_{k+1}, L_{k+1}) = (F₁ + Σ_{i=2}^{k+1} Lᵢ,
> L_{k+1})`. ∎*
>
> *Axioms used: A5/A6 (through the servicing-window discipline), A7.*

**Engineering reading.** Only the **origin's staleness** and the **relays'
latencies** compose; the relays' own freshness dials are consumed inside
their servicing windows and do not appear in the composite bound. A retrieval
stripe of hops `h` with per-hop latency `L` and origin staleness `F` serves
views stale by at most `F + (h−1)L` — a topology-dependent, traffic-free
formula (traffic-freeness is what A6 buys).

### D8 — Session illusion

> **Statement.** An asynchronous quilt presents a **synchronous illusion with
> parameter F** to an observer whose every view is `(F, L)`-bounded and whose
> consecutive queries are spaced more than `F + L` apart (cadence
> `Δ > F + L`) if the observer's value transcript is identical to that of
> some synchronous system answering each query instantly from current state.
> The illusion is a *band-limited truth*: everything faster than F is
> invisible; everything visible is current to within F.

### T7 — The session-illusion rendering

> **Theorem.** *Let every view of `O` be `(F, L)`-bounded, with responses
> arriving before the next query is issued and cadence `Δ > F + L`. Let
> `v_n` be the value returned for query `n`, issued at `t₀(n)`, and let
> `s_n` be the serial state of the viewed system with `v_n = s_n` (A7). Then:*
> (i) *the observed states are strictly increasing in commit order:
> `commit(s₁) < commit(s₂) < …`;*
> (ii) *`commit(s_n) ∈ (t₀(n) − F, t₀(n) + L)` for all `n`: each observation
> lags real time by less than `F + L`, i.e. less than the observer's own
> cadence;*
> (iii) *hence there is a single serial history — the true commit order of
> the viewed system — such that every transcript `O` can record at this
> cadence is also produced by a synchronous system serving query `n` at
> instant `commit(s_n)`.*
>
> *Proof.* (ii): staleness gives `t_r(n) − commit(s_n) ≤ F`, and
> `t_r(n) ≤ t₀(n) + L`, so `commit(s_n) ≥ t_r(n) − F ≥ t₀(n) − F`; seriality
> gives `commit(s_n) ≤ t_r(n) ≤ t₀(n) + L`. (i): `commit(s_n) ≤ t_r(n) ≤
> t₀(n) + L < t₀(n) + Δ − F ≤ t₀(n+1) − F ≤ commit(s_{n+1})` — the first
> strict inequality is `Δ > F + L`, the last is (ii). (iii): the values
> `v_n = s_n` with the strictly increasing commit points `commit(s_n)`
> *are* a serial history; the synchronous rendering that serves query `n` at
> time `commit(s_n)` (which lies within the unresolvable window behind
> `t₀(n)`) returns exactly `v_n`. Since `O`'s distinctions at cadence `Δ`
> cannot separate instants closer than `Δ > F + L`, the two transcripts are
> indistinguishable to `O`. ∎*
>
> *Axioms used: A5–A7.*

**Remark.** T7 is linearizability [HW90] with the linearization point
relaxed to lag invocation by at most `F` — exactly the *bounded-staleness*
family of continuous consistency metrics introduced by the conit model
[YV02]. What the quilt adds is that `F` and `L` are enforced properties of
the fabric (per-hop bounded operation A5, non-starvable ticks A6), so the
illusion degrades gracefully and *predictably* with topology (T6), not with
load. The negative clause is equally explicit: at cadence below `F + L` the
illusion is falsifiable by observation, and D8 claims nothing there —
"session illusion" is a statement about a timescale, not magic.

---

## 9. The snap contract: sim–twin simultaneity

### D15 — Snap pair, deadband judge, snap transaction

> **Statement.** A **snap pair** is two cells sharing a dependent variable
> `x`: the game cell `G` (simulated value `g`) and the twin cell `T`
> (sensor-derived value `s`), both representing `x` on a common integer
> basis (D16). The pair carries a **deadband dial** `Δ ∈ ℤ≥0` (in `x`'s
> units) and the **snap judge**: D3 with the metric `d(g,s) = |g − s|` at
> tolerance `r = Δ`, evaluated in **squared form** (compare `|g−s|² ≤ Δ²`),
> with verdicts WITHIN / SNAP. A **snap event** assigns `g := s` (reality
> wins) and books the correction as a transaction landing in both ledgers.
> **Per-tick divergence bound** `ρ ∈ ℤ≥0`: between consecutive tick
> boundaries, `|g|` and `|s|` each change by at most `ρ/2` (hence `|g−s|` by
> at most `ρ`). **Authority accounts**: `G:auth` and `T:auth`, custody of
> "who defines `x`"; initially `bal(G:auth) = 1, bal(T:auth) = 0`.

### T8 — Squared-form equivalence

> *For all `g, s ∈ ℤ` and `Δ ∈ ℤ≥0`: `|g−s|² ≤ Δ² ⟺ |g−s| ≤ Δ`. The judge
> needs no square root and no floats, and its verdict is identical to the
> direct comparison.*
>
> *Proof.* The map `t ↦ t²` is strictly increasing on `ℝ≥0`: if
> `0 ≤ u < v` then `t²` applied gives `u² = u·u < v·u ≤ v·v = v²`. Both
> `|g−s|` and `Δ` are non-negative, and squaring preserves and reflects the
> order on `ℝ≥0` by strict monotonicity (and injectivity). ∎

### T9 — Snap soundness: the invariant

> **Theorem.** *Under the discipline of D15 — the judge runs at every tick
> boundary; on WITHIN nothing moves; on SNAP the snap event fires — the
> invariant*
>
> `I: |g − s| ≤ Δ at every tick boundary`
>
> *holds for all time. Moreover at every instant (mid-tick included)
> `|g − s| ≤ Δ + ρ`.*
>
> *Proof.* Induction over the tick sequence of the pair. Base: at tick 0 the
> pair synchronizes (`g := s` if needed), giving `|g−s| = 0 ≤ Δ`. Step:
> assume `I` at boundary `n`. At boundary `n+1` the judge sees the new
> values `g′, s′`. If WITHIN, then `|g′−s′| ≤ Δ` — that *is* the judge's
> condition (T8) — so `I` holds at `n+1`. If SNAP, then `g′ := s′` and
> `|g′−s′| = 0 ≤ Δ`. Mid-tick: from boundary `n` with `|g−s| ≤ Δ`, each side
> moves by at most `ρ/2` before the next boundary, so
> `|g−s| ≤ Δ + ρ/2 + ρ/2 = Δ + ρ`. ∎*

### T10 — Snap soundness: custody, balance, and the debt bound

**(a) Authority conservation.** *The cut `{G, T}` with
`Φ = bal(G:auth) + bal(T:auth)` satisfies `Φ = 1` at every commit boundary.*
*Proof.* Initially `Φ = 1`; only snap transactions post to authority accounts
(by A2, no other cell can), and by T1 (the cut is crossed by nothing else;
in fact the snap transaction is interior to the cut) `Φ` is constant. ∎
*So exactly one member of the pair is the authority at all times — custody of
truth is conserved.*

**(b) The balance emendation.** *The informally written three-legged snap
transaction*
`{(G:auth, −1), (T:auth, +1), (G:snap-debt, +|g−s|)}`
*violates A1: its postings sum to `|g−s| ≠ 0`. The balanced form is
four-legged:*
`T_snap = {(G:auth, −1), (T:auth, +1), (G:snap-debt, +|g−s|), (T:debt-issued, −|g−s|)}`,
*i.e. debt is booked as a paired accrual (debit the expense, credit the
contra), or equivalently posted symmetrically in both ledgers, which the
dual-ledger discipline already provides. All theorems of this section are
stated for the balanced form.*
*Proof of violation and repair: sum the three postings:
`−1 + 1 + |g−s| = |g−s|`; sum the four:
`−1 + 1 + |g−s| − |g−s| = 0`. ∎*
This is the monograph's clearest case of upgrading informal prose to
mathematics: the arithmetic, checked, forced a definitional repair.

**(c) Snap debt bound.** *Let `D(t)` be the accumulated snap debt (sum of
`|g−s|` booked over all snap events up to time `t`, measured in ticks). Each
snap event books at most `Δ + ρ`; consecutive snap events are at least
`⌈Δ/ρ⌉` ticks apart (for `Δ > 0`); hence for a horizon of `N` ticks,*
>
> `D(N) ≤ (Δ + ρ) · (1 + ⌊N·ρ/Δ⌋)  ~  ρ·N  as Δ ≫ ρ.`
>
> *Snap debt grows at most linearly in time, with slope asymptotic to the
> per-tick drift rate `ρ`.*
*Proof.* Per-snap size: at a snap boundary `n+1`, `|g′−s′| ≤ |g−s|@n + ρ ≤
Δ + ρ` (T9's induction hypothesis plus the divergence bound). Spacing: after
a snap, `|g−s| = 0`; to reach the next snap the divergence must exceed `Δ`,
gaining at most `ρ` per tick, requiring at least `⌈Δ/ρ⌉` ticks. Hence the
number of snaps within `N` ticks is at most `1 + ⌊N/⌈Δ/ρ⌉⌋ ≤ 1 + ⌊Nρ/Δ⌋`;
multiply by the per-snap bound. The asymptotic: `(Δ+ρ)(1 + Nρ/Δ) =
(Δ+ρ) + Nρ(1 + ρ/Δ) → ρN + Δ + ρ` as `Δ/ρ → ∞`. ∎*

**(d) Reality-wins and silence-freedom.** *Post-snap, `g = s` exactly
(assignment, not blending), and every correction is a booked transaction with
one nonce landing in both ledgers: by A4, redelivery cannot double-count the
debt; by T2.1, no correction can occur without its booking. The contract
"agree-to-within-Δ, snap-on-exceed, reality-wins, log-both-books" is
therefore sound in the strict sense: the displayed divergence never exceeds
`max(Δ, sensor error)` at boundaries (T9), and the history of disagreement is
reconstructible by replay.*

---

## 10. Integer measurement and float-free simultaneity

### D16 — Measurement basis, covering radius, integer sufficiency

> **Statement.** A **measurement basis** `b` for a quantity `x ∈ ℝⁿ` is the
> unit quantum in which `x` is represented (`x` lives on the lattice
> `bℤⁿ`). The **covering radius** of `bℤⁿ` is
> `cov(b) = sup_{x∈ℝⁿ} dist(x, bℤⁿ)`. Integer representation **suffices for
> tolerance `ε`** iff `cov(b) ≤ ε`. A **Pythagorean configuration** is a
> constraint set forcing the quantities of interest into
> `P = {v ∈ ℤⁿ : ‖v‖ ∈ ℤ}` (integer vectors with integer norms; in 2D the
> 3-4-5 family and its multiples), for which the required value lies *on* the
> lattice: representation error 0.

### T11 — Covering radius and float-free agreement

**(a) Covering radius.** *`cov(bℤⁿ) = b√n / 2`. Hence the **basis
inequality**: integer representation suffices for tolerance `ε` whenever
`b ≤ 2ε/√n` (in 1D: `b ≤ 2ε`).*
*Proof.* Upper bound: for any `x = (x₁,…,xₙ)`, round each coordinate to a
nearest multiple of `b`, `rᵢ = b·⌊xᵢ/b⌉` (ties broken arbitrarily); then
`|xᵢ − rᵢ| ≤ b/2` for every `i`, so
`dist(x, bℤⁿ) ≤ ‖(xᵢ−rᵢ)‖ = √(Σᵢ (xᵢ−rᵢ)²) ≤ √(n·(b/2)²) = b√n/2`.
Lower bound (tightness): the cube center `c = (b/2, …, b/2)` has every
coordinate at distance exactly `b/2` from *both* nearest multiples of `b`, so
for any lattice point `r`, `‖c − r‖² = Σᵢ (b/2)² = n(b/2)²`, giving
`dist(c, bℤⁿ) = b√n/2`. ∎

**(b) Exactness of integer chains.** *If a rendering equation is evaluated
entirely with exactly-specified integer operations (two's-complement `+`,
`−`, `×`, comparisons — no division, no floats), then any two correct
implementations, on any substrates, compute bit-identical results on
identical integer inputs.*
*Proof.* Exactly-specified integer operations are total functions of their
bit-vector arguments, fixed by the specification (no rounding rule exists to
diverge); two implementations of the same total function agree on every
input. Induction over the expression's syntax tree transfers the agreement
from leaves (identical inputs) to the root. ∎*

**(c) Verdict uniqueness across substrates.** *A snap judge (D15) whose
squared-form comparison is computed in exact integer arithmetic reaches the
same verdict on every substrate. In particular the sim (game engine),
the twin (MCU), and any auditor replay agree on WITHIN/SNAP always — the
divergence-about-the-verdict failure mode is impossible by construction.*
*Proof.* By (b), `|g−s|²` and `Δ²` are bit-identical everywhere; a comparison
of identical integers is a total function; apply T8. ∎*

**(d) Composing the honest fallback.** *When a physical constant refuses the
lattice (e.g. `c/2` mm/ns), fixed-point (dyadic) evaluation with per-stage
envelope `εᵢ` composes with the deadband by T3(c): the effective tolerance
becomes `Δ + Σ εᵢ`, and the discipline survives — degraded exactly and
additively, never silently.*

**Remark.** T11(b)–(c) are the formal content of "the weakest substrate sets
the arithmetic": because the contract spans substrates, the compiler must
choose the one discipline all substrates implement exactly — integers — and
Pythagorean configuration choice (sensor placements, calibration marks,
report units such that constants come out whole) drives the covering radius
to zero, where arithmetic is exact *by construction*, not by approximation.

---

## 11. Maintenance: rendering chains and zoom

### D17 — Rendering chain

> **Statement.** A **rendering chain** for a displayed value `v` is a finite
> acyclic sequence `raw ⟶_{f₁} x₁ ⟶_{f₂} … ⟶_{f_n} v` where each `fᵢ` is a
> cell whose manifest carries its rendering equation (human-readable, units
> on both sides) and each arrow is a wiring (D9); **IO cells are leaves**:
> chains terminate at raw IO by construction of the quilt's rendering graph
> (acyclicity is part of well-formedness for rendering subgraphs).
> **Zoom** is the maintenance gesture: iterated `qm_view` from any displayed
> value down its chain to raw IO.

### P1 — Localization theorem ("no fourth place")

> **Proposition.** *If the raw IO at the leaf of a rendering chain is correct,
> every wiring is correctly made, and every rendering equation is correctly
> implemented, then every value displayed from that chain is correct.
> Contrapositively: any wrong displayed value localizes to at least one of
> (i) a wrong equation (a cell), (ii) a wrong wiring (a link), (iii) wrong
> raw IO (a sensor) — and zoom terminates at one of them.*
>
> *Proof.* By induction on chain length `n`. `n = 1`: `v = f₁(raw)`;
> if `f₁` is correctly implemented and `raw` correct, then `v` is the true
> rendering — correct. Step: the chain `raw ⟶ … ⟶ x_{n} ⟶ v` displays
> `v = f_{n}(x_{n−1})`; by the induction hypothesis `x_{n−1}` is correct,
> and by the `n=1` case so is `v`. The contrapositive of the conjunction
> (raw ∧ wirings ∧ equations ⟹ correct) is the disjunction of failure sites.
> Termination: the chain is finite and ends at a leaf. ∎*

*What "rendered for maintenance" buys is exactly P1: debugging is zooming,
and zoom terminates.* Note P1 says nothing about *which* site failed — it
guarantees the failure is visible *somewhere on the chain*, found by
traversal.

---

## 12. The tower discipline: language below the horizon

### P2 — Language-below-the-horizon lemma

> **Proposition.** *Fix a cell's semantic commitment (its L1 form: dials,
> equations, links, tolerances — all state, D1/D3) and two target-language
> renderings `R₁, R₂` that (i) restore state from the same canonical
> encoding (D18), (ii) evaluate every rendering equation in exact integer
> arithmetic (T11(b)), or in fixed point with declared per-equation envelope
> `εⱼ`. Then for every viewable quantity `q`:*
>
> `|q(R₁) − q(R₂)| ≤ Σⱼ εⱼ` *(= 0 in the pure-integer case),*
>
> *which is within the cell's own declared tolerance dial whenever
> `Σⱼ εⱼ ≤ r` (D3). Hence all admissible target-language choices are
> observationally equivalent within declared tolerance, and the choice of
> language is a semantics-preserving degree of freedom — **below the
> attention horizon**.*
>
> *Proof.* Pure-integer case: T11(b) gives bit-identical values, so the
> difference is 0. Fixed-point case: each equation `j` is computed with
> envelope `εⱼ` in either rendering (declared), so each rendering's value of
> `q` lies within `εⱼ` of the ideal value of equation `j` composed along the
> chain; the triangle inequality (D2(iii) applied along the two error chains,
> once per stage — the same computation as T3(c) with `k` stages) bounds the
> mutual distance by the sum of envelopes. ∎*

*Corollary:* verification that a rendering is admissible is itself a zero-
tolerance judgment (capability manifest ACCEPT/REJECT), and the entire tower
— natural-language cells, opcodes, manifests, binaries — verifies by D3
applied at successive levels. The agentic compiler owns only choices P2
declares free; the edit set (io, raw, equations, links, dials) is above its
pay grade.

---

## 13. Conjectures (the honest register)

**C1 — The freshness–partition dichotomy.** *Under a partition event `π`
of indefinite duration, for any cut `𝒞`: either (i) views across `𝒞`
degrade with staleness `F` growing to exactly the in-flight bound of T2
(`I(t)` is the candidate Lyapunov quantity: `F(t) ≤ F₀ + I(t)` while both
sides keep applying), or (ii) the ledger forks — two conservation constants
where there was one — and every quantity is conserved *within* each side
(T1 applies per component). No third behavior is possible.* Status:
open. The unpartitioned case is T6/T7 (proved); the dichotomy's "no third
thing" clause needs a bridge/seam model (what a reconnected mirror does with
divergent nonce streams is where a third behavior could hide). This is the
quilt's stated CAP position — freshness traded against availability *at a
price the ledger reads out continuously* (T2.2) — and it is a conjecture, not
a theorem.

**C2 — Judgment-drift error bound.** *With true concept metric `d_t` varying
with total drift budget `∫ ‖d_t − d_{t+1}‖ dt ≤ D`, the label error of a
judge held at fixed `(d, r)` is bounded by a function of `D` and the
acceptance-boundary margin distribution; and there is an optimal re-judging
policy (dial writes as its empirical form) keeping error bounded with
re-judging cost proportional to drift rate.* Status: open; even the right
formalization of `‖d_t − d_{t+1}‖` over pseudometric spaces needs care
(Gromov–Hausdorff-type distance on the answer-space quotient of T3(b) is the
natural candidate). Connection to C1: freshness of audit feedback bounds the
rate at which drift can even be *detected*.

**C3 — Lossless compaction for a property class.** *A compaction
(checkpointing a balanced summary and truncating the prefix, digested
Merkle-style) is **lossless for property class 𝒫** iff every 𝒫-checkable
query on the full log is answerable on the compacted log. Balance invariants
survive trivially (the summary is a balance); the conjecture is that
**provenance-of-exclusions** (what a downstream consumer did *not* train on
must survive any compaction) is preserved by digest-truncation, i.e. that
quarantine chains remain checkable.* Status: open; the live instance is the
walk-state honesty clause (mirror-by-recomputation as the extreme compaction
keeping only the source stream).

These three are architecture-*created* problems: the calculus owns them the
way arithmetic owns its open questions — because the definitions are now
precise enough to be falsified.

---

## 14. Related work

**Metric structure.** Pseudometrics, quotients, and the triangle inequality
are classical [BBI01]; T3(b) is the standard metric-identification
construction, applied here to make "aliases are data" a theorem rather than
a slogan. The judge function (D3) generalizes the tolerance judging of
PLATO's TUTOR — spelling-tolerant bit-vector matching, per-judger tolerance
switches, and the tri-state verdict [Avn81; TG72] — into a pseudometric
operation with tolerance as state.

**Petri nets and process calculi.** The ledger's conservation laws are place
invariants of the transaction system [Mur89, §V]: A1 is the all-ones
place-invariant condition, T1/T2 the corresponding invariance proofs carried
out by induction over firing (commit) sequences rather than by linear
algebra on the incidence matrix — because nonces, ownership, and in-flight
posting structure (A2, A4) live in the dynamics, not the matrix. The event
structure of D6 (per-cell total orders, no global order) is the standard
asynchronous-model stance [Lam78].

**Linearizability and bounded staleness.** T7 relates the session illusion
to linearizability [HW90] with bounded-staleness relaxation in the sense of
continuous consistency [YV02]; the quilt's contribution is that the bounds
are fabric-enforced (A5, A6) and compose topologically (T6).

**CRDTs.** Mirror convergence (T4) is the operation-based CRDT argument
[SPBZ11] with nonce-guarded idempotent application; single-writer accounts
(A2) supply the per-key serialization that op-based CRDTs require of their
delivery relation.

**Synchronous languages.** The tick discipline (D1 `τ`; A6) is the
*synchronous hypothesis* of Lustre/Esterel — time as a sequence of discrete,
non-starvable instants — as surveyed in [BB91]; quilt differs by making the
clock cell-local (endochrony) and the synchrony an *illusion parameterized
by F* (D8) rather than a global assumption.

**Double-entry accounting.** The posting/transaction/ledger trichotomy (D4)
and the trial-balance invariant are Pacioli's discipline [Pac94], with A4
(idempotent application) as the computational addition that makes
at-least-once delivery safe; event-sourcing practice (state as the sum of an
append-only log) is the modern software echo [Fow05].

**Monads.** The nest/consolidation laws (T5) instantiate the monad laws of
[ML71] at the level of balance maps; the claim is deliberately scoped there
(§7, remark).

---

## 15. References

Verification note: entries marked ✤ were verified against DBLP/OpenAlex
metadata on 2026-08-29; the remainder are canonical editions trusted from
long-standing bibliographic knowledge or carried from the repo's own
primary-source sweep (LINEAGE.md).

- [BBI01] ✤ D. Burago, Y. Burago, S. Ivanov. *A Course in Metric Geometry.*
  AMS Graduate Studies in Mathematics 33, 2001.
- [BB91] ✤ A. Benveniste, G. Berry. *The synchronous approach to reactive
  and real-time systems.* Proc. IEEE 79(9):1270–1282, 1991.
  (DOI 10.1109/5.97297.)
- [Fow05] M. Fowler. *Event Sourcing.* martinfowler.com, 2005 (bliki entry).
- [HW90] ✤ M. Herlihy, J. M. Wing. *Linearizability: A Correctness Condition
  for Concurrent Objects.* ACM TOPLAS 12(3):463–492, 1990. (DOI
  10.1145/78969.78972.)
- [Lam78] L. Lamport. *Time, Clocks, and the Ordering of Events in a
  Distributed System.* CACM 21(7):558–565, 1978.
- [ML71] S. Mac Lane. *Categories for the Working Mathematician.* Springer,
  1971 (2nd ed. 1998).
- [Mur89] ✤ T. Murata. *Petri nets: Properties, analysis and applications.*
  Proc. IEEE 77(4):541–580, 1989. (DOI 10.1109/5.24143.)
- [Pac94] L. Pacioli. *Summa de arithmetica, geometria, proportioni et
  proportionalità.* Venice, 1494 (Part I, §ix: "Particularis de computis et
  scripturis").
- [SPBZ11] ✤ M. Shapiro, N. Preguiça, C. Baquero, M. Zawirski. *Conflict-Free
  Replicated Data Types.* SSS 2011, LNCS 6976. (DOI
  10.1007/978-3-642-24550-3_29.)
- [YV02] ✤ H. Yu, A. Vahdat. *Design and evaluation of a conit-based
  continuous consistency model for replicated services.* ACM TOCS 20(3),
  2002.
- [TG72] P. J. Tenczar, W. M. Golden. *Spelling, Word, and Concept
  Recognition.* CERL Report X-35, 1972 (ERIC ED124944).
- [Avn81] E. Avner. *Summary of TUTOR Commands and System Variables.* CERL/
  PLATO Publications, 10th ed., 1981 (ERIC ED208879).

---

## 16. Statement registry

| Kind | Items |
|---|---|
| Definitions (18) | D1 cell · D2 pseudometric · D3 judgment · D4 ledger · D5 cuts · D6 runs · D7 bounded view · D8 session illusion · D9 CELLS · D10 mirror · D11 stripe · D12 composite/consolidation · D13 embedding · D14 agreement · D15 snap pair · D16 measurement basis · D17 rendering chain · D18 QUF |
| Axioms (7) | A1 balance (**axiom, not theorem**) · A2 single-writer · A3 serialization · A4 nonce idempotence · A5 bounded op · A6 tick deadline · A7 view seriality |
| Theorems (11) | T1 cut conservation · T2 in-flight identity (+ no-fabrication, partition meter) · T3 judgment structure (monotonicity, alias quotient, tolerance additivity, log-metric) · T4 mirror convergence · T5 consolidation + nest laws · T6 freshness composition (2-link + k-link) · T7 session illusion · T8 squared form · T9 snap invariant · T10 snap custody/balance/debt · T11 covering radius + float-free agreement |
| Propositions (2) | P1 zoom localization · P2 language below the horizon |
| Conjectures (3) | C1 freshness–partition dichotomy · C2 judgment-drift bound · C3 lossless compaction |

*Academic lane, 2026-08-29. Where this monograph strengthens the informal
theory, it says so (T10(b) repairs the snap transaction); where it cannot
close a proof, it files a conjecture (§13). The books balance: every credit
cited, every debt named.*
