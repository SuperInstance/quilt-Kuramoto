# DENY BY RUNNING — the evidence-grade method: reproducibility as burden of proof, the dossier schema, and what a skeptic must do

**Lane:** academic-expansion (GLM-5.3) · **Date:** 2026-08-29
**Sources upgraded:** `THE-BREAKDOWN.md` (the 12-section dossier, its grade tallies, Appendices A–B), the correction ledgers of `error-envelopes.md` §0 and `docs/academic/`'s house style, and the falsification history of RQH (error-envelopes §3, THE-BREAKDOWN §4). Self-contained: every artifact referenced is named with its command; every claim about the repo's own record cites its committed file.

> **The contract of this document.** The method in one sentence: **a claim's grade is what a denier must execute to refute it.** This paper (1) formalizes the evidence grades — pending, pen-only, machine-checked (with the bounded/unbounded/proof-assistant refinement M1/M2/M3 the dossier conflates), and machine-checked-with-teeth — as *licenses*: what each grade permits a claimant to say, and forbids (§2); (2) states the dossier schema — CLAIM → DEFINITIONS → PROOF → MACHINE-CHECK → ATTACK-SURFACE → CLOSURE — as a reusable method, with each field's contract and its characteristic failure modes (§3); (3) runs the RQH falsification history as the case study proving the method has teeth — the machine corrected the correction, against the claimant's interest, twice (§4); (4) maps grades to denial actions: the denial table, the monotonicity of denial cost, and the two attacks that survive even at the top grade (§5–6); (5) states falsifier-first design and the gaps register as first-class artifacts — the boundary that keeps "not yet run" honest (§7). §9 grades this paper by its own rules; that self-application is the method's closure test.
>
> **What this paper is not.** It is not an argument that machine-checked claims are *true* — BMC depth 55 is not proof, a testbench is not a theorem, and §2 grades them accordingly. It is an argument that the *distance between a claim and its refutation* is the right unit of evidence, and that the distance can be made explicit, priced, and — the part that matters — *falsifiably short*.

**Statement registry.** 5 definitions (DB-D1–D5), 1 theorem (DB-T1, denial monotonicity), 3 propositions (DB-P1–P3), 2 tables-as-theorems (the license table LT, the denial table DT), 6 field contracts (SCHEMA), 8 numbered arguments. Grade: **pen-only, self-applying** (§9).

---

## 1. The doctrine: denial is the unit of evidence

The classical statement is Popper's: a claim is scientific only if some conceivable observation could refute it [Pop59]. The engineering translation this method adopts is stricter and more operational:

> **DB-D1 — The denial cost of a claim C** is the minimal total effort for a competent, *hostile* skeptic to produce a refutation of C: the work to (i) understand what C asserts, (ii) obtain or construct the evidence C rests on, and (iii) produce a contrary observation or a defect in C's own chain. Denial cost is measured in the skeptic's actions (commands run, flaws found), not in the claimant's assertions.

The doctrine: **evidence is the act of raising denial cost in the specific, verifiable sense.** Not persuading, not citing, not even proving in the abstract — *shortening and hardening the path a hostile party must walk to break the claim*. Every mechanism in the method — the grades, the schema, the falsifier-first register — exists to make denial cost explicit and to make it paid in *executable* currency wherever possible.

Two corollaries frame everything:

- **Corollary (authority is worthless currency).** No result is credited because of who wrote it, where it was published, or how often it has been cited. Every theorem is either re-derived in-repo (with the derivation's location given so it can be attacked) or machine-executed (with the command given so it can be re-run). THE-BREAKDOWN's header states this as a rule; this paper states why it is a corollary: authority-based credit does not raise denial cost by one command.
- **Corollary (the corpse requirement).** A checking apparatus that has never failed anything checks nothing. A proof suite's history of kills is part of its evidence — the ci_ready hole (formal/README Findings #2), the three C4–C6 corrections, the $rtoi gotcha — because a checker with corpses has demonstrated that its assertions *can* fire. A green suite with no history is consistent with the suite asserting tautologies. (§4 makes this precise for the RQH bench.)

---

## 2. The evidence grades, formalized

### DB-D2 — The pen grades

> **E0 (pending).** The claim's supporting artifact does not exist or has not run; the claim is an intent. *Denial: argue, or wait.*
> **E1 (pen-only).** A written proof exists, complete, self-contained, with axioms named; no machine executes it. *Denial: read it and find a flaw — a bad step, an unnamed axiom, an unmodeled case.*
> **E2 (machine-checked).** An artifact executes and asserts the claim; the command is published; re-running reproduces the verdict. *Denial: run the command and get different output — or show the artifact does not check what the section says it checks (the stronger attack; §6).*
> **E3 (machine-checked with teeth).** E2, and the artifact has previously *failed* something real — a planted defect, a prior version, a known-bad input — demonstrating its assertions can fire. *Denial: as E2, plus explaining why the earlier kills were flukes.*

### DB-D3 — The machine refinement (the distinction THE-BREAKDOWN's "machine-checked" compresses)

> **M1 (bounded exercise).** The artifact checks the claim on a bounded envelope: BMC to depth d, testbenches on swept or random inputs, census sweeps. Strength: real bugs die inside envelopes (structural worst-case arguments make the envelope cover the reachable counterexample space; the README's per-property bound analysis is the discipline). Weakness: unenrolled traces are unchecked — the grade licenses "holds everywhere the machine looked, with the looked-space argued."
> **M2 (unbounded machine proof).** k-induction in `mode prove`, cover-to-induct, any engine whose verdict is over *all* traces. The flit-pipe interface contract (`tb/formal/flit_pipe.sby`, < 1 s, boolector) is the repo's current M2 instance. Licenses "holds, machine-argued, modulo the environment assumptions" — and the assumptions are enumerated and each is *weaker than the real system* (formal/README: E1–E4).
> **M3 (proof assistant).** Coq/Lean/Isabelle-grade mechanization: the proof object itself is checkable. Not present in this repo today; named so the ladder has a top and the gap is honest (THE-BREAKDOWN B1's `mode prove` upgrades are M1→M2 moves; an M3 lane would be the successor).
>
> A claim's full grade is the pair (pen grade, machine grade): e.g. §1's conservation is (E1, M1) — T1/T2 proved in the calculus, exercised by `fabric.conservation.sby` BMC 55 with no stubs; the flit-pipe contract is (E1, M2); the C2 floor (this wave: `RHO-F-FLOOR.md`) is (E1, ∅) with the bench specified.

### DB-D4 — Licenses (the speech acts each grade permits)

> **The License Table (LT).** A claimant may say:
>
> | Grade | May say | May NOT say |
> |---|---|---|
> | E0 | "we expect / it is designed to" | anything with "is", "does", "holds" |
> | E1 | "proved, modulo reading the proof" (with location) | "verified", "machine-checked", "guaranteed" |
> | E2·M1 | "checked to the stated envelope; violations require a trace outside it" | "proved for all traces", "unconditionally" |
> | E2·M2 | "machine-proved under the listed assumptions (each weaker than production)" | "assumption-free" |
> | E3 | E2's licenses + "and the harness has killed before" | "cannot be wrong" (never licensed — grade ceilings are absolute) |
>
> **Grade inflation is the characteristic sin.** The repo's own record contains the canonical examples, all caught and logged: SYNTHESIS Q3's `W_exact/2 − 1 ≤ Ŵ` assertion (fourfold loose on the lower side — an E2 artifact under-claiming, benign but sloppy; ELEGANCE E4's tightening), ABSTRACTION-MATH §5.2's inverted hyperbola envelope (E1 prose claiming the opposite direction of the E2 testbench — C1 in error-envelopes §0: *the TB was right, the prose was wrong*), and the RQH proposal's "asymptotically tightens" (E0 prose at E2 prices — §4 below). The correction ledger exists because inflation happened; that it is the *first section* of the envelopes document is the method working.

### DB-P1 — The two-sidedness of grades

> **Proposition.** Grades under-claim by design (undersell/overdeliver): an E2·M1 claim whose envelope is honestly drawn is *never violated* by a trace outside the envelope — but its license says so. The information a grade carries is therefore two-sided: an upper bound on claim strength (the license) and a lower bound on denial cost (§5's table). A method that only inflated — or only deflated — would leak on one side; the license and the denial cost move together by construction.
>
> *Argument.* Immediate from DB-D2/D4's definitions: each grade's license is the strongest statement whose refutation requires at least that grade's denial actions. ∎

---

## 3. The dossier schema as a reusable method

THE-BREAKDOWN's twelve sections all run the same six-field shape. The shape is the method's core deliverable; each field has a contract (what must be present) and characteristic failure modes (how the field goes bad, with the repo's own examples where they exist).

### SCHEMA — The six fields

> **F1 · CLAIM.** *Contract:* the assertion in one paragraph, scoped, with the numbers it will stand behind. *Failure mode:* scope creep — the claim quietly widens after the check passes (the machine checked X, the claim says Y ⊃ X). *Discipline:* the CLAIM is frozen text; §F6's CLOSURE may only narrow it.
>
> **F2 · DEFINITIONS.** *Contract:* every term the proof uses, numbered, self-contained; a reader who denies everything can check this section alone. *Failure mode:* inherited vocabulary — terms used because a companion defined them, breaking self-containment (the audit lane's FWD/LEAP registers exist to catch exactly this). *Discipline:* if a definition is a carry, cite it *and restate it* — DEPENDENCY-GRAPH's mechanical check is the model.
>
> **F3 · PROOF.** *Contract:* the derivation, complete, consuming only F2's definitions and named axioms; axioms honestly marked as assumed (balance is never a theorem — A1). *Failure mode:* the skipped algebra — "by a standard argument", the +1 slack asserted not derived (C5's upper-edge slack was exactly this class until the tail bench measured 13 witnesses). *Discipline:* each proof names its axiom consumption; the calculus's "Axioms used:" line is the pattern.
>
> **F4 · MACHINE-CHECK.** *Contract:* the artifact (file, command, expected verdict, runtime) — or the honest marker: "pen-only, check designed not run" / "PENDING". *Failure modes:* the phantom check (a command that was never run — §THE-BREAKDOWN §10's `grep -ci cosim → 0` is the audit that catches it); the harness-asserts-something-else (see F5). *Discipline:* re-runnable-this-session is the bar; Appendix A of the dossier re-ran everything it cites.
>
> **F5 · ATTACK SURFACE.** *Contract:* the levers a denier should pull, ranked, including the ones that would work — every strong claim ships with its own weakest point. *Failure mode:* decorative attacks (strawman denials nobody would attempt). *Discipline:* each attack names the artifact or proof step it targets; the *stronger attack* (the artifact does not check what the section says) must always be listed when F4 is nonempty.
>
> **F6 · CLOSURE.** *Contract:* the exact denial, stated as a recipe ("denial requires X to FAIL, or a demonstration that Y"), plus the gap ID if the section's check is not yet run. *Failure mode:* closure-by-vibes ("we are confident"). *Discipline:* a closure that cannot be executed is not a closure; downgrade the section's grade.

### DB-P2 — The schema's completeness (why six, and only six)

> **Proposition.** The six fields are jointly necessary and individually minimal for the doctrine: CLAIM fixes what is graded; DEFINITIONS fix what the proof may consume; PROOF is the E1 content; MACHINE-CHECK is the E2/M content; ATTACK-SURFACE is the denial map; CLOSURE is the grade stated as a recipe. Removing any field collapses the claim into an adjacent weaker grade (remove F5 and E2 claims become unattackable rhetoric; remove F4 and E2 silently becomes E1; remove F2 and every proof is a leap pending).
>
> *Argument.* Each field exists to carry one grade-ingredient identified in §2; the mapping is a bijection, and the failure modes above are exactly the collapses. ∎

---

## 4. Case study: RQH — the falsification history that proves the teeth

The residue-banking readout (RQH) is the method's canonical exhibit because every party in the story was *inside* the system: the proposal claimed, the theorem denied, the machine corrected the correction, and the measurement then confirmed both verdicts. Four steps, all committed:

**Step 1 — the E0 claim.** `proposals/innovations/flash.md`: the corrected readout "asymptotically tightens the envelope" toward the exact memory law. License audit (LT): E0 may say "we expect"; "tightens the envelope" is a quantitative assertion at E2 prices. Inflation, on the record.

**Step 2 — the E1 No.** error-envelopes Theorem 3: (3a) the credit is bounded (≤ 255 LSB, provable, tight); (3b) the credit is non-negative, so it *widens* the worst-case upper band — the strong claim is false **as a matter of sign**; (3c) the exact convergence condition is derived: `deposit(g) = 2^(K+QDW−g)·(1 − 1/(2 ln 2))`, and the as-built deposit `2^g` misses it by a factor ~2^(K+QDW−2g)·0.28 — quoted at first as "~9,100× at class 0."

**Step 3 — the machine corrects the correction, against the claimant.** The tb-envelope lane built `tb/tb_rqh_saturation.v` and evaluated the *document's own formula* at g = 0: 2^16 · 0.27865 = 18,261.8 — the ~9,100 was a 2^15 slip (correction C6). The honest factor is **~18,262×**: the error went *against* the system's own claim and was printed anyway. This is the corpse requirement in its sharpest form: the checker checked the checker, and the kill was self-inflicted.

**Step 4 — both verdicts measured.** Under the corrected deposit table `[18260, 9130, 4565, 2283, 1141, 571, 285, 143]`: the mis-phased mean error tightens 120.4 → 57.1 LSB at QLEAK 5 (2.1×) — the derived prediction *happens*; the as-built `2^g` delivers literally zero credit; the aligned-phase control *widens* 125.9 → 191.4 — Theorem 3b confirmed empirically; QLEAK 8 saturates and destroys the tightening — the leak dial is the other half of the condition. All in the TB and error-envelopes §7.1.

### DB-P3 — What the history proves about the method

> **Proposition.** The RQH history demonstrates the three properties the doctrine requires, each at a different step: (i) *the grades bite downward* — an E0 claim was killed by an E1 sign argument that no amount of engineering could repair (3b is an impossibility, not a shortfall); (ii) *the machine is not ceremonial* — it found an arithmetic error inside the error-correction document itself, and the correction was adverse to the claimant (the strongest possible evidence against motivated reasoning); (iii) *predictions are load-bearing* — the derived convergence condition, once satisfied, produced the predicted 2.1× tightening, and its violation, once planted (QLEAK 8), produced the predicted destruction. A method whose derived conditions neither hold-when-satisfied nor fail-when-violated is decoration; this one predicted in both directions and the bench measured both.
>
> *Argument.* The four steps with their artifacts, as cited. ∎

---

## 5. The denial table

### DB-D5 — Denial actions by grade

> **The Denial Table (DT).** To deny a claim of grade G, a skeptic must, at minimum:
>
> | Grade | Denial recipe | Cost ceiling |
> |---|---|---|
> | E0 | say "unverified" | one sentence |
> | E1 | find a flaw in the written proof (bad step, unnamed axiom, unmodeled case) and exhibit it | a careful read |
> | E2·M1 | run the command, get different output — *or* read the harness and show it asserts something other than the CLAIM (the stronger attack: it converts the section's own artifact against it); *or* produce a trace outside the envelope and show the envelope's structural worst-case argument does not cover it | minutes (re-run) to hours (harness audit) |
> | E2·M2 | as M1, plus: defeat an induction — exhibit a real counterexample the k-induction missed (only possible if an environment assumption is *false in production*, which is itself a finding the README invites: E1–E4 are each claimed weaker than the real system — falsify that claim) | hours |
> | E3 | as E2, plus: explain the prior kills (why the harness that caught the ci_ready hole and the 18,262× slip is suddenly blind *here*) | hours + a story that survives §4's precedent |
>
> **The recipe is the point:** every row is an *action sequence*, not an opinion. Appendix A of THE-BREAKDOWN is the repo-wide instantiation — nine command blocks with expected outputs and the exact denial for each.

### DB-T1 — Denial monotonicity

> **Theorem.** The denial actions are strictly nested upward through the grades: Deny(E2·M1) ⊇ Deny(E1) ∪ {machine steps}, Deny(E2·M2) ⊇ Deny(E2·M1) ∪ {induction-defeat or assumption-falsification}, Deny(E3) ⊇ Deny(E2) ∪ {explain-the-corpses}. Consequently denial cost is strictly monotone in grade, and no grade's license (LT) exceeds what its denial recipe (DT) protects.
>
> *Proof.* Each grade's definition adds an artifact on top of the previous grade's content; refuting the higher claim requires refuting everything below it that the artifact instantiates (the E2 claim contains an E1 proof — deny the proof and the artifact checks a dead theorem), plus the new step unique to the artifact. The LT/DT alignment: each license line is the strongest statement whose negation is *witnessed* by its row's recipe — by construction of the recipes above. ∎
>
> *Reading.* Monotonicity is what makes the grades *evidence* rather than decoration: paying a higher grade buys exactly a harder denial, no more (no grade licenses "cannot be wrong") and no less (no grade's denial is easier than its inferior's).

---

## 6. The two attacks that survive at the top

Grade ceilings are absolute (LT's last row). Two attacks survive even E3·M2; a claimant who pretends otherwise has inflated:

1. **The harness-semantic attack.** Show the artifact does not check what the section says it checks. This is *stronger* than a failing run: it converts the evidence into counter-evidence (the green light was shining on the wrong property). THE-BREAKDOWN's §12 defends against it by construction-in-advance: each formal harness's header states each property in English *and names the mechanism it forbids* (f_cell_core_tick.v cites opencode's `tick_go && !ci_valid` skeleton as the class Q2b excludes — the counterexample that became the regression). The defense is not immunity; it is a smaller target.
2. **The assumption-falsification attack.** M2 proofs hold *under enumerated environment assumptions*. The README's discipline — every assumption stated and each claimed weaker than the real system — makes the attack harder than the proof, but a skeptic who shows an assumption is false in production (e.g. an engine that answers in more cycles than E2's bound) has denied the claim legitimately. The discipline's honesty: the assumptions are published precisely so this attack has a published target list.

A third, honorable mention: **the checker's checker** (who audits the golden model?). The repo's answers are methodological, not final: independence (the TB's reference models are written against the spec, not the RTL — the $rtoi incident shows what happens when the reference model itself carries a bug class: iverilog's implicit real→integer *rounds*; the fix `$rtoi` is IEEE's truncation; the error was caught because the golden model's quantizer disagreed with the geometry by exactly b — a hand-computable constant), and pinned constants (the Switch Test's SHA-pinned fixture generator: claims checked against declared constants, not results files — `zero-claw-update.md` §1.3 is the exhibit).

---

## 7. Falsifier-first design and the gaps register

The method's forward-looking half: **a claim ships with its falsifier, before the check runs.**

- **The falsifier is written with the claim.** XP-1's kill condition ("if median-static wins at d = 4σ, the second-order object is dead, not downgraded — and the calculus's Theorem 5 application loses its last empirical customer") is the pattern: the threshold, the consequence, and *who loses what*, all pre-registered. A falsifier written after the data is a story; written before, it is a bet with posted stakes.
- **The gaps register is a first-class artifact.** THE-BREAKDOWN Appendix B: twelve gaps, each with its exact closing artifact and a size estimate, and the boundary rule — *nothing in the dossier rests on an unrun machine check being secretly run* (§10's `grep -ci cosim → 0` self-audit is the rule enforced on the dossier itself). The register is why "pending" is a grade rather than an embarrassment: E0 claims are legal, visible, and priced.
- **Bench reuse closes gaps.** This wave's four papers each specify their benches to assertion level (`RHO-F-FLOOR.md` §8, `DRIFT-AS-PREFILTER.md` §7, `FOLD-COVERED.md` §11): the floor bench's four assertions, the drift-equivalence cell-diff, the fold counterexample replay. They extend gap B4/B5 rather than inventing new lane overhead — the register's economics: named gaps attract cheap closures.

### DB-P3′ — The evaluator-freshness trap (cross-grade hazard)

> **Proposition (hazard register).** A claim can be honestly E2 in its evaluation environment and false in production because the *evaluation environment is informationally richer* than deployment. The canonical instance: offline/retrospective evaluation is an F = 0 audit channel; production audits at F > 0; a re-anchoring policy validated at F = 0 has been optimized against a floor of zero (`RHO-F-FLOOR.md` §7 step 7). The same shape: THE-BREAKDOWN §10's serialization freedom (the Python mirror picks one legal serialization; the RTL ring interleaves — invariant-level agreement cannot see bit-level divergence). *The discipline:* every E2 section states its envelope relative to production, not relative to the lab; a lab-only envelope is a scoped license and the CLAIM must say so.
>
> *Argument.* The two exhibits, both committed and both caught by exactly this discipline. ∎

---

## 8. Related work

- **Falsifiability** [Pop59] — the doctrine's ancestor; DB-D1 is the operational refinement (denial priced in *commands and flaws*, not conceivable observations).
- **Reproducibility practice** — the artifact-evaluation movement and command-list appendices are the field's convergence on Appendix-A-style denial kits; this method adds the grade lattice (what the reproducibility *licenses*) and the teeth requirement (E3).
- **Formal verification** — BMC/k-induction/proof-assistant stratification is standard (Sheeran–Singh–Stålmarck [SSS00] for the induction style; the sby/boolector toolchain is the repo's own). The method's contribution is not the machinery but the *license accounting*: M1 vs M2 vs M3 as claim strengths, with the M1 envelope's structural worst-case argument as a first-class proof obligation.
- **Correction ledgers** — the envelopes §0 precedent (corrections before proofs, "so the proofs are not read through the wrong lens") is, as far as the repo's record shows, the house invention this paper generalizes: *the failure history is part of the evidence surface*, not a footnote to it.

---

## 9. Self-application: this paper's grade

By its own rules: **pen-only (E1)** — the propositions are written arguments over committed artifacts; no machine executes DB-T1's nesting or the schema's validator (a `dossier-lint` script that mechanically checks each field's contract against a dossier file is the natural falsifier and is hereby registered as the gap-closing artifact for this paper). Its claims about the repo's record cite committed files and commands (Appendix A of THE-BREAKDOWN, the correction ledger, the TB list) and are therefore individually E2-checkable by re-running those citations; the *method itself* (grades improve evidence) is graded E1 with its strongest support being §4's measured history — the one place where the method's central prediction (machines correct against interest, predictions hold when conditions are met) has E3-grade artifacts behind it, because the RQH bench has corpses.

**Statement registry (this paper).** DB-D1 denial cost · DB-D2 pen grades · DB-D3 machine grades M1/M2/M3 · DB-D4 license table · DB-D5 denial table · DB-T1 denial monotonicity · DB-P1 two-sidedness · DB-P2 schema completeness · DB-P3 RQH teeth · DB-P3′ evaluator-freshness hazard · SCHEMA field contracts · 8 numbered arguments. **What this paper adds beyond THE-BREAKDOWN:** the grades formalized as licenses (LT) and denial recipes (DT) with the monotonicity theorem; the M1/M2/M3 refinement the dossier compresses; the schema's field contracts with failure modes; the RQH history argued as three distinct properties (bite, non-ceremony, load-bearing predictions); the evaluator-freshness trap as a cross-grade hazard; and the self-grade.

---

*Academic-expansion lane, 2026-08-29. The method was already running; this paper is its manual — written after the fact, on the record, by a system whose own corpses are on display in §4. Deny by running: the commands are in the dossier, the corrections are in the ledger, and this paper's falsifier is registered.*

**References.** [Pop59] K. Popper, *The Logic of Scientific Discovery*, Hutchinson, 1959 (canonical; the falsifiability doctrine). [SSS00] M. Sheeran, S. Singh, G. Stålmarck, *Checking Safety Properties Using Induction and a SAT-Solver*, FMCAD 2000 (canonical, carried from error-envelopes §6). Internal: `THE-BREAKDOWN.md` (the dossier and Appendices A–B), `error-envelopes.md` §0/§3/§7.1 (the correction ledger, RQH, the tb-envelope lane), `conjectures.md`, `zero-claw-update.md` §1.3/§4 (pinned fixtures, XP designs), `RHO-F-FLOOR.md` §7–8, `DRIFT-AS-PREFILTER.md` §7, `FOLD-COVERED.md` §11, `quilt-calculus.md` (the registry everything cites).
