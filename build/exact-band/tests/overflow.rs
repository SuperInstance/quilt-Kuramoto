//! Overflow honesty.
//!
//! `Hex::dist_sq` widens to `i128` before multiplying, so the Eisenstein norm
//! `a² − ab + b²` is correct across the entire `i32` domain — including the
//! adversarial corner `(i32::MIN, i32::MAX)`, where the true norm is
//! `13_835_058_048_839_712_769`, comfortably beyond `i64::MAX`.
//!
//! This matters because the published `eisenstein` 0.3.1 computes that norm in
//! `i64`. In release the wrap happens to land on the right `u64` bits; in debug
//! it **panics** (`eisenstein-0.3.1/src/lib.rs:79`). A crate offering "exact
//! arithmetic for safety-critical systems" should not change answer with the
//! build profile, so this crate does not.

use exact_band::{Hex, Lattice};

/// The exact norm at the worst `i32` corner, computed independently here.
fn true_norm(a: i32, b: i32) -> u128 {
    let (a, b) = (a as i128, b as i128);
    (a * a - a * b + b * b) as u128
}

#[test]
fn hex_norm_is_correct_at_the_i32_extremes() {
    let corners = [
        (i32::MIN, i32::MAX), (i32::MAX, i32::MIN),
        (i32::MIN, i32::MIN), (i32::MAX, i32::MAX),
        (i32::MIN, 0), (0, i32::MIN), (i32::MAX, 0), (0, i32::MAX),
    ];
    for (a, b) in corners {
        assert_eq!(Hex::new(a, b).norm(), true_norm(a, b),
            "norm wrong at ({a}, {b})");
    }
    // The specific value the i64 path cannot hold.
    assert_eq!(Hex::new(i32::MIN, i32::MAX).norm(), 13_835_058_048_839_712_769u128);
    assert!(13_835_058_048_839_712_769u128 > i64::MAX as u128,
        "if this ever fails the test has lost its point");
}

#[test]
fn dist_sq_is_correct_at_the_extremes_too() {
    let a = Hex::new(i32::MIN, i32::MAX);
    let b = Hex::new(i32::MAX, i32::MIN);
    // Computed independently, in i128.
    let (da, db) = (i32::MIN as i128 - i32::MAX as i128, i32::MAX as i128 - i32::MIN as i128);
    let expected = (da * da - da * db + db * db) as u128;
    assert_eq!(a.dist_sq(b), expected);
}

/// Growing a band saturates; it must never wrap to something *smaller*, which
/// would silently under-state uncertainty.
#[test]
fn growing_a_band_never_wraps_to_something_smaller() {
    use exact_band::{Banded, Z1};
    let b = Banded::new(Z1::new(0), u32::MAX - 3);
    for extra in [1u32, 10, u32::MAX] {
        let w = b.widen(extra);
        assert!(w.radius >= b.radius, "widen({extra}) shrank the band");
        assert_eq!(w.radius, b.radius.saturating_add(extra));
    }
}
