//! # exact-band
//!
//! A value that is **exact by construction**, carrying an **integer tolerance
//! band** — where a confirmation *narrows* the band rather than returning
//! pass/fail.
//!
//! No floating point. No square roots. Every comparison is exact integer
//! arithmetic.
//!
//! ## The design decision
//!
//! The radius is stored **linearly**, not squared. Storing `r²` looks natural
//! because comparisons are squared anyway, but it breaks addition:
//! `(r₁+r₂)² = r₁² + 2r₁r₂ + r₂²`, and that cross term needs an integer square
//! root. Storing `r` keeps addition exact *and* keeps comparison root-free,
//! because both sides are squared only at the moment of comparison:
//!
//! ```text
//!     overlap  ⟺  ‖c₁ − c₂‖²  ≤  (r₁ + r₂)²
//! ```
//!
//! Both sides are exact integers, so the comparison contributes **zero error**.

#![no_std]
#![forbid(unsafe_code)]
#![deny(missing_docs)]

pub mod boxed;
pub mod covering;
pub mod isqrt;
pub mod lattice;

pub use boxed::IBox;
pub use lattice::{Hex, Lattice, Z1, Z2, Z3};

/// An exact lattice value carrying an integer tolerance band.
///
/// `value` is the exact centre; `radius` is the half-width, in the same units
/// as the lattice, stored **linearly** (see the crate docs for why).
///
/// The set it denotes is the closed ball `{ p : ‖p − value‖ ≤ radius }`.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub struct Banded<T> {
    /// The exact centre. Never rounded.
    pub value: T,
    /// Half-width of the tolerance band, stored linearly.
    pub radius: u32,
}

/// The outcome of narrowing one band by another.
///
/// A contradiction is *information*, not a failure: it reports that the
/// prediction was wrong, and by how much.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash)]
pub enum Narrowed<T> {
    /// The bands overlap. Carries a sound enclosure of their intersection.
    Tightened(Banded<T>),
    /// The bands are disjoint, by `gap_sq` — the squared distance between the
    /// centres, which exceeds `(r₁ + r₂)²`.
    Contradiction {
        /// Squared distance between the two centres.
        gap_sq: u128,
    },
}

impl<T: Lattice> Banded<T> {
    /// A value with an explicit tolerance band.
    #[inline]
    pub const fn new(value: T, radius: u32) -> Self { Self { value, radius } }

    /// A value known exactly — a band of zero width.
    #[inline]
    pub const fn exact(value: T) -> Self { Self { value, radius: 0 } }

    /// Is this value known exactly? (Band collapsed to a point.)
    #[inline]
    pub const fn certain(&self) -> bool { self.radius == 0 }

    /// Squared radius, widened so it cannot overflow.
    #[inline]
    pub const fn radius_sq(&self) -> u128 { (self.radius as u128) * (self.radius as u128) }

    /// Does the band contain this exact point?
    ///
    /// Exactly `‖p − c‖² ≤ r²`.
    #[inline]
    pub fn contains(&self, point: T) -> bool {
        self.value.dist_sq(point) <= self.radius_sq()
    }

    /// Do the two bands overlap?
    ///
    /// Exactly `‖c₁ − c₂‖² ≤ (r₁ + r₂)²`. The sum is taken in `u128` before
    /// squaring, so it cannot overflow.
    #[inline]
    pub fn overlaps(&self, other: Self) -> bool {
        let reach = (self.radius as u128) + (other.radius as u128);
        self.value.dist_sq(other.value) <= reach * reach
    }

    /// Does this band lie wholly inside `other`?
    ///
    /// Exactly `‖c₁ − c₂‖ + r₁ ≤ r₂`. Rearranged to avoid a root: false unless
    /// `r₁ ≤ r₂`, then `‖c₁ − c₂‖² ≤ (r₂ − r₁)²`.
    #[inline]
    pub fn within(&self, other: Self) -> bool {
        if self.radius > other.radius { return false; }
        let slack = (other.radius - self.radius) as u128;
        self.value.dist_sq(other.value) <= slack * slack
    }

    /// Narrow this band by an observation.
    ///
    /// When the bands overlap, returns a **sound enclosure** of their
    /// intersection: the smaller of the two balls. That is always correct,
    /// because `B₁ ∩ B₂ ⊆ B₁` and `B₁ ∩ B₂ ⊆ B₂`, so either input encloses the
    /// intersection — and the smaller one is the tighter of the two valid
    /// answers. It is an over-approximation, as in all ball arithmetic.
    ///
    /// When they are disjoint, returns the squared gap rather than discarding it.
    #[inline]
    pub fn narrow(self, obs: Self) -> Narrowed<T> {
        let gap_sq = self.value.dist_sq(obs.value);
        let reach = (self.radius as u128) + (obs.radius as u128);
        if gap_sq > reach * reach {
            Narrowed::Contradiction { gap_sq }
        } else if obs.radius < self.radius {
            Narrowed::Tightened(obs)
        } else {
            Narrowed::Tightened(self)
        }
    }

    /// Widen the band by `extra`, saturating rather than wrapping.
    #[inline]
    pub const fn widen(self, extra: u32) -> Self {
        Self { value: self.value, radius: self.radius.saturating_add(extra) }
    }

    /// The band that a lattice of basis `b` induces, in `T`'s dimension.
    ///
    /// The covering radius `b√n/2` is irrational in general, so this returns the
    /// smallest **integer** radius that still covers it — found by bisection,
    /// never by `sqrt`. The result is sound: it never under-states the band.
    pub fn from_basis(value: T, basis: u32) -> Self {
        let target_x4 = covering::covering_radius_sq_x4(basis, T::DIM);
        // Smallest r with 4r² ≥ n·b².
        let (mut lo, mut hi) = (0u32, u32::MAX);
        while hi - lo > 0 {
            let mid = lo + (hi - lo) / 2;
            let m = mid as u128;
            if 4 * m * m >= target_x4 { hi = mid; } else { lo = mid + 1; }
            if lo == hi { break; }
        }
        Self { value, radius: lo }
    }
}

impl<T> Narrowed<T> {
    /// The exact magnitude of a contradiction, or `None` if the bands agreed.
    ///
    /// Rounds **up** — a contradiction is never understated.
    #[inline]
    pub fn gap(&self) -> Option<u128> {
        match self {
            Narrowed::Contradiction { gap_sq } => Some(crate::isqrt::isqrt_ceil(*gap_sq)),
            Narrowed::Tightened(_) => None,
        }
    }

    /// Did the bands agree?
    #[inline]
    pub fn agreed(&self) -> bool { matches!(self, Narrowed::Tightened(_)) }
}

impl<T> Banded<T> {
    /// Replace the centre, keeping the band.
    #[inline]
    pub fn with_value<U>(self, value: U) -> Banded<U> {
        Banded { value, radius: self.radius }
    }
}

/// Band arithmetic: half-widths add.
///
/// This is the reason the radius is stored linearly. `r = r₁ + r₂` is exact in
/// integers; the squared form would have needed a root.
impl<T> Banded<T> {
    /// Combine two bands additively, saturating the radius.
    ///
    /// The caller supplies the combined centre, because how centres combine is
    /// lattice-specific — but the band rule is universal.
    #[inline]
    pub fn combine<U>(self, other: Banded<U>, value: U) -> Banded<U> {
        Banded { value, radius: self.radius.saturating_add(other.radius) }
    }
}
