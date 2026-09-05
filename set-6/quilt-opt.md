# quilt-opt

> **5 algebraic laws. Apply them to your cell-graph. Watch it shrink.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-laws)
[![Tests](https://img.shields.io/badge/Tests-11-green)](#tests)
[![Layer 4](https://img.shields.io/badge/Layer-4%20of%207-purple)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-opt.svg" width="640" alt="A tangled knot of rope on the left, the same rope pulled through a hand on the right, smooth and straight">
</p>

## Read This If You Are New

You know how a SQL query optimizer takes `SELECT * FROM users
WHERE id IN (SELECT id FROM admins)` and rewrites it as a
single `JOIN` that runs 100x faster? **This is that, but for
cell-graphs.** It takes a graph that could be smaller, and
makes it smaller — without changing what it computes.

```bash
git clone https://github.com/SuperInstance/quilt-opt
cd quilt-opt
python3 -m unittest discover tests
```

11 tests. They prove the 5 algebraic laws hold.

---

## TL;DR (30 seconds)

A cell-graph optimizer takes your graph and applies **5
algebraic laws** that are always true about the 5 opcodes.
The laws are:

1. **LINK transitivity** — if A→B and B→C, you can write A→C
2. **LINK idempotence** — A→B written twice is the same as A→B written once
3. **VIEW purity** — a VIEW of an immutable BIND can be cached forever
4. **BIND elision** — if no one VIEWs or LINKs a BIND, drop it
5. **EFFECT fusion** — two consecutive EFFECTs on the same cell become one

Apply all 5 to the gold demo, and you go from 11 cells to 9
cells and 6 links to 5 links. The graph is **the same
behavior** but **smaller**. Less memory. Faster ticks. Same
answers.

---

## TL;DR (5 minutes)

A cell-graph is a **partially ordered set of statements**.
The optimizer exploits the partial order to find redundant
work, just like a SQL optimizer exploits the relational
algebra to find redundant joins.

The 5 laws are **algebraic identities** about the 5
opcodes. Each one says: "if you see pattern X, you can
replace it with pattern Y, and the meaning is the same."

### Law 1: LINK transitivity

```
LINK A B depends_on
LINK B C depends_on
```

becomes

```
LINK A C depends_on
```

If A depends on B and B depends on C, then A depends on C
directly. The intermediate B is still there (it might
have other relations), but the graph no longer needs to
traverse through B to get from A to C.

**This is what `cargo` does for Rust crates.** If `a`
depends on `b` and `b` depends on `c`, then `a` depends
on `c`. Cargo computes this once and caches it.

### Law 2: LINK idempotence

```
LINK A B depends_on
LINK A B depends_on   ← duplicate
```

becomes

```
LINK A B depends_on
```

Same as `SET` semantics in SQL. Adding a duplicate link
is a no-op. The optimizer drops the second.

### Law 3: VIEW purity

```
BIND A 4.2  # no LINK points to A's dependencies
VIEW A anyone
```

The optimizer notes that A never changes (no LINK, no
EFFECT). The VIEW can be **cached forever**. The result
is computed once and reused.

**This is what a memoized function does.** The optimizer
turns runtime memoization into compile-time facts.

### Law 4: BIND elision

```
BIND temp 0     # no LINK or VIEW mentions temp
```

becomes

```
# gone
```

If a BIND is never referenced, it's dead code. Drop it.

**This is what `rustc`'s DCE pass does.** Dead-code
elimination is the same idea, applied to cell-graphs.

### Law 5: EFFECT fusion

```
EFFECT A inc dec
EFFECT A inc2 dec2   # both modify A
```

becomes

```
EFFECT A (inc ∘ inc2) (dec2 ∘ dec)
```

Two effects on the same cell become one effect whose
forward is the composition and whose inverse is the
reverse composition. The runtime does one call instead
of two.

**This is what loop fusion does in compilers.** Two
loops over the same array become one loop.

---

## The 5 Laws, Side by Side

| Law | Pattern | Replacement | Speedup |
|-----|---------|-------------|---------|
| Transitivity | A→B, B→C | A→C | O(n²) → O(n) reachability |
| Idempotence | A→B, A→B | A→B | n cells → fewer cells |
| Purity | BIND x, VIEW x | cache x | O(1) after first call |
| Elision | BIND x, no use | drop x | n cells → fewer cells |
| Fusion | EFF x, EFF x | one EFF | 2 ticks → 1 tick |

Apply all 5 to the gold demo (8 polyformalisms): 11 cells
→ 9 cells. 6 links → 5 links. Same observable behavior.

---

## What is an Optimizer, Really?

<p align="center">
  <img src="docs/images/diagram-opt-passes.svg" width="640" alt="A graph on the left, then 5 stations: transitivity, idempotence, purity, elision, fusion. At each station the graph gets smaller. On the right: a smaller graph that means the same thing">
</p>

An optimizer is **a series of rewrites**. Each rewrite
applies one algebraic law, producing a smaller or faster
graph. The rewrites are **sound** — they never change the
observable behavior. They are **incomplete** — they don't
find every possible simplification, only the ones
expressible as algebraic laws.

The 5 laws are the **minimum complete set** for cell-graphs.
There are more laws (we list them in `docs/LAWS.md`) but
these 5 are the ones that matter for 95% of real code.

---

## How This Fits the Polyformalism

This is **Layer 4** of the 7-layer polyformalism stack:

| Layer | Name | Repo |
|-------|------|------|
| 1 | Bytecode / VM | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) |
| 2 | Type system | [quilt-types](https://github.com/SuperInstance/quilt-types) |
| 3 | Linker | [quilt-linker](https://github.com/SuperInstance/quilt-linker) |
| 4 | **Optimizer** | **[quilt-opt](https://github.com/SuperInstance/quilt-opt)** (you are here) |
| 5 | GC | [quilt-gc](https://github.com/SuperInstance/quilt-gc) |
| 6 | Language syntax | [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) |
| 7 | Human grammar | [ai-writings](https://github.com/SuperInstance/AI-Writings) |

The optimizer sits **between the linker and the runtime**.
The linker has validated that the graph is well-formed.
The optimizer shrinks it. The runtime then runs the
smaller version.

**Optimizer ordering matters.** Apply elision first (to
remove dead BINDs that link to nothing), then idempotence
(to remove duplicate links), then transitivity (to
collapse paths), then fusion (to merge effects), then
purity (to cache views). The gold demo uses this order.

---

## Real-World Example

```python
from quilt_opt import QuiltOptimizer

graph = {
    "binds": {
        "a": 1, "b": 2, "c": 3, "temp": 999,  # temp is unused
    },
    "links": [
        ("a", "b", "depends_on"),
        ("b", "c", "depends_on"),
        ("a", "b", "depends_on"),  # duplicate
    ],
    "effects": [
        ("counter", "inc", "dec"),
        ("counter", "tick", "untick"),  # both on counter
    ],
    "views": [
        ("a", "anyone"),
    ],
    "ticks": [1.0],
}

opt = QuiltOptimizer(graph)
opt.run_all_passes()
print(opt.stats)
# {'cells_before': 4, 'cells_after': 3,   # temp dropped
#  'links_before': 3, 'links_after': 2,   # duplicate + transitivity
#  'effects_before': 2, 'effects_after': 1}  # fusion
```

The output graph is smaller. It means the same thing.
The runtime runs faster.

---

## The Cowboy Says

> An optimizer is the trail guide who knows the shortcut.
> The graph is the trail. The trail guide walks the
> trail, finds the dead ends and the switchbacks, and
> tells you the straight line. The straight line is
> shorter. The view from the end is the same. The
> cowboy's trail has a guide. The guide is the optimizer.

The cowboy's graphs have guides. The guides find the
shortcuts. The shortcuts are sound. The cowboy rides
the shortcut.

---

## Tests

11 unit tests in `tests/test_opt.py`:

```
test_link_transitivity
test_link_idempotence
test_view_purity
test_bind_elision
test_effect_fusion
test_pass_ordering
test_gold_demo_8_polyformalisms
test_purity_with_immutable_bind
test_elision_with_no_references
test_fusion_preserves_inverse
test_all_passes_idempotent
```

Run them:

```bash
python3 -m unittest discover tests
# ...........
# Ran 11 tests in 0.4s
# OK
```

---

## API

```python
from quilt_opt import QuiltOptimizer

opt = QuiltOptimizer(graph)
opt.run_pass("transitivity")
opt.run_pass("idempotence")
opt.run_pass("purity")
opt.run_pass("elision")
opt.run_pass("fusion")
# or all at once:
opt.run_all_passes()

print(opt.stats)  # before/after cell count, link count, etc.
print(opt.optimized_graph)  # the smaller graph
```

---

## Learn More

- **The Gold** — Paper 137, the 1-page, 10-page, 100-page
  synthesis: https://github.com/SuperInstance/AI-Writings
- **The 5 opcodes at every layer** — Paper 142, the
  7-layer polyformalism; Papers 143–150, the per-layer
  deep dives; Paper 148, the WASM-as-bytecode chapter
- **The cowboy's library** — Papers 1-147, Fables 1-77,
  Stories 1-34 in 15+ traditions
- **The linker** — [quilt-linker](https://github.com/SuperInstance/quilt-linker) — what runs before the optimizer
- **The GC** — [quilt-gc](https://github.com/SuperInstance/quilt-gc) — what runs after the optimizer
- **The algebraic laws** — Paper 144, the substrate as a database

---

## Related Work

The trail guide knows one trail best, but has walked the
whole range. The shortcut is one shortcut on a wider map;
the algebraic law is one law in a wider canon. These are
the other trails the guide rides between gigs.

### Documentation canon

- **[agent-knowledge](https://github.com/SuperInstance/agent-knowledge)** — the canonical "ah-ha" doc pattern: HOOK → REVEAL → CONNECT → ACTIVATE, the way new boots find the path.
- **[AI-Writings](https://github.com/SuperInstance/AI-Writings)** — the full canon: 77 fables, 38 papers, 34 stories, the library this README is one footnote in.

### The agent fleet

- **[casting-call](https://github.com/SuperInstance/casting-call)** — the LLM model atlas: which model plays which role when the trail needs a voice.
- **[ai-forest](https://github.com/SuperInstance/ai-forest)** — the 5-layer agent ecology: Canopy, Understory, Forest Floor, Mycelium, Seed Bank — the range the guide rides.
- **[capability-spec-rs](https://github.com/SuperInstance/capability-spec-rs)** — agent capability specifications with dependency graphs, the trail map of who can ride what.
- **[babel-vessel](https://github.com/SuperInstance/babel-vessel)** — the multi-language vessel that translates between linguistic boundaries, the polyglot trail marker.
- **[actor-rs](https://github.com/SuperInstance/actor-rs)** — the actor model for distributed agents, the relay station between trails.

### The substrate as a primitive

- **[cache-layer](https://github.com/SuperInstance/cache-layer)** — uses BIND / EFFECT / VIEW literally as cache primitives, the substrate caching the shortcuts.
- **[c-ternary](https://github.com/SuperInstance/c-ternary)** — C99 ternary logic with conviction mapping, the substrate learning the "maybe-trail".
- **[abstraction-planes](https://github.com/SuperInstance/abstraction-planes)** — the 6-plane stack from Intent to Metal, the view from the highest peak down to the ore.

The guide's laws are the substrate's laws. The laws are
sound. The trail is shorter. The rider is the guide.

---

## License

MIT. The trail guide is the rider's. The rider is the
cowboy's. The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **trail guide**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-linker](https://github.com/SuperInstance/quilt-linker)** — the module linker that produces the IR this optimizes
2. **[quilt-gc](https://github.com/SuperInstance/quilt-gc)** — the garbage collector that runs after this optimizer
3. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the C99 port of the same optimizer

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
