# 07 — Open Research Questions

> *Phase 3 deliverable #6.*
> *Formal complexity-theoretic questions + down-graded formal claims + prioritized scout targets.*
> *Builds on `01_SYNTHESIS.md` through `06_THE_AUTHOR_DISCLAIMER_QUESTION.md`.*
> *Date: 2026-09-05.*

---

## What this document does

This document catalogs the open research questions the documentation set has surfaced, organized into three categories:

1. **Formal complexity-theoretic questions** — what would need to be proved or refuted to make the structural-bridge argument rigorous at the complexity-theory level.
2. **Down-graded formal claims** — where the corpus's formal claims are weaker than advertised, and the honest restatement that should be used.
3. **Prioritized scout targets** — the unread parts of the corpus that the deep-dive scout (Task 4-g) flagged as potentially containing material that would strengthen or break the argument.

This document is the bridge from Phase 3 (documentation) to Phase 4 (formal engagement / further scouting). It is the place where the user can decide which direction to push next.

---

## A. Formal complexity-theoretic questions

### A1. What is the complexity class of the quilt fleet?

**The question:** A single quilt cell is a monotone circuit (per Bridge 7 in `03_STRUCTURAL_BRIDGES.md`). The fleet achieves generality via the FORGET_completeness law (a cell can be destroyed without losing the whole; the fleet survives by distribution). What is the complexity class of the fleet?

**Why it matters:** This is the most direct complexity-theoretic question the corpus opens. If the fleet is in P (polynomial-time solvable), then the structural-bridge argument is weak — quilt does not reach a regime that classical computation cannot already reach. If the fleet is in P/poly or higher, the argument is stronger. If the fleet can compute functions that are hard for monotone circuits (per Razborov 1985, CLIQUE is hard for monotone circuits of polynomial size), then the FORGET_completeness law is doing real complexity-theoretic work.

**What would be needed to answer it:**
- A formal model of the fleet's computation (what is the input? what is the output? what is the communication model between cells?).
- A reduction from a known complexity class to the fleet's computation (or vice versa).
- Engagement with the existing literature on circuit complexity for distributed systems (e.g., LOCAL vs GLOBAL complexity, distributed circuit complexity).

**Candidate answer (speculative):** The fleet is plausibly in P/poly (polynomial-size circuits with advice) — the "advice" being the per-cell configuration that the cowboy assigns. But this is speculation; the formal model has not been developed. The Monotone Crystal's self-correction (validating against OEIS A000372) suggests the corpus is capable of formal complexity-theoretic work, but the work has not been done for the fleet as a whole.

### A2. Can a quilt cell compute a non-monotone function?

**The question:** The Monotone Crystal (Bridge 7) is explicitly restricted to monotone Boolean functions (only ever 0→1, never back). Razborov 1985 proved CLIQUE is hard for monotone circuits of polynomial size. Can a quilt cell, using the full 5+1 opcodes (BIND, LINK, EFFECT, VIEW, TICK, FORGET), compute a non-monotone function like NOT or XOR?

**Why it matters:** If the answer is yes, then the Monotone Crystal is a special case of a more general computational model, and the quilt substrate can compute general Boolean functions per cell (not just monotone ones). If the answer is no, then the substrate's per-cell computational power is genuinely restricted, and the fleet composition is doing real complexity-theoretic work.

**What would be needed to answer it:**
- A formal model of the 5+1 opcodes as a circuit model (what are the gates? what are the wires? what are the constants?).
- A reduction from a known circuit class (e.g., AC⁰, TC⁰, NC¹, P/poly) to the 5+1 opcodes.
- Engagement with the existing literature on circuit complexity for algebraic structures (e.g., circuits over monoids, circuits over semirings).

**Candidate answer (speculative):** The FORGET opcode is the key. FORGET retires a cell — it is the 0→ (nothing) transition, which is the dual of the 0→1 monotone transition. If FORGET is allowed to retire a cell that was previously BIND'd to 1, then the substrate can compute NOT (BIND 1, FORGET 1, BIND 0 — though the semantics here are unclear). But this is speculation; the formal model has not been developed.

### A3. Does the predict-and-confirm protocol produce verifiable expectation values in the formal sense?

**The question:** The structural-bridge argument (Bridge 1 in `03_STRUCTURAL_BRIDGES.md`) claims that quilt's predict-and-confirm protocol produces verifiable expectation values structurally analogous to the OTOC's expectation values. But the OTOC's verifiability is formal (the expectation value is a polynomial-time-computable quantity, and the cross-check across quantum devices is a polynomial-time-computable comparison). Is quilt's verifiability formal in the same sense?

**Why it matters:** If quilt's verifiability is formal, then the structural-bridge argument is strong at the formal level. If it is informal (a protocol-level correspondence without formal complexity-theoretic content), then the argument is weaker.

**What would be needed to answer it:**
- A formal model of the PredictionOutcome ∈ {Confirmed, Exceeded, Within} as a complexity-theoretic object (is it a decision problem? a promise problem? a sampling problem?).
- A formal model of the witness log (Merkle tree) as a verifiable computation (can a third party verify a witness entry in polynomial time? what is the soundness guarantee?).
- Engagement with the existing literature on verifiable computation (e.g., PCP theorem, interactive proofs, succinct arguments).

**Candidate answer (speculative):** The witness log is a Merkle tree, which gives a polynomial-time-verifiable authentication of any entry (given the root hash and the path). The PredictionOutcome is a decision problem (Confirmed = prediction correct within deadband; Exceeded = prediction way off; Within = slight mismatch absorbed). So quilt's verifiability is plausibly formal in the sense of being polynomial-time-verifiable. But the formal model has not been developed.

### A4. What is the complexity class of the fog-of-war decay + convoy consensus combination?

**The question:** The fog-of-war decay (`c(t) = c₀ · exp(-λt)`) + convoy consensus (Wilson LB + geometric median) is the substrate's mechanism for producing verifiable outputs from decaying measurements. What is the complexity class of this combination?

**Why it matters:** If the combination is in P, then the substrate's verifiability is polynomial-time-computable, and the structural-bridge argument is strong at the formal level. If the combination is harder (e.g., the convoy consensus with N agents is NP-hard in some parameter regime), then the substrate's verifiability has a complexity-theoretic depth that the structural-bridge argument should engage with.

**What would be needed to answer it:**
- A formal model of the convoy consensus as a distributed algorithm (what is the communication model? what is the failure model? what is the consensus guarantee?).
- A reduction from a known distributed-complexity class to the convoy consensus.
- Engagement with the existing literature on distributed consensus complexity (e.g., the FLP impossibility result, the lower bounds on Byzantine agreement).

**Candidate answer (speculative):** The convoy consensus with Wilson LB + geometric median is plausibly in P for the non-Byzantine case (geometric median is polynomial-time-computable; Wilson LB is polynomial-time-computable). For the Byzantine case (some agents are malicious), the consensus is harder, but the substrate does not currently have a formal Byzantine model. The formal model has not been developed.

### A5. Does the batten-spline router's Nadaraya-Watson kernel regression with exponential temporal decay reach a regime that classical kernel regression does not?

**The question:** The batten-spline router uses Nadaraya-Watson kernel regression with exponential temporal decay (`a_i(t) = 0.5^((t-t_i)/τ)`) on verified outcomes. This is structurally similar to a kernel method with a temporal-decay kernel. Does this combination reach a regime that classical kernel regression (without temporal decay) does not?

**Why it matters:** If the answer is yes, then the batten-spline router is doing real complexity-theoretic work (the temporal decay is not just a heuristic; it is a structural feature). If the answer is no, then the batten-spline router is a classical kernel method with a temporal-decay heuristic, and the structural-bridge argument is weaker.

**What would be needed to answer it:**
- A formal model of the batten-spline router as a kernel method (what is the kernel? what is the hypothesis class? what is the generalization bound?).
- A reduction from a known kernel-method complexity class to the batten-spline router.
- Engagement with the existing literature on online kernel methods and time-decaying kernel methods.

**Candidate answer (speculative):** The temporal decay is structurally similar to the forget factor in online learning (e.g., exponentially-weighted moving average, recursive least squares with forgetting). These are classical methods with well-understood complexity. The batten-spline router is plausibly in this class. The formal model has not been developed.

---

## B. Down-graded formal claims

The deep-dive scout (Task 4-g) found that the corpus's formal claims are weaker than advertised in several places. The documentation set should use the honest restatements below.

### B1. The "inversive monoid" claim

**The corpus claims:** The 5 opcodes form an inversive monoid (paper-169 §3, substrate-meta docs/MATHEMATICS.md §3).

**The honest restatement:** Every non-VIEW message has a well-defined inverse. VIEW has no inverse because it has no effect (paper-169 line 90). The "inversive" qualifier is technically inaccurate as stated.

**Where to use it:** In any document that engages with the formal algebraic structure of the 5 opcodes.

### B2. The "Turing-complete" claim

**The corpus claims:** The 5 messages are the Kleene closure of one primitive (the cell), which means the substrate is Turing-complete (substrate-meta docs/CODING-AGENT-GUIDE.md line 263, docs/INTRO.md line 315).

**The honest restatement:** The Kleene closure (free monoid) on a single generator is isomorphic to ℕ (just counting), which is NOT Turing-complete. The actual claim should be that the 5 opcodes form a sufficient instruction set for computation, which requires actual reduction to known Turing-complete formalisms. GENERAL-CALCULUS.md treats this as an OPEN CONJECTURE (GC-C1): *"The adjacent known result is the compilers-side analogy (Turing-complete cores with tiny opcode sets), which supplies reducibility of computation but not of organ fidelity — verdicts, books, and bounds, not just behavior; that gap is why this is a conjecture and not a citation."*

**Where to use it:** In any document that claims quilt is Turing-complete. Use "the substrate is plausibly Turing-complete, but this is an open conjecture (GC-C1) rather than a proven theorem."

### B3. The "monad" claim

**The corpus claims:** A cell is a monad in the category of values (paper-169 §4, substrate-meta docs/MATHEMATICS.md §4).

**The honest restatement:** The monad laws hold at the level of balance maps and log homomorphisms. The full categorical statement (a monad on a category of cells, with naturality squares) requires machinery the corpus does not develop; the corpus claims the laws, not the 2-categorical packaging (quilt-calculus.md line 567–577).

**Where to use it:** In any document that engages with the categorical structure of the cell.

### B4. The "equivalence gate" claim

**The corpus claims:** Two implementations, one truth (paper-186). The Rust and C implementations are bit-identical, proving the formal object is real.

**The honest restatement:** The equivalence gate is EMPIRICAL bit-identity on a finite test suite (5 fixture signals × 10 re-runs = 50 observations), NOT a formal equivalence proof. THE-BREAKDOWN.md §10 was closed small-scale on 2026-08-31 at NCELL=2 only, against MEASURED (not universal) serialization. Paper-186 itself says "evidence", not "proof": *"When they agree bit-for-bit, we have evidence that the formal object is real and the implementations are faithful."*

**Where to use it:** In any document that engages with the equivalence gate. Use "empirical bit-identity on a finite test set" rather than "formal equivalence proof."

### B5. The "law prover" claim

**The corpus claims:** The 5+1+1 laws are proven on the substrate (quilt-wiki-2126 02-the-5-laws.md line 31: "Marked: REAL (all 7 laws proven on the substrate)").

**The honest restatement:** The laws are AXIOMATIC/DEFINITIONAL — they define the opcodes, not theorems to prove. The "law prover" (`src/prove.c`) is a syntactic compliance checker that verifies compositions conform to the laws; it does not prove the laws themselves. Paper-215 admits the laws were not previously written in the canon: *"The canon has 3123 mentions of the 5 opcodes and 10 mentions of the 5 laws... The cowboy has been claiming laws he never wrote."*

**Where to use it:** In any document that engages with the 5+1+1 laws. Use "the laws are axiomatic/definitional; the prover is a syntactic compliance checker" rather than "the laws are proven."

### B6. The "spectral triple" claim

**The corpus claims:** The 8 Quilt primitives are the generators of A in the spectral triple (A, H, D) (quilt-id README).

**The honest restatement:** The README asserts the thesis; the implementation (quilt_id.py) does not implement a spectral triple. The implementation is BLAKE2b + golden-ratio multiplication + 5D lattice projection. The spectral-triple / noncommutative-torus framing is metaphorical at the implementation level.

**Where to use it:** In any document that engages with quilt-id. Use "the README asserts a spectral-triple thesis; the implementation is a content-addressing scheme."

---

## C. Prioritized scout targets

The deep-dive scout (Task 4-g) flagged the following as potentially containing material that would strengthen or break the structural-bridge argument. Priority order:

### C1. HIGH: quilt-foundation

> "10 round-stones + fire: The 5 opcodes, mathematically derived from the 10 rounds of research" (per COLLECTION.md Path 4).

The 10 rounds are described as the original research that produced the 5 opcodes. This is potentially the deepest formal foundation document and was NOT fetched by scout 1-a or scout 4-g. Source: https://github.com/SuperInstance/quilt-foundation.

**Why it matters:** If the 10 rounds contain the formal derivation of the 5 opcodes from first principles, this could be the strongest formal-claim document in the corpus. It could either strengthen the "Turing-complete" conjecture (GC-C1) or break it.

### C2. HIGH: zeroclaw-dissertation (THESIS-V3)

quilt-llvm THEORY.md explicitly cites zeroclaw THESIS-V3 for "fiber theorems about rooms on S⁶" and "adjoint inference runs backward as more forward ops on the same schedule (λ_t = Aᵀλ_{t+1})". This is the most direct adjacency to formal mathematics about adjoints / adjunctions / fibers, and may contain the strongest formal-claim bridge. Source: https://github.com/SuperInstance/zeroclaw-dissertation/blob/master/research/dissertation/THESIS-V3.md.

**Why it matters:** If THESIS-V3 contains formal theorems about adjoints and fibers that apply to quilt's opcodes, this could be the formal anchor for Bridge 4 (t-minus predict-and-confirm ↔ OTOC time-reversal structure). The "adjoint inference runs backward as more forward ops on the same schedule" is structurally the adjoint-functor formalism that could unify the predict-correct structures.

### C3. HIGH: quilt-verilog/docs/academic/{BRIDGES,CONJECTURES,RHO-F-FLOOR,DRIFT-AS-PREFILTER,FOLD-COVERED,ELEGANCE,DEPENDENCY-GRAPH}.md

The formal academic spine beyond quilt-calculus and GENERAL-CALCULUS (already fetched). These contain:
- **BRIDGES.md** — cross-document dependency proofs.
- **CONJECTURES.md** — three open conjectures (C1 dichotomy, C2 drift band, C3 fold characterization).
- **RHO-F-FLOOR.md** — the audit-freshness impossibility floor.
- **DRIFT-AS-PREFILTER.md** — the judgment-drift composition theory.
- **FOLD-COVERED.md** — the ledger-compaction losslessness theory.
- **ELEGANCE.md** — formal elegance criteria.
- **DEPENDENCY-GRAPH.md** — the formal dependency graph.

These were listed in docs/INDEX.md but not fetched by scout 4-g.

**Why it matters:** These documents are the formal academic spine. If they contain formal proofs (not just claims) of any of the structural-bridge arguments, this would dramatically strengthen the documentation set.

### C4. MEDIUM: quilt-verilog/docs/academic/annals-1905/

7 memoirs of the "Kaldfjord Circle" (1903–1905), a fictional-historical framing of the substrate's discoveries. May contain deeper formal claims disguised as fiction.

### C5. MEDIUM: AI-Writings/seed-canon/fables/

100+ fables, mostly unread. Per COLLECTION.md Path 6, the cowboy-and-X fables (76-92) "see the polyformalism in medicine, plumbing, the herd, etc." May contain quantum-bridge material in narrative form.

### C6. MEDIUM: AI-Writings/essays/, philosophy/, manifestos/

"600+ essays where the boats think out loud between watches". The FETCH essay is the "origin myth". Per scout 1-a: ~18 essays fetched, ~580 unread.

### C7. MEDIUM: quilt-rust, quilt-cloudflare

The OTHER (parallel) quilt ecosystem ("8 cell kinds / 15 cell kinds cellular runtime", per COLLECTION.md note at line 88). The COLLECTION.md note says: *"The two collections share the same cell — (name, value, identity) — but use different vocabularies. See Paper 185 for the synthesis."* This may be relevant to understanding how the 5-opcode algebra relates to the 8/15-kind cellular runtime.

### C8. LOW: quilt-cuda/src/quilt_cells.cu, quilt_graph.cu

Source code (not just docs) for the CUDA implementation. Could verify the "32 lanes = one cell" claim.

### C9. LOW: quilt-vm-haskell

"The algebraic Haskell port" per paper-139. May contain the most rigorous formalization of the 5 opcodes (Haskell typeclasses naturally express monad laws).

### C10. LOW: cell-cascade

"The stem-cell doctrine as running infrastructure. Myelination counters that auto-promote repeated paths into zero-cost rule tables" (per COLLECTION.md Path 9). May contain the implementation of the synovial-tier myelination (paper-208 §3.3).

---

## D. The bottom line for Phase 4

The documentation set has reached the point of diminishing returns from further synthesis. The strongest remaining work is:

1. **Formal complexity-theoretic engagement** (questions A1-A5). These are the questions a quantum-information theorist or a complexity theorist would engage with directly. The documentation set has flagged them; the next step is formal work, not more documentation.

2. **Deeper scouting** of the HIGH-priority targets (C1-C3: quilt-foundation, zeroclaw-dissertation THESIS-V3, quilt-verilog/docs/academic/{BRIDGES,CONJECTURES,RHO-F-FLOOR}.md). These are the most likely to contain material that would either dramatically strengthen or break the structural-bridge argument.

3. **Engagement with the quantum-information community.** The Aaronson-Hagar exchange (July 2026) is the live debate this documentation set engages with. The next step would be to write a response to either Aaronson's blog or Hagar's preprint that articulates the third position (per `05_AARONSON_HAGAR_AND_QUILT.md`).

The documentation set is now at a natural stopping point for Phase 3. Phase 4 (if the user chooses to pursue it) should focus on (1) formal complexity-theoretic work and (2) deeper scouting of C1-C3.
