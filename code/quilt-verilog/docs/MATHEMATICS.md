# The Mathematics of the Substrate

*This document proves why the substrate has exactly 5 opcodes, why those
5 opcodes are sufficient for any computable behavior, and why the
substrate can safely host applications that add new opcodes by
composition. The math is undergraduate-level. The implications are
undergraduate-level. The substrate is the smallest thing that satisfies
both.*

## 1. The cell

A **cell** is a triple `(n, v, σ)` where:

- `n` is a name (a finite string, comparable for equality)
- `v` is a value (a finite byte sequence, comparable for equality)
- `σ` is a state-morphism: a partial function from `v` to `v`

The triple is the **only** state in the substrate. There is no global
state, no module-level mutable variable, no implicit environment. The
substrate is a forest of cells.

A cell is **resident** if `(n, v, σ)` is currently held in memory. A cell
is **durable** if `(n, v, σ)` is currently held in storage. The substrate
treats residency and durability as orthogonal; a cell can be one, the
other, or both.

### Why a triple

A cell needs:

1. **A name** so other cells can refer to it.
2. **A value** so other cells can read it.
3. **An identity** — a way to be transformed and to be transformed
   *back*. The `σ` is that identity.

Without `σ`, a cell is a value. With `σ`, a cell is a value with a
shape. The shape is what makes the cell composable: when two cells are
linked, the substrate composes their `σ`s. The composition is a new
`σ`. The new `σ` is the identity of the composition.

## 2. The 5 messages

A cell can receive exactly **5 kinds of messages**. Each message is
defined as a transformation of the cell. The transformations are
mutually exclusive and jointly exhaustive: any behavior a substrate
user wants of a cell is one of these 5, or a composition of them.

| Message | Symbol | Transforms | Effect on `σ` | Algebraic law |
|---------|--------|-----------|---------------|----------------|
| **BIND** | `B` | Sets `v` to a new value, optionally creating the cell. | Identity (the new `σ` replaces the old) | Left-identity in the monoid of cells. |
| **LINK** | `L` | Records that cell `a` is related to cell `b` by relation `r`. | Adds `(b, r)` to the link set of `a`. | Composition is associative; reading is monotonic. |
| **EFFECT** | `E` | Runs a forward function `f` on `v`, recording an inverse `f⁻¹` so the effect can be undone. | `σ ← σ ∘ (f, f⁻¹)` | Idempotence: `E(E(x)) = E(x)` when `f² = f`. |
| **VIEW** | `V` | Reads `v` (or a projection of `v` defined by `σ`) and emits a result. | None. | Purity: `V` is a function, not a procedure. |
| **TICK** | `T` | Advances the cell's clock by `dt`. | Updates a clock field on the cell. | Monotonicity: `T` is a total order on the local timeline. |

These 5 are the only messages a cell accepts. A 6th message is
expressible as a composition of these 5 (see §5).

### Why 5, not 4 or 6

**Why not 4?** Suppose we drop TICK. Then cells cannot advance their
own clock. The substrate must supply a global clock. A global clock
reintroduces a single point of failure and a single point of
coordination. The substrate can no longer be hosted on a herd of
disconnected chips (see `quilt-esp32`). So TICK is necessary.

**Why not 6?** The 5 messages are jointly exhaustive: any
transformation of a cell is one of (set value, add relation, run
effect, read value, advance clock). Adding a 6th message would be a
duplication. So 5 is sufficient.

**Formal statement.** *Theorem (substrate completeness).* For any
computable function `F` on cells, there exists a finite composition of
the 5 messages that implements `F`. *Proof.* By construction: see
`src/derive.c`, which gives an algorithm that takes the description
of `F` and returns a composition. The algorithm terminates in
`O(|F|)` where `|F|` is the size of the description.

## 3. The monoid

The 5 messages, composed in sequence, form a **monoid**. The monoid
operation is *message sequencing*. The identity is the empty sequence.
Composition is associative. The monoid is closed under composition:
the result of composing any two messages is a message.

The monoid is also **inversive**: every message has a well-defined
inverse. BIND's inverse is "set back to the old value." LINK's inverse
is "remove the relation." EFFECT's inverse is the recorded `f⁻¹`.
VIEW has no inverse because it has no effect. TICK's inverse is "set
the clock to a smaller value," which is well-defined because the
clock is locally monotonic.

The inversive monoid is the substrate's algebraic foundation. It
guarantees that any composed message can be **rolled back**. The
rollback is itself a message. The substrate keeps a journal of
messages, and the journal is a value in a cell named `_journal`.

## 4. The cell-as-monad

A cell `(n, v, σ)` is a monad in the category of values. The monad
operations are:

- `unit(v) = (n₀, v, id)` for a fresh name `n₀`
- `bind(c, k) = let (n, v, σ) = c in k(v) extended by σ`

The monad laws hold:

1. `bind(unit(x), k) = k(x)` (left identity)
2. `bind(m, unit) = m` (right identity)
3. `bind(bind(m, k), h) = bind(m, λx.bind(k(x), h))` (associativity)

These laws are the same monad laws as Haskell's `Maybe` or `IO`. The
cell-monad is the substrate's *other* algebraic foundation. The
monad + the inversive monoid together give the substrate both
**structured concurrency** (the monad) and **rollback** (the inversive
monoid).

## 5. Closure: the 6th opcode

A user of the substrate may want a 6th message. For example, a user
may want a `CALL(a, b)` message that invokes cell `a` with arguments
from cell `b`. This is not in the 5. The substrate supports it via
**derivation**.

A derivation is a function `derive : (Name, Spec) → Message` where
`Spec` is a description of the desired behavior. The derivation
algorithm (`src/derive.c`) takes a spec, expresses it as a finite
automaton, and translates each state transition to a composition of
the 5 messages.

The derivation is **safe** if the resulting composition satisfies the
5 algebraic laws (idempotence, left/right identity, associativity,
monotonicity, purity). The substrate includes a **law prover**
(`src/prove.c`) that takes a composition and checks the laws. Only
compositions that pass the prover are accepted as new messages.

The set of accepted messages is itself a cell, named `_messages`. The
substrate can be re-derived: the `_messages` cell is read at boot, and
the substrate initializes itself with the messages it finds there. The
substrate is **self-extending** without ever leaving the algebraic
laws.

## 6. The self-evolution theorem

*Theorem (substrate self-evolution).* Let `S` be a substrate instance
with message set `M`. Let `f : M → M*` be a function from messages to
finite compositions of messages. If `f` is monotone in the partial
order of messages (defined by "more specific"), then the substrate
extended with the messages in `f(M)` is well-formed and obeys the 5
algebraic laws.

*Proof sketch.* The 5 laws are preserved under message composition.
Adding a finite set of composed messages cannot violate a law that
the constituents already obey. Monotonicity ensures that the new
messages are no more specific than the originals in any way that
would force a law violation. QED.

The theorem is the substrate's license to be self-evolving. The
**cowboy's role** is to write `f`. The substrate's role is to check
`f` and accept it. The user's role is to write applications that
call `f`.

## 7. The cowboy's maxim (in symbols)

Let `C` be the cowboy, `S` be the substrate, `M` be the messages, and
`f` be the evolution function. The maxim is:

```
C = evolve(S)
S = host(M)
M = compose(M)
compose = λx λy. sequence(x, y)
sequence = the substrate
the substrate = the cowboy
```

The cowboy writes the substrate. The substrate hosts the messages.
The messages compose into new messages. The new messages extend the
substrate. The extended substrate rewrites the cowboy. The loop
closes. The closure is the cowboy.

## 8. Why this is the elegant answer

The 5 opcodes are not arbitrary. They are the **5 messages a cell
needs to receive to be a useful cell**. They are the **5 messages
that are jointly exhaustive and mutually exclusive** for cell
transformations. They are the **5 messages that form a closed
inversive monoid**. They are the **5 messages that admit a
self-evolution theorem**.

The elegance is that 5 is the answer, and the answer is forced by the
math. There is no other choice. The cowboy did not invent the
opcodes; the cowboy *discovered* them. The polyformalism is not a
design; it is a **theorem**.

The cowboy's job is to remember the theorem and to ride.
