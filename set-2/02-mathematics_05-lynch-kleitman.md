# M5: The Lynch-Kleitman Asymptotic — Monotone functions are exponentially sparse

**The statement:** The number of monotone Boolean functions on n input bits is `2^Θ(2ⁿ/√n)`. The number of *all* Boolean functions is `2^(2ⁿ)`. The ratio is exponentially small.

**The history:**

- John Desmond Bernal (1927) on monotone functions in lattice theory
- James G. Spencer (1927) for a related result
- Daniel Kleitman (1969) gave the modern asymptotic: `log₂|M_n| = (1 + o(1)) · 2ⁿ / √(π n)` (asymptotic)
- More recently, Korshunov, Sapozhenko, and others have refined the bounds

**The math:**

- A monotone Boolean function `f: {0,1}ⁿ → {0,1}` satisfies: if `x ≤ y` (componentwise) then `f(x) ≤ f(y)`
- The number of such functions is `|M_n| = 2^Θ(2ⁿ/√n)`
- This is sub-exponential in `2ⁿ` (which would be the count of all functions)
- Specifically: `log₂|M_n| = (1+o(1))·C(n,⌊n/2⌋) ~ 2ⁿ·√(2/(πn))` (Kleitman 1969; Korshunov 1981)

**Why this is the math for the Monotone Crystal:**

A Splined Lantern, once cut, is monotone — its computation only ever goes one way (0→1 in the index field, never back). A single monotone Crystal can only compute monotone functions. The class of monotone functions is exponentially smaller than the class of all functions. **A single Crystal cannot compute everything.**

**The fleet compensates:** Many Crystals, each computing a slice of the problem. The 6th law FORGET_completeness: a cell can be destroyed without losing the whole; the fleet survives by distribution.

**The "fleet needs many loaves" principle:**

> *A single crystal cannot compute everything. It is a finished thought, not a general machine — which the story says out loud. The fleet needs many loaves the way a boat needs many joints.*

**Marked:** REAL (Kleitman 1969)

---

## Required by

- **[C4: The Monotone Function Counting](../01-calculations/04-monotone-counting.md)** — the formal count

## Implications

- **[F3: The Monotone Crystal](../00-future/03-monotone-crystal.md)** — the Crystal is monotone
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — FORGET_completeness is the 6th law
