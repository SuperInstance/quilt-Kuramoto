# Auditing `quilt-quantum-research-complete`

The package's own summary lists **three results that survive its cross-critique**,
after eight phases and four independent judges (quantum, hardware, complexity,
distributed systems). This is what happened when each was executed rather than
read.

| # | claim | verdict |
|---|---|---|
| 3 | measured **11.8× learning-rate advantage** (H4) | **does not survive** — the harness disabled one arm |
| 2 | **formally verified FPGA fabric**, 6 SymbiYosys proofs | **holds up** — the source is scrupulous; the package compresses it |
| 1 | **machine-checked conservation invariant**, 844,223 checks | **not checkable from the package** — the cited file is not in it |
| — | H2 sample complexity (α ≈ 0.1–0.2), already called weak | **reproduces faithfully** |

One killed, one verified, one uncheckable, one confirmed. The pattern that
matters is not "the package overclaims" — mostly it does not. It is that
**nobody ran the code.**

---

## 3. The 11.8× does not survive

Full write-up and runnable proof in [`h4-recheck/`](h4-recheck/README.md).

The event trigger was computed on sensor noise alone (`actual = predicted +
noise`, so `|actual − predicted|` is pure noise). At the headline threshold,
**zero events fired in 4,000 agent-episodes** — measured, against an analytic
P(event) of 3×10⁻²¹. The arm that "learned slower" never learned at all, and also
lost neighbour communication. The reported 0.33 "plateau" is the initialisation
residual, 0.3332 analytically.

`diagnose.py` reproduces five defects as assertions against the original code.
`fair.py` runs the corrected experiment: **the conclusion inverts** — measured per
sensor read, which is the only metric event-triggered control is designed for,
event-triggered needs 2.05× *fewer* reads.

## 2. The FPGA proofs hold up

I could not re-run them — no Yosys/SymbiYosys in this container — so this is a
documentary audit, and it began by pointing the wrong way.

`formal/AUDIT-SNAPSHOT.json` shows no entry for any of the three `mode prove`
(unbounded) configurations, every recorded conservation `prove` run INCOMPLETE
with only a base case, and two induction steps FAILED with counterexample traces.
Read alone, that looks damning.

**It isn't, and I nearly reported it as though it were.** The snapshot's newest
entry is 2026-08-30 15:11 UTC; `cell_core.tick.prove` PASSed on 2026-09-03 and
the g3 k-induction certificate on 2026-09-02. The snapshot is *stale*, not
contradictory. A failing k-induction step at depth 6 is also not a counterexample
to the property — it means no inductive invariant was found at that `k`, which is
exactly why PDR was brought in afterwards.

`docs/FORMAL-PROOFS.md` is, on inspection, unusually careful:

- it separates BMC from k-induction and spells out what a bounded PASS does and
  does not mean;
- it states outright: *"Unbounded liveness is **not claimed** anywhere in this
  suite"*;
- it marks which runs were not re-run and cites older timings as "context, not
  claim";
- it records the PDR closure in full (25.9 s, frame 9, 6184 learned clauses) and
  then **dumps the invariant** — 854 clauses over 169 latches, committed readable
  — rather than resting on the engine's word;
- it flags its own gaps: "no PDR run log" for the g3 path, solver timeouts on the
  in-flight fairness run.

The package's compression — "formally verified… proven correct" — drops the
BMC-versus-unbounded distinction the source is careful to maintain. That is a
real loss of precision, but the underlying work is sound and the caveats exist
upstream. **This leg survives.**

## 1. The conservation invariant is not checkable from the package

The 844,223 exact-arithmetic checks come from `tools/verifies/floor_bench.py`.
**That file is not in the package.** The scouts mirrored the documents that cite
the number, not the bench that produces it, so nothing here can confirm or refute
it.

The source is again more careful than the summary. `RHO-F-FLOOR.md` grades itself
**"pen + machine-checked (bounded)"**, says "Bounded enumerators; bounds printed
per run", and notes that the δ_min measurement arm "remains pen". The theorems
are pen-proved; what is machine-checked is a bounded instance class. The
package's README renders this as "A machine-checked conservation invariant
(844,223 exact-arithmetic checks)", dropping both "bounded" and the pen/machine
split.

Not a refutation — an unverifiable citation, plus compression in the same
direction as #2.

## H2: the shadow bench reproduces

`scripts/quilt_shadow_bench_v3.py` runs clean in 90 s and reproduces the reported
scaling. Committed at [`h4-recheck/shadow-bench/reproduction_v3.json`](h4-recheck/shadow-bench/reproduction_v3.json).

| topology | best α | topology | best α |
|---|---|---|---|
| ring | 0.065 | star | 0.230 |
| line | 0.111 | ER(p=0.1) | 0.235 |
| complete | 0.121 | WS(k=4,β=0.3) | 0.097 |

α ≈ 0.065–0.235 against the package's reported ≈ 0.1–0.2. It reproduces, and the
package's own reading of it — weak, closer to linear than polylog — is correct.

Two details the package does not draw out. The best method is plain
**`random_mean`** on three of six topologies, so the naive baseline beats the
graph-aware methods more often than not. And **`jepa` has α ≈ 0 everywhere**
(−0.011 to 0.024) — no scaling behaviour at all — while `kriging` goes *negative*
on ER and WS (−1.556, −0.650), meaning error grows with N.

---

## What this audit is actually about

Four expert judges reviewed H4 and none ran it. One `print` of the event counter
shows a hard zero.

The failure is not incompetence or dishonesty — the upstream documents are, if
anything, *more* careful than the summary built on them. The failure is that a
review process built on reading conclusions and checking reasoning cannot see a
harness that silently disabled an arm. Only execution can.

That is the argument for how the rest of this directory is built:
[`divergence/`](divergence/README.md) asserts a negative control on its own
contrast, so a study with no signal fails instead of reassuring;
[`CONFORMANCE-STREAM.md`](CONFORMANCE-STREAM.md) records which verification layer
catches which planted mutation, so nobody has to trust that the layers work.

And it cuts both ways. My first read of `AUDIT-SNAPSHOT.json` pointed at a much
larger finding than the evidence supported, and checking the timestamps killed
it. A method that only ever confirms suspicions is not a method.
