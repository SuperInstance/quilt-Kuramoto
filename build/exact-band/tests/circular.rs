//! Phase on a discrete circle: wraparound is arithmetic, collisions are exact.

use exact_band::{Heading, Phase};

#[test]
fn distance_takes_the_short_way_round() {
    let a = Heading::new(359);
    let b = Heading::new(1);
    assert_eq!(a.distance(b), 2, "359 deg and 1 deg are 2 apart, not 358");
    assert_eq!(b.distance(a), 2, "and the metric is symmetric");
}

#[test]
fn distance_is_never_more_than_half_the_circle() {
    for a in 0..360i64 {
        for b in 0..360i64 {
            let d = Heading::new(a).distance(Heading::new(b));
            assert!(d <= 180, "{a} to {b} gave {d}, more than half the circle");
        }
    }
}

#[test]
fn negative_and_oversized_inputs_reduce_exactly() {
    assert_eq!(Heading::new(-1).slot(), 359);
    assert_eq!(Heading::new(-361).slot(), 359);
    assert_eq!(Heading::new(720).slot(), 0);
    assert_eq!(Heading::new(361).slot(), 1);
}

#[test]
fn signed_offset_carries_direction() {
    assert_eq!(Heading::new(359).offset_to(Heading::new(1)), 2, "ahead by 2");
    assert_eq!(Heading::new(1).offset_to(Heading::new(359)), -2, "behind by 2");
    assert_eq!(Heading::new(0).offset_to(Heading::new(180)), 180, "antipode");
}

#[test]
fn offset_and_distance_agree_in_magnitude() {
    for a in 0..360i64 {
        for b in 0..360i64 {
            let (p, q) = (Heading::new(a), Heading::new(b));
            assert_eq!(p.offset_to(q).unsigned_abs() as u32, p.distance(q));
        }
    }
}

#[test]
fn advancing_wraps_without_a_special_case() {
    let p = Heading::new(350);
    assert_eq!(p.advance(20).slot(), 10);
    assert_eq!(p.advance(-360).slot(), 350);
    assert_eq!(p.advance(i64::from(u32::MAX)).slot(),
               Heading::new(350 + i64::from(u32::MAX)).slot());
}

#[test]
fn collision_is_exact_equality_not_an_epsilon() {
    assert!(Heading::new(90).collides_with(Heading::new(450)));
    assert!(!Heading::new(90).collides_with(Heading::new(91)));
}

#[test]
fn works_at_micro_degree_resolution() {
    type Micro = Phase<360_000_000>;
    let a = Micro::new(359_999_999);
    let b = Micro::new(1);
    assert_eq!(a.distance(b), 2, "wrap is exact even at 3.6e8 slots");
}

#[test]
fn a_squared_difference_would_get_this_wrong() {
    // The bug this type exists to remove, stated as a test.
    let (a, b) = (359i64, 1i64);
    let naive = (a - b) * (a - b);          // 128164
    let correct = Heading::new(a).distance(Heading::new(b));
    assert_eq!(correct, 2);
    assert!(naive > 128_000, "the naive squared form is off by two orders of magnitude");
}

// --- odd circles ---------------------------------------------------------
// These caught a real bug. `offset_to` originally compared `d > n / 2`, and
// integer division truncates, so on an odd circle the half-way point rounded
// down and offsets that were already shortest got flipped the long way round.
// Every test above used N=360, so none of them could see it.

#[test]
fn offset_magnitude_equals_distance_on_odd_circles() {
    fn check<const N: u32>() {
        for a in 0..N as i64 {
            for b in 0..N as i64 {
                let (p, q) = (Phase::<N>::new(a), Phase::<N>::new(b));
                assert_eq!(p.offset_to(q).unsigned_abs() as u32, p.distance(q),
                    "N={N} a={a} b={b}");
            }
        }
    }
    check::<5>();
    check::<7>();
    check::<9>();
    check::<361>();
}

#[test]
fn offset_never_exceeds_half_the_circle_on_odd_rings() {
    fn check<const N: u32>() {
        for a in 0..N as i64 {
            for b in 0..N as i64 {
                let d = Phase::<N>::new(a).offset_to(Phase::<N>::new(b));
                assert!(2 * d.abs() <= N as i64,
                    "N={N}: offset {d} is longer than half the circle");
            }
        }
    }
    check::<5>();
    check::<7>();
    check::<9>();
    check::<11>();
}

#[test]
fn offset_is_antisymmetric_on_odd_circles() {
    for a in 0..7i64 {
        for b in 0..7i64 {
            let (p, q) = (Phase::<7>::new(a), Phase::<7>::new(b));
            assert_eq!(p.offset_to(q), -q.offset_to(p), "N=7 a={a} b={b}");
        }
    }
}

#[test]
fn the_specific_case_that_was_wrong() {
    // N=7, from slot 0 to slot 4: the short way is backwards by 3, not
    // forwards by 4. The old code returned 4.
    assert_eq!(Phase::<7>::new(0).offset_to(Phase::<7>::new(4)), -3);
    assert_eq!(Phase::<7>::new(0).distance(Phase::<7>::new(4)), 3);
    // N=361, the even/odd boundary case.
    assert_eq!(Phase::<361>::new(0).offset_to(Phase::<361>::new(181)), -180);
}

#[test]
fn degenerate_tiny_circles_still_behave() {
    assert_eq!(Phase::<2>::new(0).distance(Phase::<2>::new(1)), 1);
    assert_eq!(Phase::<2>::new(0).offset_to(Phase::<2>::new(1)), 1);
    assert_eq!(Phase::<3>::new(0).offset_to(Phase::<3>::new(2)), -1);
    assert_eq!(Phase::<3>::new(0).distance(Phase::<3>::new(2)), 1);
}
