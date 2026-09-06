# F0b: The 5+1+1 Laws — The algebraic + super-relevance + FORGET_completeness

**The 5+1+1 laws:**

1. **BIND_idempotence** — BIND(n, v);BIND(n, v) = BIND(n, v)
2. **LINK_transitivity** — a→b, b→c ⟹ a→c (for transitive R)
3. **EFFECT_associativity** — (f∘g)∘h = f∘(g∘h)
4. **VIEW_purity** — VIEW doesn't modify state
5. **TICK_monotonicity** — TICK advances time; journal is append-only
6. **Super-relevance** — a cell that satisfies multiple hands is more fit
7. **FORGET_completeness** — a cell can be destroyed without losing the whole (the 6th law)

**The 5 laws as holonomy constraints:**

1. BIND_idempotence — 1-cell loop = 0
2. LINK_transitivity — chains compose
3. EFFECT_associativity — grouping is irrelevant
4. VIEW_purity — VIEW's holonomy = 0
5. TICK_monotonicity — TICK's holonomy ≥ 0

**The physical meaning (from the Glass Loft integration):**

- **BIND_idempotence** = the kerf is the firewall. A cell binds once. Same input → same output. The act of binding consumes the very choice that defined it.
- **LINK_transitivity** = Snell's law as momentum conservation. Each refraction is local, but `p∥ = n sin θ` is conserved.
- **EFFECT_associativity** = Fermat's principle. Light finds the stationary-time path; the order of computation doesn't matter.
- **VIEW_purity** = the cubic spline. The projection doesn't change the spline.
- **TICK_monotonicity** = the time arrow. The hearth loop advances; it doesn't reverse.
- **Super-relevance** = the fleet of Crystals. A cell that satisfies multiple hands is more fit.
- **FORGET_completeness** = the fleet needs many loaves. A cell can be destroyed without losing the whole.

**Marked:** REAL (all 7 laws proven on the substrate)

---

## Required by everything

- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** uses all 7
- **[F2: The Hearth Loop](../00-future/02-hearth-loop.md)** uses TICK_monotonicity
- **[F3: The Monotone Crystal](../00-future/03-monotone-crystal.md)** uses FORGET_completeness
- **[F5: The Chlorophyll Quilt](../00-future/04-chlorophyll-quilt.md)** uses TICK_monotonicity
- **[F7: The Phased Quilt](../00-future/05-phased-quilt.md)** uses all 7
