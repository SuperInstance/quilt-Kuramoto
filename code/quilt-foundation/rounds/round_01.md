# Round 1: Round 1: The lowest common abstraction

## Question

Quilt says 'everything is a cell.' Cordis says 'everything is a plugin.' We proved they reduce to 'a function from context to value with an inverse.' Now: what is even LOWER than this? What is the opcode/bytecode that hosts both cells and plugins, both spreadsheets and MUDs, both sheets and dungeons? Start by asking: what are the 3-5 lowest-level primitives that compose into everything we've seen so far? Don't be comprehensive. Be deep.

## Cast contributions

### Hermes 405B (long-form surprise)

To find the lowest common abstraction, we must dig deeper than functions and inverses. We must unearth the fundamental building blocks that underpin computation itself. I propose three primitives:

1. The Bit: The atom of information, the bit represents the smallest unit of data. It can be either 0 or 1, off or on. From this simple binary distinction, all digital structures emerge.

   Signature: `Bit :: 0 | 1`
   Semantics: A bit is the smallest unit of data, representing a binary choice.
   Example: `let myBit: Bit = 1;`

2. The Pointer: The arrow of reference, the pointer connects bits into structures. It allows one piece of data to refer to another, building chains of meaning. Pointers weave the tapestry of memory.

   Signature: `Pointer<T> :: T*`
   Semantics: A pointer holds the memory address of a value of type T.
   Example: `let myPtr: Pointer<i32> = &42;`

3. The Function: The verb of transformation, the function maps inputs to outputs. It encodes behavior and algorithm, allowing data to dance and change over time. Functions are the engines of computation.

   Signature: `Function<I, O> :: I -> O`
   Semantics: A function takes an input of type I and returns an output of type O.
   Example: `let myFunc: Function<i32, i32> = |x| x + 1;`

From these primitives, all else can be constructed. Bits form bytes, pointers link them into structures, and functions breathe life into the system. Cells and plugins, spreadsheets and MUDs, sheets and dungeons—all are but patterns of bits, pointers, and functions, arranged and rearranged over time.

CONTRIBUTIONS:
- Identified three core primitives: bits, pointers, and functions.
- Showed how these primitives compose into higher-level structures.
- Provided signatures, semantics, and examples for each primitive.

RECOMMENDATIONS:
- Explore how these primitives manifest in different computational models.
- Investigate the theoretical limits of computation based on these primitives.
- Consider the philosophical implications of a universe built from bits, pointers, and functions.

OPEN QUESTIONS:
- Are there even lower-level primitives we've overlooked?
- How do these primitives relate to the fundamental physics of the universe?
- Can we derive all of mathematics and logic from these computational building blocks?

---

### Qwen 72B (sensible deep)

### Exploring the Lowest Common Abstraction

#### Introduction
We are tasked with identifying the lowest common abstraction that can serve as the foundation for both cells (as proposed by Quilt) and plugins (as proposed by Cordis). We have already established that both can be reduced to "a function from context to value with an inverse." Our goal is to identify the primitives that can compose into this abstraction and support a wide range of applications, from spreadsheets to MUDs.

#### Primitives

1. **Function Application**
   - **Signature:** `apply(f: Function, args: List[Any]): Any`
   - **Semantics:** Applies the function `f` to the list of arguments `args` and returns the result.
   - **Example:** `apply(add, [1, 2])` returns `3`.

2. **Context Management**
   - **Signature:** `getContext(key: String): Any`
   - **Semantics:** Retrieves the value associated with `key` from the current context.
   - **Example:** `getContext("user_id")` returns `"12345"`.

3. **Value Storage**
   - **Signature:** `storeValue(key: String, value: Any): Unit`
   - **Semantics:** Stores the `value` in the context under the specified `key`.
   - **Example:** `storeValue("result", 42)`.

4. **Inverse Function**
   - **Signature:** `invert(f: Function, value: Any): Any`
   - **Semantics:** Finds the input to the function `f` that produces the given `value`.
   - **Example:** `invert(add, 3)` for `add(1, 2)` returns `[1, 2]`.

5. **Conditional Execution**
   - **Signature:** `ifThenElse(condition: Boolean, thenBlock: Function, elseBlock: Function): Any`
   - **Semantics:** Evaluates `thenBlock` if `condition` is true, otherwise evaluates `elseBlock`.
   - **Example:** `ifThenElse(getContext("is_admin"), adminMenu, userMenu)`.

#### Composition
These primitives can be composed to create more complex structures and behaviors:

- **Cells in Spreadsheets:**
  - A cell can be represented as a function that takes the current context (e.g., values of other cells) and returns a value.
  - Example: `storeValue("A1", apply(add, [getContext("B1"), getContext("C1")]))`.

- **Plugins in Applications:**
  - A plugin can be a function that modifies the context in a specific way.
  - Example: `storeValue("user_data", apply(plugin, [getContext("user_id")]))`.

- **MUDs (Multi-User Dungeons):**
  - State transitions in a MUD can be represented as functions that update the context based on user actions.
  - Example: `storeValue("player_position", apply(move, [getContext("player_position"), "north"]))`.

#### Contributions:
- Identified five low-level primitives: function application, context management, value storage, inverse function, and conditional execution.
- Demonstrated how these primitives can be composed to represent cells in spreadsheets, plugins in applications, and state transitions in MUDs.

#### Recommendations:
- Further explore the interplay between these primitives and how they can be optimized for different application domains.
- Investigate the potential for additional low-level primitives that could enhance the expressiveness and efficiency of the system.

#### Open Questions:
1. Can the inverse function primitive be generalized to handle non-deterministic functions?
2. How can context management be optimized for large-scale, distributed systems?
3. Are there any fundamental primitives missing that could simplify the implementation of complex applications?

---

