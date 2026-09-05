# Scaling `federated-tinyml-vessel`

Read at source. Separating what is measured from what is claimed, because the
gap here is wide and it changes what "scaling" means.

## What it is

```
audio 16kHz 1s → log-mel (60) → MFCC+Δ+ΔΔ → mean/std/max (180-dim)
  → linear 180→64   [FROZEN BACKBONE, 12,544 params, 50 KB]
  → L2 norm → 64-dim embedding
  → linear 64→5     [TRAINABLE HEAD, 325 params, 1.3 KB]  ← the only thing that learns
  → softmax
```

The backbone is calibrated once by PCA and pushed to every device; devices never
update it. Only the 64×5 head trains locally, plain SGD — no momentum, no Adam,
because "the memory budget on a Cortex-M33 doesn't allow it." That is a good
design.

## Measured vs claimed — the load-bearing distinction

| | Number | Status |
|---|---|---|
| Accuracy, synthetic audio | 95–100% across 6 configs | **measured** — but the audio is sine waves and coloured noise from `simulator.py` |
| **Accuracy, real audio (ESC-50)** | **52.5%** | **measured** — 200 files, 5 classes, 20% random baseline. *This is the number that matters.* |
| Accuracy, Whisper backbone | 26.7% | measured — worse than hand-crafted |
| Robust aggregation under 1/6 adversary | Trimmed Mean 28% vs FedAvg 20% | measured — but 28% is barely above the 20% chance floor |
| FNV-1a state hash across Python/JS/C/Rust | `0x5fd69fcc4833d9fc` | **measured, byte-identical across 4 substrates** — genuinely good work |
| int4 quantised head | 173 bytes, no synthetic accuracy loss | measured — **but not used on the wire** |
| Max devices ever run | **10** | measured — sequentially, inside one Python process |
| "<100 ms wire latency", "0.3 ms ESP32 inference" | — | **claimed, no benchmark artifact** |
| On-device training on real hardware | — | **never run.** The paper says so: *"we haven't actually run training on an ESP32."* |

The authors already named the gap themselves:

> *"Federated scheduling: 5 simulated devices is fine. 100 devices across 10
> vessels with intermittent connectivity needs a more sophisticated aggregator."*

## What breaks first, in order

1. **Round synchronisation — breaks first, and silently.**
   `maybe_fedavg()` fires on a hardcoded `>= 3` devices. At 1000 devices that
   means 997 stragglers are ignored every round, destroying the data diversity
   the whole scheme exists for. Worse: `device_client.py` hardcodes `round=0` in
   every upload, so the round number is never actually validated. There is **no
   round deadline at all** — a round hangs forever if fewer than 3 ever submit.
   *Fix:* quorum as `min(N, ceil(P · fleet_size))`, a real round id echoed in
   both directions and validated, and an explicit deadline — close on quorum or
   on timeout, marked partial.

2. **Version skew — breaks silently and corrupts the model.**
   Nothing tags a head with which backbone produced it. `heterogeneous_backbone.py`
   proves three *different* backbones can share one head — which means during a
   staggered firmware rollout FedAvg will happily average semantically
   incompatible heads and nothing will complain.
   *Fix:* tag every upload with the backbone's state hash; bucket or reject
   mismatches. The hash function already exists.

3. **Wire format — pure waste, already solved and unused.**
   The 1.3 KB figure is the raw binary `to_bytes()`. The actual wire payload is
   JSON with full-precision float arrays — several times larger. Meanwhile
   `quantize.py` and `c_port/f170_head_int4.c` already produce a **173-byte**
   int4 packing with no measured accuracy loss.
   *Fix:* ship the bytes you already know how to make. This is a config change,
   not a project.

4. **Aggregation topology.** Single-process `ThreadingMixIn` HTTP server, all
   state in one in-memory dict, no persistence — a crash loses the round.
   *Fix:* hierarchical — per-vessel aggregator, then a fleet-level aggregator of
   aggregators.

5. **Non-IID data.** Actually the *best*-covered bottleneck: `non_iid_split()`
   with Dirichlet α, tested to α=0.3, plus Trimmed Mean / Coordinate Median /
   Krum in `robust_aggregator.py`. But only to 10 devices, and the robust
   aggregators measure 28%.
   *Fix:* per-fishing-ground sub-federations that average locally, then a slower
   cross-cluster merge.

## Reuse instead of rebuild — with honest caveats

- **`quilt-mesh` as transport.** `CellEvent { cell, value: Vec<u8>, author, lamport }`
  is generic bytes, so a serialised head goes in directly, replacing `POST /head`
  with peer gossip. That gets you offline-first behaviour, which is the actual
  deployment story — a vessel 50 nm out keeps training and syncs when it meets
  another boat.
  **Caveat, and it matters:** quilt-mesh resolves conflicts last-writer-wins by
  Lamport timestamp on a single value. **It does not average.** `CellState.apply()`
  keeps the highest-Lamport head, i.e. the *last* one seen, not a merge. You would
  run `average_heads()` as an application-level reducer over accumulated events.
  Also, its own README says it is *"a design sketch. The real implementation will
  be 4-5x this size."*
- **`MerkleMesh` for contribution audit.** Each device emits its upload as a quilt
  ledger entry (round, device_id, head state-hash, samples_seen — the FNV-1a hash
  already exists), `merklemesh aggregate` folds all vessels into one root per
  round, and `merklemesh prove` lets any vessel later prove its contribution was
  included unaltered. Tamper-evidence without a trusted central log. Additive to
  quilt-mesh, not a substitute: one moves bytes, the other audits them.
- **`t-minus` / `swarm-tminus` for round timing.** `swarm-tminus`'s
  `CountdownEvent` — `quorum_required`, `has_quorum()`, and a FIRED/MISSED
  transition on a deadline — is *exactly* the missing piece in `maybe_fedavg()`.
  This is the highest-value, lowest-effort reuse on the list: it replaces a
  hardcoded `< 3` with a tested quorum-and-deadline state machine.

## The honest headline

The scaling problem is real but it is not the first problem. **52.5% on real
audio is.** Scaling a 52.5% classifier to a thousand devices produces a
thousand devices that are wrong half the time. Fix the round protocol and the
version tagging because they are cheap and they are silently corrupting; but the
backbone is where the accuracy is, and no amount of federation fixes it.
