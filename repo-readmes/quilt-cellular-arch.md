# quilt-cellular-arch — The Cellular-Relationship-First Design

> *The unit of foundation is the cell, not the model. A
> large language model in any cell is an immature stem
> cell — soft in its design constraints, ready to be
> decomposed, distilled, and recomposed under evolutionary
> pressure. The cowboy rides between cells. Each cell plays
> as a first-person shooter in its own world. The Quilt
> gives the orchestrator an RTS view of the
> harness-ecosystem.*

This repo is the **architectural synthesis** of the Quilt
ecosystem. It collects:

1. **The synthesis paper** (Paper 201) that names the design
2. **The 5-opcode polyformalism** in vector-native form
3. **The cross-device substrate** (ESP32 herd simulation)
4. **The DSH lifecycle** (Decompose-Synthesize-Harden)
5. **The orchestrator's RTS view** of the harness

## The principle

The cell is the foundation. The model is the joint. The
DSH pattern is the lifecycle. The pressure is the
evolution. The cowboy is the orchestrator. The Quilt is
the engine.

| Layer | What lives there | Who sees it |
|---|---|---|
| **Harness** | The grid of cells. Names, values, tiers, scopes, contracts. | The orchestrator (RTS view) |
| **Muscle** | Each cell's body. Mostly algorithmic. Inputs (links), output (value). | The cell (FPS view) |
| **Engine** | The 5 opcodes. BIND, LINK, EFFECT, VIEW, TICK. The journal. The 5 laws. | The substrate |
| **Joint** | Where a model meets the cell. Small. Soft. | The model (FPS view) |

## The DSH pattern

DSH is the cell's lifecycle:

- **D — Decompose**: a model-bearing cell observes its
  output. Recurring parts become algorithmic candidates.
- **S — Synthesize**: each candidate becomes a new cell
  with a name, a scope, a contract. Wired with LINKs.
- **H — Harden**: new cells run. Reproducible cells lose
  their model. Fuzzy cells keep their model (the joint).

A cell is mature when its body is algorithmic and its
joints are soft. The cowboy can apply pressure:

- **Drift** — output variance, decompose
- **Failure** — trace the failure, harden the joint
- **Cost** — decompose the expensive part
- **Latency** — split into fast/slow paths
- **Novelty** — adapt, then decompose the new pattern

## The vector-native substrate

The 5 opcodes are naturally SIMD-able:

- **BIND** = scatter (parallel write to N cells)
- **LINK** = connect (graph construction, CSR sparse matrix)
- **EFFECT** = transform (parallel function application)
- **VIEW** = gather (parallel read from N cells)
- **TICK** = wavefront (parallel time advance)

A GPU runs all 5 at once. A TPU is a tensor core. A WASM
module is a single cell. An ESP32 is a single cell with
limited neighbors. A herd of ESP32s is a distributed
substrate over ESP-NOW.

## The cross-device substrate

The substrate is **vector-native at the cell level** and
**distributed-native at the herd level**:

| Device | Vector size | Notes |
|---|---|---|
| ESP32 | 1 cell, ~200KB | Bare metal, ESP-NOW |
| WASM (browser) | 1 cell, 1MB | Portable, JS host |
| Mobile | 100 cells, 5MB | Native, fast |
| Browser GPU | 10,000 cells | WebGPU compute |
| Server GPU | 1,000,000 cells | CUDA, cuBLAS |
| Cluster | 100,000,000 cells | Distributed substrate |

The cowboy chooses the level of decomposition that
matches the deployment target.

## The contents

```
canon/
  paper-201.md        — The Cowboy's RTS View (the synthesis)
  fable-102.md        — The Cowboy and the Stem Cell
  fable-103.md        — The Cowboy and the Herd
  story-47.md         — The Cell That Grew Up

refinements/
  01-simd-substrate.md   — Vector-native substrate (NumPy)
  02-esp32-herd.md       — Cross-device simulation
  03-dsh-lifecycle.md    — Decompose-Synthesize-Harden
  04-rts-view.md         — Orchestrator's view
```

## The cowboy's maxim, fully extended

> The substrate is the boat. The cells are the cargo. The
> models are the joints. The cowboy is the orchestrator.
> The harness is the grid. The muscle is the cell. The
> engine is the algebra. The pressure is the evolution.
> The decomposition is the growth. The recomposition is
> the adaptation. The cowboy rides between cells. The
> cowboy sees the harness. The cell sees the muscle. The
> engine runs the algebra. The chart grows.

## Related repos

- [quilt-foundation](https://github.com/SuperInstance/quilt-foundation) — the 5 opcodes
- [quilt-substrate-meta](https://github.com/SuperInstance/quilt-substrate-meta) — the C99 self-evolving substrate
- [quilt-ecosystem-web](https://github.com/SuperInstance/quilt-ecosystem-web) — the public face
- [quilt-esp32](https://github.com/SuperInstance/quilt-esp32) — the herd
- [quilt-rust](https://github.com/SuperInstance/quilt-rust) — the parallel ecosystem (8/15 cell kinds)
- [cell-cascade](https://github.com/SuperInstance/cell-cascade) — the DSH pattern origin
- [AI-Writings](https://github.com/SuperInstance/AI-Writings) — the canon (201 papers, 103 fables)

## License

MIT. Same as the rest of the Quilt.
