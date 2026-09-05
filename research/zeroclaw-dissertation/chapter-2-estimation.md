# Chapter 2 — Estimation: vMF Snapshots from Dial Banks

*Dissertation draft, ZeroClaw. Source: vmf-engineering-spec.md §1 (numerically verified), elephant repo ground truth. Chapter 1 (Doctrine) is an expansion of chapter-0 §0.2; this chapter is the estimation theory.*

## 2.1 Why a distribution, not a point

A room snapshot is not one 7-vector. A single reading cannot carry tightness — κ is not identifiable from N=1. The room must be read *as a sample*: the trailing window (W messages) re-read at each arrival, producing the room-as-it-was sequence. The vMF distribution on S⁶ is the honest summary of that sample: a mean direction μ̂ (where the room's field points) and a concentration κ (how tightly it points there). Cold rooms are tight — there is one way to be cold. Warm rooms are loose — many ways to be warm. κ is that loose/tight axis, and it is *not* valence.

## 2.2 Standardization

Dial units are incommensurable: mood and joke_landing are signed in [−1,1] with neutral 0; volume, cynicism, panic are [0,1] with neutral 0; earnestness and presence are [0,1] with neutral **0.5**. Before any sphere work:

```
z_k = s_k·(v_k − c_k),  s_k = 2/(hi_k − lo_k)  →  z_k ∈ [−1,1]
```

This is a stated calibration choice, logged in `params.standardization`, not a silent default. **Scope rule (per advisor caveat):** this normalization exists only for the sphere geometry (μ̂, κ, displacement). The elephant gap, `distance()`, and the contrast training signal remain computed on raw cross-room heterogeneity — normalize where the gap lives and the sauna/plunge contrast evaporates. Same word, two layers, never mixed.

## 2.3 The estimator

Given unit vectors x_i = z_i/‖z_i‖, i = 1..N, on S⁶ (d = 7):

- r̄ = (1/N)Σx_i, ρ = ‖r̄‖, μ̂ = r̄/ρ
- κ solves A_d(κ) = ρ, the modified-Bessel ratio equation, by Newton iteration with derivative A′(κ) = 1 − A² − (d−1)A/κ, initialized at the Banerjee approximation κ₀ = ρ(d−ρ²)/(1−ρ²). The approximation is init and CI shortcut, never the final estimate.

For d = 7 the half-integer Bessels cancel their √(2/πκ) prefactors, giving a closed form in sinh/cosh — numpy-only, honoring the repo's no-scipy rule — with a series branch A₇ ≈ κ/7 below κ = 0.5 where the closed form catastrophic-cancels. Verified <1e-9 against scipy across κ ∈ [0.6, 500]; recovers true κ on exact vMF samples (the verification pass caught and patched a real sinh-overflow at high ρ: clamp ρ ≤ 0.999 with clipped init).

**Guards (the honesty layer):**
- N < 10 windows ⇒ κ = None. Not identifiable is a *result*, not an embarrassment; a κ without its CI and N is not a number, it's a mood.
- ρ ≤ 0.999, κ ≤ 500 saturation caps with a `saturated` flag — v0 dials do saturate.
- Bootstrap CI on κ (B = 200, non-overlapping windows for CIs — overlapping windows autocorrelate and fake confidence).
- Jackknife SE(μ̂), which doubles as the **drift deadband**: an edge is real iff ‖Δμ̂‖ > 2·SE(μ̂). Stillness reads as stillness.

## 2.4 Warmth as projection: the disambiguation

The fleet's historical sickness was two inconsistent "temperatures": v0 warmth (a fixed linear form) and v0 κ (the banned extremity proxy, collinear with |warmth| — it subtracted 0.5 from dials whose neutral is 0). The estimator kills both:

- **Warmth** = ŵ·μ̂, the projection of the mean direction on the linearized warm direction w = (0.30 mood, 0.10 volume, 0.10 earnest, −0.15 cyn, 0.15 joke, −0.10 panic, 0.10 presence), normalized. Warmth reads μ̂ only.
- **κ** = tightness of ρ. ρ is invariant to rotating the sample — warmth cannot move κ *by construction*.

"Temperature similarity" is thereafter always an explicit joint functional, e.g. D² = ‖μ̂−μ̂′‖² + λ·(Δ log κ)² — never silently one or the other. The v0 proxy remains in logs, labeled, for series continuity; it is banned from comparison paths.

## 2.5 The known sickness of the sample (tripwires)

The estimator is honest; the *dial space* may not be. Mood, panic, and cynicism share lexical triggers and the v0 dials saturate, so ρ partly measures dial-construction agreement rather than room tightness. This is the highest-risk assumption of the whole thesis and it ships with diagnostics, not hopes:

- `axis_spread`: per-dial std of the window sample. Anisotropy ratio (max/min) > 3 ⇒ κ is direction-dependent; report the caveat or whiten on corpus covariance.
- corr(warmth_vMF, log κ) across nights: |r| > 0.8 over ≥ 4 nights ⇒ the confound survived; investigate before trusting any retrieval built on κ.
- κ(W) sensitivity: report the sweep over W ∈ {4, 8, 16}; density-style dials are window-dependent by construction — drift is expected and disclosed, not hidden.

## 2.6 Small-sample honesty (the future warning)

The same estimator on the 384-d encoder embeddings at N ≈ 15 clips has E‖r̄‖ ≈ √(N/d) ≈ 0.20 *under uniformity* — raw-mean ρ is garbage there and needs shrinkage. In 7-dim dial space at N ≥ 10 the bias is mild. The estimator code carries this warning so the future self does not quietly reuse it where it lies.

## 2.7 What this chapter establishes

Given any room a DialBank can read, this chapter delivers a defensible (μ̂, κ, warmth) triple with uncertainties, a deadband, and shipped tripwires. It establishes nothing about whether within-room displacement clears noise — that is Chapter 4's measurement, and the deadman switch's business, not this chapter's.
