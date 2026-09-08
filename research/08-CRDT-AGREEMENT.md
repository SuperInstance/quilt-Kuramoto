# 08 — CRDT agreement: does exact-band compose with SuperInstance's distributed-state work?

Scout pass over ten SuperInstance repos, cloned shallow to
`/tmp/claude-0/scouts/crdt/<repo>`. Two repos carry the actual CRDT / gossip
code (`SmartCRDT`, `AgentGossip`); the other eight (`quilt-swarm`,
`cell-runtime`, `quilt-cell-router`, `lucineer-system`, `lucineer-relay`,
`fleet-radio`, `quicunnel`, `mudra-bridge-core`) were checked and are
orthogonal — Docker Swarm control plane, a single-process cell physics
library, a QUIC tunnel, a gesture vocabulary, a podcast pipeline, and a
Cloudflare Durable Object job queue. None merge distributed numeric state.
They aren't discussed further except where noted.

All file:line references are against the shallow-clone paths above unless
stated otherwise.

---

## 1. What is SmartCRDT actually?

It's a real, small CRDT library, reimplemented three times (TypeScript, Rust
native module, Python wrapper over the Rust module via PyO3), plus one
integration test that references a fourth implementation that **does not
exist** in the checkout.

**Types implemented**, all in
`packages/fleet-collab/src/crdt-primitives.ts`:

- `GCounter` (grow-only counter, per-node max-merge) — lines 21-69
- `PNCounter` (increment/decrement, two G-Counters) — lines 81-144
- `LWWRegister<T>` (last-writer-wins, timestamp + node-id tiebreak) — lines 157-216
- `ORSet<T>` (observed-remove set, tag/tombstone) — lines 230-349
- `LWWMap` (map of LWW-Registers) — lines 361-450

The same five types are re-implemented in Rust at
`native/crdt/src/{gcounter,pncounter,register,orset}.rs`, exposed to Python
through `python/superinstance/crdt.py` (a thin wrapper over `PyGCounter` etc.,
`python/superinstance/crdt.py:1-100`), and again as a WASM binding
(`packages/wasm/src/crdt.ts:1-100`). `MetricsAggregator`
(`packages/fleet-collab/src/metrics.ts`) and `FleetCollabStore`
(`packages/fleet-collab/src/crdt-store.ts`) compose these primitives; neither
adds a new merge law of its own — `crdt-store.ts:49-69`'s unified `merge()`
just calls each sub-component's `merge()` in sequence.

**Are the merge laws tested?** Real answer, split by substrate:

- **Rust: yes, explicitly**, but only for `GCounter`. `native/crdt/src/merge.rs`
  defines a `Merge` trait whose doc comment states the three laws
  (`merge.rs:9-12`: "Commutative... Associative... Idempotent") and the test
  module below it (`merge.rs`, `#[cfg(test)] mod tests`) has
  `test_merge_trait_commutative`, `test_merge_trait_associative`, and
  `test_merge_trait_idempotent` — each one actually merges two or three
  `GCounter`s in both orders/groupings and asserts equality. This is a genuine
  algebraic test, not a comment. `PNCounter`, `LWWRegister`, `ORSet` all
  implement the same `Merge` trait (`merge.rs`, the three `impl Merge for
  super::X` blocks right below the trait) but have **no** commutativity/
  associativity/idempotence test of their own — only the example-based unit
  tests below.
- **TypeScript: no property tests, only example-based unit tests.**
  `packages/fleet-collab/src/__tests__/crdt-primitives.test.ts` has one test
  per type covering merge behavior with concrete inputs (e.g. `'should merge
  correctly taking max per node'`, lines 38-49; `'should handle concurrent
  add-remove (add wins)'`, lines 212-224). None of these assert `a.merge(b) ==
  b.merge(a)` or run three-way associativity. The only place the word
  "commutative" appears outside `merge.rs` is a **comment**, not a test:
  `packages/fleet-collab/src/crdt-primitives.ts:45` — `"Merge takes max per
  node — commutative, associative, idempotent"` — asserted, not verified, at
  that call site.
- **Python: no tests found for CRDT merge laws** — `python/tests/test_crdt.py`
  and `tests/test_crdt.py` exist but weren't inspected line-by-line here
  beyond confirming they wrap the same Rust primitives (no independent Python
  merge logic exists to test).

**A concrete finding on test integrity**: the integration test
`packages/integration-tests/src/crdt-integration.test.ts:1-33` claims to
verify `CRDTStore` from `@lsi/swarm` — including a test literally named
`'should use addition for merging counters (not Math.max)'` (line 15) that
would, if it ran against a real implementation, describe a G-Counter merge
that is **not idempotent** (summing raw totals instead of taking a per-node
max double-counts on re-merge). But `@lsi/swarm` resolves, in this checkout,
only to an ambient type declaration —
`packages/integration-tests/src/@types/swarm.d.ts:1-16` — declaring
`CRDTStoreImpl` with `any`-typed methods and no method bodies. `grep -rln
"CRDTStoreImpl"` across the whole repo returns only that one `.d.ts` file;
`packages/swarm/src/` has no `crdt/` directory at all (confirmed by
directory listing). **I did not execute this test** (no build was attempted),
so I cannot claim it fails at runtime — but the implementation it purports to
test does not exist in the source tree, which is a strong scaffold signal on
its own regardless of runtime behavior.

**Verdict for Q1**: SmartCRDT's Rust core is a real, if small, CRDT
implementation with one genuinely-tested algebraic law (G-Counter's three
properties). The TypeScript and Python layers are faithful ports/wrappers but
carry only example tests, not property tests, for the other four types. One
integration test in the suite targets a CRDT implementation that isn't
present in the repository.

---

## 2. Floats in merge paths — the sharpest possible finding, searched for and NOT found

Searched every CRDT source directory in the repo (`packages/fleet-collab/src`,
`packages/wasm/src`, `native/crdt/src`, `native/ffi/src`,
`python/superinstance/crdt.py`) for averaging, weighted merge, or any
numeric-with-tolerance merge:

```
grep -rniI "average|mean(|confidence.*merge|merge.*confidence|position.*merge" \
  packages/fleet-collab/src packages/wasm/src native/crdt/src native/ffi/src python/superinstance
```

produced only unrelated hits (a "microseconds per operation, averaged" comment
in an HNSW benchmark file, and `np.mean` in an unrelated embeddings module —
neither in a CRDT merge path).

Type-level check: Rust counters store `u64`/`i64`
(`native/crdt/src/gcounter.rs:13`, `pncounter.rs:14-17`) — exact integers,
`saturating_add`, no floats anywhere in the merge path. The TypeScript layer
uses JS `number` (always an IEEE-754 double) for the `amount` parameter
(`crdt-primitives.ts:24`, `:85`), so a caller *could* pass a fractional
`amount`, but the merge operator itself is `Math.max` (`crdt-primitives.ts:49`,
`:120,123`) — and `Math.max` is commutative and associative for any finite
float pair, so even a float-valued G-Counter/PN-Counter would still converge
to the same value regardless of merge order (NaN inputs are the only
pathology, and nothing here produces NaN). `LWWRegister<T>`'s value can be
any type `T`, including a float, but the merge selects a winner by
**timestamp**, not by combining values (`crdt-primitives.ts:189-200`) — so
merge order doesn't perturb the chosen value either.

**Verdict for Q2**: not present. No CRDT type in SmartCRDT averages,
interpolates, or otherwise numerically combines float state across replicas.
Every merge operator found (max, LWW-by-timestamp, tag-set union) is exact
and order-independent even where the underlying storage type is a JS
`number`. This is a genuine negative result, not an "I couldn't verify" —
the search covered every merge-bearing file in every substrate the repo
ships. Distinct from "orthogonal domain that happens not to need this" —
SmartCRDT's own docs (`docs/adr/005-crdt-for-knowledge.md`) pitch it as
general-purpose distributed state, so the absence of a numeric-average CRDT
type is a real design choice/gap, not an out-of-scope one.

---

## 3. AgentGossip: hash-chained journal, canonical JSON, SHA-256 receipts, no tests

Both halves of the report check out, with one important qualification on
"canonical."

**Hash chain — real, and it matches the reported description.**
`src/ledger.ts` implements `CellLedger`, a TypeScript port explicitly noted as
mirroring a Rust original (`ledger.ts:1-18`, "TypeScript port of the
quilt-rust hash-chained, double-entry cell ledger"). Every entry seals over
its own body plus `prev_hash` (`ledger.ts:281-283`, `sealEntry`), the chain
root commits to cell identity and genesis state (`ledger.ts:287-296`,
`genesisCommit`), and `verifyChain` (`ledger.ts:310-328`) walks the whole
chain recomputing every seal and rejecting on the first mismatch. SHA-256 is
`node:crypto` (`ledger.ts:20,32-34`) — real, standard, not a toy hash.

**Canonical JSON — real, but self-admittedly not bijective the way
exact-band's wire format is.** `writeCanonical`
(`ledger.ts:61-94`) sorts object keys and renders compactly, matching the
"canonical" half of the claim. But the crate's own docstring
(`ledger.ts:43-53`) states the honest limit:

> "Number semantics (honest divergence, documented): JS numbers are all
> doubles. Integer-valued numbers (within ±2^53) render as integers —
> matching serde_json for int inputs. Non-integers render shortest
> round-trip decimal... **Fixtures stay in the exact range where this
> matches quilt-rust bit-for-bit.**"

That is a materially weaker property than exact-band's `WIRE-FORMAT.md`
claim that "hashing the bytes equals hashing the value" for **every** value
in the space. AgentGossip's canonical JSON is canonical only inside a range
its authors have pinned by fixture, not by construction — two honest
implementations (say, this TypeScript port and the Rust original it mirrors)
are only guaranteed to agree where JS's `Number.prototype.toString()`
shortest-round-trip and Rust `serde_json`'s float formatter happen to concur,
which is not proven here, only asserted by comment and (per the doc) checked
against a fixture range rather than swept exhaustively. This is exactly the
CBOR/Protobuf-style near-canonicality that exact-band's `WIRE-FORMAT.md`
explicitly built varint+delta-id rules to avoid.

**Mint receipts — real, and match the description.** `src/receipt.ts`:
`journalBytes` (`:48-50`) takes the canonical bytes of a full journal,
`mintReceipt` (`:52-55`) SHA-256's them, `verifyReceipt` (`:63-65`) recomputes
and compares. `GossipPacket` (`:29-44`) carries exactly `{boat_id, cell_id,
receipt_sha, chain_head, ts, tier}` as reported.

**No tests — confirmed.** `find . -iname '*test*'` inside the AgentGossip
checkout returns nothing. `package.json` declares `"test": "vitest run"`
(package.json, scripts block) but there is no test file for it to run, and no
`vitest.config.ts`. Also worth noting: `package.json` points `"bin":
{"agentgossip": "bin/agentgossip.js"}` and a `"cli"` script at `src/cli.ts` —
**neither file exists** in the checkout. The `original/` directory
(`original/agentgossip.ts`) is generic scaffolding (a `class AgentGossip`
with an `execute()`/`process()` stub, no gossip logic at all) explicitly
called out in the README as "the upstream stub... preserved" (README.md,
"Status" section) — i.e. the authors themselves flag it as filler, distinct
from "the real engine" in `src/`.

**Verdict for Q3**: both halves of the report are true. Add: the "canonical"
claim is real but narrower than exact-band's bijective guarantee (pinned by
fixture range, not proven exhaustively), and the package additionally has no
working CLI/binary entry point despite `package.json` declaring one — so even
setting tests aside, nothing in this checkout currently drives an actual
gossip round end-to-end.

---

## 4. Multi-node: real, or in-process objects?

Mixed, and the mix matters for the synthesis.

- **SmartCRDT is in-process by default, with one real network path.** Every
  CRDT merge test and every example calls `.merge()` directly on two objects
  living in the same process/test. But `packages/fleet-collab/src/api.ts`
  stands up a real `node:http` server (`api.ts:33`, `createServer`) exposing
  a `POST /merge` endpoint (api.ts doc comment, line 27) that accepts another
  replica's exported state — so cross-process/cross-host merge is genuinely
  wired, just not exercised by the CRDT algebra tests themselves (those all
  stay in-process). This is a real but thin multi-node story: one HTTP call,
  no membership/anti-entropy loop of its own.
- **AgentGossip has real multi-node transport, unused by anything running.**
  `src/transport.ts` implements three `Transport`s: `InMemoryTransport` (a
  `MailHub` — genuinely in-process, explicitly "tests use it,"
  `transport.ts:17-19`), `DirTransport` (real filesystem inboxes with
  atomic tmp+rename writes, for CI/demo, `transport.ts:169-244`), and
  `UdpTransport` (real `node:dgram` sockets with datagram chunking/
  reassembly for payloads over one MTU, `transport.ts:246-310`). The UDP
  transport is genuine cross-process, cross-host networking code — not a
  simulation. But as noted in §3, there is no orchestrator file (no
  `gossip.ts`, no working `cli.ts`) that actually drives a digest → pull →
  journals round using these transports, and no tests exercise any of the
  three. So the multi-node *plumbing* is real; the multi-node *protocol
  loop* that would use it is not present in this checkout.
- **The other eight repos are not multi-node CRDT systems at all.**
  `cell-runtime` is an explicitly single-process Python library (`Cell`
  objects with local GC/heartbeat/physics state,
  `src/cell_runtime.py:120-183` — its "merge" is intra-process duplicate-
  output collapsing during GC, not a distributed merge). `quilt-swarm`
  delegates actual cluster consensus to Docker Swarm itself, contributing no
  CRDT of its own. The rest (`lucineer-relay`, `fleet-radio`, `quicunnel`,
  `mudra-bridge-core`, `quilt-cell-router`) have no CRDT or convergence code
  at all.

**Verdict for Q4**: real multi-node code exists (SmartCRDT's HTTP `/merge`
endpoint; AgentGossip's UDP transport), but in both repos it is
disconnected from anything that runs an actual multi-round convergence
protocol against it in this checkout — no test, demo, or CLI drives more
than a single-hop, manually-triggered merge across a real network boundary.
Everything that is actually *exercised* (by a test or example) is in-process.

---

## Synthesis: composes, and is not redundant

**exact-band and SmartCRDT/AgentGossip answer genuinely different
questions, and neither makes the other unnecessary. They compose.**

CRDTs guarantee that *state* converges given enough gossip rounds — a
G-Counter's value, an OR-Set's membership, a hash chain's head, all
eventually agree bit-for-bit across replicas, and where SmartCRDT's Rust core
tests it (G-Counter), that convergence is provably commutative, associative,
and idempotent. But none of the four CRDT types in SmartCRDT, and nothing in
AgentGossip's ledger, carry a *numeric estimate with a tolerance* — they
carry counts, tag-sets, last-write-wins values, and hash-sealed transaction
logs. "Has replica A's counter converged with replica B's yet?" is answered
by exact equality after enough rounds (or immediately for the hash chain,
which either verifies bit-for-bit or is rejected outright — there's no
"close enough" for a SHA-256 chain by design). That's a different, and
strictly easier, question than exact-band's: "are these two nodes' *continuous*
estimates within ε of each other, decidably, integer-exact, with no float in
the judge?" SmartCRDT's domain (counts, sets, config) genuinely doesn't need
that judge, because its values aren't continuous estimates in the first
place — which is exactly what §2 found: no float-valued, order-dependent
merge exists to need banding.

Where the two would actually meet is a type of CRDT state neither repo has:
**a numeric estimate that must converge exactly under merge but is allowed to
carry irreducible measurement uncertainty** — a sensor reading, a consensus
estimate, a confidence band. If SmartCRDT ever grows that (and its own ADR
frames the library as general-purpose distributed knowledge storage, not
counters-only, so it's a plausible next step, not a strawman), a naive
implementation would reach for a float average — which is neither
commutative under floating-point rounding nor a valid CRDT merge at all (the
`exact-band/README.md` ring-consensus box-vs-zonotope result is precisely
about what goes wrong when you try to reason about convergence of such a
value using ordinary interval arithmetic instead of the shared-noise-symbol
form). exact-band's `IBox` — the axis-aligned box that is genuinely closed
under intersection, associative, commutative, and idempotent (per
`build/exact-band/README.md`, "Two band shapes" table) — is exactly a
semilattice merge over integer bands, i.e. structurally a CRDT merge
operator already. That is the concrete composition point.

### Is the banded-CRDT primitive (a) already present, (b) a small addition, or (c) unsupported?

**(c), leaning toward (b) if someone builds it — it is not in the code
today.** Specifically:

- **Not present (a) is ruled out with evidence.** §2's exhaustive grep found
  no numeric-tolerance CRDT type anywhere in SmartCRDT, and AgentGossip's
  ledger has no CRDT merge at all (it's an append-only hash chain, a
  different structure entirely — chains are verified, not merged).
- **What already exists, reusable as-is:**
  - `IBox`'s intersection-based `narrow()` in `build/exact-band` is already a
    genuine semilattice merge over integer bands (associative, commutative,
    idempotent, per the crate's own README table) — this is the missing
    piece a "banded G-Counter" or "banded LWW-Register" would need for its
    merge operator.
  - SmartCRDT's `Merge` trait pattern in `native/crdt/src/merge.rs` is
    exactly the right shape to host it: `fn merge(&mut self, other: &Self)`
    plus the three-law doc comment SmartCRDT already writes for every type.
    A `BandedRegister<IBox<N>>` implementing that trait, with `merge` calling
    `IBox::narrow`, would drop straight into the existing test pattern
    (`test_merge_trait_commutative/associative/idempotent`) SmartCRDT
    already uses for `GCounter` — that harness is a small, direct reuse.
  - exact-band's `WIRE-FORMAT.md` bijective encoding is strictly stronger
    than AgentGossip's canonical JSON (§3) and could replace it as the
    hash preimage for any future numeric field in a ledger entry, closing
    the honest gap AgentGossip's own docstring admits.
- **What would have to be built, and is not a small addition:**
  - A CRDT type wrapping `Zono<K>` (the zonotope), not just `IBox`, if the
    goal is the sharper agreement result (the README's headline: enclosure
    of `x0 - x1` collapsing to exactly zero). `Zono` merge (`add`/`sub` in
    `src/zono.rs`) is exact under *shared-symbol* addition/subtraction, but
    it is explicitly **not** a lossless semilattice under repeated
    two-way merge the way `IBox::narrow` is: condensation
    (`Zono::absorb_spill`, `src/zono.rs`) discards precision once capacity
    `K` is exceeded, and the crate's own history records a soundness bug in
    exactly that path (`build/exact-band/README.md`, "Stress-testing that
    result — which found a soundness bug"). A distributed system merging
    zonotopes from many peers, not just combining forward through one
    node's own history, would need to re-derive (or re-verify) that
    condensation stays sound under arbitrary merge orders and partial-
    gossip topologies — a genuinely new proof obligation, not present in
    the current crate, which only exercises condensation along one
    node's own forward computation.
  - Wiring: SmartCRDT's `MetricsAggregator` and `FleetCollabStore` would
    need a sixth CRDT type registered (`crdt-store.ts:49-57`'s merge
    sequence, and `types.ts`'s `CrdtKind` enum, would both need extending),
    plus serialization support parallel to the existing `toJSON`/`fromJSON`
    pattern, ideally over exact-band's wire format rather than JSON.
  - None of this exists today in either repo. The exact-band README's own
    "Status" section says as much for its own side: "Not yet wired to
    `swarm-tminus`... that is the next step" — confirming the crate itself
    does not yet claim this integration, which matches what the scout found
    on the SmartCRDT side too.

**Bottom line**: exact-band is orthogonal to what SmartCRDT and AgentGossip
ship *today* (neither has a numeric-tolerance merge to conflict or overlap
with), and complementary to what either could plausibly ship *next* — a
banded numeric CRDT is a real, buildable primitive (SmartCRDT already has the
right `Merge`-trait shape and test harness; exact-band already has the right
associative/commutative/idempotent `IBox` merge), but it is a new type that
would need to be written, tested under real multi-peer merge orders (not just
one node's forward computation), and wired through both stores' existing
serialization — not a feature quietly already present under another name.
