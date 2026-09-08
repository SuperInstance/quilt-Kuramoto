//! Emit the canonical encoding of a fixed value set as hex, for cross-substrate
//! comparison. The C and Python substrates emit the same list; if the bytes
//! differ anywhere, the format has more than one opinion about what canonical
//! means and is therefore not canonical.
//!
//! Run: `cargo run --release --example wire_vectors`

use exact_band::wire::{write_banded, write_zono, Writer};
use exact_band::{Banded, Symbols, Zono, Z1};

type Z = Zono<16>;

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn emit_banded(name: &str, v: i32, r: u32) {
    let mut buf = [0u8; 64];
    let n = {
        let mut w = Writer::new(&mut buf);
        write_banded(&mut w, &Banded::new(Z1::new(v), r)).expect("encode");
        w.len()
    };
    println!("{name} {}", hex(&buf[..n]));
}

fn emit_zono(name: &str, z: &Z) {
    let mut buf = [0u8; 512];
    let n = {
        let mut w = Writer::new(&mut buf);
        write_zono(&mut w, z).expect("encode");
        w.len()
    };
    println!("{name} {}", hex(&buf[..n]));
}

fn main() {
    emit_banded("banded/zero", 0, 0);
    emit_banded("banded/neg-one", -1, 1);
    emit_banded("banded/small", 127, 255);
    emit_banded("banded/neg-small", -128, 256);
    emit_banded("banded/i32-min", i32::MIN, 0);
    emit_banded("banded/i32-max", i32::MAX, u32::MAX);

    let mut pool = Symbols::new();
    emit_zono("zono/exact", &Z::exact(0));
    emit_zono("zono/exact-neg", &Z::exact(-123_456_789));
    emit_zono("zono/one-term", &Z::from_symbol(1000, 7, 12));

    // Consecutive ids exercise the zero-delta case; mixed signs exercise zigzag.
    let mut multi = Z::exact(-5);
    for k in 1..=5i64 {
        multi = multi.add(
            Z::from_symbol(0, k as u32, k * 100 * if k % 2 == 0 { -1 } else { 1 }),
            &mut pool,
        );
    }
    emit_zono("zono/consecutive", &multi);

    // Sparse ids exercise large deltas.
    let mut sparse = Z::exact(7);
    for k in [1u32, 1000, 70_000, 4_000_000_000] {
        sparse = sparse.add(Z::from_symbol(0, k, i64::from(k) % 977 + 1), &mut pool);
    }
    emit_zono("zono/sparse", &sparse);

    // Full capacity.
    let mut full = Z::exact(1);
    for k in 1..=16u32 {
        full = full.add(Z::from_symbol(0, k * 3, i64::from(k) - 8), &mut pool);
    }
    emit_zono("zono/full", &full);
}
