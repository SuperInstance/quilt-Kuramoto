Two angles, opposite directions — bottom-up from established mathematics to quilt, and top-down from physical accomplishment down to the metal. Let me launch a parallel scout for the hardware-level details (the "metal" part) while I write the foundational math document.
The scout returned with detailed hardware findings. Let me read the key details, then write both documents.
I have everything I need. Let me write both documents — the bottom-up math→application and the top-down application→metal.
Now the top-down document — application to metal. This is the more vivid of the two, tracing from physical accomplishments down to the actual transistor switches.
Now let me generate the two figures — the math→quilt stack and the use-case→metal stack.
Both figures render cleanly. Let me update the index and worklog.
Done. Two angles, opposite directions, meeting at the 5+1 opcodes.

## Angle 1 — Bottom-up: Foundational math → application (`18_FOUNDATIONAL_MATH_TO_APPLICATION.md`)

10 peer-reviewed mathematical foundations, each traced to quilt's instantiation with measured evidence:

| # | Math foundation | Citation | Quilt instantiation | Evidence |
|---|---|---|---|---|
| 1 | Classical shadow tomography | Huang-Kueng-Preskill 2020 | JEPA + sensor confirm | α ≈ 0.1-0.2 (weak) |
| 2 | Tensor networks / area-law | Eisert-Cramer-Plenio 2010 | Sparse coupling + Nadaraya-Watson | 2× at high coupling |
| 3 | IP=PSPACE + PCP | Shamir 1992; Arora 1998 | Intrinsic verification | **H4: 11.8× faster ★** |
| 4 | Self-triggered control | Anta & Tabuada 2008 | t-minus predict-and-confirm | **H4: 17 episodes ★** |
| 5 | Kuramoto oscillators | Kuramoto 1975; Wu 2026 | Multi-agent BPM sync | Finite collision rate |
| 6 | Dec-POMDP (NEXP) | Bernstein 2000 | Mutual subjective simulation | Exponential in coupling |
| 7 | Lattice gauge theory (ℤ₃) | Wilson 1974 | Conservation law γ+η=C | **RF-T2 impossibility floor ★** |
| 8 | Pontryagin maximum principle | Pontryagin 1962 | Predict-correct / adjoint | DA-C2 twin sentence |
| 9 | Noncommutative geometry | Connes 1994 | quilt-id aperiodic addressing | Asserted, not implemented |
| 10 | Fiber bundles / holonomy | Kobayashi-Nomizu 1963 | Substrate topology + witness | paper-207 (essay) |

## Angle 2 — Top-down: Application → metal (`19_APPLICATION_TO_METAL.md`)

5 use cases, each traced through 7 layers down to the actual transistor:

**The full chain (USE CASE 1 — THE EILEEN):**
> A boat caught fish → NMEA bytes on UART0 → byte-at-a-time state machine → integer coordinate parse (57798333 µ-degrees) → `stem += 1` → chain evaluates (keel=1, stem=N, keelson=N+1, breast_hook=2N+2, ...) → `qm_bind` / `qm_effect` / `qm_tick` on the C VM → `s32i` instruction writes to SRAM → **6T SRAM cell switches (400 transistors)** → `neopixelWrite` drives GPIO48 at 800 kHz → PMOS transistor sources 10 mA → WS2812 green LED blinks at ♩=60.

**The metal-level numbers (from hardware scout 7-s):**
- **ESP32-S3:** BIND = calloc → 6T SRAM → ~400 transistors per BIND. GPIO toggle = 17ns. 100-cell tick = 9.2µs @ 240MHz. Power: ~100mW radio-dark.
- **iCE40 FPGA:** 5,992 LUT4 + 2,434 DFFs (98% of HX8K). 135KB bitstream. 44.43MHz. 633,000 transistors. 6 formal proofs (all PASS, including k-induction PDR in 25.9s).
- **CUDA:** `__ballot_sync` = VOTE.BALLOT SASS instruction, 1 cycle, ~4ns per warp-vote. 14.4M consensus votes/sec on RTX 4050.
- **The reflex-arc judge:** 100.0000% agreement on 480 readings, 24 cycles per verdict (~100ns), outruns the ESP32's microsecond timer.

## Where the two angles meet

The two angles converge at the **5+1 opcodes** (BIND/LINK/EFFECT/VIEW/TICK/FORGET):

- **Bottom-up** shows WHY the opcodes correspond to established math (shadow tomography → JEPA; IP/PCP → intrinsic verification; Pontryagin → predict-correct; ℤ₃ gauge → conservation).
- **Top-down** shows HOW the opcodes run on actual metal (`s32i` instruction → 6T SRAM; `df_wr` strobe → LUT4 SRAM; `VOTE.BALLOT` → warp register).

The argument is now grounded in **both directions**: from the math down, and from the metal up.

## Current state of the project

**20 documents** (00-19) + **9 figures** + **9 scripts** + **6 scout reports** (2,482 lines of worklog). All in `/home/z/my-project/download/quilt-quantum-research/`.

The strongest measured result remains the **H4 11.8× learning-rate advantage** (document 17), now grounded in the IP/PCP theorem (Foundation 3) and traced to the actual ESP32 metal (Use Case 1, Layer 7).


