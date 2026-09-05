# deadband-rs

**Deadband detection, noise filtering, and constraint-theory math primitives — the numerical backbone of the fleet's tolerance system.**

Rust library with zero dependencies. Implements exact angle arithmetic, Eisenstein lattice quantization, Berlekamp-Massey sequence analysis, and hexagonal sampling — the mathematical primitives needed for deadband-aware signal processing.

## What This Gives You

- **Exact angle arithmetic** — `div360` gives exact integer quotient/remainder for angles, zero floating-point drift
- **Eisenstein lattice** — snap to nearest hexagonal lattice point in Z[ω]
- **Berlekamp-Massey** — find the shortest LFSR generating a binary sequence (anomaly detection)
- **Hexagonal sampling** — uniform random sampling over regular hexagons
- **Fibonacci spiral search** — near-uniform angular coverage in O(√n)
- **2×2 eigendecomposition** — classify dynamics: node, saddle, spiral, center
- **Deadband filtering** — suppress sub-threshold changes: thermostat hysteresis, audio noise gating, constraint tolerance

## Quick Start

```rust
use deadband::div360::div360;
use deadband::eisenstein::snap;
use deadband::bma::berlekamp_massey;

// Exact angle arithmetic — zero floating-point drift
let (q, r) = div360(730);  // (2, 10) — 730° = 2 full rotations + 10°

// Snap to nearest Eisenstein lattice point (hexagonal grid)
let (n, m, err) = snap(3.7, 2.1);

// Find shortest LFSR for a binary sequence
let seq = vec![1, 0, 1, 1, 0, 1, 0, 1, 1];
let (poly, len) = berlekamp_massey(&seq);
```

## Modules

| Module | What It Does |
|--------|-------------|
| `div360` | Exact integer ÷360 — zero drift across 129,600 integer pairs |
| `eisenstein` | Snap to Eisenstein integers (hexagonal lattice Z[ω]) |
| `bma` | Berlekamp-Massey over GF(2) — shortest LFSR for binary sequences |
| `hpdf` | Uniform sampling over regular hexagons (rejection method) |
| `fib_spline` | Fibonacci spiral vector search — near-uniform angular coverage |
| `shell` | 2×2 eigendecomposition — classify dynamics (node, saddle, spiral, center) |

## The Deadband Concept

A deadband filter suppresses changes below a perceptibility threshold:

```
|Δ| ≤ k  →  not perceivable → output stays
|Δ| > k  →  perceivable     → output passes through
```

This is thermostat hysteresis, audio noise gating, and constraint tolerance — the same idea. If the change doesn't matter, don't propagate it.

## Features

| Feature | Default | Description |
|---------|---------|-------------|
| `python` | off | Python bindings via PyO3 |
| `simd` | off | SIMD-accelerated filters |

## Testing

```bash
cargo test
cargo run  # interactive demo of all modules
```

## Installation

```toml
[dependencies]
deadband = { git = "https://github.com/SuperInstance/deadband-rs" }
```

## How It Fits

Part of the SuperInstance ecosystem:

- **[spectral-deadband](https://github.com/SuperInstance/spectral-deadband)** — Deadband as the spectral gap
- **deadband-rs** — Numerical primitives (this repo)

## License

Apache-2.0
