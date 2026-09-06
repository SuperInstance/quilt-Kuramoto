# Known gaps — what the upload did not capture

Two failure modes ran during the harvest: HTTP 404s saved as 14-byte files, and
GitHub API rate-limit errors saved as ~278-byte JSON. Both were saved as if they
were content. The affected filenames are listed here because **the existence of
the upstream document is itself information**, even though the content is gone.

## Documents that 404'd (content never captured)

These upstream files exist but were not retrieved. Several are load-bearing:

**quilt-verilog `docs/`** — `DESIGN.md`, `CONSERVATION.md`, `FOUNDATIONS.md`,
`NC_TORUS.md`, `PENROSE.md`, `SPECTRAL.md`, `POLYFORMALISM.md`,
`POLYFORMALISM_MANIFESTO.md`, `MANIFESTO.md`, `README.md`, `THESIS.md`, `FORMAL.md`

**quilt-esp32 `docs/`** — `DOCTRINE.md`, `FORMAL.md`, `INDEX.md`,
`VERIFICATION.md`, `MILESTONE-2026-08-26.md`

**Other** — `tests/test_quilt_id.py` (so `quilt-id` has no test coverage here)

Notably, **no `POLYFORMALISM.md` survives anywhere** — the central concept must be
reconstructed from `repo-readmes/quilt-polyformalism-dsl.md` and
`code/quilt-verilog/docs/INTRO.md`. Some names above survive elsewhere: real
`MATHEMATICS.md` and `INTRO.md` were captured under their `docs_` aliases and are
in `code/quilt-verilog/docs/`.

## Source files referenced but absent

- `code/quilt-cuda/src/quilt_graph.cu` — the README lists it as a deliverable
  (*"cudaGraph construction from a cell-graph edge list"*); only the `.cuh` header
  arrived. **Do not fabricate it.**
- `formal/fabric.conservation.sby` and `formal/flit_pipe.fly.sby` — the two
  harnesses that `AUDIT-SNAPSHOT.json` records as PASS are the two whose source
  did not arrive.
- `formal/g3-kinduction/` — the k-induction certificate directory.
- `formal/audit_snapshot.py` — only its output survived.
- The entire `tb/` testbench suite (`tb_cell_core.v`, `tb_fabric_smoke.v`,
  `tb_hebb_edge.v`, `tb_link_ringport.v`, `tb_wedge_repro.v`, `run_suite.sh`) —
  so the Makefile's `test` target cannot run.
- `gate-bands.json` — the input `qm_gate2c.py` needs; only its compiled output
  (`gate_qm.h`) is here.
- `tools/tower/emith.py` and `verify.py` — the generator for the oil-pressure cell.

**Consequence: nothing in `code/` builds as-is.** This archive is for reading.

## Verification status — a correction

**An earlier version of this file claimed upstream's docs overstate the formal
verification. That was wrong, and the correction matters.**

`quilt-verilog`'s README headlines "6/6 PASS" and then discloses the whole
situation in the same sentence:

> **6/6 PASS** — 5 BMC + 1 k-induction (last full run 2026-08-29, at then-depths
> tick 80 / fair 80; ⚠ audit r13 2026-09-03: depths since raised to 105/130 and
> no completed run at the new fair depth is on record — committed snapshot
> 6e59409 shows fair INCOMPLETE@85, and the r13 re-run exceeded 18 min of solver
> time at step 87)

The "6/6" is scoped to the depths it was run at, the raise is named, the absence
of a completed run at the new depth is stated, and the snapshot's
`INCOMPLETE@85` is quoted by the docs themselves. That is unusually candid, not
an overstatement.

The committed `formal/AUDIT-SNAPSHOT.json` reads:

| Verdict | Depth | Proof |
|---|---|---|
| PASS | 79 | `cell_core.tick` |
| PASS | 24 | `echo_gate.dyadic` |
| PASS | 54 | `fabric.conservation` |
| PASS | 39 | `flit_pipe.fly` |
| INCOMPLETE | 85 | `cell_core.fair` |
| INCOMPLETE | 55 | `fabric.conservation.prove` |
| INCOMPLETE | 55 | `fabric.conservation.prove-l12` |
| INCOMPLETE | 55 | `fabric.conservation.prove-t1` |
| UNKNOWN | 8 | `fabric.conservation.probe` |
| UNKNOWN | 6 | `fabric.conservation.probe-t1` |

4 PASS / 4 INCOMPLETE / 2 UNKNOWN — exactly what the README's caveat describes.

The only remaining note is mild housekeeping: the snapshot predates the depth
raise, so regenerating it via the `formal-audit` target would let artifact and
headline agree without a reader having to reconcile them.
