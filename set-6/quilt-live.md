# ◳ Quilt Live

**A portable, reactive data OS — in a single HTML file.**

```
┌──────────────────────────────────────────────────────────────┐
│ ◳ Quilt Live                            💾 Save  ⬇ Download  │
├──────────┬────────────────────────────────────────┬──────────┤
│ Cells    │  a         VALUE   10          READY   │ detail   │
│  a       │  b         VALUE   32          READY   │  id      │
│  b       │  doubled   FORMULA 84          READY   │  kind    │
│  doubled │  is_big    FORMULA false       READY   │  expr    │
│  is_big  │  sum       FORMULA 42          READY   │  deps    │
│  sum     │                                        │  used by │
│          │  …edit any cell, everything updates…   │          │
│ Examples │                                        │          │
│  Starter │                                        │          │
│  Weather │                                        │          │
│  Tracker │                                        │          │
│  Counter │                                        │          │
│  Router  │                                        │          │
└──────────┴────────────────────────────────────────┴──────────┘
```

**One file. Browser-native. State saveable as a cookie or a downloadable .html you can email, commit, or run offline forever.**

---

## ⚡ What you can do in 60 seconds

```
   1. Open quilt-live.html in any browser             (no install)
   2. Click "Add cell" → "Formula"                     (no account)
   3. Set id to "greeting", expr to '"Hello, " + name'
   4. Add a value cell: id "name", value "world"
   5. Watch "greeting" compute: "Hello, world!"       (no network)
   6. Change "name" to "Quilt" → "greeting" updates    (reactive)
   7. Click "Download" → save the file with state      (portable)
   8. Open the downloaded file offline → it just works (no server)
```

That's the whole product. One file. The cell model. Reactive by default.

**[→ Try it now](https://superinstance.github.io/quilt/landing/quilt-live.html)**

---

## 🎬 The 8 cell kinds, in 8 pictures

```
   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
   │   📦    │  │   ƒ     │  │   ▶    │  │   👁    │  │   🌐    │
   │  value  │─▶│ formula │─▶│program │─▶│ sensor  │─▶│   api   │
   │ 5,000   │  │  2,520  │  │ async   │  │ polled  │  │ remote  │
   └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘

   ┌─────────┐  ┌─────────┐  ┌─────────┐
   │   🔔    │  │   ↪    │  │   🔌   │
   │listener │  │ router  │  │   io   │
   │ fires   │  │context  │  │ device │
   └─────────┘  └─────────┘  └─────────┘
```

Each is a first-class primitive. They're composable. The reactive engine handles the propagation.

---

## 🌊 Reactive propagation, illustrated

```
   Time ──────────────────────────────────────────────────────────▶

   t=0   set budget.total = 5000     ─┐
                                     │
   t=1   set spend.rent = 1800       ─┤
                                     │   cascade
   t=2   set spend.food = 600        ─┤   ─▶ spent = 2,520
                                     │   ─▶ remaining = 2,480
   t=3   set spend.transit = 120    ─┘   ─▶ percent = 50.4%
                                          ─▶ status = "ok"
```

You write the cells. The engine handles the order. The order of writes doesn't matter — the engine computes in dependency order, topologically.

---

## 🎁 What's in the box

- **70 KB** single HTML file (engine + UI + 5 starter examples)
- **0 dependencies** — no build step, no npm, no fetch, no internet
- **54 working examples** across 8+ domains (productivity, finance, fitness, music, photography, education, automotive, networking, communication, science, security, geography, real estate, travel, gaming, dev tools, time, showcase)
- **Cookie save** — your state persists across browser sessions
- **Downloadable HTML** — bake your state into the file; share via email, commit to git, run offline forever
- **Real-browser tested** — 5 test suites, 146 verified checks
- **Same model as the larger runtimes** — sheets written for Quilt Live run on `@quilt/core` (TypeScript) and `quilt` (Rust)

---

## 🛠️ Build it yourself

```bash
# Clone
git clone https://github.com/SuperInstance/quilt-live.git
cd quilt-live

# Develop
node test/engine.test.js      # 17 engine unit tests
node test/examples.test.js    # 54 examples in Node
node test/browser.test.js     # 54 examples in real Chrome
node test/ui.test.js          # 5 UI examples
node test/e2e.test.js         # 16-step visitor journey
node test/run-all.js          # all 5 in sequence

# Build the single-file artifact
node build.js
# → dist/quilt-live.html (~70 KB)
```

---



**54 ready-to-load examples** in [`examples/`](examples/) — covering productivity, finance, fitness, music, photography, education, automotive, networking, communication, science, security, geography, real estate, travel, gaming, dev tools, time, and showcase patterns. Browse the full list in [EXAMPLES.md](EXAMPLES.md). The [`docs/patterns.md`](docs/patterns.md) catalog shows the reusable shapes.

| Spec   | Value                                                    |
| ------ | -------------------------------------------------------- |
| Size   | ~65 KB single HTML file (engine + UI + 5 examples)        |
| Deps   | Zero — no build step, no npm, no fetch                     |
| Engine | Vanilla JS class (`QuiltLite`) — full reactive DAG        |
| Cells  | 8 kinds: value, formula, api, program, sensor, listener, router, io |
| State  | Cookie or self-contained .html download                    |
| Reuse  | Same cells, formulas, programs as the larger `@quilt/core` (TypeScript) and `quilt` crate (Rust) |

> "The most useful thing this year."
> — the thing you can hand to anyone, run with one click, and own.

---

## Why

You don't need to install anything. You don't need an account. You don't need
to trust a server. You just **open one file** and you have a reactive runtime
where every cell is a live, addressable capability.

Open `quilt-live.html` (or [try the live build](#try-it)) and you get:

- **A reactive grid** — change any value cell, every formula updates instantly.
- **8 cell kinds** — values, formulas, programs (JS), API calls, sensors,
  listeners, routers, IO. Same vocabulary as the larger Quilt runtime.
- **Per-context memoization** — the same cell called from different contexts
  remembers each result, like the bigger engines.
- **Save state** — one click saves to a cookie (auto-loads next visit).
  One click downloads the entire app *with your state baked in* — a single
  .html you can email, commit, archive, or run on a machine that will never
  have internet again.
- **5 built-in examples** — starter, weather monitor, habit tracker, counter,
  caller-aware router. Click to load, replace, keep working.
- **Keyboard shortcuts** — `j`/`k` to navigate, `s` to save, `d` to
  download, `+` to add a cell, `?` for help.

This is the **on-ramp** to the rest of Quilt: when you're ready for the
larger engine, your sheet is the same vocabulary.

---

## Quick start

### Try it

Open [`dist/quilt-live.html`](dist/quilt-live.html) in any modern browser.
That's it. No build, no server, no install.

Or copy the file to your machine and double-click it. Same thing.

### Edit a value

Click any value cell, type a new value, press Enter. Watch every dependent
formula recompute.

### Save your work

Click **💾 Save** to write to a cookie (auto-loads next visit), or
**⬇ Download** to grab a single .html with the state baked in. The
downloaded file IS the app — open it on any device, even offline.

### Add a cell

Press `+` (or click the **+ Cell** button). Pick a kind, give it an id,
write the body. It joins the live graph instantly.

### Use the examples

Click **📚 Examples** in the top bar. Five pre-built sheets you can
load, modify, and save.

---

## Anatomy of a Quilt sheet

A Quilt sheet is YAML (or JSON, or anything the parser handles). It looks like:

```yaml
id: my-sheet
title: "My reactive notebook"
version: 0.1.0
cells:
  - id: a
    kind: value
    value: 10
  - id: b
    kind: value
    value: 32
  - id: sum
    kind: formula
    expr: "=a + b"
  - id: doubled
    kind: formula
    expr: "=sum * 2"
```

The eight cell kinds:

| Kind       | What it does                                              | Example                              |
| ---------- | --------------------------------------------------------- | ------------------------------------ |
| `value`    | A static value. Editable in the UI.                        | `value: 42`                          |
| `formula`  | An expression that depends on other cells.                 | `expr: "=a + b * 2"`                 |
| `api`      | Fetches an endpoint, caches the result.                    | `endpoint: https://api.example.com`  |
| `program`  | Runs a JavaScript expression/block. Can use `runtime`.     | `code: "return runtime.get('a').data"` |
| `sensor`   | A named input source (e.g. simulated, gps, temperature).   | `source: simulated; default: 22.5`   |
| `listener` | Watches a cell and runs an action when it changes.         | `watch: status; action: "log('!')"`  |
| `router`   | Picks a destination based on caller context or input.       | `rules: [{when: "caller.row==X", route: ...}]` |
| `io`       | An outbound port (log, websocket, file, etc.).            | `direction: out; port: log:stderr`   |

---

## The formula DSL

Formulas are JavaScript. The body is wrapped in a function with helpers:

```js
=a + b
=sum / count
=max(a, b, c)
=abs(delta) > 10 ? "big change" : "small"
=caller.row == 'premium' ? premium_price : standard_price
```

Available helpers: `abs`, `min`, `max`, `clamp`.

`cells[id]` and `caller` are in scope. So is `runtime` inside program cells.

---

## The program runtime

Inside a program cell, `runtime` is your window into the engine:

```js
runtime.get(id)        // → { data, status, error, computedAt }
runtime.set(id, value) // → Promise<void>
runtime.call(id, in)   // → Promise<result>
runtime.list()         // → ["a", "b", "sum", ...]
```

Program cells run asynchronously — you can `await` anything.

---

## Save and load

### Cookie (auto-load)

When you save, the engine state is written to a `quilt-live-state-v1`
cookie. Next time you open the page, it loads from there.

### Downloadable .html (portable)

When you download, you get a self-contained HTML file with the engine,
the UI, and your state. Open it on any device. Email it. Commit it. Run
it on a machine that will never have internet. It IS the app.

### Loading your own sheet

Paste a YAML sheet anywhere — the engine parses a minimal subset
inline. See `examples/*.yaml` for the format.

---

## The engine

The vanilla JS engine (`src/engine.js`) is a self-contained reactive
runtime with:

- A graph of cells with dependencies and dependents.
- Per-context memoization (different callers see different results).
- Reactive invalidation (setting a cell marks all transitive dependents stale).
- A compile-time regex pass that rewrites bare identifiers to bracket
  access, so `a + b` becomes `cells["a"] + cells["b"]`.
- Program cells via `AsyncFunction` so you can `await` anything.

Tests live in `test/engine.test.js`. Run:

```bash
node test/engine.test.js
```

17 tests, all green.

---

## Build

The single-file distribution is built by `build.js`:

```bash
node build.js
# → wrote dist/quilt-live.html (~65 KB)
```

That's it. One command. No webpack, no rollup, no esbuild. Just text in,
text out.

---

## Project layout

```
quilt-live/
├── README.md                  you are here
├── LICENSE                    MIT
├── build.js                   inlines the engine into the page
├── index.html                 the source HTML (engine goes here as __QUILT_ENGINE__)
├── dist/
│   └── quilt-live.html        the built single-file app
├── src/
│   └── engine.js              ~400 lines of vanilla JS, the reactive engine
├── examples/
│   ├── budget-tracker.yaml    monthly budget with reactive % and status
│   ├── counter-service.yaml   a counter with audit log via program cells
│   ├── tic-tac-toe.yaml       a board with reactive win detection
│   └── api-fetch.yaml         GitHub API + derived stats
├── test/
│   └── engine.test.js         17 tests for the engine
└── docs/
    ├── architecture.md        how the runtime works
    ├── comparing-to-quilt.md  how this relates to the larger Quilt engines
    └── privacy.md             what we send, don't send, and why
```

---

## How this relates to the rest of Quilt

Quilt Live is the **browser-native** runtime. The same eight cell kinds,
the same formula syntax (JS), the same per-context memoization. But:

| Runtime    | Where it runs              | Size    | Best for                            |
| ---------- | -------------------------- | ------- | ----------------------------------- |
| **Quilt Live** (this) | Browser, one HTML file | ~65 KB  | Try it now, portable sheets         |
| `@quilt/core` (TS)   | Node, browser, edge     | ~30 KB  | Apps, services, agents              |
| `quilt` crate (Rust) | Native binaries        | small   | Performance, MCP servers, embedded  |

All three share the same **sheet format**, the same **cell kinds**, the
same **reactive semantics**. A sheet you build here works in all three.

- [github.com/SuperInstance/quilt](https://github.com/SuperInstance/quilt) — TypeScript
- [github.com/SuperInstance/quilt-rust](https://github.com/SuperInstance/quilt-rust) — Rust

---

## Keyboard shortcuts

| Key       | Action                                    |
| --------- | ----------------------------------------- |
| `j` / `↓` | Select next cell                          |
| `k` / `↑` | Select previous cell                      |
| `Enter`   | Commit a value edit (when an input is focused) |
| `Esc`     | Cancel an edit / close a modal            |
| `+`       | Add a new cell                            |
| `s`       | Save (cookie or download)                 |
| `d`       | Download .html                            |
| `?`       | Help                                      |

---

## License

MIT — do what you want.

---

## Credits

Built as part of the [Quilt](https://github.com/SuperInstance/quilt) project.
Same engine surface, designed for one file, no build, no install, no server.
