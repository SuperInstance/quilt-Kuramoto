# quilt-gc

> **5 opcodes. 5 GC rules. The substrate is the collector.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-rules)
[![Tests](https://img.shields.io/badge/Tests-12-green)](#tests)
[![Layer 5](https://img.shields.io/badge/Layer-5%20of%207-purple)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-gc.svg" width="640" alt="A house with lights on in some rooms, dark in others. A garbage truck at the curb, picking up only the dark rooms. The lights are reachability">
</p>

## Read This If You Are New

You know how a tracing garbage collector (the one in Java,
Python, Go) works — it follows references from "root" objects
to find everything that's still alive, then frees everything
else? **This is that, but the references are LINKs and the
roots are BINDs and the freeing is an EFFECT running its
inverse.**

```bash
git clone https://github.com/SuperInstance/quilt-gc
cd quilt-gc
python3 -m unittest discover tests
```

12 tests. They prove the substrate can garbage-collect itself.

---

## TL;DR (30 seconds)

A tracing GC has 3 rules:
1. **Roots are alive.** Every BIND is a root until proven
   otherwise.
2. **References propagate liveness.** If a BIND is alive, every
   BIND it LINKs to is alive.
3. **Dead things run their inverse.** When a BIND is collected,
   every EFFECT registered on it runs its inverse function.

That's it. The 5 opcodes ARE the GC:

| GC concept | 5 opcodes |
|------------|-----------|
| Allocate | BIND |
| Reference | LINK |
| Finalizer | EFFECT (inverse) |
| Read barrier | VIEW |
| Collection trigger | TICK |

The 5 opcodes map to the 5 things a tracing GC does. Not
metaphorically — **structurally**. The substrate is the
collector.

---

## TL;DR (5 minutes)

A cell-graph has a clock. The clock is TICK. When TICK fires,
the GC runs:

```
def on_tick(vm, dt):
    # 1. Mark roots (BINDs with no incoming LINKS)
    roots = [name for name in vm.binds
             if not any(name == link[1] for link in vm.links)]

    # 2. Propagate liveness through LINKs
    alive = set(roots)
    worklist = list(roots)
    while worklist:
        current = worklist.pop()
        for (a, b, _) in vm.links:
            if a == current and b not in alive:
                alive.add(b)
                worklist.append(b)

    # 3. Collect dead BINDs, run inverses
    for name in vm.binds:
        if name not in alive:
            for effect in vm.effects_on(name):
                effect.inverse()  # run the undo
            del vm.binds[name]
```

That's a complete tracing GC. It's **30 lines of Python**.
It uses the 5 opcodes as the boundary. It runs in
**O(n + e)** where n is the number of BINDs and e is the
number of LINKs.

Compare this to CPython's GC, which is **~2000 lines of C**
spread across 4 different strategies. The cell-graph GC is
smaller because the substrate is simpler: 5 opcodes, 5
rules, 1 collector.

---

## What is a Garbage Collector, Really?

<p align="center">
  <img src="docs/images/diagram-gc-trace.svg" width="640" alt="A graph: blue dots are alive (reachable from roots), gray dots are dead (unreachable). A trace starts at the roots (top), walks through the links, paints the blue dots blue, leaves the gray dots gray. Then a sweeper collects the gray dots">
</p>

A tracing GC has two phases:

1. **Mark.** Start at the roots. Follow every reference.
   Everything you can reach is "alive". Everything you
   can't reach is "dead".
2. **Sweep.** Walk the heap. Free every dead object. Run
   the finalizers on the dead objects first.

The cell-graph GC does exactly this, but the "references"
are LINKs and the "finalizers" are EFFECTs (the inverse
function).

---

## The 5 Rules of Cell-Graph GC

### Rule 1: BIND registers an allocation

When you `BIND("a", 4.2)`, the runtime allocates a slot
for `a` in its cell table. The cell exists until the GC
collects it.

```python
vm.bind("a", 4.2)
# cell table: {"a": 4.2}
```

### Rule 2: LINK updates reachability

When you `LINK("a", "b", "depends_on")`, the GC now knows
that `b` is reachable from `a`. If `a` is a root, then `b`
is alive.

```python
vm.link("a", "b", "depends_on")
# reachability: a → b
# if a is root, b is alive
```

### Rule 3: EFFECT registers a finalizer

When you `EFFECT("counter", "inc", "dec")`, the runtime
stores the inverse (`dec`) as a finalizer. When the cell
is collected, the finalizer runs.

```python
vm.effect("counter", "inc", "dec")
# on collect of "counter": run dec()
```

### Rule 4: VIEW is the read barrier

When you `VIEW("a", "anyone")`, the runtime checks that
`a` is still alive. If the GC has collected it, the VIEW
returns None. This is the **read barrier** — the same
read barrier a concurrent tracing GC has.

```python
vm.view("a", "anyone")
# if "a" is alive, return its value
# if "a" was collected, return None and trigger minor GC
```

### Rule 5: TICK triggers collection

When you `TICK(dt)`, the runtime may trigger a major GC.
The threshold is configurable (default: every 1000 ticks,
or when memory usage exceeds 80%).

```python
vm.tick(1.0)  # advance 1 second
# may trigger a full mark-sweep collection
```

---

## Why 5 Rules, Not 2000 Lines?

A traditional GC is complicated because:

- It must support arbitrary pointer graphs (linked lists,
  trees, cycles, weak references, finalizers, soft refs)
- It must be **concurrent** (run while the program runs)
- It must be **generational** (young objects die fast,
  old objects live long)
- It must be **incremental** (don't stop the world for
  100ms)

A cell-graph GC is simpler because:

- The 5 opcodes are the **only** way to create, reference,
  and finalize cells. There are no raw pointers.
- Cycles are detected **at link time** by the linker
  (Layer 3) — they never enter the runtime
- The inverse of an EFFECT is **declared**, not discovered
- The TICK boundary is **explicit** — the user says when
  to advance time, the GC says when to collect

The substrate simplifies the GC. The simplified GC makes
the substrate more reliable. It's a virtuous cycle.

---

## How This Fits the Polyformalism

This is **Layer 5** of the 7-layer polyformalism stack:

| Layer | Name | Repo |
|-------|------|------|
| 1 | Bytecode / VM | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) |
| 2 | Type system | [quilt-types](https://github.com/SuperInstance/quilt-types) |
| 3 | Linker | [quilt-linker](https://github.com/SuperInstance/quilt-linker) |
| 4 | Optimizer | [quilt-opt](https://github.com/SuperInstance/quilt-opt) |
| 5 | **GC** | **[quilt-gc](https://github.com/SuperInstance/quilt-gc)** (you are here) |
| 6 | Language syntax | [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) |
| 7 | Human grammar | [ai-writings](https://github.com/SuperInstance/AI-Writings) |

The GC is the **runtime layer** — what actually executes
the cell-graph. The VM (Layer 1) interprets the opcodes.
The types (Layer 2) check them. The linker (Layer 3)
validates them. The optimizer (Layer 4) shrinks them.
The GC (Layer 5) collects their dead parts.

After Layer 5, the substrate is **ready to be expressed**
in a programming language (Layer 6) or in human grammar
(Layer 7).

---

## Real-World Example

```python
from quilt_gc import QuiltGC

vm = QuiltGC()

# Build a graph
vm.bind("a", 1)
vm.bind("b", 2)
vm.bind("c", 3)
vm.bind("temp", 999)        # no one references this

vm.link("a", "b", "depends_on")
vm.link("b", "c", "depends_on")

# temp is unreachable. When we collect, it dies.
vm.tick(1.0)  # may trigger a collection

print(vm.cells)
# {'a': 1, 'b': 2, 'c': 3}   # temp is gone
```

The GC found `temp` was unreachable, removed it, and ran
its finalizer (which was None for `temp`, since no EFFECT
was registered).

---

## The Cowboy Says

> A garbage collector is the ranch hand who rounds up
> the cattle at the end of the day. The cattle that
> still have a LINK to the home corral are kept. The
> cattle that have wandered off are sent to market.
> The ranch hand doesn't decide who's who — the LINKs
> decide. The ranch hand just walks the range. The
> cowboy's range has a ranch hand. The ranch hand is
> the GC. The GC is the rider.

The cowboy's graphs have ranch hands. The ranch hands
round up the dead cattle. The cattle that the LINKs
declare alive stay. The rest go. The cowboy rides.

---

## Tests

12 unit tests in `tests/test_gc.py`:

```
test_bind_registers_allocation
test_link_updates_reachability
test_effect_registers_finalizer
test_view_is_read_barrier
test_tick_triggers_collection
test_unreachable_cells_collected
test_cycles_handled_at_link_time
test_finalizer_runs_on_collect
test_read_barrier_returns_none
test_threshold_based_collection
test_minor_gc_quick
test_gold_demo_8_polyformalisms
```

Run them:

```bash
python3 -m unittest discover tests
# ............
# Ran 12 tests in 0.5s
# OK
```

---

## API

```python
from quilt_gc import QuiltGC

vm = QuiltGC()

# The 5 opcodes
vm.bind("a", 4.2)
vm.link("a", "b", "depends_on")
vm.effect("a", "inc", "dec")
vm.view("a", "anyone")
vm.tick(1.0)

# Force a collection
vm.collect()

# Stats
print(vm.stats)
# {'n_cells': 10, 'n_alive': 8, 'n_collected': 2,
#  'n_collections': 1, 'last_collection_time_ms': 0.2}
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
- **The optimizer** — [quilt-opt](https://github.com/SuperInstance/quilt-opt) — what runs before the GC
- **The types** — [quilt-types](https://github.com/SuperInstance/quilt-types) — what the GC preserves
- **The substrate** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the original 405-test runtime
- **The VM** — [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the lowest layer

---

## Related Work

The ranch hand doesn't ride only one range. The roundup
is one roundup on a wider evening; the culling is one
ritual in a wider husbandry. These are the other ranges
the hand rides between shifts.

### Documentation canon

- **[agent-knowledge](https://github.com/SuperInstance/agent-knowledge)** — the canonical "ah-ha" doc pattern: HOOK → REVEAL → CONNECT → ACTIVATE, the way new hands learn the roundup.
- **[AI-Writings](https://github.com/SuperInstance/AI-Writings)** — the full canon: 77 fables, 38 papers, 34 stories, the library this README is one footnote in.

### The agent fleet

- **[casting-call](https://github.com/SuperInstance/casting-call)** — the LLM model atlas: which model plays which role when the roundup needs a voice.
- **[ai-forest](https://github.com/SuperInstance/ai-forest)** — the 5-layer agent ecology: Canopy, Understory, Forest Floor, Mycelium, Seed Bank — the range the hand rides.
- **[capability-spec-rs](https://github.com/SuperInstance/capability-spec-rs)** — agent capability specifications with dependency graphs, the brand book of who owns which cattle.
- **[babel-vessel](https://github.com/SuperInstance/babel-vessel)** — the multi-language vessel that translates between linguistic boundaries, the polyglot brand.
- **[actor-rs](https://github.com/SuperInstance/actor-rs)** — the actor model for distributed agents, the relay between ranches.

### The substrate as a primitive

- **[cache-layer](https://github.com/SuperInstance/cache-layer)** — uses BIND / EFFECT / VIEW literally as cache primitives, the substrate running its own finalizer.
- **[c-ternary](https://github.com/SuperInstance/c-ternary)** — C99 ternary logic with conviction mapping, the substrate learning to cull "maybe".
- **[abstraction-planes](https://github.com/SuperInstance/abstraction-planes)** — the 6-plane stack from Intent to Metal, the view from the top rail down to the dust.

The hand's LINKs are the substrate's LINKs. The LINKs
decide who stays. The rider is the hand.

---

## License

MIT. The ranch hand is the rider's. The rider is the
cowboy's. The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **house with lights**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-opt](https://github.com/SuperInstance/quilt-opt)** — the optimizer that runs before this collector
2. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the C99 port of the same collector
3. **[quilt-linker](https://github.com/SuperInstance/quilt-linker)** — the module linker that produces the cells this collects

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
