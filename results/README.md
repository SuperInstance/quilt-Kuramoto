# Measured results

Genuine tool and experiment output, kept separate from the prose that cites it.

## `benchmarks/`
`h4_results.json` and `results_v1/v2/v3.json` back `research/quantum-bridge`
documents 16 and 17. These are **simulation** outputs, not hardware measurements.
`results_v3.json` records the scaling exponents that refuted the polylog
hypothesis (ring/random-mean α ≈ 0.065, graph-weighted α ≈ 0.004).

## `reflex-arc/`
Acceptance evidence for the ESP32 reflex-arc limb: `vectors.jsonl` (80 real bars,
480 channel readings), `ref.jsonl` (desktop reference verdicts),
`dissent-ledger-host.jsonl` (per-channel divergences), and `findings.json`
(reported 100% agreement, 480/480 and 80/80).

## Elsewhere
- FPGA synthesis measurements stayed with their repo:
  `code/quilt-verilog/synth/` — `scale.tsv`, `silicon.tsv`, `sweep.tsv`,
  `wall_hx8k_util.txt`, the nextpnr logs and reports. These include honest
  failures (`PNR_FAIL`, `PnR exit 255`, 162% utilisation).
- Formal verification verdicts: `code/quilt-verilog/formal/AUDIT-SNAPSHOT.json`.
  See `docs/MISSING.md` — it does not match the "6/6 PASS" prose.
