//! `isqrt` is verified against its *defining property*, not against a
//! floating-point reference — using `f64::sqrt` as the oracle would import the
//! very imprecision this crate exists to avoid.
//!
//! The defining property is exact and self-contained: `r² ≤ n < (r+1)²`.

use exact_band::isqrt::{isqrt, isqrt_ceil};

#[test]
fn floor_property_holds_exhaustively_on_a_dense_range() {
    for n in 0u128..100_000 {
        let r = isqrt(n);
        assert!(r * r <= n, "isqrt({n}) = {r}: r² = {} exceeds n", r * r);
        assert!(n < (r + 1) * (r + 1), "isqrt({n}) = {r}: (r+1)² = {} does not exceed n", (r + 1) * (r + 1));
    }
}

#[test]
fn floor_property_holds_at_extremes_and_near_perfect_squares() {
    // Every perfect square up to 2^32, plus its neighbours.
    for k in 0u128..70_000 {
        let sq = k * k;
        assert_eq!(isqrt(sq), k, "perfect square {sq} must give exactly {k}");
        if sq > 0 {
            assert_eq!(isqrt(sq - 1), k - 1, "just below {k}²");
        }
        // k=0 is the one exception: isqrt(1) = 1, not 0.
        if k > 0 {
            assert_eq!(isqrt(sq + 1), k, "just above {k}²");
        } else {
            assert_eq!(isqrt(1), 1);
        }
    }

    // The full u128 range, where a float oracle would be hopeless.
    assert_eq!(isqrt(u128::MAX), (1u128 << 64) - 1);
    let big = (1u128 << 127) - 1;
    let r = isqrt(big);
    assert!(r * r <= big);
    assert!(big / (r + 1) < (r + 1));
}

#[test]
fn ceil_never_understates() {
    for n in 0u128..100_000 {
        let c = isqrt_ceil(n);
        assert!(c * c >= n, "isqrt_ceil({n}) = {c} understates: c² = {} < n", c * c);
        if c > 0 {
            assert!((c - 1) * (c - 1) < n, "isqrt_ceil({n}) = {c} is not minimal");
        }
    }
}

/// A contradiction's reported magnitude must never be smaller than the truth —
/// understating a disagreement is the one error that matters here.
#[test]
fn contradiction_gap_never_understates() {
    use exact_band::{Banded, Z1, Narrowed};
    for d in 0..500i32 {
        let a = Banded::new(Z1::new(0), 1);
        let b = Banded::new(Z1::new(d), 1);
        if let Narrowed::Contradiction { gap_sq } = a.narrow(b) {
            let gap = a.narrow(b).gap().unwrap();
            assert!(gap * gap >= gap_sq,
                "reported gap {gap} understates true squared gap {gap_sq}");
            assert_eq!(gap, d as u128, "centres are {d} apart on ℤ, so the gap is exactly {d}");
        }
    }
}
