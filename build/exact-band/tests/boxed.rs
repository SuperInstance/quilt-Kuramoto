//! `IBox` narrowing is *exact*, not an over-approximation — so it admits a much
//! stronger test than the ball type: the result must equal the true set
//! intersection, point for point, not merely contain it.

use exact_band::IBox;

#[test]
fn intersection_is_exact_not_an_over_approximation() {
    let mut checked = 0u32;
    for l1 in -6..=6i64 { for h1 in l1..=6i64 {
    for l2 in -6..=6i64 { for h2 in l2..=6i64 {
        let a = IBox::<1>::new([l1], [h1]);
        let b = IBox::<1>::new([l2], [h2]);
        let got = a.narrow(b);
        for p in -12..=12i64 {
            let truth = a.contains([p]) && b.contains([p]);
            let mine  = got.is_some_and(|g| g.contains([p]));
            assert_eq!(truth, mine,
                "[{l1},{h1}] ∩ [{l2},{h2}] at {p}: exact intersection expected");
            checked += 1;
        }
    }}}}
    assert!(checked > 10_000, "expected a real sweep, checked {checked}");
}

#[test]
fn narrowing_never_widens_on_any_axis() {
    let a = IBox::<2>::new([0, 0], [10, 10]);
    let b = IBox::<2>::new([3, -5], [7, 4]);
    let n = a.narrow(b).expect("these overlap");
    assert_eq!(n.lo, [3, 0]);
    assert_eq!(n.hi, [7, 4]);
    for i in 0..2 {
        assert!(n.width(i).unwrap() <= a.width(i).unwrap());
        assert!(n.width(i).unwrap() <= b.width(i).unwrap());
    }
}

#[test]
fn narrowing_can_reach_certainty() {
    let a = IBox::<1>::new([5], [9]);
    let b = IBox::<1>::new([9], [12]);
    let n = a.narrow(b).expect("they touch at 9");
    assert!(n.certain(), "a single surviving point means the value is now known");
    assert_eq!(n.lo, [9]);
}

#[test]
fn disjoint_boxes_report_where_and_by_how_much() {
    let a = IBox::<2>::new([0, 0], [4, 4]);
    let b = IBox::<2>::new([2, 20], [6, 24]);   // overlaps on axis 0, not axis 1
    assert!(a.narrow(b).is_none());
    let (axis, gap) = a.disagreement(b).expect("they are disjoint");
    assert_eq!(axis, 1, "axis 1 is the one that disagrees");
    assert_eq!(gap, 16, "hi=4, lo=20 → gap of 16");
}

#[test]
fn agreeing_boxes_report_no_disagreement() {
    let a = IBox::<2>::new([0, 0], [4, 4]);
    let b = IBox::<2>::new([2, 2], [6, 6]);
    assert!(a.narrow(b).is_some());
    assert_eq!(a.disagreement(b), None);
}

#[test]
fn repeated_confirmation_monotonically_tightens() {
    // The predict-and-confirm loop: each observation can only shrink the band.
    let mut band = IBox::<1>::centered([100], 50);
    let observations = [
        IBox::<1>::centered([102], 30),
        IBox::<1>::centered([99], 12),
        IBox::<1>::centered([101], 5),
    ];
    let mut last = band.width(0).unwrap();
    for obs in observations {
        band = band.narrow(obs).expect("all consistent");
        let w = band.width(0).unwrap();
        assert!(w <= last, "confirmation must never widen: {w} > {last}");
        last = w;
    }
    assert!(last < 12, "three confirmations should have tightened it well below the start");
}

#[test]
fn centered_and_add_saturate_rather_than_wrapping() {
    let b = IBox::<1>::centered([i64::MAX - 2], 100);
    assert_eq!(b.hi, [i64::MAX]);
    let c = IBox::<1>::new([i64::MAX - 1], [i64::MAX]);
    assert_eq!((c + c).hi, [i64::MAX]);
}

#[test]
fn empty_is_never_certain() {
    let e = IBox::<1>::new([5], [3]);
    assert!(e.is_empty());
    assert!(!e.certain());
}
