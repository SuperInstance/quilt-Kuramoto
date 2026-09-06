//! Choosing a lattice basis from a tolerance, with no square roots.
//!
//! The covering radius of the scaled integer lattice `b·ℤⁿ` is **exactly**
//! `b√n / 2`, attained at the deep holes — the cube centres, equidistant from
//! all `2ⁿ` corners. So representing values on that lattice meets a tolerance
//! `ε` for every reachable point iff
//!
//! ```text
//!     b√n / 2  ≤  ε
//! ```
//!
//! Squaring both sides clears the root and leaves an exact integer test:
//!
//! ```text
//!     n · b²  ≤  4ε²
//! ```
//!
//! Every function here is integer-only.

/// Four times the squared covering radius of `b·ℤⁿ`, exactly: `4·(b√n/2)² = n·b²`.
///
/// Scaled by 4 so the halving never needs a division and never loses a bit.
#[inline]
pub const fn covering_radius_sq_x4(basis: u32, dim: u32) -> u128 {
    let b = basis as u128;
    (dim as u128) * b * b
}

/// Does basis `b` on an `n`-dimensional lattice meet tolerance `eps`?
///
/// Exactly `n·b² ≤ 4ε²`. No roots, no floats.
#[inline]
pub const fn basis_meets(dim: u32, basis: u32, eps: u32) -> bool {
    let e = eps as u128;
    covering_radius_sq_x4(basis, dim) <= 4 * e * e
}

/// The largest basis that still meets tolerance `eps` in `dim` dimensions.
///
/// Found by integer bisection — never `sqrt`. Returns 0 when even `b = 1`
/// cannot meet the tolerance (i.e. `eps` is too tight for any integer lattice).
pub const fn max_basis(dim: u32, eps: u32) -> u32 {
    if !basis_meets(dim, 1, eps) { return 0; }
    let (mut lo, mut hi) = (1u32, u32::MAX);
    // Invariant: `lo` always meets, `hi` never does.
    while hi - lo > 1 {
        let mid = lo + (hi - lo) / 2;
        if basis_meets(dim, mid, eps) { lo = mid; } else { hi = mid; }
    }
    lo
}

/// The exact squared distance from a deep hole to the nearest lattice point,
/// scaled by 4: `4·(b√n/2)² = n·b²`.
///
/// This is the worst case, and it is *attained*, which is why [`max_basis`]
/// is tight rather than conservative.
#[inline]
pub const fn deep_hole_error_sq_x4(basis: u32, dim: u32) -> u128 {
    covering_radius_sq_x4(basis, dim)
}
