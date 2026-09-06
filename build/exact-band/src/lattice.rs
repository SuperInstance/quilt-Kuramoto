//! Exact integer lattices.
//!
//! A `Lattice` point knows how to give the **squared** Euclidean distance to
//! another point, exactly, as an integer. Squared, because that is the only form
//! that stays exact — `‖v‖` itself is irrational for most integer `v`, but
//! `‖v‖²` is always an integer.

/// A point on an exact integer lattice.
///
/// Implementors must guarantee `dist_sq` is **exact** — no rounding, no floats.
pub trait Lattice: Copy + PartialEq {
    /// Ambient dimension. Used by [`crate::covering`] to size bands.
    const DIM: u32;

    /// Exact squared Euclidean distance to `other`.
    ///
    /// Computed in `u128` so that `i32` coordinates cannot overflow.
    fn dist_sq(self, other: Self) -> u128;
}

#[inline]
fn d2(a: i32, b: i32) -> u128 {
    let d = (a as i64) - (b as i64);
    (d as i128 * d as i128) as u128
}

/// A point on the 1-D integer lattice `ℤ`.
#[derive(Copy, Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
#[allow(missing_docs)]
pub struct Z1(pub i32);

impl Z1 {
    /// A point on `ℤ`.
    pub const fn new(x: i32) -> Self { Self(x) }
}

impl Lattice for Z1 {
    const DIM: u32 = 1;
    #[inline]
    fn dist_sq(self, o: Self) -> u128 { d2(self.0, o.0) }
}

/// A point on the 2-D integer lattice `ℤ²`.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash, Default)]
pub struct Z2 {
    /// First coordinate.
    pub x: i32,
    /// Second coordinate.
    pub y: i32,
}

impl Z2 {
    /// A point on `ℤ²`.
    pub const fn new(x: i32, y: i32) -> Self { Self { x, y } }
}

impl Lattice for Z2 {
    const DIM: u32 = 2;
    #[inline]
    fn dist_sq(self, o: Self) -> u128 { d2(self.x, o.x) + d2(self.y, o.y) }
}

/// A point on the 3-D integer lattice `ℤ³`.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash, Default)]
pub struct Z3 {
    /// First coordinate.
    pub x: i32,
    /// Second coordinate.
    pub y: i32,
    /// Third coordinate.
    pub z: i32,
}

impl Z3 {
    /// A point on `ℤ³`.
    pub const fn new(x: i32, y: i32, z: i32) -> Self { Self { x, y, z } }
}

impl Lattice for Z3 {
    const DIM: u32 = 3;
    #[inline]
    fn dist_sq(self, o: Self) -> u128 { d2(self.x, o.x) + d2(self.y, o.y) + d2(self.z, o.z) }
}

/// A point on the hexagonal (Eisenstein) lattice `ℤ[ω]`, `ω = (−1 + √−3)/2`.
///
/// Represents `a + bω`. The Eisenstein norm `a² − ab + b²` is the exact squared
/// Euclidean length in the plane embedding, so exact 60° geometry costs no
/// floating point at all.
///
/// Mirrors the representation used by `SuperInstance/eisenstein`'s `E12` so the
/// two interoperate, but carries no dependency.
#[derive(Copy, Clone, Debug, PartialEq, Eq, Hash, Default)]
pub struct Hex {
    /// Coefficient of 1.
    pub a: i32,
    /// Coefficient of ω.
    pub b: i32,
}

impl Hex {
    /// The Eisenstein integer `a + bω`.
    pub const fn new(a: i32, b: i32) -> Self { Self { a, b } }

    /// The six unit directions of the hexagonal lattice, exactly.
    ///
    /// Each has norm 1. No trigonometry is involved or needed.
    /// Ordered so that `UNITS[i]` and `UNITS[i + 3]` are opposite.
    ///
    /// These are the six units of `ℤ[ω]`: `±1`, `±(1 + ω)`, `±ω`. Each has norm
    /// exactly 1. Note `(-1, 1)` is *not* a unit — its norm is 3.
    pub const UNITS: [Hex; 6] = [
        Hex { a: 1, b: 0 }, Hex { a: 1, b: 1 }, Hex { a: 0, b: 1 },
        Hex { a: -1, b: 0 }, Hex { a: -1, b: -1 }, Hex { a: 0, b: -1 },
    ];

    /// Eisenstein norm `a² − ab + b²`. Exact, always non-negative.
    #[inline]
    pub fn norm(self) -> u128 {
        let (a, b) = (self.a as i128, self.b as i128);
        (a * a - a * b + b * b) as u128
    }

    #[inline]
    /// Difference of two Eisenstein integers.
    pub const fn sub(self, o: Self) -> Self {
        Self { a: self.a.wrapping_sub(o.a), b: self.b.wrapping_sub(o.b) }
    }
}

impl Lattice for Hex {
    const DIM: u32 = 2;
    #[inline]
    fn dist_sq(self, o: Self) -> u128 {
        let (a, b) = ((self.a as i128) - (o.a as i128), (self.b as i128) - (o.b as i128));
        (a * a - a * b + b * b) as u128
    }
}

/// Interop with `SuperInstance/eisenstein`'s `E12`.
///
/// `E12` is the same mathematical object as [`Hex`] — an Eisenstein integer with
/// norm `a² − ab + b²` — so it plugs straight in. Enabled by the `eisenstein`
/// feature, which pins `default-features = false` because that crate's `snap`
/// feature pulls in `libm`/`f64` — the very thing this crate exists to avoid.
/// (`std` builds fine; an earlier note here claimed otherwise, from a reading of
/// the GitHub HEAD rather than the published 0.3.1. Withdrawn.)
///
/// One caveat inherited from upstream: `E12`'s `Add`/`Sub`/`Mul` use plain `i32`
/// arithmetic with no overflow checks — they panic in debug and wrap in release.
/// Keep coordinates well inside `i32` range, or use [`Hex`], whose `dist_sq`
/// widens to `i128` before multiplying.
#[cfg(feature = "eisenstein")]
impl Lattice for eisenstein::E12 {
    const DIM: u32 = 2;
    #[inline]
    fn dist_sq(self, o: Self) -> u128 {
        (self - o).norm() as u128
    }
}
