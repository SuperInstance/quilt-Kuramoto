# CHIP-MATRIX — every chip on the desk as a cell

**Lane:** chip-matrix · **Date:** 2026-08-29 · **Companions:** `EDGE-BENCH.md` (the night lane, same scorer), `TAP-FABRIC.md` (cell semantics), `tools/edgebench/edgebench.py` (the engine this tool reuses).

> **The question this document answers.** Casey's directive: run the edge experiments across ALL local silicon — the RTX 4050, the Ryzen AI 9 HX 370's CPU (and its NPU if honestly reachable), and anything else that actually works. Measure prompt and generation throughput on a fixed deterministic prompt set; then rerun a 100-round slice of the judgment-cell game on the top-3 models GPU-vs-CPU to test the hundred-boats question: **is CPU-only inference good enough to be a cell?**

## 1. Backends found (the probe)

| backend | live | evidence |
|---|---|---|
| `ollama-gpu` | **YES** | Ollama 0.32.15, default placement; NVIDIA GeForce RTX 4050 Laptop GPU, 6141 MiB, 595.79; /dev/dxg present |
| `ollama-cpu` | **YES** | Ollama with `num_gpu=0` — all layers on AMD Ryzen AI 9 HX 370 w/ Radeon 890M (24 threads) |
| `ort-cpu` | **YES** | onnxruntime 1.28.0, providers AzureExecutionProvider,CPUExecutionProvider |
| `ort-directml` | no | skipped honestly — pip rc=1: ERROR: No matching distribution found for onnxruntime-directml |
| `llama.cpp-vulkan` | no | skipped honestly — not attempted: no Vulkan SDK headers (/usr/include/vulkan); no cmake; no dzn (Vulkan-on-D3D12) ICD; mesa ICDs present (asahi_icd.json,gfxstream_vk_icd.json,intel_hasvk_icd.json,intel_icd.json,lvp_icd.json,nouveau_icd.json,radeon_icd.json,virtio_icd.json) cannot drive the paravirtual WSL GPU; no vulkaninfo to enumerate devices; apt locked (sudo needs a password); SDK/ICDs not installable from this shell |
| `hx370-xdna2-npu` | no | skipped honestly — no NPU device node or accel sysfs class in WSL (see §5) |

Vulkan gate detail: SDK headers absent, loader present, dzn ICD absent (mesa ICDs cannot drive the paravirtual WSL GPU), vulkaninfo absent, cmake absent, non-interactive sudo password-locked.

## 2. Throughput matrix (fixed prompt set, temperature 0)

5 short + 2 long deterministic prompts × model ladder × live backends. ptok/s = prompt eval, gtok/s = generation, medians; Ollama's own counters (load time excluded).

| model | gpu ptok/s (S/L) | gpu gtok/s (S/L) | cpu ptok/s (S/L) | cpu gtok/s (S/L) | cpu/gpu gen |
|---|---|---|---|---|---|
| `nano` (`qwen2.5:0.5b`) | 2990.8 / 8808.0 | 223.6 / 230.9 | 932.4 / 662.3 | 110.1 / 97.1 | 0.49× |
| `q3b` (`qwen2.5:3b`) | 1504.6 / 3054.7 | 84.4 / 78.1 | 226.8 / 148.2 | 31.7 / 27.0 | 0.38× |
| `wesley` (`granite3.1-dense:2b`) | 1957.0 / 3713.1 | 94.1 / 89.9 | 300.3 / 171.3 | 38.6 / 30.6 | 0.41× |
| `qwen3` (`qwen3:8b`) | 236.7 / 747.2 | 26.4 / 22.3 | 85.8 / 61.9 | 15.7 / 12.4 | 0.59× |
| `lfm` (`Liquid-LFM2.5-2.6B`) | 1045.3 / 3082.8 | 91.0 / 90.7 | 142.9 / 155.2 | 33.9 / 32.3 | 0.37× |
| `gpt2-124m-int8` (ort-cpu probe) | 201.7 / 794.0 | 20.9 / 16.2 | same lane | same lane | — |

ort-cpu lane note: greedy token loop WITH KV cache (merged graph: empty past [1,12,0,64] on the prompt pass, present.* fed back per step) on Xenova/gpt2 int8 (128 MB, HF hub); gpt2-124m is a throughput probe, not a cell candidate (it cannot follow the op schema).

Notes: ptok/s = prompt_eval_count/prompt_eval_duration; gtok/s = eval_count/eval_duration -- Ollama's own counters, load time excluded.; Prompts are unique per (model,lane) so prompt eval is cache-cold; the small shared system prefix may be cached after the warmup query.; gpu lane = Ollama default placement (no num_gpu override); cpu lane = num_gpu 0 (all layers on the HX370).

## 3. The cell experiment — GPU vs CPU, 100-round slice

Top-3 by cell-worthiness on the GPU lane (schema-probe parse rate ×2 + normalized bench speed): **`nano` (`qwen2.5:0.5b`), `wesley` (`granite3.1-dense:2b`), `lfm` (`Liquid-LFM2.5-2.6B`)** — criterion `2*schema-probe parse rate (4 turns, GPU lane, temp 0) + normalized bench gtok/s (short)`.

Same BenchFabric, same schema-strict `parse_op`, temperature 0 on both lanes. 3 pair-turns per round, one `qm_tick` per round; checkpoints every 20 rounds (`cells_*.quf`, QUF-verified).

GPU lane: 100 rounds (300 queries). CPU lane: 100 rounds (300 queries). Comparison window: first 100 rounds.

| lane | parse rate | op mix f/l/d | warmth end (range) | emergent fires | edges (seed 9) | Σwalks | med turn (s) |
|---|---|---|---|---|---|---|---|
| gpu | 100.0% (300/300) | 180/45/75 | +0.206 (-0.313..+0.360) | 25 | 9 | 7055 | 3.6 |
| cpu | 100.0% (300/300) | 184/40/76 | +0.261 (-0.175..+0.328) | 25 | 9 | 7119 | 2.6 |

**Why GPU turns are slow here (measured, `gpu_reload_probe.json`):** the GPU lane's eval runs at full speed (nano 210-276 tok/s in the slice), but Ollama's WSL/dxg runner keeps one model hot at a time — every model switch reloads weights through dxg (`load_duration` ≈3.5s): a nano burst runs 3.74s → 0.10s → 0.09s per turn, while nano→wesley→nano reloads on each switch. The alternating 3-cell pair pattern pays the reload on every query, so the CPU lane — whose runners stay resident in RAM — is end-to-end faster for small-model cell fleets at default settings. Single-model bursts on the GPU are the chip ceiling (~0.1s a nano turn); the reload is policy, not silicon.

Temperature-0 note: `lfm` answered every turn with the same op class (`fire` throughout) — deterministic sampling makes a satisfied cell a metronome; diversity at temp 0 comes only from state changes in the prompt (the night lane at temperature 0.7 sees richer op mixes).

| cell | gpu parse | gpu ops f/l/d | gpu med lat | cpu parse | cpu ops f/l/d | cpu med lat |
|---|---|---|---|---|---|---|
| `nano` | 100.0% | 40/0/60 | 3.6s | 100.0% | 47/0/53 | 1.1s |
| `wesley` | 100.0% | 40/45/15 | 4.0s | 100.0% | 37/40/23 | 4.4s |
| `lfm` | 100.0% | 100/0/0 | 4.0s | 100.0% | 100/0/0 | 3.5s |

```
gpu warmth +*+*:+:+:= =:=.-:+:+:+-+:+:+-=-+-#-+:=-+.+:=:=:+:=
```
```
cpu warmth +#-*:+ = - =:= =:+ =:=.=:+.=.=:+.+:+ =:+.=:+:+-+ =
```

### Verdict on the hundred-boats question

**YES — CPU-only inference is good enough to be a cell.** GPU parsed 100.0% vs CPU 100.0% (gap +0.0 pts); the CPU fabric grew Σwalks 7119 vs GPU 7055 and finished 100/100 rounds in the window; median cell turn 3.6s on GPU vs 2.6s on CPU — on this WSL/dxg setup the CPU lane is end-to-end FASTER for the small-model cell pattern (see the reload note above), and both sit far inside a 60-second judgment budget.

## 4. Boat doctrine — how many cells per chip

A cell turn is one judgment prompt (the fixed `turn_prompt`: room state, edges, recent events — a few hundred tokens) plus the op reply (measured medians ≈15 tokens; wesley runs to its num_predict cap, the others answer in 13-21). If each cell speaks once per round, a chip carries `round_budget / turn_latency` cells:

| carrier | turn (s) | cells @60s rounds | cells @300s rounds |
|---|---|---|---|
| `nano` on GPU (alternating fleet) | 3.6 | 17 | 83 |
| `nano` on CPU | 1.1 | 53 | 266 |
| `wesley` on GPU (alternating fleet) | 4.0 | 15 | 76 |
| `wesley` on CPU | 4.4 | 14 | 69 |
| `lfm` on GPU (alternating fleet) | 4.0 | 15 | 76 |
| `lfm` on CPU | 3.5 | 17 | 85 |
| `nano` on GPU, same-model burst (chip ceiling) | 0.09 | 667 | 3333 |

The alternating-fleet GPU numbers are the honest DEFAULT-policy numbers (one hot runner; ~3.5s dxg reload per model switch, §3); the burst row is the same chip with the runner kept hot. The Ollama daemon serializes queries per model-runner but runs different models' runners concurrently, and the GPU and CPU lanes are separate runners of the same tags — the desk's honest fleet is the **sum**: CPU boats (runners resident, no reload) + GPU boats (fastest for a dedicated single-model fleet or longer generations, cf. `qwen3:8b`'s 2× on GPU in §2) + the ort-cpu lane for schema-free work.

## 5. NPU honesty — the XDNA2 door is real but it is not this side of the glass

The Ryzen AI 9 HX 370 carries a 50-TOPS XDNA2 NPU. Probe evidence from this WSL session: NPU device nodes none, `/sys/class/accel` entries none — the NPU is **not exposed to WSL2**; the ryzen-ai stack (drivers, Vitis AI runtime, `onnxruntime-vitisai` / `ryzen-ai` wheels) is Windows-only, exactly like `onnxruntime-directml` (§1: no Linux wheels — verified by the failed pip install recorded in `probe.json`). Nothing here fakes it.

What a Windows-side runner would need to open the door:

1. Windows 11 23H2+ with the AMD XDNA2 NPU driver installed and the NPU enabled in Device Manager.
2. Ryzen AI Software 1.3+ (or ONNX Runtime ≥1.18 with the `VitisAIExecutionProvider` / `onnxruntime-vitisai` Windows wheels), Python on the Windows side.
3. Models as ONNX (int8/bf16) with Vitis-AI partitioning — the ladder's qwen2.5/granite class has export paths; or a Windows llama.cpp build with `-DGGML_RYZENAI=ON` (its Vitis-AI backend).
4. A small bridge: the runner answers the same judgment prompts over a local port this harness can curl; `chipmatrix.py` would grow one lane that talks to it. **This is the open door** — the same Windows runner also unlocks `onnxruntime-directml` for the Radeon 890M iGPU and the RTX 4050 dGPU in one step.

## 6. Reproduce

```
python3 tools/edgebench/chipmatrix.py --selftest
python3 tools/edgebench/chipmatrix.py --phase probe
python3 tools/edgebench/chipmatrix.py --phase bench   # ollama-gpu + ollama-cpu + ort-cpu lanes
python3 tools/edgebench/chipmatrix.py --phase cells   # top-3 x {gpu,cpu}, 100 rounds, checkpoints
python3 tools/edgebench/chipmatrix.py --phase report   # regenerates this document
python3 tools/quf.py verify tools/edgebench/chipmatrix_runs/cells_gpu.quf
```

Artifacts: `chipmatrix_runs/probe.json` (backend evidence), `bench.jsonl`/`bench.json` (every bench query + summary), `top3.json` (selection), `cells_{gpu,cpu}.jsonl` (every judgment query), `cells_{gpu,cpu}_state.json`, `cells_{gpu,cpu}.quf` (QUF-verified fabric snapshots), `gpt2-onnx/` (download cache, git-ignored).

*Every chip measured where it honestly stands; the boats that float are counted, the doors that are shut are named.*
