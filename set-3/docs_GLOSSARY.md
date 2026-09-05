# Glossary

*Every term used in the substrate, with cross-references to where
the term is defined or used. Read this first. A coding agent who
knows these terms can read the rest of the codebase without help.*

## A

**algebraic law** — A property that a primitive (BIND, LINK, EFFECT,
VIEW, TICK) must obey. The 5 laws are listed in
[docs/MATHEMATICS.md §2](MATHEMATICS.md#2-the-5-messages).
The prover at `src/prove.c` checks compositions against the laws.

**apply** — A synonym for *send a message to a cell*. A substrate
user does not "call" a function; they "apply" a message.

## B

**BIND** — Message 1 of 5. Sets a cell's value. The new value is
the only persistent thing about the cell. See
[include/opcodes.h](../include/opcodes.h) for the API and
[src/opcodes.c](../src/opcodes.c) for the implementation.

**binding** — A `(name, value)` pair. The "thing that BINDs." A
binding can be resident (in memory) or durable (in storage) or
both.

## C

**cell** — `(name, value, identity)`. The only state in the
substrate. Defined in [include/cell.h](../include/cell.h).

**closure** — A composed message. The result of `sequence(m1, m2)`.
The closure is a new message; the closure is itself sequenceable.

**composition** — The monoid operation. Two messages composed in
sequence form a single new message.

**cowboy** — The user of the substrate. The cowboy writes
applications and the substrate runs them. See
[docs/CODING-AGENT-GUIDE.md](CODING-AGENT-GUIDE.md) for the cowboy's
codebase-tour.

**cycle** — One TICK. A cycle is the unit of time in the substrate.
A cycle is small (microseconds in C, milliseconds in Python).

## D

**derivation** — The algorithm that takes a spec for a new message
and returns a composition of the 5 primitives. Implemented at
[src/derive.c](../src/derive.c). Documented in
[docs/MATHEMATICS.md §5](MATHEMATICS.md#5-closure-the-6th-opcode).

**durable** — A cell is durable if its triple `(name, value,
identity)` is held in storage. Durability is orthogonal to
residency.

## E

**EFFECT** — Message 3 of 5. Runs a forward function and records
its inverse. The inverse is the substrate's rollback mechanism.

**evolution** — The substrate's ability to add new messages by
derivation. See [include/evolution.h](../include/evolution.h).

## F

**f⁻¹** — The inverse of an effect's forward function. Required by
the algebraic law of EFFECT.

## G

**gate** — A test that gates a derived message. A derived message
that fails its gate is rejected. The gate is the prover
[src/prove.c](../src/prove.c).

## H

**handshake** — The protocol by which two cells link. The handshake
records the relation and the inverse relation.

## I

**identity** — The `σ` of a cell. A partial function from value to
value. The "shape" of the cell.

**inverse** — The undo of a message. Every message has a well-defined
inverse. The substrate keeps a journal so that inverses can be
applied in reverse order to roll back.

**inversive monoid** — A monoid where every element has an inverse.
The 5 messages form an inversive monoid under composition.

## J

**journal** — The cell named `_journal`. The journal holds the
history of messages. The journal itself is a cell and is itself
editable via BIND.

## L

**law** — Short for *algebraic law*. The 5 laws of the 5 messages.

**LINK** — Message 2 of 5. Records a relation between two cells.
Composition is associative; reading is monotonic.

**link set** — The set of `(peer, relation)` pairs for a cell. The
link set is itself a value; the link set can be BINDed.

## M

**message** — A unit of behavior sent to a cell. One of the 5
primitives, or a composition of them.

**monad** — The algebraic structure on cells. See
[docs/MATHEMATICS.md §4](MATHEMATICS.md#4-the-cell-as-monad).

**monoid** — The algebraic structure on messages. Closed under
composition.

## N

**name** — The first component of a cell. A finite string. Two
cells with the same name are the same cell (the substrate
uniquifies by name).

**namespace** — A prefix on names. Used to group related cells
(e.g., `user/alice/email`).

## O

**opcode** — A message. (The terms are interchangeable; the
substrate chose "message" to emphasize that messages are first-class
values that can be passed around.)

## P

**partial order** — A relation `≤` on messages such that `m1 ≤ m2`
means "m1 is a specialization of m2." Used in the self-evolution
theorem. See
[docs/MATHEMATICS.md §6](MATHEMATICS.md#6-the-self-evolution-theorem).

**peek** — A *read* of a cell without sending VIEW. Peek is a
debugging primitive; production code should use VIEW.

**purity** — The algebraic law of VIEW. A VIEW has no effect; the
same VIEW applied to the same cell always returns the same result.

**push** — A *write* of a cell that triggers the cell's inverse
journal. Push is the runtime's tick hook.

## R

**relation** — The label on a LINK. A relation is a string
(e.g., `"friend"`, `"manages"`, `"owns"`).

**resident** — A cell is resident if its triple is in memory. A
resident cell can be read with peek.

**rollback** — Apply the inverses of a sequence of messages in
reverse order. The substrate can rollback to any point in the
journal.

## S

**sequence** — The monoid operation. `sequence(m1, m2)` is the
message "do m1, then do m2."

**spec** — A description of a desired message, used as input to
derivation. A spec is a finite automaton.

**substrate** — The C library in this repo. Hosts applications.

**substrate instance** — A live substrate in a process. Each
process has at most one substrate instance.

## T

**TICK** — Message 5 of 5. Advances the cell's clock. The
substrate has no global clock; each cell has its own clock.

**triple** — A `(name, value, identity)` cell. Also used for
"the only state in the substrate."

## V

**value** — The second component of a cell. A finite byte
sequence. The value is what the cell *is*.

**VIEW** — Message 4 of 5. Reads the cell (or a projection of
it). Pure.

## W

**wiring** — A static graph of cells and links. A wiring is the
topology of a substrate application. The substrate reads the
wiring from the `_wiring` cell at boot.

## Cross-references

- For the math, see [docs/MATHEMATICS.md](MATHEMATICS.md).
- For how to read the codebase, see
  [docs/CODING-AGENT-GUIDE.md](CODING-AGENT-GUIDE.md).
- For the public API, see [include/substrate.h](../include/substrate.h).
- For tests, see [tests/](../tests/).
