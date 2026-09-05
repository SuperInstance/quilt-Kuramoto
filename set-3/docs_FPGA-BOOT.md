# FPGA-BOOT — QUF file to cell state at reset (design stub)

2026-08-29, boot lane companion to docs/SYNTHESIS-FPGA.md. **This is the
design document, not the RTL.** It specifies the boot harness that turns
one QUF container (docs/QUF-SPEC.md) arriving over SD or serial into the
runtime state of a quilt fabric on FPGA, by wrapping the module that
already exists and is already synthesizable: `rtl/q_uf_loader.v`.

What exists today (measured this lane on iCE40):

- `q_uf_loader` — streaming QUF parser, 1,488 LUT4 / 793 FF standalone,
  no vendor primitives. Eats the container as 16-bit words
  (`i_val/o_rdy` handshake, bytes little-endian, one word per 3 cycles
  worst case, `o_rdy` depends only on local state — the skid discipline,
  no ready-chain loops). Emits:
  - `o_dial_wr / o_dial_addr[3:0] / o_dial_wdata[15:0]` — byte-exact
    dialfile row image (§9 loader profile, QUF-SPEC)
  - `o_edge_wr / o_edge_addr[3:0] / o_edge_data[31:0]` — edge slot word
    `{base[15:0], dst[7:0], mode[7:0]}`
  - `o_route_wr / o_route_dst[3:0] / o_route_via[3:0]` — route nibbles
  - `o_tick_tpw[4:0]` — tick period exponent from the ticks section
  - `o_done`, `o_err[7:0]` (sticky; codes 1–9: bad magic/version,
    overrun, endian, KV, type, u64-high, name, edge.k range)
  - `i_mycell[3:0]` — the cell whose dials row / edges this instance claims
- The fabric it boots: `q_fabric_top` (SYNTHESIS-FPGA.md §4's converged
  HX8K build is the reference target).

## 1. Boot model, one paragraph

Power-on → fabric held in `rst_n=0` (cores FSM-frozen; every register
that QUF populates — dialfile, edge tables, route table — is
synchronous and accepts writes under reset, because their write ports
are gated by write strobes, not by core state) while the loader consumes
the QUF stream and writes state through its ports. On `o_done && !o_err`
the harness releases reset; on `o_err` it stays in HOLD with reset
defaults (v1 semantics — the fabric is never booted into a half-image).
Doctrine item 3 holds at the metal: state is a file, and the file is
loaded before the first tick, so the fabric's first op after release is
against fully-specified state.

## 2. Boot FSM (`boot_top`, to be written)

```
POR ──► HOLD ──► LOAD ──► LATCH ──► RELEASE ──► RUN
          │        │(o_err≠0)                  │
          └────────┴──► HOLD_ERR (sticky; status readable, retry by POR)
```

| state | fabric rst_n | tick | loader | notes |
|---|---|---|---|---|
| POR | 0 | masked | held in reset | settle deglitch; dials at compile defaults |
| HOLD | 0 | masked | released, idle | host handshake may happen here (§5) |
| LOAD | 0 | masked | streaming | all QUF writes land under reset |
| LATCH | 0 | masked | done | tick exponent latched (§6); BOOT_OK flit composed |
| RELEASE | 0→1 | armed | quiescent | one-cycle release; tick scheduler starts from 0 |
| RUN | 1 | running | bypass | loader out of the datapath entirely |

Design rules carried over from the fabric lane: `o_rdy` of the whole boot
path is local-only (compose the loader's 1-in-3 backpressure into the
transport, never a ready chain); every state transition is a single
condition on `{o_done, o_err}` — no timeouts in v1 (the host owns
completion; a wedged stream stays in LOAD, observable, retryable by POR).

## 3. Transports (the loader neither knows nor cares)

The loader sees only `i_val/i_dat` words. Two transport shims feed it:

- **Serial (UART, the bring-up lane):** `uart_serializer` (to be
  written, ~150 LUT): 8-N-1 RX shift → pair bytes into 16-bit words,
  low byte first (the QUF reference writer already pads files to an even
  word count, QUF-SPEC §"align ≥ 8" — the shim never fabricates a pad
  byte). Handshake math: the loader eats one word per 3 cycles worst
  case; at 27 MHz fabric clock that is ≥9M words/s ≫ 115200 baud, so
  the shim is always ready and can be a pure streamer with a 2-word
  skid. At faster links (SPI, USB-CDC) the 1-in-3 backpressure must be
  honored into the transport's flow control.
- **SD/µSD (the deployment lane):** an upstream block-reader (soft core
  or dedicated FAT/shim — v1 spec: raw-block mode, QUF at fixed LBA, no
  filesystem in RTL) DMAs sectors into a 512B BRAM ring that presents
  the same word interface. This is where ice40's spare BRAM pays: the
  converged HX8K build uses 0/32 blocks; the ring costs one.

Rule: both transports present identical `i_val/i_dat/o_rdy` — the boot
FSM and loader are transport-agnostic by construction, and simulation
TBs drive the interface directly (the QUF TB already does).

## 4. Dials as iceBRAM (`dials asIceBRAM`)

Today `q_dialfile` is 16×16b of FFs + a 16:1 read mux (252 LUT4 / 257 FF
per cell, SYNTHESIS-FPGA.md §2). The boot design maps it to one
`SB_RAM40_4K` block shared across the fabric's cells:

- **Geometry:** one 4Kb block = 256 × 16b — the complete dial image of
  *16 cells* (16 rows × 16 dials), or per-cell at 16 dials each for a
  256-cell fabric. The loader's `o_dial_wr/o_dial_addr/o_dial_wdata`
  becomes the boot write port; `qm_bind` becomes the runtime write port.
- **Port discipline (the seam that must be designed, not improvised):**
  SB_RAM40_4K is dual-port with *one* write port. v1 rule: the boot port
  is strobed only in LOAD (fabric in reset — the core provably cannot
  emit `df_wr` while its FSM is frozen in reset state), so the two write
  sources are mutually exclusive by construction, not by arbitration.
  Post-RELEASE the boot port is held disabled forever (until POR).
- **Reset defaults:** BRAM initializes at bitstream load with the same
  compile-time defaults `q_dialfile` uses today (v1 defaults = the v1
  acceptance gate). A boot failure therefore yields *default dials*, not
  garbage — fail-static to the bit-exact v1 configuration.
- **Edge/route tables:** same treatment. Edge word `{base,dst,mode}` ×E
  slots fits trivially; the engine bucket arrays stay in FFs until the
  E≥16 crossover (SYNTHESIS-FPGA.md §6).
- **Why BRAM here and not in the fabric proper:** the fabric's own read
  timing is a registered handshake (`df_rd/df_rstb`) — a synchronous
  BRAM read drops in with zero timing delta; the measured fmax of the
  converged build is unaffected, and the FF/LUT budget freed (≈500 LCs
  per 2-cell fabric) is exactly the headroom the loader needs (§8).

## 5. Boot handshake (host ↔ fabric)

Commissioning sequence, spec level:

1. Host may poll **BOOT status** in HOLD/RUN: a read-only status word
   surfaced as a dedicated io_port view (`view(2)` row in the FUTURE
   space QUF-SPEC reserves) or the dedicated status flit in LATCH:
   `{state[2:0], o_err[7:0], o_done, crc16[15:0]}` — crc16 over the
   consumed stream (loader-side CRC is a v1.1 add-on; the spec reserves
   the field).
2. Host streams the QUF (words, §3). The fabric never speaks during
   LOAD — silence is progress.
3. `o_done=1, o_err=0` → LATCH → the fabric emits **BOOT_OK** through
   the io node (a status flit, op=VIEW-class, src=EXTID-addressable
   boot entity) and releases.
4. Host verifies with a probe `qm_view` of a dial whose QUF value it
   knows (acceptance rule: one view, exact match — same discipline as
   the fabric smoke test's golden check).
5. `o_err≠0` → HOLD_ERR: status word readable, no BOOT_OK, no release.
   Recovery is POR (v1: no in-band retry — a partial image must never
   run).

## 6. Tick period seam (the one honest hole)

`q_tick_sched`'s TPW is a **synthesis-time parameter**; the loader
captures `o_tick_tpw[4:0]` from the QUF ticks section. The boot harness
latches it at the LATCH→RELEASE edge into the tick period exponent
register, and the rule is **latch-once-at-release**: the tick cadence is
fixed for the run, because Q2's deadline semantics (SYNTHESIS.md Part A)
are defined against a stable epoch. Changing cadence mid-run is a spec
change, not a wiring change; v1 refuses it by construction. (The RTL
seam: `q_tick_sched` gains a runtime `i_tpw` input loaded at release, or
the harness instantiates it with `TPW=5` and compares a masked counter —
spec decision for the RTL lane, both are ≤20 LCs.)

## 7. Multi-cell boot

One QUF describes the whole fabric (dials section is per-cell rows;
edges carry src). Spec: **one loader instance per cell, all fed the same
broadcast word stream**, each pinned to its `i_mycell`:

- dials: loader `i_mycell` selects its row; other rows' bytes are
  consumed and discarded (the loader already implements exactly this
  filter — it is the §9 profile's cell-selector).
- edges: each instance claims records with `src == i_mycell`, slot-order
  preserved; the route section is fabric-global, written by cell 0's
  instance only (spec rule; avoids N-way duplicate writes).
- cost: N loaders ≈ N × 1,488 LUT — acceptable to 2 cells on the ECP5
  lane, prohibitive on HX8K (§8); the fallback spec (one loader +
  fan-out write mux) is one `boot_top` regeneration away because the
  write ports are identical.

## 8. Budget reality (measured, SYNTHESIS-FPGA.md F5)

Loader (1,488) + converged 2-cell fabric (7,400 LC) > 7,680 — **does not
fit one HX8K as-is.** Three funded paths, cheapest first:

1. **BRAM-ify the dials** (§4: −~500 LC) + the e1 engine config →
   loader rides the freed headroom; same device, same bitstream story.
2. **Soft-core host** (serv/PICorv32-class) owning load *and* serial:
   loader RTL unused on-FPGA; the soft core bit-bangs the same dialfile/
   edge write ports. Moves ~1.5k LUT cost into ~2k LUT of CPU that also
   owns the future host protocol. The pragmatic board lane.
3. **ECP5** — the full-parameter fabric needs it anyway (F1); boot
   overhead disappears into the slack.

## 9. RTL to be written (the TODO list, nothing else)

| module | size | content |
|---|---|---|
| `boot_top.v` | ~300 LC | §2 FSM + status word + tick latch |
| `uart_serializer.v` | ~150 LC | §3 serial shim |
| `q_tick_sched_rt` patch | ~20 LC | §6 latch-once period exponent |
| BRAM dialfile variant | swap-in | §4 dual-port mapping |
| SD block-reader | or soft core | §3, bring-up-lane optional |

Everything else — QUF parse, cell filtering, write-port contracts, error
taxonomy — already exists in `rtl/q_uf_loader.v` and is proven by
`tb/quf_tb.v`. The boot lane is integration, not invention.
