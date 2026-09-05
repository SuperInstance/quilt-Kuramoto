# 🤖 quilt-agent

> **AI agents where every capability is a cell.**

The agent is a sheet. Its memory is a set of value cells. Its tools are API cells. Its reasoning is a chain of program cells. Its goals are listener cells. Its conversation history is a value cell that grows. Its prompt is a formula that depends on the conversation.

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Try it](https://img.shields.io/badge/try-live-7ec699)](https://superinstance.github.io/quilt/landing/quilt-agent.html)

**[→ Try the agent reasoning chain live](https://superinstance.github.io/quilt/landing/quilt-agent.html)** — unfold each cell step by step.

---

## ⚡ See it in 30 seconds

```yaml
# A research agent in one YAML file
id: research-agent
title: "Simple research agent"
version: 0.1.0
cells:
  - id: input.task
    kind: value
    value: "What is Quilt?"

  - id: memory
    kind: value
    value: []

  - id: tool.search
    kind: api
    endpoint: "https://api.search.example/query"
    method: POST

  - id: tool.llm
    kind: api
    endpoint: "https://api.openai.com/v1/chat/completions"
    method: POST

  - id: reasoning.prompt
    kind: formula
    expr: |
      "You are a research agent. The user asked: " + input.task +
      ". Your memory: " + memory.join(", ")

  - id: reasoning.thought
    kind: program
    code: |
      return await runtime.call('tool.llm', {
        prompt: runtime.get('reasoning.prompt').data
      })

  - id: output
    kind: formula
    expr: "reasoning.thought"
```

That's the whole agent. Memory, tools, reasoning, output — all cells. The reactive engine handles the data flow.

---

## 🎬 The reasoning chain, visualized

```
   ┌──────────────────────────────────────────────────────────────────┐
   │                       quilt-agent                                │
   │                                                                  │
   │   ┌─────────┐                                                    │
   │   │  input  │                                                    │
   │   │  .task  │                                                    │
   │   │ "What   │                                                    │
   │   │  is     │                                                    │
   │   │  Quilt?"│                                                    │
   │   └────┬────┘                                                    │
   │        │                                                         │
   │        ▼                                                         │
   │   ┌──────────────┐     ┌──────────┐                              │
   │   │  reasoning   │     │ memory   │                              │
   │   │  .prompt     │◀────┤ (array)  │                              │
   │   │  (formula)   │     └──────────┘                              │
   │   │              │                                               │
   │   │  builds the  │                                               │
   │   │  LLM prompt  │                                               │
   │   └──────┬───────┘                                               │
   │          │                                                       │
   │          ▼                                                       │
   │   ┌──────────────┐     ┌──────────────┐                          │
   │   │  reasoning   │     │  tool.llm    │                          │
   │   │  .thought    │────▶│  (api cell)  │─────▶ OpenAI API          │
   │   │  (program)   │     │              │                          │
   │   │              │◀────│              │◀───── response            │
   │   └──────┬───────┘     └──────────────┘                          │
   │          │                                                       │
   │          ▼                                                       │
   │   ┌──────────────┐     ┌──────────────┐                          │
   │   │  output      │     │  listener    │                          │
   │   │  (formula)   │     │  on_output   │─────▶ side effects        │
   │   │              │     │              │     (log, alert, store)   │
   │   │  "Quilt is a │     └──────────────┘                          │
   │   │   cellular   │                                               │
   │   │   runtime…"  │                                               │
   │   └──────────────┘                                               │
   │                                                                  │
   └──────────────────────────────────────────────────────────────────┘
```

---

## 🎁 What's in the box

- **Agent = sheet** — memory, tools, reasoning, goals, all first-class cells
- **Reactive** — change the task, the prompt rebuilds, the LLM is called, the output updates
- **Inspectable** — every cell is queryable, every transition is visible
- **Composable** — agents can call other agents (it's just `kind: api`)
- **No vendor lock-in** — switch LLMs by changing one cell
- **Working example** — `examples/research-agent.yaml`

---

## 🏗️ Architecture: the cell model of an agent

| Agent concept | Cell kind | Why |
| --- | --- | --- |
| **Memory** | value | A list of past observations, growing over time |
| **Task / input** | value | The current goal, mutable |
| **Tools** | api | External capabilities (search, calculator, code exec) |
| **Reasoning prompt** | formula | Built from memory + task + context |
| **Reasoning step** | program | The actual LLM call, async, side-effecting |
| **Output** | formula | The final answer, derived from reasoning |
| **Goals / alerts** | listener | "If confidence < 0.7, ask the user" |
| **Conversation history** | value | Append-only, growing |

The agent's whole behavior is one YAML file. The reactive engine handles the orchestration.

---

## 💡 Use cases

| Use case | What you build |
| --- | --- |
| **Research agent** | Search the web, summarize findings, cite sources. Cells: task, search, llm, output. |
| **Coding assistant** | Read a file → LLM → write a file. Cells: file, prompt, llm, file. |
| **Data analyst** | Query a DB → LLM explains → dashboard updates. Cells: query, llm, viz. |
| **Customer support** | Tickets in, response out. Cells: ticket, context, llm, response. |
| **Workflow automation** | Trigger → action. Cells: trigger, llm, action, log. |
| **Multi-agent collaboration** | Agent A is a cell in Agent B's sheet. The mesh is the team. |

---

## 🛠️ Develop

```bash
git clone https://github.com/SuperInstance/quilt-agent
cd quilt-agent

# Open the example
cat examples/research-agent.yaml

# Run it with the canonical Quilt engine
npx @quilt/core run examples/research-agent.yaml
```

---

## 📚 Cell patterns for agents

```yaml
# Memory cell
- id: memory
  kind: value
  value: []
  # every observation appends here

# Tool cell (read-only)
- id: tool.search
  kind: api
  endpoint: "https://..."
  method: POST

# Reasoning prompt (derived)
- id: prompt
  kind: formula
  expr: "task + '\\n\\n' + memory.join('\\n')"

# Reasoning step (async, side-effecting)
- id: thought
  kind: program
  code: |
    return await runtime.call('tool.llm', {
      prompt: runtime.get('prompt').data
    })

# Output (derived)
- id: answer
  kind: formula
  expr: "thought"

# Alert (fires on change)
- id: alert_low_confidence
  kind: listener
  watch: thought
  condition: "thought.confidence < 0.7"
  action: "console.log('Low confidence — need more data')"
```

---

## 🛣️ Roadmap

1. **Streaming responses** — handle token-by-token LLM output
2. **Tool-use protocol** — standard `tool.calculator`, `tool.code_exec` cells
3. **Memory types** — short-term, long-term, episodic, semantic
4. **Multi-agent sheets** — agent-to-agent as cells
5. **Self-modification** — agents that edit their own sheets
6. **Quilt-MCP bridge** — every cell becomes an MCP tool automatically

---

## 🔗 Related

- [Quilt (TypeScript)](https://github.com/SuperInstance/quilt) — the canonical reactive runtime
- [Quilt MCP](https://github.com/SuperInstance/quilt) — every cell is an MCP tool, so every agent is an MCP server
- [Quilt (Rust)](https://github.com/SuperInstance/quilt-rust) — the desktop runtime
- [Quilt Live](https://github.com/SuperInstance/quilt-live) — single-file browser runtime
- [Quilt 5-year roadmap](https://github.com/SuperInstance/quilt/blob/main/quilt-roadmap-2026.md)

## License

MIT.
The dominant agent framework in 5 years won't be a Python library. It
will be a sheet.

A modern agent needs:

- A **memory** of past interactions.
- A set of **tools** to call.
- A **reasoning loop** to plan and act.
- A **personality / system prompt** that defines behavior.
- A way to **share state** with other agents.
- A way to **observe the world** (sensors, web, files, code).
- A way to **act on the world** (tools, actuators, code).

Quilt cells map to these perfectly:

- `memory.facts` (value) → facts the agent knows
- `memory.recent` (value) → recent conversation
- `tool.search` (api) → a web search
- `tool.code` (program) → a code execution sandbox
- `reasoning.next_step` (program) → the LLM call that picks the next step
- `goal.task` (value) → what the user asked
- `goal.done` (listener) → fires when the task is complete
- `world.temperature` (sensor) → current weather
- `act.send_email` (api) → outbound action

Multiple agents share cells. A "research agent" writes to a `findings`
cell; a "writing agent" reads from it. The graph IS the team.

## The agent as a sheet

```yaml
id: research-agent
title: "Research agent"
description: "Reads a topic, searches the web, summarizes, returns a report."
cells:
  - id: input.topic
    kind: value
    value: "What is Quilt?"

  - id: memory.recent
    kind: value
    value: []

  - id: memory.findings
    kind: value
    value: ""

  - id: tool.search
    kind: api
    endpoint: "https://api.search.example/query"
    method: POST

  - id: reasoning.prompt
    kind: formula
    expr: |
      "You are a research agent. The user asked: " + input.topic +
      ". Here is what you have found so far: " + memory.findings +
      ". What is the next search query? Return JSON: {query: string}"

  - id: reasoning.next_query
    kind: program
    code: |
      const r = await runtime.call('tool.search', { query: reasoning.prompt.data });
      return r.data?.query || 'no result';

  - id: reasoning.summarize
    kind: program
    code: |
      const findings = runtime.get('memory.findings').data || '';
      const topic = runtime.get('input.topic').data;
      const llm = await runtime.call('tool.llm', {
        prompt: 'Summarize these findings about ' + topic + ': ' + findings
      });
      return llm.data?.text || '';

  - id: output.report
    kind: program
    code: "return runtime.get('reasoning.summarize').data;"

  - id: goal.done
    kind: listener
    watch: output.report
    condition: "output.report !== null"
    action: "console.log('Agent finished:', output.report);"
```

That's a working agent. Add cells for more tools, more memory, more
reasoning steps. The graph grows. The agent gets smarter.

## What's in this repo (sketch)

A Python implementation that demonstrates the pattern. The full
implementation would be a YAML parser + a small agent runtime that
plugs into any LLM API.

```bash
# Run the example
python3 -m quilt_agent examples/research-agent.yaml
```

## Status

Design sketch. The shapes are clear. The implementation is the easy
part — it's a Quilt runtime with an LLM call as a program cell.

## Why this matters

The cell model is the right abstraction for agents because:

- **Memory is a value cell.** No special memory framework needed. The
  history is automatic.
- **Tools are API cells.** No special tool framework needed. The
  declaration is the tool schema.
- **Reasoning is a program cell.** The prompt is a formula. The
  response is a value.
- **Composition is graph composition.** Multiple agents share cells.
  The graph is the team.
- **Debugging is cell inspection.** Click a cell, see its value,
  see its history, see its dependencies. The agent is debuggable in
  the same way a spreadsheet is debuggable.

The current generation of agent frameworks (LangChain, AutoGen, etc.)
re-invent the cell model badly. Quilt doesn't need to reinvent it —
it already exists.

## Related

- [Quilt (TypeScript)](https://github.com/SuperInstance/quilt) — the
  canonical runtime, in the browser.
- [Quilt (Rust)](https://github.com/SuperInstance/quilt-rust) — the
  desktop runtime.
- [Quilt Live](https://github.com/SuperInstance/quilt-live) — the
  single-file browser runtime.
- [Quilt 5-year roadmap](../../quilt-roadmap-2026.md) — the bigger
  picture.

## License

MIT.
