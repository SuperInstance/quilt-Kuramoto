# C3: The Photorefractive Write-Loop — The index writes itself from the light

**What it calculates:** Given a light beam's intensity pattern, compute the new refractive index field of the glass.

**The math:** `n(r, t+dt) = n(r, t) + (dn/dT) · P(r) · dt / (ρ · c_p)`

- `n(r, t)` = refractive index at point r and time t
- `dn/dT` ≈ +10⁻⁵ to +10⁻⁶ /K = thermo-optic coefficient
- `P(r)` = light power per unit volume at point r (the beam's intensity)
- `ρ · c_p` = density × specific heat (the glass's thermal mass)
- `dt` = time step

**The loop:**

1. **Lamp** shines a beam into the glass
2. **Heat** — the beam's energy warms the glass at the points where it's absorbed
3. **Index** — the warmed glass has a higher refractive index
4. **Path** — the new index bends the next beam
5. **Repeat** — the next beam follows the new path, which is different, so the next heating is different

**Real-world counterpart:** Photorefractive two-wave mixing in LiNbO₃, holographic learning since the 1980s. The interference field of the signal beams themselves writes the grating.

**The Hearth Rule (the discipline):**

> *Change is only allowed if the light pays for it.*

Heat that comes from the beam itself is *memory*. Heat you add from outside is *cooking*. A seasoned loaf is worth ten green ones.

**Marked:** REAL (LiNbO₃ 1980s), STRETCH (the deliberate, stable, slow improvement)

---

## Required for

- **[F2: The Hearth Loop](../00-future/02-hearth-loop.md)** — the loop is the calculation

## Mathematics required

- **[M3: Fermat's Principle](../02-mathematics/03-fermat.md)** — the next beam's path

## Foundations

- **[F0a: The 5 Opcodes](../03-foundations/01-the-5-opcodes.md)** — TICK advances time; the loop runs one TICK at a time
- **[F0e: The 6 Lifecycle Stages](../03-foundations/05-the-6-stages.md)** — the glass goes through cellulization, persistence pulse, vitality leak; the loop is the pulse
