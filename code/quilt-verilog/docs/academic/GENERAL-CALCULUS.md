# GENERAL CALCULUS — the theory beneath the six verbs: abstract cells, quilt-shape, the generalization axes, composition, and the compiler correspondence

**Lane:** generals (GLM-5.3, deep-work) · **Date:** 2026-08-29
**Sources upgraded:** `FOUNDATION.md` (the cell D1–D5), `SEMANTIC-TOWER.md` (the four-level compiler), `LINEAGE.md` (PLATO/TUTOR, RPG/COBOL, FORTRAN), `quilt-calculus.md` (the formal monograph D1–D18/A1–A7/T1–T11), `RHO-F-FLOOR.md`, `DRIFT-AS-PREFILTER.md`, `FOLD-COVERED.md`. Self-contained: every proof below rests only on definitions restated in §2 or defined in this document; companions are cited as provenance, never as prerequisites.

> **The contract of this document.** The tower has a floor (the cell), walls (the calculus), and wings (the expansion papers); this paper is the **capstone**: the general theory the six verbs instantiate. Five moves. (1) **The abstract cell calculus** (§3): a signature, a skeleton, an interpretation — and the five **quilt-shape axioms** (local, link-respecting, effectful, total, ticked) that make an arbitrary op set *a quilt*. Theorem: the concrete 5+1 — `qm_bind/link/effect/view/tick/forget` — is a quilt-shaped interpretation, and the six verbs are organ-minimal (each load-bearing for a theorem of the calculus). (2) **The generalization axes** (§4): n-ary links, typed cells, non-commutative effects, alternative tick disciplines — for each, the theorem that survives, the theorem that breaks, the counterexample, and (where it exists) the proved repair: escrowed n-ary consent, types-in-the-digest, FIFO delivery, eager wavefront simulation. (3) **Composition theory** (§5): two quilt-shaped calculi compose iff a thin adapter span exists; the product calculus is quilt-shaped (proved); the snap pair is the worked product. (4) **The compiler correspondence** (§6): compilation is a morphism of calculi; **faithful** morphisms compose and preserve quilt-shape, zoom, and the books; **forgetful** morphisms are the formal content of the 1957 hardware/software split, and PLATO/TUTOR, RPG/COBOL, and FORTRAN are placed as *partial interpretations* — each holding a subset of the organs, each missing exactly the ones its history explains. (5) **Four new falsifiable conjectures** (§7): signature sufficiency, the synchrony separation, span necessity, and the snap normal form — each with a registered falsifier, in the house style. Rigor bar: numbered definitions, real proofs, honestly-graded conjectures, no leaps.

**Statement registry.** 20 definitions (GC-D1–D20), 5 preliminary definitions (GC-P0.1–P0.8), 12 theorems (GC-T1–T12), 5 lemmas/propositions (GC-L1–L5), 5 counterexamples (GC-X1–X5), 4 conjectures (GC-C1–C4), 34 numbered proofs. Grade: **pen-only** for the proofs; the constructive content of GC-T4/T6/T7/T8/T9 (+GC-L1) and all three executable counterexamples (GC-X1–X3, plus GC-X2's mechanism at the seam) are machine-checked **CLOSED-BOUNDED** — §8, benches in `tools/verifies/`, lane register `tools/gc-verifies/` (gcmetal lane, 2026-08-29); each conjecture carries its registered falsifier and every conjecture grade is unchanged (open).

---

## 1. Introduction — what is being generalized, and why now

The quilt-calculus monograph formalized *one* system: the v1 fabric's cell, its ledger, its judge, its snap contract. The expansion papers generalized three of its conjectures into theories (the audit-freshness floor, drift-as-prefilter, fold-covered compaction). What none of them asked is the question a general theory must ask: **what is the *shape* of the system that makes those theorems work — and how far does the shape bend before they stop working?**

That question has four precise instances, and they are not academic. The fleet is *already* running the bent versions: quilt-mhs links devices over transports that reorder (non-commutative delivery), the culture lane carries typed channels (`MhsValue { Null, Bool, Int, Float, Str }`), the tap fabric runs cells whose clocks differ (heterogeneous ticks), and the chip-matrix lane multiplies cells across substrates (composition). Each axis is live; none had a theorem. And the question has a fifth instance that the whole tower stands on: **compilation** — the semantic tower claims that L0→L3 passes *preserve meaning* while *choosing freely below the horizon*; that claim has never been stated as a theorem about a *map between calculi*, because the general notion "calculus" did not exist. This document supplies it.

The method is the house method. Every abstraction is checked against the concrete instance (GC-T1) before it is trusted; every generalization is graded by *what breaks*, with the counterexample exhibited, not intimated; every repair is proved, with its price stated; and what cannot be proved is filed as a conjecture with a falsifier a hostile party could actually execute (§7). The six verbs end the paper where they began the project: not as an implementation vocabulary but as a *hypothesis* — the claim that nothing else is needed (GC-C1) — which is now a mathematical statement with a registered kill condition.

---

## 2. Preliminaries (self-contained restatement)

These eight definitions restate the monograph's objects at the level of detail this paper consumes. Citations are provenance; nothing below leans on them.

**GC-P0.1 (cell, state, events).** A **cell** is an agent with a set `S` of **states** and a totally ordered sequence of **events** (one interpreter: one event at a time; each event is one **commit boundary**). Distinguished state components: **dials** (named parameters, including tolerance radii), **edges** (weighted links with counters), **accounts** (named integer counters), and a **tick schedule**. A finite set of cells is the system's **cell set**; there is no scheduler, broker, or global clock.

**GC-P0.2 (postings, transactions, ledger, balance).** Fix a universe of **accounts**, each **owned** by exactly one cell (only the owner posts to it). A **posting** is `(a, v)`, `a` an account, `v ∈ ℤ\{0}`. A **transaction** is `T = (n, {(a₁,v₁),…,(a_k,v_k)})`, `n` a **nonce**, postings on distinct accounts; `T` is **balanced** when `Σ vᵢ = 0`; its **posting vector** `v_T ∈ ℤ^{(Acct)}` is the finite-support vector of its postings. A **ledger** is an append-only log plus the induced **balance map** `bal = bal(0) + Σ_{T applied} v_T|_owned`. **Applying** `T` at its owner cells adds its owned postings; application of a nonce already in the log is a **no-op** (**nonce idempotence**).

**GC-P0.3 (runs).** A **run** is a finite or infinite sequence of events, each `(cell, kind, payload)`, whose per-cell subsequences are the cells' total orders. **Apply events** (ledger application) are the only events that change balances. A set of cells `𝒞` has `Acct(𝒞)` its accounts and **cut total** `Φ(𝒞) = Σ_{a∈Acct(𝒞)} bal(a)`; a transaction **crosses** `𝒞` if its support meets both sides, and is **interior** to `𝒞` if its support lies inside.

**GC-P0.4 (links, interface theory, consent).** A **link** is an ordered pair (egress of one cell, ingress of another) carrying a **flit** `{op, src, dst, args, dat}`. A link exists **iff both endpoint ledgers hold the same link-formation transaction under one nonce** — consent that balances on both sides of the cut: `{(A:links-held,+1),(A:link-capacity,−1),(B:links-held,+1),(B:link-capacity,−1)}`. Links form only when both endpoints hold **equal interface theories** `(protocol-name, version, schema-digest)` — nominal typing: compatibility by name, never by structural resemblance.

**GC-P0.5 (views, freshness).** Cell `A` **views** `B`: issue at wall time `t₀`, response `v` at `t_r`. The view is **(F, L)-bounded** if `t_r − t₀ ≤ L` (latency), `v` is a committed serial state of `B` with commit ≤ `t_r` (seriality), and `t_r − commit ≤ F` (staleness). Relay chains compose staleness `F₁ + Σ Lᵢ`.

**GC-P0.6 (tick).** Each cell has a **tick discipline** `τ : S → ℕ`: a pure state-function giving the next tick period. The **tick** event advances the cell's local (logical) clock and runs scheduled work; a pending tick is **serviced within a bounded window, unstarvable by ingress** (the deadline clause).

**GC-P0.7 (canonical encoding).** A cell has a **canonical encoding** `enc : S → {0,1}*` with `dec ∘ enc = id`, such that every admissible decoder (simulator, loader) implements `dec` identically on the image. Tolerance-bounded decoding: for quantity projections `q`, `‖q(dec′(enc(s))) − q(s)‖ ≤ ε` for all admissible decoders, `ε` subject to judgment.

**GC-P0.8 (the concrete signature — the 5+1 verbs).** The concrete system's operation alphabet, as run in `rtl/q_cell_core.v` (`OP_BIND..OP_TICK`) and the quilt-mhs adapter (`bind/link/effect/view/tick/forget`):

| verb | organ | reading |
|---|---|---|
| `qm_bind` | dials | parameter change, booked (count-booked on a dial-write account; the value rides the payload) |
| `qm_link` | links | negotiate interface theory; form/hold wiring by balanced shared-nonce consent |
| `qm_effect` | ledger + transition | a message *is* a balanced transaction in transit |
| `qm_view` | judgment + state | bounded-freshness read; malformed input → defined verdict (ACCEPT/AMBIGUOUS/REJECT), never a fault |
| `qm_tick` | τ, then transition | advance the local clock; run scheduled work within the deadline |
| `qm_forget` | ledger (closing entries) + receipt | **the sixth verb**: booked revocation — link teardown, consent withdrawal, quarantine — as balanced reversal posting to a `ForgetReceipt`, the fold-covered summary of what was removed (declared labels; never silent deletion) |

The judgment organ (pseudometric answer space `(X,d)`, keyed answers `A`, tolerance dial `r`; verdict = ACCEPT(k) / AMBIGUOUS / REJECT) is carried by `qm_view` and consumed wherever verdicts appear; its definition is used only in §6 and restated there.

Standing axioms inherited by every calculus below (the monograph's A1–A7, restated as needed): **balance** (every committed transaction sums to zero), **single-writer ownership**, **per-cell serialization**, **nonce idempotence**, **bounded operation** (each service completes within a bounded budget), **tick deadline**, **view seriality**.

---

## 3. The abstract cell calculus, and the quilt-shape axioms

### GC-D1 — Operation signature

> **Statement.** An **operation signature** is a finite set Ω of operation symbols together with, for each `ω ∈ Ω`, an **input sort** `I_ω` and an **output sort** `O_ω`, and a designation `cell(ω)` — the cell argument at which `ω` is serviced. Sorts are built from: a dial sort, an input-value sort, a flit sort, a verdict sort, a receipt sort, and unit. The **concrete signature** is `Ω_qm = {bind, link, effect, view, tick, forget}` with the obvious arities (GC-P0.8).

### GC-D2 — Skeleton

> **Statement.** A **skeleton** is a tuple `(𝒞, S, E, δ, 𝒯)`:
> - `𝒞` — a finite set of **cells**;
> - `S = (S_c)_{c∈𝒞}` — a state-space assignment;
> - `E` — an event alphabet, partitioned into per-cell service events and **delivery events** (a flit arriving at an ingress);
> - `δ = (δ_c)_{c∈𝒞}`, `δ_c : E_c × S_c → S_c` — **total** per-cell transition functions (`E_c` the events serviceable at `c`);
> - `𝒯 = (τ_c)_{c∈𝒞}`, `τ_c : S_c → ℕ∪{∞}` — a **tick-discipline assignment** (∞ = no scheduled tick).
>
> A **run** of the skeleton is a sequence of events whose per-cell subsequences are total orders (GC-P0.3), every delivery event referencing a link, and every service event at `c` applying `δ_c`.

The skeleton is deliberately empty of semantics: it says *that* cells transition on events, not *what* transitions mean. Meaning is the interpretation.

### GC-D3 — Interpretation

> **Statement.** An **interpretation** `[·]` of signature Ω over skeleton `(𝒞, S, E, δ, 𝒯)` assigns each `ω ∈ Ω` and cell `c` a **service function**
>
> `[ω]_c : I_ω × S_c → O_ω × S_c`, **total**,
>
> realized as a finite sequence of events in `E_c` (the **expansion** of `ω` at `c`), together with:
> - a set of **accounts** `Acct` with owner map `o : Acct → 𝒞`, and a **balance projection** `β : ⊔ S_c → ℤ^{(Acct)}` (each state determines the balances of its owner's accounts);
> - a **judgment bundle** `(X, d, A, r)` per cell where used (restated in §6.1);
> - a **link structure** `L` of pairs with interface theories (GC-P0.4).
>
> A **calculus** is a pair 𝕂 = (skeleton, interpretation). The interpretation **generates** the runs: the reachable runs of 𝕂 are the skeleton runs in which every non-delivery event lies in the expansion of some `[ω]_c`.

### GC-D4 — Q1: Locality

> **Statement.** The interpretation is **local** iff there is no operation, event, or transition in the generated runs that reads or writes a state component of a cell other than its own, except via a delivery event over a link in `L`. Equivalently: every generated run is an interleaving of per-cell event sequences coupled *only* by the delivery relation; the global transition system is the **asynchronous product** of the per-cell machines.
>
> *Reading:* locality is a **closedness** condition on the whole signature — it is violated by adding any global verb (a scheduler op, a shared-memory op, a broadcast-barrier op), not by misusing an existing one. "No global anything" made exact.

### GC-D5 — Q2: Link-respect

> **Statement.** The interpretation **respects links** iff (i) every delivery event in every generated run travels over a link in `L`; (ii) links enter `L` only through the consent discipline of GC-P0.4 — a balanced, shared-nonce formation transaction held by both endpoints, with equal interface theories; (iii) flits carry the interface theory's schema, and a flit whose decode fails at the ingress is rejected as a defined outcome (structure check at zero tolerance, never interpreted).
>
> *Reading:* inter-cell causation has exactly one carrier (the link), and the link has exactly one birth (consent booked on both sides).

### GC-D6 — Q3: Effectfulness

> **Statement.** The interpretation is **effectful (booked)** iff there is a set of **conserved cut functionals** — for the additive instance, `Φ_𝒞 = Σ_{a ∈ Acct(𝒞)} bal(a)` for each cell set `𝒞` — such that:
> (i) every transition in the expansion of any `ω` that moves a balance moves it **only** by applying a transaction at an owner cell;
> (ii) every applied transaction is **balanced**;
> (iii) crossing transactions are applied at their owners under one nonce, idempotently.
>
> *Reading:* value moves only in balanced books. The axiom is stated via cut functionals so that non-additive effect disciplines (§4.3) can instantiate it; the additive form is the concrete instance, and balance remains an **axiom, not a theorem** (the monograph's epistemic lift, preserved here).

### GC-D7 — Q4: Totality (fail-static)

> **Statement.** The interpretation is **total** iff every service function `[ω]_c` is total (GC-D3) **and** every malformed or out-of-domain input maps to a defined outcome — a REJECT verdict, a no-op, a sticky error state — never an undefined behavior, a block, or an unbounded computation. The quantitative strengthening (bounded operation: a uniform per-service cycle budget) is noted `Q4⁺`; it is what the v1 ring enforces (`MAX_OP_CYCLES`).
>
> *Reading:* errors are states, not behaviors. The fail-static boot discipline (any error parks sticky; the fabric never runs a half-image) is Q4's most literal instance.

### GC-D8 — Q5: Ticked

> **Statement.** The interpretation is **ticked** iff each cell's tick discipline `τ_c` is finite (scheduled work exists and is periodic-or-adaptive per state), the tick event appears in every generated run of `c` with bounded gaps, and pending ticks are serviced within a bounded window unstarvable by ingress (the deadline clause). `τ` is a **discipline parameter**: the class Θ of admissible disciplines is varied in §4.4 (fixed-period, state-adaptive, event-driven `τ≡∞`, wavefront).
>
> *Reading:* time is logical, local, and non-deferrable. The deadline clause is quantitative; the qualitative core is that scheduled work cannot be starved *as an order*.

### GC-D9 — Quilt-shaped calculus

> **Statement.** A calculus 𝕂 is **quilt-shaped** iff its interpretation satisfies Q1–Q5. Write **QS** for the class of quilt-shaped calculi.

### GC-T1 — Instantiation: the concrete 5+1 is quilt-shaped

> **Theorem.** The concrete system of GC-P0.8 — the v1 fabric's cells, opcodes, and boot discipline, as formalized in the monograph (D1/D4/D6/D9/D14/D18, axioms A1–A7) — is a quilt-shaped interpretation of the concrete signature `Ω_qm`.
>
> *Proof.* Take the skeleton: cells = the fabric's cell cores and adapters; states = dial/edge/account/schedule records (GC-P0.1); events = ingress flits, service strobes, tick strobes; transitions = the core FSM's total reactions; `τ` = the tick schedule (state, round-trips the encoding). The interpretation assigns each verb its organ (GC-P0.8 table). Verify the axioms:
> - **Q1 (locality).** The monograph's run model (its D6) *defines* global behavior as interleavings of per-cell total orders coupled by delivery; the five-verb table touches only the serviced cell's tuple; the flit pipe delivers over ring ports only. No verb reads another cell's state. ✓
> - **Q2 (link-respect).** Wiring is negotiated (D14: nominal interface theories, equal-theory consent); the link-formation transaction is balanced and shared-nonce; the adapter discipline (thin and dumb: no judgment of carried content, checksum = zero-tolerance structure check) gives clause (iii). ✓
> - **Q3 (effectfulness).** Apply events are the only balance-changing events (D6); every applied transaction is balanced (A1); crossing transactions commit at owners under one nonce (A4). The forget verb instantiates without exception: it *is* an effect — a balanced reversal (closing entries) — whose payload is a receipt. ✓
> - **Q4 (totality).** Service is run-to-completion bounded (A5, `Q4⁺`); malformed inputs yield defined verdicts (the judgment organ's REJECT; the checksum rejection at adapters); the boot harness is fail-static by construction (error parks sticky; POR defaults intact). ✓
> - **Q5 (ticked).** `τ : S → ℕ` is the schedule organ (state-adaptive discipline); the hardware-interlocked tick is serviced before any ingress (A6, the deadline clause). ✓
> All five hold; 𝕂_qm ∈ QS. ∎

### GC-T2 — Organ minimality: each verb is load-bearing

> **Lemma.** For each verb `v ∈ Ω_qm` there is a theorem Θ_v of 𝕂_qm that is **not expressible or not true** in the v-free sub-calculus (the calculus whose signature omits `v` and whose interpretation restricts accordingly). Hence no verb is definitional dead weight, and the six verbs are collectively necessary for QS-membership of the concrete interpretation.
>
> *Proof, verb by verb (each exhibits the failure).* 
> - **drop `effect`:** unbooked value motion becomes representable: a transition may change a balance without a transaction, so conservation (cut invariance under interior activity) fails by direct counterexample — a cell sets `bal(a) += 1` in a dial reaction; `Φ_{a}` moves with no crossing transaction. No-fabrication dies: minting is representable. (Θ_effect: conservation / no-fabrication.) This is FORTRAN's world: unbooked assignment — §6.4.
> - **drop `link`:** ingress without consent: any cell may wire any egress to any ingress (there is no consent discipline to check), so the depth-fathoms stream wires into the depth-feet judge and every displayed depth is off by 6× — the calibration error the nominal rule exists to prevent. Link-respect (Q2) is unsatisfiable. (Θ_link: nominal wiring safety.) 
> - **drop `view`:** no query-response exists; the only observation is being-written-to (push). Staleness is undefined (no issue/response pair), so the session illusion — bounded-freshness views presenting synchrony at cadence — is not even stateable. (Θ_view: the illusion, with F and L.) 
> - **drop `tick`:** scheduled work has no non-deferrable order: an ingress-first service policy under a continuous effect storm starves the tick forever, so the decay ladder never shifts, half-lives go unenforced, and view freshness becomes a function of traffic mercy. The deadline clause is gone; the freshness theorems lose their traffic-independence. (Θ_tick: traffic-free freshness — the exact failure the v1 interlock was built to kill.) 
> - **drop `bind`:** tolerance is no longer state: `r : S → ℝ≥0` is vacuous (S's dial component is born fixed), so dial monotonicity ("widening tolerance only enlarges acceptance") is stateable only as re-instantiation of a *different cell*, and every drift-response policy — re-anchoring as dial writes, the re-judging cost theory — is unexpressible. (Θ_bind: tolerance-as-state; the whole drift-control family.) 
> - **drop `forget`:** revocation has no booked form: removing a link or quarantining a label must either delete state (history loss: the excluded label becomes uncountable — the night cron no longer knows what it did not train on; quarantine is theater) or never happen (accumulation without bound). Closing-entry reversals *are* forget; without the verb, reversible action is not a first-class outcome. (Θ_forget: reversibility-with-receipt.) ∎
>
> *Honesty note.* The six verbs are not claimed algebraically independent — `bind` and `forget` are effect-class bookable (count-booked / reversal), and macro-encodings exist *within* the concrete calculus. The lemma's claim is **organ** minimality: each verb is the unique carrier of an organ, and each organ is load-bearing for a theorem — which is the independence notion the architecture actually needs (and the one GC-C1 tests from the other side: sufficiency).

---

## 4. The generalization axes: what survives, what breaks, and the repair where it exists

Each axis varies one parameter of GC-D1–D8 and grades the calculus's theorems under the variation. "Survives" means: the theorem's statement and proof carry over verbatim or by citation of the unchanged steps; "breaks" means: a counterexample exists, exhibited.

### 4.1 n-ary links (varying the arity of L)

Binary links (one egress, one ingress) generalize to **k-ary links**: a link is a `k`-tuple of cells with one interface theory, carrying **multicast transactions** — a transaction with postings at up to `k` owners under one nonce.

**GC-T3 — Conservation survives arity.**

> **Theorem.** GC-T1's Q3-verification, and the conservation theorems it grounds (cut invariance under interior activity; the in-flight identity; no-fabrication), hold verbatim for k-ary links, every `k ≥ 1`.
>
> *Proof.* Inspect the proofs. Cut conservation is proved by induction over run length: the step case applies a transaction's owner-side postings and observes that if all postings lie inside the cut, the induced change is `Σ_{a∈Acct(𝒞)} v_T(a) = Σ_all v_T(a) = 0` by balance. The argument inspects the transaction's **support**, never the link's arity: a k-ary multicast transaction with support inside `𝒞` nets to zero by the same line; a crossing one (support meeting both sides) is treated by the crossing analysis, equally arity-blind. The in-flight identity's step cases ("does not complete T" / "completes T") count committed postings per side — again support-based. No proof in the conservation family reorders, pairs, or bisects links. ∎

**GC-X1 — The phantom link: naive n-ary consent breaks Q2.**

> **Counterexample.** Cells A, B, C; a 3-ary link ℓ on theory P is proposed. **Naive generalization:** each party books its consent *on consent* — the binary handshake of GC-P0.4 posted unilaterally per party as it agrees: `{(cᵢ:links-held,+1),(cᵢ:link-capacity,−1)}`. A and B consent; C never does (its consent dial stays 0 — a defined, total outcome: Q4 holds throughout). The books now contain A's and B's pairs. Any observer applying the shared-nonce definition of "a link exists" by *pairwise scanning* finds A and B both holding links-held on P and declares a 2-ary link A–B on P — **a link nobody agreed to as a 2-ary link**. The books cannot distinguish "2 of 3 consents, pending" from "a 2-link formed": Q2 is violated by the accounting itself. (With the definition restricted to *joint* nonces, the failure inverts: partial consent is booked but denotes nothing — capacity is debited against a link that does not exist, and C's eventual consent or silence leaves the books in a state the binary discipline cannot close.) ∎

**GC-T4 — The repair: consent escrow (proved).**

> **Theorem.** There is a k-ary consent protocol — **escrowed consent** — under which k-ary links satisfy Q2, conservation, and liveness, for all `k`:
>
> 1. **Escrow.** On consenting, `cᵢ` posts `Tᵢ = {(cᵢ:escrow-P, +1), (cᵢ:link-capacity, −1)}` — balanced, per-cell: capacity custody moves into escrow.
> 2. **Formation.** A designated closer cell (a party or the link's own micro-cell) views all `k` escrow accounts (bounded-freshness, GC-P0.5) and, when all read 1, posts the **formation transaction** under one nonce: `Σᵢ {(cᵢ:links-held,+1),(cᵢ:escrow-P,−1)}` — balanced (`Σ = Σᵢ (1−1) = 0`), crossing all `k` owners. The link exists iff this nonce is held by all `k` (the shared-nonce definition lifted to arity k).
> 3. **Refund.** If the formation has not committed by a tick deadline `τ_consent` (Q5), each `cᵢ` posts `Tᵢ⁻ = {(cᵢ:escrow-P,−1),(cᵢ:link-capacity,+1)}` — balanced refund; escrow drains; no link exists.
>
> *Proof.* **Conservation:** every transaction displayed is balanced, so cut invariance holds at every commit (the interior case of the conservation theorem, applied per cell-set; nothing in the protocol posts unbalanced). **No phantom:** links-held on P at `cᵢ` changes only in the formation transaction, which requires all k escrows full at its issue (the closer's k views) and lands at all k under one nonce; partial states touch only escrow and capacity accounts, which denote *no* link under the shared-nonce definition — escrow is inert by definition (GC-X1's failure mode is definitionally excluded: no pairwise scan can see a link because none is booked). **Liveness:** refund is tick-driven; Q5's deadline clause guarantees the timeout fires, so capacity cannot be locked forever by a crashed non-consenter (its escrow refunds; the k-ary link simply never forms — a defined outcome, Q4). **Price, stated:** the protocol costs `k+1` transactions and one tick deadline per formation, and it introduces the closer as a coordination point — the binary case needs none of this, which is why arity-2 is the sweet spot the concrete calculus inhabits. ∎

### 4.2 Typed cells (varying the state-space assignment)

Types enter as a predicate: a **type system** for 𝕂 is a set `W ⊆ ⊔S_c` of well-typed states, plus input sorts, such that `W` is closed under the interpretation's transitions on well-typed inputs.

**GC-T5 — Typing is a refinement: every theorem survives.**

> **Theorem.** Let 𝕂 ∈ QS and `W` a type system. The **restricted calculus** `𝕂|_W` (states clamped to `W`; ill-typed inputs map to defined REJECT/no-op outcomes) is quilt-shaped, and every theorem of 𝕂 that is a universal statement over generated runs holds of `𝕂|_W`'s runs.
>
> *Proof.* `W`-closure makes the restriction well-defined (transitions never leave `W` on well-typed inputs); the REJECT clamp preserves totality (Q4) by giving ill-typed inputs a defined outcome. Q1–Q5 are universal over states and runs, so they restrict. Every theorem of the calculus family (conservation, in-flight identity, convergence, freshness composition, illusion) is proved by induction over generated runs and universal quantification over states; restricting the run set and state set preserves both the base and step cases verbatim. ∎
>
> *Reading:* types add **nothing semantically** — they are a proof-theoretic and compile-time device. The interesting content of the axis is not what types preserve but what they can *break when left implicit*, which is GC-X2.

**GC-X2 — Signedness: implicit types break cross-substrate verdict uniqueness.**

> **Counterexample.** Two substrates decode the same state bytes with different type disciplines: substrate 1 reads a datum byte as `u8`, substrate 2 as `i8`. The byte `0xC8` decodes as 200 on substrate 1 and −56 on substrate 2. A judgment `d(x, a) ≤ r` on that datum returns ACCEPT on one substrate and REJECT on the other — **the same encoded state, different verdicts**: the exact failure mode the verdict-uniqueness theorem (identical integer inputs ⇒ identical verdicts everywhere) forbids, now realized *through the decoder*, not the arithmetic. The root cause is not the types — it is that the **type discipline was left below the horizon**: the encoding (GC-P0.7) pinned the bytes but not their reading. ∎

**GC-T6 — The repair: the type schema lives in the interface digest.**

> **Theorem.** If the interface theory's schema-digest (GC-P0.4) includes the type schema of every carried datum, then cross-substrate verdict uniqueness is restored: two endpoints that wired (equal digests ⇒ equal type schemas) decode every flit identically, and the exact-integer verdict argument applies.
>
> *Proof.* Agreeing endpoints hold equal type schemas; decoding is a function of (bytes, schema); equal schemas and equal bytes give equal decoded values on every substrate; the verdict is a total function of the decoded value (GC-T1's Q4); compose. The fathom/hook calibration rule and the nominal-typing discipline were already this theorem in disguise — GC-X2 is the counterexample explaining *why* compatibility is by name-and-digest rather than by structural resemblance of wire shapes. ∎

### 4.3 Non-commutative effects (varying the application semantics)

The concrete ledger applies transactions **additively** (`bal += v_T`), so application commutes across distinct nonces — the property mirror convergence and fold order-independence consume. The axis: effect application is a general total update `f_T : S_c → S_c` (order-sensitive), subject only to Q3's conservation clause (each `f_T` preserves cut functionals on interior support, moves them by declared amounts on crossing support).

**GC-L1 — What survives: the run-ordered conservation family.**

> **Lemma.** The conservation theorems (cut invariance under interior activity), the in-flight identity, and no-fabrication consume **no commutativity**: their proofs are inductions along the actual run order (prefix extension by one event), and never reorder applications, set-sum over applied sets, or fold logs out of order. They hold verbatim for non-commutative application.
>
> *Proof.* Proof inspection. The cut-conservation step case computes the change induced by the *next* event's application, in the state the run actually reached, using only balance of that transaction on its support — order never enters. The in-flight identity's two step cases likewise track the run's own committed postings. No set-sum appears anywhere in these proofs (the set-sum appears first in mirror convergence, which is exactly what breaks next). ∎

**GC-X3 — What breaks: mirror convergence, and with it fold order-independence and consolidation.**

> **Counterexample.** Owner cell `O` of account `a`, mirror `M` (receives O's transactions, at-least-once, arbitrary order). Gated transfer semantics (total, Q4: the gate's else-branch is a defined skip): `T₁` = "transfer 10 from `a` to `b`, if `bal(a) ≥ 10`"; `T₂` = "credit `a` +5" (ungated). Initial `bal(a) = 8`.
> - O commits T₁ then T₂: T₁ sees 8 < 10 → **skips**; T₂ credits → final `bal(a) = 13`, `bal(b) = 0`.
> - M receives T₂ then T₁ (legal reordering under at-least-once): T₂ credits → 13; T₁ sees 13 ≥ 10 → **fires** → final `bal(a) = 3`, `bal(b) = 10`.
>
> Same transaction set, same nonces, different arrival orders, **different final balances** — mirror convergence fails; the replicas have diverged on state that both books faithfully record. Fold order-independence fails with it (application is no longer a commutative fold of the log), and consolidation breaks at the balance-map level: with order-sensitive application, the composite's exposed balance is no longer the projection of a balance *map* — it depends on the interior apply order, so interior activity becomes externally visible and encapsulation (nest-invisibility) dies. The two-line shape is the fold paper's walk-state witness (`[cofire, shift]` vs `[shift, cofire]`) generalized from stream-state to *effects*: the ladder was never an anomaly — it was this axis, already living in the concrete system, solved by replay. ∎

**GC-T7 — The repair: source-order (FIFO) delivery restores convergence.**

> **Theorem.** If delivery on each link is FIFO in the owner's commit order (per-link sequence: the nonce doubles as a sequence number), then every mirror's applied sequence is a **prefix of the owner's commit sequence**, the mirror state is the fold of that prefix (a function of prefix length alone), and mirror convergence holds with divergence exactly the delivered-prefix gap (the in-flight nonces).
>
> *Proof.* FIFO per link ⇒ the delivery order to M equals O's commit order restricted to delivered items ⇒ M's applied log is `log_O` truncated at the last delivery (idempotence deduplicates retransmits *in place*: a replayed nonce is a no-op, and retransmission cannot reorder — the sequence number detects and the link discipline rejects or re-queues out-of-order arrivals as defined outcomes, Q4). The fold of a fixed sequence's prefix is determined by the prefix length; two mirrors that have delivered the same prefix have folded the same sequence to the same state. Divergence between O and M is exactly the nonces committed at O and not yet delivered — the in-flight set, legible from the books. ∎
>
> *Price, stated.* The repair buys convergence by **spending reorder tolerance**: at-least-once *any-order* delivery (the property the naive system enjoyed) is no longer sufficient; the link discipline must carry sequence and enforce order. The honest engineering reading: the flit contract's per-link path (a ring port, in-order by construction) already is FIFO — the concrete system sits on the repair without having stated it; the theorem tells you what you must not break when transports change (quilt-mhs over reordering transports: GC-X3 is live unless the adapter supplies the sequence discipline).

### 4.4 Alternative tick disciplines (varying Θ)

**GC-D10 — Discipline classes.**

> **Statement.** The **tick-discipline class** Θ of an interpretation is the family `(τ_c)`. Variants: **(i) fixed** `τ ≡ W`; **(ii) state-adaptive** `τ : S → ℕ` (the concrete discipline); **(iii) event-driven** `τ ≡ ∞` (no scheduled work: the cell acts only on ingress); **(iv) wavefront-W** — a *global* barrier every W logical units: all cells advance together at barrier instants (PLATO's 1/60-second broadcast frame; the synchronous-language stance). (iv) is not a per-cell `τ`: it is a discipline on the **synchronized product**, and therefore leaves Q1's asynchronous product — see GC-T9.

**GC-L2 — Tick erasure: the time-free stratum.**

> **Lemma.** Erasing tick-kind events from any generated run (keeping the apply/dial events the ticks scheduled) leaves the balance evolution and every judgment verdict unchanged. Hence every theorem of the ledger and judgment families is **tick-agnostic**: it holds under every discipline in Θ.
>
> *Proof.* Tick events post no transactions and render no verdicts (GC-P0.3: apply events are the only balance-changing events; the judgment organ is consumed by view/effect services, not by the tick itself). Erasure commutes with the balance projection and the verdict projection; a proof by induction over runs transports along the erasure. ∎

**GC-X4 — Event-driven discipline starves freshness.**

> **Counterexample.** Discipline (iii), single cell, service policy ingress-first (legal: with `τ ≡ ∞` there is no non-deferrable scheduled event to prioritize against it). A continuous ingress storm arrives; a view is issued at `t₀`. The view is queued behind unbounded ingress and is never serviced: `L = ∞`, and no `(F, L)` bound exists for any finite F. The freshness-composition and session-illusion theorems are not false here — they are **unsatisfiable in hypotheses**: the deadline clause (Q5) was exactly the axiom their traffic-independence consumed. (This is the historical failure the v1 hardware interlock was designed against, and the reason event-driven cells in practice smuggle ticks back in as timers.) ∎

**GC-T8 — Wavefront ⊑ local-tick: eager simulation with F ≤ W.**

> **Theorem.** Every run of a wavefront-W calculus is simulated by a state-adaptive local-tick calculus with `τ ≡ W`: per-cell apply sequences are preserved (each barrier's batch is serviced eagerly on arrival, in the same per-cell order), and every view bound the wavefront guarantees (state age ≤ W at observation) holds in the simulation with `F = W`.
>
> *Proof.* Given a wavefront run R: cell c computes on barrier batches `B₀, B₁, …` at instants 0, W, 2W, …. Construct the local-tick run R′: c services the deliveries of batch `B_k` immediately on arrival (eager service), and c's tick fires at c-local times `kW + φ_c` (any phase). Per-cell apply order: identical (A3 orders each cell's service; the batch's internal order is a per-cell order in both). Freshness: at any observation instant t, c's state is its post-batch-k state for some k with `t − (kW + φ_c) ≤ W` (the next tick is within W), so staleness ≤ W. Latency improves or stays (eager service services no later than the barrier). The simulation forgets only the wavefront's *jointness* — the barrier's simultaneity — which no per-cell observation reads. ∎
>
> **The converse price (observation, feeding GC-C2).** Simulating a local-tick calculus in a wavefront machine requires buffering inter-barrier arrivals: a cell may legally receive arbitrarily many deliveries between barriers (Q1–Q5 bound *service*, never *arrival*), so a wavefront simulator preserving every behavior needs unbounded per-cell ingress buffers in general. The historical bounded answer is PLATO's output controller: two 1024-word double-buffered memories + **write-only-changes** — the burst is bounded *by protocol design* (deltas, not frames; NOPs to idle terminals): the special case where the source's shape caps the buffer. Whether any bounded-buffer wavefront simulation exists for *arbitrary* sources is exactly conjecture GC-C2.

**Axis table (§4, one line each).**

| Axis | Survives | Breaks | Counterexample | Repair (price) |
|---|---|---|---|---|
| n-ary links | conservation family, arity-blind by proof inspection (GC-T3) | naive consent: phantom links, Q2 (GC-X1) | 2-of-3 consents read as a 2-link | escrow + closer + tick refund (GC-T4; +k+1 transactions, a coordinator) |
| typed cells | everything — typing is a refinement (GC-T5) | nothing *of the theorems*; implicit types break cross-substrate verdict uniqueness (GC-X2) | `0xC8` as u8 vs i8 | type schema in the interface digest (GC-T6; nominal typing was this all along) |
| non-commutative effects | run-ordered conservation family (GC-L1) | mirror convergence, fold order-independence, consolidation/encapsulation (GC-X3) | gated transfer T₁ vs credit T₂, two arrival orders | source-order FIFO delivery (GC-T7; spends reorder tolerance — nonce becomes sequence) |
| tick disciplines | ledger + judgment families, all Θ (GC-L2) | freshness/illusion under (iii) (GC-X4); Q1 under (iv) — synchronized product | ingress-first starvation; barrier = global event | deadline clause (Q5) for (iii); eager simulation for (iv) with F ≤ W (GC-T8); buffering price → GC-C2 |

---

## 5. Composition theory: the product calculus

### GC-D11 — Adapter span

> **Statement.** Given calculi 𝕂₁, 𝕂₂, an **adapter span** is a triple `(𝔄, e₁, e₂)`: a signature 𝔄 (the **adapter signature** — flit formats and consent postings only) and **thin embeddings** `e_i : 𝔄 → Ω_i` — maps assigning each adapter operation a macro in 𝕂_i — such that:
> - **thinness:** every `e_i(α)` adds no judgment (no tolerance, no verdict beyond zero-tolerance structure checks), no state of its own, and is total (the D13 adapter discipline lifted to calculi);
> - **encoding agreement:** there is a canonical encoding of 𝔄-flits (GC-P0.7) that both `e₁` and `e₂` decode identically — bit-exact, or within a declared ε with the ε judged;
> - **consent representability:** both `Ω_i` can book the shared-nonce consent transaction of GC-P0.4 for adapter links (the escrowed form of GC-T4 if arity is needed).

### GC-D12 — Product calculus

> **Statement.** The **product** 𝕂₁ ⊠ 𝕂₂ of two calculi with an adapter span: cell set = disjoint union; states and interpretations componentwise; links: intra-calculus links as in each factor; **cross-links** only over adapter operations (the span's 𝔄-flits), formed by the consent discipline in both factors. Runs: interleavings over the union cell set with the union delivery relation (cross-link deliveries decode via the span).

### GC-T9 — The product theorem

> **Theorem.** If 𝕂₁, 𝕂₂ ∈ QS and an adapter span `(𝔄, e₁, e₂)` exists, then 𝕂₁ ⊠ 𝕂₂ ∈ QS. Moreover: (i) every transaction crossing the calculus seam is an ordinary crossing transaction in the union ledger, so the conservation family applies to the product unmodified; (ii) a view chain crossing the seam is `(F₁ + L_ad + ΣL₂, ·)`-bounded, where `L_ad` is the adapter hop's bounded service time (thinness + Q4⁺); (iii) heterogeneous tick disciplines are permitted: each cell keeps its factor's discipline.
>
> *Proof.* **Q1:** product runs are interleavings over a disjoint cell set coupled only by delivery (the union of two asynchronous products with a delivery relation restricted to links — still an asynchronous product); the adapter adds no cell, no state (thinness), so no new coupling. **Q2:** cross-links carry the 𝔄 schema-digest in both factors' interface theories; consent is the shared-nonce transaction, bookable by hypothesis (span condition 3); malformed adapter flits reject at zero tolerance in both factors (thinness). **Q3:** a seam-crossing effect is one transaction whose posting vector lives in the union account universe; it commits at its owners under one nonce (both factors' apply events, each doing its half); balance is a property of the whole vector — A1 at product level. Encoding agreement (span condition 2) is what makes "one transaction, two decodes" coherent: both sides apply the same vector. Interior-to-a-factor transactions are interior to product cuts ⊇ the factor; conservation transports. **Q4:** factor services are total; adapter service is total (thinness). **Q5:** per-cell disciplines, each with its own deadline clause. (i) and (iii) are now immediate; (ii) is the freshness-composition law with the adapter hop as a relay whose latency is bounded by its total service. ∎
>
> **The necessity question.** GC-T9's converse — *no span, no quilt-shaped product* — is conjecture GC-C3 (§7): the claim that adapter-less calculi cannot be linked into QS by any protocol cleverness, every candidate discipline failing some axiom.

**Worked example: the snap pair is a product.**

> The semantic tower's game-port simultaneity (its §5) is an instance of GC-T9: 𝕂₁ = the game calculus (frame-ticked, `τ ≡ 1/60`, event-serviced renders), 𝕂₂ = the twin calculus (hardware-ticked, sensor-serviced), adapter span = the shared-variable interface (one integer datum, the deadband dial, the four-posting snap transaction). The product theorem gives: the seam transaction (the snap) is an ordinary crossing transaction — its four postings balance across the union ledger, so authority custody and debt accounting hold in the product exactly as in the single-calculus treatment; the pair judge's view bound crosses the seam at `F₁ + L_ad`; **heterogeneous ticks are legal**, and the pair-boundary discipline is the slower factor's boundary.
>
> **Corollary (heterogeneous-tick deadband).** *In a product snap pair with tick periods `τ₁, τ₂`, the deadband invariant holds at pair boundaries (the aligned-tick instants of the slower factor), and the mid-boundary divergence bound reads `|g − s| ≤ Δ + ρ_pair` with `ρ_pair` the per-**pair-period** divergence bound — ρ must be quoted at the longer period, not per-factor.* *Proof.* The invariant's induction runs on the boundary sequence where the judge evaluates; between boundaries, each side moves by at most (its rate) × (pair period); sum the two motions exactly as the single-calculus proof does at its own period. ∎
>
> This corollary is the formal content of "the contract spans substrates, so the contract chooses the cadence": the pair period is a *contract* quantity, and quoting ρ per-tick across heterogeneous ticks is the arithmetic error the corollary forecloses.

---

## 6. The compiler correspondence: compilation as a morphism of calculi

### GC-D13 — Calculus morphism

> **Statement.** A **morphism** `Φ : 𝕂_s → 𝕂_t` is a pair of maps:
> - **states:** `Φ_S` assigns each source cell `c` a finite **sub-quilt** of target cells (a placement plus local wiring), and each source state `s ∈ S_c` a target state-set `Φ_S(s)` over that sub-quilt, such that the quantity projections round-trip within declared tolerance: `‖q(Φ_S(s)) − q(s)‖ ≤ ε_q` for every declared quantity `q` (the encoding discipline of GC-P0.7);
> - **operations:** each source verb `ω` at `c` expands to a finite **macro** of target verbs over `Φ_S`'s sub-quilt (an operational macro: a finite op-sequence with bounded service).
>
> The morphism is **faithful** iff additionally:
> - **(M2) semantic commutation:** for every generated source run there is a target run of the macro-expansions whose observations (verdicts, rendered quantities) agree with the source's within declared tolerance at every observation point;
> - **(M3) booking preservation:** the macro of `effect`/`forget` maps each source transaction to target transactions with the same nonce class and **balanced image** — the induced ledger map is a homomorphism on posting vectors (projection-or-identity on supports; balance preserved);
> - **(M4) provenance carriage:** the image carries the source's manifests (rendering equations with units, tolerance dials, raw provenance) as target state — the metadata a zoom needs (§6.2).
>
> A morphism lacking M3 is **forgetful**; lacking M4, **opaque**.

### GC-T10 — Faithful morphisms compose; the image of a quilt is a quilt

> **Theorem.** (i) Faithful morphisms compose: `Ψ ∘ Φ` is faithful, with tolerances summing (`ε_{ΨΦ} ≤ ε_Φ + ε_Ψ` — the additive tolerance law) and macros concatenating. (ii) If `𝕂_s ∈ QS` and `Φ : 𝕂_s → 𝕂_t` is faithful, the **image calculus** `Φ(𝕂_s)` — the sub-calculus of 𝕂_t generated by the macros — is quilt-shaped.
>
> *Proof.* (i) M1: the round-trip composes through the intermediate quantities; each leg is within its ε; the triangle inequality sums them (the same computation as tolerance composition under serial stages — the additive law again). M2: macro of macros is a macro; run correspondence composes by chaining the two simulations; observations agree within the sum. M3: homomorphisms compose; balanced images of balanced images are balanced (a homomorphism maps 0 to 0 on posting vectors). M4: manifests carried into carried state. (ii) Transport each axiom's witness along Φ. Q1: the macro of a source verb is a finite sub-quilt computation; locality of the target plus the finiteness of the sub-quilt keeps every generated image run an interleaving (the image's coupling is wiring the morphism itself laid down — links, consent-formed by M3's representability of the consent transaction). Q2: image links are target links; consent bookable (M3); schemas carried (M4's manifest includes the interface digest). Q3: image effects are balanced (M3); the cut functionals of the image are the projections of the source's. Q4: finite macros of total services are total (bounded concatenation). Q5: the tick macro schedules within bounded service (M2 + Q4), giving the image its deadline clause. ∎

**The tower, restated.** The semantic tower's levels are now theorems' hypotheses: **L0→L1 is elaboration** — a presentation change (prose notation for the same interpreted calculus; the identity morphism, faithful trivially); **L1→L2 is realization** — a faithful morphism from the abstract calculus to a substrate calculus (C/ESP32, Verilog/fabric, JS/worker), each substrate's *capability manifest* being precisely the witness kit for the target's quilt-shape (below); **L2→L3 is encoding** — the canonical-encoding bijection (GC-P0.7), faithful with ε = 0 bit-exact. GC-T10 is why the tower stands: faithfulness composes level over level, so L3 binaries inherit quilt-shape from L0 sheets through the whole chain — *nothing below the horizon ever meant "nothing below the law."*

### GC-T11 — Zoom is faithfulness: localization lifts along faithful morphisms

> **Theorem.** If the source calculus satisfies the rendering-chain invariant (every displayed value is the endpoint of a finite chain of cells-with-equations over wired links, terminating at raw IO), and `Φ` is faithful (M1–M4), then the image satisfies it: every image-displayed value chains to image raw IO through image links, with the equations carried by M4. Contrapositively, debugging-by-zoom survives every faithful compilation.
>
> *Proof.* The source chain `raw →_{f₁} x₁ → … → v` maps to `Φ(raw) →_{Φ(f₁)} Φ(x₁) → … → Φ(v)`: each `fᵢ` is a cell (image sub-quilt by M1), each arrow a wiring (the morphism's own links, consent-formed), each equation carried (M4), each macro total (Q4 transport). The chain is finite (finite macros). The localization theorem (wrong displayed value ⇒ wrong equation, wrong wiring, or wrong raw; no fourth place) is a property of the chain structure, inherited by the image chain verbatim. ∎

**GC-X5 — The fourth place, constructed: a forgetful/opaque compilation.**

> **Counterexample.** Compile the oil-pressure cell's equation `psi = (mV − 500)·3/80` to a *floating-point* target **without declaring an envelope and without carrying the equation**: the arithmetic is now approximate in a way no manifest records (no ε declared: M1's tolerance is unstated), the books book nothing of the rounding (M3 vacuous — no transactions in the arithmetic), and the displayed PSI has no equation to zoom to (M4 dropped: the compiled artifact is arithmetic without provenance). A wrong displayed value now has a failure site the chain cannot reach — *rounding below the horizon* — the fourth place, constructed. This is not hypothetical hygiene: it is the pre-repair state of the tower's own float-free lemma and its error-budget derivation (the repairs — declared envelopes, exact-integer discipline, provenance KV — are exactly M1/M3/M4 restored). ∎

### GC-P1 — The substrate table is the quilt-shape witness kit

> **Proposition.** The semantic tower's substrate capability table (its §7) is, row for row, the evidence a realization morphism must present for the *target calculus* to satisfy the axioms:
>
> | Substrate fact | Axiom/condition witnessed |
> |---|---|
> | numeric discipline (FPU? Q-formats?) | Q4 + verdict-unique arithmetic (exact-integer discipline or declared ε) |
> | memory budget | GC-P0.7 serializability (state-is-a-file: the sub-quilt fits and round-trips) |
> | tick guarantee (hardware interlock?) | Q5's deadline clause |
> | IO surface | the raw-IO vocabulary (rendering-chain leaves; zoom's termini) |
> | allocation policy (none-in-loop?) | Q1/D18 (no hidden global allocator = no global verb; flat warm image) |
> | latency class | Q4⁺ (bounded service: the `L` in every freshness law) |
> | verification harness | the meta-row: verification *is* a judgment on the morphism (zero-tolerance ACCEPT of the capability manifest; a substrate without a harness is not a target — "a rumor") |
>
> *Proof.* Row-wise: each row either is a hypothesis of an axiom's witness (as displayed) or is the observation that the row names the target-side object an axiom quantifies over. No row is decorative; no axiom lacks its row. ∎

### 6.4 The lineage, placed formally: partial interpretations of QS

The lineage lane's thesis — the six verbs as "the common denominator of PLATO's TUTOR runtime, RPG's program cycle, COBOL's ledger batch, and FORTRAN's array machine" — becomes a checkable claim under GC-D4–D8: each historical system is a **partial interpretation**, holding some organs and lacking exactly the ones its history explains. The verb × system table (✓ present in-language; ~ partial/degenerate; ✗ absent):

| | bind (dials) | link (consent) | effect (books) | view (bounded read) | tick (deadline) | forget (receipt) | verdict |
|---|---|---|---|---|---|---|---|
| **TUTOR/PLATO** | ✓ (`specs` family: per-judger switches, `toler`, `nospell` — tolerance *is* state) | ~ (notesfiles/term-talk had authentication at the community layer; not a language-level consent transaction) | ✗ (**the books were kept about the system, not by it**: NTU billing post-hoc; no booking in the opcodes) | ✓ (frame-bounded: 1/60 s output frame, NOP to idle) | ~ (**global/wavefront**: the broadcast frame — Q5 in synchronized-product form, not local) | ✗ | *judgment fully born (tri-state verdict, pseudometric bit-vector matching, aliases-as-data); the session illusion empirically real; locality broken by shared common blocks (multi-writer state); the ledger never a language citizen.* |
| **RPG** | ✓ (indicators 01–99: booleans as state gating the cycle) | ✗ (files, not links: batch transfer is wiring without a handshake) | ~ (level-break totals: balance as a *run-end audit* — effectfulness deferred to batch close, not per-commit) | ✗ (the world between runs is invisible: F = batch period) | ✓ (the program cycle: the loop *is* the structure — the purest tick) | ✗ | *the tick in its most disciplined form; the ledger deferred; links and views absent — the batch shape.* |
| **COBOL** | ~ (PICTURE: data described as forms — typing more than dials) | ✗ (master/transaction files; no consent) | ✓ (control totals, hash totals, the audit trail: double-entry discipline at batch granularity — A1 as run-end invariant) | ✗ (batch F) | ✓ (the run = the cycle) | ~ (closing entries exist in the accounting practice COBOL encodes — reversal-as-forget, un-receipted in-language) | *the transactional lineage complete at batch granularity; per-commit effectfulness, links, and views are what it structurally could not have.* |
| **FORTRAN** | ✗ | ✗ | ✗ (assignment unbooked — Backus's own 1978 verdict: the assignment statement as the bottleneck) | ~ (I/O without bounds) | ✗ (time-free) | ✗ | *not a partial backend at all — and the source of the thing the others lacked: the **morphism discipline**.* |

> **The Split, formalized (GC-P2).** The 1954 abstraction moment — "information concerning… a large number of other coding techniques is built into the FORTRAN system and it is not necessary for the programmer to be familiar with this information" — is the declaration that compilation may be **forgetful**: the machine model (timing, layout, word size, IO discipline) left the language, and with it the organs Q1/Q3/Q5. Formally: the era's dominant morphisms ceased to be faithful (M3 dropped first — unbooked assignment; then M4 — no provenance in the artifact; then Q5 — time-free semantics), and the kernel/BIOS lineage is precisely the population of engineers who kept maintaining the forgotten organs *by hand*, outside any calculus. The counter-examples (the lineage's own): the Burroughs B5000 and the Cray-1's vector registers are machines built to keep the morphism faithful for one language family each — the exception proving the forgetful rule. What each tradition got right, in these terms: **PLATO/TUTOR**: the judgment organ complete, tolerance-as-state, totality by budget (the 300-char judging bound — a fail-static device), and the session illusion with real bounds — but the tick was global (the wavefront discipline, GC-D10(iv)) and the books were outside the language, which is why its scaling story ("plug in another server") met the shared-state wall (Q1). **RPG/COBOL**: locality, tick, and (COBOL) the ledger at batch granularity — but effectfulness deferred to run-end makes interactive consent impossible (a bad entry is discovered at close, not at commit: the per-commit discipline is what a link needs), and the view organ is absent, so F = the batch period. **FORTRAN**: the morphism discipline itself — compilation as a checked, optimizing, *simulable* map (the 1957 compiler's Monte Carlo block placement is simulation validating a morphism, the ancestor of golden-model testbenches) — and state made mathematical (arrays). The cell calculus is the **conjunction**: six organs, five axioms, one tuple — the rejoin the lineage lane predicted, now with the missing-organ table as its proof of necessity (GC-T2's Θ-verbs are, row for row, the organs the historical systems lacked).

---

## 7. Conjectures (the honest register)

Four new falsifiable conjectures about the general calculus. Each carries: statement, what is proved around it, the **registered falsifier** (the artifact a hostile party executes to kill it), and grade. House rule: a falsifier written with the claim is a bet with posted stakes.

**GC-C1 — Signature sufficiency (the six-verb hypothesis).**

> *Statement.* Every quilt-shaped calculus 𝕂* — every signature Ω* and interpretation satisfying Q1–Q5 over any skeleton — is **behaviorally reducible** to the concrete signature: each `ω* ∈ Ω*` expands to a finite macro of the six verbs such that the expansion preserves and reflects verdicts (within declared tolerance), conservation constants (exactly), and freshness bounds (within additive slack). No seventh primitive is ever needed.
>
> *What is proved around it.* GC-T2 (organ minimality — the "no fewer" side: each verb is load-bearing). The macro-expressibility of the axis repairs (GC-T4's escrow, GC-T7's sequencing, the snap pair) are existence proofs for nontrivial families: n-ary consent, ordered delivery, and cross-calculus correction all reduce.
>
> *Registered falsifier.* A triple `(𝕂*, ω*, I)`: a calculus with the five axioms verified in-document; an operation `ω*` of its signature; and an invariant `I` — with proof — that every six-verb macro-expansion preserves `I` while `ω*` breaks it (a separation). The triple published with its proofs kills the conjecture; a macro found for any candidate strengthens it. *Grade: open.* The adjacent known result is the compilers-side analogy (Turing-complete cores with tiny opcode sets), which supplies reducibility *of computation* but not of **organ fidelity** — verdicts, books, and bounds, not just behavior; that gap is why this is a conjecture and not a citation.

**GC-C2 — The synchrony separation.**

> *Statement.* (a) Every wavefront-W calculus is eagerly simulated by a local-tick calculus with freshness F ≤ W (GC-T8 — **proved**, the ⊑ direction). (b) **No** wavefront calculus with bounded per-cell ingress buffers simulates the local-tick calculi: for every buffer bound B there is a local-tick quilt (a burst source: a cell legally receiving more than B deliveries between barriers) whose behaviors no bounded-B wavefront machine preserves without dropping or blocking — and dropping loses behaviors, blocking breaks totality (Q4).
>
> *Registered falsifier.* A wavefront simulator with fixed buffer bound B, no drops, no blocking, and a simulation proof covering *all* local-tick quilts (the artifact: the machine, the proof, and the treatment of the burst family — the source that emits k deliveries between barriers for adversarial k). Alternatively, a lower-bound proof (unboundedness for all wavefront simulators) resolves the conjecture positively. The historical stake: PLATO's controller is the bounded-B special case where the *source* is protocol-shaped to fit the buffer (write-only-changes); the conjecture says that shape was necessity, not thrift. *Grade: (a) proved — machine-checked bounded (`wavefront_bench.py`, W ∈ {2,3,4}); (b) open — burst pressure measured bounded (occupancy = k for k ≤ 12, exceeds every B ∈ {1,2,4,8}, no drops/blocks; evidence, not proof).*

**GC-C3 — Span necessity for composition.**

> *Statement.* GC-T9's converse: if no adapter span exists between 𝕂₁ and 𝕂₂ (no signature with thin embeddings, encoding agreement, and consent representability), then **no linking discipline whatsoever** makes a quilt-shaped product: every candidate cross-calculus link discipline violates at least one of Q1–Q5 (a hidden global verb for Q1, an unbookable or unilateral consent for Q2/Q3, a partial decode for Q4, or an unservicable deadline for Q5).
>
> *Registered falsifier.* A pair of calculi with adapter-impossibility *proved* (e.g.: disjoint account semantics — one side's conservation is integer-custody, the other's is unbounded-mass with no integer conserved functional; or encoding disagreement with no declared ε), **plus** a cross-link discipline, **plus** a five-axiom verification of the linked product. The triple kills the conjecture; the discipline would be a genuinely new composition mechanism. *Grade: open.* What is proved: the "if" direction (GC-T9) and the necessity of each *individual* span condition (drop encoding agreement → GC-X2's failure; drop consent representability → GC-X1's; drop thinness → the adapter judges, and judgment at the seam is a global verb — Q1) — the three single-condition necessities are now also machine-exhibited (`product_bench.py`, §8.5).

**GC-C4 — The snap normal form.**

> *Statement.* Let `T` be any transaction between two cells sharing a dependent variable, such that: (i) balanced; (ii) idempotent by nonce; (iii) **custody-conserving** on every shared-variable authority family (`Σ auth = 1` invariantly); (iv) **reality-wins** (on fire, the dependent variable is assigned the sensor-side value, never blended). Then `T`'s action on the authority-and-debt account family is equivalent to a composition of four-posting snaps: authority swap `(G:auth −1, T:auth +1)` paired with debt booking `(G:snap-debt +|g−s|, T:debt-issued −|g−s|)` — the monograph's emended form is the **normal form** of correction transactions.
>
> *What is proved.* The single-variable, single-fire case: the four-posting form is the unique balanced form booking authority and drift with those invariants (the "no third option" argument, upgraded in the monograph to the emendation theorem) — and the bounded single-fire class is machine-verified (`product_bench.py`, §8.5: every enumerated survivor is the four-posting form; every excluded candidate dies by a named clause). *Registered falsifier.* A transaction `T` satisfying (i)–(iv) whose account-action is not generated by the normal form (not a composition of swaps and paired debt bookings), with the invariant checks exhibited — the kill; a normal-form derivation for any candidate `T` strengthens. *Grade: open.* The n-variable, multi-fire case is where the wiggle room lives (partial authority, deferred debt, variable-coupled corrections).

---

## 8. Machine-check status, honestly

Pen-only for the proofs (the house grade for tower papers): GC-T1–T11 are theorems about formal objects, proved above by proof-inspection and construction; the two inspection lemmas (GC-L1, GC-L2) are mechanical proof-audits of the monograph's arguments and are themselves checkable by re-reading the cited proofs against the stated consumption claim. The benches that exercise the constructive content were specified to assertion level and are now **BUILT and PASSING** (gcmetal lane, 2026-08-29: exact-integer enumerators, zero float verdicts, in `tools/verifies/`; lane runner and bounds register `tools/gc-verifies/run_gc.sh`; 1,337,024 checks total across the five, 0 failures; the three pre-existing verifies benches re-run green as a regression guard). Status per bench:

1. **`escrow_bench.py`** — k-ary consent over the tapfabric ledger: run GC-X1's naive protocol (assert the phantom-link reading fires: a pairwise scanner declares the A–B link) and GC-T4's escrow (assert: no phantom under pairwise scanning; formation fires only at k-full; refund fires at the tick deadline; all cut constants conserved at every commit).
   **Status (gcmetal 2026-08-29): BUILT, PASS — 519 checks.** GC-X1 EXECUTED (the pairwise scanner declares the A–B 2-link from 2-of-3 naive consents; under the joint definition the failure inverts: capacity stranded against no link; phantom fires on exactly the |S| ≥ 2 subsets, k ∈ {3,4} enumerated). GC-T4 **CLOSED-BOUNDED**: k ≤ 4, every nonempty consent subset (25 escrow runs) — no links-held posting exists outside the formation transaction, formation only at k-full, refund at exactly the τ_consent = 3 deadline, every cut (all 2^k subsets) constant at every commit (GC-T3's arity-blindness checked literally, not by inspection).
2. **`nc_bench.py`** — non-commutative effects: the gated transfer of GC-X3 (assert: the two delivery orders reach the exhibited divergent balances `(13,0)` vs `(3,10)`), then FIFO discipline on (assert: convergence, divergence = delivered-prefix in-flight exactly).
   **Status (gcmetal 2026-08-29): BUILT, PASS — 10,194 checks.** GC-X3 EXECUTED (orders [T1,T2] → (13,0), [T2,T1] → (3,10); the gate fires/skips exactly as specified; reordering divergence is generic at these bounds: 9/35 multisets order-diverge). GC-L1 **CLOSED-BOUNDED** (Φ constant at every commit under every enumerated order: 1,117 ordered runs over 85 sequences). GC-T7 **CLOSED-BOUNDED**: 4,944 at-least-once schedules (reorders + retransmits) — applied log is always the delivered prefix, mirror state = the prefix fold, divergence = in-flight exactly, two-mirror convergence on 1,236 paired schedules; the PRICE exhibited: naive any-order reaches non-prefix states on 54 of 416 replays where FIFO queues the reorder as a defined outcome (336 detections).
3. **`wavefront_bench.py`** — GC-T8's eager simulation (assert: per-cell apply sequences preserved, staleness ≤ W) and the GC-C2 burst family (assert: buffer demand exceeds any fixed B, no drops, no blocks).
   **Status (gcmetal 2026-08-29): BUILT, PASS — 59,783 checks.** GC-T8 **CLOSED-BOUNDED**: W ∈ {2,3,4} × 27 batch shapes × ≤ 40 due-time patterns × φ ∈ 0..W−1 (8,172 sim constructions) — apply multisets preserved, batch order preserved, staleness ≤ W at every observation instant, delivered-item latency no later than the barrier; φ = 0 gives full sequence equality (2,508 runs). GC-C2(a) machine-checked. GC-C2(b) pressure MEASURED: occupancy = k exactly for every burst (k ≤ 12; linear, no plateau), demand exceeds every B ∈ {1,2,4,8} with no drops and no blocks (bounded machine must drop or block; unbounded preserves behavior) — **EVIDENCE-BOUNDED, grade unchanged (open)**.
4. **`type_bench.py`** — GC-X2 (assert: u8/i8 divergence on `0xC8` through two decoders), GC-T6 (assert: digest-pinned decode agrees).
   **Status (gcmetal 2026-08-29): BUILT, PASS — 10,772 checks.** GC-X2 EXECUTED (0xC8 → 200 vs −56 → ACCEPT/REJECT on identical bytes; census over all 256 bytes boundary-exact: every radius r < 256 splits exactly the 128 high bytes, r = 256 splits none — the decode delta is exactly 256). GC-T6 **CLOSED-BOUNDED**: digest-pinned decode agrees on the full byte × anchor × radius grid (9,216 comparisons, zero splits); every u8/i8 pairing refused by the nominal rule (4,608 refusals, a defined no-link outcome); the STRUCTURAL counterfactual wires the bad pair and diverges on 128/256 bytes — the name-and-digest rule is load-bearing, not decorous.
5. **`product_bench.py`** — the snap pair over heterogeneous ticks (assert: the heterogeneous-tick deadband corollary; ρ quoted at pair period).
   **Status (gcmetal 2026-08-29): BUILT, PASS — 1,255,756 checks.** GC-T9's worked instance **CLOSED-BOUNDED**: (τ₁,τ₂) ∈ {(3,2),(5,2)}, Δ = 1, rates 1, horizon two pair periods — seam snaps are ORDINARY CROSSINGS (one nonce at both owners, posting sum zero, union cut constant at every commit on every enumerated run, factor cuts move by the exact crossing halves, seam replay a no-op), heterogeneous ticks legal on schedule, snap round-trips bit-exact through the span's canonical encoding (span path = direct path), thinness and consent representability checked structurally; the heterogeneous-tick deadband corollary holds with ρ at the PAIR period on every enumerated run (worst mid-boundary = Δ+ρ tight, witnesses exhibited) while the per-tick quote is FALSIFIED on both configs and the faster-factor-period quote on (5,2). GC-C3 direction: each span condition's necessity machine-exhibited (encoding agreement dropped → seam books unbalanced by exactly 144; consent representability dropped → seam phantom with no shared nonce; thinness dropped → ownerless adapter drop: Q1 violated and union cut moves) — **grade unchanged (open)**. GC-C4 bounded probe: on the enumerated single-fire correction class (g,s ∈ [−3,3], α ∈ [−2,2], x ∈ [−3,3], pure/blend/freeze) all 90 survivors are exactly the four-posting normal form and all 4,320 exclusions die by a NAMED clause (blend/freeze/underbook/overbook/sign-reversal/custody) — no third option at this scale; **grade unchanged (open)**.

A falsification of any proved statement is a publishable trace (the house rule); a falsification of a conjecture is the registered artifact doing its job. **The five benches exist and pass (gcmetal lane, 2026-08-29); zero falsifications — every proved statement checked at the stated bounds held, and every counterexample fired exactly as printed.** What the benches did not close: GC-C1 (its falsifier is a separation triple, not a bounded enumeration — unprobed), and the open halves of GC-C2(b), GC-C3, GC-C4 (bounded evidence recorded above; grades unchanged). The bench-absence this section registered at G5 (DEPENDENCY-GRAPH §6) is remedied for all five benches; the conjectures keep their register entries.

---

## 9. Related work

**Process calculi and asynchronous products.** The skeleton's asynchronous-product locality (Q1) is the classical stance of actor models and asynchronous π-calculi [Agh90; HT91]: agents, point-to-point async messages, no shared store. The quilt-shape axioms are a *disciplinary* overlay — what actor freedom must give up to earn conservation, consent, totality, and deadlines — closer in spirit to session types' discipline on π [Hon93] (consent ≈ session initiation) than to any single calculus; the ledger organ (Q3) has no counterpart in the actor family, which is the point of carrying it.

**Petri nets and place invariants.** Conservation under additive effects is a place invariant (the monograph's kinship remark); the non-commutative axis (§4.3) corresponds to the net-theory distinction between incidence-linear invariants (order-free) and reachability-sensitive properties (order-dependent) [Mur89] — GC-L1/GC-X3 draw that line inside one ledger.

**Synchronous languages and GALS.** The tick axioms (Q5, Θ) sit between Esterel/Lustre's global logical tick [BB91] (the wavefront discipline, GC-D10(iv)) and globally-asynchronous-locally-synchronous design; GC-T8/GC-C2 formalize the async-vs-sync expressiveness trade the synchronizer literature studied for networks [Awe85] — here restated for *cells with ledgers and freshness bounds*, where the price is measured in buffers and the currency is staleness.

**CRDTs, op- vs state-based.** GC-T7's FIFO repair is the causal-delivery hypothesis of operation-based CRDTs [SPBZ11] restated as a *price* (reorder tolerance spent); GC-X3 is the standard counterexample shape (commutativity failure) instantiated on a concrete custody ledger.

**Compilers and correctness.** Faithful morphisms (GC-D13) sit in the verified-compilers tradition: CompCert's simulation-based refinement [Ler09] is M2 with ε = 0 and no organ structure; provenance carriage (M4) is the observation leveled-up from provenance-aware systems and the tower's own KV keys — the recognition that *semantic* preservation without *provenance* preservation breaks maintenance (GC-X5), which is a correctness property verified compilers do not state.

**Historical systems.** The lineage placements (§6.4) consume the repo's own primary-source sweep (CERL X-5/X-20/X-27/X-35, Avner 1981, the 1954 FORTRAN Preliminary Report, Backus 1978) as *provenance for organ presence/absence*, not as mathematical dependencies; each ✗/~ in the table is checkable against the cited documents.

---

## 10. Statement registry

| Kind | Items |
|---|---|
| Preliminaries (5+3) | GC-P0.1 cell/state/events · P0.2 postings/ledger · P0.3 runs/cuts · P0.4 links/consent · P0.5 views · P0.6 tick · P0.7 encoding · P0.8 the concrete 5+1 signature (counted as 8 statements in 5 families) |
| Definitions (20) | GC-D1 signature · D2 skeleton · D3 interpretation · D4 Q1 locality · D5 Q2 link-respect · D6 Q3 effectfulness · D7 Q4 totality · D8 Q5 tickedness · D9 quilt-shaped · D10 discipline classes · D11 adapter span · D12 product · D13 morphism (faithful/forgetful/opaque) · D14–D20 reserved by §5–6 inline (span conditions, faithfulness clauses M1–M4, image calculus, partial interpretation) |
| Theorems (12) | GC-T1 instantiation (5+1 ∈ QS) · T2 organ minimality · T3 arity-blind conservation · T4 escrowed consent · T5 typing-as-refinement · T6 types-in-digest · T7 FIFO repair · T8 wavefront eager simulation · T9 product theorem · T10 faithful composition + image quilt-shape · T11 zoom-is-faithfulness · (heterogeneous-tick deadband corollary, §5 inline) |
| Lemmas/Propositions (5) | GC-L1 no-commutativity lemma (conservation survives) · GC-L2 tick erasure · GC-P1 substrate table = witness kit · GC-P2 the Split formalized · (eager-simulation freshness clause, within T8) |
| Counterexamples (5) | GC-X1 phantom link (n-ary naive consent) · GC-X2 signedness (implicit types) · GC-X3 mirror divergence (non-commutative) · GC-X4 view starvation (event-driven) · GC-X5 the fourth place (opaque compilation) |
| Conjectures (4) | GC-C1 signature sufficiency · GC-C2 synchrony separation · GC-C3 span necessity · GC-C4 snap normal form — each with registered falsifier |

**What this paper adds beyond the sources.** Over `quilt-calculus.md`: the abstraction (signature/skeleton/interpretation; the five quilt-shape axioms) with the concrete system *proved* an instance (GC-T1) and organ-minimal (GC-T2); the four generalization axes graded by survives/breaks/counterexample with two proved repairs (escrow, FIFO) and one eager-simulation theorem; the product calculus with the span-composition theorem (GC-T9); the morphism theory (faithful/forgetful) with composition, image, and zoom theorems (GC-T10/T11); the substrate-table correspondence (GC-P1); the historical systems placed as partial interpretations with the Split formalized (§6.4). Over the expansion papers: consumes their content as *instances* (drift-as-stage prices the dial organ; fold theory prices the forget organ's receipts; the floor prices the tick organ's audit side) without leaning on them. The four conjectures are new; each ships its kill condition.

---

*Generals lane, 2026-08-29. The tower had a floor and walls; it now has a capstone: the six verbs are one instantiation of a shape, the shape has a tested boundary (four axes, five counterexamples, three repairs), composition has a theorem with a conjectured converse, compilation has a definition with a conscience — and the claim that nothing else is needed is a bet, posted with its falsifier, in the register where bets live. The books balance: every organ credited to its century, every break exhibited, every repair priced.*

**References.** Internal (provenance, not prerequisites): `FOUNDATION.md`, `SEMANTIC-TOWER.md`, `LINEAGE.md`, `quilt-calculus.md` (D1–D18/A1–A7/T1–T11), `RHO-F-FLOOR.md`, `DRIFT-AS-PREFILTER.md`, `FOLD-COVERED.md`, `DENY-BY-RUNNING.md` (grades), `BRIDGES.md` (B1–B10), `DEPENDENCY-GRAPH.md` (§7 canonical names; this paper adopts them). External: [Agh90] G. Agha, *Actors*, MIT Press 1990 (canonical, carried). [HT91] K. Honda, M. Tokoro, *An Object Calculus for Asynchronous Communication*, ECOOP 1991 (canonical, carried). [Hon93] K. Honda, *Types for Dyadic Interaction*, CONCUR 1993 (canonical, carried). [BB91] A. Benveniste, G. Berry, *The synchronous approach…*, Proc. IEEE 79(9), 1991 (✤ via the monograph's verified registry). [Mur89] T. Murata, *Petri nets…*, Proc. IEEE 77(4), 1989 (✤ same). [SPBZ11] Shapiro, Preguiça, Baquero, Zawirski, *Conflict-Free Replicated Data Types*, SSS 2011 (✤ same). [Awe85] B. Awerbuch, *Complexity of Network Synchronization*, JACM 32(4), 1985 (canonical, carried — synchronizers). [Ler09] X. Leroy, *Formal verification of a realistic compiler*, CACM 52(7), 2009 (canonical, carried). Historical primary sources via `LINEAGE.md`'s registry: CERL X-5/X-20/X-27/X-35; Avner 1981 (ERIC ED208879); Backus et al., *Preliminary Report… FORTRAN*, 1954; Backus, *Can Programming Be Liberated…*, CACM 21(8), 1978.
