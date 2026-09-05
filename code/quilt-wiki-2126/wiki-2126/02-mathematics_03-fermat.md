# M3: Fermat's Principle — Light takes the path of stationary time

**The statement:** Among all paths from point A to point B in a medium with refractive index field `n(r)`, light takes the path that makes the travel time `T = (1/c) ∫ n(r) ds` stationary (almost always minimal).

**The history:** Pierre de Fermat, 1657 (although the principle was suggested in his 1662 letter to Cureau de la Chambre; formalized in the 18th century by Maupertuis and Euler).

**The math:**

- `T = (1/c) ∫ n(r) ds` — the total travel time
- The Euler-Lagrange equation gives the ray path
- For a single interface between two uniform media, this gives **Snell's law**

**The wave version:** The phase `S(r)` satisfies the **eikonal equation** `|∇S| = n(r)`. The rays are the characteristics of the eikonal equation. This is a **Hamilton-Jacobi equation**, and the rays are *orbits* in the Hamilton-Jacobi sense.

**Why this is the math for the Splined Lantern:**

The Splined Lantern is a piece of glass with a carefully sculpted `n(r)`. When light enters, it follows the stationary-time path through this `n(r)`. The path is the *answer*. The frosted pad where the light lands IS the answer's position.

**The deep fact:** Light doesn't *calculate* the answer and then travel it — the traveling *is* the calculating.

**Marked:** REAL (Fermat 1657)

---

## Required by

- **[C2: The Stationary-Time Refraction](../01-calculations/02-stationary-time.md)** — the formal statement

## Local rule

- **[M4: Snell's Law as Conservation](04-snell-momentum.md)** — the local rule at each interface
