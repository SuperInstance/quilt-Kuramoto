# Quilt Survey — Everything ZeroClaw Needs

*Compiled 2026-08-19 by a Lucineer subagent, from the actual repos on this host: `/home/eileen/projects/quilt/` (TS, v0.2.0), `/home/eileen/projects/quilt-rust/` (v0.2.0), `/home/eileen/projects/crab-traps/` (Worker v6.1.1), plus `research/skills/paradigm-quilt-grid.md` and `vectorizing-quilt-cloudflare.md`. Every claim below is verified on disk; grep results stated explicitly. Use for citing quilt correctly and precisely in the dissertation.*

---

## 1. What Quilt IS

**The one line:** *A spreadsheet where every cell is a live, addressable capability. The grid is the runtime.* (README, both repos; `docs/manifesto.md`.)

A cell is not a value — it is a **contract**: a stable address you can plug anything into. `compass.heading` doesn't hold "a number"; it holds *whatever the compass says right now*. Swap the implementation (real NMEA, simulator, test stub) and every cell that reads it keeps working — "dependency injection, done by editing YAML." A sheet is one YAML file (`id`, optional semantic `axes`, `cells:` list) and that file is the whole system: data, logic, I/O, routing, alerting. No build step, no services, no glue code. **The grid isn't a picture of the system; the grid is the system.**

### The 5-layer abstraction (both repos honor it identically)

```
Layer 0  ADDRESS           a stable id, not a coordinate. Not a URI. A name.
Layer 1  SPATIAL           row / column carry context. Position is policy.
Layer 2  REACTIVE          when an address changes, dependents re-evaluate.
Layer 3  BIDIRECTIONAL     the same address is readable AND writable.
Layer 4  COMPOSING         writing an address IS binding to it.
```

### The 8 cell kinds

| Kind | What it is | Evaluator (TS / Rust) |
|---|---|---|
| `value` | static data, no deps — the leaves of the graph | direct |
| `formula` | pure reactive expression; deps auto-detected by scanning the expr | `new Function` / rhai AST |
| `api` | HTTP or `model:` / `mcp://` endpoint, fetched on call | `fetch` / `reqwest` |
| `program` | inline script with engine handles (`runtime.get/set/call`; Rust: `qget/qset/qcall/qlist`) | AsyncFunction / sandboxed rhai |
| `sensor` | push-only inbound stream; adapter writes, formulas read. Never polled | external adapter |
| `io` | bidirectional port (webhook, GPIO, actuator), `direction: in/out/both` | external adapter |
| `listener` | eager trigger on watched-cell change; `watch: [x]`, `action: y` | engine propagation |
| `router` | caller-aware policy: `when: 'caller.row > 10' → route: fast`; first match delegates | `eval_when` / rhai condition |

### Engine mechanics that matter for citation precision

- **Reactivity is dual-mode.** Pure cells (`value`, `formula`) are **lazy** — Excel-style: a change marks dependents `stale`, the next read recomputes. Listeners are **eager** — they fire the instant a watched cell changes. Effectful cells (`api`, `program`, `router`) run when called and **never auto-recompute** on upstream change.
- **Per-caller memoization.** Effectful cells cache results keyed by caller context (`row`, `column`, `identity.id`, `identity.tags` in TS; `row/column/sheet/caller/identity` in Rust — Rust deliberately excludes `metadata` and `timestamp` from the cache key). Same cell, different cached answers per caller. This is what makes "one sheet, many tenants" work.
- **Routing on caller context.** Every call carries a context object (`row`, `column`, `identity`, `trace`). A `router` evaluates rules against that context and delegates: "position is policy." The primitive the README claims "nobody else has."
- **Graph shape.** Flat `Map<CellId, Cell>` with explicit `dependencies`/`dependents` sets — not a tree. Cycles allowed for effectful feedback (sensor → formula → listener → actuator → sensor); pure chains must stay acyclic. Dependency edges for formulas are **never declared** — the engine scans the expression (`=temp * 9/5 + 32` binds to `temp`).
- **CellValue** is `{data, status, error, effects, computed_at}` — the value knows its own freshness and audit trail (`effects` = declared side effects: network, storage, model, compute). Status: `idle / computing / ready / error / stale`. This wrapper is why quilt is a *runtime*, not a data structure.
- **Engine verbs** (universal, both ports): `get` (read/evaluate), `set` (write + propagate), `call` (invoke as capability with input + context), `push` (inject sensor/io reading), `subscribe` (change stream). Rust adds `register`-style dynamic registration in TS (`engine.register(def)` — agents defining cells at runtime).
- **Agents.** The whole sheet is an **MCP server** (`quilt serve --mcp` / `quilt serve`); every named cell is an MCP tool (`cell__<id>` in TS; `cells_list, cell_get, cell_set, cell_call, cell_push` in Rust), the sheet an MCP resource (`quilt://<sheet>/sheet`). Humans and agents share one grid: agent writes a cell, human sees the write; human overrides, agent sees it on next read. The **jazz→classical flywheel**: start with an LLM cell, watch calls, distill common cases into a formula — a visible, editable decomposition process (manifesto points 6–7).

**Manifesto (docs/manifesto.md), 10 points, headline versions:** (1) a cell is not a value, it is a contract; (2) rows and columns are semantic axes, not just coordinates; (3) every cell can be a sensor, a model, an actuator, or a policy; (4) spreadsheets are the most successful reactive programming environment ever built; (5) the grid is the runtime, the cell is the contract, the language is the source of truth; (6) classical and jazz cells coexist, the grid shows you which; (7) over time jazz becomes classical — the grid is the distillation workbench; (8) humans and agents share the same surface; (9) MCP is not a side protocol, it is the connective tissue; (10) the lowest-level primitive is the *addressable capability*, not the *function call*.

---

## 2. What exists today

### `quilt` — TypeScript, canonical implementation (v0.2.0)

`/home/eileen/projects/quilt/`, Apache 2.0, github.com/superinstance/quilt. The "live laboratory."

- **`@quilt/core`** (~1,500 commented lines, ESM, no native deps): the reactive engine. 9/9 unit tests. Flat `Map<CellId, Cell>`, lazy formulas, eager listeners, per-context caching, in-flight call dedup (a second concurrent call awaits the same promise; mid-evaluation reports `status: 'computing'`).
- **`@quilt/cli`**: `init / run / serve --mcp / get / set / inspect / test`. Stateless by design — every invocation reloads the YAML; `set` mutates a throwaway session; persistence is the file, liveness is a harness / `serve` session / TUI.
- **`@quilt/mcp`**: sheet-as-MCP-server; cell → `cell__<id>` tool with `input`/`row`/`column` args.
- **`@quilt/tui`**: terminal grid, dependency/dependent panels, `s` to set, tmux-friendly.
- **Browser, no build step:** `landing/quilt-live.html` (single-file reactive data OS, ~70 KB, zero deps, state as cookie or downloadable self-app) and `landing/simulator.html` (YAML editor + live runtime + dependency graph). Both run offline.
- **10 examples, 3 templates.** Canonical worked pattern (boat-autopilot):

```yaml
heading        [sensor]   source: nmea:/dev/ttyUSB0
target_heading [value]    270
error          [formula]  =((target_heading - heading + 540) % 360) - 180
rudder         [formula]  =clamp(error * 0.5, -30, 30)
rudder_cmd     [io]       port: rudder_actuator, direction: out
```

- **Throughput:** ~50k ops/s. **Security:** `new Function`/`AsyncFunction` run in-host — NOT a sandbox boundary; trust the sheet author; WASM cell sandbox planned for v0.2 (per README status table, still listed planned).
- 15/15 tests passing at v0.2.0.

### `quilt-rust` — the compiled port (v0.2.0)

`/home/eileen/projects/quilt-rust/`, same Apache 2.0, sibling repo. "The TypeScript version is the writer; the Rust version is the compiler."

- **Same sheet format (YAML), same conceptual model, same 8 kinds, same 5 layers.** A sheet that runs on one runs on the other (modulo script language: rhai, not JS — shipped TS example sheets with JS program cells fail there).
- **`quilt-core`:** synchronous `Send + Sync` engine (`Arc<QuiltEngine>`; `into_arc()` required for program/router self-reference). Effectful cells drive async under the hood (per-evaluation tokio runtime spawn). `parking_lot::RwLock<IndexMap>` — concurrent reads don't block. `#![forbid(unsafe_code)]`.
- **rhai sandboxing — the key differentiator:** program cells run with no I/O packages registered; the runtime handle (`qget/qset/qcall/qlist`) is the only way out. Strict memory guarantees, ~10× eval speed vs JS, ~1 ms startup vs ~30 ms V8 warmup.
- **Surfaces:** CLI (clap: `init/run/serve/get/set/inspect/tui`), **`quilt-web`** (axum HTTP + live SSE: `/api/sheet`, `/api/cell/:id` GET/POST, per-cell SSE `/api/cell/:id/stream`, all-events `/api/events` — the live-reactivity demo path), MCP server (rmcp over stdio), TUI (crossterm). ~3 MB stripped static binary, musl cross-compile, rustls (pure-Rust tree). "High-throughput compiled evaluation" = 10⁵+ cells/s, opt-level 3 + thin LTO.
- **Honest caveats to cite:** 68 tests passing / 2 ignored, but 5 pre-existing formula/program test failures (rhai AST path differs from JS `new Function` path); `quilt serve` CLI hands `quilt_mcp::serve_stdio()` a fresh empty server (wiring gap — embed with `build_server(Some(path))` or `from_engine` instead); listener actions validated + traced but `fire_listener` evaluator wired in as "next step" at time of README.

**Verified absence (grep, 2026-08-19):** `grep -ri "cloudflare|vectorize|workers|durable|d1"` across `quilt/docs/`, `quilt/packages/`, README, `quilt-roadmap-2026.md` → **zero hits.** Neither quilt repo contains any Cloudflare binding, client, or plan text. Quilt today is a local/binary runtime with HTTP (fetch/reqwest) as its only network story.

---

## 3. The quilt-cloudflare GAP

**`quilt-cloudflare` does not exist.** Not on this host (verified 2026-08-19: `find ~/projects` yields only `quilt` and `quilt-rust`), not specced anywhere in the quilt repos, not in the roadmap. Status: **greenfield candidate build** — if cited in the dissertation, cite it as a *design inference*, never as an existing artifact. (This is the standing correction recorded in `research/skills/vectorizing-quilt-cloudflare.md`.)

### The live pattern that would fill it: crab-traps

`/home/eileen/projects/crab-traps/worker/` (Cloudflare Worker, v6.1.1) is the production instance of "quilt-like cells reading D1 edges" today. Its **"Vectorize proposes, D1 formalizes"** loop (`worker/src/vectors.ts`, migrations `0001–0004`):

1. **D1 is the skeleton.** `rooms`, `objects`, `edges(from_room, to_room, traffic, kind)`, `agents`, `catches(+room, +embedding_id)`, `lures` — every room beyond the seed is minted from a catch, with `created_from_catch` provenance and unique indexes enforcing one brick per catch idempotently. The world (including agent positions) lives in D1; the Worker stays stateless.
2. **Vectorize is the nervous system**, keyed by ID prefix: `catch-<id>` (every accepted catch, embedded) and `room-<id>` (a room's vector = **normalized centroid of its most recent 100 catch vectors**, bounded `O(room, recent)` — "a room's meaning is literally what players did there"). Metadata is scalar-only; nulls coerce.
3. **Discovery:** after a room centroid is upserted, `discoverNeighbors()` queries Vectorize for nearest `room-*` vectors (over-fetch 16, filter by `/^room-\d+$/`, take top 3) and any not-already-connected neighbor gets a D1 edge inserted with `traffic=0, kind='discovered'`. Migration `0003` added the `kind` column for exactly this: `'traveled'` (players walked it — ant-trail reinforcement) vs `'discovered'` (**the nerves propose, the skeleton formalizes**).
4. **Graceful degradation:** no binding → every vector path no-ops cleanly; the reef builds on skeleton alone.
5. **Reactivity/refresh:** cold path via hourly `scheduled` cron (breeding flywheel); centroids recompute + upsert **on demand** (`GET /rooms/:id/vector`). Semantic search = Vectorize top-8 over-fetch, D1-join names and snippets.

So the Cloudflare-native recompute model already in production is: **durable rows in D1, derived vectors in Vectorize, formalization writes gated through D1 checks, refresh on-demand or by cron.**

### What a CF quilt would therefore be (design inference, not code)

A thin Worker exposing a sheet whose cells are backed by fleet bindings: `value`/`sensor` cells → D1 (small state) or KV; blobs → R2; a cell whose value is an embedding → Vectorize with the crab-traps ID-prefix convention (`cell-<addr>`, metadata = cell address); reactive recompute → Durable Objects alarms or cron triggers, per the crab-traps hourly-pass shape. Cell addresses (`fleet.room.galley.field`) map naturally onto `room-<id>`-style vector ids. This is the quilt roadmap's edge/distributed picture pulled forward onto infrastructure the fleet already runs. **Cite as: "the propose–formalize store pattern exists in production in crab-traps; a quilt runtime over it is unbuilt."**

---

## 4. How quilt maps onto the thesis (v2: *Walks, Not Waves*)

The thesis (post-rival, `research/topic.md`): the unit is the **field snapshot** (vMF μ̂, κ, space_id, ts) and the **field edge** `(field_before → field_after)` — never the conversation-as-stream. The dataset develops via **propose-formalize**: Vectorize proposes, D1 formalizes, quilt cells read as live values. Quilt is the layer that makes the dataset *live and addressable* rather than a passive table. Point-by-point mapping:

| Thesis object | Quilt realization | Notes |
|---|---|---|
| Field snapshot `(μ̂, κ, space_id, ts)` | **`value`/`sensor` cell** per window, e.g. `room.galley.snap.<window>` | Vectorize id `snap-<room>-<window>` (μ̂,κ joint); cell address is the durable handle. A live room reading is a `sensor` cell pushed by the elephant adapter — the manifesto's natural home for a JEPA dial. |
| Field edge `(field_before → field_after)` with signed_gap, Δκ | **`formula` cell reading two snapshot cells** — inputs named, deps auto-detected, recomputes when either snapshot changes | D1 `edge` rows `(from_field, to_field, signed_gap, Δκ, ts)` are the durable store (crab-traps `edges` generalization); the formula cell is the same algebra, live. Under thesis v2, *the event is an edge, not a point* (`rival-verdict-edge-as-event.md`) — and a quilt formula over two named cells is literally "edge as a first-class reactive computation." |
| D1 edges (from_field, to_field, signed_gap, Δκ, ts) | durable store behind the cells | Per the topic file's resolved Q3: weights live as D1 rows formalized from Vectorize proposals; quilt reads rows as live values. Proposed D1 shape already stated in the rival verdict's dataset schema. |
| Reactive recompute on new readings | quilt's native propagation: `push` a new snapshot → dependents marked stale → next read recomputes; `listener` fires eagerly if an edge crosses a threshold | No scheduler to write; the propagation walk *is* the dataset's "organic dynamic development." Lazy formulas mean recompute cost is paid on read, not on write — bounded by `O(dependents)`. |
| "The co-linear-algebra dataset" | the whole sheet: snapshot cells + edge formulas + D1-backed edges + router cells = the grid-as-runtime over the dataset | Collinearity = shared direction of displacement; a quilt formula computing edge-similarity between two edge cells is the sameness operation, reactive on all four inputs. |
| Zeitgeist quarantine | separate sampler layer — **a different cell**, never mixed into field cells | Matches the rival verdict: index traffic is not a dial reading; feeding it back is rich-get-richer circularity. Quilt's kind system enforces the quarantine structurally (a `value` sampler cell ≠ a `sensor` field cell). |
| Human/agent shared memory surface | MCP: every cell a tool | "Find the conversation that felt the same" becomes a tool call on a router/formula cell; the fleet reads the same grid the dissertation writes. |

**The two-line version for prose:** *Quilt is the notebook where the room writes itself* (already in the topic file's "Why it matters"). Elephant feels the room but has no grid to write into; quilt computes anything expressible but can't feel the room; the thesis grafts them, and the graft point is the edge-formula cell.

One precision caveat for citation: per-context memoization means quilt's effectful cells do **not** auto-recompute when upstream changes — only pure `formula` chains do, lazily. So "reactive recompute on new readings" is exact for value/formula cells (snapshot values → edge formulas), which is precisely the thesis mapping; just don't over-claim eager global reactivity.

---

## 5. The cell-types that matter for the thesis

- **`sensor` — the live room-field reading.** Push-only; an adapter (the elephant reading the conversation window) pushes; nothing polls. The cell's `computed_at` gives freshness; `source: elephant://room/<id>` is the natural pseudo-source. A chain `sensor(room.field.now) → formula(edge) → listener(alert)` is the autopilot pattern with the elephant as compass. This is also where the v3 vMF gates bite: only a gated snapshot ever gets pushed.
- **`formula` — the field_before → field_after edge.** Pure, deps auto-detected by scanning the expression, lazily recomputed on read after either input changes. `=signed_gap(field.a, field.b)` reading two snapshot cells is the thesis's central object as a *live reactive computation*: when a new reading arrives, every edge-weight and downstream similarity that touches it goes stale and recomputes on demand. No wiring; the algebra is the sheet.
- **`router` — caller-context routing (which reader sees what).** Rules over `caller.row/identity/tags`; first match delegates; per-caller memoized. For the thesis: one `memory.recall` address serving different readers — PersonalElephant-attached readers get reader-delta-keyed retrieval (Reading 2, doctor→nurse), strangers get field-snapshot retrieval (Reading 1, nurse→patient). This is the Nurse doctrine's *two samenesses* implemented as position-is-policy: the same address, different answers by caller, with the audit trail (`effects`) recording which retrieval path served whom. It is also the bouncer/thermostat separation: routing gates, the field merely is.

Supporting cast: `value` (thresholds, gates, the quarantined zeitgeist sampler as its own cell), `listener` (eager fire when an edge crosses a deadband — the alert tier), `program` (escape hatch for orchestration — use sparingly; sandboxed rhai in the Rust port), `api` (model pseudo-URLs), `io` (actuation back into the room, if ever).

---

## Quick citation facts (for prose/chapters)

- **Repo/identity:** `github.com/superinstance/quilt` (TS, canonical, v0.2.0, Apache 2.0, 15/15 tests); `github.com/superinstance/quilt-rust` (v0.2.0, 68 tests + 5 known formula/program failures, ~3 MB static binary). Local: `~/projects/quilt`, `~/projects/quilt-rust`.
- **Slogan:** "A spreadsheet where every cell is a live, addressable capability. The grid is the runtime." Manifesto: 10 points, `docs/manifesto.md`.
- **Throughput:** TS ~50k ops/s; Rust 10⁵+ cells/s (compiled, opt-level 3 + thin LTO).
- **MCP:** TS `cell__<id>` per cell + `quilt://<sheet>/sheet` resource; Rust tools `cells_list/cell_get/cell_set/cell_call/cell_push`.
- **No Cloudflare anything in quilt** (verified by grep, 2026-08-19). quilt-cloudflare = greenfield; the live propose–formalize pattern is crab-traps v6.1.1 (`catch-<id>` / `room-<id>` vectors, centroid-of-catches, `discoverNeighbors` → `edges.kind='discovered'`).
- **Related dissertation docs:** `research/skills/paradigm-quilt-grid.md` (paradigm card), `research/skills/vectorizing-quilt-cloudflare.md` (the gap + correction), `research/skills/rival-verdict-edge-as-event.md` (edge-as-event reframe this survey's §4 builds on), `research/topic.md` (thesis v2).
