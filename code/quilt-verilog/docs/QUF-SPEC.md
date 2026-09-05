# QUF — QUilt Format, v1

**QUF is the GGUF of cellular silicon.** llama.cpp won because weights are
just a file; QUF is the same bet for the fabric: a flat, binary,
little-endian container that holds the complete state of a quilt — dials,
edges (with Hebbian walk counts), routing, and the tick schedule. One file
loads into simulation (testbench), a soft core, or a real FPGA, identically
(DOCTRINE item 3). Where GGUF carries *tensors*, QUF carries *cell state*.

| GGUF notion            | QUF counterpart                                  |
|------------------------|--------------------------------------------------|
| magic `GGUF`           | magic `'Q','U','F',0x00` (bytes `51 55 46 00`)   |
| little-endian scalars  | same                                             |
| header KV metadata     | same encoding, GGUF value-type numbering         |
| aligned tensor sections| aligned state sections: dials/edges/routing/ticks|
| `general.*` keys       | `quf.version`, `quant.*` keys                    |
| unknown KV → skip      | same rule                                        |

Reference implementation: `tools/quf.py` (stdlib only).
Synthesizable consumer: `rtl/q_uf_loader.v` (§9, loader profile).

## 1. Conformance

- **Full spec** — `tools/quf.py`: parses and emits everything below,
  verifies structure, restores all state including edge walk counts.
- **RTL loader profile** — `rtl/q_uf_loader.v`: streaming parse of the
  subset a v1 cell needs (§9). Unknown metadata is *skipped*, never
  fatal — the extensibility rule is load-bearing.

## 2. File map

```
+-----------------------------+  offset 0
| magic          4 bytes      |  'Q','U','F',0x00
| version        u32          |  = 1
| endian         u32          |  = 1 (little); big-endian QUF is undefined
| kv_count       u32          |  number of header KV pairs
+-----------------------------+
| kv_count × KV pair          |  §4
+-----------------------------+
| section_count  u32          |
| section_count × entry       |  §5 (name, kind, offset u64, size u64)
+-----------------------------+  end of table
| zero padding to `align`     |
| section payloads            |  §6, at the offsets named in the table
| zero padding between/after  |  file padded to `align` at EOF
+-----------------------------+
```

All multi-byte integers are **little-endian**. Offsets are absolute from
byte 0 of the file.

## 3. Fixed header (16 bytes)

| field     | size | value                                            |
|-----------|------|--------------------------------------------------|
| magic     | 4    | `51 55 46 00`                                    |
| version   | u32  | 1 (this document)                                |
| endian    | u32  | 1 = little-endian. No other value is defined.    |
| kv_count  | u32  | number of KV pairs that follow                   |

## 4. Header KV metadata

Each pair:

```
u32 name_len, name_len × UTF-8 bytes, u32 value_type, value bytes
```

Value types use **GGUF's numbering** so tooling intuition transfers:

| id | type   | size                  |
|----|--------|-----------------------|
| 0  | u8     | 1                     |
| 1  | i8     | 1                     |
| 2  | u16    | 2                     |
| 3  | i16    | 2                     |
| 4  | u32    | 4                     |
| 5  | i32    | 4                     |
| 6  | f32    | 4                     |
| 7  | bool   | 1                     |
| 8  | string | u32 len + len bytes   |
| 9  | array  | u32 elem_type, u32 count, count × elements |
| 10 | u64    | 8                     |
| 11 | i64    | 8                     |
| 12 | f64    | 8                     |

Array element types must be fixed-size (no nested strings/arrays).

**Standard keys** (writers emit them in this order; `*` = required when
the related section is present):

| key             | type   | meaning                                        |
|-----------------|--------|------------------------------------------------|
| `quf.version`   | string | producer identification                        |
| `cell_count`*   | u32    | number of cells the file describes             |
| `edge_count`    | u32    | number of edge records (= rows in `edges`)     |
| `route_count`   | u32    | number of routing records                      |
| `edge.k`        | u32    | ladder buckets per edge record, 1..16, default 8 |
| `tick_period`   | u32    | ticks per scheduler period (2^tpw), semantic  |
| `quant.dials`   | string | Q-format of dial words, e.g. `Q1.15`           |
| `quant.edges`   | string | Q-format of edge base weights                  |
| `quant.routing` | string | numeric format of routing fields               |
| `align`         | u32    | section alignment, power of two ≥ 8, default 32|

The reference writer derives `cell_count`/`edge_count`/`route_count` from
the payloads when omitted, and computes `tick_period` from the ticks
section. f32/f64 exist in the type space for numbering compatibility; the
reference writer **refuses to emit them** (doctrine: quantized-by-default,
no floats in fleet state).

## 5. Section table

`u32 section_count`, then per section:

```
u32 name_len, name_len × UTF-8 name, u32 kind, u64 offset, u64 size
```

Rules:

- `kind = 0` is the standard raw-bytes kind; other kinds are skipped by
  readers that do not understand them.
- `offset` is absolute from file start and **must be a multiple of
  `align`**.
- Table entries must be **strictly ascending by offset**, and sections
  must **not overlap** and must **not extend past end of file**. Padding
  between the table and the first section, between sections, and after
  the last section is zero bytes.
- Duplicate section names are a verification failure.
- Unknown section names: skip via the table (extensibility rule).
- The reference writer pads the whole file to `align`, so the byte stream
  is always an integral number of 16-bit words (what the RTL loader eats).

## 5a. Invalid files (hostile-input semantics)

What a reader MUST do when the file lies about itself. Every rule is
reject-or-skip with a machine-readable reason code, extending the E1–E6
family of `QUF-FORGETTING-V1.md` §4.2 (E1–E6 remain reserved for epoch/
custody failures; E7+ below are container-level failures). "Reject" means
fail the whole file before any state is restored — partial-restore on an
invalid file is forbidden (a hostile file must never get half its payload
written into a fabric). Findings cited as F# are from
`HOSTILE-CONSUMER-REPORT.md` (d3dfa08). Compatibility law: **none of these
rules may change behavior on any valid file** — every rule fires only on
bytes a conformant writer never emits (R5's one nuance and R10's
loosening are called out below).

**Check order** (readers report the first failure in this sequence):
(1) header scalars — R1, R2, R8's `edge.k` range; (2) structural walk
bounds — R3/R4 as the KV/table walk proceeds, framing before per-entry
field validation; (3) per-section fields — R5, R6, R7, R9; (4) padding —
R11; (5) KV value lengths — R12. R18 (value types) fires when the walk
first meets the bad type, inside phase 2.

### Rules

1. **R1 — Magic and version gate (F1).** `magic != 'QUF\0'` → reject,
   `E7`. `version != 1` → reject, `E8` (§8 rule 6 already mandates this;
   the code makes it machine-checkable). This restates §3 as an explicit
   reject-with-code; F1 itself was an ecosystem finding, not an open
   spec defect (the referee-side magic gate is separate from this
   document).
2. **R2 — Endian word is profile-wide (F10).** `endian != 1` → reject,
   `E9`. §9 error 4 already binds the RTL profile; this rule promotes it
   to the full profile so two legal consumers cannot disagree. Endian is
   detected, never negotiated (§7).
3. **R3 — Truncation of framing (F6).** If the byte stream ends before
   the 16-byte fixed header, before the KV walk reaches the
   `section_count` word, before the table walk completes its
   `section_count` entries, or before any section's `offset+size` →
   reject, `E10`. §5's "must not extend past end of file" covered
   payloads only; this rule closes the framing regions. (Count-driven
   overruns of the same regions belong to R4, not R3.)
4. **R4 — Counts that lie (F7).** `kv_count` or `section_count` whose
   entries walk past end of file, or any `name_len` that does → reject,
   `E11`. The section table must additionally end at or before the
   smallest section-payload offset and at or before EOF — a table that
   runs into payload space is lying about its count, `E11`. Bounded
   readers may pre-check `kv_count ≤ (file_size−16)/9` (min KV pair:
   4+0+4+1) and `section_count ≤ file_size/24` (min entry: 4+0+4+8+8)
   before walking (§9 error 3 is the RTL shadow of this).
5. **R5 — u64 high words and the 4 GiB ceiling (F4).** Any nonzero high
   u32 word of a section `offset` or `size` → reject, `E12`; likewise
   `offset+size ≥ 2^32` (sum overflow with clean high words, e.g.
   `offset=0xFFFF0000, size=0x20000`). §9's limit (error 7) is promoted
   to format law on the authority of DOCTRINE item 3 — one file loads
   identically into sim, soft core, and FPGA; a >4 GiB file cannot.
   Base §2/§5 never bounded the u64s (that dispute *is* F4); this rule
   resolves it. No known artifact approaches the bound.
6. **R6 — Payload must not overlap the front matter (F11).** Every
   section `offset` must be ≥ end of the section table (before alignment
   padding). A payload pointing into the header/KV/table → reject,
   `E13`. §5 forbade section-vs-section overlap only; this closes the
   point-`dials`-at-offset-32 attack (offset 32 is `align`-clean, so R9
   cannot catch it — R6 is the load-bearing rule).
7. **R7 — Known-section size formulas, zero-length (F9).** A known v1
   section's `size` must equal its §6 formula given the header counts
   (`dials`: `cell_count×32`, `edges`: `edge_count×(12+K)`, `routing`:
   `route_count×2`, `ticks`: `4+4×cell_count`). Size 0 is legal only
   when the corresponding count is 0. Violation → reject, `E14`. When a
   count KV is absent (§4 permits omission), the known sections must
   agree with each other on the derived count (`dials`↔`ticks` on
   `cell_count`, etc.); disagreement → `E14`.
8. **R8 — Present counts are assertions (F5); `edge.k` range.** A
   present-and-wrong `cell_count`/`edge_count`/`route_count` → reject,
   `E14` (one failure class with R7: declared size/count ≠ payload).
   Writers MAY omit counts (derivation, §4); once present, they are
   assertions, not hints. `edge.k` outside 1..16 → reject, `E8`.
9. **R9 — Alignment and file length (F3).** File length not a multiple
   of `align`, or any section `offset` not a multiple of `align` →
   reject, `E15`. §5 said only what the reference writer does; this
   makes unpadded EOF a detectable lie (576→575 truncation now dies
   with `E15`, not luck).
10. **R10 — Names are bytes, not text (F8).** KV and section names are
    length-counted opaque bytes. A reader MUST NOT reject on invalid
    UTF-8 content (skip size is fully determinate from `name_len`);
    name comparison is byte equality. This is the sole *loosening* rule:
    it can only widen acceptance relative to base §4/§5.
11. **R11 — Padding is zero, everywhere — §8 rule 5 REPEALED (F2).**
    Every padding byte (between table and first section, between
    sections, after the last section to EOF) MUST be 0x00. A nonzero
    byte in any padding run → reject, `E16`. This resolves the §5-vs-§8.5
    contradiction explicitly: **§5's zero-padding law wins; §8 rule 5
    ("bytes after the last section … are ignored") is repealed by name**
    and replaced by this rule. Rationale: "ignored" trailing bytes are an
    unauthenticated side channel — a file may not carry bytes the format
    disclaims. No version bump: repealing a tolerance is not a change to
    the meaning or encoding of any section/KV or the fixed header
    (§8 rule 6). Consequential note: QUF-FORGETTING-V1 §2.4 cites the
    ignore-rule as one rationale for rejecting the whole-file seal; that
    citation is superseded — §2.4's conclusion still stands on its other
    grounds (padding mutability, canonicalization cost).
12. **R12 — Unbounded KV value lengths (F12).** A KV string `len` or
    array `count` whose value would extend past end of file, or overflow
    any size arithmetic → reject, `E17`. Skip-size derivability (§8
    rule 1) presumes the length is honest; R12 makes dishonesty fatal.
13. **R18 — Unskippable value types (base §8 rule 2, given a code).**
    An undefined KV value type id, or an array element type that is not
    fixed-size → reject, `E18` (RTL error 6 already binds the loader
    profile; this is the container-level twin).

Pre-existing §5 verification failures (duplicate section names,
non-ascending offsets, section-vs-section overlap) retain their §5
status; assigning them codes is out of scope for this F1–F12 amendment.

### Reason-code table

| code | failure                                     | action            |
|------|---------------------------------------------|-------------------|
| E7   | bad magic (R1)                              | reject file       |
| E8   | bad version; bad scalar range — `edge.k` (R1, R8) | reject file |
| E9   | bad endian word (R2)                        | reject file       |
| E10  | truncation of framing/payload (R3)          | reject file       |
| E11  | lying count or name_len; table into payload (R4) | reject file |
| E12  | nonzero u64 high word; sum ≥ 2^32 (R5)      | reject file       |
| E13  | payload overlaps front matter (R6)          | reject file       |
| E14  | declared size/count ≠ payload (R7, R8)      | reject file       |
| E15  | misaligned offset / unpadded EOF (R9)       | reject file       |
| E16  | nonzero padding byte (R11)                  | reject file       |
| E17  | KV value length overrun (R12)               | reject file       |
| E18  | unknown value type / bad array elem type (R18) | reject file    |

RTL loader mapping: E7→1, E8(bad version)→2, E8(`edge.k` range)→9,
E9→4, E10/E11/E13→3, E12(high word)→7, E12(sum overflow)→3, E18→6
(§9 codes unchanged; no new hardware). E14–E17 are full-spec-profile
(`tools/quf.py`) obligations only — the v1 RTL loader derives counts
and never checks padding; closing that gap is future RTL work, booked,
not claimed here.

### Regression list — mutants that must flip to rejected-with-code

From `hostile-consumer/fuzz.py` (seed `tb/run/quf_tb_input.quf`), these
were determinate-by-luck and now MUST be rejected with the stated code
(on-disk names are decimal; `4294967295` = `0xFFFFFFFF`):

- `truncate-8`, `truncate-16`, `truncate-100`, `truncate-300`,
  `truncate-543` (cuts last section) → E10 (R3/R4 fire before R9 per
  check order)
- `truncate-575` (unpadded EOF) → E15
- `kvcount-lie-11` → E18 (the fake 11th pair's value type is undefined
  before any bound is crossed on this seed)
- `section-count-5` → E11 (table runs into payload space, R4's second
  clause); `section-count-1000`, `section-count-4294967295` → E11
- `endian-zero`, `endian-two`, `version-nonce-ff` (byte 9 is inside the
  endian word — the fuzz case name is wrong, the mutation is an endian
  corruption) → E9
- `zero-size-dials`, `zero-size-edges`, `zero-size-routing`,
  `zero-size-ticks` → E14 (formula check fires before R11's padding
  check per order)
- `bad-magic` → E7; `version-nibble-hi`, `version-nibble-lo` → E8
- `edgek-0`, `edgek-17`, `edgek-4294967295` → E8
- `kv-vtype-13`, `kv-vtype-99`, `kv-array-of-strings` → E18
- (not yet generated, required:) padding byte flip after last section →
  E16; section-0 `offset` → 32 (F11) → E13; KV string len =
  0xFFFFFFFF (F12) → E17; `cell_count`=3 with 2-cell dials (F5) → E14.

### Compatibility

R1–R9 and R11–R18 fire only on bytes a §4/§5-conformant writer never
emits: zero padding, aligned offsets, honest counts, u32-sized sections,
multiple-of-`align` EOF are writer invariants already — so consumers
predating §5a accept a strict superset of §5a-valid files for those
rules. Two honest exceptions: **R5** narrows the never-exercised,
profile-disputed u64 allowance (base §2/§5 never bounded it — that
dispute was F4 itself); **R10** loosens (invalid-UTF-8 names become
tolerated, not rejectable). Golden vector §11 (sha256 `5b2a236b…`)
parses clean under §5a.

### Out of scope, noted (hash observability)

The silicon lane booked an UNADJUDICATED hash-observability failure
(0eb231b: distinct seeds, identical state hash). §5a itself needs no
state hashing — it seals nothing. But if QUF-FORGETTING-V1 epoch
verification is ever routed through fabric-side state hashing (the §5
KHASH organ proposal), that failure becomes a **dependency of the
verify-then-skip rule** (FORGETTING §4: an unverifiable seal must fail
closed E3 — a hash that collides across distinct states silently
downgrades fail-closed to fail-confused). Flagged, not fixed here.

### Provenance

Drafted against d3dfa08 (F1–F12); codes extend the E1–E6 family of
a83c5be §4.2. Coder passes: `claude -p` (Sonnet — 11 findings: R8 code
self-contradiction, E8→9 mapping split, R3/R4 code overlap, superset
overclaim, R5 DOCTRINE grounding + sum-overflow mapping, no-version-bump
justification + §2.4 staleness flag, R7 absent-count rule, E14–E17 RTL
gap honesty, F1 framing, KV-region wording, §5 pre-existing failures
scope) and `opencode run --auto` (10 findings: E18 missing +
`kvcount-lie-11` first-failure correction, `section-count-5` bound fix,
check-order clause, `version-nonce-ff` endian-byte catch, R12 wording,
compat softening, mapping nits, decimal mutant names, min-entry sizes).
All folded. Gatekeeper (bullshit-test only): DeepInfra was the
mandated lane but the account's user-set billing limit rejected the call
(`inference prohibited` — booked, not retried against policy); fallback
wide model GLM-5.3 via Z.ai, docs inlined, thinking disabled. Verbatim
final line: **"VERDICT: PASS (no bullshit)"** — the pass independently
re-derived the golden-vector byte layout (table end 379, ticks ends 556)
and confirmed every regression entry fires under the stated check order,
including the `section-count-5` → E11 and `kvcount-lie-11` → E18
corrections.

## 6. Sections (v1)

### 6.1 `dials` — per-cell dial register file image

Flat image of the `q_dialfile`: `cell_count` rows × 16 `u16` words
(row = one cell, word = one dial, index = dial address 0..15), row-major,
little-endian. Size = `cell_count × 32` bytes. Interpretation is
saturating fixed-point, format declared by `quant.dials` (default
`Q1.15`). Values are stored **pre-saturated**; loaders never clip on the
way in. The dial map itself is defined by `q_dialfile.v` (ETA_F, ETA_S,
KF, KS, KA, THRESH, REFR, COS_MIN, P0E, MODE, HL at addresses 0..10;
11..15 reserved, still round-tripped).

### 6.2 `edges` — Hebbian edge table

`edge_count` records, each `12 + edge.k` bytes, little-endian:

| off | size | field    | notes                                    |
|-----|------|----------|------------------------------------------|
| 0   | 1    | src      | owning cell id                           |
| 1   | 1    | dst      | peer cell id                             |
| 2   | 1    | mode     | 0 = ladder, 1 = hyperbolic               |
| 3   | 1    | slot     | edge slot index within src cell          |
| 4   | 2    | base     | u16 bind-time base weight, `quant.edges` |
| 6   | 2    | wh       | u16 hyperbolic integer weight            |
| 8   | 4    | age      | u32 hyperbolic age counter (ticks)       |
| 12  | K    | buckets  | u8 × K ladder walk counts; bucket 0 = newest class |

`K = edge.k`. Size = `edge_count × (12 + K)`. Both decay engines' state
travels in every record; the active one is selected by `mode`.

### 6.3 `routing` — topology portability

`route_count` records of 2 bytes: `u8 dst, u8 via` (destination cell,
next hop toward it). For the v1 single ring `via == dst`; the section
exists so multi-ring / mesh fabrics stay file-compatible. Size =
`route_count × 2`.

### 6.4 `ticks` — tick schedule

`u32 tpw` followed by `cell_count` × `u32 phase` (per-cell phase offset
in clock cycles; v1 single-clock fabric ignores phases, they are carried
for v2 metronome cells). Size = `4 + 4 × cell_count`. `tick_period` in
the header is the semantic period `2^tpw`.

## 7. Alignment and endianness

- Little-endian everywhere; the header `endian` word exists so a
  big-endian host can detect and refuse, not to define a second encoding.
- `align` (default 32) applies to **section offsets** and to the whole
  file length. The fixed header and KV region are never moved.

## 8. Extensibility and versioning

1. **Unknown KV keys: skip.** A reader must not fail on metadata it does
   not know (skipping is safe because every value's size is derivable
   from its type).
2. **Unknown value types: reject.** An undefined type id makes the value
   un-skippable; readers must fail loudly, not guess.
3. **Unknown section names: skip** via the section table.
4. **Unknown section kinds: skip** the payload.
5. **[Repealed by §5a R11]** Bytes after the last section (within the
   final padding) are ignored — superseded: nonzero bytes after the last
   section are now a rejection (reason code E16).
6. New sections and new KV keys may be added without bumping `version`.
   Changing the meaning or encoding of an existing section/KV, or the
   fixed header, bumps `version` — readers reject other versions.

## 9. RTL loader profile (`rtl/q_uf_loader.v`)

The synthesizable consumer. What it does:

- Eats the QUF as a **word stream** on the `q_io_port` external-ingress
  handshake shape (`i_val/o_rdy/i_dat[15:0]`); bytes arrive little-endian,
  low byte of each word first.
- Parses the fixed header, **skips** every KV pair it does not need, and
  captures `edge.k` (must be u32; known key with wrong type = error).
- Walks the section table, then streams the payloads:
  - `dials`: writes the row of cell `i_mycell` into the `q_dialfile`
    write port, word for word, byte-exact.
  - `edges`: writes records with `src == i_mycell` into the edge RAM as
    32-bit words `{base[15:0], dst[7:0], mode[7:0]}` addressed by `slot`.
  - `routing`: writes `{dst, via}` nibbles into the route RAM.
  - `ticks`: captures `tpw` (bits [4:0] → the `q_tick_sched` parameter).
- Asserts `o_done` after the last byte of the last known section.

v1 profile limits, on purpose: edge walk state (`wh`, `age`, `buckets`)
is *consumed but not restored* — the v1 `q_hebb_edge` engines have no
load port; a warm-started fabric re-binds topology + dials and trains the
ladders back (full state restore is the Python path). Files must be
< 4 GiB (u64 high words must be zero), names ≤ 255 bytes, `edge.k` in
1..16.

Error codes (`o_err`, sticky, stops the load):

| code | meaning                                        |
|------|------------------------------------------------|
| 1    | bad magic                                      |
| 2    | bad version                                    |
| 3    | layout overrun (pos passed a section offset)   |
| 4    | bad endian word (≠ 1)                          |
| 5    | known KV (`edge.k`) not u32                    |
| 6    | unknown value type / bad array element type    |
| 7    | nonzero u64 high word (offset or size)         |
| 8    | KV/section name longer than 255 bytes          |
| 9    | `edge.k` out of 1..16                          |
| 12   | payload digest mismatch (`crc32`, §12.2)       |

## 10. JSON schema and CLI (`tools/quf.py`)

Input to `create` is the golden shape:

```json
{
  "header":  { "quf.version": "...", "cell_count": 2, "edge_count": 3,
               "route_count": 3, "edge.k": 8, "tick_period": 64,
               "quant.dials": "Q1.15", "quant.edges": "Q1.15",
               "quant.routing": "u8", "align": 32 },
  "dials":   [ [16 × u16], ... per cell ],
  "edges":   [ {"src":0,"dst":1,"mode":0,"slot":0,"base":4660,
                "wh":0,"age":0,"buckets":[0,0,0,0,0,0,0,0]}, ... ],
  "routing": [ {"dst":1,"via":1}, ... ],
  "ticksched": { "tpw": 6, "phases": [0, 3] }
}
```

Commands: `create IN.json OUT.quf` (also writes `OUT.hex`, a
byte-per-line hex image for `$fscanf` testbenches), `info`, `dump`,
`verify`, `hex`, `selftest`.

## 11. Golden test vector

The canonical byte-exact vector (embedded in `tools/quf.py`, asserted by
`selftest`, loaded by `tb/quf_tb.v` via `tb/quf_tb.json`): 2 cells,
3 edges, 3 routes, ticks tpw=6. 576 bytes, sha256
`5b2a236ba5e38bca9ad96783c4252a12f36517f98a9164a249f0db115f221392`.

Layout walk: fixed header 16 B → 10 KV pairs 241 B → section table
(4 + 29+29+31+29 =) 122 B → 379 → pad 5 B to 384 → `dials` @384 (64 B) →
`edges` @448 (60 B) → `routing` @512 (6 B) → `ticks` @544 (12 B) → pad to 576.

```
51554600 01000000 01000000 0a000000                        ; magic, v1, LE, 10 KVs
0b000000 7175662e76657273696f6e 08000000 0a000000 7175662e707920312e30
0a000000 63656c6c5f636f756e74     04000000 02000000
0a000000 656467655f636f756e74     04000000 03000000
0b000000 726f7574655f636f756e74   04000000 03000000
06000000 656467652e6b             04000000 08000000
0b000000 7469636b5f706572696f64   04000000 40000000
0b000000 7175616e742e6469616c73   08000000 05000000 51312e3135
0b000000 7175616e742e6564676573   08000000 05000000 51312e3135
0d000000 7175616e742e726f7574696e67 08000000 02000000 7538
05000000 616c69676e               04000000 20000000
04000000                                                       ; 4 sections
05000000 6469616c73 00000000 80010000 00000000 40000000 00000000   ; @384, 64 B
05000000 6564676573 00000000 c0010000 00000000 3c000000 00000000   ; @448, 60 B
07000000 726f7574696e67 00000000 00020000 00000000 06000000 00000000 ; @512, 6 B
05000000 7469636b73 00000000 20020000 00000000 0c000000 00000000   ; @544, 12 B
... 256 B zero padding to offset 384 ...
; dials row 0 (cell 0): 0800 0080 0006 000c 0005 5000 0004 2ccd
;                        0014 0000 0030 0000 0000 0000 0000 0000
; dials row 1 (cell 1): 0800 0080 0006 000c 0005 6000 0004 2ccd
;                        0014 0001 0040 0000 0000 0000 0000 0000
; edges: 00 01 00 00 3412 0000 00000000 0000000000000000   ; src0→dst1 base 0x1234
;        00 02 01 01 4000 0700 e8030000 00...00              ; src0→dst2 mode1 wh7 age1000
;        01 00 00 00 0002 0300 05000000 00...00              ; src1→dst0 (other cell)
; routing: 01 01 02 02 0f 0f
; ticks: 06000000 00000000 03000000
; trailing zero padding to 576
```

## 12. Integrity digests (opt-in)

Both digests cover PAYLOAD bytes only (section data in table order);
header, KV pairs, and alignment padding are excluded. Both are plain
header KVs, so consumers that do not understand them skip them per §8.

### 12.1 `quf.sha256` (host-side)

Hex string over sha256 of the (name, size, data) triplets — see
`tools/quf.py add_digest` / `verify` (`--digest`). Python-side only;
the RTL has no sha engine. Digest KV itself shifts offsets, so it is
computed over the digested doc REBUILT without the KV.

### 12.2 `crc32` (silicon-checkable)

IEEE CRC-32 (zlib convention: init 0xFFFFFFFF, poly 0xEDB88320
reflected, final xor 0xFFFFFFFF) over the raw payload byte stream in
table order, stored as a u32 header KV. Writer: `quf.py create --crc32`
(or `hdr["crc32"] = "auto"`). Loader: `rtl/q_uf_loader.v` accumulates a
bit-serial CRC over payload-state bytes only and gates DONE on the
captured digest (error 12 on mismatch); the check runs one cycle after
the last payload byte (NBA-order) and covers ONLY containers that carry
the KV — undigested files load exactly as before.

Full hex (whitespace-insensitive):

```
5155460001000000010000000a0000000b0000007175662e76657273696f6e080000000a0000007175662e707920312e300a00000063656c6c5f636f756e7404000000020000000a000000656467655f636f756e7404000000030000000b000000726f7574655f636f756e74040000000300000006000000656467652e6b04000000080000000b0000007469636b5f706572696f6404000000400000000b0000007175616e742e6469616c73080000000500000051312e31350b0000007175616e742e6564676573080000000500000051312e31350d0000007175616e742e726f7574696e670800000002000000753805000000616c69676e040000002000000004000000050000006469616c73000000008001000000000000400000000000000005000000656467657300000000c0010000000000003c0000000000000007000000726f7574696e670000000000020000000000000600000000000000050000007469636b730000000020020000000000000c0000000000000000000000000008800006000c00050000500400cd2c140000003000000000000000000000000008800006000c00050000600400cd2c1400010040000000000000000000000000010000341200000000000000000000000000000002010140000700e80300000000000000000000010000000002030005000000000000000000000000000000010102020f0f00000000000000000000000000000000000000000000000000000600000000000000030000000000000000000000000000000000000000000000
```
