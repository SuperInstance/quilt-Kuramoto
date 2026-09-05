# C2: The Stationary-Time Refraction — Light's path of least time

**What it calculates:** Given a refractive index field `n(r)` and two points A and B, find the path that light takes from A to B.

**The math:** `T = (1/c) ∫ n(r) ds`

- `T` = total travel time
- `c` = speed of light in vacuum
- `n(r)` = refractive index at point r
- `ds` = arc length element
- The path **r**(s) extremizes T (almost always minimizes it)

**Fermat's principle:** Among all paths from A to B, light takes the one that makes the travel time stationary.

**Why this is the calculation for the Splined Lantern:**

The Splined Lantern is a piece of glass with a carefully sculpted refractive index field. When light enters, it bends along the path of stationary time. The path is the *answer*. The frosted pad where the light lands IS the answer's position.

**The deep fact:** Light doesn't *calculate* the answer and then travel it — the traveling *is* the calculating. Every ray in every lens in the world has already solved a boundary-value problem by the time it lands.

**Marked:** REAL (Fermat 1657, formalized in the 18th century)

---

## Required for

- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** — the inner loom is a stationary-time computer
- **[F2: The Hearth Loop](../00-future/02-hearth-loop.md)** — the new index gives a new stationary-time path
- **[F5: The Chlorophyll Quilt](../00-future/04-chlorophyll-quilt.md)** — bioluminescent photons follow Fermat

## Mathematics required

- **[M3: Fermat's Principle](../02-mathematics/03-fermat.md)** — the formal statement
- **[M4: Snell's Law as Conservation](../02-mathematics/04-snell-momentum.md)** — the local rule

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — VIEW of the cell IS the light's landing pad
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — TICK_monotonicity: time moves forward
