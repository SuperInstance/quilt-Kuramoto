//! Band algebra: containment, overlap, narrowing, and the soundness property
//! that makes `narrow()` trustworthy.

use exact_band::*;

#[test]
fn exact_values_are_certain() {
    let p = Banded::exact(Z2::new(3, 4));
    assert!(p.certain());
    assert!(p.contains(Z2::new(3, 4)));
    assert!(!p.contains(Z2::new(3, 5)));
}

#[test]
fn containment_is_the_squared_form_judge() {
    let b = Banded::new(Z2::new(0, 0), 5);
    // 3-4-5 triangle: exactly on the boundary, and must be INSIDE (≤, not <).
    assert!(b.contains(Z2::new(3, 4)));
    assert!(b.contains(Z2::new(5, 0)));
    // One unit further out is not.
    assert!(!b.contains(Z2::new(4, 4)));   // 32 > 25
    assert!(!b.contains(Z2::new(6, 0)));   // 36 > 25
}

#[test]
fn overlap_is_symmetric_and_boundary_inclusive() {
    let a = Banded::new(Z1::new(0), 3);
    let b = Banded::new(Z1::new(7), 4);   // touching exactly: 7 == 3+4
    assert!(a.overlaps(b));
    assert!(b.overlaps(a));

    let c = Banded::new(Z1::new(8), 4);   // 8 > 3+4
    assert!(!a.overlaps(c));
    assert!(!c.overlaps(a));
}

#[test]
fn narrowing_tightens_and_never_widens() {
    let predicted = Banded::new(Z2::new(100, 40), 5);
    let observed  = Banded::new(Z2::new(102, 41), 2);

    match predicted.narrow(observed) {
        Narrowed::Tightened(b) => {
            assert_eq!(b.radius, 2, "should adopt the tighter band");
            assert!(b.radius <= predicted.radius, "narrowing must never widen");
        }
        Narrowed::Contradiction { .. } => panic!("these bands overlap"),
    }
}

#[test]
fn contradiction_carries_the_disagreement() {
    let predicted = Banded::new(Z1::new(0), 2);
    let observed  = Banded::new(Z1::new(10), 3);   // 10 > 2+3

    match predicted.narrow(observed) {
        Narrowed::Contradiction { gap_sq } => {
            assert_eq!(gap_sq, 100, "the gap is information, not a failure");
        }
        Narrowed::Tightened(_) => panic!("these bands are disjoint"),
    }
}

/// **The soundness property.** `narrow()` returns an over-approximation, so any
/// point in the true intersection must still be inside the returned band.
/// This is what makes the result safe to keep using.
#[test]
fn narrow_result_encloses_the_true_intersection() {
    let mut checked = 0u32;
    for cx in -6..=6i32 {
        for r1 in 0..=6u32 {
            for r2 in 0..=6u32 {
                let a = Banded::new(Z1::new(0), r1);
                let b = Banded::new(Z1::new(cx), r2);
                if let Narrowed::Tightened(out) = a.narrow(b) {
                    // Every integer point in BOTH inputs must be in the output.
                    for p in -20..=20i32 {
                        let pt = Z1::new(p);
                        if a.contains(pt) && b.contains(pt) {
                            assert!(out.contains(pt),
                                "unsound: {p} is in both inputs but not in the narrowed band \
                                 (a=0±{r1}, b={cx}±{r2}, out={}±{})", out.value.0, out.radius);
                            checked += 1;
                        }
                    }
                }
            }
        }
    }
    assert!(checked > 200, "expected a real sweep, only checked {checked}");
}

#[test]
fn within_implies_overlap() {
    for cx in -8..=8i32 {
        for r1 in 0..=8u32 {
            for r2 in 0..=8u32 {
                let a = Banded::new(Z1::new(cx), r1);
                let b = Banded::new(Z1::new(0), r2);
                if a.within(b) {
                    assert!(a.overlaps(b), "a ⊆ b must imply a ∩ b ≠ ∅");
                }
            }
        }
    }
}

#[test]
fn hex_lattice_has_six_exact_unit_directions() {
    let origin = Hex::new(0, 0);
    for (i, u) in Hex::UNITS.iter().enumerate() {
        assert_eq!(u.norm(), 1, "unit {i} must have norm exactly 1");
        assert_eq!(origin.dist_sq(*u), 1, "unit {i} must be at squared distance 1");
    }
    // Exact 60° geometry, no trigonometry.
    // Opposite units are 2 apart (squared 4); adjacent units are 1 apart.
    for i in 0..3 {
        assert_eq!(Hex::UNITS[i].dist_sq(Hex::UNITS[i + 3]), 4, "units {i} and {} must be opposite", i + 3);
    }
    for i in 0..6 {
        let next = Hex::UNITS[(i + 1) % 6];
        assert_eq!(Hex::UNITS[i].dist_sq(next), 1,
            "adjacent units {i} and {} are 60° apart, so exactly 1 apart", (i + 1) % 6);
    }
}

#[test]
fn bands_add_linearly_which_is_the_whole_point() {
    let a = Banded::new(Z1::new(0), 3);
    let b = Banded::new(Z1::new(0), 4);
    let c = a.combine(b, Z1::new(0));
    // 3 + 4 = 7 exactly. Had we stored r², this would have needed √(9·16).
    assert_eq!(c.radius, 7);
}

#[test]
fn widen_saturates_rather_than_wrapping() {
    let a = Banded::new(Z1::new(0), u32::MAX - 1);
    assert_eq!(a.widen(100).radius, u32::MAX);
}

#[test]
fn from_basis_is_sound_never_understating_the_band() {
    for basis in 1..=40u32 {
        let b: Banded<Z3> = Banded::from_basis(Z3::new(0, 0, 0), basis);
        // 4r² ≥ n·b²  — the band must cover the true covering radius.
        let r = b.radius as u128;
        assert!(4 * r * r >= exact_band::covering::covering_radius_sq_x4(basis, 3),
            "basis {basis}: radius {} understates the covering radius", b.radius);
    }
}
