# Claim Audit — SuperInstance org, checkable README/docs claims

Scope: 37 repos cloned shallow to `/tmp/claude-0/scouts/audit/<repo>` and audited
against their own source. Toolchains installed live in-session (`apt-get`,
direct binary downloads) so claims could be *run*, not just read: gcc, go,
rustc/cargo, node/npm, python3/pytest, lua5.4, gforth, zig 0.13.0, ghc 9.4.7 +
cabal-install, elixir/erlang, iverilog. npm/PyPI registry lookups were made
over HTTPS to check publication claims. Every finding below cites a
file:line and states exactly what command or read produced the verdict.

Continues the prior scout's finding that `quilt-c`, `quilt-verilog`,
`quf-vhdl` carry the `0xe435d91d6d92a1d8` byte-exact badge with no matching
test, and `quilt-cell` claims byte-exactness with five ports with no
cross-language check anywhere. Both are re-confirmed here with fresh
evidence (§2), and the pattern is shown to be far more widespread — and more
varied — than a single copy-pasted template.

---

## 1. Summary table

| Repo | Claims checked | Supported | Unsupported | Unverifiable-here |
|---|---|---|---|---|
| quilt-c | 1 (byte-exact badge) | 0 | 1 | 0 |
| quilt-go | 2 (byte-exact hash, 7/7 tests) | 2 | 0 | 0 |
| quilt-rust | 1 (byte-exact badge) | 0 | 1 | 0 |
| quilt-rust-vibe | 2 (byte-exact hash, 6/6 tests) | 2 | 0 | 0 |
| quilt-zig | 2 (byte-exact hash, 7/7 tests) | 2 | 0 | 0 |
| quilt-lua | 1 (byte-exact hash "verified") | 0 | 1 | 0 |
| quilt-haskell | 1 (byte-exact hash "verified") | 0 | 1 | 0 |
| quilt-j | 1 (byte-exact hash "verified") | 0 | 0 | 1 |
| quilt-forth | 1 (byte-exact hash "verified") | 0 | 1 | 0 |
| quilt-verilog | 2 (byte-exact badge, RTL claims) | 0 | 1 | 1 (RTL sim, no iverilog target hit) |
| quf-vhdl | 1 (byte-exact badge) | 0 | 1 | 0 |
| quilt-cell | 2 (byte-exact w/ 5 ports; self-test) | 1 | 1 | 0 |
| quilt-vm-c | 1 (6 tests passing) | 1 | 0 | 0 |
| quilt-vm-rust | 1 (7 tests passing) | 0 | 1 | 0 |
| quilt-vm-typescript | 1 (6 tests passing / `npm test`) | 0 | 1 | 0 |
| quilt-vm-wasm | 1 (5 unit tests / `cargo test`) | 0 | 1 | 0 |
| quilt-vm-haskell | 1 (6 tests passing) | 0 | 0 | 1 |
| quilt-esp32 | 3 (2 tests; 24 firmware checks; host-verified) | 3 | 0 | 0 |
| quilt-timesfm-rust | 2 (bit-exact w/ C/Python; 49 tests) | 2 | 0 | 0 |
| quilt-conformance | 1 (self-reported cross-VM audit numbers) | 1 (corroborated independently) | 0 | 0 |
| adinkra-math-pypi | 1 (45+ tests) | 1 | 0 | 0 |
| federated-tinyml-npm | 2 (byte-exact tag; shipped self-test) | 0 | 2 | 0 |
| cell-router-pkg | 2 (byte-exact w/ JS; `pip install`) | 1 | 1 | 0 |
| mudra-vessel-bridge-pkg | 3 (11 modules; 51 self-tests; `pip install`) | 0 | 1 | 2 (minor drift, not fabrication) |
| live-canon-npm | 2 (9 papers; byte-exact hash) | 0 | 2 | 0 |
| live-canon-pypi | 2 (9 papers; byte-exact hash) | 0 | 2 | 0 |
| quilt-live-canon-npm | 2 (9 papers; byte-exact hash) — **live on npm as `@superinstance/live-canon@0.9.1`** | 0 | 2 | 0 |
| quilt-live-canon-pypi | 2 (71 papers; byte-exact hash) | 2 | 0 | 0 |
| quilt-k3s | 1 (`npm install -g @quilt/k3s`) | 0 | 1 | 0 |
| quilt-elf | 1 (`npm install @quilt/elf`) | 0 | 1 | 0 |
| agent-priming-toolkit-pkg | 0 (no checkable install/verify claim) | — | — | — |
| tit_quilt_elixir | 1 (16/16 tests, "Verified") | 0 | 0 | 1 |
| quilt-llvm | 0 (explicitly "nothing claimed to work yet") | — | — | — |
| quilt-cellular-arch | 0 (design essay, no local checkable claim) | — | — | — |
| quilt-cuda | 0 (design essay, no local checkable claim) | — | — | — |
| bare-metal-plato | 0 (design essay, no local checkable claim) | — | — | — |
| quilt-mojo | 0 (design essay, no local checkable claim) | — | — | — |
| tit-quilt | 0 (no checkable claim found) | — | — | — |
| **Totals** | **~48** | **18** | **20** | **7** |

---

## 2. Every UNSUPPORTED claim

### 2.1 The `0xe435d91d6d92a1d8` badge family (re-confirmed + extended)

**quilt-c** — `quilt-c/README.md:8` badge `hash-0xe435d91d6d92a1d8-brightgreen`,
and `README.md:25`: *"The test cell (id=1, dials=[1..16], neighbors=[2,3,4])
produces `0xe435d91d6d92a1d8` byte-exactly."*
Check: the repo's only source file is `live_canon.c`, a **different program**
(the "Live Canon" paper-navigation demo, not the 16-dial quilt-cell model).
Compiled with `gcc -std=c99 -o /tmp/qc live_canon.c -lm` and ran it: it prints
`state hash: 0x20648cc7914cd541` for its own 3-paper demo and never
constructs or hashes a cell with id=1/dials[1..16]/neighbors[2,3,4]. There is
no code in the repo that could produce `0xe435d91d6d92a1d8`. **UNSUPPORTED —
the specific claimed test does not exist in this repo.**

**quilt-rust** — `README.md:8` (badge) and `README.md:25` (same hash-claim
sentence, verbatim template). Check: `grep -rn 0xe435d91d6d92a1d8` over the
whole repo (205 files) matches only the two README lines — no test, no
crate, computes this value. The repo is actually a large, unrelated
"spreadsheet-as-runtime" project (`packages/core`, `packages/cli`, …); its
`crates/live-canon` and `crates/federated-tinyml` implement a *different*
FNV-1a-based hash for a different data model. **UNSUPPORTED.** Also carries
the same copy-paste artefact the prior scout found, in a new flavor —
`README.md:33`: `| C99 (Rust) | ✓ | manual |` — the table row was copied from
the C99 port's README and only "(Rust)" was appended, never fixed to a real
row.

**quf-vhdl** — `README.md:8`, `:25` (badge + hash sentence, same template).
`grep -rln 0xe435d91d6d92a1d8 $(find . -iname '*.vhd*')` over all 11 VHDL
files: no match. **UNSUPPORTED**, confirms prior finding. Copy-paste artefact
at `README.md:32`: `| C99 (VHDL) | ✓ | manual |`.

**quilt-verilog** — `README.md:8`, `:25`. `grep -rln 0xe435d91d6d92a1d8`
across the entire 1047-file repo (including `tools/*.py`) returns nothing.
This repo is otherwise a large, genuinely rigorous RTL project — its
`docs/academic/*.md` files contain real machine-checked numbers (565,551
exact checks, 5,138 byte-exact round-trips, etc., for a *different*,
internal "byte-exactness" property unrelated to the polyformalism hash) —
which makes the unbacked top-line badge stand out more, not less.
**UNSUPPORTED**, confirms prior finding. Copy-paste artefact at
`README.md:32`: `| C99 (Verilog) | ✓ | manual |`.

**quilt-lua** — `README.md:3`: *"Hash `0xe435d91d6d92a1d8` verified
byte-exact."* `README.md:69-80` shows a fabricated-looking terminal
transcript ending `PASS: hash byte-exactly matches 0xe435d91d6d92a1d8`.
Check: installed `lua5.4` (`apt-get install -y lua5.4`) and ran the actual
shipped files. `lua5.4 test.lua` → `lua5.4: test.lua:19: malformed number
near '0xe435d91d6d92a1d8ULL'`. `lua5.4 quilt.lua` → `lua5.4: quilt.lua:24:
malformed number near '0xcbf29ce484222325ULL'` — the FNV-1a offset constant
itself. **`ULL` is a C/C++ integer-literal suffix; it is not valid Lua
syntax.** Neither file has ever successfully parsed in a real Lua
interpreter, let alone run. Stripping the `ULL` suffixes by hand made the
hash line pass (`0xe435d91d6d92a1d8` genuinely is what the corrected
algorithm computes — the *logic* is right) but the file then fails later, at
`quilt.lua:238`, on an opcode-behavior `assert`. **UNSUPPORTED**: the
transcript in the README was never produced by running this code.

**quilt-haskell** — `README.md:3` and the "verified byte-exactly" transcript
at `README.md:58-69`. Check: installed `ghc` 9.4.7 (`apt-get install -y
ghc`), ran `runghc runTest.hs` → `Quilt.hs:22:1: error: Could not find
module 'Data.ByteString.Little'`. `Data.ByteString.Little` **does not
exist** in the `bytestring` package (the real module for little-endian
packing is `Data.ByteString.Builder`, functions `word64LE`/`int16LE`); the
file also imports `Control.Monad.State.Strict` (`Quilt.hs:23`), which needs
the `mtl` package that isn't declared anywhere. The module has never
compiled. **UNSUPPORTED.**

**quilt-forth** — `README.md:3` and the "verified byte-exactly" transcript
at `README.md:47-58`. To its credit, the README's own "Run the test"
section (`README.md:45-58`) is careful to say to run `python3
reference_vibe.py`, not the Forth file itself — so the literal instructions
are honest about which language actually gets exercised. But the headline
sentence at line 3 still asserts the hash is "verified byte-exact" for a
Forth runtime, and the Forth source is not runnable: installed `gforth`
(`apt-get install -y gforth`), ran `gforth quilt.fs` →
`quilt.fs:75: Undefined word >>>...<<<` — the file literally contains
`... ;  \ (deferred; see below for full impl)` (`quilt.fs:75`) as a stand-in
for un-written code, not valid Forth. **UNSUPPORTED**: no Forth
implementation exists to verify against.

**quilt-cell** — `README.md:3`: *"**Byte-exact** with the Python, C, Rust,
Verilog, and VHDL ports."* and the "Self-test" section
(`README.md:19-25`): *"The test file includes a check that the state hash
for a cell matches the Python implementation's hash byte-for-byte."* Check:
ran `npm test` (genuinely passes, 7/7 checks) and read `test/test.js` in
full. The only hash-related assertion is `stateHash deterministic` — it
computes the same fabric twice **inside this same JS file** and compares
the two JS results to each other. There is no reference value, no imported
Python output, and no reference to the shared `0xe435d91d6d92a1d8` test
vector used by every language port. **UNSUPPORTED** for the byte-exact and
cross-language claims specifically; SUPPORTED for the narrower claim that
the JS library is internally self-consistent. Confirms and sharpens the
prior scout's finding with an exact quote and a passing-but-irrelevant test
run.

### 2.2 Broken test suites the README presents as green (a distinct pattern from the badge)

**quilt-vm-rust** — `README.md:6` badge `Tests-7%20passing-brightgreen`,
`README.md:22`: `cargo test  # 7 tests, all should pass`. Check: `cargo
test` → compile error. `src/lib.rs:280-283`:
```rust
let gandalf: HashMap<String, i32> = [
    ("name".to_string(), "Gandalf".to_string()),
    ("perception".to_string(), 15),
].iter().cloned().collect();
```
mixes a `String` value with an `i32` literal in an array declared to collect
into `HashMap<String, i32>` — `error[E0308]: mismatched types` /
`error[E0277]`. The crate's own test target has never successfully compiled
as committed. **UNSUPPORTED.**

**quilt-vm-wasm** — `README.md:379`: `cargo test  # Native tests (5 unit
tests + the gold demo)`. Check: `cargo test` fails before compiling any
code: `error: failed to parse manifest … feature 'wasm' includes
'wasm-bindgen', but 'wasm-bindgen' is not an optional dependency` — the
`Cargo.toml`'s `[features] wasm = ["wasm-bindgen"]` line requires
`wasm-bindgen` to be declared `optional = true`, and it isn't. This is a
`Cargo.toml` manifest error, not a code bug — `cargo test` has never worked
for this crate as committed. **UNSUPPORTED.**

**quilt-vm-typescript** — `README.md:6` badge `Tests-6%20passing`, `package.
json` script `"test": "tsc && node dist/test_quilt_vm.js"`. Check: `npm
test` → `tsc` succeeds silently, then `node dist/test_quilt_vm.js` →
`Error: Cannot find module '.../dist/test_quilt_vm.js'`. `tsconfig.json`
mirrors the `tests/` and `src/` subfolders under `dist/` (rootDir "."), so
the real output is `dist/tests/test_quilt_vm.js`, but `package.json`'s
script omits the `tests/` prefix (and the `gold` script has the same bug
for `src/gold.js`). Running the file at its *actual* path
(`node dist/tests/test_quilt_vm.js`) does genuinely print `6 passed, 0
failed, 6 total` — the test logic is correct, but **the documented command
(`npm test`) has never worked as committed.** UNSUPPORTED for "run `npm
test`"; the underlying 6/6 claim is true once invoked correctly.

**federated-tinyml-npm** — `package.json` `"keywords": [..., "byte-exact",
...]`, `"test": "node test.js"`. Check: `npm test` → `TypeError:
head.toBytes is not a function` at `test.js:12`. `index.js`'s
`ClassifierHead` class has no `toBytes`, `fromBytes`, or `toJSON` methods at
all (`grep -n "toBytes|fromBytes|toJSON" index.js` → no matches), yet the
package's own shipped `test.js` calls all three. **This package is live on
npm** — `https://registry.npmjs.org/@superinstance/federated-tinyml`
reports `dist-tags.latest = 0.3.0`, matching the locally cloned
`package.json` version exactly, so the currently-installable
`npm install @superinstance/federated-tinyml` ships a self-test that
crashes on line 2 of 5. **UNSUPPORTED**, and consumer-facing.

### 2.3 Stale / drifted data — the "aspirational README written before a later change" pattern

**live-canon-npm** — `README.md:6` badge `state_hash-0xbf27a3631cdee337`,
`README.md:59`: *"The package bundles 9 papers…"*, `test/test.js:11`:
`assert.strictEqual(canon.paperCount, 9, …)`. Check: `npm test` →
`AssertionError [ERR_ASSERTION]: expected 9 papers … 14 !== 9`. `git log
--oneline -- index.js test/test.js` shows a single commit,
`6983031 v0.3.0: 14 papers, state hash 0xb4b3dcf0c653e721`, that updated the
bundled data but never updated `test/test.js`'s assertion or the README.
Running `node -e "…canon.stateHashString…"` directly confirms the actual
shipped hash is `0xb4b3dcf0c653e721`, not the `0xbf27a3631cdee337` still
printed at `README.md:6,35,72-75`. The package's own `npm test` fails
outright. **UNSUPPORTED.**

**live-canon-pypi** — `README.md:6,59,72`: same `0xbf27a3631cdee337` /
"9 papers" claim. Check: `python3 -c "from live_canon import LiveCanon;
print(LiveCanon().paper_count, LiveCanon().state_hash_string)"` → `14
0xb4b3dcf0c653e721`. Same drift as the npm sibling, no test suite ships to
even catch it locally. **UNSUPPORTED.**

**quilt-live-canon-npm** — same stale `0xbf27a3631cdee337`/"9 papers" claim
at `README.md:6,35,72-75`, and `test/test.js` is a byte-for-byte copy of
`live-canon-npm`'s test (checks `canon.paperCount === 9` and
`canon.stateHashString === '0xbf27a3631cdee337'`). Check: `npm test` →
`AssertionError … 71 !== 9` (this repo's bundled `data.json` has 71 papers).
Worse: `canon.stateHashString` **does not exist** on this repo's
`LiveCanon` class at all (`grep -n stateHashString index.js` → no match;
only a `stateHash()` method) — the copied test would fail a second way even
past the paper-count assertion. **This is the source repo for the live npm
package** `@superinstance/live-canon` — `registry.npmjs.org` shows
`dist-tags.latest = 0.9.1`; downloaded the actual published tarball
(`live-canon-0.9.1.tgz`) and confirmed the **currently-installable package**
ships `index.js` with 71 papers / hash `0x7f563ed9982496a1`, while its own
bundled `README.md:6,35,72-75` still advertises `0xbf27a3631cdee337` and "9
papers" — a real consumer running the README's own `console.log
(canon.stateHashString)` example gets `undefined`. **UNSUPPORTED, and this
is the most consumer-facing finding in this audit** (live, versioned,
installable, wrong).

### 2.4 "Verified"/"published" claims aimed at outside consumers that don't hold

**quilt-k3s** — `README.md:105,107,113,124`: instructs `npx @quilt/k3s test`
/ `npx @quilt/k3s scenario …` with a fabricated-looking sample output
`# Reports: ✓ 5/5 passed in 87.3s`; `README.md:157`: `npm install -g
@quilt/k3s`. Check: `curl https://registry.npmjs.org/@quilt%2Fk3s` →
`HTTP 404 {"error":"Not found"}`. The package has never been published; the
"try it right now" instructions cannot be followed by an outside reader as
written. (The repo does contain real TypeScript source, a `test/` dir, and
`scenarios/`, so the underlying tool may work locally — that part is
UNVERIFIABLE-HERE since it needs Docker/k3d — but the *publication* claim
itself is checkable and false.) **UNSUPPORTED** for "install this package."

**quilt-elf** — `README.md:117`: `npm install @quilt/elf`. Check:
`registry.npmjs.org/@quilt%2Felf` → `HTTP 404`. Not published.
**UNSUPPORTED.**

**cell-router-pkg** — `README.md:6`: `pip install cell-router`. Check:
`pypi.org/pypi/cell-router/json` → `HTTP 404`. Not published.
**UNSUPPORTED** for the install claim. (The *byte-exact* claim on the same
README, `README.md:3`, is the rare case that checks out — see §3.)

**mudra-vessel-bridge-pkg** — `README.md:6,14-16`: `pip install
mudra-vessel-bridge[...]` (four variants). Check: `pypi.org/pypi/mudra-
vessel-bridge/json` → `HTTP 404`. Not published. **UNSUPPORTED** for the
install claim; see §3 for the (largely supported) self-test-count claim on
the same README.

---

## 3. Clean repos

These repos' checkable claims were run and held up, or held up closely
enough that the gap is disclosure noise rather than fabrication. Named
explicitly per the brief:

- **quilt-go** — `README.md:3,16,46-47` claims "7/7 tests pass" and shows
  the exact hash transcript. `go test -v` (after adding a `go.mod`, which
  was simply missing — not a claim issue) genuinely produces `--- PASS:
  TestHashReferenceCell` with hash `0xe435d91d6d92a1d8`, and 7/7 pass.
- **quilt-rust-vibe** — `README.md:3` "6/6 tests pass. Hash …verified
  byte-exact." `cargo test` → 6/6 pass, including
  `state_hash_matches_expected` asserting the exact `0xe435d91d6d92a1d8`
  value against `id=1, dials=[1..16], neighbors=[2,3,4]` as specified.
- **quilt-zig** — `README.md:37-45` "7/7 tests pass". Installed Zig 0.13.0
  and ran `zig test test_hash.zig` → `All 7 tests passed`, including the
  exact hash reference test.
- **quilt-vm-c** — `README.md` "Tests: 6 passing" badge. `make test` → all
  6 named tests pass (`PASS test_bind_and_view` … `PASS
  test_full_polyformalism`).
- **quilt-esp32** — three separate claims (2 host unit tests; 24 firmware
  regression checks; "host-verified (gcc) and cross-verified against the
  Rust reference VM"). `cargo test` → 2/2. `make -C firmware run` →
  matches the README's example output exactly. A separately compiled
  `host_opcodes/main.c` harness prints `{"ok":true,"passed":24,"failed":0}`
  matching the README's "24 checks" claim exactly. This repo's own status
  section (`README.md:290-298`) is also a model of calibrated disclosure:
  it explicitly flags `src/lib.rs` as "the API sketch" and states the
  on-metal run is "still pending" — a claim of hardware verification that
  is *not* made, correctly.
- **quilt-timesfm-rust** — `README.md`: "Bit-exact with the C and Python
  ports" and `cargo test # 49 tests`. `cargo test --lib --tests` → exactly
  49 tests pass, including `test_42_state_hash_bit_exact`.
- **adinkra-math-pypi** — `tests/test_all.py` docstring: "Comprehensive
  pytest suite … (45+ tests)". `pip install -e .` then `pytest tests/` →
  **58 passed**, exceeding the stated floor.
- **quilt-live-canon-pypi** — `README.md:8,13`: "papers-71" badge, "71 in
  the bundled canon", and hash badge `0x7f563ed9982496a1`.
  `LiveCanon().state_hash()` → `0x7f563ed9982496a1` over 71 papers — matches
  exactly. This is the one member of the "Live Canon" family (§2.3) that is
  internally consistent; it appears to be the canonical/current version
  that the others (`live-canon-npm`, `live-canon-pypi`,
  `quilt-live-canon-npm`) drifted away from without being updated to match.
- **cell-router-pkg** (byte-exact claim only, not the install claim — see
  §2.4) — `README.md:3`: "byte-exact with the JS port." No test ships, but
  manually invoking `cell_id()`/`cell_dials()` in `cell_router.py` and
  `cellId()`/`cellDials()` in `cell-router.js` on the same synthetic bottle
  produced byte-identical output (`0x9be30a196b51e8bb`, identical 16-dial
  array) in both languages. Genuinely byte-exact, just untested in CI.
- **mudra-vessel-bridge-pkg** (self-test claim, not the install claim — see
  §2.4) — `README.md:9`: "51 self-tests." Running each module's real
  `selftest`/`--selftest` entry point as a package
  (`python3 -m mudra_vessel_bridge.<mod> selftest`, needed because three of
  the six modules use relative imports that fail when run as bare scripts —
  a packaging wrinkle, not a false claim) gives 5 + 7 + 7 + 7 + 7 + 12 = 45
  self-tests, all passing. 45 vs. the claimed 51 is a real but modest gap
  (12%), most plausibly module additions/removals since the number was last
  written down — flagged as a minor drift, not a fabrication. Module count
  ("11 Python modules") is similarly close (12-13 actual, depending on
  whether `__init__.py` counts).
- **quilt-conformance** — deserves special mention: this repo *is* an
  internal audit, and its self-description ("zero 'trust me it passes'
  claims — every number below was produced by executing code on this
  host") is corroborated rather than undermined by this audit. Its
  `README.md:14-18` status table independently documents, as of
  2026-08-25: `quilt-vm-rust`: "`cargo test` **fails to compile** (BUG-1)"
  — matches §2.2 exactly; `quilt-vm-typescript`: "6/6 (wrong dist paths —
  BUG-2)" — matches §2.2 exactly; `quilt-vm-wasm`: "invalid Cargo.toml
  (BUG-3)" — matches §2.2 exactly. These bugs were filed by the org's own
  tooling weeks before this audit and simply never fed back into the
  individual repos' badges (see §4). **quilt-conformance is the one repo in
  this org whose entire purpose is exactly what this audit is doing, and it
  is doing it correctly.**
- **quilt-llvm** — `README.md:3`: "**Work has begun. Nothing here is
  claimed to work yet.**" A design-stage repo that makes no checkable
  claims and says so explicitly — exactly the honest calibration the brief
  asks to distinguish from the real problem cases.
- **agent-priming-toolkit-pkg, quilt-cellular-arch, quilt-cuda,
  bare-metal-plato, quilt-mojo, tit-quilt** — design/concept documents with
  no locally checkable factual claim (no test suite referenced, no
  install/publish instruction, no specific numeric result tied to this
  repo's own code). Read in full; nothing to check, nothing to flag.

---

## 4. Pattern analysis

**Is the copy-paste template the main cause?** Partially, and it is more
visible than previously known. The prior scout found the `C99 (C99)` /
`C99 (Verilog)` / `C99 (VHDL)` row on `quilt-c`/`quilt-verilog`/`quf-vhdl`.
This audit adds a **fourth instance**: `quilt-rust/README.md:33` has
`| C99 (Rust) | ✓ | manual |` — the same unedited copy, propagated into the
"real" flagship Rust monorepo, which doesn't even implement the polyformal
cell model its own README's badge and hash sentence describe. The badge/
hash-sentence/table triad (`README.md` lines ~3, ~8, ~25 in every port) is
reused verbatim across at least 11 repos (`quilt-c`, `quilt-go`,
`quilt-rust`, `quilt-rust-vibe`, `quilt-zig`, `quilt-lua`, `quilt-haskell`,
`quilt-j`, `quilt-forth`, `quilt-verilog`, `quf-vhdl`) — clearly stamped
from one template at the start of each port. But template stamping alone
does **not** explain most of what's actually broken:

- **Never-executed code presented as verified** (quilt-lua, quilt-haskell,
  quilt-forth, quilt-vm-rust, quilt-vm-wasm): these are not missing tests,
  they are *syntactically or type-invalid* source files whose accompanying
  README nonetheless shows a "PASS" transcript. This suggests the
  transcript was generated once against a working draft and the source was
  edited afterward without re-running it — or the transcript was written by
  reasoning about what output *should* look like rather than by running
  anything. Either way it is a distinct failure mode from copy-paste: the
  claim is about *this specific file*, and this specific file cannot run.

- **Drifted data, not fabricated data** (`live-canon-npm`,
  `live-canon-pypi`, `quilt-live-canon-npm`): here the original claim was
  almost certainly true when written. `git log` on `live-canon-npm` shows
  the bundled canon growing from 9 → 14 papers in one commit that touched
  both `index.js` and `test/test.js` but only fixed the code, not the
  test's expected value or the README. This is the single most avoidable
  category — a CI job running `npm test` on every publish would have caught
  every instance instantly (and does exist for at least one sibling, since
  `quilt-live-canon-pypi` — same family, same claim shape — is fully
  correct at 71 papers). The fact that one branch of the family stayed
  correct while three others drifted independently suggests no CI gate
  runs the self-test before README claims are trusted or before `npm
  publish`.

- **Packaging/wiring bugs mistaken for passing** (`quilt-vm-typescript`'s
  `dist/tests/…` path, `quilt-vm-wasm`'s non-optional `wasm-bindgen`
  feature, `federated-tinyml-npm`'s missing `toBytes`/`fromBytes`/`toJSON`):
  the underlying logic in two of these three cases is fine or nearly fine
  once invoked correctly — the failure is that nobody ran the *documented*
  command (`npm test`, `cargo test`) after the last change that broke it.

- **Aspirational publication claims** (`quilt-k3s`, `quilt-elf`,
  `cell-router-pkg`, `mudra-vessel-bridge-pkg`): real source exists, but
  the package was never pushed to the registry the README instructs the
  reader to pull from. This is the cheapest failure mode to produce (a
  README line typed before `npm publish`/`twine upload` ever ran) and the
  cheapest to fix.

- **A working internal audit that never closed the loop**
  (`quilt-conformance`): the org already has a rigorous, dated, self-
  critical conformance suite that names three of the exact bugs this audit
  independently rediscovered (BUG-1/2/3, `quilt-conformance/README.md:14-18`,
  dated 2026-08-25). None of those three bugs' host repos (`quilt-vm-rust`,
  `quilt-vm-typescript`, `quilt-vm-wasm`) have their badges corrected as of
  this audit (2026-09-08), two weeks later. The problem is not a shortage
  of internal QA; it's that the QA repo's findings don't feed back into the
  individual repos' README badges.

**Net read:** copy-paste explains why the *same wrong badge* shows up on
many repos, but the underlying failures are a mix of "never ran the code,"
"ran it once and it drifted," and "wrote the install line before
publishing" — three separate process gaps, only the first of which the
template pattern actually causes.

---

## 5. Prioritized fix list

Ordered by expected damage to an outside reader's trust, cheapest fix noted
for each.

1. **`@superinstance/live-canon` on npm (currently 0.9.1, live today).**
   Highest priority: this is the only finding in this audit that is an
   *actively installable* package with a wrong claim baked into its
   published README and a broken example line
   (`console.log(canon.stateHashString)` → `undefined`). Fix: republish
   with the badge/table updated to `0x7f563ed9982496a1`/71 papers (already
   correct in the sibling `quilt-live-canon-pypi`, so the right numbers are
   sitting right there), and add a `stateHashString` getter or remove the
   line from the README example. Should ship with `npm test` wired into
   `prepublishOnly` so this can't recur.

2. **`@superinstance/federated-tinyml` on npm (currently 0.3.0, live
   today).** `npm test` throws on the second assertion for any consumer who
   checks. Fix: either implement `toBytes`/`fromBytes`/`toJSON` on
   `ClassifierHead`, or rewrite `test.js` to only exercise what
   `index.js` actually exports — either is a same-day fix, and `npm test`
   in CI before publish would have caught it originally.

3. **`quilt-vm-rust`, `quilt-vm-wasm`, `quilt-vm-typescript` badges.** All
   three show green "Tests: N passing" badges for commands that do not run
   as committed, and the org's own `quilt-conformance` repo already knows
   this (dated three weeks prior). Fix is mechanical and already diagnosed
   in `quilt-conformance/results/BUGS.md`: fix the `HashMap<String,i32>`
   literal in `quilt-vm-rust/src/lib.rs:280-283`, add `optional = true` to
   `wasm-bindgen` in `quilt-vm-wasm/Cargo.toml`, and fix the two `dist/`
   paths in `quilt-vm-typescript/package.json`. None of these are more than
   a one-line change; the fact they've sat unfixed since a dated internal
   bug report is the more important thing to close.

4. **`quilt-c`, `quilt-rust`, `quilt-verilog`, `quf-vhdl` byte-exact
   badges.** These are the highest-visibility claim (a green badge on every
   port's README) attached to the *least* real work (no code anywhere
   computes the claimed value). Cheapest honest fix: delete the badge and
   the "byte-exact" sentence from the four repos that don't implement the
   test, or — better, since the value the badge claims is real and
   verified elsewhere (quilt-go, quilt-rust-vibe, quilt-zig) — actually add
   the missing reference-cell test to each, which for `quilt-c` is a ~15
   line addition given the FNV-1a function already exists in the file.

5. **`quilt-lua`, `quilt-haskell`, `quilt-forth` — code that has never
   parsed.** Lower external visibility than #4 (fewer people will try to
   run niche-language ports) but the most severe *gap between claim and
   reality*: a "PASS" transcript for code with a syntax error. Fixes are
   small and mechanical: strip the three `ULL` suffixes in `quilt-lua`
   (confirmed this alone gets the hash test passing; a second, real bug at
   `quilt.lua:238` remains and needs an actual fix, not just deletion);
   swap `Data.ByteString.Little` for `Data.ByteString.Builder` and drop or
   vendor `Control.Monad.State.Strict` in `quilt-haskell`; finish the
   `... ;  \ (deferred; see below for full impl)` stub at
   `quilt-forth/quilt.fs:75`.

6. **`quilt-k3s`, `quilt-elf` publish claims.** Real code, unpublished
   package. Either run `npm publish` or change "Try it right now" /
   `npm install …` to "not yet published — clone and run locally." Five-
   minute fix either way.

7. **`cell-router-pkg`, `mudra-vessel-bridge-pkg` publish claims.** Same
   shape as #6 but lower stakes — both repos' *substance* claims (byte-
   exactness, self-test counts) are essentially true, only the `pip
   install` line is aspirational. Same fix: publish, or change the wording.

8. **Live Canon family duplication.** `live-canon-pypi` and
   `quilt-live-canon-pypi` declare the *same* PyPI package name
   (`quilt-live-canon`) in their respective `setup.py` files, and
   `live-canon-npm`/`quilt-live-canon-npm` are two independently-drifting
   copies of the same npm package. Not a false claim by itself, but a
   structural cause of #1 and the drift in §2.3 — worth consolidating to
   one source repo per published package before the next drift happens.

---

## Verification note (added by the dispatching session)

Four of this report's highest-impact claims were re-checked independently before
being relayed. All four hold, and the checks are recorded so a reader does not
have to take either the scout's word or mine.

### 1. `@superinstance/live-canon@0.9.1` — README and shipped code disagree

Fetched the tarball the registry actually serves:

```
hash in the shipped README : 0xbf27a3631cdee337
hash in the shipped CODE   : 0x7f563ed9982496a1
```

### 2. The README's own example returns `undefined`

`package/README.md:35` reads:

```js
console.log(canon.stateHashString);  // 0xbf27a3631cdee337
```

Executed against the published package:

```
canon.stateHashString -> undefined
exported keys: LiveCanon, fnv1a_64, stateHash, cellToDials, DEFAULT_CANON, BODIES
```

There is no `stateHashString` export. This is the currently-installable version,
so the first thing a new user copies from the README does not work.

### 3. `quilt-lua` does not parse — run, not inferred

`quilt-lua/quilt.lua:24` uses the C integer suffix `ULL`:

```lua
local FNV_OFFSET = 0xcbf29ce484222325ULL  -- Lua 5.3+ has integer literals
```

Running it:

```
lua5.4: quilt.lua:24: malformed number near '0xcbf29ce484222325U'
```

The comment on that very line asserts Lua 5.3+ compatibility. It is wrong, and
the file has therefore never executed — yet the repo displays a passing-hash
transcript.

### 4. The sibling ports, same pattern

- `quilt-haskell/Quilt.hs:22` imports `Data.ByteString.Little`, which is not a
  module in `bytestring` (the real one is `Data.ByteString.Builder`).
- `quilt-forth/quilt.fs:75` is a literal stub: `... ;  \ (deferred; see below
  for full impl)`.

### What was NOT re-verified

Everything else in this report — the other ~44 claims, the clean-repo list, the
`quilt-vm-*` badge findings, the registry 404s. Those rest on the scout's work,
which installed real toolchains and ran things, and whose four checked claims
all held. That is grounds for confidence, not proof.

### One thing for the owner to reconcile

The scout reports an org repo named **`quilt-conformance`** which "already
documented all three `quilt-vm-*` bugs three weeks earlier". This archive
independently created `build/quilt-conformance/` for the state-hash corpus,
without knowing that repo existed. The two should be reconciled before either is
promoted — and if the org's QA repo already found these bugs and they were never
fixed, then the constraint here is not detection but follow-through, which no
further tooling will solve.
