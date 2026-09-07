//! Does the agreement result survive realistic conditions?
//!
//! `examples/agreement.rs` shows a zonotope tracking the true disagreement
//! exactly to zero while a box stays pinned. That was a clean setup: three
//! nodes, one reading each, division by a power of two, plenty of capacity.
//! Real systems are not clean. This sweeps the three things most likely to
//! break it, and reports whatever comes out.
//!
//!   * **fresh noise every round** — the realistic killer. Each round brings a
//!     new measurement, so the symbol count grows as `N·T` and the fixed
//!     capacity must condense. Condensation is where tightness is given up.
//!   * **limited capacity** — `K` far below the number of live sources.
//!   * **ring size** — more nodes, slower mixing, more terms.
//!
//! The truth reference is not estimated. Every recurrence here is affine in the
//! sources, so a zonotope with capacity far above the source count and no
//! rounding *is* the exact reachable set. `REF` plays that role, and the
//! run asserts it never condensed — if it had, it would not be a reference.
//!
//! Run: `cargo run --release --example agreement_sweep`

use exact_band::{Fixed, Symbols, Zono};

const T: usize = 8;
const RADIUS: i64 = 12;
const CENTER: i64 = 1000;

type Ref = Fixed<512>;
type Small = Fixed<8>;

/// Run consensus on a ring of `n`, return the disagreement width of `x0 - x1`
/// in thousandths of a unit, for a form of capacity `K`.
fn run<const K: usize>(n: usize, fresh_noise: bool, pool: &mut Symbols)
    -> (i128, u32)
{
    let mut z: [Fixed<K>; 12] = core::array::from_fn(|i| {
        if i < n {
            Fixed::new(Zono::<K>::from_symbol(CENTER, pool.fresh(), RADIUS))
        } else {
            Fixed::new(Zono::<K>::exact(0))
        }
    });
    for _ in 0..T {
        let prev = z;
        for i in 0..n {
            let mut v = prev[i].scale(2)
                .add(prev[(i + n - 1) % n], pool)
                .add(prev[(i + 1) % n], pool)
                .div_pow2(2);
            if fresh_noise {
                // A new measurement each round: its own independent source.
                v = v.add(Fixed::new(Zono::<K>::uncertain(0, 2, pool)), pool);
            }
            z[i] = v;
        }
    }
    let d = z[0].sub(z[1], pool);
    let w = 1000 * d.width_scaled() / (1i128 << d.shift());
    (w, d.numerator().condensations())
}

/// The same recurrence under interval arithmetic, carried without rounding.
fn box_width(n: usize, fresh_noise: bool) -> i128 {
    let mut lo = [CENTER as i128 - RADIUS as i128; 12];
    let mut hi = [CENTER as i128 + RADIUS as i128; 12];
    let mut den: i128 = 1;
    for _ in 0..T {
        let (plo, phi) = (lo, hi);
        for i in 0..n {
            lo[i] = 2 * plo[i] + plo[(i + n - 1) % n] + plo[(i + 1) % n];
            hi[i] = 2 * phi[i] + phi[(i + n - 1) % n] + phi[(i + 1) % n];
        }
        den *= 4;
        if fresh_noise {
            for i in 0..n { lo[i] -= 2 * den; hi[i] += 2 * den; }
        }
    }
    1000 * ((hi[0] - lo[0]) + (hi[1] - lo[1])) / den
}

fn main() {
    println!("Disagreement width of x0 - x1 after {T} consensus rounds.");
    println!("Thousandths of a unit. `true` is an exact zonotope reference");
    println!("(capacity 512, asserted never to condense).\n");

    for &fresh in &[false, true] {
        println!("{}", if fresh {
            "--- fresh measurement noise EVERY round (the realistic case) ---"
        } else {
            "--- one reading per node, no new noise (the clean case) ---"
        });
        println!("  {:>5}  {:>10}  {:>9}  {:>9}  {:>9}  {:>9}  {:>9}",
                 "nodes", "true", "K=8", "K=32", "K=128", "K=512", "box");
        for &n in &[3usize, 5, 8, 12] {
            let mut p1 = Symbols::new();
            let (tw, refc) = run::<512>(n, fresh, &mut p1);
            assert_eq!(refc, 0, "the reference must not condense, or it is not a reference");
            let mut p2 = Symbols::new();
            let (w8, _) = run::<8>(n, fresh, &mut p2);
            let mut p3 = Symbols::new();
            let (w32, _) = run::<32>(n, fresh, &mut p3);
            let mut p4 = Symbols::new();
            let (w128, _) = run::<128>(n, fresh, &mut p4);
            let bw = box_width(n, fresh);
            // Soundness, checked on every cell: a smaller capacity may only widen.
            for (k, w) in [(8, w8), (32, w32), (128, w128)] {
                assert!(w >= tw,
                    "n={n} K={k}: width {w} is NARROWER than the true {tw} -- \
                     condensation must only ever widen");
            }
            println!("  {:>5}  {:>10}  {:>9}  {:>9}  {:>9}  {:>9}  {:>9}",
                     n, tw, w8, w32, w128, tw, bw);
        }
        println!();
    }

    let _: Ref = Fixed::new(Zono::<512>::exact(0));
    let _: Small = Fixed::new(Zono::<8>::exact(0));
}
