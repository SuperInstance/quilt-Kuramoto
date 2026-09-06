# tminus-band

**Fire on what is known, not on how many said it.**

`swarm-tminus`'s `CountdownEvent` fires when `confirmed_count() >= quorum_required`
— a head-count. That treats three vague confirmations as better than one precise
one, which is backwards.

`BandedCountdown` fires when the accumulated **band** has narrowed past a target
width. Every confirmation carries an actual observation; observations intersect,
so agreement tightens the band and disagreement is recorded with its exact
magnitude instead of being dropped.

Stdlib only, matching `swarm-tminus`'s own doctrine. Integers all the way down:
no `float`, no `math.sqrt`, no rounding.

```python
from tminus_band import BandedCountdown, IBox

e = BandedCountdown("haul", IBox.centered([1000], 200),
                    target_width=20, min_reporters=2)

e.confirm("boat-a", IBox.centered([1005], 60))   # band: width 120
e.confirm("boat-b", IBox.centered([998],   8))   # band: width 16
e.ready()                                        # (True, 'known_enough')

e.confirm("boat-c", IBox.centered([1400],  5))   # disjoint
e.ready()                                        # (False, 'contradicted')
e.contradictions()[0].disagreement               # (0, 388)  axis, exact gap
```

## The divergence this exists to fix

```python
# Three subscribers confirm. Every one of them is nearly clueless.
for who in ("a", "b", "c"):
    bc.confirm(who, IBox.centered([1000], 400))

up.has_quorum()            # True  - upstream is satisfied, fires the event
bc.ready()                 # (False, 'band_too_wide')
bc.band.max_width()        # 800   - nobody actually knows when to fire
```

That case is a test (`test_the_divergence_this_exists_to_fix`), not a slogan.

## The firing rule

Firing requires **both**:

1. the band is at least as tight as `target_width`, **and**
2. at least `min_reporters` distinct subscribers have been accepted.

Condition 2 is a count, and yes, it is quorum returning through the back door —
deliberately. The difference is that quorum today is necessary *and sufficient*;
this floor is necessary and **never sufficient**. Five wide reports never fire;
two tight, mutually consistent ones fire fast.

The floor is not optional politeness. Exact intersection makes one
false-precision report unusually dangerous: a subscriber reporting
`IBox.point(p)` anywhere inside the current band collapses the width to zero,
and nothing in the geometry distinguishes an exactly-correct claim from a lie
that happens to be consistent with what we already believed. A contradiction is
caught for free; an over-confident consistent lie is invisible. Hence the floor.
(`test_one_confident_reporter_cannot_fire_alone`.)

## Contradictions are stronger than deferrals

Upstream's `DEFERRED` only ever grants *time* — it turns a would-be `MISSED`
into `COUNTING`, and only when quorum isn't already met. It never blocks a firing
that quorum earned.

A contradiction does the opposite: it **vetoes** firing even when width and
reporter conditions are met. `DEFERRED` says "not yet, ask me again."
`CONTRADICTED` says "what you think you know is wrong, by this much."

A contradicting observation is **not** folded into the band — intersecting a
disjoint box would empty it and destroy what was already known. It is recorded,
and it blocks firing until the band can accommodate it.

## The over-confidence trap, and the cure

Intersection only narrows. Over a long-running event the band converges to a
point and then rejects a later, *correct* observation.

`stale_widen_per_tick` is the least-machinery cure: the band forgets at a fixed
integer rate on ticks with no accepted report. No decay curve, no half-life, no
float. Off by default.

```python
e = BandedCountdown(..., stale_widen_per_tick=5)
# ... band converges to a point, then a correct observation contradicts it
for _ in range(3):
    e.tick()          # forgetting re-admits it
```

## Interop: two paths

**Today, with no upstream change.** The band rides in the existing free-form
`CountdownEvent.payload` dict, so `.swarm/*.event.json` stays loadable by
upstream's own `from_dict` and old readers ignore it:

```python
bc.attach_to(upstream_event)     # writes payload["banded"]
```

`attach_to` also mirrors the verdict onto the upstream event so count-based
tooling still sees something sensible: accepted reporters become `CONFIRMED`,
contradicting ones become `DEFERRED`.

**Properly, with a one-line upstream change.** In that mode upstream's own
`tick()` still fires on a head-count. `upstream/swarm-tminus-knowledge-gate.patch`
proposes adding the knowledge gate as an `OR` alongside quorum. It is inert when
`knowledge_band` is absent — which is every existing event and all 301 existing
tests.

## Cross-substrate conformance

This is a **port**, not an independent design. It is held to the Rust crate
[`exact-band`](https://github.com/SuperInstance/exact-band) by
`tests/vectors.json` — **240 golden vectors** emitted by
`exact-band/examples/emit_vectors.rs`, covering the covering-radius sweep
(including its negative control), `isqrt` to the `u128` extremes, Eisenstein and
`Z²` distances at the `i32` corners, ball narrowing, and box intersection.

If Python and Rust ever disagree, one is wrong — and having two substrates is
what makes the disagreement visible. This mirrors the ecosystem's existing
byte-exact discipline, where a cell state hash agrees across five language ports.

## Tests

23 tests, all running (none skipped):

- **6 conformance** — every one of the 240 Rust vectors reproduced exactly
- **12 semantics** — monotone narrowing, the Byzantine floor, contradiction
  veto, band preservation under contradiction, decay, lossless payload round-trip
- **5 live integration** — against the real installed `swarm-tminus`, including
  the divergence case above
- Plus a test asserting **no float ever reaches the serialised state**

## Not built, on purpose

- **No trust weighting or Bayesian fusion.** If a report shouldn't count, exclude
  it (boolean); don't down-weight it (continuous). Weights are floats wearing a hat.
- **No Byzantine detection or slashing.** `disagreement()` reports the axis and
  magnitude and stops. Reconciliation is application policy, and every detection
  heuristic is an unfalsifiable claim about adversary behaviour.
- **No configurable decay curve.** One integer widen rule. A pluggable strategy
  invites a float half-life "for realism."
- **`Banded` (the ball) is not in the firing path.** Balls are not closed under
  intersection, so ball-narrowing returns a sound enclosure rather than the true
  intersection. `IBox` is the only correct backend for a decision that fires real
  events; offering both interchangeably would let a caller silently pick the
  unsound one.
- **No cross-event DAG propagation** through `Campaign` yet. Real feature, separate
  proposal, waits until this has its tests green.

## License

MIT
