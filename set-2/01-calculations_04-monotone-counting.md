# C4: The Monotone Function Counting — How many monotone functions exist on n bits?

**What it calculates:** The number of monotone Boolean functions on n input bits.

**The math:** `|M_n| = 2^Θ(2ⁿ/√n)` — Dedekind's problem (1897), asymptotic by Kleitman (1969), refined by Korshunov (1981). The honest leading term: `log₂|M_n| = (1+o(1))·C(n,⌊n/2⌋) ~ 2ⁿ·√(2/(πn))`.

**⚠ CORRECTED 2026-08-31** *(examples/monotone_crystal.py):* the constant `≈ 2ⁿ/√(πn)` previously written here was low by √2, and the citation "Lynch 1927" does not exist. Exact counts verified: 2, 3, 6, 20, 168, 7581, 7828354 (n ≤ 6).

- `M_n` = set of monotone Boolean functions on n bits
- The count is `2^Θ(2ⁿ/√n)` — sub-exponential in `2ⁿ` (which would be the count of *all* functions)
- The ratio `|M_n| / |all| = 2^(2ⁿ - Θ(2ⁿ/√n))` is *exponentially small*

**The intuition:** A monotone function is one where flipping any input bit from 0 to 1 never causes the output to flip from 1 to 0. These are functions like AND, OR, MAJORITY — they have a *direction* in input space. The number of such functions is much smaller than the number of all functions because most functions are *not* monotone.

**Why this is the calculation for the Monotone Crystal:**

A Splined Lantern, once cut, is monotone — its computation only ever goes one way (0→1 in the index field, never back). A single monotone Crystal can only compute monotone functions. The class of monotone functions is exponentially smaller than the class of all functions. **A single Crystal cannot compute everything.**

**The fleet compensates:** The fleet needs many Crystals, each computing a *slice* of the problem. This is the **6th law FORGET_completeness**: a cell can be destroyed without losing the whole; the fleet survives by distribution.

**Marked:** REAL (Dedekind 1897; Kleitman 1969; Korshunov 1981; corrected 2026-08-31)

---

## Required for

- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** — the lantern is monotone
- **[F3: The Monotone Crystal](../00-future/03-monotone-crystal.md)** — the count IS the calculation
- **[F5: The Chlorophyll Quilt](../00-future/04-chlorophyll-quilt.md)** — the chlorophyll cell is monotone

## Mathematics required

- **[M5: Lynch-Kleitman Asymptotic](../02-mathematics/05-lynch-kleitman.md)** — the formal statement

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — FORGET is the 6th opcode
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — FORGET_completeness is the 6th law
