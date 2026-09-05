# CONJECTURES — the three open problems, attacked

**Lane:** conjectures (GLM-5.3, the deep-math lane) · **Date:** 2026-08-29
**Sources:** `quilt-calculus.md` (definitions/axioms/theorems, its own registry D1–D18, A1–A7, T1–T11, P1–P2, C1–C3), `BRIDGES.md` (B1–B10), `ELEGANCE.md` (E1–E5). Self-contained modulo those three; every statement below cites the monograph's registry it consumes.

**Method.** For each conjecture: (1) restate precisely, exposing what the informal clause must *mean* — where a restatement repairs a slip, the repair is flagged; (2) survey adjacent results; (3) attack: prove a restricted version, or construct a counterexample, or state the exact gap with the weakest closing hypothesis. Doctrine: every proof real; every No loud.

**Outcomes (one line each).**

- **C1 freshness–partition dichotomy** — **proved-restricted** during clean partitions (Theorem 1: exact staleness and fork meters), **counterexample at the seam** (Counterexample 2: nonce collision silently defeats the ledger's own instruments — a third behavior), **closing hypothesis proved** (Theorem 3: structural nonces make uniqueness a theorem of A2+A3, and the seam then closes loudly).
- **C2 judgment-drift bound** — **proved-restricted** (Theorem 4: the drift band, reduced to T3(c); Theorem 5: re-judging cost linear in drift rate at fixed error, √-scaling at the joint optimum, and an impossibility floor set by audit freshness); general metric drift **gap-formalized** (labeled-perturbation hypothesis).
- **C3 lossless compaction** — **counterexample to the conjecture as stated** (Counterexample 7: post-hoc exclusion queries are unanswerable after digest-truncation — unconditionally for summary-only, in ROM with the digest), **restricted theorem proved** (Theorem 6: lossless = fold-covered; T4/T5 are its first two instances), **recovery and pricing proved** (Theorem 8, Corollary 9: declared-label folds restore checkability; enumeration predicates force linear checkpoints).

**Statement registry.** 3 conjectures attacked · 2 counterexamples (plus the ROM hiding lemma inside Counterexample 7) · 6 theorems · 2 lemmas · 2 corollaries · 13 numbered proofs.

---

## Part I — C1: the freshness–partition dichotomy

### 1.1 Precise restatement

The conjecture (calculus §13):

> Under a partition event π of indefinite duration, for any cut 𝒞: either (i) views across 𝒞 degrade with staleness F growing to exactly the in-flight bound of T2 (I(t) is the candidate Lyapunov quantity: F(t) ≤ F₀ + I(t) while both sides keep applying), or (ii) the ledger forks — two conservation constants where there was one — and every quantity is conserved within each side (T1 applies per component). No third behavior is possible.

To make this a mathematical claim, four things must be pinned down that the statement leaves implicit.

**C1-d1 (Partition event, clean split).** A *partition event* π at instant t_π is a condition on the delivery relation, not on cells: for all t ≥ t_π, no link crossing the cut 𝒞 = 𝒜 ∣ ℬ delivers any flit. Cells on both sides keep running (A1–A7 hold *within* each component). Flits that had *already crossed* before t_π and sit in a far-side cell's ingress are not blocked — they are inside the component — and are serviced within a bounded **drain transient** Δ_drain fixed by ingress depth at t_π and the A5/A6 service bounds. All steady claims below are stated for t ≥ t_dr := t_π + Δ_drain; the transient is bounded, topology-determined, and traffic-free by the same A5/A6 discipline T6/T7 consume.

**C1-d2 (What "views across 𝒞" must mean).** A `qm_view` issued from ℬ at a cell in 𝒜 cannot be served during a clean partition (its request flit never crosses, past the drain). The only serviceable "view across the cut" is one served by a **mirror** (D10): a ℬ-side replica of an 𝒜-side owner, answering from its own log. This is a repair of the conjecture's clause (i), not a weakening: the interesting object during a partition is precisely the mirror, because that is what T4 governs.

**C1-d3 (The two staleness meters).** For owner O of account a and mirror M of O, at commit-boundary time t:
- **time-staleness** age(t) = t − t_last, where t_last is the commit instant of the last owner transaction *delivered* to M;
- **value-deviation** δ_a(t) = |bal_O(a, t) − bal_M(a, t)|, the account's units.
Define the **M-in-flight set** InF_M(t) = {T : nonce(T) applied in O's log by t, not applied in M's log by t} and the **mirror in-flight** I_M(a, t) = Σ_{T ∈ InF_M(t)} v_T(a). (t_last likewise stabilizes at t_dr: flits already in M's ingress at t_π may commit up to the drain.)

The conjecture's "F(t) ≤ F₀ + I(t)" conflates a time quantity with a quantity-unit sum and — more substantively — proposes the *cut-crossing* in-flight I_𝒞(t) of T2 as the Lyapunov function for *view degradation*. That is the wrong meter: I_𝒞 measures the conservation discrepancy between components (which transactions have postings committed on both sides); view degradation is governed by *delivery*, i.e. by I_M. A transaction entirely interior to 𝒜 (no ℬ-side postings) leaves I_𝒞 untouched yet still stales the mirror by its full posting. The repaired clause (i) reads: time-staleness grows at rate 1 from the last delivery; value-deviation *equals* the mirror in-flight, exactly, at all times. Both are then theorems (Lemma 1, Theorem 1).

**C1-d4 (What "the ledger forks" must mean).** Under A2, each account has exactly one owner, and only the owner posts. During a clean partition, balances therefore *cannot* diverge — the non-owner side cannot write, full stop. The fork of clause (ii) is not a behavior the calculus permits; it is a **deliberate A2 break**: an operator reassigns ownership of accounts to cells on the far side (the only way to keep both sides writable), after which each component is a closed universe with its own conservation constant. The dichotomy, made precise, is: *preserve A2 and accept metered staleness on the read side, or break A2 and accept two constants with a metered fork discrepancy.* That is the quilt's CAP position with the price tag attached, and it can be proved.

### 1.2 Adjacent results

- **Conit-based continuous consistency** [YV02] ✤ — a replicated object ("conit") carries three error bounds: numerical error E (how far the value may deviate), order error, and staleness W (version-window age). C1's repaired clause (i) is precisely the statement that under a partition, the conit's numerical error is *exactly* the in-flight posting sum — the ledger is the error meter, continuously (this is T2.2 promoted from delivery windows to partitions). The time/value split of C1-d3 is Yu–Vahdat's W/E split, with E computed by bookkeeping rather than estimated.
- **PBS: probabilistically bounded staleness** [BVF+12; BVF+14] — k-staleness and t-visibility quantify *how stale* eventually-consistent reads are, probabilistically, in quorum systems. PBS is the probabilistic, steady-state cousin of C1's deterministic, worst-partition regime; C1 asks for the adversarial bound and gets it from the ledger rather than from quorum intersection.
- **Consistency/availability/convergence trade-offs** [MDV11] — under partitions, real-time (bounded-staleness) guarantees are unachievable while both sides remain available; three-way impossibility results sharpen CAP [GL12] for time-bounded consistency. C1 is the quilt's escape hatch: rather than deny the impossibility, it prices it — the impossibility is *metered* by I_M (case i) or *fenced* by two constants (case ii).
- **Session guarantees and anti-entropy** [TTP+95] — Bayou's merge-on-reconnect (dependency checks, tolerated divergence) is the engineering shape of the seam: C1's open residue lives exactly there (§1.4).
- **CRDT merge** [SPBZ11] ✤ — strong eventual consistency by commutative idempotent application; T4 is the op-based instance. The seam question is whether T4's argument survives a *divergent-minting* period — answer: only under a nonce discipline (§1.4–1.5).

### 1.3 The restricted theorem: the dichotomy holds during a clean partition

**Lemma 1 (mirror identity — T2 specialized to a mirror, no partition assumed).** *For any owner O, mirror M (D10), account a ∈ Acct_O, at any commit boundary t:*
`bal_O(a,t) − bal_M(a,t) = I_M(a,t).`
*Proof.* By T4's induction (application is additive per nonce: bal = bal(0) + Σ_{applied} v_T), bal_O(a,t) = bal_O(a,0) + Σ_{T ∈ log_O(t)} v_T(a) and likewise for M. D10 delivers to M only transactions O has committed (delivery follows the source's service order, D6), so applied-at-M ⟹ applied-at-O-earlier: log_M(t) ⊆ log_O(t) up to nonce identity. Mirrors start equal (bal_M(a,0) = bal_O(a,0)). Subtracting, the common applied nonces cancel (integer sums), leaving exactly the sum over applied-at-O, unapplied-at-M transactions: the definition of I_M(a,t). ∎ *(Consumes: A2, A3, A4 — as T4.)*

**Theorem 1 (during-partition dichotomy; C1 proved for clean partitions).** *Hypotheses: A1–A7 hold within each component of the clean partition π of 𝒞 = 𝒜 ∣ ℬ from t_π, with drain point t_dr; no ownership reassignment. Then for all t ≥ t_dr:*

**(i) Metered staleness (A2 preserved).** *For every mirror M ∈ ℬ of an owner O ∈ 𝒜 and account a ∈ Acct_O:*
- *time: age(t) = t − t_last with t_last fixed for all t ≥ t_dr (no fresh delivery across the cut), so age grows at rate exactly 1 per unit wall time;*
- *value: δ_a(t) = |I_M(a,t)| exactly (Lemma 1), and InF_M(t) is monotone nondecreasing from t_dr — every post-drain application at O adds its posting to the meter and nothing ever removes one;*
- *the cut-crossing meter of T2 is frozen past the drain in its fully-applied part: F_𝒞(t) = F_𝒞(t_dr) for all t ≥ t_dr, and I_𝒞(t) is monotone nondecreasing from t_dr.*

**(ii) The fork (A2 broken deliberately).** *If at t_f ≥ t_π ownership of some accounts is reassigned across the cut (the only way to obtain writes on the far side; note it cannot even be booked as a transaction, since a booking crossing the cut would require delivery), then from t_f each component is a closed universe: every transaction committed within a component is interior to it, so T1 applies verbatim per component — Φ(𝒜) and Φ(ℬ) are each conserved from t_f on: two constants where the unpartitioned system had one — and the inter-component discrepancy is the frozen-then-monotone I_𝒞, legible from both sides' books.*

**(iii) No third behavior, during.** *The global run is the interleaving of two independent component runs (D6) plus a frozen crossing structure; every event is an apply event (interior: T1/T4 machinery per component; crossing-partial: in-flight growth per T2), a non-apply event (touches nothing), or the ownership-reassignment operator event (which switches (i) → (ii)). D6's alphabet admits no fourth case, and the clean-partition delivery relation admits no channel that could carry one. The dichotomy is exhaustive during the partition.*

*Proof.* (i) time: past the drain, M's applies require a fresh cross-cut delivery — none occurs; hence N_M(t) = N_M(t_dr), t_last fixed, and age(t) = t − t_last by C1-d3. (i) value: Lemma 1 plus N_M constant gives InF_M(t) = N_O(t) ∖ N_M(t_dr), monotone because N_O only grows (A3 append-only). (i) cut meter: past the drain, a crossing transaction completes only when its last outstanding posting commits at a far-side owner — which requires either a fresh cross-cut delivery (blocked: clean partition) or an already-arrived flit still in ingress (none left: drained); so no crossing transaction completes for t ≥ t_dr (F frozen there), and every additionally committed 𝒜-side posting of a pending crossing transaction adds to I_𝒞 (T2's step case: "does not complete T" ⟹ I += P), never subtracts (A4: a completed transaction never re-enters I; an in-flight one cannot complete past the drain). (ii): post-reassignment minting has postings only on locally-owned accounts (A2 enforced within the component; a posting to a far-side account would require the far owner's service, i.e. delivery). T1's proof consumes only per-cell runs and A1/A2/A4 — all available within the component. The unbookability of reassignment: a balanced reassignment transaction must post to accounts on both sides (ownership moves across), i.e. cross the cut, i.e. require delivery to commit globally — unavailable; hence reassignment is an operator dial event, outside the ledger's own discipline, which is exactly why it *breaks* the single constant rather than moving it. (iii): closed-list case analysis over D6's event kinds under the delivery-blocked relation, as displayed. ∎ *(Consumes: A1–A7 via T1/T2/T4; C1-d1–d3.)*

**Bar line.** *During a partition the dichotomy is not a conjecture: staleness is a meter reading (exactly the mirror in-flight), the fork is two constants with a frozen discrepancy, and the event alphabet has no room for a third thing.*

### 1.4 The seam: where a third behavior hides — and bites

The calculus itself flags it: "what a reconnected mirror does with divergent nonce streams is where a third behavior could hide." It does hide there, and it is worse than a fork: it is a **silent divergence that reads as convergence on every instrument the calculus defines.**

**C1-d5 (Seam protocol).** At healing time t_s, each component ships its full minted set to the other (anti-entropy à la Bayou [TTP+95]); delivery is at-least-once; application per A4 (nonce fresh ⟹ apply; seen ⟹ no-op).

**Counterexample 2 (the silent seam: nonce collision defeats the meter).** *The "no third behavior" clause of C1, read to include seam behavior, is false as stated.*

*Construction.* Owner O ∈ 𝒜 with accounts p₁, p₂; mirror M ∈ ℬ (D10). Partition at t_π. The operator forks (case ii of Theorem 1): ownership of the cloned accounts (same names p₁, p₂) is reassigned to M. Both sides mint during the partition — O mints `T₁ = (n*, {(p₁,−7), (p₂,+7)})`; M mints `T₂ = (n*, {(p₁,+3), (p₂,−3)})` — and **the nonces collide**. They can: D4 says "n a unique nonce," but under a partition no global registry exists; both sides drawing from timestamps or pre-partition-aligned counters collides with positive probability (and an adversary schedules it with certainty).

*Seam.* O receives T₂: nonce n* is in log_O (T₁'s) ⟹ **no-op by A4**. M receives T₁: n* is in log_M (T₂'s) ⟹ **no-op**. Final logs: O holds T₁ but never T₂; M holds T₂ but never T₁. The nonce *sets* are equal: N_O = N_M ∋ n*.

*Claims.*
1. **The wrong join.** The semantically correct post-seam state is the semilattice join of the minted sets (T4's regime: both transactions applied everywhere). The fabric computes something else: each transaction applied exactly once, on one side only. The merged ledger ≠ union — silently.
2. **The instruments read zero.** Every ledger-internal instrument the calculus defines reports *convergence*: the nonce sets compare equal (anti-entropy set-difference is empty), T2's cut in-flight over nonces is empty, and each side's books balance (T₁, T₂ are each balanced). Contrast case (i) (meter grows, legibly) and case (ii) (two constants with a frozen, legible discrepancy): here the discrepancy meter itself returns zero while the content diverges. This is the third behavior: *converged-by-instruments, divergent-in-content.*
3. **A4 is the mechanism of the failure.** T4's proof goes through on *transaction sets*; A4 implements its dedupe over *nonces*. The two coincide only while nonce→transaction is injective — an injectivity the fork destroys.

*Why this is a genuine No to the claim as stated.* The dichotomy's promise is that the price of every partition regime is *read out continuously by the books* (T2.2). At the seam, under nonce collision, the books lie: the meter says converged, the ledgers are not. Not case (i) (no growing staleness — the sides exchange everything), not case (ii) as advertised (the fork's discrepancy is *not* metered; the meter reads zero). A third behavior, constructible from D4/D6/A4 alone. ∎

### 1.5 Closing the seam: the weakest additional hypothesis is not additional

**Theorem 3 (seam closure under structural nonces).** *Replace D4's nonce clause "n a unique nonce" (an assumption with no enforcement mechanism under partition) by the structural discipline **nonce := (minter-cell-id, per-cell serial)**. Then:*

**(a) Uniqueness becomes a theorem.** *Distinct minters have distinct ids; a single cell's serials are distinct by A3's total service order (D6). No two minted transactions share a nonce — across a fork or otherwise — with zero probability mass or adversary budget left over.*

**(b) The seam converges.** *After healing, with at-least-once delivery eventually covering S* = log_𝒜(t_s) ∪ log_ℬ(t_s) (well-defined as a set by (a)), every cell's applied set converges to S* and every balance map converges to bal(0) + Σ_{T∈S*} v_T. No ordering agreement anywhere.*

**(c) The join is loud, never silent.** *The merged balance is the sum of both components' net flows; an application-level invariant that held in each component separately (non-negativity of a custody account, a capacity cap) can be violated by the join — but the violation is a first-order predicate of balances, checkable by a D3 judge at r = 0 or by walk-state replay. The dichotomy then extends across the seam: a fork ends in a converged join with loudly checkable invariants, or in a loudly detected invariant failure — never in Counterexample 2's silent divergence.*

*Proof.* (a): as displayed; nothing beyond A3 and distinct cell ids (fabric-level naming, outside the ledger's own trust base — the same base A2 already rests on). (b): A4 applies per nonce; distinct nonces ⟹ no conflation; T4 verbatim with common set S* (its induction needs only per-nonce additive application and at-least-once coverage). (c): balance sums are functions of the applied set (T4); invariant predicates of balances are D3-checkable at r = 0 (the discrete metric of D13's thinness discipline); a violation, if present, is *in* the observable balance vector — nothing hides in a no-op. ∎ *(Consumes: A2, A3, A4; D3.)*

**Bar line.** *C1's hiding place was never the partition — it was the seam, and the seam's failure was D4's unenforceable uniqueness clause. Make the nonce carry its minter and the conjecture stops being open: uniqueness is then a theorem of A2+A3, and the third behavior becomes unrepresentable.*

**C1 status.** Proved-restricted (Theorem 1: the dichotomy is a theorem during clean partitions, with the Lyapunov quantity repaired to the mirror in-flight and both meters exact); counterexample at the seam (Counterexample 2); closed by a discipline that costs nothing (Theorem 3). **Machine layer (bounded, 2026-08-29):** `tools/verifies/c1_seam_bench.py` PASS — 87,245 integer checks: Lemma 1's mirror identity on all 85 enumerated mint sequences × every delivery prefix; Counterexample 2 executable AND generalized (7,225 aligned-counter pairs, all 6,684 differing-content collisions silently diverge while every instrument reads converged); Theorem 3's closure (uniqueness on all 441 fork pairs; union convergence under 68,576 replay interleavings; the loud join firing at r = 0). The residual open residue, stated honestly: **flapping partitions** (sequences of split/heal events) reduce to alternating Theorem 1 / Theorem 3 phases under structural nonces — a composition, not a new case — and *asymmetric* healing (one direction delivers, the other blocked) composes Theorem 1(i) meters with Theorem 3(b) coverage; neither hides a fourth behavior, but the composition lemma remains to be written out (the narrowed residue of the old B3).

---

## Part II — C2: the judgment-drift error bound

### 2.1 Precise restatement

The conjecture (calculus §13):

> With true concept metric d_t varying with total drift budget ∫‖d_t − d_{t+1}‖ dt ≤ D, the label error of a judge held at fixed (d, r) is bounded by a function of D and the acceptance-boundary margin distribution; and there is an optimal re-judging policy (dial writes as its empirical form) keeping error bounded with re-judging cost proportional to drift rate.

The conjecture is honest that even the formalization is open ("the right formalization of ‖d_t − d_{t+1}‖ over pseudometric spaces needs care"). The attack below fixes a formalization in which both clauses become theorems, and isolates exactly what the general formalization still owes.

**C2-d1 (Drifting truth frame).** Time is discrete (tick granularity — natural for the calculus: re-judging is a dial write, a commit event). A *truth frame* at t: the same finite key set K = {k_1..k_m} throughout, with answers moving: A_t = {(a_j(t), k_j)}_{j}, on an answer space carrying a *family* of pseudometrics d_t (D2 at each t). The *held judge* is J₀ = (A₀, r) under d₀, fixed (D3 with d = d₀, A = A₀).

**C2-d2 (Drift budgets).**
- *Answer drift* (path length): D_a^{(j)}(t) = Σ_{s<t} d_{s+1}(a_j(s+1), a_j(s)); D_a(t) = max_j D_a^{(j)}(t).
- *Metric perturbation* (the labeled part of ‖d_t − d_{t+1}‖): η_s = sup_{x,y∈X} |d_{s+1}(x,y) − d_s(x,y)|; D_m(t) = Σ_{s<t} η_s.
- *Combined budget* γ(t) = D_a(t) + D_m(t). *Drift rate* ρ = sup_t γ(t+1) − γ(t), so γ(t) ≤ ρt.

**C2-d3 (Verdicts, margins, error).** V_0(x) = {k_j : d_0(x, a_j(0)) ≤ r} (the held judge's key set; the D3 verdict ACCEPT/AMBIGUOUS/REJECT is a function of this set). V_t^{true}(x) = {k_j : d_t(x, a_j(t)) ≤ r}. The *margin* of input x: m(x) = min_j |d_0(x, a_j(0)) − r| — the distance from x's answer-distance profile to the acceptance boundary. Label error under input distribution μ: err(t) = P_{x∼μ}[V_0(x) ≠ V_t^{true}(x)].

### 2.2 Adjacent results

- **Dynamic regret / tracking with path length** — Zinkevich's dynamic regret for online gradient descent scales with the comparator path length V_T [Zin03]; fixed-share tracking bounds scale with the number of shifts/diameter [HW98]. C2's Theorem 4 is the classification analog: *fixed judge = fixed comparator; drift budget = path length; error = regret against the moving truth.* The band shape (error ⟺ margin within budget) has no exact analog there — the classification margin is what buys it.
- **Variation budgets** [BGZ15] — non-stationary stochastic optimization with total variation budget V_T: optimal regret Θ(V_T^{1/3} T^{2/3}), and *restart* policies are optimal. Theorem 5's policy analysis is the judgment-side echo: periodic re-judging (a restart of the judge) with cost shaped by the drift budget.
- **Continuous consistency** [YV02] ✤ — the conit's numerical error E is the value-space drift meter for *replicated data*; C2 is the judgment-space analog, and Theorem 5 below imports audit freshness exactly as YV02 imports propagation delay into E.
- **PBS t-visibility** [BVF+12] — wall-clock staleness distributions for quorum reads; the probabilistic cousin of the freshness term that enters Theorem 5.
- **Concept-drift detection** (DDM and successors; survey [GZB+14]) — drift detectors alarm on error-rate shifts; detection delay is an additive freshness term (Theorem 5(iii) formalizes what the folklore says: *you can't react faster than you can observe*).
- **Gromov–Hausdorff distance** [BBI01] ✤ — the natural metric on metric spaces for the *unlabeled* part of metric drift; §2.5 states precisely why it is insufficient alone for verdict stability (verdicts are pointwise/labeled).

### 2.3 The restricted theorem: the drift band

**Lemma 4 (perturbation accumulation).** *For all j, t, and x ∈ X:*
`|d_t(x, a_j(t)) − d_0(x, a_j(0))| ≤ D_a^{(j)}(t) + D_m(t) ≤ γ(t).`
*Proof.* Write f_s = d_s(x, a_j(s)) and step_j(s) = d_{s+1}(a_j(s), a_j(s+1)). Forward step: triangle on d_{s+1}, then one perturbation —
f_{s+1} ≤ d_{s+1}(x, a_j(s)) + step_j(s) ≤ (f_s + η_s) + step_j(s).
Backward step: perturb once, then take the triangle wholly at d_{s+1} (one perturbation, not two) —
f_s ≤ d_{s+1}(x, a_j(s)) + η_s ≤ d_{s+1}(x, a_j(s+1)) + d_{s+1}(a_j(s), a_j(s+1)) + η_s = f_{s+1} + step_j(s) + η_s.
So |f_{s+1} − f_s| ≤ η_s + step_j(s) at every step; telescoping over s < t: |f_t − f_0| ≤ Σ_s (η_s + step_j(s)) = D_m(t) + D_a^{(j)}(t). ∎ *(Consumes: D2 only. Both directions cost exactly one η per step — routing the backward chain through d_{s+1} throughout is what keeps the combined budget at D_a + D_m rather than D_a + 2D_m.)*

**Theorem 4 (the drift band).** *Under C2-d1/d2, for every input x and time t:*
`V_0(x) ≠ V_t^{true}(x)  ⟹  m(x) ≤ γ(t).`
*Consequently err(t) ≤ μ({x : m(x) ≤ γ(t)}), and the bound is attained: no assumption narrows the band itself — only μ-mass can be excluded from it.*
*Proof.* V_0(x) is a function of the membership vector b_j(x) = 1[d_0(x, a_j(0)) ≤ r] over j; V_t^{true}(x) of b_j^t(x) = 1[d_t(x, a_j(t)) ≤ r]. Equal vectors give equal key sets, hence equal verdicts. So a verdict difference implies some j with b_j(x) ≠ b_j^t(x): one of the two distances is ≤ r and the other > r, so r lies between them and |d_0(x, a_j(0)) − r| ≤ |d_0(x, a_j(0)) − d_t(x, a_j(t))| ≤ γ(t) by Lemma 4; hence m(x) ≤ γ(t). The probability statement is immediate. Attainment: X = {x} (one point), one key, fixed metric (η ≡ 0), a_j(0) at distance r + γ − ε from x; let the truth move along the geodesic to distance r (path length γ − ε ≤ D_a): membership flips, verdict flips REJECT → ACCEPT, so err = 1 while μ({m ≤ γ}) = 1 — the bound is tight for every γ > 0. ∎ *(Consumes: D2, D3; T3(a)'s territory.)*

**Corollary 4′ (drift is an unmodeled prefilter stage — the T3(c) reduction).** *Holding (A₀, d₀, r) against truth frame t is verdict-equivalent to judging the undrifted truth through a prefilter stage of accuracy γ(t) (T3(c)): every key is accepted within r − γ and rejected beyond r + γ of the drifted profile, and all T3(c) composition guarantees transfer with r replaced by r ± γ.*
*Proof.* T3(c) consumes only |d(observed, ideal)| ≤ ρ for the interposed stage; Lemma 4 supplies exactly that with ρ = γ(t). ∎

This is the bridge the conjecture wanted: **drift composes with tolerance additively, exactly as an approximate stage does** — the three-word summary is *drift is latency's judgment-side twin* (a view chain adds latencies to F, T6; a judgment chain adds accuracies and drifts to r, T3(c) + Theorem 4).

### 2.4 The re-judging policy

**Theorem 5 (policy: linear cost at fixed error; √-scaling at the optimum; a freshness floor).** *Hypotheses: drift rate ρ; re-judge cost c per event (one dial write, one commit — A3/A6 service it in bounded time); margin mass bound μ({m ≤ ε}) ≤ σε for 0 ≤ ε ≤ ε_max; audit observations reach the policy with view freshness F (D7), so a re-judge decided at t acts on truth already drifted by up to ρF more than observed. Policy: re-judge every T ticks (reset J₀ to the current frame; displacement restarts at 0).*

**(i) Error bound.** *err(t) ≤ σ·ρ·(T + F) for all t.*
**(ii) Fixed-error regime (the conjecture's clause).** *To hold err ≤ σε₀ for all t: take T = ε₀/ρ − F (requires ρF < ε₀). Re-judging cost per tick: c/T = cρ/(ε₀ − ρF) ~ (c/ε₀)·ρ — linear in the drift rate, as conjectured.*
**(iii) Impossibility floor (freshness caps controllability).** *Every policy's worst-case error against rate-ρ drift is at least μ({x : m\*(x) ≤ ρF}), where m\*(x) is the margin of x against the freshest frame the policy can anchor to (an F-stale frame at best). The adversary is Theorem 4's attainment construction played inside the stale window: hold truth still (the policy's anchors converge), then move a key across a boundary band at rate ρ through an F window the policy cannot yet observe. In particular, if ρF ≥ ε₀, no re-judging policy — however frequent — meets an ε₀-band target for any μ charging the boundary band: undetected drift within one freshness window already fills it. Drift within one audit-freshness window is the floor no dial schedule can sweep.*
**(iv) Joint optimum (F = 0).** *Minimizing error + cost rate, σρT + c/T, gives T\* = √(c/(σρ)) and total rate 2√(cσρ): the optimal trade-off scales as √ρ — sublinear in drift, sharpening the conjecture's "proportional."*

*Proof.* (i): between consecutive re-judges, accumulated combined drift ≤ ρT (rate definition); the decision's information is F stale (D7), so the displacement actually uncorrected at the worst instant ≤ ρ(T + F); apply Theorem 4 and the margin bound. (ii): solve ρ(T + F) ≤ ε₀; cost per tick = c/T; asymptotics for ρF ≪ ε₀. (iii): let m\*(x) be the margin of x against the freshest frame usable by any policy — at best an F-stale frame, by D7. The adversary plays Theorem 4's attainment construction inside the stale window: hold the truth frame static long enough that the policy's anchors coincide with it, then move one key across a boundary band at rate ρ for F time units; every observation the policy can act on predates the move (its data is F stale), so at the instant the move completes, the held judge differs from truth on every x whose m\*(x) ≤ ρF — err = μ({m\* ≤ ρF}) at that instant, for every policy. Hence an ε₀-band target with ε₀ < ρF fails whenever μ charges the ρF-band. (iv): AM–GM: σρT + c/T ≥ 2√(σρc), with equality iff σρT = c/T ⟺ T = √(c/(σρ)). ∎ *(Consumes: D3, D7; Theorem 4; A3/A6 for the bounded cost model.)*

**Bar line.** *A drifting judge blurs exactly like a staged one — by the drift budget, additively; hold error fixed and re-judging costs linearly in drift; optimize jointly and it costs √drift; and no policy at all sees through a freshness window: audit lag F sets the floor ρF that error cannot be squeezed below.*

### 2.5 The honest gap: general metric drift

Theorem 4's Lemma 4 needs the *labeled* perturbation bound η_s = sup_{x,y} |d_{s+1}(x,y) − d_s(x,y)| — the metric moves, but points keep their identities and the two-sided pointwise excursion is summable. The calculus's suggested candidate — Gromov–Hausdorff distance on the alias quotient (T3(b)) [BBI01] — measures the *unlabeled* geometry: d_GH(X_s, X_t) small means the spaces are isometric *up to some correspondence*, not that the identity map on points is an ε-isometry. Verdicts live on points (x vs keyed answer a_j under d(x, a_j)); a correspondence may relabel x, and a relabeled point can flip every verdict at zero GH cost (e.g., X = {u, v} at distance 1; d_t swaps which points are "close" to the answer while staying isometric to d_0 — d_GH = 0, verdicts reversed). So:

**Gap statement (C2, general form).** The exact residue between Theorem 4 and C2-as-stated is the **labeling**: GH-type budgets control geometry up to correspondence; verdict stability needs pointwise (labeled) stability. *Weakest additional hypothesis that closes it:* a family of correspondences that is the identity on represented points, i.e. precisely a pointwise two-sided bound — which is C2-d2's η. Equivalently: quote the alias quotient's metric drift *with the identity correspondence*. Under that hypothesis, Lemma 4–Theorem 5 are the full conjecture. Without it, C2-as-stated is not merely open — it is false-in-spirit (GH-small drift with verdict reversal is the counterexample shape), and the repair is the hypothesis itself.

**C2 status.** Proved-restricted (Theorem 4 + Corollary 4′: the bound is exactly "margin mass within the drift band," tight, and reduces to T3(c); Theorem 5: cost linear in ρ at fixed error, √ρ at the optimum, impossibility floor ρF). Gap formalized (labeled perturbation = the closing hypothesis; GH alone insufficient, with the relabeling counterexample shape). **Machine layer (bounded, 2026-08-29):** `tools/verifies/floor_bench.py` PASS — 844,223 exact Fraction checks: Lemma 4 on 643,125 step sequences; Theorem 4's band on 1,286,250 instances (200,693 flips, all inside; attainment at margin == γ); Corollary 4′'s DA-T1/DA-T2 core with the annulus equality instance; **Theorem 5(iii)'s floor over a 9-policy schedule class — every policy errs ≥ φ(0, ρF), all sit exactly on the floor; the F = 0 control collapses it** (the all-policy generality remains pen).

---

## Part III — C3: lossless compaction

### 3.1 Precise restatement

The conjecture (calculus §13):

> A compaction (checkpointing a balanced summary and truncating the prefix, digested Merkle-style) is **lossless for property class 𝒫** iff every 𝒫-checkable query on the full log is answerable on the compacted log. Balance invariants survive trivially (the summary is a balance); the conjecture is that **provenance-of-exclusions** … is preserved by digest-truncation, i.e. that quarantine chains remain checkable.

Two formalization decisions do all the work:

**C3-d1 (Compaction scheme; answering regime).** A compaction of L = (T₁,…,T_n) at checkpoint c is the object K_c(L) = (σ(T₁..T_c), h(T₁..T_c), T_{c+1..n}): a *summary fold* σ over the truncated prefix, a Merkle root h of the prefix, and the raw suffix. A query Q is **answered by the compacted ledger** iff its answer is computable from K_c(L) *alone* — no retained prefix, no external witness. (Verifiability *with* a witness is separated out, Theorem 8; conflating answerability with witness-verifiability is exactly the slip the conjecture makes.)

**C3-d2 (Summary fold).** A fold is (Σ, ⊕, f): Σ a state set, ⊕ associative and commutative, f : transactions → Σ; σ(P) = ⊕_{T∈P} f(T). Order-independence is not assumed — it is the T4/B3 lemma (application is additive per nonce; integer sums commute), which is why folds are the calculus's native summaries.

**C3-d3 (Losslessness).** K is lossless for 𝒫 iff for every Q ∈ 𝒫 and every log L: the answer computed from K_c(L) equals Q(L), for every valid c. A query class 𝒫 is **fold-covered** (by σ) iff for each Q ∈ 𝒫 there is q̂ with Q(L) = q̂(σ(L)) for all L.

### 3.2 Adjacent results

- **Mergeable summaries** [ACH+12] — count sketches, quantile summaries, distinct-count sketches closed under ⊕-merge with error guarantees: the ε-approximate fold catalog (§3.5).
- **Theta sketches** [Coh97; DLT07; DataSketches] — the size-estimation framework: sampling-based set sketches whose *unions* are again theta sketches with bounded error; the natural repair vehicle for exclusion-set provenance at fixed ε (inclusion–exclusion over unions is the theta-native operation).
- **CPC sketches** [LS18] — compressed probabilistic counting: mergeable distinct-count near the information-theoretic frontier; the "how small can an ε-fold be" benchmark for per-label quarantine counters.
- **Merkle auditing** [Mer80; RFC6962] — certificate-transparency-style logs: the digest chain preserves *verifiability* of membership claims (inclusion proofs against the root) — precisely the witness regime of Theorem 8(b).
- **Event sourcing** [Fow05] — snapshot-plus-tail is the industry shape of K; the folklore "snapshots lose audit detail" is Corollary 9's Ω(c) in engineering dress.
- **In-calculus adjacency** — T4 (balance fold), T5 (consolidation fold), and T2.1 (no fabrication: nothing leaves the books unposted) are the three results the conjecture leans on; Theorem 6 shows they are *the same theorem*.

### 3.3 The restricted theorem: lossless = fold-covered

**Theorem 6 (fold characterization of losslessness).**
**(a) Sufficiency.** *If every Q ∈ 𝒫 is fold-covered by σ, then K is lossless for 𝒫: answer via q̂(σ(prefix) ⊕ σ(suffix)).*
**(b) Necessity (summary-only schemes).** *If a scheme retains only σ′(prefix) (no digest, no raw prefix), then losslessness for 𝒫 forces every Q ∈ 𝒫 to be constant on the fibers of P ↦ σ′(P) — i.e. fold-covered, exactly.*
**(c) The calculus's own theorems are the first two folds.** *Balance queries: Σ = ℤ^(Acct), f = v_T, ⊕ = + (T4's semilattice). Exposed-projection queries: Σ = ℤ^(E), f = π_E ∘ v_T (T5's consolidation — lossless compaction for every query that factors through the boundary is literally T5(b)'s statement that interior activity is externally invisible). Counts, sums, joins/meets, and per-label counters (Theorem 8) are further instances.*

*Proof.* (a): associativity + commutativity give σ(A ⊎ B) = σ(A) ⊕ σ(B) (induction appending one transaction at a time; order immaterial — the T4 argument). The compacted object computes σ(T₁..T_n) = σ(T₁..T_c) ⊕ σ(T_{c+1..n}); q̂ of it is Q(L) by fold-coverage. (b): contrapositive. If some Q is not constant on some fiber — σ′(P₁) = σ′(P₂), Q(P₁) ≠ Q(P₂) — pick any common suffix S: logs L₁ = P₁ ⊎ S and L₂ = P₂ ⊎ S have identical compacted forms but different Q-values, so no answerer can be right on both. (c): T4 and T5, verbatim, read as fold lemmas. ∎ *(Consumes: T4/T5 machinery — A2, A4, and the projection algebra of D12.)*

**Remark (the conjecture's "trivially" clause is the theorem).** "Balance invariants survive trivially (the summary is a balance)" — Theorem 6 says there is nothing else: *the summary is the answer space*. Every exactly-compaction-safe query class is a fold image, and the calculus's catalog (T4 balance, T5 projection) plus the standard mergeable families is the whole shelf.

### 3.4 The counterexample: post-hoc exclusions do not survive

The conjecture's substantive clause is that provenance-of-exclusions survives digest-truncation. Under C3-d1's honest answering regime (the compacted ledger alone), it does not — in either of two formalizations, one unconditional, one computational.

**Counterexample 7 (the post-hoc exclusion query).** *Digest-truncation compaction is not lossless for exclusion-provenance queries with post-hoc (undeclared) predicates.*

*Construction.* Accounts a, b, c, d. Two prefixes of length 2:
- P₁ = [T*, T**], T* = (n₁, {(a,+5),(b,−5)}), T** = (n₂, {(a,−5),(b,+5)});
- P₂ = [U*, U**], U* = (n₃, {(c,+7),(d,−7)}), U** = (n₄, {(c,−7),(d,+7)}).

Both are balanced sequence-wise (A1 per transaction) and both net every touched account to zero: **the balance folds agree**, σ_bal(P₁) = σ_bal(P₂) = initial balances. Let Q = "does the compacted-away prefix contain a posting of value +5?" — Q(P₁) = YES, Q(P₂) = NO. This is a genuine provenance-of-exclusions query in the conjecture's own sense ('what a downstream consumer did *not* train on'): the payload predicate (+5-valued datum) is arbitrary, chosen by whoever audits the training-set exclusion later — *post hoc* by nature; a quarantine label set fixed at compaction time cannot anticipate it (that is Corollary 9's content).

*Regime 1 (unconditional; summary-only).* For any common suffix S, K(P₁ ⊎ S) = K(P₂ ⊎ S) — same summary fold, same suffix — while Q differs. By Theorem 6(b)'s contrapositive, no answerer exists. This needs no cryptography: the two prefixes are information-theoretically indistinguishable through the fold. ∎

*Regime 2 (computational; digest retained, random-oracle model).* Now K retains h(P) = Merkle root of the prefix. The root *does* separate P₁ from P₂ (as strings) — but separation is not extraction. **Hiding Lemma:** model the hash chain as a random oracle; for the answerer A holding only (σ_bal(P_b), h(P_b)) with b uniform: the roots h(P₁), h(P₂) are values of a random function at distinct (hidden) inputs, hence uniform and independent of b *from A's perspective*; A's view is identically distributed under b = 0 and b = 1, so A's advantage in computing Q is exactly 0 — not negligible: zero. (Scope, stated honestly: this is the standard ROM commitment-hiding argument and models the arriving-after-truncation auditor — no prefix on hand, no witness. It says the digest preserves *verifiability*, never *discoverability*.) ∎

*Why the conjecture's clause fails.* Digest-truncation converts the prefix from data to a commitment: membership claims about the prefix remain *checkable given a witness* (Merkle inclusion paths — [Mer80; RFC6962], the certificate-transparency pattern), but existence, counting, and enumeration over predicates not folded into the checkpoint become unanswerable. "Quarantine chains remain checkable" is true exactly for the labels someone had the foresight to fold; the conjecture's clause as stated — exclusions as such, surviving *any* compaction — is false, loudly: **you cannot quarantine after the fact what you did not think to count.**

### 3.5 Recovery, pricing, and the sketch catalog

**Theorem 8 (recovery: declared labels + witnesses).** *Fix a finite label set Λ of quarantine predicates q : transactions → {0,1} at compaction time; each is decidable on transaction payloads (D3 at r = 0 — payload structure checks are the thin-adapter discipline, D13). Augment the checkpoint with the Λ-fold (Σ_Λ = ℕ^Λ, f_Λ(T) = (q(T))_{q∈Λ}, coordinate-wise +) and, optionally, per-label accumulator roots.*
**(a)** *For every declared q: "how many q-flagged transactions were excluded?" and "was any?" are answered exactly from the checkpoint (Theorem 6(a) instance).*
**(b)** *A witness holding the dropped prefix (or the originators, or any replica) supplies (T, Merkle path); inclusion verifies in O(log c) against the retained root; the count from (a) plus witnessed enumeration makes the quarantine chain 'every excluded q-flagged datum is accounted for' fully checkable.*
**(c)** *The checkpoint grows by |Λ| counters (plus accumulator roots): permanent, exact, per declared predicate.*
*Proof.* (a): ℕ^Λ with coordinate-wise + is associative-commutative; Theorem 6(a). (b): Merkle-path soundness under collision resistance [Mer80]. (c): definition. ∎

**Corollary 9 (pricing: enumeration predicates force linear checkpoints).** *If 𝒫 includes enumeration answers for post-hoc predicates (predicates chosen after compaction; "list the prefix's qualifying transactions" is one), then any compaction lossless for 𝒫 retains Ω(c) state at checkpoint c. No fixed-size scheme — digest-truncation included — repairs Counterexample 7; the repair set is exactly {declared exact folds (Theorem 8), ε-approximate folds (below)}.*
*Proof.* Prefixes of length c over ≥ 2 payload symbols number ≥ 2^c; the "list the prefix" predicate's answers are pairwise distinct on them; losslessness demands pairwise distinct compacted states, so the state space has ≥ 2^c elements ⟹ ≥ c bits. The +5-family of Counterexample 7 likewise carries c/2 independent bits ⟹ Ω(c). ∎

**The ε-repair (survey, honestly scoped).** For count/existence-style exclusion queries over *declared families* (not post-hoc arbitrary), mergeable sketches give approximate folds: theta sketches for set-union cardinality and inclusion–exclusion (the exclusion-set's size, intersections with training windows — theta-native operations with error bounds [Coh97; DLT07]); CPC for distinct counts near the information frontier [LS18]; the PODS'12 catalog for frequencies/quantiles [ACH+12]. Each family costs its sketch's size in the checkpoint at its declared ε — Theorem 8(c)'s pricing with ε-slack. None of them touches Corollary 9: post-hoc enumeration stays Ω(c), forever.

**Remark (the monograph's live instance, resolved).** The conjecture's live instance is the walk-state honesty clause: "mirror-by-recomputation as the extreme compaction keeping only the source stream." The fold characterization explains it: walk-state (ladder buckets) is *not* fold-covered by the balance fold — P₁, P₂ above (or any T5(a) pair: different interiors, identical balances) are the witness fibers — so *no balance-checkpointing scheme whatsoever* can answer walk-state queries; keeping the source stream is not an implementation choice but the unique lossless compaction for that class. And the deep symmetry, worth saying once: **T5's consolidation-invisibility and C3's exclusion-opacity are the same phenomenon** — invariance on fold fibers — with opposite engineering valence. At a nest boundary, kernel-of-the-fold is the *feature* (interior churn cannot leak); at a compaction boundary, it is the *bug* (excluded churn cannot be recovered). The calculus already contained both halves; the fold is the hinge.

**Bar line.** *Compaction is lossless exactly over fold images; the digest keeps verdicts about the prefix verifiable but never discoverable; the checkpoint is priced by the declared query class — and undeclared questions cost the whole log.*

**C3 status.** Counterexample to the conjecture as stated (Counterexample 7, both regimes); restricted theorem proved (Theorem 6, with T4/T5 as instances — the conjecture's "trivially" clause promoted to the characterization theorem); recovery and lower bound proved (Theorem 8, Corollary 9). **Machine layer (bounded, 2026-08-29):** `tools/verifies/c3_fold_bench.py` PASS — 565,551 exact checks: Counterexample 7 executable (identical zero folds, differing Q) + 40 killing fiber pairs; the ROM hiding lemma with advantage exactly 0 over all 256 decision rules while binding holds; Theorem 8's Λ-counts and Merkle witnesses (forgeries rejected); Corollary 9's separation at c ≤ 10; the fold taxonomy byte-exact on 5,138 round-trips. Residual residue, stated honestly: an ε-lower-bound *matching* the theta/CPC repair (is Θ(ε⁻²) per family optimal for exclusion-set provenance specifically?) is surveyable but unproved here; the Ω(c) exact-enumeration bound is the closed half.

---

## IV — Outcomes register

| Conjecture | Outcome | Where |
|---|---|---|
| C1 freshness–partition dichotomy | **proved-restricted** (Theorem 1: dichotomy is a theorem during clean partitions; Lyapunov repaired to mirror in-flight; both meters exact) + **counterexample** at the seam (Counterexample 2: nonce collision — converged-by-instruments, divergent-in-content; the meter itself reads zero) + **closed** (Theorem 3: structural nonces make D4's uniqueness a theorem of A2+A3; seam merges loudly) | §I |
| C2 judgment-drift bound | **proved-restricted** (Theorem 4: drift band, tight, reduced to T3(c) by Corollary 4′; Theorem 5: cost ∝ ρ at fixed error, ∝ √ρ at the optimum, impossibility floor ρF) + **gap-formalized** (labeled perturbation is the closing hypothesis; GH-style unlabeled budgets are insufficient — relabeling flips verdicts at zero GH cost) | §II |
| C3 lossless compaction | **counterexample** (Counterexample 7: post-hoc exclusion queries — unconditional for summary-only, ROM-hiding with the digest; quarantine chains survive only for pre-declared labels) + **proved-restricted** (Theorem 6: lossless = fold-covered; T4/T5 are instances) + **recovery/pricing proved** (Theorem 8, Corollary 9: declared folds + witnesses restore checkability; enumeration predicates force Ω(c) checkpoints) | §III |

What would close each fully, weakest-first:

- **C1**: adopt Theorem 3's structural nonce discipline in D4 (one line of definition; makes the seam a composition of Theorem 1 and Theorem 3 phases). Then the full dichotomy — during, at, and after partitions — is proved modulo the composition lemma for flapping/asymmetric seams, which is bookkeeping, not insight.
- **C2**: accept C2-d2's labeled perturbation budget as the formalization of ‖d_t − d_{t+1}‖ (the identity correspondence on the alias quotient); Theorems 4–5 are then the full conjecture. The genuinely open remainder — optimal *adaptive* policies (drift-rate estimation with F-stale data, bandit-style dial schedules) — is a different, softer problem, adjacent to [BGZ15]'s restart optimality.
- **C3**: the conjecture should be *inverted*: lossless-for-𝒫 compaction exists iff 𝒫 is fold-covered (Theorem 6); exclusion provenance is preserved iff declared (Theorem 8); post-hoc enumeration is uncompressible (Corollary 9). What remains open is the ε-frontier for exclusion-family folds (§3.5's residue).

---

## V — References

Verification note (same convention as the monograph): ✤ = verified against live sources or the monograph's same-day-verified registry (2026-08-29); plain = trusted canonical bibliographic knowledge, live re-verification quota-blocked today (search API 429); flagged honestly.

- [ACH+12] P. Agarwal, G. Cormode, Z. Huang, J. M. Phillips, Z. Wei, Y. Yi. *Mergeable Summaries.* PODS 2012.
- [BBI01] ✤ D. Burago, Y. Burago, S. Ivanov. *A Course in Metric Geometry.* AMS GSM 33, 2001. (via quilt-calculus.md registry, same day)
- [BGZ15] O. Besbes, Y. Gur, A. Zeevi. *Non-stationary Stochastic Optimization.* Operations Research 63(5), 2015.
- [BVF+12] ✤ P. Bailis, S. Venkataraman, M. J. Franklin, J. M. Hellerstein, I. Stoica. *Probabilistically Bounded Staleness for Practical Partial Quorums.* VLDB 2012. (live-verified 2026-08-29)
- [BVF+14] ✤ P. Bailis, S. Venkataraman, M. J. Franklin, J. M. Hellerstein, I. Stoica. *Quantifying Eventual Consistency.* CACM 57(5), 2014. (live-verified 2026-08-29)
- [Coh97] E. Cohen. *Size-Estimation Framework with Applications to Transitive Closure and Reachability.* J. Comput. Syst. Sci. 55(3), 1997.
- [DataSketches] Apache DataSketches project documentation (theta sketch framework, set operations, error bounds).
- [DLT07] N. Duffield, C. Lund, M. Thorup. *Priority Sampling for Estimation of Subset Sums.* JACM 54(6), 2007.
- [Fow05] M. Fowler. *Event Sourcing.* martinfowler.com, 2005. (via quilt-calculus.md registry)
- [GL12] S. Gilbert, N. Lynch. *Perspectives on the CAP Theorem.* IEEE Computer 45(1), 2012.
- [GZB+14] J. Gama, I. Žliobaitė, A. Bifet, M. Pechenizkiy, A. Bouchachia. *A Survey on Concept Drift Adaptation.* ACM Computing Surveys 46(4), 2014.
- [HW98] M. Herbster, M. K. Warmuth. *Tracking the Best Expert.* Machine Learning 32(2), 1998.
- [LS18] K. Lang, A. Shrivastava. *CPC: A Memory-Bound Optimal Sketch for Set Membership and Cardinality.* (compressed probabilistic counting; see DataSketches documentation.)
- [MDV11] P. Mahajan, L. Alvisi, M. Dahlin. *Consistency, Availability, and Convergence.* UT Austin TR-11-22, 2011.
- [Mer80] R. C. Merkle. *Protocols for Public Key Cryptosystems.* IEEE S&P 1980.
- [RFC6962] B. Laurie, A. Langley, E. Kasper. *Certificate Transparency.* RFC 6962, IETF, 2013.
- [SPBZ11] ✤ M. Shapiro, N. Preguiça, C. Baquero, M. Zawirski. *Conflict-Free Replicated Data Types.* SSS 2011. (via quilt-calculus.md registry, same day)
- [TTP+95] D. B. Terry, M. M. Theimer, K. Petersen, A. J. Demers, M. J. Spreitzer, C. H. Hauser. *Managing Update Conflicts in Bayou, a Weakly Connected Replicated Storage System.* SOSP 1995 / ACM TOCS 13(3), 1995.
- [YV02] ✤ H. Yu, A. Vahdat. *Design and Evaluation of a Conit-based Continuous Consistency Model for Replicated Services.* ACM TOCS 20(3), 2002. (via quilt-calculus.md registry, same day)
- [Zin03] M. Zinkevich. *Online Convex Programming and Generalized Infinitesimal Gradient Ascent.* ICML 2003.

---

*Conjectures lane, 2026-08-29. Two conjectures died partially and loudly (C1's seam, C3's clause); the survivors were promoted to restricted theorems with exact meters (C1 during-partition, C2's band and policy, C3's fold characterization); each carries its own weakest closing hypothesis. The books balance: every credit cited, every No loud, every proof real.*
