# FOUNDATION — quilt's mathematics, from the beginning

**Lane:** foundation (GLM-5.3, high-level) · **Date:** 2026-08-29
**Companions:** `LINEAGE.md` (the historical lane, concurrent — PLATO/Tutor, RPG/COBOL, FORTRAN vectorization, the hardware/software split; this document is its *formal* twin and deliberately repeats none of its history), `ABSTRACTION-MATH.md` (hardware semantics: dyadic staircases, traced monoidal wiring), `SYNTHESIS.md` (the v1 mechanisms these definitions describe), `BACK-DECK-APP.md` (the worked example running throughout).

> **The thesis being formalized (Casey's, stated plainly).** PLATO already contained every building block of quilt: asynchronous sessions that *felt* synchronous (and scaled by plugging in another server), approximate-answer judgment (misspelling-tolerant FORTRAN data analysis on Tutor judge fields), constraint vocabularies shaped by hardware price-points (plasma-panel economics) and user limitations (teachers), and the COBOL/RPG transactional lineage — every update debiting one side of a book and crediting another. Quilt is those four primitives, made explicit and cellular: **the ultimate backend under any OS** — distribute, mirror, stripe (compute *and* retrieval), secure, nest, embed, and interconnect generically with any protocol two cells agree on — with **double-entry bookkeeping as the intercell contract**.
>
> This document makes that thesis mathematical. Five definitions do the work: the **cell** (D1), the **judgment** (D2), the **ledger** (D3), the **session illusion** (D4), and the **distribution algebra** (D5). Everything else is corollary or honest debt (§5).

---

## 0. Preliminaries — words defined before they are used

- **State.** A cell's state is a finite, byte-addressable record: dials (named parameters), edges (weighted links with walk counts), routing, and a tick schedule. The doctrine pins this down physically: *state is a file* (QUF). Mathematically, state is just a set `S`; the file doctrine says every `s ∈ S` has a canonical byte encoding both a simulator and a silicon loader read identically (§4).
- **Time.** There is no global clock. Each cell keeps a **local clock** (a monotonically increasing counter of **logical instants**). A **tick** is the event that advances a cell's local clock; the fabric makes ticks **deadlines** (they cannot be starved by traffic — SYNTHESIS Q2). Wall time, when it exists at all, is just another dial.
- **Event.** An event is a discrete happening at a cell: an ingress flit accepted, a tick serviced, a dial written. Events at one cell are **serialized** (one interpreter — Law 2), so each cell has a total order on its own events. Across cells there is no total order, and quilt never pretends otherwise.
- **Commit boundary.** The point in a cell's event stream after which a state change is observable by other cells. One event = one commit. There is no multi-cell atomic commit; §1.3 explains why none is needed.
- **Account.** A named integer counter a cell maintains for bookkeeping: e.g. `TOTE-PORT:labels-emitted`, `XID-MATCH:labels-received`, `CAM-UW:retro-labels`. Accounts are the vocabulary of §1.3. A cell's accounts are part of its state.

Notation: `ℤ` integers, `ℝ≥0` non-negative reals, `𝒫(X)` powerset, `A → B` the set of functions A to B. `x : T` reads "x has type T."

---

## 1. The formal cell

### D1 — Cell

> **Definition (cell).** A **cell** is a 5-tuple
>
> `C = (S, J, L, τ, δ)`
>
> where
> - `S` — a set of **states** (finite, byte-addressable; dials + edges + accounts + tick schedule);
> - `J` — a **judgment function** (D2), `J : X → {ACCEPT, REJECT, AMBIGUOUS} × note`, consuming an input value from an input space `X` fixed by the cell's kind;
> - `L` — a **ledger** (D3), an append-only log of balanced transactions over the cell's accounts;
> - `τ : S → ℕ` — the **tick discipline**: a pure function from state to the next tick period (the schedule is state, so it round-trips QUF);
> - `δ ⊆ (E × S) → S` — the **transition relation**, where `E` is the cell's event alphabet (ingress flits, tick strobes, egress grants). δ is a *relation* but each cell serializes events, so on any run it behaves as a function.

Everything in a quilt is a cell: fabric cores, adapter ports (Law 4), application graph nodes (BACK-DECK-APP §2). A **quilt** is a finite set of cells plus a set of **links** (wired egress→ingress pairs). That is the entire ontology — there is no scheduler, no service registry, no message broker. Composition is wiring (§2).

The five opcodes are the only verbs that touch this tuple, and each maps to exactly one organ:

| Opcode | Organ touched | Formal reading |
|---|---|---|
| `qm_bind` | dials ⊂ S | parameter change, booked as a transaction (D3) |
| `qm_link` | links | negotiate a shared protocol (§2.5) |
| `qm_effect` | δ + L | a message *is* a balanced transaction (D3) |
| `qm_view` | J + S | a bounded-freshness read (D4) |
| `qm_tick` | τ, then δ | advance the local clock; run scheduled work |

### D2 — Judgment: match-with-tolerance as a metric-space operation

PLATO's Tutor **judge fields** accepted student answers with tolerance — the canonical instance being FORTRAN data-analysis problems where `32.4` was fine for `32.2` and *gravitee* was fine for *gravity*. Quilt generalizes the judge from a courseware convenience into a first-class organ of the cell.

> **Definition (metric space; pseudometric).** A **pseudometric** on a set `X` is `d : X × X → ℝ≥0` with `d(x,x)=0`, symmetry `d(x,y)=d(y,x)`, and the triangle inequality `d(x,z) ≤ d(x,y)+d(y,z)`. A **metric** additionally has `d(x,y)=0 ⟹ x=y`. A pseudometric permits *distinct things at distance zero* — which is exactly an alias (`pink ≡ humpy`): the ALIAS cell is the statement that the answer space's distance function is a pseudometric, and the canonical species ID is membership in a zero-distance class. *"Aliases are data" means the metric is a pseudometric.*

> **Definition (judgment function).** Let `(X, d)` be an answer space and `K` a set of candidate classes (the possible identities a match could confer). A **judge** is a pair `J = (A, r)` with `A ⊆ X × K` a finite set of **keyed answers** and `r : S → ℝ≥0` a **tolerance dial** (tolerance is state, not code). For input `x ∈ X`, define the **verdict set**
>
> `V(x) = { k : ∃ (a, k′) ∈ A, d(x, a) ≤ r ∧ k = k′ }`
>
> and the judgment
>
> `J(x) = ACCEPT(k)` if `V(x) = {k}`; `AMBIGUOUS` if `|V(x)| > 1`; `REJECT` if `V(x) = ∅`.

Three properties worth naming:

1. **Exact match is the r=0 case** with a discrete metric. Constraint-cells (the tote rule) are judges at zero tolerance: the input space is destinations, `d` discrete, one keyed answer per tote. The whole spectrum from hard rule to fuzzy match is one dial.
2. **Monotone in r.** Widening the tolerance dial grows the acceptance region monotonically. Every judgment the fabric makes about itself is also of this form: the acceptance gate's golden-value checks (`W_exact/2 − 1 ≤ Ŵ ≤ 2·W_exact + 1`, SYNTHESIS Q3) are a judge on the multiplicative pseudometric `d(x,y)=|log x − log y|` with `r = log 2`. *Verification is judgment at log-2 tolerance.* That is not a metaphor; it is the same definition.
3. **AMBIGUOUS never guesses.** The verdict set, not a score, is the output — XID-MATCH's `AMBIGUOUS` flag is D2 working correctly, not a failure mode.

> **Worked example (D2, back deck).** Input space X = event pairs `(leave-frame t_u, surface-break t_d)`, pseudometric `d = |t_u − t_d|`, tolerance dial `MATCH_WIN = 4.0 s`. Keys: camera-handoff identities. `t_u = 12:04:31.2`, `t_d = 12:04:33.9`: `d = 2.7 ≤ 4.0` → `ACCEPT(same-fish)`, and the tote label propagates backward to the underwater sighting. Two deck cameras breaking surface at `12:04:32.1` and `12:04:34.0`: `V(x) = {cam-P, cam-H}` → `AMBIGUOUS` — no label moves. Widening `MATCH_WIN` trades lost labels for crossed labels (paper 68 §6.2) — the dial is the bet.

> **Worked example (D2, PLATO).** `X` = typed answer strings, `d` = edit distance, `r = 1`; keyed answer `(“gravity”, PHYS-TERM)`. Input `gravitee`: distance 1 → `ACCEPT(PHYS-TERM)`. Input `levity`: distance 5 → `REJECT`. The 1970s judge and the 2026 fabric cell run the same definition, differing only in the space, the metric, and where the tolerance lives (paper, then; dial, now).

### D3 — Ledger: the intercell protocol is balanced books

RPG and COBOL transaction processing inherited double-entry bookkeeping's core discipline: **no value moves without two entries** — a debit on one account, an equal credit on another — so the books always sum to a constant. Quilt takes that discipline out of the back office and makes it *the wire format*.

> **Definition (transaction, balance, ledger).** Fix a set of accounts (per cell, D0). A **posting** is a pair `(acct, v)` with `v ∈ ℤ \ {0}` (`v>0` a credit, `v<0` a debit). A **transaction** is a finite set of postings plus a unique **nonce** (transaction id):
>
> `T = (n, {(a₁,v₁), …, (a_k,v_k)})`, balanced: `Σᵢ vᵢ = 0`.
>
> A **ledger** `L` is the pair (a partial map `bal : accounts → ℤ`, the append-only log of transactions). **Applying** a balanced transaction updates `bal ← bal + Σᵢ vᵢ·[aᵢ]` and appends `T`. **Idempotent application:** if nonce `n` is already in the log, application is a no-op. A posting is **cleared** once applied; **in flight** from the moment its counterpart cell has committed it. A transaction **crosses a cut** (a set of cells) if its postings touch accounts on both sides.

The fabric's flit contract `{op, src, dst, a0, a1, a2, dat}` is already half of D3: **src and dst are the two entries**. Quilt's completion of the idea is that an `qm_effect` flit is *literally* a balanced transaction in transit: debit `src`'s egress account, credit `dst`'s ingress account, one nonce, one payload.

> **Definition (conservation cut).** For a quantity carried in accounts (labels, credits, tokens, pounds), the **cut invariant** over any set of cells 𝒞 is `Σ_{a ∈ accounts(𝒞)} bal(a) = K_𝒞` for a constant `K_𝒞` changed only by transactions crossing the cut.

> **Proposition (consistency without consensus).** *If (i) every transaction is balanced at commit, (ii) commit is atomic per cell (one interpreter, one event = one commit), and (iii) idempotent application is enforced by nonce, then every cut invariant holds at every commit boundary, with the discrepancy during delivery exactly the sum of in-flight postings — observable, bounded by the in-flight count.*
>
> *Proof sketch.* Induction over the global partial order of commits. A transaction internal to 𝒞 nets to zero by balance, so it cannot disturb `K_𝒞`; a crossing transaction changes exactly the accounts it names, symmetrically, so both sides' constants move by the same amount at their respective commits; between the two commits the difference is the in-flight posting, which is visible, not hidden. Replay of a cleared nonce is a no-op by (iii), so retries cannot double-count. ∎
>
> **What consensus would be for, and why quilt declines it.** Consensus buys a *total order* on transactions. Quilt needs none: every invariant above is per-transaction local; accounts need only per-account serialization (each account has exactly one owning cell — the definition of an account is *the thing exactly one cell may post to*). Ordering matters only where two cells must agree on a sequence, and quilt makes that an explicit negotiated protocol instead of an implicit global service (§2.5). This is the COBOL shop's insight kept, its mainframe discarded: **balanced books give you consistency; they never needed the consensus machine to do it.**

> **Worked example (D3, the label bus).** A pink hits the port tote. Three transactions, one label, always balanced:
>
> 1. `T₁ (n=0x11A2): {(TOTE-PORT:emitted, −1), (XID-MATCH:received, +1)}` — the constraint-cell emits ground truth; the match cell takes custody.
> 2. `T₂ (n=0x11A3): {(XID-MATCH:held, −1), (CAM-UW:retro, +1)}` — after `ACCEPT(same-fish)`, custody of the label crosses to the underwater sighting.
> 3. Later, captain disagrees: quarantine is *not* deletion — `T₃ (n=0x11C0): {(CAM-UW:retro, −1), (QUARANTINE:held, +1)}` and the audit trail says exactly who moved what where. The label's entire biography is three balanced lines.

### D4 — Session illusion: asynchronous composition that feels synchronous

PLATO's terminals were asynchronous creatures — keystrokes crossing shared lines, screens updating late — yet a session *felt* like a conversation with one machine, and the system scaled by plugging in another server precisely because nothing in that feeling depended on a global heartbeat. "Felt synchronous" is doing real work in that sentence. Here is what it means.

> **Definition (bounded-freshness view).** Cell A **views** cell B when A issues a `qm_view` and receives a value `v`. The view is **(F, L)-bounded** if: (i) **latency** — a response arrives within `L` of issue (else the fabric is in violation, not "slow"); (ii) **causal freshness** — `v = B@s` for some serial state `s` of B with `s` committed no later than the response time (no future states, no torn states — atomic by event-serialization); (iii) **staleness bound** — `v = B@s` for some `s` committed within the last `F` of wall time: the response may be stale, but its staleness is *bounded and known*.

> **Definition (session illusion).** An asynchronous quilt presents a **synchronous illusion with parameter F** to an observer if every view the observer makes is (F, L)-bounded *and* the observer's queries are separated by more than F + L. Under those conditions the observer cannot distinguish the quilt from a synchronous system that answers instantly from current state: asynchrony is exactly the part of the dynamics that happens *underneath* the observation timescale. The illusion is not a lie; it is a **band-limited truth** — the quilt guarantees that everything faster than F is invisible, and everything visible is current to within F.

The illusion is a *property with a budget*, and the fabric spends the budget in hardware:

- **The view bound is a theorem of the v1 ring.** SYNTHESIS I2: a view accepted at a cell is answered within `(flits queued ahead) × MAX_OP_CYCLES + ring latency` under a continuous effect storm, because the core is run-to-completion bounded (I1) and ingress is not starvable. That is D4's `L` with `MAX_OP_CYCLES = 64`; `F` inherits the same arithmetic. *PLATO's feeling of synchrony was an empirical accident of light load; quilt's is an enforced bound with a testbench* (`tb_fabric_smoke.v` asserts it while training traffic runs).
- **The tick is what makes F honest.** Without a non-deferrable tick, staleness could grow without bound under load (busy cell, starved viewers). The hardware-interlocked tick (Q2: `tick_pend` serviced before any ingress) bounds how far any cell's scheduled state can lag reality, so F is a function of topology, not of traffic mercy.

> **Worked example (D4).** Wheelhouse views the SOUNDER's biomass dial once per 10 s. Fabric arithmetic: worst case `L = 3 queued × 64 cycles + 12-cycle ring = 204 cycles ≈ 2 µs` at 100 kHz; staleness F dominated by the sounder's own tick period (say 1 s). Query spacing 10 s ≫ F + L. The skipper is inside the illusion: for all he can measure, the sounder answers synchronously. Drop queries to 10 ms spacing and the illusion *correctly* breaks — D4 is a statement about a timescale, not a promise of magic.

---

## 2. The algebra of distribution

"Ultimate backend under any OS" is a slogan until it is an algebra. The verbs — **mirror, stripe, nest, embed, agree** — are operations on quilts, and they compose. To say *how* they compose we need one small piece of vocabulary, used lightly and honestly:

> **Definition (the category CELLS, informally).** Objects are cells. A morphism `f : A → B` is a **wiring**: an egress of A bound (by `qm_link`) to an ingress of B. Morphisms compose by wiring end-to-end: `g ∘ f` is A→B→C. The functor laws — identity wiring changes nothing, and (A→B→C wired as one) equals (A→B then B→C) — are the formal content of *composition is wiring, not scheduling*: nothing in the middle reorders, buffers-by-policy, or interprets; a wire is a wire. (ABSTRACTION-MATH §1 grounds this in traced symmetric monoidal structure of the ring; we need only the plain form here.)

### D5 — The five distribution operations

> **Definition (mirror).** A **mirror** of cell C is a cell C′ with `J′ = J`, `τ′ = τ`, and a ledger L′ that receives the *same transactions* (same nonces) as L. By idempotent application (D3), at-least-once delivery of the transaction stream is safe: the first application clears the nonce, every replay is a no-op. **Replication = idempotent credit.** Mirrors **converge** (identical `bal`, modulo in-flight) whenever they have *applied the same transaction set* — no order agreement required, because posting to the same accounts is commutative given per-account serialization.
>
> *Worked example.* `LEDGER-SCALE` mirrors to the wheelhouse display and to `NIGHT-CRON`. A link flaps; the scale's `{t, 41.2 lb, pink}` transaction re-delivers. Both mirrors already cleared nonce `0x2F71`; the pounds are counted once. The v1 honesty clause from BACK-DECK §6 is also a mirror statement: walk-state that is *not* transaction-carried (ladder buckets) is not mirrored — the graph re-earns it by replaying the day, which is mirror-by-recomputation, the ledger being the source of truth.

> **Definition (stripe).** A **placement** is a function `σ : cells → sites` (a site is any substrate that can host a cell: a fabric, a soft core, an OS process). **Striping** is the induced functor `S_σ : CELLS → CELLS_σ`, mapping each cell to its placed copy and each wiring to a **route** (the same flit contract, forwarded across sites by bridges). Compute-striping partitions *who judges what* (many judges in parallel); retrieval-striping partitions *who holds which accounts* (state access spread out). The functor laws are the entire correctness claim: **wiring survives placement** — `S_σ(g ∘ f) = S_σ(g) ∘ S_σ(f)` says a composite quilt behaves the same whether f and g sit on one site or two, *provided every cut crossed by a route respects the flit contract*. Where it does not, the seam (not the algebra) is the risk — owned in §5, P1.
>
> *Worked example.* The 4-cell ring on one FPGA vs. the same four cells on four soft cores: same opcodes, same flits, same QUF. What changed is σ; what did not is the category. Retrieval example: a corpus brain striped by edge-id across sites — every `qm_view` of an edge weight lands at exactly one site; no lock, no cache coherence, because the account's owner is unique by definition (D3).

> **Definition (nest).** A cell may hold cells: a **composite cell** `C[ C₁ … Cₖ ]` has state = its own dials/accounts *plus the QUFs of its children* (state-is-a-file makes nesting literal — a QUF section can carry a sub-QUF). Its organs are **consolidations**: `J_C` = an aggregation (e.g. any-child-ACCEPT) over children's verdicts; `L_C` = the boundary ledger. The **consolidation lemma**: a balanced transaction *interior* to the composite nets to zero in the consolidation, so `L_C` contains exactly the transactions that crossed the composite's boundary. Interior bookkeeping is invisible from outside — that is the point.
>
> This is the monad shape, stated plainly: nest is `T(T(X))`, consolidation is `join : T(T(X)) → T(X)`, and the monad laws are the safety argument. **Associativity** (nest three deep = nest two-then-one) holds *because consolidation is additive and interior transactions net to zero* — the algebraic fact doing the work is D3's balance, again. **Identity** (a composite of one is that cell) holds because an empty boundary ledger consolidates to the cell itself.
>
> *Worked example.* `BESTSHOT` is a composite of per-camera review cells. `AUDIT-CAPTAIN` views it as **one** cell with one ledger; a thousand interior transactions (frame triage, chain assembly) net to zero at the boundary, which posts only `{(BESTSHOT:offered, −1), (AUDIT:inbox, +1)}` per fish.

> **Definition (embed).** A **foreign protocol** P is a theory: message schemas plus progress obligations (what a conforming speaker must do). An **embedding** of P into CELLS is a functor `E : P → CELLS`: each foreign message type maps to an effect/dial-write at one adapter cell; P's progress obligations map to the adapter's tick discipline. Law 4 ("adapters are thin and dumb") is the functor's honesty condition: **E preserves structure and adds no judgment** — no interpretation, no inference, no tolerance dials of its own. All intelligence sits in the cells the adapter feeds (the fabric does not know what a salmon is; the adapter does not either).
>
> *Worked example.* NMEA 0183 into `SOUNDER`: the adapter maps each `$SDDPT` sentence to a `{t, depth}` effect flit and nothing else. Malformed checksums REJECT at the adapter's zero-tolerance judge (a checksum *is* an exact-match judgment, D2 at r=0) — structure enforcement, not interpretation.

> **Definition (agree-on-protocol).** A link forms only when both cells hold the same **interface theory**: a triple `(protocol-name, version, schema-digest)`. `agree(P, P′) ⟺ P = P′` — **nominal typing of protocols**: compatibility is by *name*, never by structural resemblance. The handshake itself is a balanced transaction (D3): each side posts consent; neither may unilaterally create a link, exactly as neither may unilaterally create a credit. Two structurally identical but semantically different streams (depth-feet vs. depth-fathoms) carry different names and refuse to wire — the nominal rule is what makes the fathom/hook calibration (BACK-DECK dial `HOOK_PITCH`) a property of the *agreed* protocol rather than an accident of wire shapes.

### The backend theorem (informal)

> **Claim.** *For any substrate that can host one adapter cell, and any quilt Q, there is a placement σ of Q into that substrate — because every organ of Q (judgment, ledger, session, tick) is cell-local, and every boundary crossing is either a wire (flit contract) or an embedding (functor from the substrate's native protocol).*
>
> That is the formal content of **"the ultimate backend under any OS"**: a backend's four jobs — storage (ledgers), compute (judges), scheduling (ticks), communication (links) — are all cell organs, and a cell is hostable anywhere one dumb adapter fits. Storage, compute, and scheduling are not services quilt *uses*; they are what cells *are* (D1). ∎ (informally — §5 P1 owns the honest asterisk: partition behavior of the wires.)

---

## 3. Security as bookkeeping

Double-entry buys specific, provable properties — and fails to buy others. Listing both sides is the honest ledger of this section.

### 3.1 What balanced books make provable

1. **No fabrication (conservation).** By the consistency-without-consensus proposition (D3), no cell can *create* a tracked quantity; it can only receive, hold, and pass it. A spoofed label with no emitting debit is not merely forbidden — it is **unrepresentable**: there is no balanced transaction that mints custody. The tote rule's authority is exactly this: labels enter the world in one place, balanced, or they do not enter.
2. **Provenance (audit = replay).** State is the sum of the ledger. Any auditor cell can replay the log and check every balance invariant; the check is linear time, local, and needs no trust in the audited cell's goodwill — only in the books' arithmetic. The quarantine chain (BESTSHOT → AUDIT-CAPTAIN → NIGHT-CRON) is a replay query: *which labels' biographies touch a disputed sighting?* Three balanced lines answer it (D3, worked example).
3. **Tamper-evidence.** Alter one entry and the books stop balancing: a single-sided edit is arithmetically loud. This is Pacioli's five-century property, and it is the reason single-entry ledgers lost. Silent corruption requires *balanced* falsification — two coordinated lies, which is strictly harder than one and leaves a twice-as-visible trail.
4. **Safe retry (idempotence).** Nonce-guarded application (D3) makes at-least-once delivery free of double-counting — the mirror operation (D5) is built on it, and so is every flaky-link retransmit a boat will ever suffer.
5. **Reversible action (quarantine as closing entries).** Nothing is deleted; accounts are closed by balanced reversal (D3 example, T₃). An excluded label remains *countable* — the night cron knows exactly what it did not train on, which is itself training data (paper 68 §5).

### 3.2 What balanced books cannot buy (and what buys it instead)

1. **Truth of entries.** The books can be balanced *and wrong*: a pink thrown in the hold is booked, balanced, as a chum. Double-entry conserves custody, not correctness. What buys truth: judges on the *source* (D2 — the crew's sorting is the label), and audit cells judging the *chain* (the flip-through). Bookkeeping makes wrongness *traceable*; it never makes it impossible.
2. **Confidentiality and access control.** A balanced book is a readable book. Privacy is not a ledger property; it is a dial (`QUARANTINE` weight) plus policy at the ingress judges. No arithmetic here — honest debt.
3. **Collusion.** Two cells can fabricate balanced fictions *between themselves* (the wash trade): debit and credit, no underlying event. Books make collusion *symmetric and visible* (two accounts moved, one nonce, replayable) but do not prevent it. The mitigation is cross-checking judges with independent sources — XID-MATCH exists precisely to catch a tote/ledger pair that agrees with itself but not with the cameras.
4. **Availability under partition.** Balanced books do not deliver in-flight postings across a cut. Delivery is a *freshness* problem, and freshness under partition is precisely the open problem P1 (§5) — the ledger tells you *exactly how much is in flight* (the cut discrepancy is measurable), which is the best any discipline can offer short of solving the partition itself.

The pattern: **bookkeeping gives integrity, provenance, and reversibility; judgment gives truth; freshness bounds give availability.** The three organs of D1 are also the three legs of security — which is why the cell is not decomposable into "data structure + protocol + policy" without losing the theorem.

---

## 4. Where hardware design split from programming — and the cell as the rejoin

The split (LINEAGE.md carries the full history; here is its formal residue): hardware design converged on the **resource contract** — a module *is* its timing and area budget, setup/hold enforced physically, bounded cycles, widths fixed at birth, failure mode = timing violation. Software converged on the **object contract** — a module *is* its interface semantics, garbage-collected time, unbounded cycles, failure mode = exception. Two traditions, two notions of state (registers vs. heap), time (clock edges vs. scheduler), and interface (pin contract vs. method signature). Each borrowed the other's clothes badly: hardware description languages grew "behavioral" escapes that synthesize into surprises; software grew "real-time" annotations that hardware does not enforce.

Quilt's claim, formally: **the cell is one object carrying both contracts simultaneously**, because the two contracts are two *interpretations of the same state space*:

| Contract | Hardware reading (enforced in RTL) | Software reading (used by programs) |
|---|---|---|
| State `S` | QUF byte image, fixed-point widths, saturate-never-wrap | an object with dials, edges, accounts |
| `J` | comparator + tolerance register (a few LUTs) | a judgment call returning a verdict |
| `L` | counter file, nonce register | an append-only audit log |
| `τ` | `tick_pend` interlock — deadline silicon cannot starve | a cron schedule |
| `δ` | run-to-completion FSM, `MAX_OP_CYCLES` bound | an event handler |

> **Definition (QUF, formally).** QUF is the **shared word**: a canonical byte encoding `enc : S → {0,1}*` such that the simulator's decode (`tools/quf.py`, software interpretation) and the loader's decode (`rtl/q_uf_loader.v`, hardware interpretation) yield *identical* state. Bit-exact where the fabric allows; tolerance-bounded where it does not — and the bound is *itself* a judgment (D2: the acceptance gate's golden checks at multiplicative radius 2).

The reunion discipline is therefore a theorem-shaped sentence: **verification is the judgment that the two interpretations of one cell agree within tolerance.** `tb_fabric_smoke.v` asserting `wsum == base + N·2^8` against an independently computed golden model is the software interpretation and the hardware interpretation being *judged against each other* — ACCEPT and the cell exists (Law 5); REJECT and it does not. "Verified or it doesn't exist" is not a slogan; it is D2 applied to the split itself. The fabric smoke test is PLATO's judge field, grading silicon.

---

## 5. Open mathematical problems we own

These are not survey gaps; they are the problems this architecture *creates* and therefore owns. Each is stated with what is known and what is missing.

**P1 — Freshness bounds vs. partition tolerance.** D4's F is proven for the unpartitioned v1 ring (SYNTHESIS I1/I2: bounded ops, unstoppable ticks, no-drop ingress). The open question is the **trade-off curve** `F(π)` under a partition event π: how stale may views go, and what ledger state measures it? The cut discrepancy of D3 (in-flight postings) is a *candidate Lyapunov quantity* — the claim worth proving is that under partition, either F grows to exactly the in-flight bound or the ledger forks (two constants K where there was one), and never a third thing. This is quilt's CAP position: not C-or-A but **F-for-A with a meter** — freshness traded against availability *at a price the ledger reads out continuously*. What's missing: the bridge/seam model (v2 surface), the proof, and the failure-injection fabric test that would falsify it.

**P2 — Judgment-metric drift.** D2 fixes `(X, d, A, r)` at bind time; the world drifts (camera fouling, fish behavior, new gear geometry). Formal statement: with true concept `d_t` varying over time (drift budget `∫‖d_t − d_{t+1}‖ dt ≤ D`), bound the label error of a judge held at fixed `d, r`; then find the re-judging policy (the A/B cell's dial writes are its empirical form) that keeps error bounded. Known: the empirical handle works (night cron + `PROMOTE_MARGIN`); the back deck already *runs* the policy. Missing: any theorem connecting drift budget to error bound — the tote rule has no drift (hard constraint), but XID-MATCH's `MATCH_WIN` and the sounder's edges drift with the sea. The connection to P1: freshness of the *audit feedback* bounds how fast drift can even be detected.

**P3 — Ledger pruning without history loss.** Ledgers grow; silicon and QUF do not. **Compaction** (checkpointing a balanced summary account and truncating the prefix) must be defined against a preservation property. Proposed definition: a compaction is **lossless for property class 𝒫** iff every 𝒫-invariant checkable on the full log is checkable on the compacted log. Balance invariants survive compaction trivially (the summary *is* a balance). Provenance does not — unless the prefix is digested (Merkle-style) so that *claims about* the truncated history remain checkable even when the history itself is gone. The live instance is BACK-DECK §6's honest clause: walk-state is not round-tripped; the graph **re-earns its weights by replaying the day** — mirror-by-recomputation as the extreme compaction where nothing is kept but the source stream. Owning this problem means deciding *which* 𝒫 the doctrine promises: our claim is conservation + provenance-of-exclusions (what the night cron did not train on must survive any compaction, or quarantine is theater).

---

## Appendix — the five definitions, one line each

- **D1 (cell):** `C = (S, J, L, τ, δ)` — an asynchronous agent whose entire being is state, judgment, ledger, tick discipline, and transition.
- **D2 (judgment):** `J = (A, r)` over a (pseudo)metric answer space — match-with-tolerance returning ACCEPT/REJECT/AMBIGUOUS, tolerance a dial, aliases zero-distance classes; PLATO's judge generalized.
- **D3 (ledger):** every transition is a nonce-carrying balanced transaction (`Σvᵢ = 0`); the intercell protocol *is* the books — conservation by induction, consistency without consensus.
- **D4 (session illusion):** asynchronous composition feels synchronous iff views are (F, L)-bounded and observation spacing exceeds F + L — synchrony as a band-limited truth, F enforced in silicon.
- **D5 (distribution algebra):** mirror = idempotent credit; stripe = placement functor preserving wiring; nest = composite cell consolidating interior books to zero (monad by balance); embed = structure-preserving functor from a foreign protocol, thin and dumb; agree = nominal typing of interface theories, links formed by balanced consent.

*Foundation lane, 2026-08-29. The history of these objects is LINEAGE.md's to tell; the hardware semantics are ABSTRACTION-MATH.md's; the application is the back deck's. This document holds the definitions the other three stand on.*
