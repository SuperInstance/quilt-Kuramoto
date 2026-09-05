# Removed files (128)

Every deletion is recoverable: `git show 0aa675c:<path>`. Nothing unique was removed.

## 1. Failed downloads saved as content (34 + 24 = 58)

**34 files containing only the 14 bytes `404: Not Found`** — see [MISSING.md](MISSING.md) for what they should have been.

**24 JSON files containing only a GitHub API rate-limit error** (~278 bytes each):
```
ai-writings-tree.json
following_p1.json
philosophy-listing.json
quilt-agent.json
quilt-bathy.json
quilt-cell.json
quilt-cowboy.json
quilt-cuda-tree.json
quilt-cuda.json
quilt-esp32.json
quilt-foundation.json
quilt-live.json
quilt-llvm-tree.json
quilt-mesh.json
quilt-picker.json
quilt-polyformalism-dsl-tree.json
quilt-polyformalism-dsl.json
quilt-substrate-meta-tree.json
quilt-tui.json
quilt-verilog-tree.json
quilt-vm-c.json
quilt-wiki-2126-tree.json
starred_p1.json
tree-master.json
```

## 2. Aborted browser downloads (22)

`Unconfirmed NNNNNN.crdownload` files. Each was verified byte-identical to a
file already present (20 Python/ini sources) or was itself a 404 stub (2).

## 3. Byte-identical duplicates (48)

The harvest fetched many files twice — once under `docs/FOO.md` and once under
the path-flattened alias `docs_FOO.md` — producing ` (1)` suffixed collisions.
One copy of each was kept. Verified identical by md5 before deletion:

- Source: `critic_gate`, `eileen_limb`, `nmea`, `nmea_limb`, `qm_opcodes`, `qm_serve`, `qm_tables`, `tower_oil_pressure_port`, `tower_port`, `twin_config`, `twin_snap`, `oil_pressure_main`, `oil-pressure-port.cell.yaml`
- Docs: `SYNTHESIS`, `SYNTHESIS-FPGA`, `SYNTHESIS-RESULTS`, `FPGA-BOOT`, `FORMAL-PROOFS`, `THE-TICK`, `RECON`, `ORGAN-MAP`, `BACKEND-NOTES`, `DOCTRINE`, `QUILT-CUDA`, `MILESTONE-2026-08-26`, `README.master`, `00_INDEX`, `08_GLOSSARY`
- Figures: `fig3`, `fig6`, `fig7`, `fig8`, `fig9` ` (1).png` copies
- Papers: `paper-130 (1)`, `paper-181 (1)`, `paper-185 (1)`
- Corpus meta: `ai-writings-collection-main/-master`, `ai-writings-readme-main`

## What was deliberately NOT removed

- **`paper-219 (1).md`** — the `(1)` copy was the *only* copy. Renamed to `paper-219.md`.
- **The five `main*.c` files** — different programs, not duplicates. Separated by lane.
- **`DOCTRINE.md` / `GLOSSARY.md` pairs** — different documents from different repos.
- **Near-identical synthesis logs** (`pnr_k4b4a8e1.log` / `(1).log`, `report_k4b4a8e1.json` / `(1).json`, `stat_fabric2_k4b4a8e1.txt` / `(1).txt`) — genuinely different tool runs with different placer seeds. Kept as seed-variance evidence.
