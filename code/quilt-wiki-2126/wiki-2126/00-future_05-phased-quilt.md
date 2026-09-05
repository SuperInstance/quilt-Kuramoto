# F7: The Phased Quilt — A substrate that links temporal and spatial origins through theta

**What it does:** A spinning disc — one rotation = one period (clock, relative to t=0), axis orientation = depth (relative to spatial origin). The phase angle theta links the two. The substrate is a quilt of framings.

**The math:** `θ = ωt + φ` — angular velocity × time + phase offset. The substrate is a **fiber bundle**:

- **Base space** = cell graph
- **Fiber** = each cell's local frame
- **Connection** = LINK between cells (transform)
- **Curvature** = wound (a cell whose frame doesn't agree with its neighbors)
- **Holonomy** = journal (the angle rotated around a closed loop)
- **Cowboy heals curvature** (wound healing)

**The 5 opcodes as transforms:**

- BIND: name → value (labeling)
- LINK: cell → cell (relational)
- EFFECT: inputs → outputs (functional)
- VIEW: state → projection (projection)
- TICK: moment → next moment (temporal)

**The 5 framings (the 6 tiers as framings):**

| Tier | Framing | Holonomy | Cost | Latency |
|---|---|---|---|---|
| Totipotent | 2D plane (full view) | full | 1.0 | 2s |
| Multipotent | 1D line (scoped) | partial | 0.4 | 800ms |
| Differentiated | tangent vector | restricted | 0.15 | 300ms |
| Sclerotic | trivial (no rotation) | zero | 0 | 1ms |
| Synovial | the seam itself | variable | variable | variable |

**The 5 laws as holonomy constraints:**

1. BIND_idempotence — 1-cell loop = 0
2. LINK_transitivity — chains compose
3. EFFECT_associativity — grouping is irrelevant
4. VIEW_purity — VIEW's holonomy = 0
5. TICK_monotonicity — TICK's holonomy ≥ 0

**Marked:** REAL (fiber bundle math since the 19th century), STRETCH (the cellular actualization)

---

## Calculations required

- **[C5: Spline Phase-Coupling](../01-calculations/05-spline-phase-coupling.md)** — the theta linking
- **[C1: Bending-Energy Minimization](../01-calculations/01-bending-energy.md)** — the holonomy is a spline

## Mathematics required

- **[M1: Cubic Spline](../02-mathematics/01-cubic-spline.md)** — the holonomy is a spline
- **[M2: Euler Elastica](../02-mathematics/02-euler-elastica.md)** — the full spline

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — every opcode is a transform; the 5 transforms are 5 framings
- **[F0c: The 6 Tiers](../03-foundations/03-the-6-tiers.md)** — the 6 tiers are 6 framings
- **[F0e: The 6 Lifecycle Stages](../03-foundations/05-the-6-stages.md)** — the curvature heals (wound healing) over the lifecycle

---

*"The substrate is a quilt of framings. The math is theta. The journal is the holonomy. The 5 laws are holonomy constraints. The 4 tiers are 4 framings. The 5th tier is the synovial tier — the seam itself, the cell at the joint. The cowboy reads the holonomy. The wound is curvature. Heal the wound, restore flatness."*
