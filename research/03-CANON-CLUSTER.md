# The canon cluster — scouting report

Cloned (shallow, 2026-09-08) to `/tmp/claude-0/scouts/canon/<repo>`. All repos are
`github.com/SuperInstance/<repo>`, author `Casey Digennaro`.

**Headline finding, stated up front:** the scout brief's working definition of
"canon" — provenance records of WHO said WHAT, WHEN, derived from WHAT — does
**not match what the code does**. There is no claim object, no provenance
schema, no observer identity, no timestamped assertion-with-evidence anywhere
in this cluster. "Canon" here means *a literary/citation canon* — a corpus of
~14–71 short self-authored write-ups ("papers", F-numbered) about the Quilt
project's own development, served from one Cloudflare Worker, with a
citation graph and a keyword-search feature confusingly named `claim`. This is
the single most important fact for the synthesis question, so it is repeated
in section 4.

## 1. Repo table

| repo | real code or mirror | LOC (js+py) | tests | what it does |
|---|---|---:|---|---|
| `canon-hash` | mirror (HTTP client) | 39 | 1 file, hits **live** API, no fixtures | GETs `/api/canon/hash` from the live worker, returns whatever JSON comes back. Computes nothing itself. |
| `canon-graph` | mirror (HTTP client) | 82 | 1 file, live API | GETs `/api/canon`, does client-side BFS text-dump of the citation graph (`renderGraph`). |
| `canon-claim` | mirror (HTTP client) | 73 | 1 file, live API | Thin wrapper for `/api/canon/claim` and `/api/canon/drill`. **These routes do not exist on the deployed worker** (see §3) — verified live, 404. |
| `canon-suite` | mirror (re-export) | 18 | none | Re-exports `canon-claim`+`canon-hash`+`canon-graph` under one import. No logic of its own. |
| `canon-zoo` | stub | 0 | none | `README.md` only, one paragraph ("a system prompt for inspiration through play"). No code. |
| `canon-recs` | mirror (HTTP client + local scoring) | 150 | 1 file, live API | Combines `claim()` + cosine similarity over a metadata vector to rank "recommended" papers. Depends on the broken `/claim` route. |
| `canon-paper` | mirror (HTTP client) | 104 | 1 file, live API | Fetch one paper by number; body-lookup depends on `/api/canon/claim`, silently returns `body: null` when that 404s. |
| `quilt-canon-cli` | mirror (HTTP client, CLI) | 149 | 1 file, live API | `canon claim/drill/hash/count/graph/paper` — CLI wrapping the same broken/live endpoints. |
| `quilt-live-canon` | **real implementation (server)** | 1711 | none in repo | The actual Cloudflare Worker source (`worker.js`) deployed at `live-canon.superinstance.dev`. Implements navigate/confluence/lineage/ghost/tick/hash/cell-admit/vibe/verify/playground/WebSocket room. **Does not implement `/api/canon/claim` or `/api/canon/drill`** despite being what every claim/drill client above targets. |
| `live-canon-gh` | **real implementation (standalone, offline)** | 287 | none | Self-contained JS module + bundled `data.json` (71 papers + body excerpts). Implements `claim`/`drill` **locally** as keyword substring scoring (see §2). No test file present despite being the one place claim/drill actually run. |
| `live-canon-npm` | **real implementation, packaged** | 234 | 1 file — **fails as checked out** (asserts 9 papers, bundle has 14) | Published npm package `@superinstance/live-canon` (early version). |
| `live-canon-pypi` | **real implementation, packaged** | 216 | none | PyPI `quilt-live-canon` sdist, same 5-op LiveCanon class (no claim/drill in this version). |
| `quilt-live-canon-npm` | **real implementation, packaged** | 341 | 1 file — **fails as checked out** (asserts 9 papers, bundle has 71) | Newer npm package, full 7-op LiveCanon incl. claim/drill, bundles 71-paper `data.json`. |
| `quilt-live-canon-pypi` | **real implementation, packaged** | 415 | none | Newer PyPI sdist, mirrors `quilt-live-canon-npm`'s 71-paper bundle and 7 ops. |

Adjacent (checked per the brief, not part of the "canon" prefix):

| repo | notes |
|---|---|
| `SmartCRDT` | Large, real, separate project (2972 files, TS+Rust+Python monorepo, Docker stack). Implements textbook CRDTs (G-Counter, PN-Counter, OR-Set, LWW-Register, RGA) + ChromaDB vector search. About **merge of concurrent writes**, not agreement-within-tolerance of independent measurements. No "canon" naming, no relation to the F-number paper corpus. `/tmp/claude-0/scouts/canon/SmartCRDT/README.md`, `smartcrdt/*.py`. |
| `AgentGossip` | Small (1025 LOC across `src/ledger.ts`, `src/receipt.ts`, `src/transport.ts`), and — despite having nothing to do with the "canon" name — is conceptually the **closest thing in the whole scouted set to real origin-bookkeeping**: a hash-chained, append-only per-cell ledger with a genuine canonical-JSON preimage (sorted keys, pinned number semantics) and SHA-256 "mint receipts" (`src/receipt.ts:1-83`). But: `package.json` promises `vitest` tests and a `bin/agentgossip.js` CLI that **do not exist in the repo** (`find . -iname "*test*"` returns nothing); it is a documented port of external repos (`quilt-rust`, `quilt-esp32`) not present in this cluster, so it can't be verified from what's here. Aspirational/unverified, not fake. |
| `quilt-agent-memory-archive` | Markdown snapshot archive (agent session memory dumps), not code. `snapshots/2026-09-07-archive-v1/`. Irrelevant to canon/exact-band. |

## 2. What canon actually is (technical, evidenced)

**The corpus.** "The canon" is a set of short paper records, each:
```json
{"number":408,"title":"F98 — The 165-Test Polyformalism Conformance Suite",
 "f_number":98,"phase":222,"date":"2026-09-03","ref_papers":[],"ref_f_numbers":[97]}
```
(`/tmp/claude-0/scouts/canon/live-canon-gh/data.json`, first entry). Titles are
self-referential progress reports about the Quilt project's own repos and
benchmarks ("The Quilt Atlas: 47 Repositories, 280K Lines of Code", "Playtest:
6 Assets, 4 Controllers, 2 Bugs, 1 Real Result"). This is a blog/changelog
corpus with a citation graph, not a set of claims about external
observations.

**"Cell" and the hash.** Every paper is deterministically re-encoded as a
synthetic 16-slot vector ("Q1.15 dials") derived from its *metadata* — year,
phase, F-number, an FNV-1a hash of the title split into two 16-bit halves,
and a clamped reference count:
```js
// live-canon-gh/index.js:21-34, byte-identical in quilt-live-canon/worker.js and both *-pypi packages
function cellToDials(p) {
  const year = parseInt((p.date||'1970-01-01').slice(0,4)) || 1970;
  const yearQ = (year-1970)*546;
  const phaseQ = (p.phase||0)*218;
  const fQ = (p.f_number||0)*218;
  ...
  return [numQ, titleLo, fQ, phaseQ, yearQ, nRefsQ, titleHi, 0,0,0,0,0,0,0,0,0];
}
```
The **state hash** is FNV-1a 64-bit (offset `0xcbf29ce484222325`, prime
`0x100000001b3`) over these dial vectors, sorted by paper number and
byte-flattened lo/hi (`live-canon-gh/index.js:36-51`; identical in
`quilt-live-canon-pypi/live_canon/__init__.py:82-96`, `quilt-live-canon/worker.js:123-141`).
So: **canon-hash does not hash a claim, an observation, or arbitrary
content — it hashes a lossy, quantized re-encoding of paper metadata**
(title is hashed and truncated to 32 bits total, not preserved). Two papers
with different bodies but colliding metadata dials would hash identically.
It is a change-detection checksum for the corpus, not a content-addressed
provenance hash.

I independently recomputed this (not trusting the bundled tests, which are
stale — see §3) and it is **real and correct**: running the JS and Python
packages' own `state_hash`/`stateHash` over their bundled 71-paper
`data.json` both produced `0x7f563ed9982496a1`, matching the value both
READMEs claim. This is the one piece of the cluster that is a genuine,
verified cross-language conformance result.

**"Claim."** A `claim(query)` is *not* a provenance claim. It is keyword
substring search: tokenize the query, score every paper by
`title_match*100 + h1_match*50 + body_substring_match*25 + f_number_cite_match*200 + f_number*0.1`,
return the top scorer as `winner` plus 3 `runners_up`
(`live-canon-gh/index.js:151-216`, function `scorePaper`/`claim`). There is
no notion of source, timestamp of assertion, confidence, or evidence chain —
only which cached paper's title/excerpt contains the query words. `drill()`
takes the top-3 from `claim()` and relabels them DOCTRINE /
IMPLEMENTATION / VERIFICATION by a citation-count heuristic
(`live-canon-gh/index.js:214-243`). This is a document retrieval feature,
named with words ("claim", "drill") that suggest something epistemic it
does not do.

**"canon-graph" / lineage / confluence / navigate / ghost.** All are graph
operations over the citation edges (`ref_papers`, `ref_f_numbers`) of this
same paper corpus: BFS (`navigate`), shortest citation path (`lineage`),
cosine-similarity over the same metadata dial-vectors (`ghost`), and a
no-op "re-balance" (`tick` just returns `{ticked_cells: N}`,
`live-canon-gh/index.js:147-149`). `canon-graph` (the npm package) is a
client-side re-implementation of `navigate`/BFS-with-depth-and-max-F-number
filtering over the same JSON (`canon-graph/index.js:14-56`).

## 3. Is there a spec / canonical form? — honest answer

**No claim/wire spec exists.** There is no schema document, no IDL, no
"claim format" anywhere in the cluster. The closest things to a "spec" are:

- The FNV-1a algorithm description repeated as prose + constants in
  `quilt-live-canon/worker.js:35-46, 484-500, 841-846, 894-921` (a Python
  code fragment embedded in a JS string for the `/api/vibe` endpoint) and in
  each package's docstring. This *is* a real, byte-exact, cross-language
  spec — but only for **the metadata checksum**, not for a claim, a
  measurement, or any provenance record.
- No canonical serialization of a "paper" or a "claim" object is defined
  anywhere: field order, JSON key order, number formatting, and optional
  fields are all whatever `JSON.stringify`/`json.dumps` happens to produce.
  Contrast this explicitly with
  `/home/user/quilt-Kuramoto/build/exact-band/src/wire.rs:1-33`, which
  states the requirement this cluster is missing in one sentence: *"A format
  where two byte strings can mean the same thing cannot be used for
  provenance: two honest parties would compute different digests for the
  same measurement,"* and then enforces it (minimal varints, strictly
  ascending term ids, no representable zero coefficients, decoder rejects
  anything non-canonical). Nothing in `canon-*` does this.
- The one place a real canonical-encoding discipline appears in the whole
  scouted set is **outside the canon cluster**, in `AgentGossip/src/ledger.ts:34-50`
  (sorted-key compact JSON with pinned number semantics as the SHA-256
  preimage) — and even that repo ships no tests to verify it
  (`find AgentGossip -iname "*test*"` → empty, despite `package.json`
  declaring `"test": "vitest run"`).

**Verdict: origin-bookkeeping that is not byte-canonical is not
origin-bookkeeping, and this cluster is not byte-canonical for anything
except a lossy metadata checksum of its own internal blog corpus.**

## 4. Coherence: is `/api/canon/claim` even real?

I hit the live server directly (2026-09-08):
```
$ curl https://live-canon.superinstance.dev/api/canon/hash
{"state_hash":"0x7d8d32cd7f8a9f26","paper_count":14,"test_cell_hash":"0xe435d91d6d92a1d8","canon_target":"0xbf27a3631cdee337"}

$ curl https://live-canon.superinstance.dev/api/canon/claim?topic=trust+ladder
{"error":"not found","path":"/api/canon/claim"}
```
This matches the static analysis: `quilt-live-canon/worker.js`'s route
dispatch table (grep for `path ===`, lines 561-770) has no `/api/canon/claim`
or `/api/canon/drill` branch. **`canon-claim`, `canon-recs`, `canon-paper`,
`canon-suite`, and `quilt-canon-cli`'s `claim`/`drill` commands are all thin
clients of an endpoint that does not exist on the one server they all point
to.** `canon-paper` catches the resulting error and silently returns
`body: null` (`canon-paper/index.js:29-41`); the others would throw. This
is not a hypothetical — it's the live production state today.

The corpus itself is not stable either: the live worker currently reports
14 papers; the two most-recently-published packages (`quilt-live-canon-npm`
0.9.0, `quilt-live-canon-pypi` 0.9.0) bundle a **different, frozen snapshot
of 71 papers**; the earlier packages (`live-canon-npm`, `live-canon-pypi`)
bundle 9 and 14 respectively. Running each package's own bundled test suite
as checked out from git fails on its own paper-count assertion:
```
$ node quilt-live-canon-npm/test/test.js
AssertionError [ERR_ASSERTION]: 71 !== 9   (test.js:11 asserts 9, bundle has 71)
$ node live-canon-npm/test/test.js
AssertionError [ERR_ASSERTION]: 14 !== 9   (test.js:11 asserts 9, bundle has 14)
```
i.e. these packages have never been re-tested since their last data bump —
there is no CI gate keeping test and bundle in sync.

**So: several unrelated things sharing a prefix**, more precisely:
1. One real server (`quilt-live-canon`) with 8 working routes and 2 dead
   ones that half the ecosystem depends on.
2. A family of thin, largely interchangeable HTTP-client mirrors
   (`canon-hash`, `canon-graph`, `canon-claim`, `canon-suite`, `canon-recs`,
   `canon-paper`, `quilt-canon-cli`) that add no logic beyond URL
   construction and light client-side re-computation, all pointed at the
   same live host, none of which is independently useful once you know the
   3-4 URL patterns.
3. A separately-versioned, self-contained "LiveCanon" library shipped four
   times (`live-canon-gh`, `live-canon-npm`, `live-canon-pypi`,
   `quilt-live-canon-npm`, `quilt-live-canon-pypi` — five, actually) with
   its own bundled data snapshot that has drifted across versions and is
   not kept in sync with its own tests.
4. `canon-zoo`: an empty README, no code.

## 5. Tests / conformance — what's real vs performative

- **Genuinely verified by me, independently:** the FNV-1a state-hash
  algorithm is byte-identical across the JS and Python packagings. I ran
  `stateHash()`/`state_hash()` from `quilt-live-canon-npm/index.js` and
  `quilt-live-canon-pypi/live_canon/__init__.py` against their own bundled
  71-paper `data.json` and got the identical value
  `0x7f563ed9982496a1` both times, matching what their READMEs assert.
  This is a real, working cross-language conformance property, but it is
  conformance of a **metadata checksum**, not of a claim/observation format.
- **Not tested at all:** `canon-suite`, `canon-zoo`, `quilt-live-canon`
  (the actual server — no test directory in the repo), `live-canon-gh`,
  `live-canon-pypi`, `quilt-live-canon-pypi` — 6 of 13 repos ship zero test
  files.
- **Tests present but stale/broken as checked out:** `live-canon-npm`,
  `quilt-live-canon-npm` both fail their own bundled assertion on paper
  count (shown above) — meaning nobody has run `npm test` since the last
  data bump landed.
- **Tests present but network-dependent, no local fixtures:**
  `canon-hash`, `canon-graph`, `canon-claim`, `canon-recs`, `canon-paper`,
  `quilt-canon-cli` — every test in these 6 repos is "hit the live prod
  server and assert on whatever it returns today" (e.g.
  `canon-claim/test/test.js:9`: `if (!r1.winner || r1.winner.f_number !== 168) throw ...`
  against live data). Two of these six (`canon-claim`, and anything using
  `claim`/`drill`) are currently failing outright against production
  because the endpoint 404s (§4). There is no offline/mocked test in the
  whole cluster.
- **No cross-implementation conformance test exists as a *test*.** Nothing
  in any repo asserts "JS output == Python output" programmatically; the
  claim is made only in README prose and a hardcoded expected-hash string.
  I had to write the comparison myself (§2) to check it. There is no CI
  workflow file in any of the 13 repos I could find (no `.github/workflows`
  turned up in the file listings).

## 6. Maturity: published, and is anything using it?

Real, public registries — verified live, not from repo metadata:

| package | registry | status |
|---|---|---|
| `@superinstance/canon-hash` | npm | published, 1 version (0.1.0) |
| `@superinstance/canon-graph` | npm | published, 1 version (0.1.0) |
| `@superinstance/canon-claim` | npm | published, 1 version (0.1.0) |
| `@superinstance/canon-suite` | npm | published, 1 version (0.1.0) |
| `@superinstance/canon-recs` | npm | published, 1 version (0.1.0) |
| `@superinstance/quilt-canon-cli` | npm | published, 1 version (0.1.0) |
| `@superinstance/live-canon` | npm | published, **21 versions**, up to 0.9.1 — actively iterated |
| `quilt-live-canon` | PyPI | published, 18 versions, up to 0.9.1 |

npm download counts (last 30 days, via `api.npmjs.org/downloads/point/last-month`):
`canon-hash` 166, `canon-graph` 192, `canon-claim` 199, `canon-suite` 151,
`canon-recs` 169, `quilt-canon-cli` 142, `live-canon` 1498. These are
consistent with automated registry-mirror/scanner traffic for a
single-author package with no known consumers, not organic adoption — I
found no evidence (no reverse-dependency listing, no GitHub code search
result surfaced by the repos themselves) that any other project depends on
these packages. `canon-paper` is published under a *different* package name
(`@superinstance/canon-paper-gh`, per its own `package.json`) than its
README documents (`@superinstance/canon-paper`), and that mismatched name
is not on npm at all — a small but concrete sign of low maintenance
attention.

**Conclusion: yes, genuinely published; no evidence of real usage beyond
the author's own tooling.**

## 7. THE SYNTHESIS QUESTION

**Does canon (provenance) compose with exact-band (agreement)?**

Answered honestly: **no, not as things stand, because canon does not carry
what the synthesis needs it to carry.** The premise "a claim carrying a band
whose provenance is hashed canonically" requires three things to already
exist in canon and be composable with exact-band's `Banded`/`Zono` types
(`/home/user/quilt-Kuramoto/build/exact-band/src/lib.rs`,
`src/wire.rs`). None of the three exist:

1. **No claim object.** There is nothing in `canon-*` that represents "a
   measurement, from a source, at a time." A "paper" (`live-canon-gh/data.json`)
   has `title`, `f_number`, `phase`, `date`, `ref_papers` — a document
   record with a citation graph, not `(value, source, timestamp, tolerance)`.
   A `claim()` call is keyword search over document titles/bodies
   (§2), unrelated in kind. There is no field anywhere that could hold an
   `exact_band::Banded` value even if you wanted to bolt it on — you would
   be adding a wholly new object type, not composing with an existing one.

2. **No point-vs-band distinction, so nothing to upgrade.** `exact-band`'s
   entire value proposition is replacing a bare point measurement with an
   exactly-stated tolerance region and a decidable overlap test
   (`build/exact-band/src/lattice.rs`, `src/zono.rs`,
   `build/exact-band/examples/agreement.rs`). Canon has no measurements at
   all to begin with — its numeric fields (`f_number`, `phase`, a synthetic
   16-dial metadata vector) are internal bookkeeping identifiers, not
   observations of anything external. There is nothing here that is
   "a value known to within a tolerance" that a band would replace.

3. **The one hash canon does have is the wrong kind of hash for this
   synthesis.** `exact-band/src/wire.rs` hashes *exact byte-canonical
   encodings of the value itself* — hash the bytes, and honest parties with
   the same value get the same digest by construction (bijective codec,
   decoder rejects non-canonical bytes). Canon's FNV-1a state hash
   (§2) hashes a *lossy, quantized re-derivation of metadata* (a title
   collapses to 32 bits via FNV, numeric fields are scaled into Q1.15
   dials) — it is a change-detection checksum for "has the corpus JSON
   changed," and by design does **not** preserve enough information to
   reconstruct or verify the source content from the hash. You cannot
   staple exact-band's byte-exact-provenance discipline onto canon's hash
   function; you would have to replace it, not extend it.

**What would actually have to be built**, if the "killer primitive" is worth
pursuing:
- A genuine claim/observation schema: `{value_or_band, source_id, observed_at,
  derived_from: [claim_id...]}`, serialized through something with
  `exact-band/src/wire.rs`'s discipline (minimal varints, canonical field
  order, no float — this part could plausibly *reuse* exact-band's wire
  module directly, since it already refuses floats and is bijective).
- Replace FNV-1a-over-quantized-metadata with SHA-256 (or similar) over the
  canonical bytes of the claim itself, so the hash is a real content
  commitment, not a corpus-changed flag. `AgentGossip/src/ledger.ts:34-50`'s
  canonical-JSON approach is a closer starting point than anything in
  `canon-*`, though it too is unshipped/untested (§1).
- A hash chain or append-only log per source/claimant, so "derived from
  WHAT" is checkable, not just asserted — nothing in `canon-*` has this;
  `AgentGossip/src/ledger.ts` (hash-chained journal) is the only code
  anywhere in this scouting pass that does, and it isn't part of the canon
  cluster and isn't tested.
- Fix the cluster's existing rot before building on it: the dead
  `/api/canon/claim` and `/api/canon/drill` routes (§4), the stale
  bundled-data-vs-test mismatches in two published npm packages (§3), and
  the complete absence of CI (§5) would all need to be resolved so the
  *existing* "byte-exact across languages" claim about the state hash
  (which is real and worth keeping — §2/§5) isn't sitting next to visibly
  broken siblings.

**Bottom line:** "canon + exact-band = byte-exact provenance-plus-agreement
primitive" is a coherent and appealing idea on its own terms, and
exact-band's half of it is solid and already built
(`build/exact-band/src/wire.rs`, `src/zono.rs`, `tests/conformance.rs`). But
it is not a description of code that exists. The canon cluster is a
citation-graph-and-keyword-search product for the project's own internal
paper trail, with one solid, narrow, verified result (an FNV-1a metadata
checksum that is genuinely byte-identical across a JS and a Python
packaging) surrounded by thin HTTP-client mirrors, two dead routes half the
mirrors depend on, no canonical claim format, no measurement/band concept,
and no tests that run offline or gate publishing. Composing it with
exact-band today would mean designing and building the claim/provenance
layer from scratch — canon does not currently have a "claim" to attach a
band to.
