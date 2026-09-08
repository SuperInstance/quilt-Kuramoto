# The language-ports cluster — scouting report

Cloned (shallow, 2026-09-08) to `/tmp/claude-0/scouts/ports/<repo>`, all
`github.com/SuperInstance/<repo>`. Plus three repos pulled in because the port
repos cite them as the spec/upstream: `quilt-claude-charts` (the protocol
document), `quilt-cellular-arch` (a much larger, separate "1000-year
inheritance" doc-mountain), `quilt-mhs` (a real, single-substrate Rust
conformance suite cited by `quilt-engine-ports`). Two more were checked via
the pre-fetched mirrors at `/tmp/claude-0/qqr/quilt-quantum-research-complete/scout_data/`:
`quilt-esp32` and a duplicate `quilt-verilog`.

**Headline finding, stated up front:** the org does not have one "quilt
opcode set" ported 12+ times. It has **at least three unrelated designs that
all call themselves "the 5 opcodes,"** plus a fourth unrelated reactive-sheet
protocol, plus a fifth unrelated 8-primitive Python library, all sharing the
word "quilt." Only one of the three opcode designs has anything resembling
cross-language conformance, and what it has is **one hand-picked test vector
and one hash**, hardcoded independently into each repo's test file — not a
shared fixture, not a generator, not a differential harness, and nothing
remotely like the `exact-band` conformance stream this scout is benchmarked
against. Several repos' README badges claim conformance that the repo's own
code does not check. This is stated plainly because it is the useful finding.

## 0. The three (or four) things all called "the 5 opcodes"

| Lineage | Opcode names | Cell shape | State check | Repos |
|---|---|---|---|---|
| **A. "Vibe protocol"** (`quilt-claude-charts/QUILT_VIBE_PROTOCOL.md`) | `BIND/LINK/EFFECT/VIEW/TICK` (+optional `FORGET`) | fixed 16×`int16` Q1.15 "dials" + u64 id + neighbor list | **one** FNV-1a-64 hash of **one** fixed test cell: `0xe435d91d6d92a1d8` | `quilt-c`*, `quilt-go`, `quilt-zig`, `quilt-rust` (+`quilt-rust-vibe`), `quilt-haskell`, `quilt-lua`, `quilt-forth`, `quilt-j`, `quilt-mojo`, `quilt-cell` (JS), `quf-vhdl`*, `quilt-verilog`* (`*` = claimed, not evidenced — see §3) |
| **B. "Polyformalism VM"** (narrative, no written spec found) | `BIND/LINK/EFFECT/VIEW/TICK` as methods on a generic typed cell-graph (`Thing{name,value,links,effects}`) — models spreadsheets, TTRPGs, MUDs, neural nets as the same class | arbitrary JS/Haskell value, no canonical byte layout | **none** — no hash, no shared fixture, no cross-repo assertion of any kind | `quilt-vm-typescript`, `quilt-vm-haskell`, `quilt-esp32` (cites this family, not A) |
| **C. "QUF" hardware fabric** (`quilt-verilog/docs/QUF-SPEC.md`) | `qm_bind/qm_link/qm_effect/qm_view/qm_tick/qm_forget` — real FSM opcodes over Hebbian-weighted edges, GGUF-style binary container | dial file + edge table + routing + tick schedule, a real binary format (`QUF-SPEC.md`) | RTL testbenches (`tb/run_suite.sh`, 18/18), a Python behavioral model (`sim/`), 6 SymbiYosys formal proofs, real iCE40 place-and-route | `quilt-verilog`, `quf-vhdl` (VHDL is a much thinner echo of this — see §3) |
| **D. `quilt-compat`** (`quilt-rust/docs/quilt-compat-contract.md`) | not opcodes — a reactive-sheet **edge/ledger** contract: value/formula/sensor cells, hash-chained ledger entries | JSON edge record + SHA-256 chain hash, real tolerance table (1e-12 reference / 1e-6 to 1e-9 gates) | a genuine golden-vector harness (`compat/golden.json` + `compat/conformance_test.rs`), but **implemented in only one substrate** — no evidence any other tier (TS/Python/Go/Julia/CUDA) actually built the harness the contract asks for | `quilt-rust` only |

Lineage A is the one that matches the task's "BIND/LINK/EFFECT/VIEW/TICK/FORGET,
5+1" description most closely and is what most of the 19 assigned repos
actually implement, so §§1–4 below focus on it. Lineages B–D are called out
because three of the assigned repos (`quilt-vm-typescript`, `quilt-vm-haskell`,
`quilt-nomad`/`quilt-elf`/`quilt-cell`/`cell-runtime`) belong to none of A/C/D
at all, and conflating them would overstate what exists.

Two more names deserve a mention because they explain the "1000-year
inheritance" language elsewhere in the corpus: `quilt-cellular-arch` (a huge,
mostly-Markdown repo, "5+1+1" laws with 14 "levels" and 6 cell "lifecycle
stages" — its own `QUILT_GUIDE.md` states up front "*Written by the team. 5
LLMs fired in parallel. Hand-synthesized.*" — this is prose mythology, not an
engineering spec, and it is **not** the document any of the 19 ports actually
cite or implement against) and `quilt-mhs` (a real, disciplined,
single-substrate Rust conformance suite — C1–C13 checks, a "lying transport"
differential test — but for a hardware-control protocol that, per its own
`PORTING.md`, "has no public spec, SDK, schema, or conformance suite" from
Anthropic yet; not cross-language, not part of the 19).

## 1. The port table

Columns: **opcodes** = does the repo implement BIND/LINK/EFFECT/VIEW/TICK
(lineage A)? **tests** = what exists, and did I run it? **conformance** =
what it is actually checked against, evidenced. **grade** = A (real,
independently verified) / B (real code, plausible, not independently run
here) / C (claim exceeds what the repo's own code checks) / D (unrelated
content or scaffold only).

| port | language | opcodes (lineage) | tests | conformance to anything? | grade |
|---|---|---|---|---|---|
| `quilt-c` | C99 | **No.** `live_canon.c` (291 lines) implements NAVIGATE/CONFLUENCE/LINEAGE/GHOST/TICK over AI-Writings papers — a different 5-op set entirely. Compiles clean (`gcc -std=c99`, verified). | none for the vibe opcodes; `live_canon.c` has a `main()` demo, no test harness | README badge claims hash `0xe435d91d6d92a1d8` and "byte-exact with the rest of the polyformalism" (A); the string never appears anywhere in the actual `.c` file — **unsupported claim** | **D** |
| `quilt-go` | Go | Yes (A) — `Cell.BIND/LINK/EFFECT/VIEW`, `Fabric.TICK`, `quilt.go` | `quilt_test.go`, 7 tests. **Ran it: all 7 PASS** (`go test -v`, output captured). No `go.mod` shipped — had to run `go mod init` to test it, a sign it was never wired into CI. | Independently reproduces the shared hash `0xe435d91d6d92a1d8` in native Go code (`TestHashReferenceCell`) | **A** |
| `quilt-zig` | Zig | Yes (A) — `quilt.zig` | `test_hash.zig`, ~7 tests incl. FNV-1a known vectors. **Not run** (no `zig` toolchain in this sandbox); source correctly mirrors the protocol | Same hash test, same struct; code review only, not executed here | **B** |
| `quilt-haskell` | Haskell | Yes (A) — `Quilt.hs`, pure + State-monad `tickM` variant | `runTest.hs`; **the port's own README says the Haskell code is not actually run in CI** ("Haskell is rarely pre-installed in modern CI; the Python mirror proves the algorithm is correct") | `reference_vibe.py` (a bespoke, per-repo Python transliteration, **not shared with any other repo — see md5sums below**) is what's actually verified. **Ran it: PASS.** The Haskell source itself was reviewed, not executed. | **B-** (conformance claim rests on a Python stand-in, by the repo's own admission) |
| `quilt-lua` | Lua 5.3+ | Yes (A) — `quilt.lua`, OOP-style `Cell`/`Fabric` | `test.lua` exists, exercises hash + all 5 opcodes | Same pattern as Haskell: `reference_vibe.py` present and independently different (md5 differs from every other repo's copy). **Not run** (no Lua interpreter here). | **B** |
| `quilt-forth` | Forth (gforth) | Yes (A) — `quilt.fs`, 118 lines | **None.** No `test.fs`, no test file of any kind — only `reference_vibe.py`. This is the only vibe-line repo with zero native test file. | Same pattern, Python-only | **C** (weakest of the "real" ports — no independent verification path exists even in principle without hand-running `quilt.fs`) |
| `quilt-j` | J | Yes (A) — `quilt.ijs` | `test.ijs` (`load 'quilt.ijs' / run_test 0`) | Python mirror only, not run (no J interpreter here) | **B** |
| `quilt-mojo` | Mojo | Yes (A) — `quilt_vibe.mojo` | `test_vibe_hash.mojo` | Charter's own compatibility matrix lists Mojo as `⏳ planned`, not done, even though this repo exists; no `mojo` toolchain available to check | **C** |
| `quilt-elf` | TypeScript | **No.** Cloudflare Worker "invisible elves" — background token-budget scheduler (`ContextManager`/`ResourceTracker`/`Backlog`/`Dispatcher`/`AuditLoop`), unrelated to any opcode set. | `test/elf.test.ts` (24 assertions), `test/vibe-score.test.ts` (5) — not run (needs `npm install` + wrangler); code looks self-consistent | none — not a "quilt port" in any of the four senses above, despite the `quilt-` prefix | **D** (mislabeled for this survey, not a bad repo) |
| `quilt-vm-typescript` | TypeScript | Yes (**lineage B**, not A) — `QuiltVM` class, `bind/link/effect/view/tick` methods | `tests/test_quilt_vm.ts`, 6 tests (per README) — local-only assertions (bind-then-view, link creates reverse edge, etc.); nothing cross-language | **None whatsoever.** No hash, no golden file, no shared fixture with any sibling repo. README's compatibility matrix (`✓` for Rust/C/TS/Haskell/WASM) is asserted prose, not evidenced by any file in this repo. | **C** |
| `quilt-vm-haskell` | Haskell | Yes (lineage B) — `QuiltVM.hs`, `bind/link/effect/view/tick` in `IO` | `test/Main.hs`, 6 tests, same local-only shape as the TS sibling | Same as above — zero cross-language check | **C** |
| `quilt-engine-ports` | GDScript (Godot) + design doc | Cites lineage **A+FORGET** explicitly ("the 5+1 opcodes... BIND/LINK/EFFECT/VIEW/TICK + FORGET") and is honest about status in its own README: "BIND/LINK/VIEW/TICK are implemented; EFFECT and FORGET are law-shaped stubs... **Text files only... not yet run against a Godot binary in CI.**" Unity/Unreal sections are pure design doc, explicitly marked "Not scaffolded." | none runnable here (Godot editor required) | Points at `quilt-cellular-arch` for "five proved laws and a completeness guarantee" (myth-doc, §0) and at `quilt-mhs` for a "conformance check" precedent (real, but a different single-substrate project) | **C**, but the most self-aware repo in the set about its own limits |
| `quilt-rust` | Rust | **No** lineage-A opcodes anywhere (the earlier `BIND`/`LINK` grep hits are unrelated networking terms in `crates/quilt-wire`). This is the org's largest, most professional repo (176 files: bindings for 5 languages, ESP32 firmware, CLI/TUI/web packages) and it implements **lineage D**, the `quilt-compat` reactive-cell-ledger contract. | Has a real spec (`docs/quilt-compat-contract.md`) + golden file (`compat/golden.json`, 206 lines) + reference harness (`compat/conformance_test.rs`) with a genuine tolerance table (1e-12 ref / up to 1e-6 gate) and **5 real ops** (value read, formula eval, propagation order, edge record, ledger chain-hash) | The contract explicitly names TypeScript/Python/Go/Julia/R/C/CUDA/WASM as tiers that must "implement the five ops against `compat/golden.json` in your substrate" — **no such implementation exists in this repo or any other scouted repo.** It is a one-substrate reference implementation with an aspirational multi-tier contract document. | **B for the contract's engineering quality, D for "cross-port" conformance** — none exists yet |
| `quilt-rust-vibe` | Rust | Yes (A) — separate small repo, `src/lib.rs` (188 lines), `Fabric::bind/link/effect/view/tick` | `tests/hash_test.rs`, 6 tests. **Ran it: all 6 PASS** (`cargo test`, output captured). | Independently reproduces `0xe435d91d6d92a1d8` in native Rust | **A** |
| `quf-vhdl` | VHDL | Cites lineage A in its README (same boilerplate as `quilt-c`/`quilt-verilog` — see §3) **but its actual RTL is lineage C**: `rtl/q_cell_core.vhdl` implements `OC_BIND/OC_LINK/OC_EFFECT/OC_VIEW/OC_TICK/OC_FORGET` as an FSM over the QUF Hebbian-edge model, nothing to do with Q1.15 dials or the shared hash. Has real testbenches (`tb/tb_q_dialfile.vhdl` etc.) and `sim/run_byte_exact.sh`. | not run (no `ghdl`) | The hash `0xe435d91d6d92a1d8` never appears in any `.vhdl`/`.py`/`.sh` file in this repo — **the README's "byte-exact" badge is unsupported.** `sim/run_byte_exact.sh` checks byte-exactness of something else (the QUF file format), not the vibe hash. | **C** |
| `quilt-verilog` | Verilog + Python (`sim/`) | Same split as `quf-vhdl`: README (`README.md`) is the same vibe-lineage boilerplate with a **copy-paste bug** ("C99 (Verilog)" in its own compatibility table, verbatim from the C/VHDL template — see §3); the real content lives in `README.archived-20260830.md` and describes lineage-C QUF opcodes (`qm_bind` etc.) | By far the most substantial repo of the 19: `make test` → 18/18 RTL testbenches, `make sim` → 34/34 behavioral-Python, `make formal` → 6 SymbiYosys proofs, `make pnr` → real iCE40 place-and-route (measured LC/bitstream numbers in `synth/`), a `corpus/mutants/` mutation-testing directory, 5 competing architecture proposals cross-reviewed and scored (`docs/SCORECARD.md`) | Internal RTL↔behavioral-Python conformance for the QUF format is real and disciplined (closest thing in the whole scout to the `exact-band` methodology). **Zero connection to the vibe hash / lineage A** despite the README claiming it. Not cross-language conformance with any of the software ports (Go/Rust/etc.) — a different opcode set, different state model, different serialization. | **A for internal engineering rigor, D for the specific "12-language byte-exact" claim its own README makes** |
| `quilt-cell` | JavaScript | **No** lineage-A opcodes as such — `index.js` implements the *AI-Writings paper→dials* mapping (`cellToDials`), same 16-dial/FNV-1a machinery reused for a different domain (papers, not the fixed test cell) | `test/test.js` — reviewed in full (60 lines). Checks: FNV constant values, hash determinism (h1==h2, h1≠h3), `cellToDials` returns length 16, cosine-sim of a vector with itself ≈1, `stateHash` determinism across two independently-built fabrics, one hardcoded `formatHash` string check. | README claims "**Byte-exact** with the Python, C, Rust, Verilog, and VHDL ports" — **this is the closest match to the task's "cell state hash that agrees across five language substrates" claim, and it does not hold up**: the test file never computes a hash for a shared/known cell and compares it to a value from another language. Every assertion in `test.js` is internal-only. | **C** — this is the specific repo behind the "five substrates" rumor; see §5 |
| `quilt-nomad` | TypeScript | No — Nomad control-plane compiler built on the (unrelated, undocumented-here) "Quilt sheet" formula concept | `test/nomad-engine.test.ts`, 14 tests (count only, not run) | none relevant to opcode conformance | **D** (not a language port in the surveyed sense) |
| `cell-runtime` | Python | No — **lineage E**, a wholly separate "8 primitives" model (Z_in/Z_out/JEPA/DoubleEntry/Vibe/GC/Murmur/Graph), explicit in its own README | `tests/test_cell.py`, `tests/test_quf_bridge.py` — not run | none shared with any other repo in this survey | **D** (different project, same word) |

*Md5sums of the five `reference_vibe.py` copies (Haskell/Lua/Forth/J/Mojo
repos) are all different* — `4d31…`, `3739…`, `2370…`, `3b89…`, `50d4…` —
confirming these are **not** one shared fixture file distributed to each
port, but five independently (re-)written transliterations that happen to
agree on the one number they were told to reproduce.

## 2. Is there a spec?

**Yes, for lineage A — and it is honest about being minimal.**
`quilt-claude-charts/QUILT_VIBE_PROTOCOL.md` and `.../QUILT_CHARTER.md` are
real, concrete documents: fixed opcode signatures, an exact byte layout
(`type(1) || id(8 LE) || dials(32 LE) || neighbors(8*N LE)`), FNV-1a-64 with
named constants, and one worked example. But the protocol document says so
itself, in so many words:

> *"The vibe-coder's mantra: I do not write a Quilt. I write a hash
> function. If the hash is right, the Quilt is right."*
> — `quilt-claude-charts/QUILT_VIBE_PROTOCOL.md`

> *"The hash is the type system. The hash is the runtime check. The hash is
> the only truth that survives portability."*
> — `quilt-claude-charts/QUILT_CHARTER.md`

The protocol's own "harness" (a paste-into-any-Claude-session prompt) asks
for exactly **one** test vector to be reproduced, explicitly to keep porting
"5–30 minutes." That is the entire verification bar for admission to the
"12+ languages, byte-exact" claim repeated across every README.

**No, for lineage B** (`quilt-vm-typescript`/`quilt-vm-haskell`/`quilt-esp32`).
No spec document was found anywhere in the org for this family — each repo's
README independently narrates the same five words with the same table
structure (evidence of a shared prompt template, not a shared written spec),
but there is no canonical byte layout, no reference hash, nothing a second
implementation could check itself against beyond "does it also have methods
named bind/link/effect/view/tick."

**Yes, and it is the best-written spec in the whole scout, for lineage D**
(`quilt-rust/docs/quilt-compat-contract.md`) — versioned, has a real
tolerance table modeled explicitly on this org's own polyformal-kernel
precedent, states its canonicalization rules precisely enough to catch a
real bug (documents finding `85.0` serializing as `"85"` and fixing it), and
names per-tier conformance classes for 8 substrates. Its weakness is not
rigor, it's **adoption**: nothing outside `quilt-rust` implements it.

**"Spec" vs. "each one its own interpretation":** lineage A is "one spec, N
interpretations, one shared checkpoint." Lineage B is "N independent
interpretations of a shared metaphor, zero shared checkpoints." Lineage C
(QUF/Verilog) is its own self-contained, well-specified world
(`docs/QUF-SPEC.md`) that borrowed lineage A's marketing language (the
badges) without borrowing its actual test vector.

## 3. Is there existing cross-port conformance? (Including: the "state hash across five language substrates" claim)

**The claim is real but far narrower than advertised, and I can locate its
exact scope.** The task's brief mentions "a cell state hash that agrees
across five language substrates" — that is `0xe435d91d6d92a1d8`, the FNV-1a
hash of one fixed test cell (`id=1, dials=[1..16], neighbors=[2,3,4]`),
defined in `quilt-claude-charts/QUILT_VIBE_PROTOCOL.md` and
`QUILT_CHARTER.md`, and repeated as a badge in nearly every lineage-A repo's
README.

What I could independently verify by running the code myself:

| Substrate | How verified | Result |
|---|---|---|
| Python | `python3 quilt-haskell/reference_vibe.py` (and equivalent in 4 other repos) | **PASS**, `0xe435d91d6d92a1d8` |
| Go | `go test -v` in `quilt-go` (after `go mod init` — none was shipped) | **PASS**, 7/7, hash matches |
| Rust | `cargo test` in `quilt-rust-vibe` | **PASS**, 6/6, hash matches |

What exists as source but I could not execute here (no `zig`/`lua`/`ghc`/`j`/`mojo`
toolchain in this sandbox): Zig (`quilt-zig/test_hash.zig`), Lua
(`quilt-lua/quilt.lua`+`test.lua`), Haskell (`quilt-haskell/Quilt.hs` — and
note the repo's own README says this code is *not* run in its own CI;
Haskell "conformance" today rests entirely on the bundled Python mirror),
J (`quilt-j/quilt.ijs`), Mojo (`quilt-mojo/quilt_vibe.mojo` — and the
charter itself still lists Mojo as `⏳ planned`, contradicting the repo's own
"ref" claim).

What is **claimed but false or unverifiable from the repos themselves**:
- **C** (`quilt-c`): the badge and comparison table claim the hash; the
  actual repo (`live_canon.c`) implements a different tool entirely and the
  hash string appears nowhere in it.
- **Verilog / VHDL** (`quilt-verilog`, `quf-vhdl`): same badge, same claim;
  `grep -rn "e435d91d6d92a1d8"` over every `.v`/`.vhdl`/`.py`/`.sh` file in
  both repos returns **zero matches**. Both repos' real RTL implements a
  different, unrelated opcode set (QUF/Hebbian fabric, lineage C).
- **JavaScript** (`quilt-cell`): README says "Byte-exact with the Python, C,
  Rust, Verilog, and VHDL ports" — the literal sentence closest to the
  task's "five language substrates" tip-off. `test/test.js` (read in full)
  never performs that comparison; every assertion is internal-only.

There is also no **shared fixture file**: `vectors.json`/`golden.json` in the
`exact-band` sense do not exist for lineage A. The one test vector lives as
prose (a markdown code block) in two files in `quilt-claude-charts`, and each
port's test file hardcodes the expected constant independently. Two visible
symptoms of that: (1) the five `reference_vibe.py` copies are five different
files (different md5s, §1), not one file distributed and reused; (2) three
READMEs (`quilt-c`, `quf-vhdl`, `quilt-verilog`) contain the **identical**
comparison table with a **copy-paste substitution bug** — each table's
second row reads `"C99 (VHDL)"` or `"C99 (Verilog)"` instead of the port's
own language, i.e. the badge/table block was generated once from a C
template and had only the top-level language name substituted, not the
table body. That is direct, textual evidence that the "12+ languages,
byte-exact" claim was produced as a templated marketing pass, not as N
independent verifications.

**Net answer:** yes, there is *something* — a single fixed hash,
independently and correctly reproduced by at least 3 language substrates I
could run myself (Python, Go, Rust) and plausibly by 2 more I could read but
not run (Zig, Lua/J source looks correct). That is real cross-language
agreement, on one data point. It is not a conformance *suite* by any
definition this org's own `exact-band` work uses: no golden-vector file, no
random differential stream, no internal-state check, and (for at least 3 of
the ~10 repos claiming it) no supporting evidence in the repo at all.

**`quilt-compat` (lineage D)** has the opposite problem: a real golden file
and harness (`quilt-rust/compat/golden.json`, `conformance_test.rs`) with a
genuine tolerance table — but it is unimplemented outside the one Rust repo
that defines it. Zero cross-port conformance exists for it today, by
construction (there is only one port).

## 4. THE OPPORTUNITY

**What already exists to build on:**
- A genuinely portable, deliberately tiny target: 5–6 opcodes, a fixed
  41-byte-per-cell binary layout, FNV-1a-64 — small enough that a real
  golden-vector suite (hundreds of cases, not one) is a same-day build in
  any of these languages.
- Real, working native code in at least Go, Rust (×2), Zig, Haskell, Lua,
  Forth, J, Mojo, JS (9-10 languages with *some* implementation of lineage
  A's opcodes on disk right now), plus a completely different but far more
  rigorously verified hardware implementation (Verilog/VHDL, lineage C) that
  could plausibly be re-targeted or run in parallel.
- A worked example of what "real" looks like *in this same org*:
  `quilt-rust/docs/quilt-compat-contract.md` + `compat/golden.json` +
  `compat/conformance_test.rs` is a well-designed single-substrate harness
  (versioned contract, explicit tolerance table, a documented bug the
  contract itself caught) that is simply missing the other 7 tiers it names.
  It is a template for exactly the deliverable this scout is evaluating,
  already written, already proven to work for one substrate.
- `quilt-verilog`'s `make test`/`make sim`/`make formal` pipeline and its
  `corpus/mutants/` directory show this org's engineers already know how to
  build mutation-tested, multi-lane conformance (RTL vs. Python behavioral
  model) when they choose to — it's just aimed at a different, single-family
  problem (QUF), not at cross-language agreement of the software ports.

**What is missing, concretely:**
1. **A shared fixture file.** Today the "golden vector" is a markdown code
   block, copy-pasted into ~10 independent test files with independently
   varying transliterations. The single highest-leverage first step is
   exactly what `build/check-substrates.sh` does for `exact-band`: one
   generator, one committed `vectors.json`, and a CI check that every port's
   copy is byte-identical to a fresh run of the generator (`emit_vectors`
   equivalent). None of that exists for lineage A today.
2. **More than one test case.** One hash covers one input. `exact-band`'s
   801 hand-picked vectors plus a million-iteration PRNG conformance stream
   is what actually finds divergent rounding/shift/overflow behavior between
   substrates — the exact class of bug lineage A's single static vector is
   structurally unable to catch (e.g., dial overflow/clamping at ±32768,
   TICK direction state persisted across restarts, LINK on a
   not-yet-BIND'd id, multi-cell fabrics, EFFECT ordering when two cells
   are both source and neighbor). None of the 19 repos test any of this
   cross-language.
3. **A real CI wiring, not a README badge.** Several claims (C, Verilog,
   VHDL, the JS "byte-exact" line) are simply false on inspection of the
   claiming repo's own code. A conformance suite that runs and gates merges
   — the way `check-substrates.sh` does for four substrates today — would
   both fix and prevent this class of overclaim.
4. **Toolchain reality.** Several of the "byte-exact ✓" languages in the
   charter table (Zig, Mojo, VHDL, Verilog-as-lineage-A) could not even be
   executed in this survey's sandbox and, per the charter's own
   compatibility matrix, some (Mojo) are still marked "planned" by the
   org's own bookkeeping despite a repo existing. A real program would need
   to first establish which toolchains are actually runnable in CI before
   claiming conformance for them.
5. **Resolve or separate the three "5 opcodes."** Before any conformance
   claim across "12+ languages" is meaningful, the org needs to either (a)
   converge lineages A/B/C on one opcode semantics, or (b) stop describing
   them as the same thing. Right now a reader of the READMEs alone would
   reasonably believe `quilt-vm-typescript` and `quilt-go` implement the
   same "quilt" — they do not share a byte layout, a hash, or even an
   agreed meaning for EFFECT (undo-with-inverse in B; propagate-dial-0 in A).

**Effort estimate for a genuine v1** (targeting lineage A, the closest thing
to a real cross-language substrate already): build a `vectors.json` +
generator in the reference tier (Python or Rust), migrate 3–4 best-maintained
ports onto reading it (below), add a PRNG conformance stream analogous to
`exact-band`'s (the opcode set is simpler than tolerance-band arithmetic, so
the stream design is more, not less, tractable) — **on the order of the
effort already spent building `exact-band`'s own harness, i.e. days, not
weeks, per substrate**, once the shared fixture format is fixed. The reason
it hasn't happened is not difficulty; the vibe protocol was deliberately
designed to make *portability* fast (5–30 min/port) at the cost of never
building *conformance depth* — a different, and much cheaper, thing to
optimize for.

## 5. Which 3 ports are the best first targets

Ranked by: does it actually run, does it actually and independently
reproduce the one real shared data point, is the code substantial enough to
extend into a real vector suite without a rewrite.

1. **`quilt-rust-vibe`** — real Rust crate, clean `Fabric`/`Cell` API
   (188 LOC), 6/6 tests independently verified passing in this session,
   idiomatic and easy to extend with a `#[test]`-per-vector loop reading a
   JSON fixture. Best target for **being the reference tier** the way
   `exact-band`'s Rust crate is: fastest to iterate, and this org already
   has the muscle memory (`quilt-rust`'s `compat/conformance_test.rs` is a
   template for exactly this pattern, sitting in a sibling repo).
2. **`quilt-go`** — real, idiomatic, 7/7 tests independently verified
   passing. Only gap found was a missing `go.mod` (one-line fix). Second
   substrate for a differential harness; Go's stdlib JSON makes fixture
   loading trivial.
3. **`quilt-zig` or `quilt-verilog`, situationally.** `quilt-zig`'s source
   (`test_hash.zig`, `quilt.zig`) is well-written and includes independent
   FNV-1a known-answer tests beyond the single shared vector — a good sign
   of care — but could not be executed in this sandbox, so it is a
   "probably-A, confirm before relying on it" pick. Alternatively, if the
   goal is to showcase something no other org has, **`quilt-verilog`** is
   the standout: it already has a real multi-lane conformance pipeline
   (RTL/formal/behavioral-Python/synthesis) and mutation-tested corpus —
   but it would need to be **retargeted onto lineage A's opcode/hash
   semantics** (it currently implements a different, unrelated opcode set)
   before it could join the same suite as the other two. Recommend `zig`
   first (lower-risk, same lineage, just needs a toolchain check) and treat
   `quilt-verilog`'s harness *design*, not its opcode set, as the model for
   the conformance stream once lineage A has 3+ working substrates.

**Explicitly not recommended as early targets, and why:** `quilt-c` and
`quf-vhdl`/`quilt-verilog`-as-lineage-A (claims unsupported by their own
code — would need to be built from scratch under the same name, which is
confusing); `quilt-haskell`/`quilt-lua`/`quilt-forth`/`quilt-j`/`quilt-mojo`
(all plausible but blocked on toolchain availability, and Forth has no
native test file to build on at all); `quilt-vm-typescript`/`quilt-vm-haskell`
(real code, but a different, unhashed lineage — joining them to lineage A's
suite means redesigning them, not just wiring them in).
