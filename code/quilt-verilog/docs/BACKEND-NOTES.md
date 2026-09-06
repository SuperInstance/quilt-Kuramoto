# BACKEND-NOTES — the adversarial first user's report

2026-08-29, backend lane. Mandate: playtest and debug like a user who
wants to break it. Everything below was executed, not reviewed. Numbers
are from the benches in `tools/backend/` (`bash tools/backend/run_all.sh`);
every fixed bug carries a regression check (57 checks, 0 failures at
commit time). Failures first; the survivors are undersold, not oversold.

## The tally

**23 bug classes found. 5 in RTL (2 of them silicon-semantics-grade),
14 in the Python backend, 4 in tooling. All fixed except the ones listed
under "what remains weak".** The nastiest three, in order:

1. **q_cell.v weight mux was an OR-tree over all engines** — an engine's
   `o_w` is a register that keeps its last readout forever; once any edge
   had been read, every later `view(1)` ORed the stale weights in and
   effect integration could OR stale bits into a fresh readback. Found by
   the differential cosim on its second directed program (RTL said wsum
   0x8400, model said 0x8200 — the delta was exactly the stale reads).
   Every pre-existing TB missed it because they never read one edge,
   then wsum'ed the rest. Fix: one-hot select. Regression: cosim
   directed program 7 (4 links + interleave + wsum) — it fails on the
   old mux within two ops.

2. **q_uf_loader.v dispatched the end of the section table through a
   stale `have[]` view** — the NBA that registers the last table entry
   and the `goto_data` decision fire on the same edge, so a
   single-section QUF booted "clean" WITHOUT LOADING ITS ONLY SECTION,
   and a truncated stream could reach `done` before its tail arrived:
   **a released half-image**, the exact thing quf_boot.v exists to
   prevent. Invisible to tb_quf_boot (the golden file has four
   sections; the race is masked whenever an earlier section's `have`
   bit is already committed). Fix: a registration-aware dispatch
   (`qv0..3/qminX` next-view wires; the entry being registered this
   cycle participates in the decision). Regression: boot_fuzz's
   single-section and truncated-tail case families.

3. **QUF payload corruption was invisible** — `verify` checked structure
   only; flipping ANY byte inside dials/edges/ticks verified PASS in
   60/60 sampled payload bytes (the per-byte sweep measured 100% of the
   payload region don't-care). A bit-flip in transit silently loads
   wrong dial state, warm or cold. Fix: opt-in content digest
   (`quf.sha256` KV, sha256 over name|size|data tuples in table order —
   content-only, so it survives rebuild; `create --digest`, and
   tapfabric now exports digest-bearing QUFs). The golden vector
   predates digests and stays byte-exact. **Silicon-side closure
   (this pass): `crc32` KV (§12.2)** — IEEE CRC-32 over raw payload
   bytes in table order, `create --crc32`; the RTL loader now
   bit-serially accumulates it and gates DONE on the digest (err 12,
   fail-static hold; tb_quf_boot cases 5/6). `quf.sha256` stays the
   stronger host-side anchor.

## Fuzz volumes (fixed seeds, deterministic)

- Format fuzz (`fuzz_quf.py`): 600 random valid configs through
  build→read→decode→rebuild — decode(encode(x))==x, byte-exact
  re-encode, rebuild idempotence, verify-clean: 600/600/600/600.
  21 invalid-config classes rejected loud (out-of-range dials, k=0/17,
  align 0/3/2^24/2^31, tpw=32, NaN, list/None docs, short rows...).
  Corruption sweep 240 flips across header/KV/table/payload/tail +
  ~19k truncation lengths: every response is either clean or QufError
  (72 non-QufError crash sites existed before the fix on a single
  352-byte sample); truncation that cuts declared content is always
  caught (14,976/14,976), padding-only cuts pass legitimately (4,136).
  Digest: 60/60 planted payload corruptions caught, 60/60 clean files
  pass. Align guards: 0/5 hostile aligns build bombs or divide by zero.
- Boot-boundary fuzz (`boot_fuzz.py` + `tb/tb_boot_fuzz.v`): 232
  fuzzed QUF byte streams through the real quf_boot FSM in iverilog —
  112 must-boot (dial rows + tpw + epoch latch checked bit-exact),
  107 must-fail-static (HOLD_ERR sticky, `o_rst_n` NEVER asserted —
  zero released half-images), 13 hold-waits. **0 split-brains** (Python
  accept ⟺ RTL boot, Python reject ⟹ RTL refuse, on load-bearing
  issues). Two more RTL finds came out of building this bench, below.
- Differential cosim (`cosim_cell.py` + `tb/tb_cosim_fuzz.v`): 68
  programs (8 directed corner + 60 seeded random, ladder and hyperbola
  modes), 5,491 ops, **10,982 view checkpoints bit-exact (100%
  agreement), 386 fire fanout events matched exactly** — Python v1
  model vs q_cell RTL including the PIPE_EFF retime. Before the two
  RTL fixes this bench disagreed on ~550 checkpoints (wacc) and
  produced wrong wsum on the second program it ever ran (OR-mux).

## What was broken, in full

**RTL (4 fixes; suite stayed 18/18 green after each):**

- `rtl/q_cell.v` — OR-mux (above). one-hot select now.
- `rtl/q_cell_core.v` — `wacc` was PW+1 bits; EDGES_N readouts of up
  to 0xFFFF sum past 2^17 and WRAP (0x20008-class sums read as ~0x0008
  on view(1)). Now PW+EIW+1 bits, saturation tests the whole upper
  range. Found by cosim random program 6 (saturating wsum expectations).
- `rtl/q_uf_loader.v` — zero-size known sections entered their payload
  state with `pleft==0`, which underflows (0−1 = 2^32−1) and swallows
  the rest of the file as payload bytes: E_TRUNC on a verify-clean
  file (split-brain; a `dials`-before-`ticks` cc=0 file demonstrates
  it). Zero-size sections are now skipped at table parse (empty =
  absent, matching quf.py).
- `rtl/q_uf_loader.v` — the stale-`have` dispatch race (nasty #2,
  above). Also surfaced that the loader is last-wins on duplicate
  section names, same as Python's payload dict — now flagged by
  verify instead of silently ambiguous.

**tools/quf.py (10 fixes):** CLI wrapper (FileNotFoundError,
IsADirectoryError, PermissionError, JSONDecodeError, QufError → one-line
`quf.py: error:` + exit 1, never a traceback); UTF-8 guards on KV/section
names (UnicodeDecodeError was raw); `decode_sections` bounds-checks every
unpack (struct.error was raw; a header lying about cell_count crashed
dump); `build` type-guards the doc and header (AttributeError on
list/None JSON was raw); `rebuild` validates align (ZeroDivisionError on
0; ~4 GiB allocation attempt on 2^31) and raises QufError on unencodable
KVs (AttributeError was raw); `_infer_extra`'s array-element loop tested
the list instead of the element — u32-array extras were impossible (dead
code) while pretending to be supported; verify flags tick_period≠2^tpw
without materializing 2^(garbage tpw) (Python 3.11+ int→str digit bomb —
the error message itself crashed); verify flags duplicate section names,
names >255 B (spec §7; hardware rejects E_NAME), mistyped count KVs, and
neutralizes poisoned values so downstream size math cannot TypeError;
`to_hexfile` refuses >64 KiB files (4-digit TB length field);
`quf.sha256` opt-in digest + `create --digest` (above). The 576-byte
golden vector is byte-identical throughout (selftest pins the sha).

**sim/tools/tapfabric.py (6 fixes):** warm boot was trust-everything —
`zip()` silently truncated short `tap.cellnames` (the half-loaded-room
case: patrons GONE, fabric keeps running, no error), edges naming
unloaded cells crashed KeyError, a valid edgeless QUF crashed KeyError,
missing dials crashed KeyError. `import_quf` now verifies + length-checks
everything and raises QufError before touching state — fail-static, or
nothing. `replay` opened logs in strict UTF-8 and one bad byte killed
the whole replay mid-stream, violating the module's own "the parser
never chokes" contract (now `errors="replace"`). `Cell.link` minted a
duplicate slot number after eviction (two live edges both slot 7 —
ambiguous QUF records; now the evicted slot is reused). DIAL_DEFAULTS
had drifted from the RTL POR table (HL 48 vs 64 — a 1.33× ladder decay
rate mismatch between bridge and silicon, plus KLE/RQ/RQL raw-word
drift); now raw-word parity, enforced by a regression check that parses
`rtl/q_dialfile.v` directly. Gap EMAs (the elephant's rhythm state)
silently reset on warm boot; now ride a `tap.gap` KV. The docstring no
longer claims routing/ticks are restored (they are write-only in this
bridge — the fabric model derives routing from `order`).

**Tooling (3 fixes):** `synth/rebuild_scale_tsv.py` globbed
`synth/*` relative to cwd — run from anywhere else it printed a
header-only table and exited 0 (a silent wrong answer for a build
report); now path-resolved from the script location and fails loud when
no logs exist. `tools/openmic/record_night.py` died on a raw
PermissionError for a bad `--outdir`; now a clean one-liner, rc=1.

## What took it to break (selected receipts)

- `python3 tools/quf.py dump <352-byte file with byte 20 XORed>` →
  `UnicodeDecodeError` traceback, before the guards.
- Truncate any QUF 1 byte before its last section end and `verify`
  catches it; corrupt 1 byte INTO the last section and (pre-digest)
  verify said PASS — the loader booted happily wrong.
- `tapfabric.import_quf(fab, <QUF with 2 of 4 cellnames>)` returned a
  FABRIC THAT KEPT RUNNING with 2 cells — then one crafted `speak`
  detonated a KeyError three calls later, far from the cause.
- A QUF whose table lists ONE section: pre-fix loader = boots clean,
  loads nothing (state = POR); quf.py = clean verify. Both agreed, both
  wrong.

## What remains weak (honestly)

- ~~**Hardware is digest-blind.**~~ **Closed (this pass):** the `crc32`
  KV (§12.2) is the silicon-checkable digest the loader needed — a
  trailing-shape u32 KV fits the FSM, and the loader now accumulates
  IEEE CRC-32 over payload bytes bit-serially and refuses DONE on
  mismatch (error 12; undigested files unaffected, boot-fuzz 232 cases
  still pass). `quf.sha256` remains the stronger host-side anchor;
  hardware can now catch its own corruption class. Remaining gap
  (honest): the loader covers only what it can name — a digest whose
  KV carries the WRONG value, or sha256-only files, are still
  uncheckable in silicon.
- **Python-strict vs RTL-tolerant asymmetries remain by design**:
  verify polices `kind≠0`, alignment, duplicate names, tick_period
  consistency — the loader ignores all four (forward-compat). Files
  failing ONLY those checks boot fine in RTL; documented in
  `boot_fuzz.py`'s `HW_BLIND` table.
- **tpw > 31 is now Python-rejected** (was: silently truncated).
  quf.py verify flags `tpw > 31` as a hard issue -- hardware latches
  `o_tpw` as 5 bits, so a hostile tpw=40 file would boot silicon with
  epoch tpw=8 while the file claims 40. The writer rejects tpw out of
  0..31 outright. The RTL-side tolerance (boots with `tpw&31` rather
  than fail-static) remains by design and is registered in
  `boot_fuzz.py`'s `HW_BLIND` table, whose BOOT oracle lands on
  `tpw&31` -- same asymmetry doctrine as digest/kind blindness.
  Hostile-file check: patched tpw=40 file (no tick_period KV) now
  verifies dirty with the explicit epoch-field message.
- **Hyperbola age wraps at 24 bits (AGEW)** in RTL; the Python QUF
  record carries age as u32. Diverges only after 16.7M unticked ticks
  on a wh=0 edge; cosim programs are bounded well below.
- **`quf_boot` parks in HOLD forever on an empty stream** (no first
  byte, eod ignored in HOLD): correct fail-static behavior, but a host
  that asserts eod-before-bytes never gets an error code — it just
  waits. The fuzz bench pins this as the documented contract.
- **Dial 13 (FTRACE) in a QUF dial row is dead weight**: the dialfile
  ignores writes to the probe alias by construction; boot_fuzz masks
  it to POR 0 in expectations. quf.py still stores whatever the JSON
  said.
- The suite runner (`tb/run_suite.sh`) does not invoke the backend
  battery; run `bash tools/backend/run_all.sh` beside it. Wiring it in
  was left out deliberately — that file is shared with live lanes.

## Reproduce

```
bash tools/backend/run_all.sh     # fuzz + boot fuzz + cosim + regress (~2 min)
bash tb/run_suite.sh              # RTL suite, 18/18 PASS at commit
python3 -m unittest sim.tools.test_tapfabric   # 34/34 with new defaults
```

## Second-generation pass (2026-08-29, devil-nudge)

Objection booked: a regression bench built from caught bugs only proves
those are fixed. Re-ran all three fuzzers against HEAD with NEW seed
bases at 2× discovery volume. All three fuzzer mains now take optional
seed/scale argv (pinned discovery values unchanged when omitted):

- `fuzz_quf.py 1200 0x6E276832` — 1200/1200/1200/1200 round-trip,
  14,976/14,976 truncation caught, 0 findings.
- `boot_fuzz.py 0xF00D5EED` — 235 cases (116 must-boot, 106
  fail-static, 13 hold-wait): 0 half-loads, **0 split-brains**.
- `cosim_cell.py 0x5EED5EED 120` — 128 programs, 11,105 ops,
  **22,210 view checkpoints bit-exact (100%)**, 893 fire events matched.

**Clean. The hardening claim now has second-generation evidence.**

Coverage residue noted (same nudge): tb_serfabric's QUF has 3 edges but
all-zero buckets — it proves multi-edge BOOT byte-exact, not the
multi-edge wsum readback seam where the OR-mux lived. That seam is
covered at cell level by cosim directed program 7 + the random-program
wsum checkpoints above. CLOSED (worker lane, 2026-09-03): tb_serfabric
now reads wsum back through the serialized port post-boot (asserts 0 on
both cells -- the §9 no-engine-load-port contract, bases do NOT ride in
via QUF) and again after LINKing distinct nonzero bases into cell0's two
slots and cell1's slot (asserts the slot sums 0x1234+0x0050 and 0x0100).
Driver contract learned en route: a solo host op's src must be a LIVE
node id -- the ack is addressed back to dst=src, and an ack to a
nonexistent id circulates the ring forever, starving ringport
injection. Also note the serfabric wsum block sits AFTER the mirrored
phase-2 compare on purpose: extra solo ops before it re-phase the tick
domain and break the documented cycle-lock exceptions.

## MODEL-LEDGER — the multi-model backend (amplification round)

Per Casey's amplification ("use many models for the backend, really"):
the playtest was re-run as a genuinely multi-model exercise after the
single-model pass. Every voice below answered for real; artifacts in
`tools/backend/multimodel/runs/` (JSONL with model ids and usage);
harness in `tools/backend/multimodel/`.

| Model | Role | Contribution |
|---|---|---|
| DeepSeek V4-Flash (`deepseek-chat`) | adversarial case generation | 45 invented cases over 4 rounds (incl. a directed round seeded with the session's REAL bug classes, asked for relatives/hybrids): 0 residual crash/wrong-answer finds — the hardened quf.py held. Its NUL-in-argv case is unexecutable by OS design (execve refuses; logged, not a tool bug). It DID find 2 bugs in my fuzz *harness* along the way (malformed-case guards, region-map ordering) — the generator debugged its own executor. |
| DeepSeek V4-Pro (`deepseek-reasoner`) | blind root-cause reader | Fed the three RTL mismatch evidence packs EXACTLY as first seen (no fix shown). **3/3 correct guilty side AND mechanism**: q_cell RTL + stale-o_w-OR-pollution; RTL + 17-bit wacc wrap; loader FSM + the same-edge NBA race on `have[]`. Independent confirmation of every RTL diagnosis before the fixes were shown. |
| qwen3:8b (local ollama) | independent oracle (spec-only) | 5 spec-derivation cases: 1 agreement, **4 defensible disagreements** — all spec-ambiguity class (below). |
| deepseek-r1:8b (local ollama) | independent oracle | 1 case before the runner window closed (32 s answer): **split with qwen3:8b** on the payload-integrity case — the two oracles defended opposite readings. |
| Seed-2.0-mini (DeepInfra) | adversarial UX user | WROTE the abuse script itself (leading-dash/newline/CR filenames, control-char + 20k-key JSON, stdin pipes, dirs-as-inputs, flag soup; ~30 vectors); we ran it live with stderr unredacted: **0 tracebacks**, every abuse handled. |
| GLM-5.3 (this session) | orchestration, integration, docs | Ran everything, wrote the harnesses, integrated the verdicts, this ledger. |

**3-way findings (Python vs RTL vs oracle), the class the amplification
asked for** — every one is a place where the spec underdetermines the
tool and reasonable readers diverge:

1. *Payload bit-flip, no digest.* qwen3:8b read `verify` as content
   verification → FAIL; deepseek-r1:8b read it as structural → PASS;
   the implementation (pre-fix) was PASS. Two defensible readings = the
   spec never said which. Resolved this session by making both readings
   representable: digest present → FAIL (content), absent → PASS
   (structure). qwen3's reading is the one the format needed.
2. *Trailing garbage after the last section.* Oracle: FAIL; tool+RTL:
   PASS (GGUF-style tolerance; the loader discards residue by design,
   and quf_boot's discard path is load-bearing for aligned writers).
   Still an open spec sentence — worth writing "bytes past declared
   content are don't-care" into QUF-SPEC §7.
3. *align larger than the file.* Oracle: FAIL; tool: PASS (offsets
   need alignment, not the file). Defensible either way; documented.
4. *More buckets than edge.k.* Oracle: invalid; writer: silently
   truncates to k (canonical form). The oracle's reading is arguably
   better — a loud rejection would not hide user data; noted as a
   weakness candidate (the coercion is at least deterministic and now
   pinned by the fuzz bench's canonical-form property).

**Availability honesty:** deepseek-r1:8b's runner slot was occupied by
another consumer for most of the window (single 6 GB VRAM slot, 30/70
CPU/GPU offload) — it got exactly one oracle question before the lane
closed, and that answer is the one logged. No voice was faked; the
absence is the finding.

## Fabric-level cosim pass (2026-08-31, worker lane) — §10/B6 closed small-scale

The last open gap in THE-BREAKDOWN: a shared-stimulus Python-vs-RTL diff on
the real ring (`q_fabric_top`, NCELL=2, TPW=14). Landed as
`tools/backend/cosim_fabric.py` + `tb/tb_cosim_fabric.v` (commit 3157b3d);
18/18 programs bit-exact at the pinned seed (689 egress flits), fresh-seed
second generation 30/30 (1509 flits), wired into run_all.sh [4/5].

What the harness does differently from a naive one (each was a bug first):

- **The model replays the MEASURED serialization.** The TB records each
  cell's cycle-stamped core event stream — op acceptances (ci handshake)
  and tick services (ST_TICK entries). My first cut sampled serviced-tick
  counts at GRANT time and the first random program disagreed (act 0 vs
  32): a tick serviced while an op was queued behind it orders
  tick-before-op on the ring, and grant-time sampling cannot see that.
  Event-stream replay is exact; the counts-only view is not.
- **Tick pulses MERGE mid-service** (tick_pend is a latch, not a counter):
  pulse counts would over-count decays. Serviced counts are the truth.
- **Intra-window egress order is multiset-checked**, window attribution
  exact: response-vs-fire order inside one pacing window depends on ring
  micro-timing and is deliberately not claimed.
- **Fire-fanout delivery is cross-checked**: every modeled fanout effect
  must match an accepted op on the peer's stream, or it is a FINDING
  (a lost fanout cannot pass silently).

Two model-side semantics pinned by the first disagreement, neither
reachable by the cell-level cosim or the invariant bench:

1. A link flit whose `src` is a peer CELL gets its ACK routed to that cell
   (delivered, consumed silently) — only `src==EXTID` ACKs egress.
2. `view(2)` on dial 13 reads the LIVE `q_echo_gate` trace (0xFFFF refill
   on fire, deadband-snap leak per tick), not dial storage. The cell-level
   model never read dial 13 post-fire; the fabric lane did, first try.

Residual scope (honest): NCELL=2, measured-not-universal serialization,
serdes front-end still RTL-vs-RTL only. Scale-out is future lane work.
