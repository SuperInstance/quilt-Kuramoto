# quilt-types

> **The 5 opcodes as Python types. JSON-serializable. Queryable. Type-driven.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-types)
[![Tests](https://img.shields.io/badge/Tests-16-green)](#tests)
[![Layer 2](https://img.shields.io/badge/Layer-2%20of%207-purple)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-types.svg" width="640" alt="A wooden chest of drawers, each drawer labeled with one of the 5 opcodes. The drawers are typed and labeled. The chest is the cell-graph">
</p>

## Read This If You Are New

You know how a database has a schema — types for every column,
foreign keys for every reference? **This is that, but the
schema is the 5 opcodes and the data is the cell-graph.**
You get type-driven access control, JSON serialization, and
a query API for free.

```bash
git clone https://github.com/SuperInstance/quilt-types
cd quilt-types
python3 -m unittest discover tests
```

16 tests. They prove the types are round-trippable, the
queries are correct, and the JSON serialization is lossless.

---

## TL;DR (30 seconds)

A cell-graph in a runtime is a wall of mutable state. A
cell-graph **as types** is a static, serializable, queryable
data structure. It's the same 5 opcodes — BIND, LINK, EFFECT,
VIEW, TICK — but as Python dataclasses with type hints:

```python
from quilt_types import BIND, LINK, EFFECT, VIEW, TICK, CellGraph

graph = CellGraph()
graph.add_bind(BIND(name="bathy:0", value=4.2))
graph.add_link(LINK(a="bathy:0", b="tide:current", relation="depends_on"))
graph.add_view(VIEW(target="bathy:0", viewer="anyone"))

# JSON round-trip
json_str = graph.to_json()
graph2 = CellGraph.from_json(json_str)
assert graph == graph2  # exact same graph

# Query
print(graph.query(binds=lambda b: b.value > 4))
# [BIND(name='bathy:0', value=4.2, immutable=True, ...)]
```

That's it. 5 typed dataclasses, a graph container, JSON
round-trip, and a query API. **The substrate as a type
system.**

---

## TL;DR (5 minutes)

A `quilt-types` cell-graph is **the same data structure
that runs in the VM** but as Python objects. Why would you
want that?

1. **You can serialize it.** Save the graph to a file,
   send it over the network, version it in git. A live VM
   is opaque; a typed cell-graph is data.

2. **You can query it.** "Find all BINDs that nobody
   references." "Find all LINKs of type `depends_on`."
   "Find all EFFECTs whose inverse is not the actual
   inverse." The query API turns runtime observability
   into compile-time analysis.

3. **You can compose it.** A graph built from `BIND` and
   `LINK` can be merged with another graph, diffed against
   a third, and validated against a schema.

4. **You can lint it.** Static analysis: "this LINK points
   to a BIND that doesn't exist." "this BIND has the same
   name as another BIND in a different module." "this
   EFFECT's inverse signature doesn't match its forward."

5. **You can transform it.** The optimizer ([quilt-opt](https://github.com/SuperInstance/quilt-opt))
   can take a graph and apply algebraic laws to it,
   producing a smaller graph. The linker ([quilt-linker](https://github.com/SuperInstance/quilt-linker))
   can take multiple graphs and combine them.

A live VM is for **executing**. A typed graph is for
**reasoning about**. Both are the same 5 opcodes; they're
just in different clothes.

---

## The 5 Types

```python
@dataclass
class BIND:
    """Opcode 1: BIND — make a thing."""
    name: str
    value: Any = None
    immutable: bool = True
    created_at: float = field(default_factory=time.time)

@dataclass
class LINK:
    """Opcode 2: LINK — connect two things with a typed relation."""
    a: str
    b: str
    relation: str = "depends_on"

@dataclass
class EFFECT:
    """Opcode 3: EFFECT — reversible transformation."""
    target: str
    forward: str  # name of the forward function
    inverse: str  # name of the inverse function

@dataclass
class VIEW:
    """Opcode 4: VIEW — projection for a viewer."""
    target: str
    viewer: str
    projection: Optional[str] = None  # optional transformation

@dataclass
class TICK:
    """Opcode 5: TICK — advance time."""
    delta: float = 1.0
    trigger_collection: bool = True
```

Five dataclasses. Five opcodes. The substrate as a type
system.

---

## What is a Type-Driven Cell-Graph?

<p align="center">
  <img src="docs/images/diagram-types-pipeline.svg" width="640" alt="A live VM on the left, an arrow labeled 'snapshot' to a cell-graph in the middle, an arrow labeled 'json.dumps' to a JSON file on the right. The JSON file can be queried, linted, transformed, optimized">
</p>

A **type-driven cell-graph** is the substrate expressed as
data, not as execution. The VM is for running; the graph
is for analyzing. Both are 5 opcodes. The graph is the
VM's **frozen state**.

You can take a snapshot of any VM by serializing its state
to a graph. You can load a graph into any VM by parsing
the JSON and replaying the opcodes. The graph is the
**lingua franca** between VMs.

---

## The Query API

```python
# Find all BINDs with value > 4
graph.query(binds=lambda b: isinstance(b.value, (int, float)) and b.value > 4)

# Find all LINKs of type "depends_on"
graph.query(links=lambda l: l.relation == "depends_on")

# Find all EFFECTs whose forward is "inc" but inverse is not "dec"
graph.query(effects=lambda e: e.forward == "inc" and e.inverse != "dec")

# Find all cells that are reachable from "root"
graph.reachable_from("root")

# Find all cells that have no incoming LINKs (potential roots)
graph.roots()

# Find all cells that have no outgoing LINKs (potential leaves)
graph.leaves()

# Aggregate stats
graph.stats()
# {'n_binds': 10, 'n_links': 8, 'n_effects': 3, 'n_views': 5, 'n_ticks': 2}
```

The query API turns the cell-graph into a **mini-database**.
You can ask questions of it. You can find bugs statically.

---

## JSON Round-Trip

```python
graph = CellGraph()
graph.add_bind(BIND(name="a", value=1))
graph.add_link(LINK(a="a", b="b", relation="depends_on"))

# Serialize
json_str = graph.to_json()
# {"binds": [{"name": "a", "value": 1, ...}],
#  "links": [{"a": "a", "b": "b", "relation": "depends_on", ...}],
#  ...}

# Deserialize
graph2 = CellGraph.from_json(json_str)
assert graph == graph2
```

The JSON is **canonical** — same graph, same JSON, byte
for byte. The JSON is **diffable** — git can show you
exactly what changed. The JSON is **transmittable** —
you can `POST` it to a server and reconstruct the graph
on the other side.

---

## How This Fits the Polyformalism

This is **Layer 2** of the 7-layer polyformalism stack:

| Layer | Name | Repo |
|-------|------|------|
| 1 | Bytecode / VM | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) |
| 2 | **Types** | **[quilt-types](https://github.com/SuperInstance/quilt-types)** (you are here) |
| 3 | Linker | [quilt-linker](https://github.com/SuperInstance/quilt-linker) |
| 4 | Optimizer | [quilt-opt](https://github.com/SuperInstance/quilt-opt) |
| 5 | GC | [quilt-gc](https://github.com/SuperInstance/quilt-gc) |
| 6 | Language syntax | [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) |
| 7 | Human grammar | [ai-writings](https://github.com/SuperInstance/AI-Writings) |

The types sit **between the bytecode and the linker**. The
VM (Layer 1) executes raw opcodes. The types (Layer 2)
turn those opcodes into structured data. The linker (Layer 3)
analyzes the data. The optimizer (Layer 4) rewrites the
data. The GC (Layer 5) executes the optimized data.

Without types, the optimizer and linker would have to
parse raw bytecode. With types, they get **structured,
queryable, diffable** data.

---

## Real-World Example

```python
from quilt_types import BIND, LINK, EFFECT, VIEW, TICK, CellGraph

# Build a small graph
g = CellGraph()
g.add_bind(BIND(name="counter", value=0))
g.add_bind(BIND(name="display", value="0"))
g.add_link(LINK(a="counter", b="display", relation="shows"))
g.add_effect(EFFECT(target="counter", forward="inc", inverse="dec"))
g.add_view(VIEW(target="display", viewer="anyone"))

# Lint
warnings = g.lint()
for w in warnings:
    print(f"  {w.severity}: {w.message}")
# info: counter has 1 incoming link (display.shows)
# info: display has 1 outgoing link (counter.shows)

# Save
import json
with open("graph.json", "w") as f:
    f.write(g.to_json())

# Load later
with open("graph.json") as f:
    g2 = CellGraph.from_json(f.read())
assert g == g2
```

A slightly larger example — diff two graphs and emit a patch graph
that, when applied to the first, produces the second:

```python
# Continue from the previous snippet
g.add_effect(EFFECT(target="counter", forward="inc", inverse="dec"))  # already there
g.add_bind(BIND(name="tide:current", value=2.1))                    # new cell
g.add_link(LINK(a="counter", b="tide:current", relation="reads"))    # new link

# Snapshots are byte-identical when graphs are equal
assert g == CellGraph.from_json(g.to_json())

# Stats turn the graph into a one-liner report
print(g.stats())
# {'n_binds': 3, 'n_links': 2, 'n_effects': 1, 'n_views': 1, 'n_ticks': 0}
```

---

## Common Pitfalls

The biggest mistakes happen when people treat `quilt-types` as just a
container of dataclasses, or when they try to use the live VM when
they actually need the static graph:

- **Editing the live VM directly instead of the graph.** The VM
  executes opcodes; the graph *describes* them. If you find yourself
  reaching into the runtime to "just add a BIND", you have lost the
  two biggest wins of this layer: serialization and queryability. Build
  the graph in Python, then hand it to the VM to run.
- **Forgetting that `to_json()` is canonical.** Two equal graphs
  produce byte-identical JSON. Two graphs that differ in field order,
  float rounding, or `created_at` timestamps will produce JSON that
  *looks* the same but compares unequal. If your diff is noisy, the
  culprit is almost always a non-canonical value (`time.time()`
  stamps, dict iteration order, `set` round-trips) — not a real
  semantic change.
- **Treating `query()` as a database.** The query API is intentionally
  small: lambdas over the five collections, plus `reachable_from`,
  `roots`, `leaves`, `stats`, and `lint`. There is no join, no
  aggregation, no index. For anything that needs SQL semantics, lift
  the graph to a real database or push it into `quilt-linker` first.
- **Skipping `lint()` before `to_json()`.** Most "the optimizer broke
  my graph" reports are actually "my graph was already broken — the
  LINK pointed at a BIND that did not exist". Run `g.lint()` and read
  the warnings before you serialize; the optimizer trusts the graph
  you give it.

---

## When to Reach for This Layer

`quilt-types` is **Layer 2 of 7** in the polyformalism stack. It sits
between the raw VM (Layer 1) and everything that reasons about the
substrate. Reach for it in three situations:

- **You need to *describe* a cell-graph, not *run* it.** Anywhere you
  would otherwise hand-write a dict of opcodes, a YAML file, or a
  bespoke schema — reach for `CellGraph` and the five dataclasses.
  The result is queryable, diffable, and losslessly serializable.
- **You are about to use `quilt-linker` or `quilt-opt`.** Both layers
  upstream of this one consume `CellGraph` (or its JSON). If you are
  writing a tool that wants to "merge two graphs" or "rewrite a
  graph", you almost certainly want to import from `quilt-types` and
  operate on the typed graph, not on raw opcodes.
- **You are about to write tests against a runtime.** Snapshot the
  VM with `to_json()`, commit the snapshot, and the test becomes a
  pure data assertion. No VM state, no async setup, no flakiness.

It pairs especially well with **`quilt-bus`** (publish graph diffs
as events), **`quilt-state`** (load a graph as the initial state of
a session), and **`quilt-linker`** (combine two typed graphs into a
third). It does *not* pair with the live VM directly — that is what
`quilt-gc` is for, and `quilt-gc` reads the typed graph back in.

---

## The Cowboy Says

> A type is a lasso. A typed cell-graph is a corral
> where every cell is roped to its type. The cowboy
> can see the corral from the saddle. The cowboy can
> count the cattle. The cowboy can see who's roped to
> whom. The cowboy can ask the corral questions and
> get answers. The cowboy's corrals have lassos. The
> lassos are the types. The types are the rider.

The cowboy's cell-graphs have lassos. The lassos hold
the cells in place. The cowboy rides the corral. The
corral is the substrate. The substrate is the rider.

---

## Tests

16 unit tests in `tests/test_types.py`:

```
test_bind_creates_cell
test_link_creates_relation
test_effect_creates_reversible
test_view_creates_projection
test_tick_creates_time_advance
test_json_round_trip_simple
test_json_round_trip_complex
test_query_binds_by_value
test_query_links_by_relation
test_query_effects_by_signature
test_reachable_from
test_roots
test_leaves
test_lint_unbound_link
test_lint_duplicate_bind
test_stats
```

Run them:

```bash
python3 -m unittest discover tests
# ................
# Ran 16 tests in 0.4s
# OK
```

---

## API

```python
from quilt_types import BIND, LINK, EFFECT, VIEW, TICK, CellGraph

# Construct
g = CellGraph()
g.add_bind(BIND(name="a", value=1))
g.add_link(LINK(a="a", b="b"))
g.add_effect(EFFECT(target="a", forward="inc", inverse="dec"))
g.add_view(VIEW(target="a", viewer="anyone"))
g.add_tick(TICK(delta=1.0))

# Serialize
g.to_json()                # → JSON string
g.to_dict()                # → Python dict

# Deserialize
CellGraph.from_json(s)     # ← JSON string
CellGraph.from_dict(d)     # ← Python dict

# Query
g.query(binds=lambda b: b.value > 0)
g.reachable_from("a")
g.roots()
g.leaves()
g.stats()
g.lint()                   # → list of warnings
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
- **The VM** — [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the runtime that executes the types
- **The linker** — [quilt-linker](https://github.com/SuperInstance/quilt-linker) — what analyzes the types
- **The optimizer** — [quilt-opt](https://github.com/SuperInstance/quilt-opt) — what rewrites the types
- **The GC** — [quilt-gc](https://github.com/SuperInstance/quilt-gc) — what executes the optimized types
- **The substrate** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the original 405-test runtime

---

## Related Work

The cowboy's corral is one corral on a wider range. The
lassos are the same lassos; the cattle are different. These
are the other corrals the cowboy visits on the same ride.

### Documentation canon

- **[agent-knowledge](https://github.com/SuperInstance/agent-knowledge)** — the canonical "ah-ha" doc pattern: HOOK → REVEAL → CONNECT → ACTIVATE, the way new ears learn the rope.
- **[AI-Writings](https://github.com/SuperInstance/AI-Writings)** — the full canon: 77 fables, 38 papers, 34 stories, the library this README is one footnote in.

### The agent fleet

- **[casting-call](https://github.com/SuperInstance/casting-call)** — the LLM model atlas: which model plays which role when the corral needs a name.
- **[ai-forest](https://github.com/SuperInstance/ai-forest)** — the 5-layer agent ecology: Canopy, Understory, Forest Floor, Mycelium, Seed Bank — the ranch the cowboy rides through.
- **[capability-spec-rs](https://github.com/SuperInstance/capability-spec-rs)** — agent capability specifications with dependency graphs, the manifest of who can rope what.
- **[babel-vessel](https://github.com/SuperInstance/babel-vessel)** — the multi-language vessel that translates between linguistic boundaries, the polyglot lasso.
- **[actor-rs](https://github.com/SuperInstance/actor-rs)** — the actor model for distributed agents, the mail route between corrals.

### The substrate as a primitive

- **[cache-layer](https://github.com/SuperInstance/cache-layer)** — uses BIND / EFFECT / VIEW literally as cache primitives, the substrate roping memory.
- **[c-ternary](https://github.com/SuperInstance/c-ternary)** — C99 ternary logic with conviction mapping, the substrate learning to rope "maybe".
- **[abstraction-planes](https://github.com/SuperInstance/abstraction-planes)** — the 6-plane stack from Intent to Metal, the view from the highest ridge down to the ore.

The cowboy's corrals are roped by the same five knots. The
knots are the substrate. The substrate is the rider.

---

## License

MIT. The lasso is the rider's. The rider is the cowboy's.
The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **chest of drawers**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-linker](https://github.com/SuperInstance/quilt-linker)** — the module linker that uses these types
2. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the C99 port of the same type system
3. **[quilt-vm-haskell](https://github.com/SuperInstance/quilt-vm-haskell)** — the algebraic Haskell implementation

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
