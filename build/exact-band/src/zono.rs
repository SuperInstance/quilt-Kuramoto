//! Integer zonotopes — bands that remember *why* they are uncertain.
//!
//! [`IBox`](crate::IBox) is sound but not tight, and its own docs say so: it is
//! interval arithmetic, so if the same uncertainty reaches a result along two
//! paths it is counted twice. The classic symptom is that `x - x` is not zero.
//! For `x ∈ [9, 11]`, interval subtraction gives `[-2, 2]` — a two-wide band
//! around an answer that is exactly `0`, every time, for every `x`.
//!
//! That is the **dependency problem**, and it compounds: chain a few dozen
//! operations that reuse the same measurements and the box grows without bound
//! while the true reachable set stays small.
//!
//! ## The correction, and the claim it retires
//!
//! An affine form carries the *sources* of its uncertainty instead of only the
//! total:
//!
//! ```text
//!     x  =  c  +  x₁ε₁ + x₂ε₂ + … + xₖεₖ,        εᵢ ∈ [−1, 1]
//! ```
//!
//! The `εᵢ` are shared symbols, so subtracting `x` from itself cancels term by
//! term and yields exactly `0`. The set such a form denotes is a *zonotope*.
//!
//! `boxed.rs` previously stated that this needs "real-valued noise
//! coefficients, i.e. floats, so it is deliberately out of scope". **That is
//! wrong, and this module is the retraction.** Integer coefficients work
//! perfectly: addition, subtraction and scaling are exact in `ℤ`, and the two
//! operations that are not — division and multiplication — stay sound by
//! pushing their error into a *fresh* noise symbol with an integer coefficient
//! that is rounded **up**. Nothing is approximated silently; every inexactness
//! becomes a named term you can inspect.
//!
//! ## Fixed capacity, on purpose
//!
//! Each inexact operation mints a symbol, so the term list would grow without
//! bound. [`Zono`] is generic over a capacity `K` and stores its terms inline,
//! so it needs no allocator and fits the same ESP32 targets as the rest of the
//! crate. When a result would exceed `K` terms, the smallest are **condensed**
//! into one fresh symbol whose coefficient is the sum of their magnitudes —
//! which is exactly the interval-arithmetic answer for those terms, and so is
//! sound. Condensation is the only place tightness is deliberately given up,
//! and [`Zono::condensations`] counts how often it happened.
//!
//! ## What this does *not* buy
//!
//! Zonotopes are **not universally tighter than boxes**, and the tests say so
//! rather than leaving it to be discovered. For a single isolated
//! multiplication, interval arithmetic is often already optimal: `x·x` for
//! `x ∈ [9, 11]` has exact range `[81, 121]`, width 40, while affine
//! multiplication must bound the nonlinear part by `rad·rad` over a fresh
//! symbol's full `[−1, 1]` when the truth is that `ε²` lies in `[0, 1]` —
//! giving width 42. No amount of integer arithmetic changes that.
//!
//! The win is on **chains that reuse a value**, which is what the dependency
//! problem actually is. `examples/zono_vs_box.rs` measures where the crossover
//! sits rather than asserting it.
//!
//! ## Prior art — most of this is not new
//!
//! A literature review (`research/05-PRIOR-ART-EXACT-NUMERICS.md`) established
//! that the core mechanisms here are decades old, and it is worth saying so
//! where the code lives rather than only in a report:
//!
//! * **Shared noise symbols that cancel under subtraction** is the founding
//!   idea of affine arithmetic (Comba & Stolfi, 1993; Stolfi & de Figueiredo,
//!   *Self-Validated Numerical Methods and Applications*). "`x − x` collapses
//!   to zero" is affine arithmetic's oldest selling point, not a contribution
//!   of this module.
//! * **Pushing an inexact operation's error into a fresh, rounded-up symbol**
//!   is the standard AA treatment of rounding. `div_round`, `mul` and
//!   `absorb_spill` apply it to integer remainders instead of floating-point
//!   rounding; the soundness argument is the classical one.
//! * **Condensation** is zonotope *order reduction* — a named, surveyed
//!   technique (Girard and successors; see "Methods for Order Reduction of
//!   Zonotopes", TUM). This is its coarsest instance, target order one.
//!   [Arpra](https://github.com/arpra-project/arpra) (2021) already does the
//!   same merge-the-smallest-terms trick over MPFR.
//! * **Exact-rational zonotopes already exist**: `LazySets.jl` supports
//!   `Rational` coefficients as a type parameter.
//! * **Zonotopes beating intervals for networked estimators** is established
//!   set-membership estimation — including zonotope diffusion across agents
//!   toward partial consensus (IRI-UPC, IEEE CDC 2018), which is the same
//!   territory as this crate's ring-consensus example, years earlier.
//!
//! What appears to remain unclaimed, and is stated as *appears* because the
//! review was web-search-only: an affine arithmetic that is **integer all the
//! way down** while also being `no_std`, allocator-free and fixed-capacity for
//! an MCU; the [`Fixed`] binary-scale trick that makes division by a power of
//! two mint nothing; and the cross-substrate (Rust/C/Python) byte-exact
//! treatment with a soundness bug documented and caught by its own sweep.

use crate::isqrt;

/// Allocator for noise symbols.
///
/// Every inexact operation needs a symbol nobody else is using; sharing one by
/// accident would claim a dependency that does not exist and could make a band
/// *too narrow*. A single counter is enough, and making it explicit means the
/// caller can see how many independent error sources a computation introduced.
#[derive(Copy, Clone, Debug, Default, PartialEq, Eq)]
pub struct Symbols(u32);

impl Symbols {
    /// A fresh pool. Symbol 0 is never handed out, so it can mean "none".
    pub const fn new() -> Self { Self(0) }

    /// Mint a symbol that has never been used by this pool.
    pub fn fresh(&mut self) -> u32 {
        self.0 += 1;
        self.0
    }

    /// How many symbols have been minted.
    pub const fn minted(&self) -> u32 { self.0 }
}

/// An affine form over at most `K` noise symbols, with integer coefficients.
///
/// Denotes `{ c + Σ xᵢeᵢ : eᵢ ∈ [−1, 1] }`, a zonotope. Terms are kept sorted
/// by symbol id, which makes combining two forms a single linear merge.
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct Zono<const K: usize> {
    center: i64,
    ids: [u32; K],
    coeffs: [i64; K],
    len: usize,
    condensations: u32,
}

impl<const K: usize> Zono<K> {
    /// An exactly known value: no noise terms at all.
    pub const fn exact(center: i64) -> Self {
        Self { center, ids: [0; K], coeffs: [0; K], len: 0, condensations: 0 }
    }

    /// A value known to within `radius`, from a **new, independent** source.
    ///
    /// Two calls produce two symbols, so the results are treated as unrelated —
    /// which is the safe default. To express that two values share a source,
    /// build them from the same symbol with [`Zono::from_symbol`].
    pub fn uncertain(center: i64, radius: u32, pool: &mut Symbols) -> Self {
        let mut z = Self::exact(center);
        if radius > 0 && K > 0 {
            z.ids[0] = pool.fresh();
            z.coeffs[0] = radius as i64;
            z.len = 1;
        }
        z
    }

    /// A value whose uncertainty comes from an *existing* symbol.
    ///
    /// This is how a shared measurement is expressed, and it is the whole point
    /// of the module: two values built from the same symbol will cancel exactly
    /// when subtracted.
    pub fn from_symbol(center: i64, symbol: u32, coeff: i64) -> Self {
        let mut z = Self::exact(center);
        if coeff != 0 && K > 0 {
            z.ids[0] = symbol;
            z.coeffs[0] = coeff;
            z.len = 1;
        }
        z
    }

    /// The exact centre.
    pub const fn center(&self) -> i64 { self.center }

    /// How many noise terms are live.
    pub const fn terms(&self) -> usize { self.len }

    /// How many times tightness was given up to fit the capacity.
    pub const fn condensations(&self) -> u32 { self.condensations }

    /// Total half-width: `Σ|xᵢ|`, in `i128` so it cannot overflow.
    pub fn radius(&self) -> i128 {
        let mut r: i128 = 0;
        let mut i = 0;
        while i < self.len {
            r += (self.coeffs[i] as i128).abs();
            i += 1;
        }
        r
    }

    /// The interval this form denotes, saturating at the `i64` ends.
    pub fn interval(&self) -> (i64, i64) {
        let r = self.radius();
        let lo = (self.center as i128) - r;
        let hi = (self.center as i128) + r;
        (clamp_i64(lo), clamp_i64(hi))
    }

    /// Is the value known exactly?
    pub fn is_exact(&self) -> bool { self.radius() == 0 }

    /// The `i`-th term as `(symbol, coefficient)`, or `None`.
    ///
    /// Exposed so a conformance harness can mix the INTERNAL representation,
    /// not merely the interval: two substrates that condense differently can
    /// still agree on a width by coincidence, and the term list is where that
    /// coincidence stops.
    pub fn term(&self, i: usize) -> Option<(u32, i64)> {
        if i < self.len { Some((self.ids[i], self.coeffs[i])) } else { None }
    }

    /// The coefficient on `symbol`, or 0.
    pub fn coeff_of(&self, symbol: u32) -> i64 {
        let mut i = 0;
        while i < self.len {
            if self.ids[i] == symbol { return self.coeffs[i]; }
            i += 1;
        }
        0
    }

    /// Add an exactly known offset. Never loses tightness.
    pub fn shift(mut self, by: i64) -> Self {
        self.center = self.center.saturating_add(by);
        self
    }

    /// Multiply by an exact integer. Exact: coefficients scale with the centre.
    pub fn scale(mut self, k: i64) -> Self {
        self.center = self.center.saturating_mul(k);
        let mut i = 0;
        while i < self.len {
            self.coeffs[i] = self.coeffs[i].saturating_mul(k);
            i += 1;
        }
        self
    }

    /// Sum of two forms. **Exact** — shared symbols combine rather than stack.
    pub fn add(self, other: Self, pool: &mut Symbols) -> Self {
        self.merge(other, 1, pool)
    }

    /// Difference of two forms. **Exact**, and `x.sub(x)` is exactly zero.
    pub fn sub(self, other: Self, pool: &mut Symbols) -> Self {
        self.merge(other, -1, pool)
    }

    /// `self + sign * other`, merging two sorted term lists in one pass.
    fn merge(self, other: Self, sign: i64, pool: &mut Symbols) -> Self {
        let mut out = Self::exact(self.center.saturating_add(
            if sign < 0 { other.center.saturating_neg() } else { other.center },
        ));
        out.condensations = self.condensations + other.condensations;

        // Overflow beyond K is collected here and re-admitted as one symbol.
        let mut spilled: i128 = 0;
        let (mut i, mut j) = (0usize, 0usize);

        // Both inputs are sorted by id, so one linear pass suffices and equal
        // ids meet -- which is where the cancellation actually happens.
        while i < self.len || j < other.len {
            let (id, c) = if j >= other.len || (i < self.len && self.ids[i] < other.ids[j]) {
                let v = (self.ids[i], self.coeffs[i]);
                i += 1;
                v
            } else if i >= self.len || other.ids[j] < self.ids[i] {
                let v = (other.ids[j], other.coeffs[j].saturating_mul(sign));
                j += 1;
                v
            } else {
                let v = (self.ids[i],
                         self.coeffs[i].saturating_add(other.coeffs[j].saturating_mul(sign)));
                i += 1;
                j += 1;
                v
            };
            if c == 0 { continue; }          // exact cancellation: drop the term
            if out.len < K {
                out.ids[out.len] = id;
                out.coeffs[out.len] = c;
                out.len += 1;
            } else {
                spilled += (c as i128).abs();
            }
        }
        out.absorb_spill(spilled, pool);
        out
    }

    /// Re-admit condensed magnitude as one fresh, independent symbol.
    ///
    /// Sound because `|Σ aᵢeᵢ| ≤ Σ|aᵢ|`: replacing several terms by a single
    /// term of their summed magnitude can only widen the set, never narrow it.
    fn absorb_spill(&mut self, spilled: i128, pool: &mut Symbols) {
        if spilled == 0 { return; }
        self.condensations += 1;
        let c = clamp_i64(spilled);
        if self.len < K {
            self.ids[self.len] = pool.fresh();
            self.coeffs[self.len] = c;
            self.len += 1;
        } else {
            // Full. The slot must be freed by absorbing an existing term into a
            // FRESH symbol -- never by adding the spill to an existing one.
            //
            // Merging spill into a live symbol id is UNSOUND, and subtly so: two
            // forms that both dump error into the same shared symbol will cancel
            // that error when subtracted, because subtraction cancels shared
            // symbols by design. The result is a band that is too NARROW, which
            // is the one failure mode that matters -- it lets a caller conclude
            // that two values agree when they do not. An earlier version of this
            // branch did exactly that, and called itself sound in a comment.
            //
            // Replacing a shared term `aₛεₛ` with a fresh term of magnitude |aₛ|
            // is a genuine over-approximation: the new symbol ranges over the
            // whole of [−1, 1] independently, so it covers everything `εₛ` could
            // have done. What is lost is the correlation with other forms, and
            // losing correlation can only widen later results, never narrow them.
            let mut min_i = 0usize;
            let mut k = 1usize;
            while k < self.len {
                if self.coeffs[k].abs() < self.coeffs[min_i].abs() { min_i = k; }
                k += 1;
            }
            let absorbed = (self.coeffs[min_i] as i128).abs() + (c as i128);
            self.ids[min_i] = pool.fresh();
            self.coeffs[min_i] = clamp_i64(absorbed);
        }
        // Terms must stay sorted by id for `merge` to pair shared symbols; a
        // fresh id is the largest yet minted, so bubble it to the end.
        let mut k = 1usize;
        while k < self.len {
            if self.ids[k - 1] > self.ids[k] {
                self.ids.swap(k - 1, k);
                self.coeffs.swap(k - 1, k);
            }
            k += 1;
        }
    }

    /// Divide by a positive integer, rounding the centre and accounting for
    /// every discarded remainder in a fresh symbol.
    ///
    /// Integer division is not exact, so this is where an integer affine form
    /// could quietly lie. It does not: the exact remainder of the centre and of
    /// every coefficient is accumulated, divided once, rounded **up**, and
    /// carried as one fresh independent symbol.
    ///
    /// Treating that rounding as a *fresh independent* source is sound but
    /// pessimistic — the real rounding is a deterministic function of the
    /// inputs, not an adversary — and in a division-heavy loop the charge
    /// accumulates every step. `examples/zono_vs_box.rs` measures a case where
    /// that makes zonotopes lose to plain interval arithmetic.
    pub fn div_round(self, d: i64, pool: &mut Symbols) -> Self {
        assert!(d > 0, "divisor must be positive");
        let q_c = div_nearest(self.center, d);
        let mut out = Self::exact(q_c);
        out.condensations = self.condensations;

        // Exact remainder bookkeeping: accumulate the true leftovers and divide
        // ONCE at the end. Charging a flat unit per term, as an earlier version
        // did, over-counts by roughly two and compounds on every step of a loop.
        let mut rem: i128 =
            ((self.center as i128) - (q_c as i128) * (d as i128)).abs();

        let mut i = 0;
        while i < self.len {
            let q = div_nearest(self.coeffs[i], d);
            if q != 0 && out.len < K {
                out.ids[out.len] = self.ids[i];
                out.coeffs[out.len] = q;
                out.len += 1;
                rem += ((self.coeffs[i] as i128) - (q as i128) * (d as i128)).abs();
            } else {
                // Dropped outright -- its whole post-division magnitude is error.
                rem += (self.coeffs[i] as i128).abs();
            }
            i += 1;
        }
        // Round the accumulated error UP, so the band never understates.
        let err = (rem + (d as i128) - 1) / (d as i128);
        out.absorb_spill(err, pool);
        out
    }

    /// Product of two forms.
    ///
    /// Multiplication is not affine, so the cross terms cannot be represented
    /// exactly. The linear part is kept and the entire nonlinear remainder is
    /// bounded by `rad(self)·rad(other)` in a fresh symbol — the standard
    /// affine-arithmetic bound, here computed in `i128` and rounded up.
    pub fn mul(self, other: Self, pool: &mut Symbols) -> Self {
        let (ca, cb) = (self.center as i128, other.center as i128);
        let mut out = Self::exact(clamp_i64(ca * cb));
        out.condensations = self.condensations + other.condensations;

        let mut spilled: i128 = 0;
        let (mut i, mut j) = (0usize, 0usize);
        while i < self.len || j < other.len {
            let (id, c) = if j >= other.len || (i < self.len && self.ids[i] < other.ids[j]) {
                let v = (self.ids[i], (self.coeffs[i] as i128) * cb);
                i += 1;
                v
            } else if i >= self.len || other.ids[j] < self.ids[i] {
                let v = (other.ids[j], (other.coeffs[j] as i128) * ca);
                j += 1;
                v
            } else {
                let v = (self.ids[i],
                         (self.coeffs[i] as i128) * cb + (other.coeffs[j] as i128) * ca);
                i += 1;
                j += 1;
                v
            };
            if c == 0 { continue; }
            if out.len < K {
                out.ids[out.len] = id;
                out.coeffs[out.len] = clamp_i64(c);
                out.len += 1;
            } else {
                spilled += c.abs();
            }
        }
        // The nonlinear remainder, bounded and rounded up.
        spilled += self.radius() * other.radius();
        out.absorb_spill(spilled, pool);
        out
    }

    /// Euclidean length of the generator vector, rounded up.
    ///
    /// Useful for reporting a magnitude without reaching for `f64::sqrt`, which
    /// is the habit this crate exists to remove.
    pub fn generator_norm_ceil(&self) -> u128 {
        let mut s: u128 = 0;
        let mut i = 0;
        while i < self.len {
            let c = (self.coeffs[i] as i128).unsigned_abs();
            s += c * c;
            i += 1;
        }
        isqrt::isqrt_ceil(s)
    }
}

fn clamp_i64(v: i128) -> i64 {
    if v > i64::MAX as i128 { i64::MAX }
    else if v < i64::MIN as i128 { i64::MIN }
    else { v as i64 }
}

/// Round-half-away-from-zero integer division. Symmetric, so a sign flip in the
/// input produces a sign flip in the output — a floor would bias one direction,
/// which is the bug this repo already fixed once in `phase_lock`.
fn div_nearest(n: i64, d: i64) -> i64 {
    let (n128, d128) = (n as i128, d as i128);
    let q = if n128 >= 0 { (2 * n128 + d128) / (2 * d128) }
            else { -((-2 * n128 + d128) / (2 * d128)) };
    clamp_i64(q)
}

/// A zonotope carried at a binary scale: the value is `z / 2ᶠ`.
///
/// [`Zono::div_round`] mints a fresh noise symbol every time it is called,
/// because integer division genuinely loses information and affine arithmetic
/// has no way to say "this error is a deterministic function of inputs I
/// already track". In a loop that divides every step, those charges never
/// cancel and the band creeps — measurably: see `examples/zono_vs_box.rs`,
/// where plain interval arithmetic beats a dividing zonotope outright.
///
/// The fix is to stop dividing. Dividing by a power of two becomes a change of
/// scale — [`Fixed::div_pow2`] increments an exponent and touches no
/// coefficient — so it is **exact, and mints nothing**. Rounding happens once,
/// at [`Fixed::rescale`], when the coefficients are about to get large, instead
/// of once per step.
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub struct Fixed<const K: usize> {
    z: Zono<K>,
    shift: u32,
}

impl<const K: usize> Fixed<K> {
    /// A value at scale zero — an ordinary integer zonotope.
    pub const fn new(z: Zono<K>) -> Self { Self { z, shift: 0 } }

    /// The underlying numerator form.
    pub const fn numerator(&self) -> &Zono<K> { &self.z }

    /// The binary exponent: the value is `numerator / 2^shift`.
    pub const fn shift(&self) -> u32 { self.shift }

    /// Divide by `2^k`, **exactly**. No rounding, no new symbol.
    pub const fn div_pow2(mut self, k: u32) -> Self {
        self.shift += k;
        self
    }

    /// Multiply by an exact integer.
    pub fn scale(mut self, k: i64) -> Self {
        self.z = self.z.scale(k);
        self
    }

    /// Largest magnitude anywhere in the form — the overflow early-warning.
    pub fn max_magnitude(&self) -> i128 {
        let mut m = (self.z.center as i128).abs();
        let mut i = 0;
        while i < self.z.len {
            let c = (self.z.coeffs[i] as i128).abs();
            if c > m { m = c; }
            i += 1;
        }
        m
    }

    /// Bring both operands to a common scale by raising the smaller.
    ///
    /// Raising is exact (a multiplication); it is lowering that would round, so
    /// this never rounds. The caller keeps magnitudes in range with
    /// [`Fixed::rescale`].
    fn aligned(self, other: Self) -> (Zono<K>, Zono<K>, u32) {
        let s = if self.shift > other.shift { self.shift } else { other.shift };
        let a = if self.shift < s { self.z.scale(1i64 << (s - self.shift)) } else { self.z };
        let b = if other.shift < s { other.z.scale(1i64 << (s - other.shift)) } else { other.z };
        (a, b, s)
    }

    /// Exact sum.
    pub fn add(self, other: Self, pool: &mut Symbols) -> Self {
        let (a, b, s) = self.aligned(other);
        Self { z: a.add(b, pool), shift: s }
    }

    /// Exact difference — the operation that decides whether two estimates
    /// have converged, and the one interval arithmetic cannot answer.
    pub fn sub(self, other: Self, pool: &mut Symbols) -> Self {
        let (a, b, s) = self.aligned(other);
        Self { z: a.sub(b, pool), shift: s }
    }

    /// Drop the scale back to `target`, rounding once with full remainder
    /// accounting. This is the only place a `Fixed` loses tightness.
    pub fn rescale(self, target: u32, pool: &mut Symbols) -> Self {
        if target >= self.shift { return self; }
        let d = 1i64 << (self.shift - target);
        Self { z: self.z.div_round(d, pool), shift: target }
    }

    /// The interval the value denotes, rounded **outward** so it never
    /// understates: the low end floors, the high end ceilings.
    pub fn interval(&self) -> (i64, i64) {
        let r = self.z.radius();
        let d = 1i128 << self.shift;
        let lo = self.z.center as i128 - r;
        let hi = self.z.center as i128 + r;
        (clamp_i64(div_floor(lo, d)), clamp_i64(div_ceil(hi, d)))
    }

    /// Total width of that interval, in units of `2^-shift`, without rounding —
    /// the honest number to compare against a true width.
    pub fn width_scaled(&self) -> i128 { 2 * self.z.radius() }
}

fn div_floor(n: i128, d: i128) -> i128 {
    let q = n / d;
    if n % d != 0 && (n < 0) != (d < 0) { q - 1 } else { q }
}

fn div_ceil(n: i128, d: i128) -> i128 {
    let q = n / d;
    if n % d != 0 && (n < 0) == (d < 0) { q + 1 } else { q }
}
