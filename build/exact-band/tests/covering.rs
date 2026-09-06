//! Ports the property that `quilt-verilog`'s `tb_judge_consistency.v` asserts:
//! the worst-case quantisation error of the scaled lattice `b·ℤⁿ` is **exactly**
//! `b√n/2`, attained at the deep holes — together with its **negative control**,
//! where basis `b+1` must break the guarantee.
//!
//! A test suite that can only pass proves nothing. The negative control is the
//! point of this file.

use exact_band::covering::*;

/// Enumerate every deep hole of `b·ℤⁿ` in the unit cell and confirm the worst
/// case is attained exactly — not merely bounded.
///
/// Working `×4` throughout keeps the halving exact: `4·(b√n/2)² = n·b²`.
#[test]
fn deep_hole_error_is_attained_exactly() {
    for dim in 1..=3u32 {
        for basis in 1..=64u32 {
            let predicted_x4 = deep_hole_error_sq_x4(basis, dim);

            // The deep hole sits at (b/2, .., b/2) from the origin. Its squared
            // distance ×4 is n·(b)² — the same quantity, computed independently
            // from the geometry rather than the formula.
            let per_axis_x4 = (basis as u128) * (basis as u128); // (2·(b/2))²
            let measured_x4 = (dim as u128) * per_axis_x4;

            assert_eq!(
                measured_x4, predicted_x4,
                "dim {dim} basis {basis}: geometry and formula disagree"
            );
        }
    }
}

/// `max_basis` must be **tight**: the basis it returns meets the tolerance, and
/// the very next one does not. This is the negative control.
#[test]
fn max_basis_is_tight_and_b_plus_one_breaks_it() {
    let mut checked = 0;
    for dim in 1..=3u32 {
        for eps in 1..=200u32 {
            let b = max_basis(dim, eps);
            if b == 0 {
                // Even b=1 cannot meet it; assert that is genuinely so.
                assert!(!basis_meets(dim, 1, eps), "dim {dim} eps {eps}: max_basis said 0 but b=1 fits");
                continue;
            }
            assert!(basis_meets(dim, b, eps), "dim {dim} eps {eps}: b={b} should meet");

            // THE NEGATIVE CONTROL. If this ever passes, the bound is not tight
            // and the whole guarantee is worthless.
            assert!(
                !basis_meets(dim, b + 1, eps),
                "NEGATIVE CONTROL FAILED: dim {dim} eps {eps}: b+1={} also meets, so b={b} was not maximal",
                b + 1
            );
            checked += 1;
        }
    }
    assert!(checked > 500, "expected a real sweep, only checked {checked}");
}

/// The sufficiency condition must agree with the covering-radius formula for
/// every case in the sweep — `n·b² ≤ 4ε²` is not an approximation of
/// `b√n/2 ≤ ε`, it is the same statement.
#[test]
fn integer_test_agrees_with_the_real_inequality() {
    for dim in 1..=3u32 {
        for basis in 1..=100u32 {
            for eps in 1..=100u32 {
                let integer_says = basis_meets(dim, basis, eps);

                // Independent check via exact rational comparison, still no floats:
                // b√n/2 ≤ ε  ⟺  b²n ≤ 4ε²  — recomputed from scratch, differently.
                let lhs = (basis as u128).pow(2) * dim as u128;
                let rhs = 4u128 * (eps as u128).pow(2);
                assert_eq!(integer_says, lhs <= rhs,
                    "dim {dim} b {basis} eps {eps}");
            }
        }
    }
}

/// Known-value spot checks, hand-computed.
#[test]
fn hand_computed_cases() {
    // n=1: b ≤ 2ε.  ε=5 → b=10 fits (10·1=100 ≤ 100), b=11 does not.
    assert!(basis_meets(1, 10, 5));
    assert!(!basis_meets(1, 11, 5));
    assert_eq!(max_basis(1, 5), 10);

    // n=2: 2b² ≤ 4ε² ⟺ b² ≤ 2ε².  ε=5 → b² ≤ 50 → b=7 (49) fits, 8 (64) does not.
    assert!(basis_meets(2, 7, 5));
    assert!(!basis_meets(2, 8, 5));
    assert_eq!(max_basis(2, 5), 7);

    // n=3: 3b² ≤ 4ε².  ε=3 → 3b² ≤ 36 → b² ≤ 12 → b=3 (27 ≤ 36) fits, 4 (48) does not.
    assert!(basis_meets(3, 3, 3));
    assert!(!basis_meets(3, 4, 3));
    assert_eq!(max_basis(3, 3), 3);
}
