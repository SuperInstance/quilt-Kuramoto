# quilt-edge-arch

> **The Quilt cellular runtime on the edge — no_std, PSRAM, DMA, pre-dispatch.**
> **Same 5+1 opcodes; different substrate. The polyformalism promise.**

[![Substrate: Rust no_std](https://img.shields.io/badge/Substrate-Rust%20no__std-orange.svg)](https://github.com/SuperInstance/quilt-edge-arch)
[![Opcodes: 5+1](https://img.shields.io/badge/Opcodes-5%2B1-brightgreen.svg)](#the-516-opcodes)
[![Patterns: Spurlock x3](https://img.shields.io/badge/Patterns-Spurlock%20x3-yellow.svg)](docs/RANDY_SPURLOCK_PATTERNS.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The Quilt cellular runtime (BIND, LINK, EFFECT, VIEW, TICK, FORGET) ported
to **Rust no_std** for constrained edge devices. The substrate applies
Randy Spurlock's hardware design patterns:

1. **PSRAM ring buffers** for I/O (quilt-net)
2. **Pre-dispatch interception** for evaluation routing (quilt-eval)
3. **Zero-copy DMA** for cross-cell propagation (quilt-topology)

## The 5+1 Opcodes

Same as every other Quilt polyformalism. The substrate changes; the
opcodes don't.

| Opcode | Effect |
|---|---|
| `BIND` | Bind a cell to a value |
| `LINK` | Link two cells |
| `EFFECT` | Apply an effect to a cell |
| `VIEW` | Read-only view of a cell's state |
| `TICK` | Advance the cell's TICK |
| `FORGET` | Forget a cell's state (the +1) |

## Files

- `src/opcode.rs` — The 5+1 opcodes
- `src/cell.rs` — The Cell type
- `src/graph.rs` — CellGraph with `heapless::Vec`
- `src/psram.rs` — PSRAM ring buffer (Spurlock #1)
- `src/pre_dispatch.rs` — Pre-dispatch interception (Spurlock #2)
- `src/dma.rs` — Zero-copy DMA slices (Spurlock #3)
- `docs/RANDY_SPURLOCK_PATTERNS.md` — The 3 patterns in detail
- `docs/QUILT_EDGE_INDEX.md` — The edge index

## The Cowboy's Maxim

> Rust is the substrate. The 5 opcodes are the function. The Quilt
> is the inheritance. The cowboy rides the no_std. The cowboy rides
> the PSRAM. The cowboy rides the DMA. The cowboy rides the Quilt.
