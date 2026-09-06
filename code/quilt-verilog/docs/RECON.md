# Recon — mapping the cudaclaw organs before building

Date: 2026-08-27 (AKDT). Lane: CUDA-QUILT. Directive: "a pure ptx/cuda
version for the other side and working with our cudaclaw system and other
operations."

## The organs (all read, none modified)

| Organ | Location | What it is |
|---|---|---|
| cudaclaw (study clone) | `~/projects/study-cudaclaw` | Rust + CUDA. Persistent worker kernel (`kernels/executor.cu`), lock-free SPSC queue in unified memory, warp-level dispatch (lane 0 polls, `__shfl_sync` broadcasts to 31 lanes), SmartCRDT engine (`crdt_engine.cuh`, ~3.4k lines), RGA CRDT (`smartcrdt.cuh`), CellAgent + MuscleFiber (`src/gpu_cell_agent/`), RamifiedRole DNA, LLM kernel optimizer (`installer/`), PTX tooling (`src/ramify/ptx_branching.rs`, `nvrtc_compiler.rs`, `src/cuda_claw/ptx.rs`) |
| cudaclaw (main clone) | `~/projects/study-cudaclaw-main` | Same tree, second clone |
| cudaclaw (researchlocal) | `~/projects/researchlocal/projects/cudaclaw` | Same tree + build artifacts; `SMARTCRDT_INTEGRATION_SUMMARY.md` documents `CMD_SPREADSHEET_EDIT`, CellID, CellValueType |
| cudaclaw-bridge | `~/projects/study-cudaclaw-bridge` | Thin Rust bridge (one `src/lib.rs`). GitHub: SuperInstance/cudaclaw-bridge — "Rust bridge between the Flux→PTX oxide pipeline and cudaclaw GPU execution runtime. Deploys compiled PTX to persistent CUDA kernels with warp-level consensus." `INSIGHT_GPU_RUNTIME.md` = full ecosystem scout report |
| quilt-cell-bridges | `~/projects/quilt-cell-bridges/cudaclaw_to_quilt.py` | Existing exporter: cudaclaw repo structure → `.qzt` Quilt sheet (JSON). 5 primitive cells (CommandQueue, CudaKernel, Agent, DispatchOp, MemoryPage), 32 agent cells (one per warp lane), 8 dispatch op cells, substrate = unified memory |
| quilt-cellular-arch | `~/projects/quilt-cellular-arch/cudaclaw/BRIDGE.md` | The existing bridge doc. Already maps CellAgent fields *implicitly* to the 5 opcodes. Names the 5 laws. Lists what cudaclaw lacks: LINK as typed relationship, VIEW as pure projection, TICK as wavefront, journal, prover |
| GitHub remotes | SuperInstance/cudaclaw (main, 766KB, public), SuperInstance/cudaclaw-bridge (master, 28KB, public) | Verified via `gh api` |

## Key findings lifted straight from the organs

### 1. The persistent-kernel pattern (executor.cu)

- Launch once `<<<1, 32>>>` — one block, one warp; never exits until shutdown.
- Lane 0 = queue manager: polls `queue->head` behind `__threadfence_system()`.
- Lanes 1–31 receive the command via `__shfl_sync()` broadcast; all 32 lanes
  process in parallel through the SmartCRDT engine.
- `__nanosleep(100)` idle backoff; zero `cudaDeviceSynchronize()` in hot path.
- **This is the GPU-resident cell agent**: a warp that stays alive, receives
  ops, and ticks in place. quilt-cuda carries the same pattern.

### 2. Warp consensus already exists there

`executor.cu` reduces success across the warp with
`__ballot_sync(FULL_WARP_MASK, success)`; `crdt_engine.cuh` uses
`__shfl_sync` for warp-aggregated merges, `atomicCAS` for lock-free cell
updates. **One warp = one consensus unit is already cudaclaw's model** —
quilt-cuda names it the *consensus cell* and gives it the W13 witness word.

### 3. CRDTCell (crdt_engine.cuh) — the 32-byte cell

```cpp
struct __align__(32) CRDTCell {
    double    value;      // cell value
    uint64_t  timestamp;  // Lamport clock for ordering
    uint32_t  node_id;    // origin node
    CellState state;
    uint32_t  padding[2];
};
```

LWW conflict resolution at hardware level via `atomicCAS`, ordered by
(timestamp, node_id). quilt-cuda's cell state merges as CRDT ops the same
way; the full engine stays in cudaclaw (referenced, not duplicated).

### 4. The 5 opcodes are implicit in CellAgent (BRIDGE.md's own reading)

- BIND = writing `value`
- TICK = `timestamp` (Lamport) updated each fire
- VIEW = reading `value`
- LINK = `constraint_mask` (which neighbors matter)
- EFFECT = `fiber_affinity` (which kernel runs)

quilt-cuda makes these *explicit opcodes* — that's the gap BRIDGE.md names:
"cudaclaw has a queue, not a graph."

### 5. The 5 laws (quilt-cellular-arch/FRAMEWORK.md)

1. BIND_idempotence
2. LINK_transitivity
3. EFFECT_associativity
4. VIEW_purity
5. TICK_monotonicity

## Toolchain status (honest)

- `nvcc`: **absent** from this WSL. `/usr/local` has no CUDA dir.
- `nvidia-smi`: **absent**. The dxgk bridge is unstable — no GPU runs tonight
  regardless.
- Therefore: quilt-cuda is **written but uncompiled**. No fake compile
  checks. First roadmap item: install the CUDA toolkit and run
  `make ptx` (`nvcc -c --ptx`) as a syntax/ISA check, still without GPU runs.

## What this repo adds (the delta)

1. The 5+1 opcodes as explicit CUDA operations — including FORGET.
2. **cudaGraph as the compiled cell graph** (LINK made structural).
3. The W13 witness layer as a per-cell `uint32` word with OR-union and
   `__ballot_sync` consensus (the consensus cell = one warp).
4. A CRDT merge kernel matching cudaclaw's LWW discipline.
5. The bridge story: Flux→PTX (cudaclaw-bridge) deploys into this substrate;
   `cudaclaw_to_quilt.py` remains the structure exporter — extended by
   reference, never broken.
