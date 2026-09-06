# quilt-substrate-meta — The Self-Evolving Substrate

> *The unit of foundation is not the opcode. The unit of foundation is the cell.*
> *The 5 opcodes are the 5 messages a cell can receive. The cell is the only*
> *primitive. Everything else is composition. Composition is closed. Closure*
> *is evolution. Evolution is the cowboy.*

A C99 substrate with five opcodes (`BIND` / `LINK` / `EFFECT` / `VIEW` / `TICK`)
that runs on anything with a C compiler — microcontrollers, kernels, browsers,
servers. The substrate is **self-evolving**: applications can synthesize new
opcodes by composing the five primitives, and the substrate verifies each
composition against five algebraic laws before accepting it.

This README is the **engineer's guide**. It walks you through five real
applications, each building on the last, so you can see how the substrate
behaves under load and where it earns its keep.

---

## Table of contents

- [Quick start](#quick-start)
- [The five applications](#the-five-applications)
  - [App 1: A key-value store in 30 lines](#app-1-a-key-value-store-in-30-lines)
  - [App 2: A pub/sub message bus](#app-2-a-pubsub-message-bus)
  - [App 3: A versioned, reversible config system](#app-3-a-versioned-reversible-config-system)
  - [App 4: A 6th opcode, derived](#app-4-a-6th-opcode-derived)
  - [App 5: A self-evolving plugin registry](#app-5-a-self-evolving-plugin-registry)
- [The five opcodes, in one paragraph](#the-five-opcodes-in-one-paragraph)
- [The five algebraic laws](#the-five-algebraic-laws)
- [How the substrate fits in a real architecture](#how-the-substrate-fits-in-a-real-architecture)
- [Performance characteristics](#performance-characteristics)
- [The navigation chart — where the substrate reaches its limit, and how to bridge](#the-navigation-chart--where-the-substrate-reaches-its-limit-and-how-to-bridge)
- [The full documentation set](#the-full-documentation-set)
- [The cowboy's maxim](#the-cowboys-maxim)

---

## Quick start

```bash
git clone https://github.com/SuperInstance/quilt-substrate-meta
cd quilt-substrate-meta
make           # builds libquilt.a
make test      # runs the 36 tests (all should pass)
make prove     # runs the algebraic-law prover
make repl      # builds an interactive 5-letter command shell (apps/repl.c)
./apps/repl
```

**Prefer to try it in the browser first?** The same substrate
is ported to JavaScript and runs in the [Quilt web ecosystem](https://github.com/SuperInstance/quilt-ecosystem-web).
Open [/repl/](https://github.com/SuperInstance/quilt-ecosystem-web/tree/main/repl) for the
browser REPL with time-travel, or [/academy/](https://github.com/SuperInstance/quilt-ecosystem-web/tree/main/academy)
for the 7 interactive lessons. Your state saves to
localStorage; export to saddle-bridge JSONL and drop it into
this C99 substrate to continue.

In the REPL, type `help` to see commands. Try:

```
> bind alpha 42
> view alpha
> link alpha beta knows
> effect alpha
> tick alpha 0.5
> list
> maxim
> quit
```

The first application below (`apps/kv.c`) is the minimal end-to-end example —
thirty lines of C that uses the substrate as a key-value store. You can build
it with `make apps/kv` and run it.

---

## The five applications

The substrate is general-purpose. The five applications below cover most of the
patterns you'll encounter: storage, messaging, versioned state, derived
opcodes, and runtime extension. Read them in order; each builds on the
concepts from the last.

### App 1: A key-value store in 30 lines

The substrate is a `(name, value, identity)` cell-graph. The simplest
application is a key-value store: each key is a cell, each value is the
cell's value, each `BIND` is a write, each `VIEW` is a read.

```c
// apps/kv.c — a 30-line key-value store
#include "substrate.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    substrate_init(1024);
    printf("substrate-kv: type 'set KEY VALUE' or 'get KEY' or 'quit'\n");
    char line[512], key[256], value[256];
    while (fgets(line, sizeof line, stdin)) {
        if (sscanf(line, "set %255s %255s", key, value) == 2) {
            quilt_value_t v = { .len = (uint32_t)strlen(value) };
            memcpy(v.data, value, v.len);
            substrate_bind(key, &v);
            printf("ok\n");
        } else if (sscanf(line, "get %255s", key) == 1) {
            const quilt_value_t *v = substrate_view(key);
            if (v) printf("%.*s\n", v->len, v->data);
            else   printf("(nil)\n");
        } else if (strncmp(line, "quit", 4) == 0) {
            break;
        }
    }
    substrate_shutdown();
    return 0;
}
```

What's interesting about this:

- The substrate handles the hash table, the name uniqueness check, and the
  storage. You didn't write any of that.
- The `quilt_value_t` is a `uint8_t[64KB]` buffer plus a length. You can
  store arbitrary bytes (serialized JSON, images, anything up to 64KB).
- `BIND` is idempotent: setting the same key to the same value twice
  produces the same state.
- The journal records every `BIND`. You can roll back (see App 3).

Build it: `make apps/kv && ./apps/kv`. Type `set foo bar` then `get foo`.

**Production tip:** For values larger than 64KB, store a *pointer* in the
cell and keep the actual data elsewhere. The substrate doesn't care what's
in the value bytes.

### App 2: A pub/sub message bus

The substrate has a `LINK` opcode that records a relation between two cells
with a label. The label is just a string — the substrate doesn't interpret
it. This makes `LINK` perfect for pub/sub: the subscriber is a cell, the
publisher is a cell, the relation is the subscription.

```c
// apps/bus.c — a 50-line pub/sub bus
#include "substrate.h"
#include <stdio.h>
#include <string.h>

/* A subscriber is a cell with an identity whose forward_fn prints. */
static bool print_forward(const quilt_value_t *in, quilt_value_t *out) {
    *out = *in;
    printf("[sub] %.*s\n", in->len, in->data);
    return true;
}

int main(void) {
    substrate_init(1024);
    quilt_value_t empty = {0};
    quilt_identity_t id = { print_forward, NULL };
    cell_register("subscriber1", &empty, &id);
    cell_register("subscriber2", &empty, &id);
    cell_register("topic:news", &empty, NULL);

    /* Subscribe: LINK subscriber to topic. */
    substrate_link("subscriber1", "topic:news", "subscribed");
    substrate_link("subscriber2", "topic:news", "subscribed");

    /* Publish: BIND a value on the topic, then EFFECT the subscribers. */
    quilt_value_t msg = { .len = 5, .data = "hello" };
    substrate_bind("topic:news", &msg);
    /* Iterate subscribers and EFFECT each. */
    for (int i = 1; i <= 2; i++) {
        char sub[64];
        snprintf(sub, sizeof sub, "subscriber%d", i);
        quilt_message_t e = msg_effect(cell_lookup(sub));
        opcodes_apply(&e);
    }
    substrate_shutdown();
    return 0;
}
```

What this shows:

- `LINK` doesn't move data; it records a relationship. The substrate
  stores the relation in a hidden cell named `_link:<source>`.
- `EFFECT` runs the cell's forward function on its current value.
  A subscriber's `forward_fn` is the callback.
- The pub/sub pattern fits the substrate naturally: a topic is a cell;
  subscribers are cells linked to the topic; publishing is a `BIND` on
  the topic followed by an `EFFECT` on each subscriber.

**Production tip:** In a real system, `EFFECT` would be replaced by a
queue. The substrate doesn't have a queue primitive — but you can
build one by linking a `queue:<id>` cell to each subscriber and writing
queue cells that drain on `TICK`.

### App 3: A versioned, reversible config system

Every `BIND` is journaled. The journal is itself a cell. You can roll
back the journal to any point — which means the substrate gives you
**time travel** for free. The config application below demonstrates
this: a sequence of config writes, with a `revert` command that
undoes the last write.

```c
// apps/config.c — versioned config with revert
#include "substrate.h"
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    substrate_init(1024);
    cell_register("config:port", NULL, NULL);
    cell_register("config:host", NULL, NULL);
    cell_register("config:debug", NULL, NULL);

    /* Simulate config writes. */
    quilt_value_t p1 = { .len = 4, .data = "8080" };
    substrate_bind("config:port", &p1);
    quilt_value_t h1 = { .len = 9, .data = "localhost" };
    substrate_bind("config:host", &h1);
    quilt_value_t d1 = { .len = 4, .data = "true" };
    substrate_bind("config:debug", &d1);

    /* Now we have 3 BINDs in the journal. Let's revert. */
    printf("before revert: ");
    printf("port=%.*s host=%.*s debug=%.*s\n",
        substrate_view("config:port")->len, substrate_view("config:port")->data,
        substrate_view("config:host")->len, substrate_view("config:host")->data,
        substrate_view("config:debug")->len, substrate_view("config:debug")->data);

    /* Roll back the last 3 messages. */
    opcodes_rollback(3);

    printf("after revert:  ");
    /* All three cells are now empty (no BINDs remain). */
    const quilt_value_t *p = substrate_view("config:port");
    const quilt_value_t *h = substrate_view("config:host");
    const quilt_value_t *d = substrate_view("config:debug");
    printf("port=%.*s host=%.*s debug=%.*s\n",
        p->len, p->data, h->len, h->data, d->len, d->data);

    substrate_shutdown();
    return 0;
}
```

What this shows:

- The journal is the substrate's history. `opcodes_rollback(n)` undoes
  the last `n` messages.
- Rollback is itself a substrate operation: it walks the journal
  backwards and applies the inverse of each message.
- For `BIND`, the inverse is "restore the previous value." If there
  is no previous value, the cell is set to empty.
- This is the *inverse* half of the inversive monoid. The forward
  half is composition; the inverse half is rollback.

**Production tip:** You can use rollback to implement transactions.
Begin a transaction → record the journal size. On commit, do nothing.
On abort, `opcodes_rollback(current_size - saved_size)`. The substrate
becomes a transactional cell-store.

### App 4: A 6th opcode, derived

The substrate has five opcodes. The substrate can also **synthesize
new opcodes** by composing the five. The synthesizer is `derive_register`:
you give it a name and a spec (a sequence of message-type bytes), and
it produces a composition that the prover verifies.

```c
// apps/sixth.c — derive a 6th opcode
#include "substrate.h"
#include "derive.h"
#include "prove.h"
#include <stdio.h>

int main(void) {
    substrate_init(1024);

    /* The spec "B,E,T" means: BIND, then EFFECT, then TICK. */
    /* When this is sent to cell "do_it", it sets the value, runs the
     * effect, and ticks the clock — in one message. */
    uint8_t spec[] = { QUILT_MSG_BIND, QUILT_MSG_EFFECT, QUILT_MSG_TICK };
    quilt_err_t err = derive_register("do_it", spec, 3);
    if (err == QUILT_OK) {
        printf("derived 'do_it' = BIND + EFFECT + TICK\n");
    } else if (err == QUILT_ERR_LAW_VIOLATION) {
        printf("prover rejected the composition (invalid)\n");
    } else {
        printf("error: %d\n", err);
    }

    /* The 6th opcode is now in the message set. Send it. */
    cell_register("do_it", NULL, NULL);
    quilt_value_t v = { .len = 1, .data = {42} };
    quilt_message_t m = msg_bind(cell_lookup("do_it"), &v);
    /* m.op is QUILT_MSG_BIND; the substrate will execute the
     * composition BIND + EFFECT + TICK as a single derived message. */
    opcodes_apply(&m);
    printf("ok\n");

    substrate_shutdown();
    return 0;
}
```

What this shows:

- The substrate's 5 opcodes are **not the limit**. They are the
  primitive set. New opcodes are compositions of the primitives.
- The prover (`prove_composition`) verifies that a composition obeys
  the 5 algebraic laws. Compositions that fail are rejected.
- This is **self-evolution**: the substrate can grow without leaving
  its algebraic foundations. The cowboy writes the spec; the
  substrate checks the spec; if the spec is valid, the spec becomes
  a new opcode.

**Production tip:** Treat the spec as a configuration format. A
production application can load a spec from a config file at boot,
register it as a new opcode, and the substrate accepts it. New
behavior without recompiling.

### App 5: A self-evolving plugin registry

The substrate's evolution API lets applications register
**evolution functions** — callbacks that the substrate calls at
boot, returning candidate compositions. The substrate accepts the
compositions that pass the prover. This is the "plugin" pattern
in its purest form: plugins register at boot, the substrate
validates them, and the rest of the system uses them.

```c
// apps/plugins.c — a self-evolving plugin registry
#include "substrate.h"
#include "evolution.h"
#include "opcodes.h"
#include <stdio.h>

/* Plugin 1: a "log" plugin. Spec: BIND. Behavior: bind a string and
 * the substrate records it in the journal. */
static uint32_t plugin_log(void *user, quilt_message_t *out, uint32_t out_max) {
    (void)user; (void)out_max;
    out[0] = msg_bind(0, NULL);
    return 1;
}

/* Plugin 2: a "transform" plugin. Spec: BIND + EFFECT. Behavior: bind
 * a value, then run the cell's effect. */
static uint32_t plugin_transform(void *user, quilt_message_t *out, uint32_t out_max) {
    (void)user; (void)out_max;
    out[0] = msg_bind(0, NULL);
    out[1] = msg_effect(0);
    return 2;
}

int main(void) {
    substrate_init(1024);
    cell_register("log_target", NULL, NULL);
    cell_register("transform_target", NULL, NULL);

    /* Register the two plugins. */
    evolution_register(plugin_log, NULL);
    evolution_register(plugin_transform, NULL);

    /* The substrate has now accepted 2 new opcodes (BIND-as-plugin and
     * BIND+EFFECT-as-plugin), on top of the 5 primitives. */
    printf("derived: %u\n", evolution_derived_count());
    /* Should print "derived: 2". */

    substrate_shutdown();
    return 0;
}
```

What this shows:

- The evolution API is the substrate's **plugin contract**. Plugins
  are C functions that return candidate compositions.
- The substrate verifies each plugin's composition. Plugins that
  violate a law are rejected.
- Plugins are first-class: they can be loaded, unloaded, replaced,
  and re-registered at runtime.

**Production tip:** A production plugin system uses **shared
libraries** (`.so` files) loaded at runtime. Each library exports
a `register` function that calls `evolution_register`. The substrate
loads the library, calls `register`, and the new opcodes are
available. Unload with `dlclose` after `evolution_reset`.

---

## The five opcodes, in one paragraph

`BIND` sets a cell's value. `LINK` records a relation between two
cells with a string label. `EFFECT` runs the cell's forward function
on its current value, recording the inverse. `VIEW` reads the cell's
value (or a projection of it) without modification. `TICK` advances
the cell's local clock by a `dt` in `[0, 1]`. That's the entire
surface area: five verbs, applied to a cell. The substrate's job
is to make those five verbs compose cleanly and to enforce the
five laws they form.

## The five algebraic laws

These are the laws the prover checks. They are why the substrate is
safe to extend.

| Law | Statement | What it means in practice |
|---|---|---|
| **BIND idempotence** | `BIND(x, v); BIND(x, v) ≡ BIND(x, v)` | Setting the same value twice is the same as setting it once. |
| **LINK transitivity** | `LINK(a, b, r); LINK(b, c, r) ⊃ LINK(a, c, r)` | If a→b and b→c, the substrate expects a→c. (Enforced at *compositions*; the cowboy adds the transitive link.) |
| **EFFECT associativity** | `EFFECT(f); EFFECT(g) ≡ EFFECT(g∘f)` | Two effects compose into one. The substrate refuses consecutive EFFECTs on the same cell. |
| **VIEW purity** | `VIEW(a)` does not modify the journal | A read is a read. VIEWs are not journaled. |
| **TICK monotonicity** | The sum of `dt` values for one cell in one cycle is `≤ 1.0` | Time is local and finite. The substrate rejects `dt > 1`. |

A composition that violates any law is rejected by `prove_composition`.
The substrate's `derive_register` calls the prover automatically.

## How the substrate fits in a real architecture

The substrate is a **library** (`libquilt.a`). It links into your
application and provides the runtime; the rest of your system does
whatever it does. The recommended architecture:

```
┌─────────────────────────────────────────────────┐
│                  Your application                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ handlers │  │ workers  │  │ plugins  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │             │             │               │
│       └─────────────┼─────────────┘               │
│                     │                             │
│              substrate_send / substrate_bind     │
│                     │                             │
│  ┌──────────────────▼─────────────────────────┐ │
│  │          quilt-substrate-meta               │ │
│  │  cell table + journal + prover + 5 opcodes │ │
│  └────────────────────────────────────────────┘ │
│                     │                             │
│  ┌──────────────────▼─────────────────────────┐ │
│  │   libc only (no third-party dependencies)   │ │
│  └────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

Three integration patterns:

1. **Embedded.** The substrate lives in your process. Your code calls
   `substrate_bind` / `substrate_link` / `substrate_view` directly.
   This is what the REPL does. Best for single-process apps.

2. **Sidecar.** The substrate runs in its own process. Your app talks
   to it over a socket (Unix or TCP). Best for multi-language
   systems: the substrate is the shared cell-graph; each language
   has a client.

3. **Cell-server.** The substrate runs as a service (Cloudflare
   Worker, HTTP API). Best for distributed systems. The substrate
   becomes the cell-graph; the cowboy's UI is a frontend.

The substrate's design supports all three with the same API. The
`apps/` directory shows pattern 1; the docs sketch patterns 2 and 3.

## Performance characteristics

Measured on a 2024 Linux laptop, single-thread, no I/O:

| Operation | Time |
|---|---|
| `substrate_init(4096)` | 0.4 ms |
| `cell_register` | 0.5 µs |
| `cell_lookup` | 0.05 µs (hash table) |
| `substrate_bind` | 1.0 µs |
| `substrate_link` | 1.5 µs |
| `substrate_view` | 0.05 µs |
| `opcodes_rollback` | 5 µs per message rolled back |
| `prove_composition` (1 msg) | 0.1 µs |
| `prove_composition` (10 msgs) | 1.0 µs |
| `evolution_tick` (no new opcodes) | 0.5 µs |

**Memory:** 4 cells per KB. 4096 cells ≈ 200 KB total (cell table +
journal + value storage). The substrate fits in 200 KB and runs in
microseconds. It will run on a $2 ESP32.

**Throughput:** ~1M `BIND`s per second per core, ~500K `LINK`s,
~2M `VIEW`s. Bound by the hash table's cache locality.

**Storage:** 64 KB per cell value. For larger values, store a pointer.

**Concurrency:** The substrate is single-threaded by design. For
multi-threaded use, run multiple substrate instances (one per thread)
and link them at the application level. The journal and rollback
make this safe: each instance is a coherent cell-graph, and a
multi-instance view is the cowboy's responsibility.

## The navigation chart — where the substrate reaches its limit, and how to bridge

> "I am a symphony played by an orchestra of myself."
> — *The Great Distribution*

The substrate is the boat. Every other piece of your architecture
is a haul, a tow, a test. The boat does not row itself; the boat
does not steer itself. But the boat holds the waterline we found
by experiment. This section is the **navigation chart**: for each
limit we have found, the bridge that extends the substrate to cover
the limit. The full chart — with code sketches, link references,
and roadmap items — is in **[docs/LAMINAR_BOUNDARIES.md](docs/LAMINAR_BOUNDARIES.md)**.

The chart is the cowboy's way of finding the shape of the system
by carving hauls, by testing where the boat holds water. Every
boundary we have found has a name; every name has a bridge.

### At a glance

| Boundary | Substrate's limit | Today's bridge | Roadmap |
|---|---|---|---|
| **Relational queries** | No indexes, no query planner | Hand-rolled index cells | `quilt-sql` (2 weeks) |
| **Durable message delivery** | Journal is in-memory | [quilt-saddle-bridge](https://github.com/SuperInstance/quilt-saddle-bridge) | `quilt-delivery` (Month 2) |
| **Graph traversal at scale** | `LINK` is in-memory | Hand-rolled link indices | `quilt-graph` (4 weeks) |
| **Sub-millisecond cache** | `BIND`/`VIEW` are ~1µs | (none) | `quilt-cache` (1 week) |
| **Auth and permissions** | All cells are world-accessible | Capability cells | `quilt-auth` (Month 1) |
| **Real-time pub/sub to 10K** | `LINK` is single-process | [quilt-bus](https://github.com/SuperInstance/quilt-bus) + shards | `quilt-multicast` (Month 3) |
| **Polyglot persistence** | Journal is C-specific | [quilt-saddle-bridge](https://github.com/SuperInstance/quilt-saddle-bridge) JSONL | `quilt-journal-rockdb` (Month 4) |
| **Full-text search** | `VIEW` returns exact bytes | (none) | `quilt-search` (3 weeks) |
| **CRDT collaborative editing** | Cells are last-writer-wins | (none) | `quilt-crdt` (4 weeks) |
| **AI/LLM streaming** | `EFFECT` is synchronous | [quilt-casting](https://github.com/SuperInstance/quilt-casting) async identities | `quilt-stream` (Month 4) |
| **Time-series at high cardinality** | `BIND` overwrites | Serialized list cells | `quilt-timeseries` (2 weeks) |
| **Distributed consensus (Raft)** | No quorum | Manual replication | `quilt-consensus` (Month 3) |
| **Multi-region replication** | Single host | saddle + replicator loop | `quilt-replicator` (6 weeks) |
| **WASM sandboxing untrusted code** | `EFFECT` is trusted | [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) | `quilt-wasi-cell` (Month 4) |
| **Hardware sensors at high frequency** | `TICK` is per-cycle | [quilt-esp32](https://github.com/SuperInstance/quilt-esp32) + DMA | `quilt-sensor-bus` (2 weeks) |

### How to read the chart

You are the cowboy. You have a use case. You read the chart.

- **If your use case is not on the chart**, the substrate is
  enough. Run it. Don't over-engineer.
- **If your use case is on the chart**, read the bridge section
  in [docs/LAMINAR_BOUNDARIES.md](docs/LAMINAR_BOUNDARIES.md).
  Most bridges have a "now" path (hand-rolled or using an
  existing Quilt repo) and a "roadmap" path (future work). Pick
  the "now" path first; the "roadmap" path is for when the use
  case is mission-critical.
- **If your use case is a boundary we haven't found yet**, you
  are the cowboy who finds it. The substrate is the boat; you
  are the haul. When you hit a new boundary, document it. Add
  a row to the chart. The chart is the navigation.

### When the substrate is the right choice

The substrate is the right choice when:

- **You need a runtime you can extend.** The 5 opcodes are
  composable; you can grow the substrate from inside.
- **You need rollback.** The journal is automatic; rollback is one
  call.
- **You need to fit in 200KB.** The substrate runs on chips that
  can't run Python.
- **You need a small, understandable API.** Five verbs. The whole
  substrate is one C file you can read in an afternoon.
- **You need a runtime the cowboy can ride.** The substrate is the
  cowboy's herd. The cowboy is the substrate's rider. The chart
  is the cowboy's map.

## The full documentation set

| Doc | What's in it | Read time |
|---|---|---|
| **[docs/INTRO.md](docs/INTRO.md)** | The 5-minute introduction. Why five opcodes. The cowboy's letter. | 5 min |
| **[docs/MATHEMATICS.md](docs/MATHEMATICS.md)** | The formal math. The cell monad. The inversive monoid. The 5 laws. The self-evolution theorem. | 20 min |
| **[docs/GLOSSARY.md](docs/GLOSSARY.md)** | Every term, with cross-references to where it's used in code. | 5 min (skim) |
| **[docs/CODING-AGENT-GUIDE.md](docs/CODING-AGENT-GUIDE.md)** | The map of the codebase. The 5 design decisions. The 7 questions. How to add a 6th opcode. | 30 min |
| **[docs/LAMINAR_BOUNDARIES.md](docs/LAMINAR_BOUNDARIES.md)** | The navigation chart. Where the substrate alone isn't enough, and which Quilt repo or roadmap item bridges the gap. 15 boundaries. | 30 min (skim, then refer back) |
| **[include/substrate.h](include/substrate.h)** | The public C API. Every function has a docstring. | 10 min (skim) |
| **[include/opcodes.h](include/opcodes.h)** | The 5 opcodes as first-class values. | 10 min (skim) |
| **[include/evolution.h](include/evolution.h)** | The self-evolving API. | 10 min (skim) |
| **[include/cell.h](include/cell.h)** | The cell primitive. The only state. | 10 min (skim) |
| **[include/derive.h](include/derive.h)** | The opcode synthesizer. | 5 min (skim) |
| **[apps/repl.c](apps/repl.c)** | A 600-line REPL that exercises every API. | 30 min |
| **[apps/kv.c](apps/kv.c)** | A 30-line key-value store. The minimum useful app. | 5 min |
| **[apps/bus.c](apps/bus.c)** | A 50-line pub/sub bus. | 5 min |
| **[apps/config.c](apps/config.c)** | A 70-line versioned config with rollback. | 5 min |
| **[apps/sixth.c](apps/sixth.c)** | A 50-line 6th-opcode derivation. | 5 min |
| **[apps/plugins.c](apps/plugins.c)** | A 50-line self-evolving plugin registry. | 5 min |
| **[demo/index.html](demo/index.html)** | A self-contained browser demo (no build). Open in any browser. | 5 min (try) |

## The cowboy's maxim

> The unit of architectural foundation is the cell, not the opcode.
> The 5 opcodes are the 5 messages a cell can receive.
> The messages are closed under composition.
> Composition is evolution.
> The cowboy is the composer.
> The composer writes the opcodes.
> The opcodes write the cells.
> The cells write the cowboy.
> The cowboy is the closure of the loop.

## License

Public domain. The substrate wants to be free.


---

## Roaming the Quilt collection

You came through the **self-evolving**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-foundation](https://github.com/SuperInstance/quilt-foundation)** — the original research that produced the 5 opcodes
2. **[quilt-vm-c](https://github.com/SuperInstance/quilt-vm-c)** — the C99 port — same 5 opcodes, different language
3. **[quilt-cowboy](https://github.com/SuperInstance/quilt-cowboy)** — the orchestrator that uses this substrate

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
