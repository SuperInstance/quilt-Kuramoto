//! Cross-implementation conformance, in the spirit of this ecosystem's
//! "byte-exact across substrates" discipline.
//!
//! This crate's [`Hex`] and the published `eisenstein::E12` are the same
//! mathematical object. If they ever disagree on a distance, one of them is
//! wrong. Run with `--features eisenstein`.
#![cfg(feature = "eisenstein")]

use exact_band::{Hex, Lattice};
use eisenstein::E12;

#[test]
fn hex_and_e12_agree_on_every_distance_in_a_sweep() {
    let mut checked = 0u32;
    for a1 in -12..=12i32 {
        for b1 in -12..=12i32 {
            for a2 in -6..=6i32 {
                for b2 in -6..=6i32 {
                    let mine = Hex::new(a1, b1).dist_sq(Hex::new(a2, b2));
                    let theirs = E12::new(a1, b1).dist_sq(E12::new(a2, b2));
                    assert_eq!(mine, theirs,
                        "disagreement at ({a1},{b1}) -> ({a2},{b2})");
                    checked += 1;
                }
            }
        }
    }
    assert!(checked > 100_000, "expected a real sweep, checked {checked}");
}

#[test]
fn both_agree_the_six_units_have_norm_one() {
    for u in E12::directions() {
        assert_eq!(u.dist_sq(E12::new(0, 0)), 1);
    }
    for u in Hex::UNITS {
        assert_eq!(u.norm(), 1);
    }
}

/// Our `UNITS` are in **angular** order, so consecutive entries are adjacent
/// (exactly 1 apart). Upstream's `directions()` is not ordered that way — it is
/// the same set, listed differently. Documented here so nobody assumes the two
/// arrays are index-compatible.
#[test]
fn our_units_are_angularly_ordered_upstreams_are_not() {
    for i in 0..6 {
        assert_eq!(Hex::UNITS[i].dist_sq(Hex::UNITS[(i + 1) % 6]), 1,
            "our UNITS must be in angular order");
    }
    let up = E12::directions();
    let adjacent_pairs = (0..6)
        .filter(|&i| up[i].dist_sq(up[(i + 1) % 6]) == 1)
        .count();
    assert!(adjacent_pairs < 6,
        "upstream directions() turned out to be angularly ordered after all - \
         update this test and the doc comment on Hex::UNITS");
}

#[test]
fn banded_works_over_upstream_e12() {
    use exact_band::{Banded, Narrowed};
    let predicted = Banded::new(E12::new(10, 4), 3);
    let observed  = Banded::new(E12::new(11, 4), 1);
    match predicted.narrow(observed) {
        Narrowed::Tightened(b) => assert_eq!(b.radius, 1),
        Narrowed::Contradiction { .. } => panic!("should overlap"),
    }
}
