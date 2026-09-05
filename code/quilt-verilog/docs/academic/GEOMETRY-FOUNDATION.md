# GEOMETRY FOUNDATION — 2026-08-28 — The Verified Core and What It Buys the Dissertation

**Author:** ZeroClaw assist lane. **Status:** research note, annotate-only. Nothing registered, sealed, or frozen is altered. The wave-4 S2 freeze remains the next experiment, unconditionally, per `docs/RE-THINK-2026-08-28.md` §5.

**Sources:** `quilt-geometry` @ `948655a` (README + library), scout briefs `rd/patches/geometry/SCOUT-A-PENROSE.md` and `SCOUT-B-MANDELBROT.md` (2026-08-28), `docs/RE-THINK-2026-08-28.md`, `research/STATUS-2026-08-28.md`, `research/topic.md` v3.

**Honesty markers** (same convention as RE-THINK): **[V]** verified — reproduced in this session unless noted; **[S]** speculative — plausible, must be earned by registered experiment; **[M]** metaphor promoted to math — the dangerous tier.

---

## 0. Verification note — what this lane reproduced, not just read

Before citing anything, this session ran the quilt-geometry test suite and re-derived the headline numbers from the library directly (2026-08-28, quilt-geometry @ `948655a`):

- `pytest tests/ -q` → **9 passed**.
- Tile counts per generation, generated fresh: gen 0–5 = **10, 35, 110, 275, 720, 1915** (thin/thick: 5/5, 15/20, 45/65, 110/165, 265/455, 735/1180). Matches README exactly.
- Gen-5 patch: **3730 adjacency edges, average degree 3.90**, every interior edge shared by exactly 2 tiles [V, library invariant, test-enforced].
- Diffusion field variance per round: **1.0000, 0.8775, 0.8228, 0.7875, 0.7608, 0.7390, 0.7204, 0.7040, 0.6894** — strictly decreasing, reproduced digit-for-digit.
- Embedding locality (8-dim, seed 7, gen-5 patch): mean adjacent-pair cosine **0.7394** — reproduced exactly. Random-pair baseline: README reports 0.0092; this session's independent draw gave **0.0134**. Both ≈ 0; the third decimal is draw-dependent and should be quoted as "~0.01" not as a fixed constant.

One honest failure is recorded in the library itself and is first-class here (§1.3).

## 1. The verified geometry core

### 1.1 P3 tiling by pentagrid [V]

`quilt-geometry` generates Penrose P3 rhombus patches (thin 36°/144°, thick 72°/108°) by the de Bruijn **pentagrid** (cut-and-project dual) method. Generation g is the infinite tiling's g-fold golden deflation (scale ψ^g, ψ = 1/φ = 0.618…) restricted to a fixed origin-centric window of radius 2φ^g. This is the same corrected cut-and-project family the scouts found in `quilt-id` / `quilt-velato` (canonical integer address in the sum-zero lattice L ⊂ ℤ⁵, never floats) — SCOUT-A §(b) construction 2.

Verified deflation signature — tile growth per generation: 3.500, 3.143, 2.500, **2.618**, 2.660, converging to **φ² = 2.618** (linear scale shrinks by 1/φ per generation, area hence tiles grow by φ²). Thick:thin ratio at gen 5: 1180/735 = **1.605**, approaching φ = 1.618. Both are consistency checks the library's tests assert, not new claims.

### 1.2 Origin-centric coordinates + Pythagorean snapping [V as arithmetic; S as dissertation tooling]

Every tile gets a center in origin-centric polar form; distances from origin snap to the nearest **primitive Pythagorean hypotenuse** (5, 13, 17, 25, 29, 41, …), angles preserved. Verified snap behavior on a unit-scale patch (radius 24): raw tile distances spanning 0.81–23.99 snap to histogram **{5: 320, 13: 535, 17: 855, 25: 530}** — e.g. 12.17→13, 17.07→17, 22.54→25. All origin distances become exact integers; metric bookkeeping needs no floating-point tolerance.

**Honest limits:** the triple lattice is sparse (hypotenuses grow ~quadratically), so angle resolution must snap too or the coordinate map is lossy; and **snapping is a modeling choice that must be registered like any threshold** (RE-THINK Lib 2 failure mode) — an unregistered snap launders structure into the metric.

### 1.3 The honest failure: deflation was built, verified, and shelved

The library's own README records this: a direct **Robinson-triangle deflation** (acute → acute + gnomon; gnomon → 2 gnomons + 1 acute, child scale ψ) was implemented and verified locally, but **mirror-state propagation across patch boundaries is error-prone**, so it was abandoned; the pentagrid yields the identical deflation hierarchy exactly and is what ships. This is the dissertation's method discipline applied to geometry — ship the exactly-verifiable construction, shelve the theoretically-nicer one, record why — and it belongs in the method chapter as a case study, not in a footnote.

### 1.4 Diffusion gravity field [V]

Field construction: seed each tile with normalized total 1/d² gravity weight, then run 8 rounds of lazy neighbor-averaging over shared-edge adjacency. Variance across tiles per round: **1.0000 → 0.6894**, strictly decreasing (§0), converging toward the graph average. Honest notes: 8 rounds is a choice, not a derived constant; the floor after 8 rounds (0.689) is nowhere near zero — convergence is slow and the field retains most of its seed structure at this depth. The monotonicity is the verified content.

### 1.5 Locality-correlated embedding [V]

8-dim embedding initialized locality-correlated (random + 0.5 × neighbor average, normalized): adjacent tile pairs mean cosine **0.7394** vs random pairs **~0.01**. This locality is obtained **by construction** — no training, no data. That fact is a result in itself (§3.2).

## 2. What each component does for the dissertation — claim by claim

The claim inventory is `research/topic.md` v3 / STATUS §2. Orthogonality is stated where it holds; geometry is not a universal solvent.

### 2.1 SUPPORTS — the expanded walks-substrate frame (RE-THINK §5), and with it open question 4 (cross-strata transfer)

The dissertation's surviving substrate object is the **walk** (edge log; fabric journal walks per STATUS §5). The tiling gives walks an **exact substrate**: adjacency is a computable integer relation (3730 edges on gen-5; every interior edge shared by exactly 2 tiles [V]), and the deflation hierarchy gives the same patch at scales 1, ψ, ψ², … exactly (growth → φ² [V]). Consequences:

- **The walk object becomes definable without a window choice.** The edge log's window scale is a known artifact surface (the band-movers finding: the static in-band ratio is a window-scale artifact — STATUS §2). Tile adjacency carries no window parameter. A walk as an edge-set on a Penrose patch (RE-THINK §3) has exactly computable relations — no kernel, no threshold, no learned similarity.
- **Cross-strata transfer (open Q4)** acquires a concrete grain: walks-up-to-relabeling over the same aperiodic relation structure. Tap-corpus walks and fabric-journal walks become edge-sets over patches of the *same* tiling family — comparable by deflation level and Ammann co-membership rather than by windowed correlation. Registrable as a test; not yet registered.
- **Multiscale persistence becomes a discrete test** (RE-THINK §4): a structure that survives deflation levels 4→5 (720→1915 tiles) is scale-robust by exact rescaling, not by smoothing-kernel argument.

This is the claim geometry best supports: **not any warmth or reader claim, but the frame generalization itself — walks over aperiodic-tiled fields are well-founded, with the first instance (speech rooms) intact.**

### 2.2 SUPPORTS — apparatus generality of the field machinery (thermometer, method)

The diffusion field runs on tiles exactly as the vMF/field machinery runs on dials: seed → local averaging → a scalar field with monotone concentration (variance 1.0000→0.6894 strictly decreasing [V]). This is weak but real support for the room-field thermometer's *apparatus* claim — the field construction is substrate-independent, not a speech-room accident. It supports **no warmth claim whatsoever**; the thermometer's evidence stays in speech rooms, where it was earned.

The pentagrid-over-deflation decision (§1.3) supports the **method chapter** directly: a documented case of choosing exact verifiability over theoretical elegance, with the failure recorded in the artifact.

### 2.3 SUPPORTS — the fabric-walks bridge (STATUS §5) gets its coordinate layer

Pythagorean snapping (§1.2) gives tit-quilt-elixir cells an origin-centric, rationally exact coordinate assignment; journal trajectories become walks with exact distance bookkeeping, and restart/tear entries become **metric discontinuities on snapped coordinates** — the walk-integrity measurement STATUS flagged as genuinely new. Status: tooling exists [V as arithmetic]; the export and the registration do not [S]. Booking per STATUS: after wave-4 S5, not before.

### 2.4 UNDERMINES — locality-as-evidence readings of the encoder tier (sharpening an already-filed downgrade)

The 8-dim embedding achieves adjacent-pair cosine 0.7394 vs ~0.01 random **with zero learning** (§1.5). Therefore: **in-sample similarity structure cannot distinguish "the embedding measured something" from "the embedding built the geometry in."** This does not produce a new verdict — the encoder tier is already filed as "retrieval fact, not instrument" (held-out 0.0694 vs in-sample 0.478, topic.md claim 3) — but it hands the apparatus a **construction-null**: any future encoder upgrade (the registered upgrades of open Q2; any wave-4+ fiber-side embedding claim) that cites adjacency-correlated similarity as evidence must be treated as construction-tier until held-out separation is shown. Concretely: a learned embedding should be compared against a locality-correlated-by-construction baseline of the same dimension; if the learned one does not beat the construction-null out-of-sample, the locality was free, not measured. Registrable as a clause; not yet registered.

Secondary, milder tension: the tiling shows exact relation structure is *available*, which makes the edge log's order-of-arrival adjacency look like what it is — one chosen relation structure among several, with its window-scale artifacts disclosed. That is a framing caution for Ch6, not a falsification of the edge log, whose SOLID verdict is untouched (its evidence is replay-honesty and determinism, not uniqueness of the relation choice).

### 2.5 ORTHOGONAL — reader-delta, premise, H-reader≡room, E4 regress

Geometry touches none of these. The reader-delta object, the premise's ratio/ICC apparatus, the slope regression (INDETERMINATE at registered rule), and the E4 flooding read (day-9 [A] 0.1731) are claims about speech rooms and commit streams. No geometry result supports or undermines them, and this lane will not stretch one to. The RE-THINK's guard applies in full: the S2 freeze is the last experiment of the old frame and the calibration instrument of the new one — do not skip it.

## 3. What is still speculative — not earned, do not cite as results

- **Phason stiffness ↔ κ rigidity [S].** The quasicrystal analogy (a room's mood shifting as a whole while local dial-pair relations stay intact) is the right *name* for a measurable quantity, but no phason-flip experiment exists. SCOUT-A confirms phason shifts γ are implemented in quilt-id as window translations; measuring "how much coordinated shift before the pattern tears" on a tiling with a dial field on it is a registrable experiment and nothing more.
- **Post-quantum / no-aliasing substrate [S→M, per RE-THINK].** The testable core — *aperiodic relation structures resist collision/periodicity exploits* — remains a registrable experiment, not a slogan. Nothing in quilt-geometry addresses it.
- **Gravity-weighted metric d_w(p,q) = d·g(p)·g(q) [M→S].** The diffusion field uses 1/d² gravity weights [V], but the metric modification itself is unbuilt. The warm/cold monotone (κ high = smooth gravity; κ low = rough) is a hypothesis about dial fields, untested.
- **Ammann-line co-membership and deflation-parent relations [S].** Adjacency is verified; the Ammann and parent relation matrices (RE-THINK Lib 1 API) are specified, not implemented in quilt-geometry.
- **Snap-histogram density as "coverage" [S].** The {5:320, 13:535, 17:855, 25:530} histogram shows real distances land on the triple lattice; whether the induced discretization preserves field structure (e.g. diffusion monotonicity) is untested.
- **Fleet-lore bridges (golden twist, Mandelbrot inward) [M→S].** SCOUT-B is explicit that the 4D R(α,β) unification is paper-claim, zero code, and fibonacci-growth's log(φ)/log(2) boundary link is conceptual. Do not cite as established; treat as named follow-up lanes (quaternionic escape-time is a genuine greenfield gap the scouts found).

## 4. Booking

1. **No new registrations from this lane** (annotate-only). Candidates queued for the committee, in order: (a) the construction-null clause for encoder upgrades (§2.4); (b) walks-as-edge-sets over a fixed P3 patch as the cross-strata grain (§2.1); (c) snap-parameter registration template whenever pythag-snap is first used on corpus data (§1.2).
2. **Wave-4 S2 freeze proceeds first, unchanged** (RE-THINK §5; STATUS §4). Geometry work is library-building in the gap, not a parallel claim lane.
3. **Library gap list for `penrose-quilt` (Lib 1):** Ammann/parent relation matrices; exact ℚ[√5] vertex arithmetic; dual-construction cross-validation against the substitution construction (SCOUT-A recommendation — two independent constructions agreeing is a free correctness oracle).

---

*Provenance: quilt-geometry README + library (tests executed, numbers reproduced in-session, @ `948655a`); SCOUT-A/SCOUT-B briefs; RE-THINK-2026-08-28; STATUS-2026-08-28; topic.md v3. No frozen, sealed, or registered artifact was modified.*
