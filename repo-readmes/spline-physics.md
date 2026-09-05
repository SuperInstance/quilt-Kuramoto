# spline-physics

> Spline-based beam mechanics with multi-agent debate solvers — where physics equilibrium emerges as consensus.

[![Part of SuperInstance](https://img.shields.io/badge/Part%20of-SuperInstance-blue)](https://github.com/SuperInstance)

Part of the **SuperInstance** fleet.

## Overview

A Rust implementation of Euler elastica beam physics that approaches equilibrium computation through **multi-agent debate**. Instead of a single solver, multiple agents — each using a different computational method (energy minimization, shooting method, analytical reference) — argue about the beam shape. The physically correct answer emerges as a **consensus point** in belief space.

The research hypothesis: beam equilibrium shape is where agents with different priors all agree, and debate convergence is governed by the trust topology's cycle space dimension β₁ = E − V + 1.

## Solvers

| Solver | Method | Status |
|--------|--------|--------|
| `EnergyMinimizationSolver` | Gradient descent on pin positions, ‖∇E‖ < 1e-8 | ✅ |
| `ShootingMethodSolver` | Euler elastica ODE, RK4 + bisection | ✅ |
| `AnalyticalSolver` | Closed-form: T1 (straight), T2 (circular arc), T6 (parabola) | ✅ |

## Multi-Agent Module

- **5 agent roles:** Architect, SpilingAgent, EnergyAgent, ShootingAgent, QualityAgent
- **Spring-damper debate model** — Hooke's law for belief updates
- **Trust topology** — EnergyAgent ↔ ShootingAgent (×1.5), SpilingAgent → Architect (×1.3), QualityAgent discounts all (×0.4)
- **Consensus:** 92% agreement + spread < 5mm

## Installation

```bash
cargo add spline-physics
```

Or clone and build:

```bash
git clone https://github.com/SuperInstance/spline-physics.git
cd spline-physics
cargo build --release
cargo test
```

## Usage

```rust
use spline_physics::*;

// Run the multi-agent beam solver
let example = include_str!("../examples/multi_agent_beam.rs");
// See examples/ for full working code
```

Run the example:

```bash
cargo run --example multi_agent_beam
```

## Project Structure

```
src/
├── lib.rs            # Core types and exports
├── beam.rs           # Beam model and boundary conditions
├── cross_section.rs  # Cross-section geometry
├── material.rs       # Material properties (Young's modulus, etc.)
├── solution.rs       # Solution representation
├── solvers/          # Three independent solver implementations
├── comparison/       # Cross-solver validation
├── multi_agent/      # Multi-agent debate system
└── multi_segment/    # Multi-segment beam support
```

## Research

See [`papers/multi-agent-beam-dissertation.md`](papers/multi-agent-beam-dissertation.md) and [`SPEC.md`](SPEC.md) for the full mathematical framework connecting beam equilibrium to sheaf cohomology and consensus dynamics.

## License

MIT
