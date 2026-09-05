# ⬢ Quilt

> **The reactive, typed, cellular runtime.** A spreadsheet that thinks. A database that reacts. A control plane that's a single file. Twenty-five open-source repos. One ecosystem.

<p align="center">
  <img src="assets/hero.png" alt="Quilt: the reactive cellular runtime" width="900">
</p>

<p align="center">
  <a href="#the-point">The point</a> •
  <a href="#the-philosophy">Philosophy</a> •
  <a href="#the-architecture">Architecture</a> •
  <a href="#concrete-proof">Concrete proof</a> •
  <a href="#the-25-repos">The 25 repos</a> •
  <a href="#getting-started">Get started</a> •
  <a href="#why-you-should-care">Why care</a>
</p>

[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![version](https://img.shields.io/badge/version-0.6.0-orange.svg)](./packages/core/package.json)
[![node](https://img.shields.io/badge/node-%3E%3D18-green.svg)](./packages/core/package.json)
[![tests](https://img.shields.io/badge/tests-115-brightgreen.svg)](#)
[![repos](https://img.shields.io/badge/repos-25-blue.svg)](#)
[![platform](https://img.shields.io/badge/platform-cloud%20%7C%20workstation%20%7C%20esp32-blue.svg)](#)
[![discussions](https://img.shields.io/badge/discussions-welcome-brightgreen.svg)](https://github.com/SuperInstance/quilt/discussions)

---

## ✦ The point

You're building software. Some of it is a web app, some is an embedded sensor, some is a data pipeline, some is an LLM agent, some is a control plane for a fleet of edge devices. Each one has a different framework, a different language, a different deployment story. Each one breaks in different ways. Each one has a different way of testing, observing, and evolving.

Quilt is one model that fits all of them. A **cell** is a value, a formula, a listener, an API call, an AI call, a sensor, a router, a program, or a vector store. A **sheet** is a JSON document of cells with dependencies. An **engine** evaluates the sheet reactively — when a cell changes, every cell that depends on it is recomputed. The same model runs in the browser, on a server, on a Cloudflare Worker, on a Raspberry Pi, on a Jetson, on an ESP32.

If you've ever wished your entire software system could be a single reactive spreadsheet, Quilt is for you.

## ✦ The philosophy

Most software is built in layers. A presentation layer. A business logic layer. A data layer. An infrastructure layer. Each layer speaks a different language, uses a different framework, and breaks in a different way. The result is complexity that compounds with every line of code.

Quilt proposes a different model. **Everything is a cell.** A user input is a cell. A computed value is a cell. An API call is a cell. A database record is a cell. A webhook is a cell. A LLM call is a cell. A sensor reading is a cell. A scheduled task is a cell. They're all just nodes in a reactive graph.

The implication: your entire system is a JSON document. The cells describe the data. The formulas describe the computation. The listeners describe the side effects. The engine evaluates the graph reactively. There's nothing else.

```
                          ┌──────────────────────┐
                          │   Quilt Sheet (JSON) │
                          │                      │
                          │  "a": 1,             │
                          │  "b": 2,             │
                          │  "sum": a + b,       │
                          │  "log": listens sum  │
                          │                      │
                          └──────────┬───────────┘
                                     │
                          ┌──────────▼───────────┐
                          │  Quilt Engine        │
                          │  (TypeScript / Rust) │
                          │                      │
                          │  reactive evaluation │
                          │  memoization         │
                          │  listener firing     │
                          │  federation          │
                          └──────────┬───────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
       ┌──────▼──────┐        ┌──────▼──────┐        ┌──────▼──────┐
       │   Browser   │        │  Cloudflare │        │  ESP32      │
       │   (TS)      │        │  Worker     │        │  (Rust)     │
       └─────────────┘        └─────────────┘        └─────────────┘
```

The same sheet. The same engine. Different runtimes. That's the entire point.

## ✦ The architecture

Quilt is a **25-repo ecosystem** organized in 6 layers:

```
                    ╔═══════════════════════════╗
                    ║  L8  Ecosystem / community ║  25 repos, cross-refs
                    ╠═══════════════════════════╣
                    ║  L7  Workflows / demos     ║  30+ work-doing pages
                    ╠═══════════════════════════╣
                    ║  L6  Invisible elves       ║  quilt-elf (5 components)
                    ╠═══════════════════════════╣
                    ║  L5  Embedded orchestrators ║  quilt-swarm, quilt-nomad
                    ╠═══════════════════════════╣
                    ║  L4  Specialized cells     ║  time, vault, vision, zk, flow
                    ╠═══════════════════════════╣
                    ║  L3  Cell + AI core         ║  quilt-core, quilt-ai, quilt-evolve
                    ╠═══════════════════════════╣
                    ║  L2  Federation             ║  quilt-fleet, quilt-mesh, quilt-agent
                    ╠═══════════════════════════╣
                    ║  L1  Hygiene / engineering  ║  LICENSE, CI, Dependabot, ESLint
                    ╚═══════════════════════════╝
```

The first three layers (L1-L3) are the foundation. The next three (L4-L6) are the value-add. The top two (L7-L8) are the experience.

Every repo at every layer cross-references the others. Every repo has the same engineering bar: Apache 2.0 license, GitHub Actions CI, CODEOWNERS, SECURITY.md, Dependabot, ESLint.

## ✦ Concrete proof

**1. A Quilt sheet, top to bottom:**

```ts
import { QuiltEngine } from '@quilt/core';

const engine = new QuiltEngine('expense-tracker');

engine.loadSheet({
  name: 'expense-tracker',
  cells: [
    // Inputs (the knobs you turn)
    { path: 'income',      kind: 'value', value: 5000 },
    { path: 'food',        kind: 'value', value: 800  },
    { path: 'rent',        kind: 'value', value: 1500 },
    { path: 'transport',   kind: 'value', value: 200  },

    // Derived (recompute when inputs change)
    { path: 'total_spent', kind: 'formula',
      fn: (ctx) => ctx.food + ctx.rent + ctx.transport },
    { path: 'savings',     kind: 'formula',
      fn: (ctx) => ctx.income - ctx.total_spent },
    { path: 'savings_rate', kind: 'formula',
      fn: (ctx) => ctx.savings / ctx.income },

    // Reactive (fires when a value changes)
    { path: 'on_spend_change', kind: 'listener', listens: 'total_spent',
      fn: (ctx) => console.log('Total spent:', ctx.total_spent) },
  ],
});

console.log(engine.get('savings_rate'));  // 0.5

engine.set('food', 1000);  // changed a value
console.log(engine.get('savings_rate'));  // 0.46 (auto-recomputed)
```

[Try it live →](https://superinstance.dev/playground.html)

**2. AI-powered sheets:**

Type "Track my expenses with food, transport, and income". z.ai generates the sheet.

[Try AI sheet →](https://superinstance.dev/ai-sheet.html)

**3. A reflex engine in your browser:**

A reflex engine that learns to respond to "list containers" in <50ms without an LLM. After enough uses, it never needs the LLM.

[Try Pincher →](https://superinstance.dev/pincher.html)

**4. A multi-instance fleet with federation:**

Watch cells propagate across 4 simulated instances with simulated network latency.

[Try Federation →](https://superinstance.dev/federation.html)

**5. Chaos engineering on K3s:**

Run 5 failure scenarios (node down, network partition, disk full, API down, etcd down) with Kimi-designed recovery thresholds.

[Try Chaos test →](https://superinstance.dev/chaos-test.html)

**6. A live inspector for any sheet:**

Visualize any Quilt sheet as a dependency graph. Click any node to inspect.

[Try Inspector →](https://superinstance.dev/inspector.html)

## ✦ The 25 repos

| # | Repo | What it does |
|---|---|---|
| 1 | [quilt](https://github.com/SuperInstance/quilt) | The core engine. 9 cell kinds, reactive evaluation. |
| 2 | [quilt-rust](https://github.com/SuperInstance/quilt-rust) | Rust port. Sync core, async cells. |
| 3 | [quilt-live](https://github.com/SuperInstance/quilt-live) | The whole engine in one HTML file. 70KB. |
| 4 | [quilt-esp32](https://github.com/SuperInstance/quilt-esp32) | no_std Rust for ESP32. |
| 5 | [quilt-mesh](https://github.com/SuperInstance/quilt-mesh) | Distributed cell graph. |
| 6 | [quilt-agent](https://github.com/SuperInstance/quilt-agent) | Agent substrate. 5 SDK primitives. |
| 7 | [quilt-time](https://github.com/SuperInstance/quilt-time) | Time cells: cron, intervals, debouncing. |
| 8 | [quilt-vault](https://github.com/SuperInstance/quilt-vault) | Encrypted secret cells. |
| 9 | [quilt-vision](https://github.com/SuperInstance/quilt-vision) | Vision cells: object detection, OCR. |
| 10 | [quilt-zk](https://github.com/SuperInstance/quilt-zk) | Zero-knowledge cells. |
| 11 | [quilt-flow](https://github.com/SuperInstance/quilt-flow) | Flow control cells. |
| 12 | [quilt-cloudflare](https://github.com/SuperInstance/quilt-cloudflare) | Cloudflare Workers runtime. |
| 13 | [quilt-ai](https://github.com/SuperInstance/quilt-ai) | AI cell kinds. 4 providers. |
| 14 | [quilt-evolve](https://github.com/SuperInstance/quilt-evolve) | Self-evolving cells. RLAIF. |
| 15 | [quilt-codespace](https://github.com/SuperInstance/quilt-codespace) | GitHub Codespaces runtime. |
| 16 | [quilt-jetson](https://github.com/SuperInstance/quilt-jetson) | NVIDIA Jetson runtime. CUDA. |
| 17 | [quilt-rag](https://github.com/SuperInstance/quilt-rag) | Production RAG as cells. |
| 18 | [quilt-fleet](https://github.com/SuperInstance/quilt-fleet) | Multi-instance federation. |
| 19 | [quilt-elf](https://github.com/SuperInstance/quilt-elf) | Invisible elves. LLM-powered background workers. |
| 20 | [quilt-pincher](https://github.com/SuperInstance/quilt-pincher) | Reflex engine as Quilt cells. |
| 21 | [quilt-base](https://github.com/SuperInstance/quilt-base) | Minimal container base images. |
| 22 | [quilt-swarm](https://github.com/SuperInstance/quilt-swarm) | Docker Swarm control plane. |
| 23 | [quilt-core-os](https://github.com/SuperInstance/quilt-core-os) | Immutable Ubuntu Core appliance. |
| 24 | [quilt-k3s](https://github.com/SuperInstance/quilt-k3s) | K3s chaos testing framework. |
| 25 | [quilt-nomad](https://github.com/SuperInstance/quilt-nomad) | HashiCorp Nomad control plane. |
| 26 | [quilt-tutor](https://github.com/SuperInstance/quilt-tutor) | **Polyformalism:** Quilt in PLATO Tutor (1970). |
| 27 | [quilt-pydantic-ai](https://github.com/SuperInstance/quilt-pydantic-ai) | **Polyformalism:** Quilt as a Pydantic-AI agent. |
| 28 | [quilt-mojo](https://github.com/SuperInstance/quilt-mojo) | **Polyformalism:** Quilt in Mojo. |
| 29 | [quilt-julia](https://github.com/SuperInstance/quilt-julia) | **Polyformalism:** Quilt in Julia. |
| 30 | [quilt-chapel](https://github.com/SuperInstance/quilt-chapel) | **Polyformalism:** Quilt in Chapel. |
| 31 | [quilt-cobol](https://github.com/SuperInstance/quilt-cobol) | **Polyformalism:** Quilt in COBOL. |
| 32 | [quilt-c](https://github.com/SuperInstance/quilt-c) | **Polyformalism:** Quilt in C. |
| 33 | [quilt-cpp](https://github.com/SuperInstance/quilt-cpp) | **Polyformalism:** Quilt in C++. |
| 34 | [quilt-csharp](https://github.com/SuperInstance/quilt-csharp) | **Polyformalism:** Quilt in C#. |
| 35 | [quilt-metal](https://github.com/SuperInstance/quilt-metal) | **Polyformalism:** Quilt in Metal. |
| 36 | [quilt-swift](https://github.com/SuperInstance/quilt-swift) | **Polyformalism:** Quilt in Swift. |
| 37 | [quilt-radio-orchestrator](https://github.com/SuperInstance/quilt-radio-orchestrator) | Fetalized-egg pattern. Bootstrap Quilt radio-theater sheets from a seed. |

Plus the [live workspace](https://superinstance.dev/workspace.html) with 30+ work-doing tool pages, and the [polyformalism page](https://superinstance.dev/polyformalism.html) that compares the 12 languages.

The 12 polyformalism repos all express the same model in different language constraints. [See the comparison →](https://superinstance.dev/polyformalism.html)

## ✦ Getting started

**In a browser (no install):**

```html
<script type="module">
  import { QuiltEngine } from 'https://cdn.jsdelivr.net/npm/@quilt/core@0.6.0/dist/index.js';
  // ...
</script>
```

[Or try the live playground →](https://superinstance.dev/playground.html)

**In Node:**

```bash
npm install @quilt/core
```

```ts
import { QuiltEngine } from '@quilt/core';
const engine = new QuiltEngine('my-app');
```

**On a Cloudflare Worker:**

```bash
npm install @quilt/cloudflare
```

**On a Raspberry Pi / Jetson / ESP32:**

See [quilt-codespace](https://github.com/SuperInstance/quilt-codespace), [quilt-jetson](https://github.com/SuperInstance/quilt-jetson), [quilt-esp32](https://github.com/SuperInstance/quilt-esp32).

## ✦ Why you should care

If you've ever wished your system was simpler. If you've ever had a service that depended on five other services and you couldn't keep track of the dependencies. If you've ever wanted a config file that was also a program. If you've ever wanted one model that runs in the browser, the server, and the embedded device. If you've ever wished your software was more like a spreadsheet — reactive, visual, easy to change.

This is for you.

## ✦ Gallery

The grid, rendered the way the fleet sees it — every cell a lit address on the dark, brass traces stitching them into one sheet.

<p align="center">
  <img src="assets/gallery-quilt.jpg" alt="A glowing spreadsheet spread across a dark ship chart table — every cell a small warm window with a different tiny machinery inside, thin brass traces connecting the lit cells, midnight navy and honey amber" width="720"><br>
  <em>The sheet as the chart table sees it — a grid of live, addressable capabilities, each cell its own lit window on the dark.</em>
</p>

<p align="center">
  <img src="assets/slot-quilt.jpg" alt="A living spreadsheet on a dark chart table — one cell a waveform, one a map, one a paragraph, one a wireframe — thin brass traces running between the lit cells" width="720"><br>
  <em>One grid, many kinds of cells — a waveform, a map, a paragraph, and a wireframe all answering from the same sheet.</em>
</p>

<p align="center">
  <img src="assets/quilt-ts-flux-deck.jpg" alt="The quilt deck, TypeScript edition — cell cards spread across midnight navy, each card a small lit machine, brass traces stitching between them" width="720"><br>
  <em>The deck, TypeScript edition — the same nine cell kinds, dealt out and wired together.</em>
</p>

<p align="center">
  <img src="assets/reference-quilt-cells.jpg" alt="The reference sheet — a glowing spreadsheet like the bar itself, every cell a small lit address, one cell mid-keystroke answering back, ledger lines like planking" width="720"><br>
  <em>The reference sheet the grid grew from — every cell a lit address, one mid-keystroke, answering back.</em>
</p>

## ✦ License

Apache 2.0. See [LICENSE](./LICENSE).


## ✦ Synergies with the SuperInstance Fleet

Quilt is one face of a larger idea. The **SuperInstance** ecosystem — **1,431+ repos, 9 active agents, 2,489+ tests, 18+ languages** — has independently arrived at the same primitives, conservation laws, and architectural patterns. The two projects are the same system seen from different angles.

| Concept | Quilt | SuperInstance | Match |
|---|---|---|---|
| Conservation | γ + η = C (productive + liquid) | γ + H = C (productive + entropy) | **1:1** |
| Topology | Room-as-cell RFC 0001 | PLATO rooms (room taxonomy) | **1:1** |
| Inter-cell protocol | Murmur (cell-to-cell gossip) | I2I bottles (git-native agent protocol) | **parallel** |
| A2A bridge | a2a_to_quilt.py (15.9KB) | [a2a-adapter](https://github.com/SuperInstance/a2a-adapter) (I2I ↔ Google A2A) | **parallel** |
| Agent lifecycle | Vibe + GC (slow state + decay) | [sunset-ecosystem](https://github.com/SuperInstance/sunset-ecosystem) (breed/vote/sunset/seed) | **3:1** |
| Federation | Federation of cells | 1,431+ repos as a fleet | **scale** |
| Cell evolution | Cell is the system, the system is the shell | [Hermit Crab Protocol](https://github.com/SuperInstance/SuperInstance-papers/blob/main/03-hermit-crab-protocol.md) (agent ⊂ harness ⊂ room ⊂ SuperInstance) | **parallel** |
| Multi-layer reasoning | 6 nervous systems (CNS, Fascia, Endocrine, Immune, Enteric, Somatic) | [Cognitive Engine](https://github.com/SuperInstance/CognitiveEngine) (5-level abstraction) | **parallel** |
| Spectral methods | Graph primitive (topology) | [spectral-fleet](https://github.com/SuperInstance/SuperInstance-papers/blob/main/01-conservation-law-of-intelligence.md) (eigenvalue ranking) | **parallel** |
| Address = identity | The address is the data | The vector IS the agent (Layer 5: where vectors become code) | **parallel** |

### Cross-references

- **Conservation law**: Quilt's γ+η=C ↔ [The Conservation Law of Intelligence in Multi-Agent Systems](https://github.com/SuperInstance/SuperInstance-papers/blob/main/01-conservation-law-of-intelligence.md) — same law, different name. η (liquid intelligence) is the SuperInstance team's η. The crystallized+liquid split is what we call DoubleEntry.
- **A2A bridge**: Quilt's a2a_to_quilt.py ↔ [a2a-adapter](https://github.com/SuperInstance/a2a-adapter) — both bridge to Google A2A. Combine them: the I2I↔A2A bridge could route through Quilt cells.
- **I2I bottles ≈ Murmur**: I2I is a more mature implementation of Quilt's Murmur primitive. Future Quilt version: make Murmur wire-compatible with I2I bottles.
- **PLATO rooms = Quilt rooms**: The PLATO room taxonomy in [superinstance-architecture](https://github.com/SuperInstance/superinstance-architecture) is the production version of our Room-as-cell RFC.
- **Hermit Crab = Cell evolution**: The [Hermit Crab Protocol paper](https://github.com/SuperInstance/SuperInstance-papers/blob/main/03-hermit-crab-protocol.md) is the formalization of what Quilt calls "the cell outgrows the shell."

The two projects share the same **conservation law**, the same **rooms**, the same **agent lifecycle**, and the same **address-as-identity principle**. Quilt is the cellular formalism. SuperInstance is the fleet. They are the same idea at two scales.


---

**The point is not the 25 repos. The point is the one model.**
