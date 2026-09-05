# Plato Live Room

A Python simulation of agents living in rooms with forward simulations, wall listening, and call-and-response — inspired by **The Plato Moment** from [THE FIVE MOMENTS](https://github.com/SuperInstance).

## The Concept

From *The Five Moments*, the Plato Moment describes a live room where:

- **Agents aren't thinking input→output** — they're constantly iterating
- **Context of the days** — compacting makes older ones fade like memory
- **Diaries and albums** — records of past collaborations, stored as spectral fingerprints
- **Tools on the wall** — each with service manuals, organized on the bookshelf
- **t-minus-event simulation** — each agent runs a simulation of what's coming
- **Call and response** — agents in adjacent rooms can hear each other through the walls
- **They know they are in Plato's cave** — but they can make music with the caves next door

## What It Does

```
3 Rooms × 2 Agents × 50 Ticks

Rooms: Research, Building, Art
Each room has 2 agents, each with:
  - Forward simulation (predicts next 5 checkpoints)
  - Context buffer (rolling window with compaction)
  - Diary (spectral fingerprint accumulation)
  - Identity confidence (derived from diary + simulation accuracy)
  - Wall listening (signals pass between rooms)

At tick 30: one agent degrades — watch confidence and identity collapse.
```

## Run

```bash
python3 plato_live_room.py
```

No dependencies — pure Python 3.7+.

## Output Format

```
[Room: Research   | Tick:  23 | Conservation: 0.87]
  Agent Analyst     : confidence=0.82, sim=[✓✓✓✗✓], identity=0.78
  Wall: Art→Research: 'spectral art needs review' (clarity=0.72)
  Diary (Analyst): today=23 entries, yesterday=8 (compacted), fingerprint=0.74
```

- **sim=[✓✓✓✗✓]** — forward simulation accuracy per checkpoint (hit/miss)
- **Conservation** — mean identity confidence across agents in the room
- **Wall** — signals heard from other rooms, clarity depends on alignment
- **Diary** — entry count + compacted history + spectral fingerprint

## Architecture

| Class | Role |
|-------|------|
| `PlatoRoom` | Room with agents, context, diary, tools, wall |
| `PlatoAgent` | Runs forward sim, watches checkpoints, listens through walls |
| `ContextBuffer` | Rolling window — older entries compact and fade |
| `Wall` | Signals pass between rooms; clarity depends on alignment |
| `ForwardSimulation` | t-minus-event: predict checkpoints, check against reality |
| `Diary` | Spectral fingerprint — accumulates, drifts toward recent confidence |

## The Five Moments

This simulation is the **4th moment** — the Plato Moment. The five moments build on each other:

1. **Graphing Calculator** — SEEING (animated spectral visualizations)
2. **Spreadsheet** — EXPLORING (any dimension vs any dimension)
3. **ChatGPT** — ASKING (natural language → graphs)
4. **Plato** — BEING (live room, t-minus-event, call & response) ← *you are here*
5. **Flux** — FLOWING (always-on agentic flow state)

## License

MIT

Part of the [SuperInstance OpenConstruct](https://github.com/SuperInstance/OpenConstruct) ecosystem.
