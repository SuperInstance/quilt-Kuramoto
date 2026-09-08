//! The zonotope conformance stream, Rust substrate.
//!
//! Separate from `examples/stream.rs` so that stream's committed checksums stay
//! a stable historical record. See `../CONFORMANCE-STREAM.md`.
//!
//! It carries one accumulator across iterations over a small set of SHARED
//! symbols plus fresh ones, so condensation actually happens — which is the
//! whole reason this section exists. The Rust original shipped an unsound
//! condensation producing bands too *narrow*; the internal term list is folded
//! in, not just the interval, so a substrate that condenses differently
//! diverges even where its interval happens to agree.
//!
//! Run: `cargo run --release --example zono_stream -- 50000`

use exact_band::{Symbols, Zono};

const SEED: u64 = 0x2545_F491_4F6C_DD1D;
const H0: u64 = 0xCBF2_9CE4_8422_2325;
const FNV_P: u64 = 0x0000_0100_0000_01B3;
const SCALES: [u64; 4] = [16, 1024, 1_000_000, 1_239_850_262];
const SHARED: usize = 4;

type Z = Zono<16>;

struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
    fn coord(&mut self, scale: u64) -> i32 {
        let span = 2 * scale + 1;
        let u = self.next() % span;
        (u as i64 - scale as i64) as i32
    }
}

fn mix(h: u64, v: u64) -> u64 { (h ^ v).wrapping_mul(FNV_P) }

/// Bounded by construction, so this narrowing is an assertion, not a cast.
fn as_u64(v: i128) -> u64 {
    u64::try_from(v).expect("the zonotope stream stays inside 64 bits")
}

fn main() {
    let iters: u64 = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(50_000);
    let mut rng = Rng(SEED);
    let mut pool = Symbols::new();
    let shared: [u32; SHARED] = core::array::from_fn(|_| pool.fresh());
    let mut acc = Z::exact(0);
    let mut h = H0;

    for _ in 0..iters {
        let scale = SCALES[(rng.next() % 4) as usize];
        let op = rng.next() % 5;
        let pick = (rng.next() % SHARED as u64) as usize;
        let clamped = if scale > 1024 { 1024 } else { scale };
        let coeff = rng.coord(clamped);
        let cen = rng.coord(clamped);

        acc = match op {
            0 => acc.add(Z::from_symbol(cen as i64, shared[pick], coeff as i64), &mut pool),
            1 => acc.sub(Z::from_symbol(cen as i64, shared[pick], coeff as i64), &mut pool),
            // A fresh, independent source -- this is what fills the capacity.
            2 => acc.add(Z::uncertain(cen as i64, coeff.unsigned_abs(), &mut pool), &mut pool),
            3 => acc.scale(1 + (rng.next() % 3) as i64),
            _ => acc.div_round(1 + (rng.next() % 7) as i64, &mut pool),
        };

        // Keep magnitudes bounded identically in every substrate, so none of
        // them reaches its saturation edge and they cannot diverge there.
        if acc.radius() > 1_000_000 {
            acc = acc.div_round(16, &mut pool);
        }

        h = mix(h, acc.center() as u64);
        h = mix(h, as_u64(acc.radius()));
        h = mix(h, acc.terms() as u64);
        h = mix(h, u64::from(acc.condensations()));
        for i in 0..acc.terms() {
            let (id, c) = acc.term(i).expect("term index within length");
            h = mix(h, u64::from(id));
            h = mix(h, c as u64);
        }
    }
    println!("iterations={iters} zono_checksum={h:016x}");
}
