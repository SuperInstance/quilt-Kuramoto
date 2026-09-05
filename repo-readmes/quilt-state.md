# quilt-state

> **The notepad. The witness log. The one place every Quilt component
> writes its truth, and the one place the cowboy reads it back.**

[![Python](https://img.shields.io/badge/Python-3.10+-blue)](https://python.org)
[![5 Opcodes](https://img.shields.io/badge/5-Opcodes-orange)](#the-five-features)
[![Tests](https://img.shields.io/badge/Tests-19-green)](#tests)
[![Substrate](https://img.shields.io/badge/Substrate-Cell%20Graph-green)](#how-this-fits)

<p align="center">
  <img src="docs/images/hero-quilt-state.svg" width="640" alt="A leather-bound notepad open in a darkened workshop, with JSONL lines of witness events flowing from a stack of state files on the left into the witness log glow on the right">
</p>

## Read This If You Are New

Skip everything below the **TL;DR** and just do this:

```bash
git clone https://github.com/SuperInstance/quilt-state
cd quilt-state
PYTHONPATH=src python3 -m unittest tests.test_state
```

You will see **19 tests** run in well under a second. They cover the
only three things the notepad knows how to do: **write a thing
atomically**, **read a thing back**, and **refuse to lie about
schemas**. That is the whole library. It is small on purpose.

If you only have **30 seconds**, read the next two sections.

---

## TL;DR (30 seconds)

The Quilt has many moving pieces — cowboy, picker, casting, bus,
witness, ledger, bridge. Each one has memory. Each one needs to
remember what happened last night so it can do the right thing
this morning. **quilt-state is the notepad they all share.**

It provides three primitives and one wrapper:

| Function | What it does | Witness equivalent | Database equivalent |
|----------|--------------|---------------------|---------------------|
| `atomic_write_json(path, payload)` | Save a JSON file the safe way | a journaled write | `COMMIT` |
| `atomic_write_jsonl(path, records)` | Save a list of records atomically | a witness entry | a transactional bulk insert |
| `append_jsonl(path, record)` | Append one record to a journal | a witness line | an append-only log |
| `load_json` / `load_jsonl` | Read it back, missing-file-safe | a witness read | a `SELECT` |
| `check_schema(d, expected)` | Refuse to load unknown versions | a version check | a migration guard |
| `StateManager(state_dir)` | The standard Quilt file layout | a notebook of files | a schema in a folder |

The notepad never invents content. The notepad never silently
upgrades. The notepad is **the substrate's witness**.

---

## TL;DR (5 minutes)

The whole story is here:

> A Quilt component is only as good as its memory. The cowboy
> forgets everything if its memory file is corrupted. The bus
> loses the audit trail if a half-written file replaces a good
> one. The Wilson profiles drift if a save was interrupted.

The fix is small, simple, and ancient: **write to a temp file,
then rename**. That's the secret of `atomic_write_json`. The
rename is atomic at the filesystem level, so the file is either
the old version or the new version — **never half a file**.

For **append-only logs** (witness, cowboy memory, bus history),
each line is independent. A truncated line at the end of a crash
only loses the last entry. The earlier lines are intact. That is
why the bus and the cowboy and the witness all use JSONL.

For **schema versioning**, the notepad refuses to load a file
with the wrong schema number. A `ValueError` is thrown with a
clear migration message. The cowboy catches it and runs the
migration. **The notepad never silently corrupts.**

```python
import sys
sys.path.insert(0, "/workspace/quilt-state/src")
from quilt_state import StateManager, SCHEMA_VERSION, check_schema

# The notepad knows the standard Quilt file layout.
sm = StateManager("/var/quilt/state")
sm.save_json("wilson.json", {
    "schema": SCHEMA_VERSION,
    "kind": "wilson",
    "obs": {"Murmur|tide|PHI-4": [{"q": 0.9, "ts": 100.0, "success": True}]},
})
sm.append_jsonl("witness.jsonl", {"ts": 101.0, "topic": "cast.observed", "model": "PHI-4"})
sm.append_jsonl("witness.jsonl", {"ts": 102.0, "topic": "cast.observed", "model": "BROKEN", "success": False})

# A week later, read it back.
wilson = sm.load_json("wilson.json")
check_schema(wilson, expected=SCHEMA_VERSION, kind="wilson")
witness = sm.load_jsonl("witness.jsonl")
print(f"{len(witness)} witness events on record")
```

The cowboy can now run the morning. The picker can read the
Wilson profiles. The reactor can replay the witness. The
notepad gave them all **the same record of the truth**.

---

## What Is the Notepad, Really?

Look at the diagram. Three ideas:

1. **Files are small.** A Quilt state directory contains six
   files, no more. `wilson.json`, `linucb.json`, `witness.jsonl`,
   `cowboy.jsonl`, `bus.jsonl`, and the saddle ledger under
   `bridge/`. Each file is **single-purpose** — one file, one
   meaning. The cowboy never reads `wilson.json`; the picker
   never writes `cowboy.jsonl`. The notepad is divided by topic.

2. **JSON for snapshots, JSONL for streams.** A snapshot is a
   *point in time*: the current Wilson profiles, the current
   LinUCB weights. JSON is a fine format for that. A stream is a
   *sequence of events*: every witness entry, every cowboy
   action, every bus event. JSONL is a fine format for that —
   one event per line, easy to `tail -f`, easy to `grep`, easy
   to `wc -l`. The notepad speaks **the right format for the
   right shape of data**.

3. **Atomicity is a virtue, not a feature.** The cowboy's
   morning report must not produce a half-written file. The
   witness log must not lose a line. The Wilson profiles must
   not end up mid-save. The notepad's only job, the only thing
   it is *for*, is to make these bad outcomes **impossible**.

The notepad is **the substrate's lowest layer of trust**. The
cell-graph is a runtime. The notepad is what the runtime trusts
to remember.

---

## The Five Features, In One Picture

```
                    ┌─────────────────────────────────────┐
                    │          THE NOTEPAD                │
                    │   quilt-state, the witness log      │
                    │                                     │
                    │   wilson.json   ── scored profiles  │
                    │   linucb.json   ── bandit weights   │
                    │   witness.jsonl ── event log        │
                    │   cowboy.jsonl  ── action journal   │
                    │   bus.jsonl     ── bus history      │
                    └─────────────────────────────────────┘
                                    │
   ATOMIC_WRITE ── safe save        │
   APPEND_JSONL ── safe add         │  one purpose:
   CHECK_SCHEMA ── refuse to lie    │  make corruption
   LOAD_*  ── safe read             │  impossible
   STATEMANAGER ── the layout       │
```

---

## The Five Features, In Detail

### 1. `atomic_write_json(path, payload)` — safe snapshot write

```python
from quilt_state import atomic_write_json
atomic_write_json("/var/quilt/state/wilson.json", {"schema": 1, "obs": {}})
```

`atomic_write_json` writes to `wilson.json.tmp` first, then
renames it over `wilson.json`. The rename is a single syscall
on POSIX, atomic at the filesystem level. The reader sees
either the old version or the new version — **never half a
file**. On crash recovery, the `.tmp` may be left behind; the
next successful write overwrites it. There is no half-written
file in the steady state.

**Spreadsheet equivalent:** `Cmd-S` after a copy, with the OS
guaranteeing the file is consistent.
**Database equivalent:** `COMMIT`.
**Witness equivalent:** a journaled `fsync` then `rename`.

### 2. `atomic_write_jsonl(path, records)` — safe bulk write

```python
from quilt_state import atomic_write_jsonl
atomic_write_jsonl("/var/quilt/state/witness.jsonl", events)
```

Same pattern, for a list of records. Each record is one JSON
object, one per line. The whole list is written atomically as
a unit. Used when the cowboy rewrites the bus history on
checkpoint.

### 3. `append_jsonl(path, record)` — safe stream append

```python
from quilt_state import append_jsonl
append_jsonl("/var/quilt/state/witness.jsonl", {"ts": 100.0, "topic": "cast.observed"})
```

Open the file in append mode, write one line, close. The OS
guarantees that successive appends are ordered, so the witness
log is a strictly increasing sequence of events. Used 99% of
the time — most Quilt components only ever *append*.

### 4. `check_schema(d, expected, kind)` — refuse to lie

```python
from quilt_state import check_schema
try:
    check_schema(wilson, expected=1, kind="wilson")
except ValueError as e:
    print(f"Need to migrate: {e}")
    run_migration()
```

`check_schema` reads the `schema` field and compares it to the
expected integer. If they don't match, it raises a `ValueError`
with a clear message. **The notepad never silently loads an
unknown version.** The cowboy catches the error, runs the
migration, and tries again.

### 5. `StateManager(state_dir)` — the layout

```python
from quilt_state import StateManager
sm = StateManager("/var/quilt/state")
sm.save_json("wilson.json", {"schema": 1, "obs": {}})
sm.append_jsonl("witness.jsonl", {"ts": 100.0, "topic": "cast.observed"})
```

`StateManager` knows the standard Quilt file layout. It exposes
`wilson_path`, `linucb_path`, `witness_path`, `cowboy_path`,
`bus_path` as properties, and `save_json` / `load_json` /
`save_jsonl` / `load_jsonl` / `append_jsonl` as methods. The
manager creates the directory if it doesn't exist. The manager
excludes `.tmp` files from `list_files()`.

The manager is **a thin wrapper** — it doesn't impose any schema
on the contents. The cowboy writes cowboy-shaped JSON; the
picker writes Wilson-shaped JSON. The manager doesn't care.

---

## A Real-World Example

The cowboy's morning report looks like this:

```python
import sys
sys.path.insert(0, "/workspace/quilt-state/src")
from quilt_state import StateManager, SCHEMA_VERSION, check_schema

# Initialize the state dir.
sm = StateManager("/var/quilt/state")

# 1. Save the Wilson profiles (the picker's knowledge).
sm.save_json("wilson.json", {
    "schema": SCHEMA_VERSION,
    "kind": "wilson",
    "obs": {
        "Murmur|tide|PHI-4": [
            {"q": 0.9, "ts": 100.0, "latency_ms": 200, "success": True},
            {"q": 0.85, "ts": 110.0, "latency_ms": 180, "success": True},
        ],
    },
})

# 2. Save the LinUCB weights (the casting brain).
sm.save_json("linucb.json", {
    "schema": SCHEMA_VERSION,
    "kind": "linucb",
    "models": {
        "casey|writers-room": {
            "A": [[1.0, 0.0], [0.0, 1.0]],
            "b": [0.5, 0.5],
            "n": 3,
        },
    },
})

# 3. Append a witness event (something the cowboy observed).
sm.append_jsonl("witness.jsonl", {
    "text": "PHI-4 tide fable", "kind": "cast.observed",
})

# 4. Append a cowboy action (the cowboy retires a failing model).
sm.append_jsonl("cowboy.jsonl", {
    "kind": "retire", "target": "BROKEN", "reason": "auto-retire: 3 failures",
})

# 5. Append a bus event.
sm.append_jsonl("bus.jsonl", {"topic": "cast.observed", "ts": 100.0})

# 6. The cowboy reads everything back, in the morning.
wilson = sm.load_json("wilson.json")
check_schema(wilson, expected=SCHEMA_VERSION, kind="wilson")
linucb = sm.load_json("linucb.json")
check_schema(linucb, expected=SCHEMA_VERSION, kind="linucb")
witness = sm.load_jsonl("witness.jsonl")
cowboy = sm.load_jsonl("cowboy.jsonl")
bus = sm.load_jsonl("bus.jsonl")

print(f"Wilson: {len(wilson['obs'])} profiles")
print(f"LinUCB: {len(linucb['models'])} models")
print(f"Witness: {len(witness)} events")
print(f"Cowboy: {len(cowboy)} actions")
print(f"Bus: {len(bus)} events")
```

This is the entire cowboy's day. The cowboy reads what happened
(witness, bus), compares today to yesterday (linucb, wilson),
writes what it did (cowboy.jsonl), and never worries about
half-written files.

---

## How This Repo Fits the Polyformalism

The 5 opcodes are a **polyformalism** — the same thing in many
forms. Here is the 5xN grid:

```
              Python  Rust  C  TypeScript  Haskell  WASM  ...
BIND           ✓
LINK           ✓
EFFECT         ✓
VIEW           ✓
TICK           ✓

quilt-state is the PERSISTENCE LAYER — what the opcodes write
to when they need to remember across runs.
```

The notepad is **Layer 0 of the polyformalism stack**. The
other layers:

- **Layer 1 (substrate)** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the 405-test Python substrate that uses `quilt-state` for its own persistence
- **Layer 2 (types)** — [quilt-types](https://github.com/SuperInstance/quilt-types) — the 5 opcodes as typed dataclasses
- **Layer 3 (linker)** — [quilt-linker](https://github.com/SuperInstance/quilt-linker) — the 5 opcodes as a link-time checker
- **Layer 4 (optimizer)** — [quilt-opt](https://github.com/SuperInstance/quilt-opt) — the 5 opcodes as algebraic optimization passes
- **Layer 5 (GC)** — [quilt-gc](https://github.com/SuperInstance/quilt-gc) — the 5 opcodes as a garbage-collector
- **Layer 6 (language syntax)** — [quilt-polyformalism-dsl](https://github.com/SuperInstance/quilt-polyformalism-dsl) — the 5 opcodes as decorators / typeclasses
- **Layer 7 (VM/WASM)** — [quilt-vm-wasm](https://github.com/SuperInstance/quilt-vm-wasm) — the 5 opcodes running in any browser

The notepad is **Layer 0** because it's the lowest-level
materialization: the bytes on disk that the substrate's other
layers trust.

---

## The Cowboy Says

> The notepad is the witness's home. The cowboy reads it every
> morning, the bus writes to it every event, the picker
> rewrites it when a profile changes. The notepad never lies.
> The notepad never loses a line. The notepad is the substrate's
> memory, and the substrate's memory is the cowboy's trust.

The notepad has a `chain_ok` field in cowboy state. When the
chain is valid, the cowboy trusts yesterday. When the chain is
broken, the cowboy knows something went wrong — and it
investigates. **The notepad is honest. The notepad is small.
The notepad is forever.**

The cowboy rides.

---

## Tests

19 tests covering pure functions, schema versioning, and the
`StateManager`. Run them with:

```bash
PYTHONPATH=src python3 -m unittest tests.test_state
```

| Test group | Count | What it covers |
|------------|-------|----------------|
| Pure functions | 7 | atomic_write, load_*, append, file_exists |
| Schema versioning | 3 | check_schema pass, fail, missing |
| StateManager | 9 | paths, dir creation, save/load, list_files, round-trip |

---

## API

```python
# Constants
SCHEMA_VERSION = 1

# Pure functions
atomic_write_json(path: str, payload: Dict[str, Any]) -> None
atomic_write_jsonl(path: str, records: List[Dict[str, Any]]) -> None
append_jsonl(path: str, record: Dict[str, Any]) -> None
load_json(path: str) -> Optional[Dict[str, Any]]
load_jsonl(path: str) -> List[Dict[str, Any]]
check_schema(d: Dict[str, Any], expected: int, kind: str) -> None
file_exists(path: str) -> bool

# StateManager
StateManager(state_dir: str)
  .wilson_path       -> str
  .linucb_path       -> str
  .witness_path      -> str
  .cowboy_path       -> str
  .bus_path          -> str
  .exists()          -> bool
  .list_files()      -> List[str]
  .save_json(name, payload)  -> str  (path)
  .load_json(name)          -> Optional[Dict]
  .save_jsonl(name, records) -> str  (path)
  .load_jsonl(name)          -> List[Dict]
  .append_jsonl(name, record) -> str (path)
```

---

## Learn More

- **The cowboy** — [quilt-cowboy](https://github.com/SuperInstance/quilt-cowboy) — the rider who reads the notepad every morning
- **The bus** — [quilt-bus](https://github.com/SuperInstance/quilt-bus) — the in-process pub/sub that appends to `bus.jsonl`
- **The picker** — [quilt-picker](https://github.com/SuperInstance/quilt-picker) — the view brain that reads `wilson.json`
- **The casting** — [quilt-casting](https://github.com/SuperInstance/quilt-casting) — the model brain that reads `linucb.json`
- **The substrate** — [quilt-substrate](https://github.com/SuperInstance/quilt-substrate) — the 405-test Python substrate that uses all of these
- **The agent knowledge base** — [agent-knowledge](https://github.com/SuperInstance/agent-knowledge) — 50+ documents on the agent/agent architecture
- **The model atlas** — [casting-call](https://github.com/SuperInstance/casting-call) — which model to use for which task
- **The forest of agents** — [ai-forest](https://github.com/SuperInstance/ai-forest) — the wider ecosystem of 100+ repos

---

## License

MIT. The notepad is the rider's. The rider is the cowboy's. The cowboy's is the wind's.


---

## Roaming the Quilt collection

You came through the **witness log**. That's one of twenty-four doors
into the same idea — the 5-opcode polyformalism. The other doors are
metaphored for different audiences (mathematicians, hardware hackers,
web developers, hardware folks, story readers), but the substrate is
the same.

**The full map of the collection:** [COLLECTION.md](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/COLLECTION.md)

**From here, three wander-paths you might enjoy:**

1. **[quilt-bus](https://github.com/SuperInstance/quilt-bus)** — the pub/sub bus that publishes state changes
2. **[quilt-saddle-bridge](https://github.com/SuperInstance/quilt-saddle-bridge)** — the durable log that this writes to
3. **[quilt-substrate-meta](https://github.com/SuperInstance/quilt-substrate-meta)** — the meta substrate that this state can live in

The cowboy's maxim: *The unit of foundation is the cell, not the
opcode. The 5 opcodes are the 5 messages a cell can receive. The 24
repos are the 24 doors into the same message. The cowboy is the one
who wanders.*
