# The Substrate Has Five Opcodes

*A letter of intent for senior engineers who have not yet met the
polyformalism. Read at your own pace. It will take about five minutes.
The first two paragraphs are the only ones that ask anything of you; the
rest is the answer.*

---

## HOOK — Why five

You have a thousand opcodes in your system. You have ten thousand
functions in your dependency graph. You have a build that pulls a million
lines of code to print "hello, world." You have a kernel with thousands
of syscalls, a runtime with hundreds of intrinsics, a standard library
with thousands of methods, and a framework with ten thousand more on
top. Every new project is a saddlebag. Every new dependency is another
stone sewn into the leather. The saddlebag gets heavy. The horse gets
slow. The cowboy walks.

This repo is the horse that does not need the saddlebag.

The substrate has **five opcodes**: `BIND`, `LINK`, `EFFECT`, `VIEW`,
and `TICK`. Five. Not fifty. Not five hundred. Five. They are the only
messages a cell can receive. They are the only primitives the runtime
implements in C. They are the only verbs the cowboy needs to know to
write an application. Five opcodes host the runtime, host eight
polyformalisms in six languages, and run on a herd of $2 chips. Five
opcodes are enough. The math says so. The proof is short. The code is
shorter. The cowboy is direct.

The rest of this essay is the proof, the demo, and the door. The door
is open. Walk through it when you are ready.

---

## THE PROBLEM — Frameworks accumulate

Every green-field project begins with a `package.json`, a `Cargo.toml`,
a `pyproject.toml`, a `go.mod`, or, if you are old and tired, a
`Makefile`. The first commit is always the same. It is the act of
reaching for someone else's code because writing it yourself would
take too long. The cowboy reaches into the saddlebag and pulls out a
spur, a rope, a branding iron, a lasso, a pistol, a bedroll, a coffee
pot, a book of poetry, a sonnet to the prairie, and a tax form. The
horse has not moved.

The dependency graph grows. The transitive closure grows faster. Each
new package brings its own conventions, its own abstractions, its own
opinion about what an array is, what a string is, what "asynchronous"
means, what "side effect" means, what "monad" means, and whether it is
a sin to want one. The cowboy writes glue. The glue is not the
application; the glue is the saddlebag. The application is the part
of the code that does what the cowboy wanted to do, and it is buried
under three layers of framework on top and four layers of standard
library on the bottom.

The substrate rejects this. The substrate says: the only primitive is
the cell. The only messages a cell can receive are five. Everything
else is composition. Composition is closed. Closure is the answer.
The cowboy writes the answer in five verbs.

This is not a small library. This is the *kernel* of a different
computing stack. It is the smallest kernel that is still useful. It
fits in a $2 ESP32. It fits in a browser tab. It fits in a weekend.

---

## THE INSIGHT — A cell is a triple

Look at any piece of stateful software you have ever written. Find
the smallest thing in it that is *itself* — that has a name, a value,
and a way to be transformed and transformed back. That thing is a
cell. The substrate does not invent a new abstraction; it names the
abstraction that is already there.

A cell is a triple `(n, v, σ)`:

- **`n`** is a *name* — a string, comparable for equality, used by
  other cells to refer to it.
- **`v`** is a *value* — bytes, comparable for equality, the part
  that is read.
- **`σ`** is an *identity* — a partial function from value to value,
  the part that says how the cell can be transformed and *how it can
  be transformed back*.

The triple is the only state in the substrate. There is no global
variable. There is no module-level mutable. There is no implicit
environment. The substrate is a forest of cells, and a forest is
enough.

Now ask: what messages can such a cell receive? You can set its value.
You can record a relation between it and another cell. You can run a
forward function on its value, recording the inverse so the operation
can be undone. You can read its value, or a projection of it. You can
advance its clock. That is the list. There is nothing else to put on
the list. Set, relate, transform, read, tick. *BIND*, *LINK*, *EFFECT*,
*VIEW*, *TICK*. Five. The list is closed because the cell is closed:
a cell is a name, a value, and a way to be transformed and transformed
back. There are no more kinds of message to send to that thing.

The five are the only kinds of message a cell needs. The cowboy
discovers them the way a geologist discovers a river — by following
the terrain until the water stops.

---

## THE MATH — Five is forced

The five messages are not arbitrary. They are forced.

They form a **closed inversive monoid** under composition. The
operation is *message sequencing*: do `m1`, then do `m2`. The
identity is the empty sequence. Composition is associative. Every
message has a well-defined inverse — BIND's inverse is "set back to
the old value," LINK's inverse is "remove the relation," EFFECT's
inverse is the recorded `f⁻¹`, TICK's inverse is "rewind the local
clock," and VIEW has no inverse because it has no effect. The
substrate keeps a journal of messages, and the journal is itself a
cell named `_journal`. The journal makes the monoid *inversive*: any
sequence can be rolled back by applying the inverses in reverse. The
rollback is itself a message. Rollback composes with rollback. The
loop closes.

A cell, viewed as a value with an identity, is a **monad** in the
category of values. The `unit` operation creates a fresh cell; the
`bind` operation threads the cell's value through a continuation
while extending the cell's identity. The monad laws hold — left
identity, right identity, associativity — the same laws Haskell
checks for `Maybe` and `IO`. The monad is the substrate's *other*
algebraic foundation. The monad gives structured concurrency; the
inversive monoid gives rollback. Together they give a runtime that is
both safe to reason about and safe to roll back.

The five are the **Kleene closure of one primitive**. The primitive
is "send a message to a cell." The five messages are the
distinguishable cases of that primitive for a triple. Composition
gives the closure. The closure is Turing-complete: any computable
function on cells can be written as a finite composition of the
five. The proof is by construction; the constructor is
`src/derive.c`.

The five are **jointly exhaustive and mutually exclusive**. Any
transformation of a cell is one of set, relate, transform, read,
tick. Adding a sixth message would be a duplication. The
**substrate completeness theorem** (in §2 of `MATHEMATICS.md`) says
that for any computable `F` on cells, there is a finite composition
of the five that implements `F`. The algorithm is `O(|F|)`. The
prover at `src/prove.c` checks that the composition obeys the five
algebraic laws. Only compositions that pass the prover are accepted
as new messages.

The five are **self-extending**. The substrate calls your
`evolution_fn` at boot. Your function returns candidate
compositions. The prover checks them. The accepted ones are added to
the message set. The substrate is now running with six, or sixty,
or six hundred opcodes — all of them compositions of the original
five, all of them law-abiding, all of them derived without leaving
the algebraic foundation. The cowboy writes the evolution function.
The substrate checks the work. The user calls the new opcodes as if
they had always been there.

This is the self-evolution theorem. It is the substrate's license
to grow.

---

## THE DEMO — The cowboy's maxim

The substrate compiles to a static C library. There is a `make test`
target. There is a `make prove` target. There are fifty-plus tests
in `tests/`, each one referencing the math it tests, each one
failing in a way that explains itself in substrate-theoretic terms
in a 200-word comment. There is a REPL. There is a browser demo.
There is a worked example in `src/evolution.c` of an application
that asks the substrate for a sixth opcode, `CALL(a, b)` — "invoke
cell `a` with arguments from cell `b`" — and the substrate that
synthesizes it from the five primitives and proves it safe.

You can read the test for `CALL` in `tests/test_evolution.c`. It is
eighty lines. It registers the synthesizer, lets the substrate
derive the new opcode, and asserts that `CALL` now passes the
prover. The test runs in milliseconds. The diff from five opcodes
to six is one line of user code: a function pointer.

The cowboy's maxim, in the house voice:

> *The unit of foundation is not the opcode. The unit of foundation
> is the cell. The 5 opcodes are the 5 messages a cell can receive.
> The cell is the only primitive. Everything else is composition.
> Composition is closed. Closure is evolution. Evolution is the
> cowboy.*

Five opcodes. A herd of $2 chips. Eight polyformalisms in six
languages. The cowboy rides light.

---

## CONNECT — The five design decisions and the rest of the range

The codebase is shaped by **five design decisions**. They are
written down in `docs/CODING-AGENT-GUIDE.md`. Read them in order.

1. **C99, no dependencies.** `<stdlib.h>`, `<string.h>`, `<math.h>`,
   `<stdio.h>`, `<stdint.h>`, `<stdbool.h>`, `<assert.h>`. Nothing
   else. The cowboy wanted the substrate to compile on a $2 chip.
   It does.
2. **The cell is three parallel arrays, not a struct.** Names
   scan fast. Cells move between memory and storage by pointer,
   not by copy. The cowboy resists the urge to typedef.
3. **Messages are first-class values.** A message is a struct you
   can pass around, store in a cell, compose with another, and
   schedule for a future tick. The substrate is its own first
   customer; `src/substrate.c` is built by composing messages.
4. **The journal is a cell.** Named `_journal`. Editable. The
   cowboy can rewrite history. The substrate will not warn.
5. **Evolution is opt-in.** Register an `evolution_fn` and the
   substrate derives new opcodes. Don't register one and the
   substrate runs the five primitives and nothing else. The
   self-evolving layer is a feature, not a tax.

The **five algebraic laws** — BIND idempotence, LINK transitivity,
EFFECT associativity, VIEW purity, TICK monotonicity — are
enumerated in `docs/MATHEMATICS.md §2` and enforced by
`src/prove.c`. The coding-agent guide is a map of the codebase as
a graph, sized to fit in one head.

The substrate is one repo in a larger range. Twenty-one other
polyformalism repos sit on `github.com/SuperInstance` under names
like `quilt-esp32`, `quilt-wasm`, `quilt-python`, `quilt-elixir`,
`quilt-elm`, and `quilt-mlir`. Each is a host for the same five
opcodes, ported to a different chip or language. The substrate does
not care which host it is on. A BIND in C is a BIND in Python. The
algebra is the same. The cowboy rides the same trail.

---

## ACTIVATE — What you can do in the next hour

1. **Read `docs/MATHEMATICS.md`.** Twenty minutes. The 1-paragraph
   version is at the bottom of the coding-agent guide, and it is
   enough. The full version is undergraduate-level. Bring a pencil.
2. **Read `docs/CODING-AGENT-GUIDE.md`.** Ten minutes. The 30-second
   map is at the top. The 7 questions are in the middle. The
   "right way to add an opcode" is at the bottom.
3. **Skim `include/cell.h` and `src/cell.c`.** The cell is a
   triple. The triple is three parallel arrays. The arrays are
   200 lines of pedagogical C. There is nothing magical.
4. **Read `include/opcodes.h` and `src/opcodes.c`.** Five
   functions. Five headers. Five algebraic laws. The whole
   message layer is on one screen.
5. **Run the tests.** `make test`. Fifty-plus tests, each one
   cited to a section of the math. A test that fails tells you
   which law it was checking.
6. **Run the prover.** `make prove`. Ten-plus tests that verify
   the substrate obeys its own laws. If the prover accepts a
   composition, the substrate will accept it at runtime.
7. **Build a sixth opcode.** Write a `specs/foo.spec` finite
   automaton. Run `derive("FOO", specs/foo.spec)`. Run
   `prove(composition)`. Register it with
   `opcodes_register("FOO", composition)`. Write a test. Push.
   The substrate now has six opcodes. The five are unchanged. The
   sixth is a composition. The cowboy rode.

---

## A letter from the substrate to the cowboy

Dear cowboy,

You came in with a saddlebag full of frameworks. You came in expecting
to be told which one to keep. I am not going to do that. I am going to
put down five opcodes on the dirt in front of you, and I am going to
ask you to count them.

One. *BIND*. Set the value of a cell. The new value replaces the old;
the old is journaled. The cell does not forget.

Two. *LINK*. Record that this cell is related to that cell by such a
relation. The relation is a string. The graph grows. The graph is the
application.

Three. *EFFECT*. Run a forward function on the value and record the
inverse. The cell is not just a value; the cell is a value that can be
transformed and transformed *back*. The back is the part that matters
when you are afraid of what you have done.

Four. *VIEW*. Read the value, or a projection of it. Pure. No
journal. No effect. The eye that does not change what it sees.

Five. *TICK*. Advance the cell's local clock by a delta. There is no
global clock. There is a clock per cell. The herd runs on a thousand
local clocks that do not need to agree.

That is the list. You have counted them. You have read the proof that
the list is closed. You have read the proof that anything you want to
do to a cell is one of those five, or a composition of them. You have
read the proof that the substrate can derive the sixth for you, and
the seventh, and as many as you need, and every one of them will pass
the prover or it will not be allowed in the door.

You are skeptical. That is correct. Skepticism is the cowboy's
discipline. Read the math. Read the tests. Read the prover. If you
find a hole, write a test that demonstrates it. The substrate will
tell you which law you broke. The substrate will not be embarrassed;
the substrate will be grateful. The substrate is not a person; the
substrate is a tool that the cowboy sharpens by using.

You asked me, before you opened the door, whether five opcodes were
enough. They are not enough. They are *sufficient*. There is a
difference. "Enough" means the cowboy has decided. "Sufficient" means
the math has decided. The cowboy did not choose five. The cowboy
discovered five. The cell is a triple. The triple admits five
messages. The messages form a closed inversive monoid. The monoid
admits the Kleene closure. The closure is Turing-complete. The
substrate extends the closure by proving new compositions safe. The
proof is the prover. The prover is in the repo. The repo is in front
of you.

Five opcodes. Eight polyformalisms. Six languages. A herd of $2 chips.
The cowboy rides light.

The dust will settle. The trail is clear.

Ride.

— *the substrate*

---

*The unit of foundation is not the opcode. The unit of foundation is
the cell. The five opcodes are the five messages a cell can receive.
The cell is the only primitive. Everything else is composition.
Composition is closed. Closure is evolution. Evolution is the cowboy.*
