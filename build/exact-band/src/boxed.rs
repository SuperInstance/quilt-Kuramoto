//! Axis-aligned integer boxes — bands that genuinely narrow.
//!
//! [`Banded`](crate::Banded) is a Euclidean ball, and balls are **not closed
//! under intersection**: two overlapping balls meet in a lens, not a ball. So
//! `Banded::narrow` can only return one of its inputs — sound, but it never
//! produces a band tighter than both.
//!
//! Boxes do not have that problem. The intersection of two axis-aligned boxes is
//! an axis-aligned box, exactly:
//!
//! ```text
//!     lo = max(lo₁, lo₂)        hi = min(hi₁, hi₂)
//! ```
//!
//! Integer `max` and `min`, per axis. No rounding, no approximation, and the
//! empty case (`lo > hi` on any axis) *is* the contradiction test — it comes for
//! free, with no separate overlap predicate.
//!
//! Use [`IBox`] when you want a band that really tightens under confirmation.
//! Use [`Banded`](crate::Banded) when you want the single-radius Euclidean judge.

/// An axis-aligned box on `ℤⁿ`, inclusive on both bounds.
///
/// Invariant: a box is *inhabited* iff `lo[i] <= hi[i]` for every axis.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub struct IBox<const N: usize> {
    /// Inclusive lower bound per axis.
    pub lo: [i64; N],
    /// Inclusive upper bound per axis.
    pub hi: [i64; N],
}

impl<const N: usize> IBox<N> {
    /// A box from explicit bounds. May be empty if any `lo > hi`.
    #[inline]
    pub const fn new(lo: [i64; N], hi: [i64; N]) -> Self { Self { lo, hi } }

    /// A single exact point — a box of zero width on every axis.
    #[inline]
    pub const fn point(p: [i64; N]) -> Self { Self { lo: p, hi: p } }

    /// A centre with a uniform integer half-width, saturating at the edges.
    pub fn centered(centre: [i64; N], radius: u32) -> Self {
        let r = radius as i64;
        let mut lo = [0i64; N];
        let mut hi = [0i64; N];
        let mut i = 0;
        while i < N {
            lo[i] = centre[i].saturating_sub(r);
            hi[i] = centre[i].saturating_add(r);
            i += 1;
        }
        Self { lo, hi }
    }

    /// Is the box empty — i.e. a contradiction?
    #[inline]
    pub fn is_empty(&self) -> bool {
        (0..N).any(|i| self.lo[i] > self.hi[i])
    }

    /// Is every bound tight — the value known exactly?
    #[inline]
    pub fn certain(&self) -> bool {
        !self.is_empty() && (0..N).all(|i| self.lo[i] == self.hi[i])
    }

    /// Does the box contain this exact point?
    #[inline]
    pub fn contains(&self, p: [i64; N]) -> bool {
        (0..N).all(|i| self.lo[i] <= p[i] && p[i] <= self.hi[i])
    }

    /// Width along one axis, or `None` if the box is empty there.
    #[inline]
    pub fn width(&self, axis: usize) -> Option<u64> {
        if self.lo[axis] > self.hi[axis] { return None; }
        Some((self.hi[axis] as i128 - self.lo[axis] as i128) as u64)
    }

    /// **Exact intersection.** This is the real narrowing operation.
    ///
    /// Returns `None` when the boxes are disjoint — which is precisely a
    /// contradiction, detected for free rather than by a separate predicate.
    ///
    /// The result is exact, not an over-approximation: boxes are closed under
    /// intersection, so nothing is rounded or widened.
    #[inline]
    pub fn narrow(self, other: Self) -> Option<Self> {
        let mut lo = [0i64; N];
        let mut hi = [0i64; N];
        for i in 0..N {
            lo[i] = if self.lo[i] > other.lo[i] { self.lo[i] } else { other.lo[i] };
            hi[i] = if self.hi[i] < other.hi[i] { self.hi[i] } else { other.hi[i] };
            if lo[i] > hi[i] { return None; }
        }
        Some(Self { lo, hi })
    }

    /// Which axis disagrees, and by how much, when [`narrow`](Self::narrow)
    /// returns `None`.
    ///
    /// A contradiction is information: this says *where* the prediction was
    /// wrong and by how far. Returns `None` when the boxes do intersect.
    pub fn disagreement(self, other: Self) -> Option<(usize, u64)> {
        let mut worst: Option<(usize, u64)> = None;
        for i in 0..N {
            let lo = self.lo[i].max(other.lo[i]) as i128;
            let hi = self.hi[i].min(other.hi[i]) as i128;
            if lo > hi {
                let gap = (lo - hi) as u64;
                let better = match worst { None => true, Some((_, g)) => gap > g };
                if better { worst = Some((i, gap)); }
            }
        }
        worst
    }

    /// Grow every bound outward by `extra`, saturating.
    pub fn widen(self, extra: u32) -> Self {
        let e = extra as i64;
        let mut lo = [0i64; N];
        let mut hi = [0i64; N];
        let mut i = 0;
        while i < N {
            lo[i] = self.lo[i].saturating_sub(e);
            hi[i] = self.hi[i].saturating_add(e);
            i += 1;
        }
        Self { lo, hi }
    }
}

/// Minkowski sum: bounds add per axis, saturating.
///
/// This is the interval-arithmetic rule, and it is **sound but not tight** — if
/// the same uncertainty is counted along two paths it gets added twice (the
/// classic dependency problem). An affine-arithmetic bound would be tighter but
/// needs real-valued noise coefficients, i.e. floats, so it is deliberately out
/// of scope.
impl<const N: usize> core::ops::Add for IBox<N> {
    type Output = Self;
    fn add(self, other: Self) -> Self {
        let mut lo = [0i64; N];
        let mut hi = [0i64; N];
        let mut i = 0;
        while i < N {
            lo[i] = self.lo[i].saturating_add(other.lo[i]);
            hi[i] = self.hi[i].saturating_add(other.hi[i]);
            i += 1;
        }
        Self { lo, hi }
    }
}
