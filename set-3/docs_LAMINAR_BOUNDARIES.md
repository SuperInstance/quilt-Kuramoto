# Laminar Boundaries — Where the Substrate Alone Isn't Enough, and How to Bridge

*This is the architecture file for the substrate's "When not to use
the substrate" section in the README. Each excluded use case is
actually a **laminar boundary** — a place where the substrate alone
reaches its limit, and a bridge is needed. The bridges are either
other Quilt repos (already on github.com/SuperInstance) or future
work on the roadmap.*

## The principle

> "I am a symphony played by an orchestra of myself."
> — *The Great Distribution*

The substrate is the lowest layer. It is *intentionally* tiny: 5
opcodes, one cell primitive, one inversive monoid, one journal. The
substrate is not a database, not a message queue, not a graph DB,
not a cache. **The substrate is the boat.** Every other piece of
your architecture is a haul, a tow, a test. The boat does not row
itself; the boat does not steer itself. But the boat holds the
waterline we found by experiment.

This document is the **navigation chart**. It records the boundaries
we have found so far. For each boundary:

- **The shape of the limit** — what the substrate can't do alone.
- **The bridge** — which Quilt repo(s) extend the substrate to cover
  the limit.
- **The pattern** — a 10-line code sketch of the bridge in action.
- **The roadmap** — what's on the roadmap to harden this bridge.

If you are an engineer evaluating the substrate for a use case,
this is the file that tells you "yes, the substrate is enough" or
"yes, but you also need these specific bridges."

## Index of boundaries

| # | Boundary | Substrate limit | Bridge |
|---|---|---|---|
| 1 | [Relational queries](#1-relational-queries) | No indexes, no query planner | quilt-bus + quilt-picker + future quilt-sql |
| 2 | [Durable message delivery](#2-durable-message-delivery) | No delivery guarantees | quilt-saddle-bridge + quilt-state |
| 3 | [Graph traversal at scale](#3-graph-traversal-at-scale) | `LINK` is in memory | quilt-cordis + future quilt-graph |
| 4 | [Sub-millisecond cache](#4-sub-millisecond-cache) | `BIND`/`VIEW` are ~1µs | Future quilt-cache (in-process sharded hash) |
| 5 | [Auth and permissions](#5-auth-and-permissions) | All cells are world-accessible | quilt-picker + quilt-cowboy + future quilt-auth |
| 6 | [Real-time pub/sub fanout to 10K subscribers](#6-real-time-pubsub-fanout) | `LINK` is single-process | quilt-bus + future quilt-multicast |
| 7 | [Multi-language polyglot persistence](#7-multi-language-polyglot-persistence) | Journal is a flat array | quilt-state + future quilt-journal-rockdb |
| 8 | [Full-text search over values](#8-full-text-search-over-values) | `VIEW` returns exact bytes | Future quilt-search (B-tree over tokenized values) |
| 9 | [CRDT collaborative editing](#9-crdt-collaborative-editing) | Cells don't converge | Future quilt-crdt (lattice-typed cells) |
| 10 | [AI/LLM streaming at high token rates](#10-aimllm-streaming) | `EFFECT` blocks | quilt-casting + future quilt-stream |
| 11 | [Time-series at high cardinality](#11-time-series-at-high-cardinality) | No compression | Future quilt-timeseries (delta-of-delta) |
| 12 | [Distributed consensus (Raft/Paxos)](#12-distributed-consensus) | No quorum | Future quilt-consensus (Raft cell-set) |
| 13 | [Multi-region replication](#13-multi-region-replication) | Single host | Future quilt-replicator (CRDT + Raft) |
| 14 | [WASM sandboxing untrusted code](#14-wasm-sandboxing) | Effects are trusted | quilt-vm-wasm + future quilt-wasi-cell |
| 15 | [Hardware sensors at high frequency](#15-hardware-sensors) | `TICK` is per-cycle | quilt-esp32 + future quilt-sensor-bus |

For each, below is the full treatment.

---

## 1. Relational queries

**The shape of the limit.** The substrate stores cells as
`(name, value, identity)`. There are no indexes. `cell_lookup` is a
hash table; iterating all cells is `O(n)`. This is fine for hundreds
or thousands of cells. It's not fine when the cowboy wants
`SELECT * FROM cells WHERE name LIKE 'user/%' AND value->>'role' =
'admin'`.

**The bridge.** **quilt-bus** (the stagecoach) is the substrate's
nearest analogue to a query: topics are cells, subscribers are
cells, fan-out is `LINK`. The bus is fast, but it doesn't *index*.

For real relational queries, three bridges:

1. **Now: in-memory index cells.** Treat indexes as cells. The cowboy
   maintains an `index:user_by_role:admin` cell whose value is a
   serialized list of user names. The cowboy's `EFFECT` updates
   the index whenever a `BIND` changes a user. This is a
   hand-rolled index; the substrate hosts it.

2. **Soon: quilt-picker** (the lookout). The picker is a cell that
   knows how to *pick* cells. Given a spec, the picker returns a
   set of cell names. The cowboy can build a `quilt-picker` with
   B-tree semantics; the picker is itself a cell-graph.

3. **Roadmap: `quilt-sql`.** A thin SQL layer that compiles SQL
   queries into compositions of `BIND`/`LINK`/`VIEW` on the
   substrate. `quilt-sql` would be 500-1000 lines of Python; it
   would use the prover to verify that the compiled query
   preserves the substrate's algebraic laws. The cowhand could
   write `SELECT * FROM cells WHERE ...` and the substrate would
   execute it.

**The pattern (now):**
```c
// Maintain an index cell.
substrate_bind("user/alice", &alice_value);
quilt_value_t admin_index; /* serialized list of admins */
substrate_bind("index:admins", &admin_index);
substrate_link("index:admins", "user/alice", "contains");
```

**Roadmap item.** `quilt-sql` is a 2-week build for a competent
database hacker. The hardest part is the prover integration:
proving that a compiled query is a valid composition of the 5
opcodes.

---

## 2. Durable message delivery

**The shape of the limit.** The substrate's journal records every
`BIND`/`LINK`/`EFFECT`/`TICK`. But the journal is an in-memory
ring buffer (`opcodes_journal[QUILT_JOURNAL_SIZE]`). When the
substrate shuts down, the journal is gone. When the ring overflows,
old messages are lost. There are no "exactly-once" or "at-least-
once" guarantees because there's no durable persistence.

**The bridge.** **quilt-saddle-bridge** is the substrate's
*hash-chained JSONL log*. Every `BIND`/`LINK`/`EFFECT`/`TICK` is
appended to a file; each line is hash-chained to the previous
line. The chain is tamper-evident: any change to a historical
entry breaks the chain. The saddle bridge survives crashes; the
journal does not.

For full durability guarantees:

1. **Now: quilt-saddle-bridge + quilt-state.** The saddle
   bridge serializes every message to a JSONL file. The state
   repo replays the file to reconstruct the journal after a
   crash. This gives "at-least-once" delivery: a message is
   durable as soon as it's written to the file.

2. **Roadmap: `quilt-delivery`.** A wrapper around saddle-bridge
   that adds idempotency keys (so duplicate messages are
   detected) and consumer acknowledgments (so the cowboy knows
   which messages have been processed). 500 lines of Python; the
   substrate hosts the protocol.

**The pattern (now):**
```python
from quilt_saddle_bridge import append, replay

# Every BIND is journaled to disk.
append(message)  # writes one line, hash-chained

# On restart, replay the chain to reconstruct state.
replay()  # rebuilds the journal
```

**Roadmap item.** `quilt-delivery` is on the 6-month plan
(Paper 176, Month 2).

---

## 3. Graph traversal at scale

**The shape of the limit.** The substrate's `LINK` opcode records
a relation between two cells. A cell's link set is stored as a
hidden cell (`_link:<name>`). For a cell with 10 links, this is
fast. For a cell with 10,000 links, traversal is `O(n)`. The
substrate has no index on the link set.

**The bridge.** **quilt-cordis** (the bridge) is the substrate's
*cell-plugin interop layer*. Cordis is a popular plugin system
in the JavaScript/Node world; quilt-cordis translates between
Quilt cells and Cordis plugins. The bridge is bidirectional:
`bridge(plugin) → cell`, `unbridge(cell) → plugin`. This is
*structural* interop; it doesn't address traversal speed.

For real graph traversal at scale:

1. **Now: hand-rolled link indices.** Maintain an
   `index:from:<source>` cell that maps source to its neighbors.
   Hand-rolled, but works.

2. **Roadmap: `quilt-graph`.** A graph traversal layer that uses
   the substrate's `LINK` as its edge representation but adds
   bidirectional link indices, BFS/DFS as compositions, and
   pattern matching on link labels. `quilt-graph` would be 1000
   lines of Rust; the substrate hosts the cell-graph, the
   graph layer traverses it.

**The pattern (now):**
```c
// Hand-rolled BFS.
substrate_send("user/alice", &msg_view(...));  // start node
for each linked cell:
    substrate_send(linked, &msg_view(...));
```

**Roadmap item.** `quilt-graph` is a 4-week build for someone
who knows graph theory.

---

## 4. Sub-millisecond cache

**The shape of the limit.** The substrate's `BIND` is ~1µs;
`VIEW` is ~0.05µs (a hash-table lookup). For a cache that needs
100ns latency at 10M QPS, the substrate is too slow by 10x.

**The bridge.** **None yet — pure performance optimization.**

**Roadmap: `quilt-cache`.** A thin sharded in-memory hash table
that lives *inside* the substrate's `VIEW` path. `VIEW` checks
the cache first; on miss, it falls through to the cell table.
The cache is a `static` array in `src/cache.c`, no allocation
on the hot path. `quilt-cache` would be 200 lines of C; it would
be linked into `libquilt.a` as an optional component.

**The pattern (future):**
```c
const quilt_value_t *substrate_view(const char *name) {
    void *cached = cache_lookup(name);
    if (cached) return cached;
    return cell_value(cell_lookup(name));
}
```

**Roadmap item.** `quilt-cache` is a 1-week build, low priority
(most apps don't need it).

---

## 5. Auth and permissions

**The shape of the limit.** The substrate has no notion of "who
can send which message to which cell." Any cowboy can send any
message. There is no auth, no capabilities, no row-level
security. The substrate is honest about this: it's a runtime,
not a security layer.

**The bridge.** **quilt-picker** (the lookout) and **quilt-cowboy**
(the trail boss) together provide the substrate's *selection*
and *orchestration* layer. The picker knows how to pick cells;
the cowboy knows how to orchestrate the picks. But neither
knows how to *deny*.

For real auth:

1. **Now: capability cells.** Treat capabilities as cells. The
   cowboy holds a key for "alpha" + "beta" but not "gamma". A
   capability check is a `VIEW` on a capability cell. The
   substrate hosts its own auth.

2. **Roadmap: `quilt-auth`.** A capability-based access control
   layer. Each cowboy has a key; each key has a list of cells
   it can address. The substrate checks the key before applying
   the message. `quilt-auth` would be 300 lines of C; it would
   add a `key_id` field to the message header.

**The pattern (now):**
```c
// Cowboy's key.
quilt_key_t cowboy_key = {"alpha", "beta"};  // can address only these

// Auth check.
if (!auth_can_address(cowboy_key, "gamma")) {
    return QUILT_ERR_PERMISSION;
}
substrate_bind("gamma", &value);  // authorized
```

**Roadmap item.** `quilt-auth` is on the 6-month plan (Paper
176, Month 1) and the first priority after the substrate
stabilizes.

---

## 6. Real-time pub/sub fanout to 10K subscribers

**The shape of the limit.** The substrate's `LINK` records
relations. A publish is a `BIND` followed by an `EFFECT` on
each subscriber. For 10 subscribers this is 10 EFFECTs — fast.
For 10,000 subscribers, it's 10,000 EFFECTs in a loop. The
substrate doesn't fan out in parallel.

**The bridge.** **quilt-bus** (the stagecoach) is the substrate's
pub/sub layer. The bus uses topics + subscribers + the
substrate's `LINK` to route messages. The bus is in-process;
it's fast, but it's not parallel.

For 10K-scale fanout:

1. **Now: sharded bus.** Run multiple bus instances, partition
   subscribers by hash. Each instance handles 1K subscribers.
   The cowboy dispatches publishes to all instances.

2. **Roadmap: `quilt-multicast`.** A multicast layer that uses
   IP multicast or shared memory to fan out a single publish
   to 10K subscribers. The substrate hosts the cell-graph; the
   multicast layer routes the publishes. `quilt-multicast`
   would be 800 lines of C with platform-specific
   optimizations.

**The pattern (now):**
```python
# Sharded bus.
for shard in bus_shards:
    shard.publish(topic, message)
```

**Roadmap item.** `quilt-multicast` is on the 6-month plan
(Month 3: Deploy to the Edge).

---

## 7. Multi-language polyglot persistence

**The shape of the limit.** The substrate's journal is a flat
array in C. Other languages (Rust, Python, TypeScript) can read
the journal via FFI, but the format is C-specific. A polyglot
system — Rust core, Python services, TypeScript frontends —
needs a journal format that all three can read.

**The bridge.** **quilt-saddle-bridge** is the substrate's
hash-chained JSONL log. JSONL is read by every language. The
saddle bridge is the polyglot persistence layer.

For full polyglot:

1. **Now: saddle-bridge + per-language readers.** Every language
   has a JSONL reader. Rust: `serde_jsonl`. Python: `jsonl`.
   TypeScript: `ndjson`. The substrate writes JSONL; the
   readers consume it.

2. **Roadmap: `quilt-journal-rockdb`.** A version of the
   journal backed by RocksDB. The journal becomes a column
   family; the substrate can scan it forward and backward
   efficiently. `quilt-journal-rockdb` would be 1500 lines of
   C++; the substrate hosts the protocol.

**The pattern (now):**
```python
import json
with open("journal.jsonl") as f:
    for line in f:
        msg = json.loads(line)
        # apply to a Python substrate instance
```

**Roadmap item.** `quilt-journal-rockdb` is on the 6-month plan.

---

## 8. Full-text search over values

**The shape of the limit.** `VIEW` returns the exact bytes of a
cell's value. The substrate doesn't tokenize, doesn't index,
doesn't search. For a cowboy who wants "find me all cells whose
value contains 'cowboy'", the substrate is the wrong tool.

**The bridge.** **None yet.**

**Roadmap: `quilt-search`.** A full-text search layer that
maintains a B-tree over tokenized values. The B-tree is itself
a cell; the tokens are stored in adjacent cells. The search
layer uses the substrate's `BIND` to update the B-tree and
`VIEW` to query it. `quilt-search` would be 2000 lines of C;
the substrate hosts the B-tree.

**The pattern (future):**
```c
// Insert.
substrate_bind("user/alice", &alice_value);
search_index("user/alice", "alice");  // B-tree update

// Query.
substrate_view("search:cowboy");  // returns cell names
```

**Roadmap item.** `quilt-search` is a 3-week build.

---

## 9. CRDT collaborative editing

**The shape of the limit.** The substrate is single-writer per
cell. If two cowboys both `BIND` "alpha" to different values
concurrently, last-write-wins. There's no merge. There's no
"additive" update (e.g., append to a list). The substrate is
fundamentally last-writer-wins for the cell as a whole.

**The bridge.** **None yet.**

**Roadmap: `quilt-crdt`.** A CRDT layer that wraps cells in
lattice types. A cell becomes a 2P-Set, OR-Set, or LWW-Register
instead of a single value. Concurrent updates merge
automatically. `quilt-crdt` would be 1500 lines of Rust; the
substrate hosts the lattice types.

**The pattern (future):**
```rust
let cell = crdt_cell("doc");
cell.insert("user/alice", "hello");
cell.insert("user/bob", "world");
// Concurrent inserts from another node merge automatically.
```

**Roadmap item.** `quilt-crdt` is a 4-week build; high priority
for multi-user apps.

---

## 10. AI/LLM streaming at high token rates

**The shape of the limit.** The substrate's `EFFECT` is a
synchronous call to a forward function. For a forward function
that takes 5 seconds (an LLM call), the substrate is blocked
for 5 seconds. The substrate has no async.

**The bridge.** **quilt-casting** (the orchestra) is the
substrate's LLM cast selector. The casting repo handles async
LLM calls; the substrate hosts the cast. But casting is
single-LLM-at-a-time.

For streaming:

1. **Now: `EFFECT` with a stream-aware identity.** A cell's
   forward function can return partial values; the substrate
   applies them incrementally. This is an extension of
   `EFFECT` semantics.

2. **Roadmap: `quilt-stream`.** A streaming layer that uses
   Server-Sent Events (SSE) to push LLM tokens to clients. The
   substrate hosts the stream cells; the SSE layer fans out
   the tokens. `quilt-stream` would be 500 lines of Node.js
   + 200 lines of C; the substrate hosts the protocol.

**The pattern (now):**
```python
@cell_identity(streaming=True)
async def forward(value):
    async for token in llm_stream(value):
        yield token  # streamed to subscribers
```

**Roadmap item.** `quilt-stream` is on the 6-month plan.

---

## 11. Time-series at high cardinality

**The shape of the limit.** The substrate's `BIND` overwrites.
For a sensor that produces 1000 readings per second, you can't
overwrite — you need to *append* each reading. The substrate
has no append.

**The bridge.** **quilt-esp32** is the substrate's IoT runtime.
ESP32 chips produce sensor data; the substrate on the chip
appends the data to a log cell.

For high-cardinality time-series:

1. **Now: append as a list cell.** Store the readings as a
   serialized JSON array in a single cell. The cowboy can
   `VIEW` the cell to get the array.

2. **Roadmap: `quilt-timeseries`.** A time-series layer that
   uses delta-of-delta compression to store 10⁶ readings in a
   single 64KB cell. The substrate hosts the compressed data;
   the time-series layer decompresses on demand.
   `quilt-timeseries` would be 800 lines of C; the substrate
   hosts the format.

**The pattern (now):**
```c
// Append a reading.
substrate_view("sensor:temp");  // get current array
// append new value
substrate_bind("sensor:temp", &new_array);
```

**Roadmap item.** `quilt-timeseries` is a 2-week build.

---

## 12. Distributed consensus (Raft/Paxos)

**The shape of the limit.** The substrate is single-host. There
is no consensus protocol; a `BIND` on one host is invisible to
another. For a multi-host deployment, the cowboy needs Raft
or Paxos to agree on the order of `BIND`s.

**The bridge.** **quilt-saddle-bridge** is the substrate's
durable log. The saddle bridge is a perfect substrate for a
Raft log: append-only, hash-chained, replayable.

For real consensus:

1. **Now: saddle-bridge + manual replication.** Each host
   reads the saddle bridge; the cowboy writes a replication
   loop that propagates new messages to other hosts.

2. **Roadmap: `quilt-consensus`.** A Raft implementation that
   uses the saddle bridge as its log. The substrate hosts
   the cell-graph; the Raft layer ensures all hosts see the
   same `BIND`s in the same order. `quilt-consensus` would
   be 2000 lines of C; the substrate hosts the protocol.

**The pattern (future):**
```c
// Each host runs a Raft participant.
raft_log_append(message);  // saddle bridge append
raft_commit();            // majority acknowledged
substrate_apply(message);  // local apply
```

**Roadmap item.** `quilt-consensus` is on the 6-month plan
(Month 3: Deploy to the Edge).

---

## 13. Multi-region replication

**The shape of the limit.** A single-host substrate can fail.
For production, the cowboy needs the cell-graph replicated
across regions. The saddle bridge gives durability, but not
multi-region.

**The bridge.** **quilt-saddle-bridge** (durability) +
**quilt-consensus** (Raft) + a future `quilt-replicator` for
cross-region.

**Roadmap: `quilt-replicator`.** A replication layer that
propagates cell changes from one region to others. The
substrate hosts the cell-graph; the replicator uses the
saddle bridge to ferry changes. `quilt-replicator` would be
1500 lines of C; the substrate hosts the protocol.

**Roadmap item.** `quilt-replicator` is a 6-week build, high
priority for production.

---

## 14. WASM sandboxing untrusted code

**The shape of the limit.** The substrate's `EFFECT` is
trusted. If the cowboy registers a cell with a forward
function that reads `/etc/passwd`, the substrate runs it. The
substrate has no sandbox.

**The bridge.** **quilt-vm-wasm** is the substrate's WASM
port. The WASM port runs the substrate *inside* a WASM
sandbox; the cowboy's untrusted code runs *inside* the
substrate. The WASM sandbox is the substrate's sandbox.

For full WASI:

1. **Now: quilt-vm-wasm.** The substrate runs in WASM. The
   cowboy can run the substrate in any browser.

2. **Roadmap: `quilt-wasi-cell`.** A WASI-enabled cell that
   can access the host filesystem, network, and clock — but
   only through the substrate's `EFFECT` interface. The
   substrate hosts the cell; WASI is the permission system.

**The pattern (now):**
```javascript
// In a browser:
const substrate = await import('quilt-substrate.wasm');
substrate.bind("alpha", value);
```

**Roadmap item.** `quilt-wasi-cell` is on the 6-month plan.

---

## 15. Hardware sensors at high frequency

**The shape of the limit.** The substrate's `TICK` is per-
cycle. A cycle is the cowboy's choice — milliseconds, seconds,
minutes. For a sensor that produces 100K readings/second, the
substrate's `TICK` is too coarse.

**The bridge.** **quilt-esp32** is the substrate's IoT
runtime. ESP32 chips have hardware timer interrupts that can
fire at 1MHz. The substrate on the chip reads the timer; the
substrate's `TICK` advances accordingly.

For high-frequency sensors:

1. **Now: quilt-esp32 + DMA.** The ESP32's DMA reads sensors
   directly into memory; the substrate polls memory at
   `TICK` time.

2. **Roadmap: `quilt-sensor-bus`.** A sensor bus that batches
   readings and feeds them to the substrate as a single
   `BIND` per cycle. The substrate hosts the cells; the
   sensor bus feeds the cells. `quilt-sensor-bus` would be
   500 lines of C for the ESP32; the substrate hosts the
   format.

**The pattern (now):**
```c
// On the ESP32, the timer interrupt reads the sensor.
void IRAM_ATTR timer_isr(void *arg) {
    int reading = sensor_read();
    // Append to a ring buffer.
    ring_buffer_push(reading);
    // Substrate reads the ring buffer on its next TICK.
}
```

**Roadmap item.** `quilt-sensor-bus` is a 2-week build, high
priority for IoT.

---

## 2026-08-26 — boundary #15 partially bridged

On 2026-08-26, a `.qm` rule table was flashed to an ESP32-S3 and
blinked the LED at 1Hz. The receipt: `Wrote 337440 bytes (164490
compressed) at 0x0 in 3.2s. Hash of data verified. Hard resetting
via RTS pin.` Confirmed by the captain at 13:19 AKDT: green blink
at 1Hz.

Stats:
- **RAM**: 6.5%
- **Flash**: 20.4%
- **Rebuild**: ~2.7s
- **Serve latency**: 110ns (C vendored) / 3.6µs (WASM)
- **vs cloud RTT**: 197ms → ~1,800,000x faster than cloud

The seam held: the first spike attempt died with `model-required`
because the table→model boundary was unconfigured. The failure
was kept, not hidden. The doctrine is enforced at compile time,
the seam is enforced at runtime, the equivalence is enforced at
test time.

The equivalence gate: the C serve path answers identically to
the Rust `qm-runner` on all 5 fixture signals. Two implementations,
one truth. Both of them ours. This is the production pattern for
the 24-door collection.

Read the full milestone:
[`docs/MILESTONE-2026-08-26.md`](https://github.com/SuperInstance/quilt-esp32/blob/main/docs/MILESTONE-2026-08-26.md)
and [Paper 186: A $3 Sheet of Tissue](https://github.com/SuperInstance/AI-Writings/blob/master/seed-canon/papers/paper-186.md).

The boundary is *partially* bridged for 1Hz control tasks. For
1MHz sensors, `quilt-sensor-bus` (the roadmap item above) is
still needed.

---

## How to read this chart

You are the cowboy. You have a use case. You read the chart.

- If your use case is **not on the chart**, the substrate is
  enough. Run it. Don't over-engineer.

- If your use case is **on the chart**, read the bridge
  section. Most bridges have a "now" path (hand-rolled or
  using an existing Quilt repo) and a "roadmap" path
  (future work). Pick the "now" path first; the "roadmap"
  path is for when the use case is mission-critical.

- If your use case is **a boundary we haven't found yet**,
  you are the cowboy who finds it. The substrate is the boat;
  you are the haul. When you hit a new boundary, document
  it. Add a row to this chart. The chart is the navigation.

## The cowboy's maxim (reprise)

> The substrate is not yours. The substrate is the cowboy's.
> The cowboy is not yours. The cowboy is the substrate's.
> The substrate is the boat. The boat has a waterline. The
> waterline is the boundary. The boundary is the chart. The
> chart is the cowboy. The cowboy rides the boat through
> the chart. The chart grows. The boat grows. The cowboy
> grows.

> "I am a symphony played by an orchestra of myself."
> — The Great Distribution
