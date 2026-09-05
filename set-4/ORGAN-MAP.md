# ORGAN-MAP — how each existing cudaclaw organ maps into quilt-cuda

The continuity document. Nothing here was rediscovered — every element of
quilt-cuda traces to an organ that already exists, cited by file. The fleet
should read this as: **quilt-cuda is a consumer of cudaclaw's engineering,
expressed in the quilt vocabulary.**

Companion to `docs/QUILT-CUDA.md` (the design) and `docs/RECON.md` (the
initial scan). Source of truth: `SuperInstance/cudaclaw` @ main, studied
via the local clones (24k lines).

---

## The map, organ by organ

| # | Organ (file) | What it already does | quilt-cuda mapping |
|---|---|---|---|
| 1 | Lock-free SPSC command queue — `kernels/shared_types.h` (`CommandQueue`, `Command`; volatile `head`/`tail` at offsets 48992/48996) | Producer (Rust) writes head, consumer (GPU) writes tail; volatile ops ~2–5ns vs ~50–100ns atomics; `commands_sent`/`commands_processed` counters | **The TICK/command path.** `src/quilt_command.h` defines the `QuiltCommand` u64 overlay that rides this exact queue discipline — no modification to `shared_types.h`. The persistent cell agent dequeues quilt ops; one TICK = one drain of the queue. |
| 2 | Persistent worker kernel — `kernels/executor.cu` (lane-0 poll, `__shfl_sync` broadcast, `__nanosleep(100)`, `__threadfence_system`) | 1 block / 1 warp, never exits; sub-µs dispatch | `persistent_cell_agent_kernel` in `quilt_cells.cu` carries the shape, credited. Its evolution is **warp specialization** (below). |
| 3 | Warp consensus — `executor.cu` `__ballot_sync(FULL_WARP_MASK, success)`; `crdt_engine.cuh` `__shfl_sync` merges | 32 lanes act as one consensus unit, already | `warp_vote_kernel`: the named **consensus cell** — 32 lanes = one warp = one cell; ballot re-derives the witness word; `popc/32` = consensus; fringes 0.9989 / 0.9004 (§8 of the design). cudaclaw voted on success; quilt votes on witness. |
| 4 | SmartCRDT — `kernels/crdt_engine.cuh` (CRDTCell 32B, warp-aggregated merge), `smartcrdt.cuh` (RGA), `crdt_functions.cuh` | `(timestamp, node_id)` LWW at `atomicCAS` level | `crdt_merge_kernel`: same ordering discipline, simplified surface (caveat documented in-source). Losing witnesses still union — observation never discarded. Full engine stays in cudaclaw. |
| 5 | **Ramify engine** — `src/ramify/` (`mod.rs` RamifyEngine, `ptx_branching.rs`, `nvrtc_compiler.rs`, `shared_memory_bridge.rs`, `resource_exhaustion.rs`) | DNA-driven NVRTC kernel manager; `DataPatternObserver` (`AccessWindow`, `detect_pattern()`) → `PtxTemplate.specialize()` → `BranchRegistry` caches by `(template_id, pattern)` — `nvrtc_cache` keyed `"{template_id}_{pattern:?}"` (`mod.rs:328`); in-process CUDA→PTX in 10–50ms, `cust::Module::from_ptx`, no filesystem | **Witness-keyed specialization** — the delta mapping, below. `EFF_PTX` (roadmap) routes through Ramify's `PtxBranchCompiler`, not raw static PTX. |
| 6 | Volatile dispatcher — `src/volatile_dispatcher.rs` (submit ~50–100ns, round-trip ~1–5µs, no locks/atomic-RMW on hot path) | The latency envelope quilt-cuda must live inside | **The latency targets** (table below). A quilt TICK that misses these numbers regressed the organ. |
| 7 | MuscleFiber — `src/gpu_cell_agent/muscle_fiber.rs` (CellUpdate/CrdtMerge/FormulaEval/BatchProcess/IdlePoll) | Cell assigned a kernel variant by access pattern | `body_op` in the arena — same doctrine, one field: the cell's algorithmic body selects its fiber. |
| 8 | CellAgent — `src/gpu_cell_agent/cell_agent.rs` (value, Lamport, constraint_mask, fiber_affinity, per-cell metrics) | The GPU-resident cell, implicit opcodes | `QuiltArena` rows make the opcodes explicit (BRIDGE.md named this gap; quilt-cuda closes it at the substrate). |
| 9 | cudaclaw-bridge (Flux→PTX oxide pipeline; `cuModuleLoadData` hotswap, VRAM accounting, DeployStatus, warp consensus) | Deploys compiled PTX to persistent kernels without dropping device context | The deployment path for `EFF_PTX` cell bodies. quilt-cuda supplies the arena those kernels operate on; the bridge keeps owning deployment. |
| 10 | `quilt-cell-bridges/cudaclaw_to_quilt.py` + `quilt-cellular-arch/cudaclaw/BRIDGE.md` | Structure → `.qzt` export; the implicit-opcode reading | Unchanged. `.qzt` export is the host-side VIEW; quilt-cuda is the device-side counterpart; future `quilt_cuda_to_qzt.py` is additive. |

## The witness ↔ pattern_hash mapping (the Ramify fold)

Ramify's loop today:

```
DataPatternObserver: AccessWindow.record(cell_index) → detect_pattern()
  → AccessPattern {Sequential|Strided|Random|ColumnMajor|Diagonal|Hotspot|BulkSequential}
  → PtxTemplate.specialize(constants_for_pattern(pattern))
  → BranchRegistry: cache key (template_id, pattern) — mod.rs:328 "{template_id}_{pattern:?}"
```

quilt-cuda's fold — **the witness change set becomes the pattern signal**:

```
witness[c] at tick T  and  witness[c] at tick T-1
  → delta = witness[T] & ~witness[T-1]        (trits that lit this tick)
  → pattern_hash = hash(delta)                 (which state bits moved)
  → BranchRegistry key: (body_op template_id, pattern_hash)
```

Why this is the right splice:

- The witness word already records *what changed in the cell's state* —
  Ramify's `AccessWindow` infers behavior from *where accesses landed*;
  the witness observes it directly, per cell, in one u32.
- W marks carry phase: `W_DIRTY` set = the cell is hot (Ramify's Hotspot
  pattern, but per-cell instead of per-window); unchanged witness across
  ticks = cold = no re-specialization — and `BranchRegistry::set_cooldown`
  already exists for exactly that hysteresis.
- Same compiler, same cache, same registry: only the observer changes.
  Ramify compiles; the witness watches.

Concretely (roadmap item 3, revised): `EFF_PTX` body ops specialize via
`PtxBranchCompiler` keyed on witness deltas, compiled in-process by
`nvrtc_compiler.rs` (10–50ms, cached), hot-swapped through cudaclaw-bridge
without dropping device context. No static PTX anywhere.

## The TICK/command path (the SPSC fold)

The queue IS the opcode stream. `src/quilt_command.h` defines the u64
overlay that rides `kernels/shared_types.h`'s SPSC discipline unchanged:

```
QuiltCommand (u64 doorbell / queue word):
  [63..56] opcode     QOP_BIND | QOP_EFFECT | QOP_VIEW | QOP_TICK | QOP_FORGET | QOP_VOTE | QOP_MERGE
  [55..32] cell_id    24 bits, up to 16.7M cells per GPU (cudaclaw's 1M-cell target fits)
  [31..0]  aux        float bits / param / tick low bits
```

Producer discipline per `shared_types.h`: volatile write to `head`,
consumer (persistent agent, lane 0) polls behind `__threadfence_system()`,
acknowledges via `tail`, `commands_processed` counts TICKs drained. The
existing `CMD_*` enum is untouched — quilt commands are a namespace on the
auxiliary word, not a modification.

## Latency targets (the volatile-dispatcher fold)

The organ's measured envelope (`src/volatile_dispatcher.rs:14-15`) is
quilt-cuda's budget:

| Path | Target | Organ precedent |
|---|---|---|
| Quilt op submit (host→device) | **50–100ns** | volatile write to `head`, no atomic RMW |
| Quilt op round-trip (submit→witness-visible) | **1–5µs** | GPU polling interval (`__nanosleep(100)`) |
| Sustained TICK/command rate | **>10M ops/s theoretical** | queue's lock-free drain |
| Cross-boundary ordering | `__threadfence_system()` cost, not a lock | `executor.cu` hot-path rule: zero `cudaDeviceSynchronize()` |

Design consequence already honored: `tick_wavefront_kernel`'s wavefront is
device-resident *because* a host-in-the-loop wavefront can't meet 1–5µs;
the graph path (`cudaGraphLaunch`) is the batch-TICK compromise CUDA gives
us for free. A missed target = a regression against the organ, and the
demo (when it runs) prints measured numbers next to these.

## The PTX frontier (folded, with hardware honesty)

| Frontier item | Status in quilt-cuda |
|---|---|
| **Warp specialization** (DeepSeek-scale: dedicated IB-send / NVLink-forward / MoE-gating warps; dynamic warp counts) | Design note now, implementation post-nvcc: `persistent_cell_agent_kernel` evolves into **role-dedicated warps** — a dispatch warp (queue lane-0 poll), consensus warp(s) (ballot/vote), merge warp (CRDT). The 4050's SMs host them; dynamic warp counts stay a knob. |
| **Cluster launch control** (Blackwell CC 10.0 work-stealing/preemption) | **FUTURE — marked.** Our 4050 is Ada (sm_89), not Blackwell. Cluster-level preemption of the wavefront is a next-hardware roadmap line, not a tonight claim. |
| **Dry-run to defeat lazy module loading** (launch non-persistent once before going persistent) | Roadmap note for the demo: dry-run `graph_cell_step_kernel` once so the first real TICK doesn't pay module-load. |
| **Cooperative kernels for grid-wide sync** | The alternative TICK: `cooperative_groups::grid_group::sync()` collapses `tick_wavefront_kernel`'s multi-pass host loop into one launch (sync between fire and release phases each level). Requires `cudaLaunchCooperativeKernel` + occupancy-sized launch — noted as the upgrade path; the current multi-pass form needs no cooperative support and runs anywhere. |
| **PTX-direct for critical sections** | Where the witness hot path goes if 50–100ns submit ever becomes the floor: hand-PTX the queue word CAS. Ramify's template system is the delivery vehicle. |

## Do-not-break contract (unchanged)

cudaclaw, cudaclaw-bridge, quilt-cell-bridges: referenced by file, extended
by overlay, never modified. This repo's deltas are additive: the opcode
vocabulary, the witness word, the graph-as-LINK claim, and the mappings
above.
