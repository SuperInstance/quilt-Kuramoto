# QUILT-CUDA — the 5+1 opcodes as CUDA operations

The GPU side of the quilt substrate. The 5 opcodes (BIND, LINK, EFFECT,
VIEW, TICK) plus the quiet sixth (FORGET), mapped onto CUDA primitives and
wired to the cudaclaw organs: the persistent worker kernel, the SmartCRDT
engine, and the Flux→PTX bridge.

The headline:

> **The GPU already thinks in cell graphs. A CUDA Graph IS quilt's LINK.**
> Nodes = kernel instances (BIND'd cells), edges = dependencies (LINKs),
> instantiate = compile, launch = TICK, destroy = FORGET. The wavefront
> scheduler IS the GPU scheduler. This is not an analogy — it is the same
> data structure with two vocabularies.

---

## 1. The opcode table

| Opcode | Quilt meaning | CUDA operation | In this repo |
|---|---|---|---|
| **BIND** | label a value at a key (scatter) | cell allocation: a slice of device memory with `{state, witness_word, lamport, opcode}`; the `bind` path writes value + plants the W_BOUND mark | `bind_kernel`, `quilt_bind()` host helper, arena allocator |
| **LINK** | relate two cells (connect) | a dependency edge compiled into a **cudaGraph**: `cudaGraphAddKernelNode` (the cell's kernel instance) + `cudaGraphAddDependencies` (the edge). Also carried as a plain edge list for the device-side wavefront path | `quilt_graph.cu`, `QuiltEdge` |
| **EFFECT** | run a function (transform) | a device-side kernel or atomic that mutates world state; sets W_DIRTY, advances the Lamport clock | `cell_effect` op table, `effect` kernels, atomic body ops |
| **VIEW** | project state (gather, pure) | device→host `cudaMemcpy` of telemetry (state + witness + lamport). **No device write occurs — purity is structural**, not promised | `quilt_view()` |
| **TICK** | advance time (wavefront) | **one TICK = one `cudaGraphLaunch` of the instantiated exec.** The graph's topological order across nodes, parallel within a level, is the wavefront. Alternative device-side path: Kahn-style wavefront kernel over the edge list | `tick_wavefront_kernel`, `quilt_tick()` |
| **FORGET** | retire a cell (the +1) | kernel unload / `cudaGraphExecDestroy` + `cudaGraphDestroy` / `cudaFree`; device-side `forget_kernel` zeroes state and plants opcode=FORGET before the free | `quilt_forget()` |

## 2. BIND — the cell

A cell is a slice of device memory plus its witness word. CUDA layout
(SoA, coalesced — same discipline as cudaclaw's SmartCRDT):

```c
typedef struct QuiltArena {
    float*     value;    // cell state            (BIND writes, EFFECT mutates)
    uint32_t*  witness;  // W13 witness word      (one u32 per cell)
    uint64_t*  lamport;  // per-cell Lamport clock (TICK_monotonicity)
    uint8_t*   opcode;   // last opcode that touched the cell (telemetry)
    uint32_t*  body_op;  // the cell's effect body (what fires on TICK)
    float*     body_p0;  // body param 0
    float*     body_p1;  // body param 1
    uint32_t   count;
} QuiltArena;
```

BIND is idempotent by construction: `bind(c, v); bind(c, v)` writes the same
word twice and the same witness ORs into itself (`w | w == w` — L1 as a
bitwise identity). The Lamport clock is floor'd, never decremented.

`QuiltArena` is the cudaclaw `CRDTCell` unrolled to SoA with the witness
word added — the deliberate delta this repo contributes.

## 3. LINK — the compiled cell graph

Two representations, one semantics:

**Host-compiled (the proof):** `quilt_graph_build()` takes a cell-graph
edge list and turns it into a `cudaGraph`:

```
for each BIND'd cell:  cudaGraphAddKernelNode(cell's effect kernel)
for each LINK (a→b):   cudaGraphAddDependencies(a, b)
cudaGraphInstantiateWithFlags(...)   ← the LINK set, compiled
cudaGraphLaunch(exec, stream)        ← one TICK
```

CUDA has had this abstraction since 10.0: instantiate once, launch per
tick, and the hardware walks the dependency lattice — wide where the
frontier is wide, ordered where edges exist. **Quilt's LINK_transitivity is
the graph's reachability**; the scheduler resolves it every launch, for
free, in hardware.

**Device-resident (the substrate):** the same edge list stays in device
memory (`QuiltEdge {src, dst}`) and `tick_wavefront_kernel` walks it
Kahn-style — fire cells whose indegree hit zero, release their edges,
accumulate edge-carried values into successors. One pass = one wavefront
level; the host loop until quiescence = one TICK. This is the path a
persistent kernel (below) uses when there is no host at all.

## 4. EFFECT — the mutation

An EFFECT is any device-side write that mutates world state. Three layers:

1. **Body ops** — the cell's algorithmic body, a small op table
   (`NOP / SET / SCALE / ADD / CLAMP / RSI_STEP`) applied when the cell
   fires. A cell is mostly algorithmic; its body is its function.
2. **Atomics** — `atomicOr` on witness words, `atomicAdd` on edge-carried
   values, `atomicMax` on Lamport clocks. Associativity (L3) is why atomics
   are legal here: the merge order of concurrent effects doesn't change the
   union.
3. **Kernel effects** — whole kernels a cell designates (the MuscleFiber
   pattern from cudaclaw: a cell is assigned a fiber based on observed
   access pattern; here a cell's `body_op` selects the kernel variant).

Every effect sets `W_DIRTY` and advances the cell's Lamport clock.

## 5. VIEW — the pure readback

`quilt_view()` is a `cudaMemcpy` D2H of `{value, witness, lamport, opcode}`.
**VIEW_purity is structural**: the readback path contains no device write —
no dirty-flag clearing, no acknowledgment write, nothing. The host learns;
the world is untouched. (The host tracks its own last-seen Lamport; the
device never hears about it.)

This fixes a gap BRIDGE.md named: "a VIEW as a pure projection" — in
cudaclaw reads are plain loads; here the readback is the projection, and
its purity is checkable by reading the code path.

## 6. TICK — the wavefront

One TICK = one `cudaGraphLaunch` of the instantiated exec (or one
quiescence loop of `tick_wavefront_kernel`). The wavefront is not
simulated by quilt-cuda; **it is the GPU scheduler doing its job** —
nodes with satisfied dependencies launch, run in parallel across SMs,
and unblock their successors. TICK_monotonicity: every firing stamps
`lamport = max(lamport, tick)`; the journal of stamps is append-only.

## 7. FORGET — the quiet sixth

`quilt_forget()`: `forget_kernel` zeroes state, plants `opcode = QOP_FORGET`,
then the host destroys the graph exec, destroys the graph, and frees the
arena. The archive gesture before the free: the last telemetry was already
VIEWable; the witness word's W marks record that this cell lived.

---

## 8. The W13 witness layer

One `uint32` per cell. Layout:

```
 31 30 29                2 1 0
+--+--+-------------------+---+
|Wd|Wb|  30 trit witnesses    |
+--+--+-------------------+---+
  Wd = W_DIRTY  : mutated since it was last observable (effect witnessed)
  Wb = W_BOUND  : the cell is bound, allocation witnessed
  bits 0..29    : trit witnesses — bit i set ⇔ bit i of the raw state word
                  is set. The state carries its own witness.
```

**Union is OR.** The union of witnesses from any set of observers is the
bitwise OR of their words: idempotent, commutative, associative — a
semilattice in one instruction. That is the L1 law (BIND_idempotence) as a
warp-level instruction: `witness |= w` converges no matter how many times,
from how many lanes, in what order.

`witness_union_kernel` reduces the whole arena to one word via grid-stride
OR + warp shuffle-OR reduce + `atomicOr` — the L1 law at fleet scale.

### The consensus cell: 32 lanes = one warp = one cell

`warp_vote_kernel` makes one warp the consensus cell over one witness
word: lane *i* votes bit *i* of the word (trits 0–29, the two W marks at
lanes 30–31). Then:

```c
uint32_t ballot = __ballot_sync(0xFFFFFFFFu, pred);  // the witness word,
                                                     // re-derived from
                                                     // 32 independent
                                                     // observations
float consensus = (float)__popc(ballot) / 32.0f;
```

`__ballot_sync` IS the witness union at the instruction level — one
instruction, 32 lane-witnesses, one word. `popc/32` is the consensus
fraction.

### The two fringes

The canon's consensus fringes are carried as named constants:

- `QUILT_FRINGE_HIGH = 0.9989f` — the fleet fringe
- `QUILT_FRINGE_LOW  = 0.9004f` — the degraded-but-passing fringe

Scale fact worth saying out loud: **a single warp resolves consensus in
steps of 1/32** (max 1.0; 29/32 = 0.90625 clears the low fringe; nothing
between 0.9375 and 1.0). The high fringe 0.9989 needs resolution finer
than any single warp provides: a consensus cell of N lanes resolves
1 − 1/N ≥ 0.9989 at **N ≥ 909 lanes ≈ 29 warps**. So the 0.9989 fringe is
*by construction* a multi-warp, fleet-scale statement — one GPU warp is the
smallest consensus cell; the high fringe is what a *cluster* of consensus
cells asserts after their witness words are unioned. The two fringes live
at two scales, and the math says so.

### cudaclaw already agrees

`executor.cu` reduces success across the warp with
`__ballot_sync(FULL_WARP_MASK, success)`. One warp = one consensus unit is
already cudaclaw's operational model. quilt-cuda names it and hands it the
witness word.

---

## 9. The CRDT layer

Cell state merges as CRDT ops, same discipline as cudaclaw's SmartCRDT:

- **Ordering:** Lamport clock, then node_id as tiebreak — identical to
  `CRDTCell`'s `(timestamp, node_id)` LWW ordering in `crdt_engine.cuh`.
- **Merge kernel:** `crdt_merge_kernel` takes a batch of `MergeOp`s
  (value, lamport, node_id, witness, cell_id) and merges each into the
  arena: `atomicMax` decides the Lamport winner; the winner writes state;
  witness words union with `atomicOr` regardless of who won — *the witness
  of a losing merge still counts* (it observed; observation is never
  discarded). This is a simplified LWW surface; the full engine
  (warp-aggregated merges, bitonic sort by cell_idx, Kogge–Stone prefix
  sums, RGA) lives in cudaclaw and is referenced, not duplicated.
- **Idempotence:** replaying a merge op is a no-op (`max` and `or` are
  both idempotent) — a CRDT requirement and L1 at once.

### The persistent kernel = the GPU-resident cell agent

cudaclaw's `executor.cu` pattern, carried here as
`persistent_cell_agent_kernel` (a sketch, clearly marked): one warp,
launched once, never exits. Lane 0 polls a unified-memory doorbell behind
`__threadfence_system()`; on an op, `__shfl_sync` broadcasts to the warp;
the warp executes the op against the arena (bind / effect / merge / vote);
`__nanosleep(100)` backoff when idle. The kernel that stays resident,
receives ops, and ticks in place **is** the cell agent — no launch
overhead per tick, exactly the property cudaclaw built for sub-μs
dispatch. quilt-cuda's arena is what such an agent operates on.

The command word the agent polls is specified in `src/quilt_command.h` —
the quilt opcode stream riding cudaclaw's lock-free SPSC queue discipline
(`kernels/shared_types.h`: volatile `head`/`tail`, producer/consumer
split) as a pure overlay. **Evolution (post-nvcc): warp specialization** —
role-dedicated warps in the persistent agent (dispatch warp polls the
queue, consensus warp runs ballots, merge warp runs CRDT), the
DeepSeek-scale pattern. See `docs/ORGAN-MAP.md`.

---

## 10. The bridge

### Flux → PTX → persistent kernels

The oxide pipeline compiles `.qm` opcodes to PTX; `cudaclaw-bridge` (Rust)
deploys the compiled PTX to persistent CUDA kernels with warp-level
consensus — hot-swapped via `cuModuleLoadData` without dropping device
context, with VRAM accounting and the DeployStatus state machine on the
bridge's side. quilt-cuda slots in as **the substrate those kernels operate
on**: the arena, the witness layer, the edge list, the graph builder.

The `EFF_PTX` body variant (roadmap) does **not** invent a compile path —
it routes through cudaclaw's Ramify engine (`src/ramify/`):
`nvrtc_compiler.rs` compiles CUDA→PTX in-process (10–50ms, no
filesystem), `PtxTemplate.specialize()` + `BranchRegistry` cache by
`(template_id, pattern)`. quilt-cuda's fold: the **witness change set is
the pattern signal** — `pattern_hash = hash(witness_delta)` keys the same
registry, so fibers specialize on *what changed in the cell's state*, not
only where accesses landed. The five opcodes remain the ABI. Full mapping:
`docs/ORGAN-MAP.md`.

### Where `cudaclaw_to_quilt.py` fits

The existing exporter walks the cudaclaw *repo structure* and emits a
`.qzt` sheet — primitives, 32 warp-lane agent cells, 8 dispatch ops,
unified-memory substrate. That is a **VIEW in quilt's own format**: it is
the host-side projection of the organ. quilt-cuda is the device-side
counterpart. Relationship, not replacement:

- `cudaclaw_to_quilt.py` — structure → `.qzt` (unchanged, still works)
- `quilt-cuda` — opcodes → CUDA kernels (this repo)
- future `quilt_cuda_to_qzt.py` (not built tonight) — a live arena VIEW
  that emits a `.qzt` sheet from the device telemetry instead of the repo
  tree. Additive; touches nothing existing.

### Do-not-break contract

Nothing in `cudaclaw`, `cudaclaw-bridge`, or `quilt-cell-bridges` is
modified by this repo. Reference and extend, never break.

---

## 11. Status (honest)

| Item | Status |
|---|---|
| Recon of all organs | done (docs/RECON.md) |
| Design (this doc) | done |
| `src/quilt_cells.cu` substrate | written — **uncompiled** |
| `src/quilt_graph.cu` graph builder | written — **uncompiled** |
| `host_demo.cu` 3-cell demo | written — **uncompiled** |
| nvcc in this WSL | **absent** (`which nvcc` empty; no `/usr/local/cuda*`) |
| nvidia-smi in this WSL | **absent**; dxgk bridge unstable — no GPU runs tonight |
| Compile check | **PENDING** — first roadmap item: install toolkit, `make ptx` (`nvcc -c --ptx`) as syntax/ISA check with no GPU execution |
| GPU run | blocked by dxgk instability — not attempted, by directive |

### Roadmap

1. Install CUDA toolkit in WSL; `make ptx` — PTX generation = compile check
   without GPU execution.
2. When dxgk is stable: run `host_demo` on the RTX 4050 — 3-cell witness
   chain, graph TICK, warp vote. Dry-run `graph_cell_step_kernel` once
   first (defeats lazy module loading — the persistent-kernel trick).
3. `EFF_PTX` body op via the **Ramify route**: `PtxBranchCompiler`
   specialization keyed on witness deltas, `BranchRegistry` caching,
   `nvrtc_compiler.rs` in-process compile, cudaclaw-bridge hotswap. No
   static PTX anywhere.
4. `persistent_cell_agent_kernel` full port on the quilt command overlay
   (`quilt_command.h`) riding the cudaclaw SPSC queue ABI; then warp
   specialization (dispatch/consensus/merge warps).
5. `quilt_cuda_to_qzt.py` — live arena → `.qzt` exporter.
6. The five laws as a device-side prover (`prove()` kernel over the arena).
7. Cooperative-kernel TICK: `grid_group::sync()` collapses the wavefront's
   multi-pass host loop into one launch (occupancy-sized). Cluster launch
   control (Blackwell CC 10.0 work-stealing) is **next-hardware future** —
   the 4050 is Ada (sm_89), marked and parked.

**Latency targets** (the organ's envelope, `src/volatile_dispatcher.rs`):
quilt op submit 50–100ns (volatile write), round-trip 1–5µs (polling
interval), >10M ops/s theoretical. A TICK that misses these regressed
the organ.

## 12. Organ map (who owns what)

Full continuity mapping with file-level citations: **`docs/ORGAN-MAP.md`**
— every quilt-cuda element traced to the cudaclaw organ it reuses.

| Concern | Owner | quilt-cuda's relation |
|---|---|---|
| Persistent kernel, SPSC queue, sub-µs dispatch | cudaclaw `executor.cu`, `shared_types.h` | pattern carried, referenced; command overlay |
| SmartCRDT engine (RGA, warp-aggregated merge) | cudaclaw `crdt_engine.cuh`, `smartcrdt.cuh` | LWW surface mirrored, engine referenced |
| Ramify: NVRTC, pattern-adaptive branching, bridges | cudaclaw `src/ramify/` | witness-keyed specialization fold |
| Flux→PTX compile + deploy | cudaclaw-bridge (+ cudaclaw `ramify/`) | `EFF_PTX` consumer via Ramify route |
| Latency envelope (50–100ns / 1–5µs / >10M ops/s) | cudaclaw `volatile_dispatcher.rs` | quilt-cuda's TICK budget |
| Structure → `.qzt` export | quilt-cell-bridges `cudaclaw_to_quilt.py` | unchanged; future live-arena sibling |
| The 5+1 opcodes as explicit CUDA | **quilt-cuda** | this repo |
| W13 witness word, consensus cell, fringes | **quilt-cuda** | this repo |
| cudaGraph = compiled cell graph | **quilt-cuda** (the claim, the proof) | this repo |
