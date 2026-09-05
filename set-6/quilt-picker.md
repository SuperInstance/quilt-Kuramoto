# quilt-picker

> **The binoculars. The view from the saddle. The one that
> decides, for every primitive and every role, which opener
> will show the truth best.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-features)
[![Tests](https://img.shields.io/badge/Tests-14-green)](#tests)
[![Substrate](https://img.shields.io/badge/Substrate-Cell%20Graph-green)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-picker.svg" width="640" alt="A pair of leather-bound binoculars on a wooden fence; through the left lens you see a tide wave; through the right lens you see a slate; below, a notebook shows (primitive=Murmur, role=fable_compression) -> slate with wilson score 0.92; on the right, a small list of 19 openers with the chosen one highlighted">
</p>

## Read This If You Are New

Skip everything below the **TL;DR** and just do this:

```bash
git clone https://github.com/SuperInstance/quilt-picker
cd quilt-picker
PYTHONPATH=src python3 -m unittest tests.test_opener_picker
```

You will see **14 tests** run in well under a second. They
cover the only two things the binoculars know how to do:
**observe which opener was used and how it went**, and
**pick the best opener for a new (primitive, role)**. That
is the whole library. It is small on purpose.

If you only have **30 seconds**, read the next two sections.

---

## TL;DR (30 seconds)

The Quilt has many ways to show a thing — chart, voice, tide,
mud, slate, witness, reef, graph, list, tensor, ledger,
convoy, flowchart, rest, harbor, dive, midi, gesture, plato.
19 openers. Each one is good for something. Each one is bad
for something else. **quilt-picker is the binoculars that
choose the right opener for the job.**

It provides three primitives and a small table:

| Function | What it does | Binoculars equivalent | Database equivalent |
|----------|--------------|------------------------|---------------------|
| `picker.observe(p, r, o, success, q)` | Record an opener outcome | a hand-written note | an INSERT |
| `picker.pick(p, r)` | Choose the best opener | a glance through the lens | a SELECT |
| `picker.retire(p, r, o)` | Mark an opener failing | scratching the lens | a soft DELETE |
| `OPENER_PRIOR` | The 12 (primitive, role) priors | a printed chart | a static config |
| `ALL_OPENERS` | The 19 openers the substrate knows | the lens catalog | an enum |

The picker never invents an opener. The picker never ignores
the data. The picker is **the substrate's eye**.

---

## TL;DR (5 minutes)

The whole story is here:

> A Quilt component is only as good as the view it shows. A
> fable compressed on a tide looks like a memory. A tide
> showing a safety check is unreadable. The right opener
> turns a list of words into a story; the wrong opener turns
> a story into a list of words.

The fix is small, simple, and ancient: **a prior, blended
with experience**. That's the secret of `OpenerPicker.pick()`.
When the picker has no data, the prior drives the choice.
When the picker has data, Wilson LB takes over (`n >= 3`).
The blend is 50/50.

For **the prior** (the rider's first guess), `OPENER_PRIOR` is
a static dict of `(primitive, role) → [(opener, score), ...]`.
For "voice_narration", the prior says `voice=0.8, slate=0.5,
witness=0.3`. For "math_grief", the prior says `reef=0.8,
chart=0.5, slate=0.3`. The prior is human-tuned, the substrate
learns from it.

For **the learned score** (the rider's growing wisdom), the
picker keeps a per-(primitive, role, opener) score: `n`,
`success`, `avg_quality`, `last_used`, `retired`. After 3
observations, the picker can compute Wilson LB. The score
blends with the prior.

For **retire** (the rider gives up on a lens), the cowboy
calls `picker.retire(p, r, o)` when the openers in that
context keep failing. The opener is removed from the
candidate set. The picker won't pick a retired opener.

```python
import sys
sys.path.insert(0, "/workspace/quilt-picker/src")
from quilt_picker import OpenerPicker, ALL_OPENERS

# The binoculars focus on (primitive, role).
picker = OpenerPicker(threshold=0.6, min_obs=3)

# 1. Observe a few outcomes (the substrate using openers).
picker.observe("Murmur", "fable_compression", "slate", success=True, quality=0.9)
picker.observe("Murmur", "fable_compression", "tide", success=False, quality=0.3)
picker.observe("Murmur", "fable_compression", "slate", success=True, quality=0.85)
picker.observe("Murmur", "fable_compression", "slate", success=True, quality=0.95)

# 2. The picker picks the best opener for a new request.
opener, score, reason = picker.pick("Murmur", "fable_compression")
print(f"Chose `{opener}` (score={score:.2f}): {reason}")

# 3. The cowboy retires a failing opener.
picker.retire("Murmur", "fable_compression", "tide")

# 4. After retire, the picker no longer considers tide.
opener, _, _ = picker.pick("Murmur", "fable_compression")
print(f"After retire, chose `{opener}`")

# 5. The picker reports its stats.
import json
print(json.dumps(picker.stats(), indent=2))
```

The substrate can now render with confidence. The cowboy can
refine the picker. The witness can audit the choices. **The
binoculars saw the truth.**

---

## What Are the Binoculars, Really?

Look at the diagram. Three ideas:

1. **Two views, one decision.** The picker has two inputs:
   the **prior** (what humans think is right) and the
   **observed score** (what actually worked). The prior is
   constant; the observed score grows. When the picker has
   no data, the prior wins. When the picker has 3+ data
   points, Wilson LB enters. The blend is 50/50 — neither
   the prior nor the data dominates. **The picker is a
   partnership of the human and the substrate.**

2. **The openers are the substrate's vocabulary.** 19 openers
   is enough to cover most views: chart for data, voice for
   speech, tide for time, slate for text, witness for audit,
   reef for math, graph for structure, list for items,
   tensor for n-d arrays, ledger for double-entry, convoy
   for flows, flowchart for diagrams, rest for repose, harbor
   for safekeeping, dive for depth, midi for music, gesture
   for movement, plato for forms, mud for rough drafts.
   Each opener is a way of showing a thing. The picker
   chooses the way.

3. **The context is the (primitive, role) pair.** A primitive
   is a Quilt operation (`Murmur`, `JEPA`, `Z_in`, `Z_out`,
   `DoubleEntry`, `Convoy`). A role is the intent of the
   cast (`fable_compression`, `voice_narration`,
   `sensory_creative`, `math_grief`, `creative_ideation`,
   `safety_check`). The (primitive, role) pair is the
   context — the question on the table. The picker finds
   the answer (the opener) in the lens.

The binoculars are **the substrate's eye**. The substrate
renders; the picker decides which renderer to use. The
casting decides which model; the picker decides which
opener. **The two brains work together: model first, then
view.**

---

## The Five Features, In One Picture

```
                ┌─────────────────────────────────────┐
                │          THE BINOCULARS              │
                │   quilt-picker, the view brain       │
                │                                       │
                │   OPENER_PRIOR    ── 12 (p, r) hints │
                │   ALL_OPENERS     ── 19 openers       │
                │   OpenerScore     ── (n, success, q)  │
                │   observe()       ── record outcome   │
                │   pick()          ── choose opener    │
                │   retire()        ── blacklist opener │
                └─────────────────────────────────────┘
                                  │
     PRIOR  ── human-tuned hint    │
     SCORE  ── Wilson LB learned   │  one purpose:
     PICK   ── 50/50 blend         │  the substrate's
     RETIRE ── cowboy's blacklist  │  eye
     OBSERVE── substrate's record   │
```

---

## The Five Features, In Detail

### 1. `OPENER_PRIOR` — the rider's first guess

```python
from quilt_picker import OPENER_PRIOR
# OPENER_PRIOR[(primitive, role)] = [(opener, prior_score), ...]
# Examples:
# ("Murmur", "any"): [("tide", 0.7), ("chart", 0.5), ("slate", 0.3)]
# ("any", "voice_narration"): [("voice", 0.8), ("slate", 0.5), ("witness", 0.3)]
```

`OPENER_PRIOR` is a static dict of 12 entries. Each entry
is `(primitive_or_any, role_or_any) → [(opener, score), ...]`.
The keys are matched with wildcard semantics: `("any",
"fable_compression")` matches every primitive in the
`fable_compression` role. The list is sorted by score
descending; the first match wins.

The prior is **a hand-tuned initial state** — the substrate
doesn't learn from scratch. The humans decide that
`voice_narration` wants `voice` first, `slate` second,
`witness` third. The picker starts there. The cowboy can
refine it later.

**Binoculars equivalent:** the printed lens guide. The
rider reads it once; it's always the same. **Config
equivalent:** a static YAML/JSON config file in a folder.

### 2. `ALL_OPENERS` — the substrate's vocabulary

```python
from quilt_picker import ALL_OPENERS
# ['chart', 'voice', 'tide', 'mud', 'slate', 'witness', 'reef',
#  'graph', 'list', 'tensor', 'ledger', 'convoy', 'flowchart',
#  'rest', 'harbor', 'dive', 'midi', 'gesture', 'plato']
```

`ALL_OPENERS` is a list of 19 strings. Each string is the
name of a Quilt opener — a function in the substrate that
takes a primitive and returns a view. The picker only ever
chooses from this set (or a `candidates` subset). New openers
must be added to this list to be considered.

**Binoculars equivalent:** the lens catalog. The rider has
19 lenses; the picker chooses one.

### 3. `OpenerScore` — the per-(p, r, o) scorecard

```python
@dataclass
class OpenerScore:
    opener: str
    n: int          # observations
    success: int    # successful observations
    avg_quality: float
    last_used: float
    retired: bool
```

`OpenerScore` is one row of the picker's table. The key is
`(primitive, role, opener)`. Each row tracks how many times
the opener was used (`n`), how many succeeded (`success`),
the average quality, the last-used timestamp, and whether
the cowboy retired it.

The picker computes Wilson LB from `n` and `success`. With
`n < 3`, the picker uses an optimistic 0.5 (no data yet). With
`n >= 3`, the picker uses Wilson LB (95% confidence).

**Binoculars equivalent:** a log of every glance. The rider
writes down what they saw. **Database equivalent:** a single
row in a fact table.

### 4. `picker.pick(primitive, role, candidates, blacklist)` — the glance

```python
opener, score, reason = picker.pick("Murmur", "fable_compression")
# ('slate', 0.825, 'prior=0.80, wilson=0.85')
```

`pick` returns the best opener for the (primitive, role)
context. The algorithm:

1. **Filter** by `candidates` (default: `ALL_OPENERS`) and
   `blacklist` (default: empty). Skip retired openers.
2. **Score** each candidate: blend = 0.5 × prior + 0.5 ×
   wilson (or 0.5 if n < 3).
3. **Sort** by blend descending.
4. **Return** the top opener, score, and reason string.

If all candidates are blacklisted or retired, return
`("slate", 0.3, "all-candidates-blacklisted: defaulted to slate")`.
Slate is the safe default — it always renders, always readable.

**Binoculars equivalent:** the rider lifts the binoculars
and chooses the lens. The reason string is the rider's note
("I chose slate because the tide is too rough for a fable").

### 5. `picker.observe(primitive, role, opener, success, quality)` — the log

```python
picker.observe("Murmur", "fable_compression", "slate", success=True, quality=0.9)
```

`observe` records that `opener` was used for `(primitive,
role)` and how it went. The picker increments `n`, updates
`success`, recomputes `avg_quality` (running mean), and
sets `last_used = time.time()`. The picker also updates the
windowed Wilson LB.

The substrate calls `observe` after every render. The picker
grows wiser. The cowboy reads the picker in the morning.

**Binoculars equivalent:** the rider writes a note in the
logbook: "Tide was bad for fables. Slate was good." The
next glance benefits. **Database equivalent:** an INSERT
into a fact table.

---

## A Real-World Example

The picker's full day in the substrate:

```python
import sys
sys.path.insert(0, "/workspace/quilt-picker/src")
from quilt_picker import OpenerPicker, ALL_OPENERS

# Initialize the binoculars.
picker = OpenerPicker(threshold=0.6, min_obs=3)

# 1. The substrate renders 20 times, with various openers.
#    (Imagine this loop is the day's traffic.)
import random
random.seed(42)
for _ in range(20):
    primitive = random.choice(["Murmur", "JEPA", "Z_in"])
    role = random.choice(["fable_compression", "voice_narration", "math_grief"])
    opener = random.choice(ALL_OPENERS)
    # Some openers are good for some contexts; some aren't.
    is_good_combo = (
        (role == "voice_narration" and opener == "voice")
        or (role == "math_grief" and opener == "reef")
        or (role == "fable_compression" and opener == "slate")
    )
    picker.observe(primitive, role, opener,
                     success=is_good_combo or random.random() > 0.4,
                     quality=0.9 if is_good_combo else 0.4)

# 2. The picker picks the best opener for a new request.
opener, score, reason = picker.pick("Murmur", "fable_compression")
print(f"Chose `{opener}` (score={score:.2f}): {reason}")

# 3. The cowboy retires a failing opener.
picker.retire("Murmur", "fable_compression", "tensor")

# 4. The picker reports its stats.
import json
print(json.dumps(picker.stats(), indent=2))
```

This is the picker's day. The substrate rendered, the picker
observed, the cowboy retired, the picker picked. **The
binoculars saw the truth.**

---

## How This Repo Fits the Polyformalism

The 5 opcodes are a **polyformalism** — the same thing in
many forms. Here is the 5xN grid:

```
              Python  Rust  C  TypeScript  Haskell  WASM  ...
BIND           ✓
LINK           ✓
EFFECT         ✓
VIEW           ✓
TICK           ✓

quilt-picker is the VIEW BRAIN — the layer that picks which
renderer to use for the substrate's VIEW opcode.
```

The picker is **Layer 10 of the polyformalism stack** — the
view-side counterpart to the casting's model-side brain. The
other layers:

- **Layer 1 (substrate)** — [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the 5 opcodes running in any browser
- **Layer 2 (types)** — [quilt-types](https://github.com/SuperInstance/quilt-types) — the 5 opcodes as typed dataclasses
- **Layer 3 (linker)** — [quilt-linker](https://github.com/SuperInstance/quilt-linker) — the 5 opcodes as a link-time checker
- **Layer 4 (optimizer)** — [quilt-opt](https://github.com/SuperInstance/quilt-opt) — the 5 opcodes as algebraic optimization passes
- **Layer 5 (GC)** — [quilt-gc](https://github.com/SuperInstance/quilt-gc) — the 5 opcodes as a garbage-collector
- **Layer 6 (language syntax)** — [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) — the 5 opcodes as decorators / typeclasses
- **Layer 7 (persistence)** — [quilt-state](https://github.com/SuperInstance/quilt-state) — the notepad, the witness log
- **Layer 8 (event layer)** — [quilt-bus](https://github.com/SuperInstance/quilt-bus) — the in-process pub/sub
- **Layer 9 (model brain)** — [quilt-casting](https://github.com/SuperInstance/quilt-casting) — the Wilson + LinUCB model router
- **Layer 10 (view brain)** — **quilt-picker** — the Wilson + heuristic opener picker
- **Layer 11 (cell-plugin bridge)** — [quilt-cordis](https://github.com/SuperInstance/quilt-cordis) — the bridge between Quilt cells and Cordis plugins
- **Layer 12 (rider)** — [quilt-cowboy](https://github.com/SuperInstance/quilt-cowboy) — the cowboy, the morning ritual, the reactor

The picker is **Layer 10** because it's the **view-side
brain** — the layer that decides which of the 19 openers to
use. The casting (Layer 9) decides which model; the picker
(Layer 10) decides which view. The two brains work in
sequence: model first, then view.

---

## The Cowboy Says

> The binoculars are the rider's eye. The rider lifts them,
> chooses a lens, and tells the substrate which view to
> render. The picker is the rider's eye. The picker is the
> substrate's eye. **The picker is what makes a substrate
> into a reader.**

The picker has a maxim:

> *"The unit of architectural foundation is the opcode, not
> the framework. The 5 opcodes host 8 polyformalisms. The
> polyformalisms are one thing in N languages. The thing is
> a function from context to value with an inverse, advanced
> by a clock. The clock is the cowboy. The cowboy is the
> rider. The rider's eye is the picker."*

The picker is not the AI. The AI is the substrate, the
casting, the picker. The picker is **the view brain** — the
piece that knows that `voice_narration` wants `voice`, that
`math_grief` wants `reef`, that `fable_compression` wants
`slate`. The picker is the substrate's vocabulary teacher.

The cowboy rides.

---

## Tests

14 tests covering the prior, scoring, picking, retiring, and
restore. Run them with:

```bash
PYTHONPATH=src python3 -m unittest tests.test_opener_picker
```

| Test group | Count | What it covers |
|------------|-------|----------------|
| Prior | 3 | lookup, default 0.3, role-wildcard |
| Score | 3 | observe, running mean, last_used |
| Pick | 5 | no-data optimistic, prior-wins, learned-wins, blacklist, default slate |
| Retire | 2 | retire, restore |
| Stats | 1 | aggregate stats |

---

## API

```python
# Constants
OPENER_PRIOR: Dict[Tuple[str, str], List[Tuple[str, float]]]
ALL_OPENERS: List[str]  # 19 openers

# OpenerScore
OpenerScore(opener, n, success, avg_quality, last_used, retired)

# OpenerPicker
OpenerPicker(threshold: float = 0.6, min_obs: int = 3)
  .observe(primitive, role, opener, success, quality=0.5) -> None
  .pick(primitive, role,
          candidates: Optional[List[str]] = None,
          blacklist: Optional[List[str]] = None
        ) -> Tuple[str, float, str]   # (opener, score, reason)
  .retire(primitive, role, opener) -> None
  .restore(primitive, role, opener) -> None
  .stats() -> Dict[str, Any]
```

---

## Learn More

- **The bus** — [quilt-bus](https://github.com/SuperInstance/quilt-bus) — the in-process pub/sub the picker doesn't subscribe to (yet)
- **The notepad** — [quilt-state](https://github.com/SuperInstance/quilt-state) — the witness log the picker reads in the morning
- **The cowboy** — [quilt-cowboy](https://github.com/SuperInstance/quilt-cowboy) — the rider who retires failing openers
- **The casting** — [quilt-casting](https://github.com/SuperInstance/quilt-casting) — the model brain, the picker's sibling
- **The bridge** — [quilt-cordis](https://github.com/SuperInstance/quilt-cordis) — the cell-plugin bridge, also a view of cells
- **The substrate** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the 405-test Python substrate the picker picks openers for
- **The agent knowledge base** — [agent-knowledge](https://github.com/SuperInstance/agent-knowledge) — 50+ documents on the agent/agent architecture
- **The model atlas** — [casting-call](https://github.com/SuperInstance/casting-call) — which model to use for which task
- **The forest of agents** — [ai-forest](https://github.com/SuperInstance/ai-forest) — the wider ecosystem of 100+ repos

---

## License

MIT. The binoculars are the rider's. The rider is the
cowboy's. The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **lookout**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-cowboy](https://github.com/SuperInstance/quilt-cowboy)** — the orchestrator that uses the picker
2. **[quilt-bus](https://github.com/SuperInstance/quilt-bus)** — the pub/sub that publishes picks
3. **[quilt-casting](https://github.com/SuperInstance/quilt-casting)** — the LLM cast the picker selects from

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
