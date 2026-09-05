# approximation-theory

Approximation theory in Rust. Interpolation, splines, and Chebyshev polynomials.

> **50+ tests** · depends on `nalgebra` + `serde`

---

## What This Does

A pure-Rust approximation theory toolkit covering the full pipeline:

- **Interpolation**: Lagrange and Newton divided-difference polynomials.
- **Splines**: Cubic spline interpolation with natural or clamped boundary conditions.
- **Least Squares**: Linear regression and polynomial least-squares with R² goodness-of-fit.
- **Chebyshev Bases**: Evaluation of Chebyshev polynomials T_n(x), derivatives, nodes, and extrema.
- **Remez Algorithm**: The exchange algorithm for minimax (best-uniform) polynomial approximation.
- **Fourier Approximation**: Truncated Fourier series via numerical integration.
- **Padé Approximants**: Rational function [m/n] approximation from Taylor coefficients.
- **Error Bounds**: Runge phenomenon estimation, Lebesgue constant computation.

---

## Install

Add to your `Cargo.toml`:

```toml
[dependencies]
approximation-theory = "0.1"
```

Dependencies: `nalgebra` (linear algebra), `serde` (serialization).

---

## Quick Start

```rust
use approximation_theory::{
    interpolation, spline, least_squares, chebyshev, fourier, pade, remez, error_bounds,
};

// Lagrange interpolation
let xs = vec![0.0, 1.0, 2.0];
let ys = vec![0.0, 1.0, 4.0]; // y = x²
let val = interpolation::lagrange(&xs, &ys, 1.5);
assert!((val - 2.25).abs() < 1e-10);

// Cubic spline (natural)
let spline = spline::CubicSpline::new(
    &[0.0, 1.0, 2.0, 3.0],
    &[0.0, 1.0, 4.0, 9.0],
    &spline::SplineBoundary::Natural,
);
let mid = spline.eval(1.5);

// Chebyshev nodes
let nodes = chebyshev::chebyshev_nodes(6);

// Remez (minimax degree-1 approximation of x² on [0, 1])
let (coeffs, max_err) = remez::remez(|x| x * x, 1, 0.0, 1.0, 30);

// Padé [2/2] of e^x
let taylor: Vec<f64> = (0..5).map(|k| 1.0 / (1..=k).product::<u64>() as f64).collect();
let approx = pade::pade_approximant(&taylor, 2, 2);
let e1 = approx.eval(1.0); // ≈ 2.718...
```

---

## License

MIT OR Apache-2.0 (at your option).
