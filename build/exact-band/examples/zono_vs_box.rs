//! Where do integer zonotopes actually beat boxes? Measured, not asserted.
//!
//! `IBox` is interval arithmetic: sound, and blind to the fact that two
//! quantities may share a source. `Zono` tracks the sources. The claim is that
//! this matters on chains that reuse measurements — so this measures the width
//! of each enclosure against the TRUE reachable width, and finds the crossover.
//!
//! The true width is not estimated. Every computation here is affine in the
//! underlying uncertainties, so its reachable set is a zonotope and its extreme
//! values are attained at a `±1` assignment of the source symbols. With a small
//! number of sources the vertices can be enumerated exactly.
//!
//! Run: `cargo run --release --example zono_vs_box`

use exact_band::{Symbols, Zono};

type Z = Zono<32>;

/// Exact reachable width, by enumerating every ±1 assignment of `n` sources.
fn true_width(n: u32, eval: impl Fn(&[i64]) -> i64) -> i64 {
    let mut lo = i64::MAX;
    let mut hi = i64::MIN;
    for mask in 0u32..(1u32 << n) {
        let signs: [i64; 8] = core::array::from_fn(|i| {
            if i < n as usize && (mask >> i) & 1 == 1 { 1 } else { -1 }
        });
        let v = eval(&signs);
        lo = lo.min(v);
        hi = hi.max(v);
    }
    hi - lo
}

fn main() {
    println!("CASE 1 -- where zonotopes LOSE.\n");
    println!("Consensus on a ring of 3 nodes, each holding one noisy reading.");
    println!("Every step blends a node with its neighbours and divides by 4.");
    println!("This looked like the ideal case for dependency tracking. It is");
    println!("not, and the measurement is reported rather than dropped.\n");
    println!("  {:>5}  {:>12}  {:>12}  {:>12}  {:>9}", "step", "true width", "zonotope", "box", "box/true");

    const N: usize = 3;
    let radius: i64 = 12;
    let centers: [i64; N] = [1000, 1000, 1000];

    // Zonotope state: one shared symbol per node's reading.
    let mut pool = Symbols::new();
    let syms: [u64; N] = core::array::from_fn(|_| pool.fresh());
    let mut z: [Z; N] = core::array::from_fn(|i| Z::from_symbol(centers[i], syms[i], radius));

    // Interval state: the same values, as boxes.
    let mut blo: [i64; N] = core::array::from_fn(|i| centers[i] - radius);
    let mut bhi: [i64; N] = core::array::from_fn(|i| centers[i] + radius);

    for step in 0..=8u32 {
        // The exact reachable width of node 0, by enumerating source signs.
        let tw = true_width(N as u32, |signs| {
            let mut v: [i64; N] = core::array::from_fn(|i| centers[i] + radius * signs[i]);
            for _ in 0..step {
                let prev = v;
                for i in 0..N {
                    let (l, r) = (prev[(i + N - 1) % N], prev[(i + 1) % N]);
                    v[i] = (2 * prev[i] + l + r) / 4;
                }
            }
            v[0]
        });

        let zw = (z[0].radius() * 2) as i64;
        let bw = bhi[0] - blo[0];
        println!("  {:>5}  {:>12}  {:>12}  {:>12}  {:>8.2}x",
                 step, tw, zw, bw, bw as f64 / tw.max(1) as f64);

        // Advance both representations by the same rule.
        let prev = z;
        for i in 0..N {
            let l = prev[(i + N - 1) % N];
            let r = prev[(i + 1) % N];
            z[i] = prev[i].scale(2).add(l, &mut pool).add(r, &mut pool)
                          .div_round(4, &mut pool);
        }
        let (plo, phi) = (blo, bhi);
        for i in 0..N {
            let (l, r) = ((i + N - 1) % N, (i + 1) % N);
            blo[i] = (2 * plo[i] + plo[l] + plo[r]) / 4;
            bhi[i] = (2 * phi[i] + phi[l] + phi[r]) / 4;
        }
    }

    println!("\nThe box is EXACTLY TIGHT here and the zonotope is not.");
    println!("A convex combination preserves interval width exactly, so plain");
    println!("interval arithmetic has nothing to lose. The zonotope pays for");
    println!("integer division: each step's rounding must be charged as a fresh");
    println!("INDEPENDENT source, because affine arithmetic has no way to say");
    println!("'this error is a deterministic function of inputs I already");
    println!("track'. That charge cannot cancel, so it accumulates.");
    println!("\nTightening the remainder bookkeeping to exact leftovers cut");
    println!("this from 270 to 76 at step 8. It does not remove it. The fix");
    println!("is to stop dividing -- carry a shared denominator and rescale");
    println!("rarely -- which is identified, not yet built.");

    // --- the dependency chain, where the gap is unbounded -------------------
    println!("\n\nCASE 2 -- where zonotopes win, without bound.\n");
    println!("A value that is added and removed again, N times over.");
    println!("Every step is a no-op on the true value. Interval arithmetic");
    println!("pays two full widths for each one.\n");
    println!("  {:>5}  {:>12}  {:>12}  {:>12}", "reps", "true width", "zonotope", "box");

    let mut pool = Symbols::new();
    let s = pool.fresh();
    let mut zz = Z::from_symbol(1000, s, 10);
    let (mut lo, mut hi) = (990i64, 1010i64);
    for rep in 0..=6u32 {
        println!("  {:>5}  {:>12}  {:>12}  {:>12}", rep, 20, zz.radius() * 2, hi - lo);
        let base = Z::from_symbol(1000, s, 10);
        zz = zz.add(base, &mut pool).sub(base, &mut pool);
        let (l2, h2) = (990i64, 1010i64);
        let (nl, nh) = (lo + l2 - h2, hi + h2 - l2);
        lo = nl;
        hi = nh;
    }
    println!("\nThe true width never changes -- the operation is an identity.");
    println!("The zonotope reports that. The box grows by 40 every repetition,");
    println!("without bound, and is never wrong: only useless.");
}
