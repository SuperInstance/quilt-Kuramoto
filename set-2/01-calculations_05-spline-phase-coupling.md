# C5: The Spline Phase-Coupling — Theta links temporal and spatial origins

**What it calculates:** Given a substrate of cells with local frames, compute the holonomy around any closed loop.

**The math:**

- `θ = ωt + φ` — the phase angle linking time and depth
- `ω` = angular velocity
- `t` = time
- `φ` = phase offset
- The holonomy around a closed loop = `∮ (dθ/dt) dt = ∮ ω dt`

**The deep fact:** A spinning disc has two kinds of "origin":

- **Temporal origin** = `t = 0` (when the spin started)
- **Spatial origin** = the axis orientation (the depth direction)

The phase angle `θ` links them. A single rotation = one period (clock, relative to t=0). The axis orientation = depth (relative to spatial origin). Phase = the link.

**The substrate as a fiber bundle:**

- **Base space** = the cell graph
- **Fiber** = each cell's local frame (a copy of SO(3))
- **Connection** = the LINK between cells (a transform)
- **Curvature** = wound (a cell whose frame doesn't agree with its neighbors)
- **Holonomy** = journal (the angle rotated around a closed loop)

**The 5 laws as holonomy constraints:**

1. BIND_idempotence — 1-cell loop = 0
2. LINK_transitivity — chains compose
3. EFFECT_associativity — grouping is irrelevant
4. VIEW_purity — VIEW's holonomy = 0
5. TICK_monotonicity — TICK's holonomy ≥ 0

**The cowboy heals curvature:** When two neighboring cells have frames that don't agree, the cowboy applies wound healing (recalls the lineage, regrows the blastema, dedifferentiates the root). The wound is curvature. Healing is restoring flatness.

**Marked:** REAL (fiber bundle math since the 19th century)

---

## Required for

- **[F7: The Phased Quilt](../00-future/05-phased-quilt.md)** — the phased quilt IS the calculation

## Mathematics required

- **[M6: Euler Characteristic](../02-mathematics/06-euler-characteristic.md)** — the holonomy is a winding number; `2π`-counts are topological and survive smoothing (WIRING CORRECTED 2026-08-31 by examples/spline_phase.py — previously this section listed M1/M2)
- **[M1: Cubic Spline](../02-mathematics/01-cubic-spline.md)** — the shape of the fiber the phase rides
- **[M2: Euler Elastica](../02-mathematics/02-euler-elastica.md)** — the shape under load

**Correction note (2026-08-31):** M1/M2 shape the fiber; the *holonomy itself* rests on the Umlaufsatz/Gauss–Bonnet family (M6). Verified: a 12-cell closed spline carries holonomy `2π·1.0000`; mixed-sign TICK cancels it to exactly `0.00` — TICK_monotonicity is load-bearing, not decorative.

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — every opcode is a transform
- **[F0c: The 6 Tiers](../03-foundations/03-the-6-tiers.md)** — the 6 tiers are 6 framings
