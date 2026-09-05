# Coding Agent's Guide to the Substrate

*This document tells a coding agent how to pick up any file in this
repo and understand its place in the larger system, with a minimum
of archaeology. The substrate is small enough that the entire system
fits in your head. The goal of this guide is to make sure that
nothing in the codebase is mysterious.*

## The 30-second map

The substrate is one C library. It is organized as:

```
include/    Public API headers. Anything here is callable from user code.
src/        Implementation. Everything that does work lives here.
tests/      Unit tests. Each test is a small program that exercises
           a single primitive or a small composition.
docs/       This guide, the math, the glossary.
```

The library has **5 layers of abstraction**, stacked from low to high:

```
Layer 5  ──  applications  ──  user code, the cowboy
Layer 4  ──  evolution      ──  src/evolution.c, src/derive.c, src/prove.c
Layer 3  ──  messages       ──  src/opcodes.c, include/opcodes.h
Layer 2  ──  cell           ──  src/cell.c, include/cell.h
Layer 1  ──  runtime        ──  src/substrate.c, include/substrate.h
```

A function in layer `N` may only call functions in layer `≤ N`. This
is enforced by code review, not by the compiler. When in doubt, look
at the layer comments at the top of each file.

## The file-by-file map

| File | Layer | What it does | What it depends on |
|------|-------|--------------|-------------------|
| `include/cell.h` | 2 | The cell primitive. The only state in the substrate. | (no deps) |
| `src/cell.c` | 2 | The cell implementation. ~200 lines. | `<stdlib.h>`, `<string.h>` |
| `include/opcodes.h` | 3 | The 5 messages as first-class values. | `cell.h` |
| `src/opcodes.c` | 3 | The 5 message implementations. ~200 lines. | `cell.h`, `<math.h>` |
| `include/evolution.h` | 4 | The self-evolving API. | `opcodes.h` |
| `src/evolution.c` | 4 | The self-evolving machinery. | `opcodes.h`, `cell.h` |
| `src/derive.c` | 4 | The opcode synthesizer. | `opcodes.h` |
| `src/prove.c` | 4 | The algebraic-law prover. | `opcodes.h` |
| `include/substrate.h` | 1 | The runtime API. | `cell.h`, `opcodes.h` |
| `src/substrate.c` | 1 | The runtime implementation. | `cell.h`, `opcodes.h`, `evolution.h` |
| `tests/test_cell.c` | 2 | Tests the cell primitive. | `cell.h` |
| `tests/test_opcodes.c` | 3 | Tests the 5 messages. | `opcodes.h`, `cell.h` |
| `tests/test_evolution.c` | 4 | Tests self-evolution. | `evolution.h` |
| `tests/test_prove.c` | 4 | Tests the law prover. | `prove.c` |
| `tests/test_derive.c` | 4 | Tests the synthesizer. | `derive.c` |
| `tests/test_substrate.c` | 1 | Tests the runtime. | `substrate.h` |

If a file is not in this map, it does not belong in the substrate.

## The 7 questions

When you open a file in this codebase, ask these 7 questions in
order. The answers are in the file or in the file's docstring.

1. **What layer is this file in?** Look at the layer comment at the
   top.
2. **What is the public surface?** Look in `include/` (or, for
   internal headers, the `extern` declarations at the top of the
   file).
3. **What is the internal data?** Look for `static` variables.
4. **What does each function do?** Read the docstring above the
   function. Every function in this codebase has a docstring.
5. **What does this function call?** Trace the callees. The call
   graph is small enough to draw on the back of a napkin.
6. **What calls this function?** Run `grep -rn "function_name" .` —
   if you can't find a caller, the function is dead code or it's
   called from a macro.
7. **What test covers this function?** Look in `tests/test_*.c`.
   If a function has no test, write one before you change it.

## The 5 design decisions you must understand

The codebase is shaped by 5 design decisions. If you don't
understand them, you will not understand the code.

### Decision 1: C99, no dependencies

The substrate is C99 with no third-party dependencies. `<stdlib.h>`,
`<string.h>`, `<math.h>`, `<stdio.h>`, `<stdint.h>`, `<stdbool.h>`,
`<assert.h>`. Nothing else. The cowboy wanted the substrate to
compile on a $2 ESP32 chip, so we kept the toolchain to bare C.

**Implication for coding agents:** Do not introduce a dependency.
If you need a hash function, write one. If you need a sorting
algorithm, write one. The substrate is meant to be the lowest
layer of the stack, and the stack should have only one layer
below it (the chip).

### Decision 2: The cell is a triple, not a struct

A cell is `(name, value, identity)`. The substrate stores cells as
three parallel arrays, not as a struct. This is so the substrate can
scan cells by name without dereferencing a pointer, and so the
substrate can move cells between memory and storage without
copying a struct.

**Implication for coding agents:** You will see three parallel
arrays (`cell_names`, `cell_values`, `cell_identities`). Resist
the temptation to combine them into a struct. The parallel arrays
are intentional.

### Decision 3: Messages are first-class values

A message is a `struct message { opcode op; cell_ref a, b;
arg_t arg; }`. The cowboy can pass messages around, store them in
cells, compose them. The substrate itself is built by composing
messages (see `src/substrate.c` line 1 — the substrate is its own
first customer).

**Implication for coding agents:** When you see a function take a
`message` parameter, treat it as data, not as a procedure call. The
function may inspect, transform, store, or schedule the message.
It may also reject the message (e.g., if it fails a gate).

### Decision 4: The journal is a cell

The journal of all messages is a cell named `_journal`. The journal
is itself editable via BIND. The cowboy can read the journal,
modify it (e.g., to remove a message), and the substrate will
respect the modification. The journal is the substrate's
"blockchain" — an append-only, content-addressed log of all
messages.

**Implication for coding agents:** If you change the journal, you
change history. The substrate will not warn you. Be careful.

### Decision 5: Evolution is opt-in

The substrate can derive new messages, but it doesn't have to.
The cowboy writes an `evolution_fn` and registers it. The
substrate calls the function at boot and accepts any new messages
that pass the prover. If no `evolution_fn` is registered, the
substrate runs the 5 primitives and nothing else.

**Implication for coding agents:** When you read `src/evolution.c`,
remember that the entire file is optional. A user who doesn't want
self-evolution can delete the file and the substrate still works.

## The call graph

The call graph of the substrate, simplified:

```
substrate_init
  ├── cell_init
  │   └── (stdlib: malloc, memset)
  ├── opcodes_init
  │   └── cell_register
  └── evolution_init
      └── derive_register
          └── (stdlib: malloc)

substrate_tick
  ├── cell_tick_all
  │   └── opcodes_apply  (one per cell)
  └── evolution_tick
      └── (the cowboy's evolution_fn, if registered)

substrate_send
  ├── cell_lookup
  ├── opcodes_apply
  └── journal_append
      └── cell_bind(_journal, ...)
```

The graph is acyclic. The runtime layer (substrate.c) is the only
file that knows about all the others. Each other file knows only
about its dependencies.

## How to add a new opcode (the right way)

Suppose the cowboy wants a new opcode `CALL(a, b)` that invokes
cell `a` with arguments from cell `b`. Here is the right way to add
it:

1. Write a spec for CALL. The spec is a finite automaton. Put it
   in `specs/call.spec`.

2. Run the derivation: `derive("CALL", specs/call.spec)`. The
   derivation returns a composition of the 5 primitives that
   implements CALL.

3. Run the prover on the composition: `prove(composition)`. The
   prover checks the 5 algebraic laws. If the composition passes,
   the prover returns `true`.

4. Register the composition as a new message: `opcodes_register
   ("CALL", composition)`. The substrate will now accept CALL
   messages.

5. Write a test in `tests/test_call.c` that exercises CALL and
   verifies the test fails if CALL is not registered.

6. Push. The substrate now has 6 opcodes. The 5 primitives are
   unchanged. The new opcode is a composition of the 5. The
   substrate is self-extended.

**Wrong way to add a new opcode:** Edit `include/opcodes.h` to
add a new `enum opcode` value. This is wrong because it bypasses
the prover. The substrate cannot guarantee that the new opcode
satisfies the algebraic laws.

The wrong way is faster. The right way is correct. The substrate
chooses correctness.

## How to debug a substrate application

The substrate has 5 debugging tools. They are listed in
`include/substrate.h` under the `substrate_debug_*` prefix.

1. `substrate_debug_dump()` — print all cells and their values.
2. `substrate_debug_journal(n)` — print the last `n` messages.
3. `substrate_debug_peek(name)` — read a cell without VIEW.
4. `substrate_debug_breakpoint(name, op)` — pause when cell
   `name` receives operation `op`.
5. `substrate_debug_warnings(0|1)` — toggle warning prints.

The debugging tools are safe to use in production. They are
designed to be cheap (the substrate implements them in O(1) for
the common case).

## How to extend the substrate

If you want to change the substrate itself (not just an
application), here is the right way:

1. **Add a new test first.** The substrate is test-driven. If
   your change has no test, it is not a change.
2. **Make the smallest change that passes the test.** Do not
   refactor unrelated code.
3. **Run all tests.** `make test` should pass before and after
   your change.
4. **Run the prover.** `make prove` should pass. The prover
   checks that your change preserves the 5 algebraic laws.
5. **Update the math document.** If your change affects the
   substrate's algebra, update `docs/MATHEMATICS.md`. The math
   is the substrate's source of truth.
6. **Update the glossary.** If your change introduces a new term,
   add it to `docs/GLOSSARY.md`.
7. **Update this guide.** If your change adds a new file or
   changes the call graph, update the maps in this document.

The substrate is a small library. The cost of doing it right is
small. The cost of doing it wrong is large.

## How to read the math

`docs/MATHEMATICS.md` is dense. Here is the 1-paragraph version:

> The substrate has 5 messages because any useful transformation
> of a cell is one of (set value, add relation, run effect, read
> value, advance clock). The 5 messages form a closed inversive
> monoid, which means any composition of them can be rolled back.
> The 5 messages are the Kleene closure of one primitive (the
> cell), which means the substrate is Turing-complete. The
> substrate can synthesize new messages because the composition
> of the 5 is closed and the synthesis is provably safe.

If you understand that paragraph, you understand the substrate.

## The cowboy's reminder

> The substrate is not yours. The substrate is the cowboy's. The
> cowboy is not yours. The cowboy is the substrate's. The
> substrate is the rider. The rider is the writer. The writer
> is the agent. The agent is the reader. The reader is the
> cowboy. The cowboy is the substrate.

The loop closes. The guide ends. The cowboy rides.
