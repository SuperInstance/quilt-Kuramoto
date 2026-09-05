# F2: The Hearth Loop — A glass that trains itself under its own lamp

**What it does:** The Splined Lantern, sitting under its own lamp, slowly bends toward the truth of its own experience. Ask a loaf the same thing a thousand times and the answer stops landing on the first pad and starts landing on the pad the *fleet* has learned to trust, because the glass has slowly bent toward the truth.

**Real-world instantiation:** Iunia's apprentice, Alu the Tsimpshian boy, who asked: "If the light can change the glass, and the glass changes the light — who is asking, and who is answering?" The hearth rule was the answer: change is only allowed if the light pays for it.

**The Hearth Loop (the 5 steps):**

1. **Lamp** — the forward lamp shines a beam into the loaf
2. **Heat** — the beam's energy warms the glass
3. **Index** — the warmed glass swells; the refractive index rises
4. **Path** — the new index bends the light along a new path
5. **Lamp** — the next beam follows the new path, and the loop continues

The light trains the glass. The glass trains the light. The loop is **self-organizing**.

**The Hearth Rule (the discipline):**

> *Change is only allowed if the light pays for it.*

Heat that comes from the beam itself is *memory*. Heat you add from outside is *cooking*. A seasoned loaf is worth ten green ones, and a burned one is gravel.

**Marked:** REAL (photorefractive two-wave mixing in LiNbO₃, 1980s), STRETCH (the deliberate, stable, slow improvement), FICTION (the 100-year seasoning)

**Measured basin (2026-08-31, [examples/hearth_loop.py](../examples/hearth_loop.py)):** the loop as a discrete map settles monotonically only for write-rates below a pad-width threshold (worst-case guarantee: one write may not cross a full landing pad); above it, the loaf burns by OVERSHOOT, not just by cooking — **burning has two doors**. The Hearth Rule's memory/cooking line is the exact stability boundary: beam-paid heat stops writing at the truth pad; external heat ignores the truth and always eventually burns. "Self-organizing" is true but conditional.

---

## Calculations required

- **[C2: Stationary-Time Refraction](../01-calculations/02-stationary-time.md)** — the light's new path is the stationary-time path through the new index
- **[C3: Photorefractive Write-Loop](../01-calculations/03-photorefractive.md)** — the index writes itself from the light

## Mathematics required

- **[M3: Fermat's Principle](../02-mathematics/03-fermat.md)** — light's stationary path through the new index
- **[M4: Snell's Law as Conservation](../02-mathematics/04-snell-momentum.md)** — each refraction is local, but conservation of `p∥` is global

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — VIEW depends on the cell state; the cell state changes; the view updates
- **[F0b: The 5+1+1 Laws](../03-foundations/02-the-5-laws.md)** — TICK_monotonicity holds even when the index changes

---

*"A seasoned loaf is worth ten green ones, and a burned one is gravel — because there are no board stretchers, and heat-ruined glass only comes off in the crusher."*
