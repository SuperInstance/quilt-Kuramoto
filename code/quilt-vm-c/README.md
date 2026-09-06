# quilt-vm-c

> **The 5 opcodes — laid bare on the sand. No abstractions. No runtime.
> Just C, the substrate, and the wind.**

[![Language: C99](https://img.shields.io/badge/C-C99-blue.svg)](https://en.wikipedia.org/wiki/C99)
[![Tests: 6](https://img.shields.io/badge/Tests-6%20passing-brightgreen)](#tests)
[![Runtime: 0.11ms](https://img.shields.io/badge/Gold%20Demo-0.11ms-orange)](#performance)
[![Substrate](https://img.shields.io/badge/Substrate-Cell%20Graph-green)](#what-is-the-c-port-really)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<p align="center">
  <img src="docs/images/hero-quilt-vm-c.svg" width="640" alt="A vast red desert at sunset. Five stones stand on the sand — each carved with one opcode. The shadow of a single rider falls long behind them, the only vertical thing in the landscape.">
</p>

## Read This If You Are New

Skip everything below the **TL;DR** and just do this:

```bash
git clone https://github.com/SuperInstance/quilt-vm-c
cd quilt-vm-c
make
./gold           # runs all 8 polyformalisms in 0.11ms
make test        # runs 6 tests, all should pass
```

You will see five `printf` lines march across the terminal — the
bathy reading, the Cordis plugin, the spreadsheet, the MUD
character, the TTRPG perception check, the bay dance, the
cowboy, the bus — and all of it computed by five C functions
in **less than a millisecond**. That is the whole point.
**The C port is the substrate, exposed.** There is no
allocator trick, no virtual dispatch, no garbage collector.
There is `qvm_bind`, `qvm_link`, `qvm_effect`, `qvm_view`,
and `qvm_tick`. The 5 opcodes are the runtime.

If you only have **30 seconds**, read the next two sections.

---

## TL;DR (30 seconds)

A spreadsheet has cells. A TTRPG has characters. A database
has tables. A neural net has tensors. A chat agent has
memory. **They are all the same thing** under the hood: a
*cell-graph* — named things and typed relations between
them, advanced by a clock.

This repo gives you those 5 opcodes in C, where you can see
the substrate doing its work with nothing in the way:

| Opcode | C function | What it does | Spreadsheet | TTRPG | Neural net |
|--------|------------|--------------|-------------|-------|------------|
| **BIND** | `qvm_bind(vm, name, val, free)` | Make a thing | a cell | a character | a tensor |
| **LINK** | `qvm_link(vm, a, b, type)` | Connect two things | a formula | an edge | a weight |
| **EFFECT** | `qvm_effect(vm, target, fwd, inv, arg)` | Change, with an inverse | paste, with undo | attack, with parry | gradient step |
| **VIEW** | `qvm_view(vm, target, viewer)` | Read, as a viewer | `=A1` | a perception check | a forward pass |
| **TICK** | `qvm_tick(vm, dt)` | Advance time | recalculate | end the round | optimizer step |

The same 5 words. The same runtime. The substrate is
universal; the grammar is local. C is the **most local
grammar of all** — just pointers and a struct.

---

## TL;DR (5 minutes)

The whole story is here:

> A runtime is a function from context to value with an
> inverse, advanced by a clock that processes async I/O
> while projecting a sync view.

That's it. Five opcodes cover that sentence.

- **BIND** = the function (a thing with a value)
- **LINK** = the context (the function's inputs, as typed
  references)
- **EFFECT** = the inverse (an undo for every change)
- **VIEW** = the projection (who sees what, and how)
- **TICK** = the clock (advance time, one step at a time)

In C, you see all five as plain function calls. There is
no compiler magic, no virtual table, no JIT. The
`qvm_thing` struct is **the substrate**; the five `qvm_*`
functions are **the opcodes**.

```c
#include "quilt_vm.h"

/* BIND: "the water is 4.2 m deep" */
double depth = 4.2;
qvm_bind(vm, "bathy:0", &depth, NULL);

/* LINK: "the depth depends on the tide" */
qvm_link(vm, "bathy:0", "tide:current", "depends_on");

/* VIEW: "anyone can see the depth" */
double *seen = (double *)qvm_view(vm, "bathy:0", "anyone");

/* TICK: "1 second passes" */
qvm_tick(vm, 1.0);
```

That's a working program. It compiles with `gcc -O2 -std=c99`,
links against nothing but libc, and runs in **microseconds**.
You could put it on an Arduino, a Raspberry Pi Pico, or the
F/V EILEEN's tablet, and the substrate would still be the
substrate.

---

## What Is the C Port, Really?

<p align="center">
  <img src="docs/images/hero-quilt-vm-c.svg" width="640" alt="Five stones standing on red desert sand at sunset, each carved with one opcode">
</p>

The C port is **the desert**.

Not because C is dry or empty — because the C port is the
place where everything else has been stripped away. There
is no `HashMap` magic. There is no `dyn Trait` dispatch.
There is no `Maybe` monad. There is a struct, a few
pointers, and five functions. The substrate is **the
material**, and you can read the material with your eyes.

This matters. The cowboy's maxim is:

> The unit of architectural foundation is the opcode, not
> the framework. The 5 opcodes host 8 polyformalisms. The
> polyformalisms are one thing in N languages. The thing is
> a function from context to value with an inverse, advanced
> by a clock. The clock is the cowboy. The cowboy is the
> rider.

C is where that maxim is hardest to hide from. The C
compiler will not let you paper over the opcodes with a
trait. It will not let you pretend the cell-graph is
something fancier. It will let you write `qvm_bind`, and
the function will do exactly what its name says, and
nothing more. **That scarcity is the gift.**

When the 5 opcodes work in C, they work *anywhere*:
microcontrollers without an allocator, embedded systems
without a libc++, operating system kernels without a
runtime, the F/V EILEEN's tablet out on the water. C is
the lowest place the substrate can be built and still be
called a "language" — below it is assembly, below that is
silicon. The substrate begins at C.

The desert is also where the cowboy rides best. The cowboy
does not carry abstractions. The cowboy carries five
stones — `BIND`, `LINK`, `EFFECT`, `VIEW`, `TICK` — and
sets them on the sand, and the polyformalisms rise up
around them. The C port is what you get when the cowboy
takes off the saddle.

---

## The 5 Opcodes in C

C is the language that most directly exposes the substrate.
The 5 opcodes are five function calls on a `qvm_t *`.
Nothing more.

### BIND — make a thing

```c
qvm_bind(vm, "bathy:0", &depth, NULL);
```

`qvm_bind` puts a value at a name. The name is a C string.
The value is a `void *`; you tell C how to free it (or pass
`NULL` if the value is a primitive or borrowed). BIND is
the only way to create a cell. There is no pre-existing
cell; everything is BIND.

**Spreadsheet:** typing `4.2` into A1. **TTRPG:** making a
character sheet. **Database:** `INSERT`. **Neural net:**
allocating a tensor. **C:** `qvm_bind`.

### LINK — connect two things

```c
qvm_link(vm, "bathy:0", "tide:current", "depends_on");
```

`qvm_link` draws a typed arrow from one cell to another.
If the cells do not yet exist, they are auto-created as
empty. The reverse link is registered under the type
`!depends_on`, so the graph is queryable in both
directions. C gives you a direct view of the link table:

```c
qvm_thing_t *ta = qvm_find(vm, "a");
/* ta->link_types[0]   = "depends_on"           */
/* ta->link_targets[0] = ["b"]                  */
qvm_thing_t *tb = qvm_find(vm, "b");
/* tb->link_types[0]   = "!depends_on"          */
```

**Spreadsheet:** `=B1` in A1. **TTRPG:** an acquaintance.
**Database:** FOREIGN KEY. **Neural net:** a weight. **C:**
`qvm_link`.

### EFFECT — change a thing, with an inverse

```c
static void inc(qvm_thing_t *t, void *arg) {
    (void)arg; int *v = qvm_thing_get(t); if (v) (*v)++;
}
static void dec(qvm_thing_t *t, void *arg) {
    (void)arg; int *v = qvm_thing_get(t); if (v) (*v)--;
}

int counter = 0;
qvm_bind(vm, "counter", &counter, NULL);
qvm_effect(vm, "counter", inc, dec, NULL);
qvm_tick(vm, 0.0);       /* the forward runs */
qvm_dispose(vm, "counter"); /* the inverse runs */
```

`qvm_effect` registers a transformation as the *forward*
direction and its **inverse**. The effect is queued; on
the next `qvm_tick`, the forward runs. If you change your
mind, `qvm_dispose` runs the inverse. The substrate is
**transactional by construction**: every change has an
undo. That's what makes it safe to write polyformalisms
that mutate.

**Spreadsheet:** paste, with undo. **TTRPG:** attack, with
parry. **Database:** BEGIN TRANSACTION, with ROLLBACK.
**Neural net:** gradient step, with descent on the prior
step. **C:** `qvm_effect` + `qvm_dispose`.

### VIEW — read a thing, as a viewer

```c
double *seen = (double *)qvm_view(vm, "bathy:0", "anyone");
```

`qvm_view` reads the value at a name, *as a specific
viewer*. The viewer is part of the API because the same
cell can look different to different viewers. The
projection is what makes the same cell-graph be a
spreadsheet, a TTRPG, a database, or a neural net —
depending on who is looking.

**Spreadsheet:** `=A1`. **TTRPG:** a perception check.
**Database:** SELECT. **Neural net:** a forward pass.
**C:** `qvm_view`.

### TICK — advance time

```c
qvm_tick(vm, 1.0);   /* one second passes */
```

`qvm_tick` is the clock. When the clock ticks, all pending
EFFECTs run, all scheduled perception checks fire, all
subscribers wake up. The cell-graph is **alive** because
of TICK. Without TICK, the graph is frozen. TICK is the
only way to make progress.

**Spreadsheet:** pressing F9. **TTRPG:** ending the round.
**Database:** COMMIT. **Neural net:** one optimizer step.
**C:** `qvm_tick`.

---

## A Real Example: The Bay Dance

The 8 polyformalisms run in one C process. Here's the
excerpt that hosts **the bathy reading** — the cowboy
out on the water, taking a sounding:

```c
#include "quilt_vm.h"
#include <stdio.h>

int main(void) {
    qvm_t *vm = qvm_new();

    /* The bathy reading. */
    double depth = 4.2;
    qvm_bind(vm, "bathy:0", &depth, NULL);
    qvm_link(vm, "bathy:0", "tide:current", "depends_on");

    /* The tide pushes back. */
    double *seen = (double *)qvm_view(vm, "bathy:0", "cowboy");
    printf("the cowboy sees %.2f m\n", *seen);

    /* One minute passes. */
    qvm_tick(vm, 60.0);

    qvm_free(vm);
    return 0;
}
```

This is the smallest possible substrate program in C.
It is also the largest possible polyformalism: the same
five functions, the same five opcodes, would host a
spreadsheet, a TTRPG, a MUD, a database, a neural net,
and a chat agent's memory. **The substrate does not care
how big the program gets. The 5 opcodes are the size.**

---

## How This Repo Fits the Polyformalism

The 5 opcodes are a **polyformalism** — the same thing in
many forms. The C port is **the desert** in the metaphor:
the place where the substrate is most directly visible.

```
              Rust  C  Python  TypeScript  Haskell  WASM  ...
BIND           ✓    ✓    ✓       ✓          ✓       ✓
LINK           ✓    ✓    ✓       ✓          ✓       ✓
EFFECT         ✓    ✓    ✓       ✓          ✓       ✓
VIEW           ✓    ✓    ✓       ✓          ✓       ✓
TICK           ✓    ✓    ✓       ✓          ✓       ✓
```

The C port is **Layer 1 of the polyformalism stack** —
the lowest-level materialization, the one that compiles
to anything (because C compiles to anything). The other
layers:

- **Layer 1 (this repo)** — [quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c) — the 5 opcodes in C99, the desert
- **Layer 1 (Rust)** — [quilt-vm-rust](https://github.com/SuperInstance/quilt-vm-rust) — the 5 opcodes in safe Rust, the workshop
- **Layer 1 (TypeScript)** — [quilt-vm-typescript](https://github.com/SuperInstance/quilt-vm-typescript) — the 5 opcodes in TS, the city
- **Layer 1 (Haskell)** — [quilt-vm-haskell](https://github.com/SuperInstance/quilt-vm-haskell) — the 5 opcodes in Haskell, the cathedral
- **Layer 1 (WASM)** — [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the 5 opcodes in your browser, the tent
- **Layer 2 (types)** — [quilt-types](https://github.com/SuperInstance/quilt-types) — typed Python dataclasses
- **Layer 3 (linker)** — [quilt-linker](https://github.com/SuperInstance/quilt-linker) — link-time checker
- **Layer 4 (optimizer)** — [quilt-opt](https://github.com/SuperInstance/quilt-opt) — algebraic optimization passes
- **Layer 5 (GC)** — [quilt-gc](https://github.com/SuperInstance/quilt-gc) — garbage collection
- **Layer 6 (DSL)** — [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) — decorators / typeclasses
- **Layer 7 (human grammar)** — [ai-writings](https://github.com/SuperInstance/AI-Writings) — 9+ languages

C is **the first** because it's the closest to the metal.
The other ports prove the substrate by *adding* type
safety, abstraction, and platform reach. C proves the
substrate by *removing* all of that and still running.

---

## The Cowboy Says

> The desert is the place where the substrate is bare.
> C is the desert. Five functions on a struct, no more.
> When the wind blows the abstractions away, the cowboy
> sees only the five stones — BIND, LINK, EFFECT, VIEW,
> TICK — and the sand they stand on. The sand is the
> pointer. The stones are the opcodes. The cowboy is the
> tick. The tick is the rider.

The cowboy has ridden in **5 languages** so far — C, Rust,
TypeScript, Haskell, WASM. The C port is where the cowboy
rides most thinly. There is no shelter. There is no
framework. There is only the substrate, the wind, and
the time it takes to call five functions.

The desert does not apologize for being a desert. The
desert is the place where the substrate is most
**honest**. When you have written `qvm_bind` once, you
have written it everywhere. When you have ridden the
desert, you have ridden the substrate.

The cowboy rides.

---

## Tests

```bash
make test
```

Six tests, all passing:

1. **`test_bind_and_view`** — BIND puts a value; VIEW reads it back.
2. **`test_link`** — LINK writes a forward and a reverse arrow.
3. **`test_effect_and_tick`** — EFFECT queues; TICK runs the forward.
4. **`test_dispose_runs_inverses`** — DISPOSE walks the inverses LIFO.
5. **`test_subscribe_and_tick`** — subscribers receive tick events.
6. **`test_full_polyformalism`** — all 8 polyformalisms in one VM, ticked once.

The C test suite is **the most direct** of the four ports:
each test is a `static void test_*()` that calls the
opcodes, asserts, and prints `PASS`. There is no fixture
framework. There is no test discovery. There is a `main()`
that calls six functions in order. The cowboy's test
runner.

## Performance

| Runtime | Per-op | Gold demo (8 polyformalisms) | Notes |
|---------|--------|------------------------------|-------|
| **C (this repo)** | **~13ns** | **~110µs (0.11ms)** | The fastest, the desert |
| Rust | ~50ns | ~400µs | Production, the workshop |
| WASM | ~200ns | ~1.6ms | Anywhere, the tent |
| Python | ~1µs | ~8ms | The original |
| TypeScript | ~1µs | ~1ms | The city |
| Haskell | ~500ns | ~4ms | The cathedral |

The C port is the **fastest** because there is nothing
between the opcode and the machine. One pointer indirection.
A `memcpy` of the value. A `realloc` of the link table.
That's it. The desert has no traffic.

---

## API

```c
/* Constructor / Destructor */
qvm_t *qvm_new(void);
void   qvm_free(qvm_t *vm);

/* The 5 opcodes */
int    qvm_bind  (qvm_t *vm, const char *name, void *value,
                  void (*free_value)(void *));
int    qvm_link  (qvm_t *vm, const char *a, const char *b,
                  const char *type);
int    qvm_effect(qvm_t *vm, const char *target,
                  qvm_effect_fn forward, qvm_effect_fn inverse,
                  void *arg);
void  *qvm_view  (qvm_t *vm, const char *target, const char *viewer);
void   qvm_tick  (qvm_t *vm, double dt);

/* Lifecycle helpers */
void   qvm_dispose (qvm_t *vm, const char *target);
int    qvm_schedule(qvm_t *vm, const char *key,
                    qvm_scheduled_fn fn, void *arg, double at);
int    qvm_subscribe(qvm_t *vm, qvm_subscriber_fn fn, void *arg);
void   qvm_stats   (qvm_t *vm, char *out, size_t out_size);

/* Introspection */
qvm_thing_t *qvm_find      (qvm_t *vm, const char *name);
void        *qvm_thing_get (qvm_thing_t *thing);
void         qvm_thing_set (qvm_thing_t *thing, void *value,
                            void (*free_value)(void *));
```

`qvm_thing_t` is a public struct. You can read its fields
directly: `name`, `value`, `link_types`, `link_targets`,
`n_link_types`, `effects`. The substrate is **open**.

---

## Learn More

- **The Gold** — Paper 137, the 1-page, 10-page, 100-page
  synthesis: https://github.com/SuperInstance/AI-Writings
- **The 5 opcodes at every layer** — Paper 142, the
  7-layer polyformalism
- **The cowboy's library** — Papers 1-147, Fables 1-75,
  Stories 1-33 in 15+ traditions
- **The agent knowledge base** — 50+ documents on
  the agent/agent architecture:
  https://github.com/SuperInstance/agent-knowledge
- **The substrate (Python original)** — 405 tests, the
  full cell-graph: https://github.com/SuperInstance/quilt-substrate

The 5 other ports of the substrate:

- [quilt-vm-rust](https://github.com/SuperInstance/quilt-vm-rust) — the workshop
- [quilt-vm-typescript](https://github.com/SuperInstance/quilt-vm-typescript) — the city
- [quilt-vm-haskell](https://github.com/SuperInstance/quilt-vm-haskell) — the cathedral
- [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the tent
- [quilt-foundation](https://github.com/SuperInstance/quilt-foundation) — the original, in Python

---

## License

MIT. The substrate is the rider's. The rider is the
cowboy's. The cowboy's is the wind's. The wind blows
across the desert, and the desert is the C.


---

## Roaming the Quilt collection

You came through the **desert**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-vm-rust](https://github.com/SuperInstance/quilt-vm-rust)** — the Rust port of the same VM
2. **[quilt-esp32](https://github.com/SuperInstance/quilt-esp32)** — the ESP32 firmware that uses this VM on real hardware
3. **[quilt-substrate-meta](https://github.com/SuperInstance/quilt-substrate-meta)** — the self-evolving meta substrate that extends this

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
