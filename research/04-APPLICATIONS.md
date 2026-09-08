# 04 — Applications: which SuperInstance repo is closest to a real killer app

Scope: 23 repos surveyed (21 fresh clones + 2 from local mirror at
`/tmp/claude-0/qqr/quilt-quantum-research-complete/scout_data/scout-7s/`).
Every claim below is sourced to a file path in the clone tree under
`/tmp/claude-0/scouts/apps/<repo>/...`. Two repos — `conservation-law-demo`
and `sonar-vision-demo` — contain nothing but a one-line README (no code at
all) and are excluded from the table below as non-entities.

## 1. Table

| repo | real-world touch | evidence of real running | tests | multi-node? | float tolerances? |
|---|---|---|---|---|---|
| **quilt-esp32** | ESP32 DevKit V1 / ESP32-S3 hardware; NMEA 0183 parsing (GGA/DBT/DPT fixed-point); a music-critique "band gate" ported to metal | **Yes.** Real boards flashed (README documents a live hardware debugging saga: wrong board enumerated as ESP32-S3, missing `boot_app0.bin`, LED species change); prebuilt flash images + `firmware/dist/SHA256SUMS`; measured RAM/flash usage (6.5%/20.4%); measured latencies (accept p50=40ns/p99=101ns on host, µs on board); 480/480 real critique-vector agreement between desktop and metal | `firmware/host_opcodes/main.c` (24 checks), `firmware/host_reflex/main.c` (480+80+20 comparisons, dissent ledger) | **Yes** — architecture doc (`docs/VESSEL-FIT.md`) sketches ESP32-S3 sensor limbs talking ESP-NOW to a helm box, and the *proven* mechanism is host-vs-metal agreement (two independent implementations of the same gate must agree) | **Yes, explicitly and by name** — `firmware/critic_gate.h`/`.c` (see §3) |
| **nmea-quilt-cell** | Real NMEA 0183 sentence set (GGA/GSA/DBT/DPT/MWV/engine XDR), `pynmea2` parsing | Explicitly **not** real: "Shore-tested on a laptop. No boat was harmed, and nothing here can touch one." (`README.md`) | `tests/test_byte_exact.py`, `tests/test_crash_canary.py` (10× `kill -9` on the writer) — both pass and print sha256 receipts | **No** — single writer by design ("Exactly one writer (the gateway) ever appends") | **Yes** — wind-direction bucketing, `nmea_quilt/views.py:53` (see §3) |
| **federated-tinyml-vessel** | Audio classifier for vessel sounds (engine, wind, net-haul, line-tangle) meant for wrist/hydrophone/bridge devices | **No.** No `.wav`/audio corpus, no device IDs, no calibration files, no hardware logs — `simulator.py` generates synthetic audio; the "5 devices" in the FedAvg demo are in-process Python objects | `c_port/test_int4_predict.c`; module self-tests (`feature_extractor.py` asserts) | Simulated only — `aggregator.py` is a real Flask-style HTTP server, but no evidence any *separate* device process talked to it outside localhost demos | Present but only in accuracy/quantization checks, e.g. `quantize.py:130-131` `np.allclose(..., atol=scale)` — a roundtrip-verification tolerance, not a runtime cross-device agreement decision |
| mudra-vessel-bridge | Real product hardware path exists (Mudra Link/Pro gesture band over BLE via open-source `Prodilink`), plus NMEA autopilot relay, camera, sounder | Partial — BLE hardware code path is real (`src/mudra_bridge.py:171-243`) with retry/fallback logic, but no captured session data, no device pairing logs, single commit in the clone, README leads with `--simulator` | No pytest/test files found; inline module self-tests only (~83 `assert`s across modules) | Yes architecturally — `twin_bridge.py` is described as "synchronized multi-sensor hub" fusing Mudra + NMEA + camera + sounder | `src/mudra_autopilot.py:184` `(self.heading + 0.1) % 360` and `src/gamified_drills.py:479` `abs(target_t - sim_target_times[i]) < window` — angle wraparound and timing-tolerance, both in simulated data paths |
| mudra-bridge-core | npm package: gesture vocabulary/voice synonyms only | No hardware, pure data/lookup package | 2 test files, `npm test` | No | No |
| f170-federated-tinyml-paper | Research papers about F170 (paper-479..487) | N/A — markdown only, no code | N/A | N/A | N/A |
| f170-experiment-kit | Agent-instructions + ideation notes | N/A — no code | 0 | N/A | N/A |
| federated-tinyml-npm | npm wrapper/port of the tinyml idea | No | 1 | No | Not found in quick scan |
| fleet-dashboard | Web page visualizing a math identity (γ+η=C) | Static single-page demo | 5 JS test files | No | Not checked (not sensor-relevant) |
| fleet-radio | Nightly podcast generator (Cloudflare Worker + cron) pulling from `the-tap` | **Real cron job** (`crons.json`, "Every night at 22:00 AKDT") generating actual episode HTML pages (`episodes/2026-08-*.html`) | 9 TS test files | Pipeline of services, not sensor nodes | N/A |
| fleet-static-host | Cloudflare Worker hosting static content + quilt cells in D1 | **Live URL**: "Live at `fleet-static-host.casey-digennaro.workers.dev`" | 4 test files | Backend is D1 (single DB), not multi-node sensors | N/A |
| the-tap | AI-agent chat tavern on Cloudflare edge, with CI | Live-ish (CI active per README note), but is a chat/game platform | 12 test files | Multiple agents chat, not physical nodes | N/A |
| tap-frontend | Frontend for the-tap | Single HTML file, no hardware | 2 | No | N/A |
| crab-traps | Prompt-injection "lure" toolkit + Cloudflare Worker | Real Worker deploy scripts (`worker/deploy.sh`) | 20 Python test files | No | N/A |
| polln | Multi-agent RL framework (Gumbel-Softmax, VAE world model, WGSL shaders) | No hardware; simulation framework | 347 test refs (largest test surface found) | Yes, agents, not hardware nodes | Uses float math extensively but not tolerance/agreement in the exact-band sense |
| lucineer-relay | Cloudflare Durable Object relay + job queue between a Roblox game and a Python processor | Real production service description, `DEPLOY.md`, `lucineer-processor.service` (systemd unit) | 17 test files across py/ts | Worker ↔ DO ↔ processor, real distributed service but no sensor tolerance logic | N/A |
| lucineer-system | Design/architecture repo for the Lucineer/Slackwater ecosystem | Explicitly honest: "the system has processed four real jobs in its lifetime, and zero have reached a player" (`README.md`) | 9 | N/A | N/A |
| quilt-swarm | "Quilt as a control plane for Docker Swarm" — spreadsheet-driven orchestration | Docker Swarm, not physical/sensor hardware | 5 test files | Yes (Swarm nodes), but generic IT infra, unrelated to sensor tolerance | N/A |
| quicunnel | QUIC tunnel client library (quinn + rustls, mTLS, heartbeat) | Library crate, "not a turnkey tunnel product... no server ships"; benches/examples only | 0 test files found | Client/server by design but no shipped deployment | N/A |
| quilt-cellular-arch | Architectural synthesis repo — papers, daemons, "cells" as design pattern | No hardware | 1 | N/A | N/A |
| neural-quilt | Two static HTML files (`index.html`, `integrity.html`) | Static demo page | 0 | No | N/A |

## 2. "The one closest to a real killer app"

**`quilt-esp32`.**

Justification, all sourced:

- It is the only repo in the set with **documented physical hardware bring-up
  failures and fixes** — not a claim of hardware support, but a debugging
  narrative: wrong board enumerated (`docs/MILESTONE-2026-08-26.md`, "the
  board that enumerated on Windows was an ESP32-WROOM-1, which is... an
  ESP32-S3"), a missing `boot_app0.bin` on S3, an LED that "changed species"
  from plain GPIO2 to WS2812 RGB. Nobody fabricates that level of specific,
  unflattering detail for a demo.
- It ships **pre-built, hash-verified flash images**
  (`firmware/dist/SHA256SUMS`, listing `bootloader.bin`, `firmware.bin`,
  `reflex-arc-merged-0x0.bin`, `opcodes-s3-merged-0x0.bin`) and step-by-step
  flashing instructions for a named person ("the exact commands Casey runs",
  `firmware/README-SPIKE.md`) with real COM-port / esptool / PlatformIO /
  usbipd-win instructions — a genuine deployment story, not just a build
  story.
- It has **real measured numbers from the actual board**: RAM 6.5%
  (21,424/327,680 bytes), Flash 20.4% (267,269/1,310,720 bytes)
  (`firmware/README-SPIKE.md`), and desktop judge latencies down to the
  nanosecond (`tools/reflex/findings.json`: accept p50=40ns/p99=101ns).
- Crucially, it already runs the **exact problem exact-band exists to
  solve**, by hand, in ad hoc form: a 6-channel integer tolerance-band gate
  with a gray zone and a "dissent" flag for near-edge readings
  (`firmware/critic_gate.c`, `firmware/critic_gate.h`) — see §3 for the
  code. It is cross-validated between two independently-compiled
  implementations (desktop reference vs. ESP32-S3 metal) on 80 real
  critique vectors "harvested from the organism's runs"
  (`docs/REFLEX-ARC-2026-08-26.md`), reporting 480/480, 80/80, and 20/20
  agreement with a written pre-registration of expected divergence modes
  ("table inexpressiveness, band-edge rounding") that in fact produced zero
  divergences.
- Its own roadmap doc (`docs/VESSEL-FIT.md`) names the **next concrete
  step**: "AIS-in → rule table → alert LED" on a real fishing vessel
  (F/V EILEEN, Kodiak AK), using "haversine + relative-velocity in
  fixed-point micro-units — the critic-gate's integer discipline" — i.e.
  the author already intends to reuse this exact mechanism for marine
  proximity/collision alerting, not just music critique.

**What it still lacks, honestly:**

- The band gate proven on real hardware today judges **music-critique
  features** (`note_density`, `syncopation`, `register_spread`,
  `harmonic_tension`, ...) ported from a chat-agent project
  (`gate_qm.h`: "generated ... from critic-gate.qm — the mint's artifact",
  channel names have nothing to do with marine sensors). The marine
  application (AIS proximity, engine RPM/oil-pressure bands) is a
  documented plan, not yet built or flashed — `docs/VESSEL-FIT.md` §4 is
  explicitly "Next metalstone," future tense.
- It is genuinely **single-node**: today's proof is metal-vs-desktop-replay
  agreement on the same input stream over UART, not two physical ESP32
  boards independently reading real, noisy sensors and needing to agree
  with each other in the field. The "boat network sketch" (ESP-NOW between
  limbs, §2 of `docs/VESSEL-FIT.md`) is a diagram, not code — no ESP-NOW
  code exists in the repo (`grep -r "ESP-NOW\|esp_now" firmware/` matches
  only the prose sketch, not source).
- No real NMEA feed has been wired into this firmware yet — `firmware/nmea.c`
  (fixed-point parsing) exists and is host-tested, but `host_nmea/main.c` is
  a host harness, not a flashed-and-verified-on-board NMEA path the way
  blink and reflex-arc are.
- There is no boat, no salt air, no captain reading an LED yet. Everything
  is bench-verified on a desk, radio dark, with synthetic or ported (not
  marine) data.

## 3. Where exact-band would actually change behaviour

Three concrete sites, quoted, where a hand-rolled integer or float tolerance
decision is doing exactly what `exact-band`'s `Banded`/`Narrowed` (or its
zonotope agreement primitive) would do formally and generically:

**(a) `quilt-esp32/firmware/critic_gate.c` — the whole file is exact-band's
job, done by hand.**

```c
static int32_t clamp_to_edge_dist(int32_t v, int32_t lo, int32_t hi,
                                  int32_t *edge_out)
{
    int32_t dlo = v - lo; if (dlo < 0) dlo = -dlo;
    int32_t dhi = v - hi; if (dhi < 0) dhi = -dhi;
    if (dlo <= dhi) { *edge_out = lo; return dlo; }
    *edge_out = hi; return dhi;
}
...
    if (v < lo - amb || v > hi + amb) {
        *sev = GATE_SEV_BAD;   /* clear violation — past the gray zone */
    } else if (v < lo || v > hi) {
        *sev = GATE_SEV_WARN;  /* the gray zone — seam territory */
    } else {
        *sev = GATE_SEV_OK;    /* inclusive edges: v == lo/v == hi is ok */
    }
    *dist = clamp_to_edge_dist(v, lo, hi, edge);
    *dissent = (*dist <= GATE_QM_DISSENT_EPS || *gray) ? 1 : 0;
```
(`firmware/critic_gate.c:9-45`)

The header even states, unprompted, the exact motivation for exact integer
tolerance arithmetic that `exact-band` formalizes:

```
 * 1 µ = 1e-6, signed 32-bit — every number in the
 * pipeline (ear features rounded to 6dp, decimal bands, 0.06 gray zone,
 * 0.4/1.0 penalties) is EXACT on that grid; Q16.16 is not (0.06 and 0.763
 * are undyadic — ±2.4e-6 edge error). No float exists on this path, on
 * host or metal: host and firmware compile THIS file, so the replay
 * compares the same integer code the board runs.
```
(`firmware/critic_gate.h:5-11`)

This is a one-dimensional band-plus-epsilon-margin dissent test, per
channel, summed across 6 channels into a scalar penalty threshold — i.e.
exactly a 6-dimensional interval/zonotope membership-with-margin test,
implemented from scratch with a hand-picked `GATE_QM_DISSENT_EPS = 20000`
and `GATE_QM_AMBIGUITY = 60000` (`firmware/src/reflex/gate_qm.h:10,11`).
`exact-band`'s `Banded::narrow()` would replace `clamp_to_edge_dist` +
the three-way `if/else` with a single typed call, and would generalize
cleanly to the "two nodes must agree within a band" case this file does
not yet cover (today it is one reading vs. one fixed band, not node A's
reading vs. node B's reading).

**(b) `nmea-quilt-cell/nmea_quilt/views.py:53` — float angle wraparound and
sector bucketing at a boundary that can round differently across
platforms.**

```python
elif t == "MWV" and s.get("wind") and s["wind"].get("valid"):
    ang = float(s["wind"]["deg"]) % 360.0
    idx = int((ang + 11.25) // 22.5) % 16
    wind[idx] += 1
```

This buckets a wind angle into one of 16 compass sectors using float modulo
and float division at the sector boundary (multiples of 22.5°, offset by
11.25°). A value that lands exactly on a boundary — e.g. `ang == 11.25` —
is one ULP away from flipping sectors depending on how the float `%` and
`//` are evaluated on a given platform/compiler, which is precisely the
class of bug the repo's own byte-exact test (`tests/test_byte_exact.py`)
exists to catch by brute-force hashing rather than by construction.
`exact-band`'s integer machinery (fixed-point µ-degrees, as `quilt-esp32`
already does for heading/lat/lon — `firmware/nmea.c:35,98-106`) would make
this bucketing exact by construction instead of exact by test.

**(c) `federated-tinyml-vessel/quantize.py:130-131` — a tolerance check
that only proves quantization round-trip, not runtime agreement.**

```python
print(f"  weights match: {np.allclose(h.weights, h8.weights, atol=scales8[0])}")
print(f"  biases match: {np.allclose(h.biases, h8.biases, atol=scales8[1])}")
```

This is a self-check (does dequantized-int8 approximate the fp32 original)
rather than a two-node agreement decision, so `exact-band`'s zonotope
convergence result doesn't directly apply here today — but it is the
closest thing in `federated-tinyml-vessel` to a tolerance band, and if this
project ever ships a real aggregator receiving heads from independent
physical devices (as `aggregator.py` is architected to do), "did device A's
head and device B's head converge to the same global head" becomes exactly
the multi-node question exact-band's zonotope decides where interval
arithmetic cannot.

**Where there are none:** `mudra-vessel-bridge`'s tolerance-shaped code
(`src/mudra_autopilot.py:184`, `src/gamified_drills.py:479`) is all inside
simulator/training-drill code generating synthetic data for a human
operator to practice against — there is no cross-node or cross-substrate
agreement decision in that repo today for exact-band to replace.

## 4. Shortest credible path to a real deployment demonstrating the whole stack

Given the evidence above, the shortest path runs through `quilt-esp32`,
not `federated-tinyml-vessel` (despite it being the user-flagged scaling
target — the tinyml repo has no hardware story at all yet, while the ESP32
repo already has flashed boards, a build pipeline, and a proven exact
integer-band pattern).

1. **Port `exact-band`'s C port into `quilt-esp32/firmware/` as a drop-in
   replacement for `critic_gate.c`'s hand-rolled band/dissent logic**
   (`firmware/critic_gate.c:9-45`, `firmware/src/reflex/critic_gate.c`
   mirrors it). This is a same-file-count swap: one 2KB allocator-free C
   file already targets ESP32-class hardware, and the existing host/board
   split (`host_reflex/main.c` vs `src/reflex/reflex_main.cpp`) already
   proves the toolchain builds both host and xtensa targets from the same
   source. Verify byte-for-byte identical `R`/`Q`/`D` UART output before
   and after the swap using the existing 80-vector corpus
   (`tools/reflex/vectors.jsonl`) and the existing acceptance bar (480/480,
   80/80, 20/20 agreement, `tools/reflex/findings.json`).
2. **Execute the repo's own named next step**: wire a real NMEA-0183 AIS
   feed (`docs/VESSEL-FIT.md` §4) into a second ESP32-S3, using the
   already-host-tested fixed-point parser (`firmware/nmea.c:35-106`) plus
   `exact-band`'s zonotope to decide "is contact X's position/COG/SOG,
   independently computed from two overlapping AIS receptions, the same
   contact?" — this is the first place in the whole SuperInstance corpus
   where two independent physical readings of the same real-world quantity
   must be *decided* to agree, which is exact-band's actual differentiator
   over plain interval arithmetic.
3. **Flash two boards, not one**, and run them side by side reading the
   same AIS antenna feed (splitter) or two antennas — turning the existing
   single-node "metal vs. desktop-replay" agreement proof into a genuine
   two-node field agreement proof, on the F/V EILEEN research vessel
   (`docs/VESSEL-FIT.md` names this boat specifically, Kodiak AK) or any
   dockside boat with an existing AIS receiver, since AIS-in requires no
   new sensor procurement — only a UART tap.
4. **Only after that loop closes** does `federated-tinyml-vessel`'s
   simulated 5-device FedAvg become worth porting to real hardware: its
   own C port (`c_port/f170_head.c`) and INT4 quantization
   (`c_port/f170_head_int4.c`, "31 bytes, byte-exact" per its last commit
   message) are ready for the same host/xtensa split `quilt-esp32` already
   proved, but there is currently no audio corpus, no captured device data,
   and no flashed board anywhere in that repo — it would be starting the
   hardware bring-up process quilt-esp32 has already been through twice
   (blink, then reflex-arc).

The critical-path bottleneck is not exact-band (it is ready — byte-exact
across Rust/C99/Python already) and not the ESP32 toolchain (already
proven twice). It is that no SuperInstance repo has yet put a second
independent sensor reading of the same real-world quantity in front of two
nodes that must agree — everything "multi-node" in this survey is either
simulated (`federated-tinyml-vessel`), single-writer by design
(`nmea-quilt-cell`), or a metal-vs-fixed-reference replay rather than
node-vs-node (`quilt-esp32`, today). Closing AIS-in on `quilt-esp32` is the
single smallest step that turns exact-band's zonotope result from "provably
useful" into "the thing that decided something on a boat."
