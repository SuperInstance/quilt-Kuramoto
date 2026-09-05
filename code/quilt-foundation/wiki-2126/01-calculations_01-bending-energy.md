# C1: The Bending-Energy Minimization — The batten finds the fair line

**What it calculates:** Given a set of points in 2D, find the smoothest curve that passes through them all.

**The math:** `E = (1/2) B ∫ κ² ds`

- `B` = flexural stiffness of the batten (wood)
- `κ` = curvature at each point
- `ds` = arc length element
- `E` = bending energy (what the batten minimizes)

**The approximation:** With small slopes, `∫κ²ds ≈ ∫(y″)²dx` and the minimizer through given points is exactly the **cubic spline** of numerical analysis.

**The exact form:** Without small-slope approximation, the minimizer is the **Euler elastica** — a beautiful nonlinear object (Birkhoff and de Boor worked this out in 1965).

**Why this is the calculation for the Splined Lantern:**

A shipwright's batten is a thin elastic strip. Pinned through stations (the points), it settles into the shape that minimizes bending energy. This is the **same math** as the splined surfaces of the Lofted Crystal. The batten IS the spline. The spline IS the batten.

**Marked:** REAL (Birkhoff & de Boor 1965)

---

## Required for

- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** — the inner loom is a batten
- **[F7: The Phased Quilt](../00-future/05-phased-quilt.md)** — the holonomy is a spline

## Mathematics required

- **[M1: Cubic Spline](../02-mathematics/01-cubic-spline.md)** — the small-slope minimizer
- **[M2: Euler Elastica](../02-mathematics/02-euler-elastica.md)** — the full nonlinear minimizer

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — BIND/LINK place the points; EFFECT traces the spline; VIEW projects it; TICK advances
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — VIEW_purity: the projection doesn't change the spline
