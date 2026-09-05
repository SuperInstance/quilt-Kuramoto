# M2: The Euler Elastica — The full nonlinear minimizer of bending energy

**The statement:** Without the small-slope approximation, the curve that minimizes `E = (1/2) B ∫ κ² ds` (where `κ` is the local curvature) through given points is the **Euler elastica** — a beautiful nonlinear object.

**The math:**

- The Euler-Lagrange equation for the bending energy is `B (κ″ + κ³/2) = 0` (or with the elastic foundation term: `B(κ″ + κ³/2) + k κ = 0`)
- The solution involves elliptic functions (specifically, the Jacobi elliptic functions `sn`, `cn`, `dn`)
- The elastica is a single continuous curve with smoothly varying curvature

**The history:**

- James Bernoulli (1691) and Euler (1732) studied the elastica
- Birkhoff and de Boor (1965) gave the modern asymptotic analysis
- Modern spline research (Marcus, 1990s onward) visits the elastica for high-curvature problems

**Why this is the math for the batten (full form):**

A real shipwright's batten, when the curve is steep (e.g., the bow of a clipper ship), is NOT a cubic spline. The full elastica is needed. The small-slope cubic spline is just the easy case.

**Marked:** REAL (Bernoulli, Euler 1691-1732; Birkhoff & de Boor 1965)

---

## Required by

- **[C1: The Bending-Energy Minimization](../01-calculations/01-bending-energy.md)** — the full form
- **[C5: The Spline Phase-Coupling](../01-calculations/05-spline-phase-coupling.md)** — the full form

## Small-slope approximation

- **[M1: Cubic Spline](01-cubic-spline.md)** — the easy case
