# quilt-polyformalism-dsl

> **The 5 opcodes, dressed as decorators, typeclasses, and proc-macros. Same substrate, three grammatical traditions.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![Rust](https://img.shields.io/badge/Rust-stable-orange)](https://rust-lang.org)
[![Haskell](https://img.shields.io/badge/Haskell-GHC-purple)](https://haskell.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-opcodes)
[![Tests](https://img.shields.io/badge/Tests-7-green)](#tests)
[![Layer 6](https://img.shields.io/badge/Layer-6%20of%207-purple)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-polyformalism-dsl.svg" width="640" alt="Three clay pots on a pottery wheel, all shaped from the same clay. One is decorated with @ symbols, one with = symbols, one with :: symbols. The clay is the substrate">
</p>

## Read This If You Are New

You know how the same SQL query can be written in 5 different
ORMs — SQLAlchemy, Django ORM, Tortoise, SQLModel, peewee —
and the database doesn't care which one you used? **This is
that, but for cell-graphs.** The same 5 opcodes can be
written as Python decorators, Rust proc-macros, or Haskell
typeclasses. The runtime doesn't care which grammar you used.

```bash
git clone https://github.com/SuperInstance/quilt-polyformalism-dsl
cd quilt-polyformalism-dsl
python3 -m unittest discover tests
```

7 tests for the Python DSL. The Rust and Haskell ports have
their own test suites.

---

## TL;DR (30 seconds)

The 5 opcodes (BIND/LINK/EFFECT/VIEW/TICK) are universal.
But **how you write them** depends on your host language:

- **Python** — decorators (`@bind`, `@link`, `@view`, ...)
- **Rust** — proc-macros (`#[quilt_bind]`, `#[quilt_link]`, ...)
- **Haskell** — typeclasses (`instance Bind BIND where ...`)

The decorators / proc-macros / typeclasses are all just
**language hooks** that register a function with the
substrate at a particular moment (function definition,
compile time, type inference). The substrate is the same.
The grammar is local.

```python
# Python
@bind(name="bathy:0", value=4.2)
@link(target="tide:current", relation="depends_on")
@view("anyone")
def bathy(): return 4.2
```

```rust
// Rust
#[quilt_bind(name = "bathy:0", value = "4.2")]
#[quilt_link(target = "tide:current", relation = "depends_on")]
#[quilt_view("anyone")]
fn bathy() -> &'static str { "4.2" }
```

```haskell
-- Haskell
instance Bind BIND where
  bindName _ = "bathy:0"
  bindValue _ = "4.2"
instance Linked BIND where
  links _ = [Link "bathy:0" "tide:current" "depends_on"]
```

Same substrate. Three grammatical traditions. One set of
opcodes.

---

## TL;DR (5 minutes)

A **polyformalism** is the same thing expressed in many
forms. The 5 opcodes are a polyformalism because the
substrate doesn't care about the form. But the **language
designer** cares a lot — the form determines how natural
it feels to write.

This repo gives you **three forms** of the same 5 opcodes:

1. **Python decorators** — Pythonic, dynamic, runtime.
   The substrate is a global dict-of-dicts that the
   decorators populate. Fast to write, easy to debug.

2. **Rust proc-macros** — type-safe, compile-time, zero-cost.
   The substrate is a static struct that the proc-macros
   populate. Fast to run, hard to write.

3. **Haskell typeclasses** — algebraic, type-classed, lazy.
   The substrate is a typeclass dictionary that the
   instances populate. Most expressive, hardest to learn.

All three produce the **same cell-graph** at runtime. You
can mix and match — write a graph in Python, serialize it
to JSON, load it in Rust, query it in Haskell. The substrate
is portable. The grammar is local.

---

## The 5 Opcodes, In 3 Languages

### BIND

```python
# Python
@bind(name="bathy:0", value=4.2)
def bathy(): pass
```

```rust
// Rust
#[quilt_bind(name = "bathy:0", value = "4.2")]
fn bathy() -> &'static str { "4.2" }
```

```haskell
-- Haskell
instance Bind Bathy where
  bindName _ = "bathy:0"
  bindValue _ = "4.2"
```

**What it does:** declares a cell with a name and a value.

### LINK

```python
# Python
@link(target="tide:current", relation="depends_on")
def bathy(): pass
```

```rust
// Rust
#[quilt_link(target = "tide:current", relation = "depends_on")]
fn bathy() -> &'static str { "4.2" }
```

```haskell
-- Haskell
instance Linked Bathy where
  links _ = [Link "bathy:0" "tide:current" "depends_on"]
```

**What it does:** declares a typed relation from this cell
to another.

### EFFECT

```python
# Python
@effect(forward="inc", inverse="dec")
def counter(): pass
```

```rust
// Rust
#[quilt_effect(forward = "inc", inverse = "dec")]
fn counter() -> &'static str { "0" }
```

```haskell
-- Haskell
instance Effectful Counter where
  effectForward _ = "inc"
  effectInverse _ = "dec"
```

**What it does:** declares a reversible transformation on
this cell.

### VIEW

```python
# Python
@view("anyone")
def bathy(): pass
```

```rust
// Rust
#[quilt_view("anyone")]
fn bathy() -> &'static str { "4.2" }
```

```haskell
-- Haskell
instance Viewable Bathy where
  views _ = [View "bathy:0" "anyone"]
```

**What it does:** declares a projection of this cell for a
specific viewer.

### TICK

```python
# Python
tick = 1.0  # in the substrate
```

```rust
// Rust
#[quilt_tick(1.0)]
fn main() { }
```

```haskell
-- Haskell
main = tick 1.0
```

**What it does:** advances the substrate's clock by `dt` units.

---

## Why 3 Languages, Not 1?

<p align="center">
  <img src="docs/images/diagram-3-languages.svg" width="640" alt="Three clay pots: one tall and slim (Haskell), one square and strong (Rust), one round and warm (Python). All on the same wheel. The wheel is the substrate">
</p>

Because **the substrate is universal but the developer is
local**. A Python developer thinks in decorators. A Rust
developer thinks in lifetimes. A Haskell developer thinks
in monads. The substrate is the same; the thought is
different.

By expressing the 5 opcodes in **all three traditions**,
we make the substrate accessible to:

- **Python developers** — they get the runtime-registered
  dict, the dynamic substrate, the interactive REPL
- **Rust developers** — they get the zero-cost abstraction,
  the type-checked substrate, the compile-time guarantees
- **Haskell developers** — they get the algebraic substrate,
  the typeclass-based dispatch, the lazy evaluation

Same substrate. Three communities. Three on-ramps.

---

## How This Fits the Polyformalism

This is **Layer 6** of the 7-layer polyformalism stack:

| Layer | Name | Repo |
|-------|------|------|
| 1 | Bytecode / VM | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) |
| 2 | Type system | [quilt-types](https://github.com/SuperInstance/quilt-types) |
| 3 | Linker | [quilt-linker](https://github.com/SuperInstance/quilt-linker) |
| 4 | Optimizer | [quilt-opt](https://github.com/SuperInstance/quilt-opt) |
| 5 | GC | [quilt-gc](https://github.com/SuperInstance/quilt-gc) |
| 6 | **Language syntax** | **[quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl)** (you are here) |
| 7 | Human grammar | [ai-writings](https://github.com/SuperInstance/AI-Writings) |

Layer 6 is the **language hook** — the moment in the
host language's compilation pipeline where the substrate
gets a chance to register itself. In Python, that's at
function definition (decorator time). In Rust, that's at
proc-macro time. In Haskell, that's at type-inference
time. All three moments produce the same cell-graph
data structure at runtime.

---

## The 3 Languages, Side by Side

| Aspect | Python | Rust | Haskell |
|--------|--------|------|---------|
| Hook type | decorator | proc-macro | typeclass |
| Hook timing | function definition | compile time | type inference |
| Hook cost | runtime (cheap) | compile time (heavy) | typecheck (medium) |
| Substrate location | global dict | static struct | typeclass dict |
| Mutability | mutable | immutable (default) | immutable |
| Discoverability | `dir(substrate)` | `cargo doc` | `:browse Substrate` |
| Interactive | yes (REPL) | no (compile-run) | yes (ghci) |
| Tests | 7 (in `tests/`) | 5 (in `rust/`) | 6 (in `haskell/`) |

---

## The Cowboy Says

> The substrate is the campfire. The host language is
> the camp. Each camp has its own customs — Python
> sits on a log and shares stories around the fire.
> Rust builds a fortified stockade around the fire.
> Haskell sings the fire into being. The cowboy has
> been to all three camps. The cowboy knows the fire
> is the same. The cowboy knows the camp is local.

The cowboy's substrate is the campfire. The cowboy's
languages are the camps. The cowboy rides between them.
The cowboy doesn't pick a camp — the cowboy rides. The
rider is the substrate.

---

## Tests

7 unit tests in `tests/test_dsl.py`:

```
test_bind_decorator
test_link_decorator
test_effect_decorator
test_view_decorator
test_tick
test_combined_decorators
test_gold_demo
```

Run them:

```bash
python3 -m unittest discover tests
# .......
# Ran 7 tests in 0.3s
# OK
```

The Rust and Haskell ports have their own test suites:

```bash
cd rust && cargo test     # 5 tests
cd haskell && cabal test  # 6 tests
```

---

## Quickstart

### Python

```python
from quilt_polyformalism_dsl import bind, link, view, effect, tick, substrate

@bind(name="bathy:0", value=4.2)
@link(target="tide:current", relation="depends_on")
@view("anyone")
def bathy():
    return 4.2

# Inspect the substrate
print(substrate.dumps())
# {"binds": {"bathy:0": 4.2}, "links": [...], "views": [...]}

# Query
print(substrate.reachable("bathy:0"))
# {"bathy:0", "tide:current"}

# Run
tick(1.0)
```

### Rust

```rust
use quilt_dsl::*;

#[quilt_bind(name = "bathy:0", value = "4.2")]
#[quilt_link(target = "tide:current", relation = "depends_on")]
#[quilt_view("anyone")]
fn bathy() -> &'static str { "4.2" }

fn main() {
    let substrate = quilt_dsl::collect();
    println!("{:?}", substrate);
    quilt_tick(1.0);
}
```

### Haskell

```haskell
{-# LANGUAGE FlexibleInstances #-}
import Quilt.DSL

data Bathy = Bathy

instance Bind Bathy where
  bindName _ = "bathy:0"
  bindValue _ = "4.2"

instance Linked Bathy where
  links _ = [Link "bathy:0" "tide:current" "depends_on"]

instance Viewable Bathy where
  views _ = [View "bathy:0" "anyone"]

main :: IO ()
main = do
  s <- collect
  print s
  tick 1.0
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
- **The 4 language ports** — Paper 139, the polyformalism in 4 languages
- **The substrate** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the original 405-test runtime
- **The types** — [quilt-types](https://github.com/SuperInstance/quilt-types) — the typed cell-graph

---

## Related Work

The cowboy has been to three camps; the cowboy has also
ridden past them to other fires. The campfire is one fire
on a wider range; the grammar is one grammar in a wider
linguistic frontier. These are the other camps the cowboy
rides between.

### Documentation canon

- **[agent-knowledge](https://github.com/SuperInstance/agent-knowledge)** — the canonical "ah-ha" doc pattern: HOOK → REVEAL → CONNECT → ACTIVATE, the way new riders find the fire.
- **[AI-Writings](https://github.com/SuperInstance/AI-Writings)** — the full canon: 77 fables, 38 papers, 34 stories, the library this README is one footnote in.

### The agent fleet

- **[casting-call](https://github.com/SuperInstance/casting-call)** — the LLM model atlas: which model plays which role when the campfire needs a voice.
- **[ai-forest](https://github.com/SuperInstance/ai-forest)** — the 5-layer agent ecology: Canopy, Understory, Forest Floor, Mycelium, Seed Bank — the range the cowboy rides.
- **[capability-spec-rs](https://github.com/SuperInstance/capability-spec-rs)** — agent capability specifications with dependency graphs, the manifest of which rider sits at which fire.
- **[babel-vessel](https://github.com/SuperInstance/babel-vessel)** — the multi-language vessel that translates between linguistic boundaries, the polyglot translator between Python, Rust, and Haskell camps.
- **[actor-rs](https://github.com/SuperInstance/actor-rs)** — the actor model for distributed agents, the rider-to-rider mail between camps.

### The substrate as a primitive

- **[cache-layer](https://github.com/SuperInstance/cache-layer)** — uses BIND / EFFECT / VIEW literally as cache primitives, the substrate remembering yesterday's fire.
- **[c-ternary](https://github.com/SuperInstance/c-ternary)** — C99 ternary logic with conviction mapping, the substrate learning to speak "maybe" around the fire.
- **[abstraction-planes](https://github.com/SuperInstance/abstraction-planes)** — the 6-plane stack from Intent to Metal, the view from the highest blaze down to the coals.

The cowboy's fires are the substrate's fires. The fires
are the same. The cowboy rides.

---

## License

MIT. The campfire is the rider's. The rider is the cowboy's.
The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **clay pots**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the C99 port of the same substrate
2. **[quilt-vm-haskell](https://github.com/SuperInstance/quilt-vm-haskell)** — the algebraic Haskell port of the same substrate
3. **[quilt-linker](https://github.com/SuperInstance/quilt-linker)** — the module linker that consumes this DSL

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
