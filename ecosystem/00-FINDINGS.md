# Ecosystem findings — what is already engineered

Produced 2026-09-05 by scouting the live `SuperInstance` org, not this archive.
Every claim here is sourced to a repo and, where it matters, verified at the file.

---

## 1. The org is roughly twice the size you describe it as

The profile says "500+ repos." Name-substring counts say otherwise:

| Prefix | Count |
|---|---|
| `ternary-*` | 386 |
| `fleet-*` | 323 |
| `plato-*` | 294 |
| `flux-*` | 192 |
| `si-*` | 113 |
| `quilt-*` | 95 |
| `cocapn-*` | 68 |
| `constraint-*` | 66 |

Over 1000 distinct repo names were observed directly. GitHub's search caps at
1000 results, so the true total is higher.

## 2. Three mass-creation events explain most of it

Hundreds of repos share an identical `updated_at` stamp, which means they were
generated in one sitting and never touched again:

| Date | What appeared | State now |
|---|---|---|
| 2026-05-21 | ~100 generic-description stubs | cold |
| 2026-06-04 → 06-08 | the `ternary-*` and `si-*` bursts | frozen 2026-07-12 |
| 2026-07-12/13 | `plato-*`, sheaf/spectral, Working-Animal | cold |

**The only continuously active line since mid-August is Quilt substrate +
Live Canon + the F1xx marine/edge series.** That is where the real engineering is.

## 3. Your Pythagorean-angle idea is already built, proven, and machine-checked

This is the headline finding.

You said: *"you can choose to sample on the Pythagorean angles and have tolerance
around what is sure instead of floating point."*

That is **Theorem 4a** in `quilt-verilog/docs/academic/THE-BREAKDOWN.md`, with
`docs/academic/error-envelopes.md` §4 as the elaboration. Verbatim, Definition 4:

> **Pythagorean configuration**: reachable set ⊆ `{v ∈ ℤⁿ : ‖v‖ ∈ ℤ}` → distance 0,
> arithmetic exact by construction.

The full result:

- The covering radius of the scaled integer lattice `b·ℤⁿ` is **exactly** `b√n/2`,
  attained at deep holes (cube centres). So `b ≤ 2ε/√n` is sufficient for any
  geometry; `b ≤ 2ε` in 1-D.
- The **squared-form judge** — verdict WITHIN iff `‖g−s‖² ≤ Δ²`, compared as exact
  integers — has **zero comparison error**. No square root, no float. The only
  error in the loop is sensing quantisation.
- The deadband is a **Schmitt trigger**, not a threshold: true divergence bounded
  by `Δ + 2ε` always, `2ε` right after a snap. Verdicts are guaranteed outside a
  `(Δ−2ε, Δ+2ε]` fuzzy band.
- On-lattice (Pythagorean) geometries sit at **distance 0** — no covering argument
  needed, no floats because none are needed.

**And it is machine-checked, with a negative control:**
`tb/tb_judge_consistency.v` — ~2,325 vectors over n ∈ {1,2,3}; max quantisation
error equals `b√n/2` *exactly* at the deep holes (7.0 / 6.36 / 6.93 against ε=7);
zero verdict flips outside the ±2ε band; and `b+1` **breaks** the guarantee at the
deep hole in every dimension. A test that only ever passes proves nothing; this
one has a case that fails on purpose.

### It is not just theory — there is a compiler that enforces it

`tools/tower/emith.py` compiles a YAML cell spec into a single dependency-free C
file, and **refuses to emit code when the basis is not exact**:

```python
if (span_psi * den) % num != 0:   raise CellError(...)
```

`tools/tower/verify.py` then cross-checks 17 hand-computed golden vectors *and
greps the generated C for floating-point types*:

```python
if re.search(r"\b(float|double)\b", c_text):
    failures.append("generated C mentions a floating-point type")
```

Its own output line reads `floats   : none in generated C`. The float-free
property is **checked, not asserted**.

The worked example is the oil-pressure cell: `psi = (mV − 500) · 3/80`, a basis
chosen so every 400 mV is *exactly* 15 psi — the repo calls this
*"Pythagorean snapping, the choose-your-unit trick."*

### The separate piece you may have forgotten

`SuperInstance/pythagorean48` — *"Exact 6-bit vector encoding for ARM64 edge.
8 components per uint64, zero drift, 80M queries/s on Jetson."* A Rust crate,
one `src/lib.rs`. It cross-links `tminus-dispatcher`, `tminus-client`, and
`constraint-tminus-bridge` in its own README — so the t-minus × exact-arithmetic
join you described **is already wired at the doc level**. `fleet-coordinate-js`
also carries a "Pythagorean48" port in pure TypeScript, no WASM.

### But be careful: three repos claim this, and only two deliver

A second scout read the *source*, not the descriptions, and the picture is
sharper than "it's already built":

| Repo | Exact integer? | Reality |
|---|---|---|
| `quilt-verilog` (Theorem 4a + `tools/tower/`) | **Yes** | Genuinely integer, proven, machine-checked, float-freedom *verified by grep*. The strongest of the three. |
| `eisenstein` | **Yes** | `E12 { a: i32, b: i32 }`, `norm() = a²−ab+b²` — pure `i32`, `no_std`, zero required deps, **226 tests**. Float only enters via an opt-in `snap` feature. |
| `constraint-theory-core` | **No — f32** | `PythagoreanTriple { a: f32, b: f32, c: f32 }`; `snap()` returns `([f32;2], f32 noise)`. Real Euclid-formula triple generation and a KD-tree, but the arithmetic is floating point. |

**`constraint-theory-core`'s description is wrong about itself.** It advertises
"Eisenstein lattices, deadband funnels, metronome consensus." Grepping `src/`:
*deadband*, *metronome* and *eisenstein* appear **nowhere in the source** — only
in `AGENT.md`, where the same marketing sentence is pasted as the bot's
self-description. Laman rigidity and holonomy verification are real. The actual
`deadband_ring` implementation lives in **`eisenstein`**, not here.

Two more things worth knowing before you depend on any of it:

- `pythagorean48-codes` promises a `compose()` for "unlimited hops without drift"
  that **does not exist** in its 101-line source. It has 4 tests.
- `constraint-theory-core`'s own README warns the SIMD batch path can tie-break
  differently from the scalar path — *"use the scalar `snap_batch` for
  consensus-critical code."* So "identical everywhere" is conditional on a code
  path, not inherent.
- `dcs.rs` asserts that `RICCI_CONVERGENCE_MULTIPLIER = 1.692` "matches" an
  externally-asserted law to three significant figures, with a test named
  `test_ricci_multiplier_matches_dcs`. There is no derivation connecting them.
  That is numerology wearing a test harness. Treat it as such.

### What genuinely does NOT exist — and it is the interesting part

Your idea has three parts. Two are built; the third is not built anywhere:

1. **Exact angle sampling** — built twice over (`quilt-verilog` Theorem 4a;
   `eisenstein` E12; `PythagoreanManifold`; `pythagorean48`; `snap-lut` for FPGA BRAM).
2. **Predict-and-confirm timing** — built and consolidated. `swarm-tminus`
   (Python, stdlib-only, **301 tests**) is the canonical synthesis of six
   scattered Rust/JS implementations, with a documented module→source-repo table.
   Its `CountdownEvent.has_quorum()` and `Predictor.confirm()` are exactly your
   protocol.
3. **The join — an exact value that carries its tolerance band as a first-class
   field, and that band driving when something fires.** ✗ **Nowhere.**

Today the tolerance is always a *float scalar computed after the fact* — `noise`,
`err`, `tolerance` — a **result** of snapping, not a band you set and then sample
within. There is no `ExactAngle { value: PythagoreanTriple, band: (lo, hi) }`
anywhere. And nothing maps a BPM/phase into an exact angle: every t-minus timing
type is `f64`/`Duration`, every exact type is `i32`/`u8`, and no shared trait
connects them.

Two repos are *named* as if they close this — `constraint-tminus-bridge` and
`holonomy-48-bridge` — and neither was verified. Given this org's pattern of
descriptions outrunning implementations, read them before trusting them.

**Verdict: the two halves are built and reusable today. The join is real, novel,
and unbuilt — and it is small.** That is the piece worth writing.

## 4. quilt-verilog is a real foundation, and its experiments have results

The `rtl/` you see is the winner of a documented five-crew tournament
(`docs/SCORECARD.md`): `glm` won 33 points on a tiebreak over `opencode` (33),
with `zeroclaw`'s hyperbolic decay math merged in as a mandatory second engine
mode. Two entries were rejected outright with reasons — one for "numbers are
confabulated," one for "'ready for synthesis' was false."

Experiments with real outcomes, from `spikes/`:

| Experiment | Result |
|---|---|
| E1 interference tick | **VALIDATED under stress** — ~20% fewer corrections, 83% vs 52% of ticks in deadband. **Worse at gentle params** (45.5% vs 56.7%): "a conflict-resolution regime, not a free lunch." |
| E2 quilt-as-dataset | **VALIDATED** — 471,777 records, +12.1pp over majority on unseen cohort grammar; learned weights physics-consistent |
| Model arena | A 2B local model beat the hand-tuned strategy by 10pp (93.2% vs 83.1%) |
| E1 ICL curriculum | **FALSIFIED** — the 1.2B model is a constant predictor; real ≈ shuffled ≈ no context |
| E3 self-improvement loop | **COLLAPSED in 3 rounds** — the gate starved its own training corpus. "Classic self-training distribution shift, reproduced inside a quilt." |

That mix — validated, falsified, collapsed — is what a real experiment log looks
like.

### `hostile-consumer/` is the most valuable directory in the org

A deliberately blind, spec-only red team of the QUF format. Found 11 spec bugs
(F1–F12), **all subsequently closed** with numbered rules R1–R18 and reason codes
E7–E18 plus a regression corpus of mutant files. The sharpest: a hostile file
could point the `dials` section into the KV metadata region and satisfy every
stated rule. A second stage found that renaming `epoch.1` → `epoch.05` makes a
spec-faithful consumer **silently not-see an epoch**.

A parallel adversarial pass (`docs/BACKEND-NOTES.md`) found 23 bug classes,
including a single-section QUF that "booted *clean* WITHOUT LOADING ITS ONLY
SECTION."

## 5. The redundancy is the real cost

Same thing built repeatedly, with no cross-references:

- **Ternary math as ~50 separate one-concept crates** — `ternary-graph`, `-regex`,
  `-hash`, `-sort`, `-paxos`, `-quorum`, `-lattice`, `-zkp`, `-knn`, `-svm`,
  `-transformer`… each its own repo, all created within minutes of each other.
  This is one library with submodules.
- **Exocortex built 6–7 times** — `exocortex`, `-core`, `-rs`, `-kernel-c`,
  `-mcp-ts`, `si-exocortex-rs`, plus a recovered copy.
- **Spectral graph theory 4+ times**, five overlapping sheaf libraries.
- **Three multi-model orchestrators built the same day** (2026-08-03) by three
  different models — `baton-orchestrator` (KimiCode), `slackwater-orchestrator`
  (GLM-5.2), `salidiere` (Claude Sonnet 5) — same problem, no cross-reference.
- **Four separate "entry point" repos** for Quilt in a two-day window:
  `quilt-system`, `quilt-foundation`, `quilt-core-os`, `quilt-base`.
- **Seven repos packaging the same Live Canon API** across PyPI/npm/GH/CLI.
- **8 private/public twin pairs** created in the same minute.
- **59 `recovered-copy-*` + 11 `rc-*`** repos from the 2026-08-24 recovery event.
- **Four competing metaphor systems** for one problem (budgeted agent lifecycle +
  conservation + health): Working-Animal, Cocapn/crab, Fleet/vessel, PLATO/room.

## 6. Ten underrated repos

Solid engineering that nothing else references:

1. `nmea-quilt-cell` — byte-exact replay, kill -9 crash canary
2. `provenance-log` — SHA-256 hash-chained append-only audit log, generic over serde
3. `deckhand-rs` — zero-dep BM25, "10-100x faster than Python"
4. `fibonacci-fence` — budget governor whose limit scales by the golden ratio
5. `quilt-substrate-meta` — a prover, a synthesizer, 36 passing tests
6. `sheaf-agents-rs` — "H¹ > 0 means communication can't help," real applied topology
7. `federated-tinyml-vessel` — 1.3 KB trainable head, cross-language ports
8. `mudra-vessel-bridge` — 11 modules, 51 tests, BLE + NMEA + OpenCV
9. `fleet-functions` — 55 seeded functions, semantic search, safe invoke
10. `plato-engine-block-c` — C99, zero dynamic allocation, bare-metal embeddable

## 7. Highest-test-count libraries (the ones ready to depend on today)

| Repo | Claim |
|---|---|
| `constraint-theory-py` | **167 tests** |
| `constraint-theory-core` | **83 tests**, zero deps |
| `mudra-vessel-bridge` | **51 tests** |
| `quilt-substrate-meta` | **36 tests** + prover + synthesizer |
| `quilt-types` / `quilt-opt` / `quilt-gc` | 16 / 11 / 12 tests |
