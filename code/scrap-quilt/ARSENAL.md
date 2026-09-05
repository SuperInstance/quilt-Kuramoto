# ARSENAL — the quilt ecosystem, ported into scrap-quilt

Every enhancement pattern below was **read and ported** from its origin repo in
the quilt spearhead (never modified there). scrap-quilt is the live consumer:
a 55-cell Yard Sheet that the sibling game lane is already connecting to.

| scrap-quilt piece | Origin repo | Pattern ported | Where it lives |
|---|---|---|---|
| `POST /reflex` — robot reflexes (obstacle-dodge, line-follow, brownout-guard, stall-detect) | **quilt-pincher** (`src/core/engine.ts`, `src/cells/sheet.ts`) | Reflexes as quilt **cells** (formula/program kinds); trigger embedded as a feature vector, cosine-matched against reflex prototypes (FAST tier, `hitThreshold 0.80`); **guard = the veto tier** re-checked against raw sensors; safety-priority tiebreak among guard-passers. No LLM per tick — sub-50ms by construction. | `src/reflex.ts` |
| ESP32 serialization of the reflex sheet | **quilt-pincher** (`src/platforms/esp32.ts`, `docs/ESP32_PORT.md`) + **quilt-esp32** (`src/lib.rs` no_std runtime) | `.nail` bundle contract (`ESP32Engine.loadNail`): `{version, reflexes:[{id, kind, intent, proto}]}` — embeddings recomputed on-device (HashEmbedder, no bundle vectors). **Flash path:** `/reflexes/esp32` → quilt-pincher `src/platforms/workstation.ts` compiles/verifies → platform bridge pairs `.nail` with the board hex → WebSerial flash pipeline (Milestone 2) → the flash lands back on the sheet via `POST /flash-log` (tapestry record). | `src/reflex.ts → serializeForEsp32()`, `GET /reflexes/esp32` |
| `POST /ask` (and `/chat` underneath) — Spark routed as an **ai cell** | **quilt-ai** (`src/engine.ts` router, `examples/05-cost-control.yaml`) | Question → **router cell** (pure, no model call): cheap lane `@cf/deepseek-ai/deepseek-v4-flash-0731` for casual, strong lane `@cf/zai-org/glm-5.2` for code help / long or reasoning-heavy questions → answer propagates to the spark.* cells (and onward to voice/exhibit consumers via the existing `/chat` contract). The `/chat` contract is **unchanged**; routing lives underneath and surfaces as `model` + `route` in the result. | `src/router.ts`, `src/chat.ts`, `src/index.ts` |
| `POST /lore` — RAG over the world bible with **file + line citations** | **quilt-rag** (`src/cells/`: loader → chunker → embedder → vector-store → retriever → generator) | Paragraph chunker ported **line-tracked** (every chunk knows `file:startLine-endLine`); embeddings via Workers AI `@cf/baai/bge-small-en-v1.5` (free tier); in-memory cosine vector store rebuilt from a KV-cached index; generator answers ONLY from passages and cites inline as `[file.md:L-L]` — `used` echoes the citations actually referenced. Corpus: **scrapcraft-world/worldbible** (13 files, bundled read-only via `src/corpus.ts`, regen `node scripts/build-corpus.mjs`). | `src/lore.ts`, `src/corpus.ts`, `scripts/build-corpus.mjs` |
| `POST /ghost/evolve` — self-improving ghost racers | **quilt-evolve** (`src/loop.ts`, `mutate.ts`, `judge.ts`, `scope.ts` ParameterScope) | Generator/judge loop at ghost-racer scope: **genome = racing program parameters** (drivePower, cornerBrake, steerGain, lookahead, crashRecover). Each generation every genome runs a simulated lap with the SAME kinematics as `/predict` (VirtualRobot semantics: rotation-then-translation, battery sag, 6.0 V brownout knee). **Judge = lap time + 5000 ms/crash** (no LLM — the track is the judge). Tournament selection + elitism + mutate/crossover (quilt-evolve's parameter scope); winners replace the ghost pool (persisted in KV `ghost:pool`). Seeded from the D1 tape's `race.splitMs` history when the yard has raced. | `src/evolve.ts`, `src/index.ts` |
| Pincher-cached Spark (`/chat`) — pre-existing | mist-quilt + quilt-pincher doctrine | (already live before this arsenal) | `src/chat.ts` |

## Verified live (deployed worker)

- `POST /reflex` — vector-matched, **~1 ms** per pinch (test: 1000 pinches, per-pinch ≪ 50 ms)
- `GET /reflexes/esp32` — the `.nail` bundle + documented flash path
- `POST /ask` / `POST /chat` — router lane visible (`route: cheap|strong`)
- `POST /lore` — grounded answers citing `worldbible/…md:lines`
- `POST /ghost/evolve` — gen1→gen3 lap-time improvement report; `GET /ghost/pool`

## Credit

The **quilt spearhead** built the pattern libraries: quilt-pincher (reflex
engine + three-tier federation), quilt-ai (reactive AI cells + provider
routing), quilt-rag (RAG pipeline as cells), quilt-evolve (generator/judge
self-improvement), quilt-esp32 (no_std reactive runtime for $3 chips).
scrap-quilt ports them into the live Scrapcraft worker — extend, don't break.
