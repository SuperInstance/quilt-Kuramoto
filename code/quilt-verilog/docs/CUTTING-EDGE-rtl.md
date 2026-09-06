# CUTTING-EDGE: LLM-era RTL generation & open HDL verification (2024–2026)

**Date:** 2026-08-29 · **Lane:** research sweep for the competition lanes' prompts/workflow and the verification bar · **Full paper:** `ai-writings/research/66`

**Headline:** the two things the outside world proved since we started — (1) tool-feedback loops (compile → simulate → feed errors back) are worth ~25% correctness on top of any model, and (2) a free, vendor-less **formal** flow on our exact stack is real. We ran it. `q_flit_pipe` now carries a machine-checked k-induction proof of its FIFO contract (basecase + induction PASS, <1 s, `tb/formal/`). Verified or it doesn't exist — now with proofs, not just testbenches.

---

## Adopt now

1. **Formal sanity proofs via SymbiYosys on the oss-cad-suite we already ship** (`~/tools/oss-cad-suite/bin`: yosys 0.47, sby, boolector/yices/z3/bitwuzla). `mode prove` = BMC basecase + k-induction. Demo committed: `tb/formal/flit_pipe.sby` proves `q_flit_pipe` is indistinguishable from an ideal 2-deep FIFO — no drop, no dup, no over-accept, correct backpressure (`m_valid == occ≠0`, `s_ready == occ<2`). Cost: seconds. **Every ring/pipe/queue module gets a `.sby` before it gets merged. This is the new bar for "verified."**
2. **Interface-contract properties, not internal-state peeks.** Yosys `read -formal` silently turns `dut.internal_sig` into an undriven implicit wire — a free variable, i.e. a soundness hole (it bit us mid-demo). Prove at the boundary with a shadow model. This matches the Law: modules are cells; cells have contracts.
3. **Wrap-loud shadow counters over wide conservation counters.** A 2-bit occupancy reg that wraps to 3 on any imbalance catches drops *and* dups and stays inductive; 8-bit `in/out` counters are not inductive (k-induction starts from arbitrary states and the wrap escapes the lemma). Small models, loud failure.
4. **Reset-aware formal contracts.** Our reset drops in-flight content by design — the proof counterexample showed conservation invariants must restart with the DUT (zero the shadow on `!rst_n`, gate asserts on `rst_n`, force a reset preamble via `assume(!rst_n)` while a small counter runs). Reset is a contract-violation boundary; say so in every harness.
5. **Tool-feedback in every generation lane (AutoChip pattern, +24.2% measured).** Lane prompts already demand iverilog-clean; extend to: first CI action = `iverilog -g2005` compile, second = TB run, **third = `sby` proof where a contract exists**; feed all three outputs back into the agent's next revision. AutoChip (arXiv 2311.04887) proved compiler/testbench error text in the loop beats prompt heroics.
6. **Self-simulation in prompts (HDLCoRe pattern).** Before emitting RTL, the lane walks the module cycle-by-cycle in prose ("step the FSM by hand") and checks it against the TB's golden vectors. Training-free, our models can do it today; HDLCoRe (2503.16528) shows it cuts hallucinations on RTLLM 2.0.
7. **Repo-context in every prompt (RTL-Repo lesson).** Models crater without file context; every lane prompt must inline the module's neighbors (ports it drives, cells it sits between), not just the target spec. RTL-Repo (2405.17378) exists because module-in-a-vacuum is the dominant failure mode.

## Adopt later (cheap to flip on, no urgency)

- **Equivalence flow `equiv_make`/`equiv_induct`** golden behavioral model vs synthesizable RTL per module — same yosys we proved with; worth it when a module has a behavioral reference worth trusting (the TB golden models are half-way there already).
- **Verilator lint escalation** — we run `-Wall` clean on `rtl/`; add `--lint-only -Wno-DECLFILENAME` style CI pinning and treat UNOPTFLAT as merge-blocking (the ring's ready-chain loop was exactly this; skid form fixed it, formal now proves the fix).
- **cocotb 2.x** (suite ships 2.0.0.dev) for statistical/property-fuzz TBs in Python — violates nothing (TBs are excepted from purity), but plain-Verilog TBs are doing the job; revisit when we want randomized fabric soak with scoreboard automation.
- **MCTS/evolutionary re-rolls (EvoVerilog/RTLFixer pattern)** for lanes that keep failing: population of N candidate fixes, TB pass-rate as fitness. Our competition already IS this with humans as the selector; automate the inner loop only when a lane stalls twice.
- **Tiny-Tapeout-style fully-open CI tapeout** (yosys+openroad, multi-foundry: IHP SG13G2 / sky130 / GF180 shuttles all live post-Efabless) — the day the quilt wants silicon, the path exists with zero vendor lock; not this quarter.

## Reject (and why)

- **Fine-tuned RTL models (RTLCoder/CodeV weights) as lane brains.** Their wins are data-pipeline wins (27k auto-generated problems, quality scoring, multi-level summarization); we rent frontier models through APIs and our bottleneck is feedback discipline, not model Verilog priors. Revisit only if a lane must run offline/cheap at scale.
- **SystemVerilog assertions / surelog / sv2v in `rtl/`.** Law 1 says pure Verilog-2005; `assert` in *formal harnesses only* (`tb/formal/`, `read -formal`) already gives us SVA's safety subset without breaking purity of shipped RTL.
- **CARAVEL as a harness.** The pattern is right (fixed IO ring, user area, CI from RTL to GDS) but the artifact is sky130-locked; our equivalent is `q_io_port` + `qm_view` on any foundry's flow. Copy the discipline, not the dependency.
- **NVDLA-style maximal-parameterization.** Its lesson is negative: generality that heavy rots unowned. We parameterize timing (`REG_SLICE_EVERY`), not semantics.
- **ChipNeMo-scale domain adaptation.** 43B params + continued pretraining to answer bug-report questions — orthogonal to writing a quilt. The transferable piece (RAG over our own docs/specs in lane prompts) we already do by inlining context.

## What the lanes' prompts steal, concretely

| Steal | Source | One-line prompt clause |
|---|---|---|
| Tool feedback loop | AutoChip | "Revise until compile, TB, and — if `tb/formal/` exists — `sby -f` all pass; paste the failing output in your revision notes." |
| Self-simulation | HDLCoRe | "Step your FSM cycle-by-cycle against the TB golden vectors in the reply before finalizing." |
| Repo context | RTL-Repo | "You are given the neighbor modules' port lists; violations of their contracts are bugs." |
| Failure taxonomy | VerilogEval v2 | "Known failure modes: FSM mis-sequencing, blocking/non-blocking misuse, width mismatch, reset semantics — state which you checked." |
| Contract properties | this demo | "Every queue/pipe ships an `.sby` proving its interface contract; occupancy models must be wrap-loud and reset-aware." |

## Proof-of-concept record (2026-08-29)

- `tb/formal/flit_pipe.sby` — `mode prove`, depth 15, `smtbmc boolector` → **PASS** (basecase + induction).
- Properties C1–C4 as in `tb/formal/f_flit_pipe.v`; covers confirm full occupancy and drain are reachable (proof isn't vacuous).
- Three real traps found and fixed on the way (implicit-wire XMRs, init-free reset preamble, non-inductive wide counters) — all documented above so no lane rediscovers them.

Primary sources: VerilogEval v1 2309.07544, v2 2408.11053 · RTLCoder 2312.08617 · AutoChip 2311.04887 · ChipNeMo 2311.00176 · ChipGPT 2305.14019 · HDLCoRe 2503.16528 · CodeV 2407.10424 · RTL-Repo 2405.17378 · EvoVerilog 2508.13156.
