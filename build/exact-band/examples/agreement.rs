//! Can interval arithmetic ever conclude that two nodes agree?
//!
//! This whole crate exists to make "do these two estimates agree?" a decidable
//! question. So run consensus on a ring and then ask exactly that: what is the
//! enclosure of `x₀ − x₁` after `t` rounds?
//!
//! The true answer collapses toward zero — that is what consensus *does*. The
//! question is whether each representation can see it.
//!
//! Division by 4 is done as [`Fixed::div_pow2`], a change of scale, so the
//! recurrence is carried exactly with no rounding anywhere. Widths are reported
//! in thousandths of a unit, computed in integers.
//!
//! Run: `cargo run --release --example agreement`

use exact_band::{Fixed, Symbols, Zono};

type Z = Zono<32>;
type F = Fixed<32>;

const N: usize = 3;
const RADIUS: i128 = 12;
const CENTER: i128 = 1000;

/// Exact reachable width of `x₀ − x₁`, by enumerating every ±1 assignment.
/// Returned as a numerator over `4^steps`.
fn true_width_num(steps: u32) -> i128 {
    let mut lo = i128::MAX;
    let mut hi = i128::MIN;
    for mask in 0u32..(1u32 << N) {
        let mut v: [i128; N] = core::array::from_fn(|i| {
            let s = if (mask >> i) & 1 == 1 { 1 } else { -1 };
            CENTER + RADIUS * s
        });
        // Scale up front so the whole recurrence is exact integer arithmetic.
        for x in v.iter_mut() { *x *= 4i128.pow(steps); }
        for _ in 0..steps {
            let prev = v;
            for i in 0..N {
                // (2a + l + r) / 4, with the division deferred into the scale
                v[i] = (2 * prev[i] + prev[(i + N - 1) % N] + prev[(i + 1) % N]) / 4;
            }
        }
        let d = v[0] - v[1];
        lo = lo.min(d);
        hi = hi.max(d);
    }
    hi - lo
}

fn milli(num: i128, den: i128) -> i128 { 1000 * num / den }

fn main() {
    // `--sequence` emits just the widths, for the cross-substrate comparison in
    // check-substrates.sh. The C and Python harnesses print the same line.
    if std::env::args().any(|a| a == "--sequence") {
        let rounds: usize = std::env::args()
            .nth(1).and_then(|s| s.parse().ok()).unwrap_or(10);
        let mut pool = Symbols::new();
        let syms: [u64; N] = core::array::from_fn(|_| pool.fresh());
        let mut z: [F; N] = core::array::from_fn(|i| {
            Fixed::new(Z::from_symbol(CENTER as i64, syms[i], RADIUS as i64))
        });
        let mut out = String::new();
        for r in 0..=rounds {
            let d = z[0].sub(z[1], &mut pool);
            let w = 1000 * d.width_scaled() / (1i128 << d.shift());
            if r > 0 { out.push(','); }
            out.push_str(&w.to_string());
            let prev = z;
            for i in 0..N {
                z[i] = prev[i].scale(2)
                    .add(prev[(i + N - 1) % N], &mut pool)
                    .add(prev[(i + 1) % N], &mut pool)
                    .div_pow2(2);
            }
        }
        println!("agreement_widths={out}");
        return;
    }

    println!("Ring of {N} nodes, each holding one reading known to ±{RADIUS}.");
    println!("After t rounds of consensus, how wide is the enclosure of");
    println!("x0 - x1 -- the disagreement between two nodes?\n");
    println!("Widths in thousandths of a unit. True width is exact.\n");
    println!("  {:>4}  {:>12}  {:>12}  {:>12}", "t", "true", "zonotope", "box");

    let mut pool = Symbols::new();
    let syms: [u64; N] = core::array::from_fn(|_| pool.fresh());
    let mut z: [F; N] =
        core::array::from_fn(|i| Fixed::new(Z::from_symbol(CENTER as i64, syms[i], RADIUS as i64)));

    // Interval state, carried at the same scale so the comparison is fair.
    let mut blo: [i128; N] = [CENTER - RADIUS; N];
    let mut bhi: [i128; N] = [CENTER + RADIUS; N];
    let mut bden: i128 = 1;

    for t in 0..=10u32 {
        let den = 4i128.pow(t);

        let tw = milli(true_width_num(t), den);
        let d = z[0].sub(z[1], &mut pool);
        let zw = milli(d.width_scaled(), 1i128 << d.shift());
        let bw = milli((bhi[0] - blo[0]) + (bhi[1] - blo[1]), bden);

        println!("  {:>4}  {:>12}  {:>12}  {:>12}", t, tw, zw, bw);

        // Advance the zonotopes: exact, the /4 is a scale change.
        let prev = z;
        for i in 0..N {
            z[i] = prev[i]
                .scale(2)
                .add(prev[(i + N - 1) % N], &mut pool)
                .add(prev[(i + 1) % N], &mut pool)
                .div_pow2(2);
        }

        // Advance the intervals by the same rule, also without rounding.
        let (plo, phi) = (blo, bhi);
        for i in 0..N {
            let (l, r) = ((i + N - 1) % N, (i + 1) % N);
            blo[i] = 2 * plo[i] + plo[l] + plo[r];
            bhi[i] = 2 * phi[i] + phi[l] + phi[r];
        }
        bden *= 4;
    }

    println!("\nThe true disagreement collapses to zero: that is what consensus");
    println!("does. The zonotope reports it, exactly, because the shared");
    println!("readings cancel term by term when the two estimates are");
    println!("subtracted.");
    println!("\nThe box NEVER narrows. Interval arithmetic has no way to know");
    println!("that x0 and x1 are built from the same three readings, so it must");
    println!("assume they are extreme in opposite directions -- forever. It is");
    println!("never wrong. It simply cannot conclude that the nodes agree, at");
    println!("any t, for any tolerance below 48.");
    println!("\nThat is the operation this crate is for, and it is the one");
    println!("interval arithmetic cannot do.");
}
