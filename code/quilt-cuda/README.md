# quilt-cuda

**The GPU already thinks in cell graphs — a CUDA Graph IS quilt's LINK.**

Nodes = kernel instances (BIND'd cells). Edges = dependencies (LINKs).
Instantiate = the LINK set, compiled. Launch = TICK — the wavefront IS the
GPU scheduler doing its day job. Destroy = FORGET.

This is not an analogy. The data structure quilt calls a cell graph is the
data structure CUDA calls a `cudaGraph`. This repo says so loudly and then
proves it in source.

The GPU side of the [quilt](https://github.com/SuperInstance) substrate,
wired to the cudaclaw organs — referenced and extended, never modified.

![banner](assets/banner.jpg)

## The 5+1 opcodes as CUDA operations

| Opcode | Quilt meaning | CUDA operation |
|---|---|---|
| **BIND** | label a value at a key | cell allocation: a device-memory slice `{state, witness_word, lamport, opcode}` |
| **LINK** | relate two cells | `cudaGraphAddKernelNode` + `cudaGraphAddDependencies` — **the compiled cell graph**; also a plain device-side edge list |
| **EFFECT** | run a function | device-side kernel / atomic that mutates world state, sets W_DIRTY, advances the Lamport clock |
| **VIEW** | project state (pure) | `cudaMemcpy` D2H of telemetry — **no device write in the path; purity is structural** |
| **TICK** | advance time (wavefront) | one TICK = one `cudaGraphLaunch` of the instantiated exec; or the Kahn-style `tick_wavefront_kernel` over the edge list |
| **FORGET** | retire a cell (+1) | graph exec/graph destroy, `cudaFree`, device-side zero-and-mark |

## The W13 witness layer

One `uint32` per cell: 30 trit witness bits (the state carries its own
witness) + two W marks (W_BOUND, W_DIRTY). Union is OR — idempotent,
commutative, associative: **the L1 law as a warp-level instruction**.
`__ballot_sync` is that instruction made literal: 32 lane-witnesses become
one word in a single op.

**32 lanes = one warp = one consensus cell.** `warp_vote_kernel` has each
lane vote a bit of the witness word; the ballot re-derives the word from 32
independent observations; `popc/32` is the consensus. The fringes are named
constants: `0.9989` (fleet — needs ≥ 909 lanes ≈ 29 warps, by construction)
and `0.9004` (29/32 clears it in one warp).

## What's here

```
docs/RECON.md          the cudaclaw organs, mapped before building
docs/QUILT-CUDA.md     the design: opcodes, witness layer, CRDT, the bridge
src/quilt_cells.cuh    the substrate ABI
src/quilt_cells.cu     BIND/EFFECT/TICK/FORGET kernels, witness union,
                       warp vote, CRDT merge, persistent-agent sketch
src/quilt_graph.cuh    the compiled-cell-graph ABI
src/quilt_graph.cu     cudaGraph construction from a cell-graph edge list
host_demo.cu           3-cell graph (input -> rsi -> filter), both TICK
                       paths, VIEW, witness chain, warp votes, FORGET
Makefile               make ptx = compile check (needs no GPU)
```

## Honest build status

| Item | Status |
|---|---|
| design + source | **written** |
| compiled | **NO — nvcc is absent from this WSL.** No fake compile checks; first roadmap item is installing the toolkit and running `make ptx` |
| run on GPU | **not attempted** — the dxgk bridge is unstable tonight, by directive no heavy GPU runs |
| banner | generated (DeepInfra sdxl-turbo, navy+amber) |

`make` in this environment prints the honest state instead of pretending.

## The organs (referenced, never broken)

- **[cudaclaw](https://github.com/SuperInstance/cudaclaw)** — the production
  GPU substrate this repo rides on: persistent worker kernel polling a
  lock-free SPSC queue in unified memory (lane 0 polls, `__shfl_sync`
  broadcasts to 31 lanes), SmartCRDT engine with `(timestamp, node_id)` LWW
  discipline, CellAgent + MuscleFiber, RamifiedRole DNA, PTX/NVRTC tooling.
  The persistent kernel that stays resident, receives ops, and ticks in
  place is the GPU-resident cell agent; `persistent_cell_agent_kernel`
  here carries its shape, credited.
- **Ramify engine** (`src/ramify/`) — the fold Riker surfaced: NVRTC
  in-process compile, `PtxBranchCompiler` pattern-adaptive specialization,
  `BranchRegistry` caching. quilt-cuda keys the same registry on **witness
  deltas** — the pattern signal becomes what changed in the cell's state.
  Latency targets inherited from `volatile_dispatcher.rs`: 50–100ns
  submit, 1–5µs round-trip. Full continuity map: `docs/ORGAN-MAP.md`.
- **[cudaclaw-bridge](https://github.com/SuperInstance/cudaclaw-bridge)** —
  the Flux→PTX oxide pipeline's deployer: compiled PTX to persistent CUDA
  kernels with warp-level consensus. Roadmap: an `EFF_PTX` body op here
  loads Flux-compiled cell bodies through cudaclaw's NVRTC path.
- **quilt-cell-bridges / `cudaclaw_to_quilt.py`** — the existing
  structure→`.qzt` exporter. That's a VIEW in quilt's own format (host-side
  projection of the organ); this repo is the device-side counterpart. A
  future `quilt_cuda_to_qzt.py` (live arena → `.qzt`) will be additive.

## Roadmap

1. Install CUDA toolkit in WSL → `make ptx` (compile check, no GPU).
2. When dxgk is stable: run `host_demo` — the witness chain, both TICK paths
   (dry-run first: defeats lazy module loading).
3. `EFF_PTX` via the Ramify route: witness-keyed `PtxBranchCompiler`
   specialization, `BranchRegistry` cache, cudaclaw-bridge hotswap.
4. Full persistent cell agent on the quilt command overlay
   (`src/quilt_command.h`) riding the SPSC queue ABI; then warp
   specialization (dispatch / consensus / merge warps).
5. `quilt_cuda_to_qzt.py` — live arena telemetry → `.qzt`.
6. The five laws as a device-side prover kernel.
7. Cooperative-kernel TICK (grid-wide sync). Cluster launch control =
   Blackwell future (our 4050 is Ada, sm_89).

---

MIT. Part of the SuperInstance quilt fleet.
