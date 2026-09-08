//! The Quilt cell state hash, Rust reference.
//!
//! Standalone on purpose — `rustc reference.rs`, no crate, no dependencies —
//! so a port author can check their work against it without adopting anything.
//! Held to the same corpus as the Python and C references.
//!
//! Spec: `type(1) || id(8 LE) || dials(16 × i16 LE) || neighbours(N × u64 LE)`,
//! hashed with FNV-1a 64.

const FNV_OFFSET: u64 = 0xCBF2_9CE4_8422_2325;
const FNV_PRIME: u64 = 0x0000_0100_0000_01B3;
const N_DIALS: usize = 16;

fn fnv1a64(data: &[u8]) -> u64 {
    let mut h = FNV_OFFSET;
    for &b in data {
        h ^= u64::from(b);
        h = h.wrapping_mul(FNV_PRIME);
    }
    h
}

/// Little-endian by explicit byte, never by transmuting a native integer — the
/// point is that a big-endian port must produce these same bytes.
fn serialize(id: u64, dials: &[i16; N_DIALS], nb: &[u64]) -> Vec<u8> {
    let mut out = Vec::with_capacity(41 + 8 * nb.len());
    out.push(1u8); // type
    out.extend_from_slice(&id.to_le_bytes());
    for d in dials {
        out.extend_from_slice(&d.to_le_bytes());
    }
    for n in nb {
        out.extend_from_slice(&n.to_le_bytes());
    }
    out
}

fn state_hash(id: u64, dials: &[i16; N_DIALS], nb: &[u64]) -> u64 {
    fnv1a64(&serialize(id, dials, nb))
}

fn emit(name: &str, id: u64, dials: &[i16; N_DIALS], nb: &[u64]) {
    let bytes = serialize(id, dials, nb);
    println!("  {:<18} {:>4}  0x{:016x}", name, bytes.len(), fnv1a64(&bytes));
}

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
}

fn stream(iters: u32) -> u64 {
    let mut rng = Rng(0x2545_F491_4F6C_DD1D);
    let mut h = FNV_OFFSET;
    for _ in 0..iters {
        let id = rng.next();
        let mut dials = [0i16; N_DIALS];
        for d in dials.iter_mut() {
            *d = ((rng.next() % 65536) as i64 - 32768) as i16;
        }
        let n_nb = (rng.next() % 9) as usize;
        let nb: Vec<u64> = (0..n_nb).map(|_| rng.next()).collect();
        h ^= state_hash(id, &dials, &nb);
        h = h.wrapping_mul(FNV_PRIME);
    }
    h
}

fn main() {
    let mut d = [0i16; N_DIALS];
    for (i, v) in d.iter_mut().enumerate() {
        *v = (i + 1) as i16;
    }
    println!("published cell: 0x{:016x}", state_hash(1, &d, &[2, 3, 4]));

    emit("published", 1, &d, &[2, 3, 4]);
    emit("zero", 0, &[0i16; N_DIALS], &[]);

    let mut neg = [0i16; N_DIALS];
    for (i, v) in neg.iter_mut().enumerate() {
        *v = -((i + 1) as i16);
    }
    emit("negative-dials", 7, &neg, &[1]);

    let mut ext = [0i16; N_DIALS];
    for (i, v) in ext.iter_mut().enumerate() {
        *v = if i % 2 == 0 { i16::MIN } else { i16::MAX };
    }
    emit("dial-extremes", 9, &ext, &[5]);

    let mut alt = [0i16; N_DIALS];
    for (i, v) in alt.iter_mut().enumerate() {
        *v = if i % 2 == 0 { (i + 1) as i16 } else { -((i + 1) as i16) };
    }
    emit("alternating", 3, &alt, &[9, 8, 7]);

    emit("neighbour-order", 4, &d, &[3, 2, 4]);
    emit("big-id", u64::MAX, &d, &[u64::MAX]);
    let many: Vec<u64> = (1..=32).collect();
    emit("many-neighbours", 11, &d, &many);

    println!("stream(10000):  0x{:016x}", stream(10000));
}
