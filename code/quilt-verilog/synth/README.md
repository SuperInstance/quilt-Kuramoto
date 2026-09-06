# Synthesis artifacts

Real tool output from yosys / nextpnr / icestorm. Includes failures, which is
the reason to trust the passes.

`*.run2.*` files are a **second place-and-route run of the same netlist with a
different placer seed** — not duplicates. The seed variance is itself the
evidence that these are genuine tool output rather than transcribed numbers:

| Run | LC used | Fmax |
|---|---|---|
| `report_k4b4a8e1.json` | 7575/7680 (98.6%) | 40.68 MHz |
| `report_k4b4a8e1.run2.json` | 7596/7680 (98.9%) | 44.43 MHz |

Recorded failures, kept deliberately:
- `silicon.tsv` — canonical fabric on iCE40 UP5K sg48: `PnR exit 255` (does not fit).
- `scale.tsv` — ECP5 12F at NCELL=12: `PNR_FAIL`, ~34080 cells estimated vs 24288 capacity.
- `wall_hx8k_util.txt` — full-parameter fabric: `ICESTORM_LC: 12448/7680 162%`.

The one PnR pass on the small part is `serf NCELL=1 sg48`: 3221 LUT4, 4232/5280
LC, 16.78 MHz.

Note the prose docs quote a headline run (7528/7680, 40.44 MHz) that matches
neither logged run here — a third, unlogged run.
