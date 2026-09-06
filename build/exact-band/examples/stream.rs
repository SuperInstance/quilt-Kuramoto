//! The conformance stream, Rust substrate.
//!
//! See `../CONFORMANCE-STREAM.md` for the specification. Walks a deterministic
//! pseudo-random sequence, applies every operation in the crate, and folds each
//! answer into a 64-bit checksum. Three substrates producing the same checksum
//! agreed on every case in the stream — millions of them, at a cost of one
//! number rather than one record apiece.
//!
//! Run: `cargo run --release --example stream -- 200000`

use exact_band::{covering, isqrt, Banded, Hex, IBox, Lattice, Narrowed, Phase, Z1, Z2, Z3};

const SEED: u64 = 0x2545_F491_4F6C_DD1D;
const H0: u64 = 0xCBF2_9CE4_8422_2325;
const FNV_P: u64 = 0x0000_0100_0000_01B3;

const SCALES: [u64; 4] = [16, 1024, 1_000_000, 1_239_850_262];
const RINGS: [u32; 8] = [2, 3, 5, 7, 12, 360, 361, 1000];

struct Rng(u64);

impl Rng {
    /// xorshift64. Shifts on `u64` discard rather than panic, and the only
    /// operation that could overflow-panic in debug is the multiply, which is
    /// why `mix` below uses `wrapping_mul`.
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

fn mix(h: u64, v: u64) -> u64 {
    (h ^ v).wrapping_mul(FNV_P)
}

/// Phase is a const generic, so the ring must be dispatched rather than passed.
/// The alternative — a runtime modulus — would be testing a different type than
/// the one the crate actually ships.
fn phase_pair(ring: u32, a: i64, b: i64) -> (u32, i64) {
    macro_rules! arm {
        ($n:expr) => {{
            let (p, q) = (Phase::<$n>::new(a), Phase::<$n>::new(b));
            (p.distance(q), p.offset_to(q))
        }};
    }
    match ring {
        2 => arm!(2),
        3 => arm!(3),
        5 => arm!(5),
        7 => arm!(7),
        12 => arm!(12),
        360 => arm!(360),
        361 => arm!(361),
        1000 => arm!(1000),
        _ => unreachable!("ring not in RINGS"),
    }
}

/// Every value the stream mixes is within the tightest substrate's 64-bit reach
/// by construction, so this narrowing is a checked assertion rather than a cast.
fn as_u64(v: u128) -> u64 {
    u64::try_from(v).expect("stream stays inside every substrate's 64-bit range")
}

fn step(rng: &mut Rng, mut h: u64) -> u64 {
    // 1. isqrt over the whole 64-bit range.
    let n = rng.next();
    h = mix(h, as_u64(isqrt::isqrt(n as u128)));
    h = mix(h, as_u64(isqrt::isqrt_ceil(n as u128)));

    // 2. covering.
    let dim = 1 + (rng.next() % 3) as u32;
    let basis = (rng.next() % 100_000) as u32;
    let eps = (rng.next() % 100_000) as u32;
    h = mix(h, u64::from(covering::basis_meets(dim, basis, eps)));
    h = mix(h, u64::from(covering::max_basis(dim, eps)));

    // 3. lattices, at a scale drawn per iteration.
    let scale = SCALES[(rng.next() % 4) as usize];
    let (ax, ay, az) = (rng.coord(scale), rng.coord(scale), rng.coord(scale));
    let (bx, by, bz) = (rng.coord(scale), rng.coord(scale), rng.coord(scale));
    h = mix(h, as_u64(Z1::new(ax).dist_sq(Z1::new(bx))));
    h = mix(h, as_u64(Z2::new(ax, ay).dist_sq(Z2::new(bx, by))));
    h = mix(h, as_u64(Z3::new(ax, ay, az).dist_sq(Z3::new(bx, by, bz))));
    h = mix(h, as_u64(Hex::new(ax, ay).dist_sq(Hex::new(bx, by))));

    // 4. bands, with radii on the same scale.
    const R_MAX: u64 = 1_073_741_823;
    let r1 = (rng.next() % (scale + 1)).min(R_MAX) as u32;
    let r2 = (rng.next() % (scale + 1)).min(R_MAX) as u32;
    let ba = Banded::new(Z1::new(ax), r1);
    let bb = Banded::new(Z1::new(bx), r2);
    h = mix(h, u64::from(ba.overlaps(bb)));
    h = mix(h, u64::from(ba.within(bb)));
    h = mix(h, u64::from(bb.within(ba)));
    match ba.narrow(bb) {
        Narrowed::Tightened(t) => {
            h = mix(h, 0);
            h = mix(h, t.value.0 as i64 as u64);
            h = mix(h, u64::from(t.radius));
        }
        Narrowed::Contradiction { gap_sq } => {
            h = mix(h, 1);
            h = mix(h, as_u64(gap_sq));
        }
    }

    // 5. from_basis, at all three dimensions.
    let basis2 = (rng.next() % 65_536) as u32;
    h = mix(h, u64::from(Banded::from_basis(Z1::new(0), basis2).radius));
    h = mix(h, u64::from(Banded::from_basis(Z2::new(0, 0), basis2).radius));
    h = mix(h, u64::from(Banded::from_basis(Z3::new(0, 0, 0), basis2).radius));

    // 6. two-axis boxes, bounds sorted so every input is inhabited.
    let mut lo = [0i64; 2];
    let mut hi = [0i64; 2];
    let mut lo2 = [0i64; 2];
    let mut hi2 = [0i64; 2];
    for k in 0..2 {
        let (p, q) = (i64::from(rng.coord(scale)), i64::from(rng.coord(scale)));
        lo[k] = p.min(q);
        hi[k] = p.max(q);
        let (p, q) = (i64::from(rng.coord(scale)), i64::from(rng.coord(scale)));
        lo2[k] = p.min(q);
        hi2[k] = p.max(q);
    }
    let boxa = IBox::<2>::new(lo, hi);
    let boxb = IBox::<2>::new(lo2, hi2);
    match boxa.narrow(boxb) {
        Some(nb) => {
            h = mix(h, 1);
            for k in 0..2 {
                h = mix(h, nb.lo[k] as u64);
                h = mix(h, nb.hi[k] as u64);
            }
        }
        None => {
            h = mix(h, 0);
            let (axis, gap) = boxa.disagreement(boxb).expect("disjoint boxes disagree");
            h = mix(h, axis as u64);
            h = mix(h, gap);
        }
    }

    // 7. phase, on odd and even rings alike.
    let ring = RINGS[(rng.next() % 8) as usize];
    let pa = rng.next() as i64;
    let pb = rng.next() as i64;
    let (dist, off) = phase_pair(ring, pa, pb);
    h = mix(h, u64::from(dist));
    h = mix(h, off as u64);

    h
}

fn main() {
    let iters: u64 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(200_000);
    let mut rng = Rng(SEED);
    let mut h = H0;
    for _ in 0..iters {
        h = step(&mut rng, h);
    }
    println!("iterations={iters} checksum={h:016x}");
}
