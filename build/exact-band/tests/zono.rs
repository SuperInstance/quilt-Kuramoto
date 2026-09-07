//! Integer zonotopes: the dependency problem, and whether this actually fixes it.
//!
//! Soundness is the property that matters. A tighter band that is ever WRONG is
//! worse than a wide one, so most of this file carries a concrete value through
//! the same operations in exact rational arithmetic and checks it stays inside
//! the computed enclosure.

use exact_band::{IBox, Symbols, Zono};

type Z = Zono<16>;

/// Exact rational over i128 — the reference the forms are checked against.
#[derive(Copy, Clone, Debug)]
struct Q(i128, i128);

impl Q {
    fn int(n: i128) -> Q { Q(n, 1) }
    fn div_int(self, d: i128) -> Q { Q(self.0, self.1 * d).norm() }
    fn norm(self) -> Q {
        let g = gcd(self.0.abs(), self.1.abs()).max(1);
        let (mut n, mut d) = (self.0 / g, self.1 / g);
        if d < 0 { n = -n; d = -d; }
        Q(n, d)
    }
    fn le(self, other: i64) -> bool { self.0 <= (other as i128) * self.1 }
    fn ge(self, other: i64) -> bool { self.0 >= (other as i128) * self.1 }
}

fn gcd(a: i128, b: i128) -> i128 { if b == 0 { a } else { gcd(b, a % b) } }

fn assert_encloses(z: &Z, truth: Q, what: &str) {
    let (lo, hi) = z.interval();
    assert!(truth.ge(lo) && truth.le(hi),
        "{what}: truth {}/{} escaped [{lo}, {hi}]", truth.0, truth.1);
}

// ---- the headline: dependency is tracked, not double-counted ---------------

#[test]
fn subtracting_a_value_from_itself_is_exactly_zero() {
    let mut p = Symbols::new();
    let x = Z::uncertain(10, 1, &mut p);
    let d = x.sub(x, &mut p);
    assert_eq!(d.center(), 0);
    assert_eq!(d.radius(), 0, "x - x must be exactly zero, not a two-wide band");
    assert!(d.is_exact());

    // What interval arithmetic does with the same question.
    let b = IBox::<1>::new([9], [11]);
    let diff_lo = b.lo[0] - b.hi[0];
    let diff_hi = b.hi[0] - b.lo[0];
    assert_eq!((diff_lo, diff_hi), (-2, 2),
        "the box answer is [-2, 2] -- sound, and wrong by two units of width");
}

#[test]
fn adding_then_removing_a_shared_term_restores_the_original_exactly() {
    let mut p = Symbols::new();
    let x = Z::uncertain(100, 7, &mut p);
    let y = Z::uncertain(-40, 3, &mut p);
    let back = x.add(y, &mut p).sub(y, &mut p);
    assert_eq!(back.center(), x.center());
    assert_eq!(back.radius(), x.radius());
    assert_eq!(back.coeff_of(1), x.coeff_of(1));
}

#[test]
fn independent_sources_do_not_cancel() {
    // Two separately-measured values are NOT the same value, and subtracting
    // them must widen. Cancelling here would be unsound -- the failure mode
    // that matters most, because it produces a band that is too narrow.
    let mut p = Symbols::new();
    let a = Z::uncertain(10, 1, &mut p);
    let b = Z::uncertain(10, 1, &mut p);
    let d = a.sub(b, &mut p);
    assert_eq!(d.center(), 0);
    assert_eq!(d.radius(), 2, "independent uncertainties must add, not cancel");
}

#[test]
fn a_shared_source_cancels_only_in_proportion() {
    // Two readings from one sensor, scaled differently: 3x and 5x. Their
    // difference should carry exactly 2x the source uncertainty.
    let mut p = Symbols::new();
    let s = p.fresh();
    let a = Z::from_symbol(0, s, 3);
    let b = Z::from_symbol(0, s, 5);
    assert_eq!(b.sub(a, &mut p).radius(), 2);
    assert_eq!(a.add(b, &mut p).radius(), 8);
}

// ---- soundness against an exact reference ---------------------------------

#[test]
fn linear_chains_stay_sound_and_exact_for_every_extreme_assignment() {
    // For a purely linear computation the zonotope IS the reachable set, so the
    // interval endpoints must be attained exactly at some +-1 assignment.
    for e0 in [-1i128, 1] {
        for e1 in [-1i128, 1] {
            let mut p = Symbols::new();
            let x = Z::uncertain(50, 4, &mut p);      // symbol 1
            let y = Z::uncertain(-20, 6, &mut p);     // symbol 2
            let r = x.scale(3).add(y.scale(-2), &mut p).shift(7).sub(x, &mut p);

            // truth = 3(50 + 4e0) - 2(-20 + 6e1) + 7 - (50 + 4e0)
            let t = Q::int(3 * (50 + 4 * e0) - 2 * (-20 + 6 * e1) + 7 - (50 + 4 * e0));
            assert_encloses(&r, t, "linear chain");
        }
    }
    // and the width is exactly |2*4| + |-2*6| = 20
    let mut p = Symbols::new();
    let x = Z::uncertain(50, 4, &mut p);
    let y = Z::uncertain(-20, 6, &mut p);
    let r = x.scale(3).add(y.scale(-2), &mut p).shift(7).sub(x, &mut p);
    assert_eq!(r.radius(), 20, "linear result must be exactly tight");
}

#[test]
fn division_stays_sound_over_a_grid() {
    for num in [-97i128, -1, 0, 1, 50, 1234] {
        for rad in [0i64, 1, 7, 100] {
            for d in [1i64, 2, 3, 7, 16, 1000] {
                for e in [-1i128, 0, 1] {
                    let mut p = Symbols::new();
                    let x = Z::uncertain(num as i64, rad as u32, &mut p);
                    let q = x.div_round(d, &mut p);
                    let truth = Q::int(num + (rad as i128) * e).div_int(d as i128);
                    assert_encloses(&q, truth, "div_round");
                }
            }
        }
    }
}

#[test]
fn multiplication_stays_sound_over_a_grid() {
    for a in [-30i128, -1, 0, 5, 88] {
        for b in [-7i128, 0, 3, 41] {
            for ra in [0i64, 2, 9] {
                for rb in [0i64, 1, 6] {
                    for ea in [-1i128, 1] {
                        for eb in [-1i128, 1] {
                            let mut p = Symbols::new();
                            let x = Z::uncertain(a as i64, ra as u32, &mut p);
                            let y = Z::uncertain(b as i64, rb as u32, &mut p);
                            let z = x.mul(y, &mut p);
                            let truth = Q::int((a + (ra as i128) * ea) * (b + (rb as i128) * eb));
                            assert_encloses(&z, truth, "mul");
                        }
                    }
                }
            }
        }
    }
}

#[test]
fn a_single_multiplication_does_not_beat_the_box_and_the_docs_say_so() {
    // An honest negative. For ONE isolated square, interval arithmetic is
    // already optimal -- x*x on [9, 11] is monotone on the positive side, so
    // the box answer [81, 121] (width 40) is the exact range. Affine
    // multiplication must bound the nonlinear term by rad*rad over the full
    // [-1, 1] of a fresh symbol, when the truth is that e^2 lies in [0, 1]. It
    // therefore comes out slightly WIDER, and no amount of integer arithmetic
    // changes that.
    //
    // This is the limitation to state plainly: zonotopes are not universally
    // tighter than boxes. They win on chains that REUSE a value, which is the
    // case the next test covers and the case the dependency problem is about.
    let mut p = Symbols::new();
    let x = Z::uncertain(10, 1, &mut p);
    let sq = x.mul(x, &mut p);
    for e in [-1i128, 0, 1] {
        assert_encloses(&sq, Q::int((10 + e) * (10 + e)), "x*x");
    }
    let (lo, hi) = sq.interval();
    assert_eq!(hi - lo, 42, "affine x*x is 42 wide");
    assert_eq!(121 - 81, 40, "the box is 40 wide -- narrower, and exact here");
    assert!(hi - lo > 40, "so this is a case where the box legitimately wins");
}

// ---- capacity and condensation --------------------------------------------

#[test]
fn condensation_is_counted_and_never_unsound() {
    // Force overflow: 4 slots, 8 independent sources.
    let mut p = Symbols::new();
    let mut small = Zono::<4>::exact(0);
    let mut big = Zono::<64>::exact(0);
    let mut total = 0i128;
    for k in 1..=8i64 {
        let s = p.fresh();
        small = small.add(Zono::<4>::from_symbol(k, s, k), &mut p);
        big = big.add(Zono::<64>::from_symbol(k, s, k), &mut p);
        total += k as i128;
    }
    assert_eq!(small.center(), big.center());
    assert!(small.condensations() > 0, "the small form must have condensed");
    assert_eq!(big.condensations(), 0, "the large form must not have");
    // Condensing can only widen, never narrow: that is what keeps it sound.
    assert!(small.radius() >= big.radius(),
        "condensed radius {} must not be tighter than the exact {}",
        small.radius(), big.radius());
    assert_eq!(big.radius(), total);
}

#[test]
fn a_zonotope_is_never_wider_than_the_equivalent_box() {
    // The whole claim, as an inequality: on a chain that reuses one shared
    // measurement, the zonotope enclosure must never be worse than interval
    // arithmetic on the same computation.
    let mut p = Symbols::new();
    let s = p.fresh();
    let mut z = Z::from_symbol(1000, s, 10);
    let mut b = IBox::<1>::new([990], [1010]);
    for _ in 0..12 {
        let base = Z::from_symbol(1000, s, 10);
        z = z.add(base, &mut p).sub(base, &mut p);
        let bb = IBox::<1>::new([990], [1010]);
        // the same expression under interval arithmetic
        let lo = b.lo[0] + bb.lo[0] - bb.hi[0];
        let hi = b.hi[0] + bb.hi[0] - bb.lo[0];
        b = IBox::<1>::new([lo], [hi]);
    }
    let zw = z.radius() * 2;
    let bw = (b.hi[0] - b.lo[0]) as i128;
    assert_eq!(zw, 20, "the zonotope must stay at its true width");
    assert!(bw > zw * 20, "the box should have blown up; got {bw} vs {zw}");
}

#[test]
fn generator_norm_needs_no_square_root_function() {
    let mut p = Symbols::new();
    let a = p.fresh();
    let b = p.fresh();
    let z = Z::from_symbol(0, a, 3).add(Z::from_symbol(0, b, 4), &mut p);
    assert_eq!(z.generator_norm_ceil(), 5, "3-4-5 exactly");
    assert_eq!(z.radius(), 7, "but the box radius is the L1 sum");
}

#[test]
fn the_case_where_zonotopes_lose_is_pinned_too() {
    // Ring consensus with integer division: the box is exactly tight and the
    // zonotope is not, because each division's rounding is charged as a fresh
    // independent source that can never cancel. Pinned so the limitation cannot
    // be quietly claimed away later, and so a real fix shows up as a failure
    // here rather than going unnoticed.
    let mut pool = Symbols::new();
    let syms: [u32; 3] = [pool.fresh(), pool.fresh(), pool.fresh()];
    let mut z: [Z; 3] = core::array::from_fn(|i| Z::from_symbol(1000, syms[i], 12));
    for _ in 0..8 {
        let prev = z;
        for i in 0..3 {
            let l = prev[(i + 2) % 3];
            let r = prev[(i + 1) % 3];
            z[i] = prev[i].scale(2).add(l, &mut pool).add(r, &mut pool)
                          .div_round(4, &mut pool);
        }
    }
    let zono_width = z[0].radius() * 2;
    let box_width = 24i128;       // a convex combination preserves it exactly
    let true_width = 24i128;
    assert_eq!(box_width, true_width, "the box is exactly tight on this problem");
    assert!(zono_width > box_width,
        "this is the losing case: zonotope {zono_width} vs box {box_width}");
    assert!(zono_width < 120,
        "but exact remainder accounting must keep it near {zono_width}, not the \
         270 the flat-unit charge produced");
}

// ---- Fixed: the scaled form that stops dividing ---------------------------

type F = exact_band::Fixed<16>;
use exact_band::Fixed;

#[test]
fn scaling_removes_the_rounding_that_made_zonotopes_lose() {
    // The same ring consensus that Zono::div_round loses on. Carried as Fixed,
    // the /4 is a change of exponent rather than a division, so nothing rounds
    // and nothing is minted -- the width stays exactly true.
    let mut pool = Symbols::new();
    let syms: [u32; 3] = [pool.fresh(), pool.fresh(), pool.fresh()];
    let mut z: [F; 3] =
        core::array::from_fn(|i| Fixed::new(Z::from_symbol(1000, syms[i], 12)));
    for _ in 0..8 {
        let prev = z;
        for i in 0..3 {
            z[i] = prev[i].scale(2)
                .add(prev[(i + 2) % 3], &mut pool)
                .add(prev[(i + 1) % 3], &mut pool)
                .div_pow2(2);
        }
    }
    // Width in units of 2^-shift, compared against the true width of 24.
    let den = 1i128 << z[0].shift();
    assert_eq!(z[0].width_scaled(), 24 * den,
        "a convex combination preserves width exactly; Fixed must report that");
    assert_eq!(z[0].numerator().condensations(), 0, "and mint nothing on the way");
}

#[test]
fn only_a_zonotope_can_conclude_that_two_nodes_agree() {
    // The operation this crate exists for. After consensus, x0 - x1 collapses
    // toward zero. Interval arithmetic cannot see it at any number of rounds.
    let mut pool = Symbols::new();
    let syms: [u32; 3] = [pool.fresh(), pool.fresh(), pool.fresh()];
    let mut z: [F; 3] =
        core::array::from_fn(|i| Fixed::new(Z::from_symbol(1000, syms[i], 12)));

    let mut widths = [0i128; 10];
    for w in widths.iter_mut() {
        let d = z[0].sub(z[1], &mut pool);
        // width as a fraction of a unit, in thousandths
        *w = 1000 * d.width_scaled() / (1i128 << d.shift());
        let prev = z;
        for i in 0..3 {
            z[i] = prev[i].scale(2)
                .add(prev[(i + 2) % 3], &mut pool)
                .add(prev[(i + 1) % 3], &mut pool)
                .div_pow2(2);
        }
    }
    assert_eq!(widths[0], 48000, "both start at the same place");
    assert!(widths[3] < 1000, "the zonotope must collapse fast: {}", widths[3]);
    assert_eq!(widths[8], 0, "and reach exact agreement");
    // Monotone, because consensus never un-converges.
    for t in 1..10 {
        assert!(widths[t] <= widths[t - 1], "width must not grow at t={t}");
    }

    // The box, on the identical recurrence, carried without rounding.
    let (mut blo, mut bhi) = ([988i128; 3], [1012i128; 3]);
    let mut den = 1i128;
    for _ in 0..10 {
        let (plo, phi) = (blo, bhi);
        for i in 0..3 {
            blo[i] = 2 * plo[i] + plo[(i + 2) % 3] + plo[(i + 1) % 3];
            bhi[i] = 2 * phi[i] + phi[(i + 2) % 3] + phi[(i + 1) % 3];
        }
        den *= 4;
    }
    let box_width = 1000 * ((bhi[0] - blo[0]) + (bhi[1] - blo[1])) / den;
    assert_eq!(box_width, 48000,
        "interval arithmetic cannot conclude agreement at ANY number of rounds");
}

#[test]
fn rescaling_is_sound_and_is_the_only_place_fixed_loses_tightness() {
    let mut pool = Symbols::new();
    let s = pool.fresh();
    let f = Fixed::new(Z::from_symbol(1000, s, 12)).div_pow2(6);
    assert_eq!(f.numerator().condensations(), 0, "div_pow2 mints nothing");

    // Rescaling down rounds once, and must widen rather than narrow.
    let before = f.interval();
    let after = f.rescale(0, &mut pool).interval();
    assert!(after.0 <= before.0 && after.1 >= before.1,
        "rescale must never narrow: {before:?} -> {after:?}");
    assert!(f.rescale(0, &mut pool).numerator().condensations() > 0,
        "and it is the one place a charge is minted");
}

#[test]
fn condensation_must_never_narrow_a_difference_of_shared_forms() {
    // REGRESSION. The first version of `absorb_spill` freed no slot when full:
    // it added the spilled magnitude to an EXISTING term, keeping that term's
    // symbol id. Two forms that both dumped error into the same shared symbol
    // then cancelled that error when subtracted -- because cancelling shared
    // symbols is precisely what subtraction is for -- and the result came out
    // NARROWER than the truth.
    //
    // That is the one failure mode that matters: a band too narrow lets a
    // caller conclude two values agree when they do not. The whole test suite
    // passed anyway, because nothing combined condensation, shared symbols and
    // subtraction in one computation.
    //
    // Worth being exact about what caught it: this hand-built case does NOT.
    // Reverting the fix leaves this test green and fails only
    // `condensation_stays_sound_across_a_consensus_sweep` below. The bug needed
    // the real recurrence -- many rounds, heavy condensation, correlated forms
    // -- to surface. It is kept as the readable statement of the property; the
    // sweep is the one with teeth.
    let mut pool = Symbols::new();
    let shared: [u32; 4] = [pool.fresh(), pool.fresh(), pool.fresh(), pool.fresh()];

    // Build two forms over the same sources, forcing the small one to condense.
    let mut small_a = Zono::<4>::exact(500);
    let mut small_b = Zono::<4>::exact(500);
    let mut ref_a = Zono::<64>::exact(500);
    let mut ref_b = Zono::<64>::exact(500);
    for (k, &s) in shared.iter().enumerate() {
        let ca = 7 * (k as i64 + 1);
        let cb = 3 * (k as i64 + 1);
        small_a = small_a.add(Zono::<4>::from_symbol(0, s, ca), &mut pool);
        small_b = small_b.add(Zono::<4>::from_symbol(0, s, cb), &mut pool);
        ref_a = ref_a.add(Zono::<64>::from_symbol(0, s, ca), &mut pool);
        ref_b = ref_b.add(Zono::<64>::from_symbol(0, s, cb), &mut pool);
        // Extra independent sources, to push the small form past capacity.
        let extra = pool.fresh();
        small_a = small_a.add(Zono::<4>::from_symbol(0, extra, 5), &mut pool);
        ref_a = ref_a.add(Zono::<64>::from_symbol(0, extra, 5), &mut pool);
    }

    assert!(small_a.condensations() > 0, "the small form must have condensed");
    let small_d = small_a.sub(small_b, &mut pool);
    let ref_d = ref_a.sub(ref_b, &mut pool);

    assert!(small_d.radius() >= ref_d.radius(),
        "condensed difference {} is NARROWER than the exact {} -- unsound",
        small_d.radius(), ref_d.radius());
}

#[test]
fn condensation_stays_sound_across_a_consensus_sweep() {
    // The same property, through the recurrence that actually found the bug:
    // ring consensus with fresh noise each round, which forces heavy
    // condensation, then a subtraction of two nodes.
    for n in [3usize, 5, 8] {
        for fresh in [false, true] {
            let (small, _) = sweep_width::<8>(n, fresh);
            let (exact, cond) = sweep_width::<256>(n, fresh);
            assert_eq!(cond, 0, "the reference must not condense");
            assert!(small >= exact,
                "n={n} fresh={fresh}: capacity-8 width {small} is narrower than \
                 the exact {exact} -- condensation must only widen");
        }
    }
}

fn sweep_width<const K: usize>(n: usize, fresh: bool) -> (i128, u32) {
    use exact_band::Fixed;
    let mut pool = Symbols::new();
    let mut z: [Fixed<K>; 8] = core::array::from_fn(|i| {
        if i < n { Fixed::new(Zono::<K>::from_symbol(1000, pool.fresh(), 12)) }
        else { Fixed::new(Zono::<K>::exact(0)) }
    });
    for _ in 0..6 {
        let prev = z;
        for i in 0..n {
            let mut v = prev[i].scale(2)
                .add(prev[(i + n - 1) % n], &mut pool)
                .add(prev[(i + 1) % n], &mut pool)
                .div_pow2(2);
            if fresh {
                v = v.add(Fixed::new(Zono::<K>::uncertain(0, 2, &mut pool)), &mut pool);
            }
            z[i] = v;
        }
    }
    let d = z[0].sub(z[1], &mut pool);
    (1000 * d.width_scaled() / (1i128 << d.shift()), d.numerator().condensations())
}
