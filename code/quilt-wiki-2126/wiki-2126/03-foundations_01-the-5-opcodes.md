# F0a: The 5 Opcodes (+ 1) — The substrate that hosts the math

**The 5 opcodes:**

- **BIND(name, value)** — make a thing (labeling)
- **LINK(a, b, type)** — connect things (relational)
- **EFFECT(target, fn, inverse)** — reversible transformation
- **VIEW(target, viewer, projection?)** — project for viewer
- **TICK(dt)** — advance time, process async I/O
- **FORGET(target)** — destroy a cell (the 6th opcode)

**The 5 laws:**

1. **BIND_idempotence** — BIND(n, v);BIND(n, v) = BIND(n, v)
2. **LINK_transitivity** — a→b, b→c ⟹ a→c
3. **EFFECT_associativity** — (f∘g)∘h = f∘(g∘h)
4. **VIEW_purity** — VIEW doesn't modify state
5. **TICK_monotonicity** — TICK advances time; journal is append-only
6. **FORGET_completeness** — a cell can be destroyed without losing the whole (the 6th law)

**The 5 opcodes as transforms:**

- BIND: name → value (labeling)
- LINK: cell → cell (relational)
- EFFECT: inputs → outputs (functional)
- VIEW: state → projection (projection)
- TICK: moment → next moment (temporal)
- FORGET: cell → ∅ (destructive; the 6th)

**The principle:** A runtime = a function from context to value with an inverse, advanced by a clock that processes async I/O while projecting a sync view.

**Marked:** REAL (the substrate spec, all 6 laws proven)

---

## Required by everything

Every function in the wiki uses these 6 opcodes:

- **[F1: The Splined Lantern](../00-future/01-splined-lantern.md)** uses BIND/LINK/EFFECT/VIEW/TICK
- **[F2: The Hearth Loop](../00-future/02-hearth-loop.md)** uses TICK to advance the loop
- **[F3: The Monotone Crystal](../00-future/03-monotone-crystal.md)** uses FORGET to break a finished thought
- **[F5: The Chlorophyll Quilt](../00-future/04-chlorophyll-quilt.md)** uses TICK for the breath
- **[F7: The Phased Quilt](../00-future/05-phased-quilt.md)** uses all 6 opcodes as transforms
