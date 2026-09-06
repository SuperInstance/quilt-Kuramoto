# The vMF Kernel — Polyformal Specification

*The dissertation's load-bearing math, specified once, independent of language. This is the polyformalism move applied to the dissertation itself: one kernel, many languages, differential-tested against the audited Python reference (`elephant/vmf.py`, verified vs scipy to 1.8e-12).*

**What this is:** the von Mises–Fisher (vMF) maximum-likelihood snapshot of a room's 7-dimensional field, plus the field *edge* between two snapshots. This is the measurement instrument behind "the felt size of the step."

## 0. Constants

```
D      = 7        # dimension of the field space (S⁶ ⊂ ℝ⁷)
KMAX   = 500.0    # κ saturation cap — the dials DO saturate
NMIN   = 10       # below this many windows, κ is not identifiable
RHOMAX = 0.999    # ρ clamp — the unclipped Banerjee init overflows sinh as ρ → 1
```

The dial names are `["mood","volume","earnestness","cynicism","joke_landing","panic","presence"]` — but the kernel operates on the standardized z-vectors and does not need the names.

## 1. `A7(k)` — the Bessel ratio

`A₇(κ) = I_{7/2}(κ) / I_{5/2}(κ)` — the closed-form half-integer Bessel ratio, computed **without** calling any Bessel function:

- **Series branch:** if `k < 0.5`, return `k / 7.0` (leading Taylor term; the closed form catastrophically cancels for small κ).
- **Closed form:** otherwise, with `s = sinh(k)`, `c = cosh(k)`:

```
A7(k) = ((1 + 15/k²)·c − (6/k + 15/k³)·s) / ((1 + 3/k²)·s − (3/k)·c)
```

Asymptotics (for sanity): `A7 → κ/7` as κ→0, `→ 1 − 3/κ` as κ→∞. `A7(500) = 0.994012…` exactly (`1 − 3/500`).

## 2. `vmf_fit(zs)` — the (μ̂, κ) MLE

Input: `zs`, an N×7 matrix of unit-normalized z-vectors (rows = windows). Steps, in exact order:

1. **Guard N:** if `N < NMIN`, return "unidentifiable" (None/null/NoneType per language idiom) — never a fake number.
2. **Renormalize:** each row `x / ‖x‖` (defensive; inputs should already be unit).
3. **Mean resultant:** `r = mean(rows)`; `ρ = min(‖r‖, RHOMAX)`. If `ρ < 1e-12`, return "isotropic" (no mean direction).
4. **Mean direction:** `μ̂ = r / ρ` (a unit 7-vector).
5. **κ init:** Banerjee et al. formula, clipped to `[1e-6, KMAX]`:
   `κ₀ = clip(ρ·(D − ρ²)/(1 − ρ²), 1e-6, KMAX)`
6. **Newton solve** on `A₇(κ) = ρ` with derivative `g(κ) = 1 − A₇(κ)² − (D−1)·A₇(κ)/κ`:
   up to 60 iterations: `κ ← clip(κ − (A₇(κ) − ρ)/g, 1e-6, KMAX)`; stop when `|g| < 1e-12` or `|step| < 1e-9`.
7. **Warmth:** `warmth = WARM · μ̂` where `WARM` is the fixed 7-vector in `golden.json` (dot product).
8. **Jackknife SE(μ̂):** leave-one-out mean directions, renormalized; `μ_se = sqrt((N−1)/N · Σ‖jk_i − jk_mean‖²)`.
9. **`saturated`** = `ρ >= RHOMAX or κ >= KMAX`.

Return: `mu_hat[7]`, `kappa`, `rho`, `n`, `warmth_vmf`, `mu_se`, `saturated` (plus `kappa_ci` and `axis_spread` are optional — the differential test does not require them, since they use the language RNG).

## 3. `edge(fb, fa)` — the field step between two fits

Given two fit dicts `fb` (before) and `fa` (after), both non-null:

```
d_mu       = ‖fa.mu_hat − fb.mu_hat‖
d_warmth   = fa.warmth_vmf − fb.warmth_vmf
d_log_kappa = ln(fa.kappa / fb.kappa)
real       = d_mu > 2.0 · max(fb.mu_se, fa.mu_se)   # db_factor = 2.0 (the drift deadband)
```

## 4. Differential test (the acceptance gate)

Every language port must read `golden.json` + `inputs.json` and reproduce, to the stated tolerance:

- **A7:** for each `kappas[i]`, `|A7(k) − values[i]| ≤ 1e-9` (absolute).
- **vmf_fit:** `|kappa − golden.kappa| ≤ 1e-6`, `|rho − golden.rho| ≤ 1e-6`, `|warmth − golden.warmth| ≤ 1e-6`, `|μ_se − golden.mu_se| ≤ 1e-6`, `max|mu_hat − golden.mu_hat| ≤ 1e-6`, `n == 30`, `saturated == false`.
- **edge:** `|d_mu|, |d_warmth|, |d_log_kappa|` each within `1e-6` of golden; `real == false`.

The second fit in `edge` is the first fit on `zs + 0.05` (element-wise) — reconstruct it in-language from `inputs.json` exactly as the reference did.

## What this proves

If the kernel reproduces the golden vectors in every language, the dissertation's measurement is **essential, not accidental to Python/numpy** — the same claim the polyformalism repo made for its constraint kernel, pointed at the dissertation's own object. If any language diverges past tolerance, that is a finding (a numeric-vs-reference bug), not a pass.
