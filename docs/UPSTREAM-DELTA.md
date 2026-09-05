# Upstream delta — is this harvest obsolete, or different?

**Answer: neither. It is byte-identical and incomplete.**

Verified 2026-09-05 by cloning each live repo and diffing file-by-file. Not
inferred from timestamps — actually diffed.

## The measurement

| Unit in `code/` | Files here | Files upstream | Identical | Differ | Unique here |
|---|---|---|---|---|---|
| `quilt-verilog` | 96 | **1018** | 96 | 0 | **0** |
| `quilt-substrate-meta` | 13 | 53 | 13 | 0 | **0** |
| `quilt-foundation` | 13 | 18 | 13 | 0 | **0** |
| `quilt-wiki-2126` | 24 | 81 | 24 | 0 | **0** |
| `quilt-cuda` | 8 | 14 | 8 | 0 | **0** |
| `nmea-quilt-cell` | 7 | 10 | 7 | 0 | **0** |
| `quilt-vm-c` | 3 | 8 | 1 | 2¹ | **0** |
| `quilt-id` | 1 | 2 | 1 | 0 | **0** |

¹ `quilt_vm.c` / `.h` differ **only** by a 3-line vendoring header naming the
pinned commit. Below that header the bytes are identical — it is an annotated
vendor copy, not a fork.

**Across every unit checked, not one file is unique to this archive.** The
harvest of `quilt-verilog` is 9% of the real repository, byte-for-byte.

## What that settles

- **Not obsolete.** No file here is an older version of anything. Nothing has
  drifted. There is no merge to do and no "which one is right" question.
- **Not a variant.** Nothing here is a parameter choice or an alternative
  application that would justify a separate repo under a different name. The
  question was worth asking; the answer is that this particular material
  doesn't raise it.
- **Creating repos from this content would be strictly destructive.** Each new
  repo would be a 9%-complete byte-identical copy of a live one. The org already
  carries two `recovered-copy-20260824-*` repos showing what that costs.

## What upstream has that this harvest never captured

`quilt-verilog` alone:

| Directory | Files | What it is |
|---|---|---|
| `hostile-consumer/` | 353 | Adversarial review of the design |
| `spikes/` | 283 | Exploratory experiments |
| `tb/` | 63 | The testbench suite |
| `tools/` | 56 | Incl. `tower/emith.py`, the YAML→C cell generator |
| `corpus/` | 26 | — |
| `proposals/` | 17 | Design proposals |
| `sim/` | 9 | — |
| `formal/` | 38 (vs 13 here) | Incl. proofs for `q_whistle` and `q_snaplog` |

## Two open items from `MISSING.md`, now resolved

- **`quilt_graph.cu`** — I reported it missing. It exists upstream at
  `quilt-cuda/src/quilt_graph.cu`. It was simply never harvested. Not a gap in
  the project.
- **`q_whistle.v` / `q_snaplog.v`** — I called them unwired sketch modules.
  Upstream carries formal proofs for both (`whistle.attack.sby`,
  `whistle.honest.sby`, `snaplog.integrity.sby`, `snaplog.counters.prove.sby`).
  They are proven, just not instantiated in the fabric top. My read was wrong.

## One finding that still stands, and is upstream's problem too

The `6/6 PASS` claim in `docs/FORMAL-PROOFS.md` is **not** supported by the
committed audit artifact — and the upstream `formal/AUDIT-SNAPSHOT.json` is
byte-identical to the one here, still reading:

**4 PASS · 4 INCOMPLETE · 2 UNKNOWN**

`cell_core.fair` sits at INCOMPLETE depth 85; all three
`fabric.conservation.prove*` variants at INCOMPLETE depth 55; two probes UNKNOWN.
This is the one substantive thing this archive surfaced that is worth sending
upstream — as an issue against `quilt-verilog`, not as a new repo.

## Correction to my own reorganisation

Two files were misfiled by me and corrected against upstream:
- `DEPENDENCY-GRAPH.md` → belongs to `quilt-verilog/docs/academic/`, not `quilt-substrate-meta`.
- The 22 `wiki-2126` documents → belong to `quilt-wiki-2126`, not `quilt-foundation`.
