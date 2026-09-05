# BAND SKELETON — Gate 1 Measured: DO Alarm Soak + Tempo Room

*Yard-band walking skeleton, weekend-1 scope (spec §14 step 0/1, turbo's "ship
the heartbeat"). Built and measured 2026-08-25 on branch `band-skeleton`,
deployed additively to the production `scrap-quilt` worker (new `/band/*`
routes; YardRoom, cells, tape — untouched). Raw evidence: `out/band-soak-*`,
`band_bars` / `band_soaks` tables in D1.*

## VERDICT: **PASS — the room holds tempo. The self-rescheduling DO alarm is the band clock.**

The spec's first-class risk (§2.1: "nothing in the fleet runs one") is retired
by measurement: **269/269 bar boundaries across two 5.5-minute production
soaks fired on time — worst single-boundary drift 1 ms, zero boundaries later
than 100 ms, zero catch-up batches.** The pass bar was "late-fire >100 ms rate
< 1%"; measured rate is **0.00%**. The external-ticker fallback stays designed
(spec §2.1) but is not needed. Weekend-2 (perception pass) is unblocked.

## What was built (exactly the skeleton, nothing more)

1. **`BandRoom` Durable Object** (`src/band-room.ts`) — self-rescheduling
   alarm as the bar clock. Bar length configurable via tempo (default 96 bpm
   4/4 = **2500 ms**). Next alarm is set at the **absolute** deadline
   `startMs + N·barMs`, never "+interval"; a catch-up loop drains every due
   tick in order if a fire lands late. The alarm reschedule is the handler's
   critical section; D1 blob flushes ride behind it via `waitUntil` — the
   metronome never waits on the database (spec §12).
2. **Bar blobs in D1** (`band_bars`: room, bar, voice, events_json, status
   pending/frozen) — commits write `pending` rows (deadline-checked); tick N
   freezes bar N+1 to `frozen` with final kind `ok|shell|rest`.
3. **Shell policy** — at freeze, a voice with no intent gets a held-root or
   rest event (bass: whole-bar Am root; keys: held shell voicing; ride/melody:
   rest). Miss count logged per voice. Never an error, never a silent hole.
4. **Four scripted voices, no models** (`src/band/common.ts`) — bass root
   walk (quarter notes, chromatic approach into each chord change), ride taps
   (8ths, hats on 2 & 4, form-end fill), keys chord shells (Am7/Dm7/E7, two
   hits/bar), sparse melody (seeded-deterministic A-minor pentatonic, 1–2
   notes/bar). All patterns deterministic in bar number.
5. **Soak harness** (`scripts/band-soak.ts`) — opens the room, commits every
   bar on absolute-time timers (configurable lead before freeze), kills one
   voice partway to prove shells, polls/logs per-bar fire jitter, stops, dumps
   the take, exports audio, prints the verdict math.
6. **Render proof** — end-of-soak dump of frozen bars → JSON + `.song` +
   `.mid` (hand-written SMF, format 0, PPQ 480, GM drums on ch 10). Both soak
   takes are audible/checkable: `out/band-soak-soak-gate1-{prod,h2}.mid`.

## The numbers (production, scrap-quilt.casey-digennaro.workers.dev)

### Run A — `soak-gate1-prod`, 96 bpm, 5.6 min, commits ~1 bar before freeze

| metric | measured |
|---|---|
| bar boundaries fired | **135 / 135** (none lost) |
| fire jitter mean / median | 0 ms / 0 ms |
| fire jitter p95 / p99 | 0 ms / 0 ms |
| **worst drift (max jitter)** | **1 ms** |
| fired ≤ 50 ms late | 100.00% |
| fired ≤ 100 ms late | **100.00%** |
| fired > 100 ms late | **0.00%** (bar was < 1%) |
| catch-up batches | 0 |
| frozen rows | 540 = 135 bars × 4 voices (ok 468 · shell 62 · rest 10) |
| voice on-time | bass 98.5% · ride 97.0% · keys 95.1% · melody 97.0% |
| commit RTT (median) | 116–133 ms (WSL2 harness → CF edge) |

### Run B — `soak-gate1-h2`, 96 bpm, 5.5 min, commits 2 bars before freeze (spec §3.1 H=2)

| metric | measured |
|---|---|
| bar boundaries fired | **134 / 134** |
| fire jitter mean / median / p95 / p99 | 0 / 0 / 0 / 0 ms |
| **worst drift (max jitter)** | **1 ms** |
| fired > 100 ms late | **0.00%** · catch-ups 0 |
| voice on-time | **100.0% × 4 voices** (0 late commits; lead median ≈ 3.8–4.2 s) |
| frozen rows | 536 (ok 475 · shell 57 · rest 4) — every non-ok row accounted: keys killed at bar 79 (53 bars) + 2 settle bars/voice |
| export | `.mid` 22,952 bytes, 134 bars, 4 voices |

### Local dev (wrangler/workerd in WSL2), for contrast — NOT the measurement target

1.2-min smoke: median 5 ms, p95 8 ms — then workerd degraded (broken pipes,
8–22 s request stalls) producing one **2196 ms** late tick and a crash. The
outlier is local-dev filesystem/scheduling noise, not DO behavior; production
(both runs) never exceeded 1 ms. Lesson recorded: **soak the clock against
production, not `wrangler dev`.**

## What broke / what it taught

1. **The clock once waited on D1.** First cut awaited the freeze batch inside
   the tick loop before rescheduling — a slow D1 could drag the metronome.
   Fixed: reschedule the alarm FIRST (critical section), blob flushes via
   `waitUntil`. In-memory truth advances regardless; blobs are a projection.
2. **H=1 is not enough margin for cold clients.** Run A committed one bar
   before freeze; every late commit was a first-bars TLS/timer race → 95–98.5%
   on-time. Run B at H=2 → 100.0%. The spec's `1.5·L` safety factor in the
   horizon formula is load-bearing, confirmed empirically.
3. **Every miss must sound, and did.** Late/killed voices produced exactly the
   predicted shell/rest rows — no errors, no holes, no lost bars; miss counts
   reconcile to the row (Run B: keys 55 misses = 53 killed + 2 settle bars).
4. **`wrangler dev` is a liar for clock science** (see local contrast above).
5. Minor: `leadMinMs` serialized as `null` (Infinity); cosmetic fix. A
   harness-side `pkill` self-match killed my own shell twice — operator error,
   not product.

## Honest caveats

- These are 5.5-minute soaks, not the spec's full 30-minute soak; two
  consecutive production runs showed identical character (max 1 ms), but the
  30-min confirmation should run as background before weekend-2 code rides on
  it. The harness is one command: `npx tsx scripts/band-soak.ts --url … --minutes 30`.
- Measured at 2.5 s bar cadence only. Faster cadence (e.g. 625 ms beat-ticks,
  spec §13 open question 2) is a different experiment — DO request cost math
  (§2.1 T3) applies unchanged: 134 ticks ≈ 134 alarm invocations ≈ 0.13% of
  the free-plan daily request budget per 5.5-min tune.
- Voice on-time measures network + server acceptance from one WSL2 client;
  model-lane latencies (T1/T0) are out of scope for gate 1 by design.

## How to run it

```bash
# local (pipeline check only — do not trust local clock numbers)
npx wrangler dev & npx tsx scripts/band-soak.ts --minutes 1.2

# production (the real measurement)
npx tsx scripts/band-soak.ts \
  --url https://scrap-quilt.casey-digennaro.workers.dev \
  --minutes 5.5 --lead-bars 2 --room soak-$(date +%s)
```

Endpoints: `POST /band/open` · `POST /band/commit` · `GET /band/state` ·
`GET /band/stats` · `POST /band/stop` · `GET /band/bars` · `GET /band/ws`
(all `?room=`, CORS `*` — Appendix B shape, skeleton subset).

---
*Gate 1 exit criteria check (turbo's plan): 4 voices ✓, 32-bar form ✓ (134
bars, 4.2 form cycles), 5 minutes at 96 bpm ✓, no missed tick ✓ (0 lost, 0
late > 1 ms), no audible glitch ✓ (renderer-side; every frozen bar present in
D1 with events or logged shell). The heartbeat ships.*
