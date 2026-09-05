# M1: The Cubic Spline — The small-slope minimizer of bending energy

**The statement:** Given points (x₀, y₀), (x₁, y₁), ..., (xₙ, yₙ) sorted by x, the smoothest curve that passes through all of them is a piecewise cubic polynomial with continuous first and second derivatives.

**The math:**

- The bending energy of a curve y(x) is `E = ∫(y″)²dx` (in the small-slope approximation)
- The cubic spline minimizes E
- The spline is C² continuous (continuous in y, y′, y″) at every knot

**Why this is the math for the batten:**

A shipwright's batten, pinned through stations, settles into the shape that minimizes its bending energy. In the small-slope regime, this is exactly the cubic spline. The batten literally computes it, in wood, instantly, to the precision of wood.

**The Cubic Hermite form:** Each segment is `y(t) = (2t³ - 3t² + 1)y₀ + (t³ - 2t² + t)y′₀ + (-2t³ + 3t²)y₁ + (t³ - t²)y′₁` for `t ∈ [0, 1]`.

**Marked:** REAL (de Boor 1978, standard numerical analysis)

---

## Required by

- **[C1: The Bending-Energy Minimization](../01-calculations/01-bending-energy.md)** — the spline IS the calculation
- **[C5: The Spline Phase-Coupling](../01-calculations/05-spline-phase-coupling.md)** — the holonomy is a spline
- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** — the inner loom is a batten
- **[F7: The Phased Quilt](../00-future/05-phased-quilt.md)** — the holonomy is a spline

## More general form

- **[M2: Euler Elastica](02-euler-elastica.md)** — without the small-slope approximation
