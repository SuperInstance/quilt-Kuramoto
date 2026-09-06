# THE-TICK — what happens in one tick, numbers flowing left to right

*The trace the Teacher asked for: one paragraph in the README can't carry
this; one honest walk through the RTL can. Everything below is grounded
in `rtl/q_cell_core.v`, `rtl/q_hebb_edge.v`, `rtl/q_tick_sched.v` —
state names are the RTL's own. Written 2026-08-29.*

## The core loop in one paragraph

A quilt is a ring of cells. Five opcodes are the only way anything
touches anything: bind (name me / write a dial), link (wire an edge slot
to a peer), effect (send activation into a peer's edge), view (read
state back), tick (time passes). Effects accumulate in a cell's `act`
register; ticks decay them. An edge is not a wire — it's a tiny learned
weight bank living in the receiving cell (`q_hebb_edge`), bumped by
cofires, decayed by ticks. When `act` crosses the cell's threshold, the
cell *fires*: it resets to zero, goes quiet for a refractory period, and
fans an effect out to every linked peer. That fire→integrate→
fire cascade is the entire computation; everything else is bookkeeping
for it.

## One tick, step by step

Setup for the walk: cell 7 is bound, linked to peers 3 and 9 (edge slots
0 and 1 valid), `act = 0x2140`, threshold dial = `0x3800`, ladder engine
(K=4 buckets, B=8 bits, half-life counter = 2 of 4), `refr = 0`. The
tick scheduler (`q_tick_sched`) has been free-running since POR: every
2^TPW cycles its counter wraps and `o_tick` strobes **one** cycle.

1. **The strobe latches, wherever the cell is.** `s_tick` sets
   `tick_pend` from *any* state — mid-effect, mid-view, doesn't matter
   (the Q2 interlock). Time is non-deferrable.

2. **Tick wins the next idle slot.** At the next `ST_IDLE`, the FSM
   checks `tick_pend` *first*: `ci_ready` drops (no new ingress flit is
   accepted this cycle — the formal proof `cell_core.tick` pins the
   "deferred by at most one in-flight op, never dropped" contract) and
   the state machine enters `ST_TICK`.

3. **Decay sweep, edge by edge** (`ST_TSW`/`ST_TSWW`). One at a time,
   each *valid* edge slot is selected into its `q_hebb_edge` with
   command `010` — *advance decay one tick*:
   - **Ladder engine:** `hl_cnt++`. It counts to the half-life; on the
     4th tick here, the buckets shift right one position
     (`c[3]←c[2], c[2]←c[1], c[1]←c[0], c[0]←0`) — that shift *is* the
     power law. A bump that landed in bucket 0 four ticks ago now
     contributes half of what it did.
   - **Hyperbola engine:** `age++`; every time `age` reaches the
     interval threshold, `wh−−` and `age` resets — weight decays like
     1/age, slower the older it gets. (`age` is AGEW bits; it wraps at
     2^24 — a documented bound, see BACKEND-NOTES.)

4. **Leak the activation** (`ST_TLEAK`). Back in the core:
   `act ← act − (act >>> ka)` — a shift, no multiplier. With
   `act = 0x2140` and `ka = 6`: `0x2140 − 0x85 = 0x20BB`.

5. **Fire test, same cycle.** Is the leaked `act ≥ threshold` and
   `refr == 0`? `0x20BC < 0x3800` — no fire this tick. The cell drops
   `ci_ready` back up and returns to `ST_IDLE`. Had it crossed: `afire`
   latches the pre-reset act, `refr ← d_refr`, and the FSM enters
   `ST_FIRE`.

6. **Firing: fanout** (`ST_FIRE`). For every valid edge slot, one
   `OP_EFF` flit leaves the low egress port: `dst = peer, src = 7,
   dat = afire`. When the last slot is served, `act ← 0` — a fire is a
   total reset, not a decay. The cell then stays deaf (`refr` counts
   down each tick) until the refractory dial expires.

7. **The peers receive.** Peer 3's dispatch FSM sees the effect flit,
   scans *its* edge table for `src == 7`, finds slot 2, and:
   - reads the edge's current weight (command `011`, K+1 sequenced
     cycles — the buckets are summed shift-add style),
   - integrates: `act ← sat16(act + (w × dat) >>> 15)` — a 16×16
     multiply, product shifted to Q1.15; with `w = 0x0300` and
     `dat = 0x3800` that's `act += 0x0150`,
   - and, if peer 3 *also* fired recently (the v2 echo gate), issues the
     graded cofire train (`101`): a +1 bump into a recency bucket —
     bucket 0 for a fresh cofire, deeper buckets the staler the cell's
     own fire. That +1 in bucket 0 is worth exactly 256 in weight units
     at readout; that is the Hebbian increment, all of it.

8. **Reading it back.** At any point, `view` flits interrogate the
   state: `a0=0` returns `act`; `a0=1` sweeps every edge and returns the
   saturating weight sum; `a0=2` returns dial `a1`. (A third view,
   `a0=3` — the cosine readout — is reserved and NAKs in v1; see below.)

One tick, end to end: **strobe → latch → decay every edge → leak →
fire-test → (fanout | resume)**. No DRAM, no instruction fetch: every
number above moved through a register on one clock edge.

## Honesty notes

- **Where is the cosine/vMF?** README Law 3 names it; the v1 RTL
  implements the *substrate* it is estimated from — an edge's
  bucket/weight bank is an unnormalized dot-product accumulator over the
  cofire history, and the cosine/vMF reading (normalize it) is the
  statistical interpretation carried in `docs/academic/` and
  `sim/tools/tapfabric.py`. The dedicated readout (`view a0=3`) is
  reserved and NAKs in v1. The claim in the Law was phrased one notch
  stronger than v1 silicon; it is corrected there.
- **Why the wsum view saturates:** edge weights are 16-bit and there are
  up to EDGES_N of them; `view(1)` sums into PW+EIW+1 bits and pins at
  `0xFFFF` rather than wrapping (this register's width was a real bug —
  found by cosim, see BACKEND-NOTES).
- **Serialization is one legal choice.** The sweep order (slot 0 first)
  is this RTL's pick; the Python model's tick ordering is defined to
  match bit-for-bit, and the differential cosim (`tools/backend/
  cosim_cell.py`) proves the match on 22k+ checkpoints. Any reordering
  that keeps the per-edge math identical is observationally equivalent
  *at tick boundaries* — that's the lemma the cosim leans on.

## Where to go next

- The math beneath this walk: `docs/FOUNDATION.md` (cell axioms).
- The container that boots this state into silicon: `docs/QUF-SPEC.md`.
- How any of the above is *proven*: `docs/VERIFICATION.md`, then
  `docs/academic/THE-BREAKDOWN.md` (the dossier, failures first-class).
- The full map: `docs/INDEX.md` — now with a suggested reading order.
