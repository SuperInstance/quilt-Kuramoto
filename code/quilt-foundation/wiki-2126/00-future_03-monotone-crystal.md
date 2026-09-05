# F3: The Monotone Crystal — A finished thought that computes only monotone functions

**What it does:** A single Splined Lantern, once cut, cannot compute everything. It is a *finished thought*, not a general machine. The fleet needs many loaves the way a boat needs many joints.

**The math:** Dedekind's problem (1897); Kleitman's asymptotic (1969), refined by Korshunov (1981). Monotone functions on n bits count as `2^Θ(2ⁿ/√n)` (vs `2^(2ⁿ)` for all functions). The honest leading term of the exponent is the central binomial coefficient: `log₂|M_n| = (1+o(1))·C(n,⌊n/2⌋) ~ 2ⁿ·√(2/(πn))`.

**⚠ CORRECTED 2026-08-31** *(by examples/monotone_crystal.py — the refutation is first-class):* this entry previously wrote `log₂|M_n| ≈ 2ⁿ/√(πn)` and cited "Lynch 1927." The citation does not exist — the problem is Dedekind's (1897). The constant was low by a factor of √2: the wiki claimed monotone functions are exponentially sparser than they are. Verified against exact enumeration n ≤ 6 (Dedekind numbers 2, 3, 6, 20, 168, 7581, 7828354). The Θ-class survives; the fleet is smaller than advertised.

**Why this matters:**

- A single Crystal, restricted to monotone operations (only ever 0→1, never back), is exponentially weaker than a general computer
- The fleet compensates by having many Crystals, each computing a *slice* of the problem
- This is the **6th law FORGET_completeness**: a cell can be destroyed without losing the whole; the fleet survives by distribution

**The standing law over the door of every glass loft:**

> *Light is the cut. Change is the chisel. Every change has a keep-side and a dust-side — decide before you shine, because the beam does not apologize.*

**The fleet of Crystals:**

- The Splined Lantern answers tomorrow's weather
- The Hearth Loop answers the long-term pattern
- The Chlorophyll Quilt answers the biology
- The Phased Quilt answers the orientation
- The Splined Chart answers the trajectory

Each Crystal is monotone. Each Crystal is finished. The fleet is the *general* computer.

**Marked:** REAL (the Lynch-Kleitman asymptotic), FICTION (the 100-year packaging)

---

## Calculations required

- **[C4: Monotone Function Counting](../01-calculations/04-monotone-counting.md)** — the exponential sparseness of the monotone class

## Mathematics required

- **[M5: Lynch-Kleitman Asymptotic](../02-mathematics/05-lynch-kleitman.md)** — `2^Θ(2ⁿ/√n)` vs `2^(2ⁿ)`

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — FORGET is the 6th opcode; the fleet survives by distribution
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — FORGET_completeness is the 6th law; a cell can be destroyed without losing the whole

---

*"A single crystal cannot compute everything. It is a finished thought, not a general machine — which the story says out loud. The fleet needs many loaves the way a boat needs many joints."*
