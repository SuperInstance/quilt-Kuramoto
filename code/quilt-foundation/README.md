# quilt-foundation — The 5 Opcodes, Forged in 10 Rounds

> *The librarian's forge. Ten rounds of multi-model research, with each round dogfooding the prior round's output. The fire was the *function from context to value with an inverse*. What came out of the fire was five words: BIND, LINK, EFFECT, VIEW, TICK.*

[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-opcodes)
[![10 Rounds](https://img.shields.io/badge/10-Rounds-blueviolet)](#the-10-rounds-of-research)
[![8 Polyformalisms](https://img.shields.io/badge/8-Polyformalisms-green)](#the-8-polyformalisms)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<p align="center">
  <img src="docs/images/hero-foundation.svg" width="640" alt="Ten round-stones arranged in an arc, the central one the largest with the five opcodes BIND, LINK, EFFECT, VIEW, TICK inscribed in fire, and eight sparks rising from the central stone labeled with the eight polyformalisms — cell, plugin, sheet, MUD, TTRPG, boat, cowboy, bus">
</p>

## Read This If You Are New

Skip everything and just run the VM:

```bash
git clone https://github.com/SuperInstance/quilt-foundation
cd quilt-foundation
python3 code/quilt_vm.py
```

You will see a small demo print, then the 5 opcodes, then the 8
polyformalisms that they all fit inside. The whole VM is 200
lines. The whole demo is one Python file. **Read it in five
minutes; you will know what the foundation is.**

If you only have **30 seconds**, read the next two tables.

---

## TL;DR (30 seconds)

The Quilt is built on a thesis: *a runtime is a function from
context to value with an inverse, advanced by a clock that
processes async I/O while projecting a sync view*. That
sentence is dense. The five opcodes are the *operational
version* of that sentence — five words that cover it.

| Opcode | What it does | The thesis it covers |
|--------|--------------|----------------------|
| **BIND** | make a thing with a name and a value | the function (a value lives at a name) |
| **LINK** | connect two things with a typed relation | the context (the function's inputs, expressed as arrows) |
| **EFFECT** | run a transformation, with an inverse | the inverse (every change is undoable) |
| **VIEW** | read a thing, projected for a viewer | the projection (who sees what) |
| **TICK** | advance time by dt, drain pending I/O | the clock (async I/O, sync view) |

That is the whole foundation. The rest of this README explains
how five words were forged in ten rounds, and what the five
words build when you stack them up.

---

## TL;DR (5 minutes)

<p align="center">
  <img src="docs/images/diagram-forge-rounds.svg" width="640" alt="A librarian's study: books on the left labelled 'prior canon', a director in the center labelled 'director.py, 10 rounds, multi-model', a forge on the right with the 5-opcode VM, two purple models above the director feeding in — Hermes 405B and Qwen 72B">
</p>

The Quilt substrate is a cell-graph. The cell-graph is one
program that has been running for years, in many forms:
spreadsheets, MUDs, TTRPGs, the bay dance, the cowboy's
morning report. We kept asking: *what is the lowest common
abstraction*? Ten rounds of multi-model research later, the
answer is *the function from context to value with an inverse,
advanced by a clock*. The five opcodes are the operational
form of that answer.

The cast of each round was two models — **Hermes 405B** (the
long-form surprise) and **Qwen 72B** (the sensible deep). Each
model got the prior round's documentation and the round's
question. Each model returned: a continuation, recommendations,
open questions. The director (`director.py`) merged the
contributions, decided what to focus on next, and decided when
the foundation was clear.

By round 10 we had:

- The thesis (the function-with-inverse sentence)
- The 5 opcodes (BIND, LINK, EFFECT, VIEW, TICK)
- The VM (`code/quilt_vm.py`, 200 lines, 9 tests)
- The 8 polyformalisms (cell, plugin, sheet, MUD, TTRPG, boat, cowboy, bus)
- The 9th synthesis paper (Hermes's 1-page, 10-page, 100-page versions)
- The next things to build (cowboy, bus, bay dance)

This repo is the *forge*, not the cathedral. The 200-line VM is
the artifact. The 10 rounds are the recipe. The next things
are the cathedral.

---

## What is *the foundation*, really?

Picture a librarian's study. Bookshelves on every wall, filled
with the prior canon — papers about cells, about plugins,
about spreadsheets, about MUDs, about the bay dance. In the
middle of the room, a forge. Two alchemists sit at the forge,
each round. The alchemists read the prior round's notes, ask a
new question, and try to distil the canon down to its essence.
The essence, by round 5, is **a function from context to value
with an inverse, advanced by a clock**. By round 10, the
essence has been hammered into 5 words.

The librarian's study is the **director** (`director.py`). The
alchemists are the **cast** (Hermes 405B and Qwen 72B). The
forge is the **VM** (`code/quilt_vm.py`). The bookshelf is the
**prior canon** (every paper, every fable, every demo we have
ever built). The five words are the **foundation** that the
rest of the Quilt is laid on.

The foundation is *not* a framework. The cowboy is clear on
this: **the unit of architectural foundation is the opcode,
not the framework**. The five opcodes are the unit. The Quilt
is the application of those opcodes to many domains. The
substrate is the canonical domain. The cell, the plugin, the
sheet, the MUD, the TTRPG, the boat, the cowboy, the bus — all
*are* the opcodes, composed. The composition is the value.

---

## The 5 Opcodes

### BIND — make a thing

```python
vm.BIND("bathy:0", 4.2)
```

BIND puts a value at a name. The name is a string. The value
is anything. The cell exists until you BIND another value at
the same name, or until GC reaps it. **BIND is the only way
to create a cell.** There is no "pre-existing" cell; everything
is BIND.

| Domain | What BIND is |
|--------|--------------|
| Spreadsheet | typing `4.2` into cell A1 |
| TTRPG | creating a character sheet |
| Database | `INSERT INTO bathy VALUES (4.2)` |
| Neural net | `tensor = torch.zeros(...)` |
| Substrate | the cell at address `bathy:0` |

### LINK — connect two things

```python
vm.LINK("bathy:0", "tide:current", "depends_on")
```

LINK draws a typed arrow from one cell to another. The arrow
has a relation — `depends_on`, `fights`, `cites`,
`is_parent_of`, anything. The arrow is one-way unless you also
LINK the other direction; the runtime does maintain reverse
links for you.

| Domain | What LINK is |
|--------|--------------|
| Spreadsheet | a formula `=B1` in cell A1 |
| TTRPG | Gandalf's relationship to the One Ring |
| Database | a `FOREIGN KEY` constraint |
| Neural net | a weight between two layers |
| Substrate | a typed edge in the cell graph |

### EFFECT — change a thing, with an inverse

```python
vm.EFFECT("counter", lambda v: v + 1, lambda v: v - 1)
```

EFFECT registers a transformation as the *forward* direction
and its **inverse**. Once registered, you can call the
forward and it will run. If you decide to undo, you can call
the inverse. EFFECTs are **how time moves forward** in the
cell-graph. Without EFFECTs, nothing changes.

| Domain | What EFFECT is |
|--------|----------------|
| Spreadsheet | paste, with undo |
| TTRPG | an attack roll, with the parry response |
| Database | `BEGIN TRANSACTION`, with `ROLLBACK` |
| Neural net | a gradient step, with the previous step |
| Substrate | a state change on a cell |

### VIEW — read a thing, as a viewer

```python
vm.VIEW("bathy:0", "anyone")          # raw value
vm.VIEW("bathy:0", "scientist",       # projected
        projection=lambda v, who: f"{v:.2f} m")
```

VIEW reads the value at a name, *as a specific viewer*. The
viewer is part of the API because the same cell can look
different to different viewers. **VIEW is the access control
and the formatting in one.**

| Domain | What VIEW is |
|--------|--------------|
| Spreadsheet | `=A1` in a formula |
| TTRPG | a perception check |
| Database | `SELECT` |
| Neural net | a forward pass through this layer |
| Substrate | a renderer through an opener |

### TICK — advance time

```python
vm.TICK(1.0)   # one second passes
```

TICK is the clock. When the clock ticks, all pending EFFECTs
run, all subscribers wake up, all views may recompute. The
cell-graph is **alive** because of TICK. Without TICK, the
graph is frozen. TICK is the **only way to make progress**.

| Domain | What TICK is |
|--------|--------------|
| Spreadsheet | pressing F9 (recalculate) |
| TTRPG | ending the round |
| Database | `COMMIT` |
| Neural net | one optimizer step |
| Substrate | `substrate.advance_time(dt)` |

---

## The 10 Rounds of Research

The forge did not produce 5 opcodes in one shot. It took 10
rounds. Each round's question and contributions are in
`rounds/round_NN.md`. The progression:

| Round | Question (in brief) | What emerged |
|-------|---------------------|--------------|
| 1 | *What is lower than a function-with-inverse?* | Three primitives: Bit, Pointer, Function |
| 2 | *What is the lowest common abstraction?* | Five primitives: apply, getContext, storeValue, invert, if-then-else |
| 3 | *What runs first: the runtime or the model?* | A runtime that *is* a model; the cell-graph is the model |
| 4 | *Cells reduce to function-with-inverse. Plugins too. What else?* | Spreadsheets, MUDs, TTRPGs all reduce the same way |
| 5 | *5 primitives. How do they combine?* | The 4 compositions: cell, plugin, sheet, MUD |
| 6 | *What about perception? The DM's view?* | VIEW with a projection is a perception check |
| 7 | *What about the cowboy? The bus?* | TICK fires subscribers; the bus is a subscriber |
| 8 | *What about the bay dance? 20 boats?* | Each boat is a BIND, each tick a perception check, EFFECTs handle collisions |
| 9 | *Can the 5 words be reduced further?* | No. The 5 words are minimal. |
| 10 | *What did we learn? What did we leave open?* | The 1-page, 10-page, 100-page summary; the next things to build |

By round 5, the 5 opcodes were stable. Rounds 6 through 10
were about *what the opcodes host*, not *what the opcodes
are*. The 8 polyformalisms emerged in rounds 4 through 8. The
9th synthesis paper was written in round 10.

The director's `director.py` automates this. It runs a round,
reads the round's output, decides what to focus on next, and
decides when the foundation is clear. If you want to run your
own round, set `ZAI_TOKEN`, `DEEPSEEK_TOKEN`, `KIMI_TOKEN`,
`ANTHROPIC_TOKEN`, or `DEEPINFRA_TOKEN` and call:

```bash
python3 director.py --round 11 --question "What is the cowgirl's morning report?"
```

---

## The 8 Polyformalisms

The 5 opcodes host 8 polyformalisms — eight different *forms*
of the same thing. Each is implemented in `code/quilt_vm.py`
as a test that builds the polyformalism on top of the 5
opcodes:

| # | Polyformalism | What it is | The 5 opcodes it uses |
|---|---------------|------------|----------------------|
| 1 | **Quilt cell** | a tensor-encoded value at an address | BIND + LINK + EFFECT + VIEW |
| 2 | **Cordis plugin** | a context-aware effect with coeffects | BIND + LINK (coeffect) + EFFECT (with inv) |
| 3 | **Spreadsheet** | a cell that depends on others, with a formula | BIND + LINK (depends_on) + EFFECT (recalc) |
| 4 | **MUD room** | a text-described space with users in it | BIND + LINK (in) + VIEW |
| 5 | **TTRPG player** | a character with stats and perception | BIND + LINK (near) + VIEW (with projection) |
| 6 | **Bay dance** | 20 boats, each ticking on its own schedule | 20×BIND + 20×LINK + TICK + scheduled VIEW |
| 7 | **Cowboy's model** | a model the cowboy reads in the morning | BIND + LINK + VIEW |
| 8 | **Bus event** | a subscriber fired on every TICK | BIND + subscribe + TICK |

The same 5 opcodes. Eight different domains. The substrate is
universal; the polyformalism is local.

---

## A Real-World Example — the Bay Dance in 50 lines

```python
from code.quilt_vm import QuiltVM

vm = QuiltVM()
n_boats = 20

# 1. BIND — make 20 boats
for i in range(n_boats):
    vm.BIND(f"boat:{i}", {"x": float(i), "y": 0.0,
                            "course": "north"})

# 2. LINK — each boat is in the bay
for i in range(n_boats):
    vm.LINK(f"boat:{i}", "bay", "in")

# 3. EFFECT — a perception check (with inverse) for each boat
def perception(vm):
    for i in range(n_boats):
        boat = vm.VIEW(f"boat:{i}", "anyone")
        for j in range(n_boats):
            if i == j: continue
            other = vm.VIEW(f"boat:{j}", "anyone")
            if abs(boat["x"] - other["x"]) < 1.0:
                # too close, swap course
                vm.EFFECT(f"boat:{i}",
                            lambda v: {**v, "course": "south"}
                                     if v["course"] == "north"
                                     else {**v, "course": "north"},
                            lambda v: v)

# 4. TICK — run the dance for 5 ticks
for t in range(5):
    vm.schedule(f"check-{t}", perception, at=vm.time + 1.0)
    vm.TICK(1.0)

# 5. VIEW — read where the boats ended up
for i in range(n_boats):
    print(f"  boat:{i:02d} course={vm.VIEW(f'boat:{i}', 'anyone')['course']}")
```

This is a working distributed simulation. Twenty boats, each
with their own state, each reacting to neighbours via
perception checks, all running on five words. **The same five
words that run your spreadsheet.**

---

## How this fits the polyformalism

The 5 opcodes are the foundation; everything else in the Quilt
is built on top of them. Here is where the foundation fits in
the polyformalism stack:

| Layer | Repo | What it is |
|-------|------|------------|
| 0 (foundation) | **quilt-foundation** | the 5 opcodes and the 10 rounds of research |
| 0 (machine) | [quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c) | the 5 opcodes in C, 0.11ms per tick |
| 0 (machine) | [quilt-vm-rust](https://github.com/SuperInstance/quilt-vm-rust) | the 5 opcodes in Rust, ~0.5ms |
| 0 (machine) | [quilt-vm-typescript](https://github.com/SuperInstance/quilt-vm-typescript) | the 5 opcodes in TypeScript, ~1ms |
| 0 (machine) | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) | the 5 opcodes in the browser |
| 1 (types) | [quilt-types](https://github.com/SuperInstance/quilt-types) | the 5 opcodes as Python dataclasses |
| 2 (linker) | [quilt-linker](https://github.com/SuperInstance/quilt-linker) | the 5 opcodes as a link-time checker |
| 3 (optimizer) | [quilt-opt](https://github.com/SuperInstance/quilt-opt) | the 5 opcodes as algebraic optimization passes |
| 4 (GC) | [quilt-gc](https://github.com/SuperInstance/quilt-gc) | the 5 opcodes as a garbage collector |
| 5 (DSL) | [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) | the 5 opcodes as decorators / typeclasses |
| 6 (canon) | [AI-Writings](https://github.com/SuperInstance/AI-Writings) | the 5 opcodes in 9+ human languages |
| 7 (integration) | [quilt-ecosystem-demo](https://github.com/SuperInstance/quilt-ecosystem-demo) | every piece, running together |

If you want to *understand* the foundation, this is the place
to start. If you want to *port* it, the four
`quilt-vm-*` repos are where the same opcodes live in C, Rust,
TypeScript, and WASM. If you want to *use* it, the
[quilt-substrate](https://github.com/SuperInstance/quilt-substrate)
is the canonical Python implementation with 11 primitives and
8 openers.

---

## The Cowboy Says

> *The unit of architectural foundation is the opcode, not the
> framework. The 5 opcodes host 8 polyformalisms. The
> polyformalisms are one thing in N languages. The thing is a
> function from context to value with an inverse, advanced by a
> clock. The clock is the cowboy. The cowboy is the rider.*

The foundation is the rider's horse. The opcodes are the
horse's five gaits — *bind, link, effect, view, tick*. The
polyformalisms are the trails. The rider chooses the trail.
The clock is the rider's breathing. **Five words, eight
trails, one rider.**

---

## API

The public API is `code/quilt_vm.py`. Import it and use the
`QuiltVM` class:

```python
from quilt_foundation.code.quilt_vm import QuiltVM

vm = QuiltVM()
vm.BIND("bathy:0", 4.2)
vm.LINK("bathy:0", "tide:current", "depends_on")
vm.EFFECT("bathy:0", lambda v: 5.0, lambda v: 4.2)
print(vm.VIEW("bathy:0", "anyone"))  # 5.0
vm.TICK(1.0)
```

Plus a director (`director.py`) for running your own
multi-model rounds, and 10 round docs in `rounds/` for
re-reading the research.

## Tests

The 9 tests in `code/quilt_vm.py` cover the 8 polyformalisms
plus a full-polyformalism test:

```bash
python3 -c "from code.quilt_vm import *; test_quilt_cell_in_vm(); test_cordis_plugin_in_vm(); test_spreadsheet_cell_in_vm(); test_mud_room_in_vm(); test_ttrpg_perception_check(); test_bay_dance_perception_check(); test_cowboy_morning_via_view(); test_bus_event_via_tick(); test_full_polyformalism(); print('all 9 tests pass')"
```

(Or just run `python3 code/quilt_vm.py` — the demo at the
bottom runs an in-process test of the full polyformalism.)

## Repository layout

```
quilt-foundation/
├── code/
│   └── quilt_vm.py          # the 5-opcode VM (200 lines, 9 tests)
├── rounds/
│   ├── round_01.md          # 10 rounds of multi-model research
│   ├── round_02.md
│   ├── ...
│   └── round_10.md
├── director.py              # the multi-round orchestrator
├── docs/
│   └── images/              # the SVGs in this README
└── README.md
```

## Learn More

- The 5 opcodes in the browser: [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm)
- The 5 opcodes in C, Rust, TypeScript: see the `quilt-vm-*` repos
- The 5 opcodes as Python dataclasses: [quilt-types](https://github.com/SuperInstance/quilt-types)
- The 5 opcodes as a link-time checker: [quilt-linker](https://github.com/SuperInstance/quilt-linker)
- The 5 opcodes as algebraic optimization: [quilt-opt](https://github.com/SuperInstance/quilt-opt)
- The 5 opcodes as a garbage collector: [quilt-gc](https://github.com/SuperInstance/quilt-gc)
- The 5 opcodes as decorators: [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl)
- The polyformalism canon: [AI-Writings](https://github.com/SuperInstance/AI-Writings)
- The agent knowledge index: [agent-knowledge](https://github.com/SuperInstance/agent-knowledge)
- The casting-call: [casting-call](https://github.com/SuperInstance/casting-call)
- The substrate: [quilt-substrate](https://github.com/SuperInstance/quilt-substrate)
- The flagship demo: [quilt-ecosystem-demo](https://github.com/SuperInstance/quilt-ecosystem-demo)

## License

MIT.

---

*— Mavis, 24 August 2026*
*The librarian's forge. Ten rounds. Five opcodes. Eight polyformalisms. One rider. The rider reads the morning report, picks a trail, and rides.*


---

## Roaming the Quilt collection

You came through the **10 round-stones + fire**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-substrate-meta](https://github.com/SuperInstance/quilt-substrate-meta)** — the deeper engineering write-up of the same substrate
2. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the bare-metal C99 port of the same opcodes
3. **[quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm)** — the browser-friendly version of the same runtime

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
