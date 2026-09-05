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

## Verification claims vs. committed evidence

Worth flagging plainly. The prose docs
(`code/quilt-verilog/docs/FORMAL-PROOFS.md`, and the repo README) headline
**"6/6 PASS"**. The only raw, machine-generated verification artifact in the
archive — `code/quilt-verilog/formal/AUDIT-SNAPSHOT.json`, a deterministic dump of
solver workdir results — records this instead:

| Verdict | Depth | Proof |
|---|---|---|
| PASS | 79 | `cell_core.tick` |
| PASS | 24 | `echo_gate.dyadic` |
| PASS | 54 | `fabric.conservation` |
| PASS | 39 | `flit_pipe.fly` |
| **INCOMPLETE** | 85 | `cell_core.fair` |
| **INCOMPLETE** | 55 | `fabric.conservation.prove` |
| **INCOMPLETE** | 55 | `fabric.conservation.prove-l12` |
| **INCOMPLETE** | 55 | `fabric.conservation.prove-t1` |
| **UNKNOWN** | 8 | `fabric.conservation.probe` |
| **UNKNOWN** | 6 | `fabric.conservation.probe-t1` |

That is **4 PASS, 3 INCOMPLETE, 2 UNKNOWN** (plus one more probe). The docs
describe later, deeper runs reaching PASS ("Depth-130 PASS … 2h29m54s wall"),
which is plausible and internally consistent — but no artifact committed here
evidences it. Treat "6/6 PASS" as unverified within this archive.

The docs are otherwise notably candid: `FORMAL-PROOFS.md` carries a dated
*"Correction note (2026-08-30)"* walking back a mislabeled assertion, and
documents a k-induction failure that PDR later closed.
