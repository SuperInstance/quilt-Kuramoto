//! Emits golden conformance vectors as JSON on stdout.
//!
//! Any other implementation of this algebra — the Python port in
//! `tminus-band`, or a future C or TypeScript one — must reproduce these
//! byte-for-byte. This is the same discipline the ecosystem already applies to
//! its cell state hash, which agrees across five language substrates.
//!
//! Run: `cargo run --release --example emit_vectors > vectors.json`

use exact_band::{covering, isqrt, Banded, Hex, IBox, Lattice, Narrowed, Phase, Z1, Z2, Z3};

fn main() {
    let mut out = String::from("{\n");

    // --- covering: basis_meets / max_basis over a sweep -------------------
    out.push_str("  \"covering\": [\n");
    let mut first = true;
    for dim in 1..=3u32 {
        for eps in [1u32, 2, 3, 5, 7, 10, 16, 32, 100, 255] {
            let b = covering::max_basis(dim, eps);
            if !first { out.push_str(",\n"); }
            first = false;
            out.push_str(&format!(
                "    {{\"dim\":{dim},\"eps\":{eps},\"max_basis\":{b},\"meets\":{},\"meets_plus_one\":{}}}",
                covering::basis_meets(dim, b, eps),
                covering::basis_meets(dim, b + 1, eps)
            ));
        }
    }
    out.push_str("\n  ],\n");

    // --- isqrt ------------------------------------------------------------
    out.push_str("  \"isqrt\": [\n");
    let mut first = true;
    for n in [0u128, 1, 2, 3, 4, 15, 16, 17, 24, 25, 26, 99, 100, 101,
              1_000_000, 999_999_999_999, u64::MAX as u128, u128::MAX] {
        if !first { out.push_str(",\n"); }
        first = false;
        out.push_str(&format!("    {{\"n\":\"{n}\",\"floor\":\"{}\",\"ceil\":\"{}\"}}",
            isqrt::isqrt(n), isqrt::isqrt_ceil(n)));
    }
    out.push_str("\n  ],\n");

    // --- lattice distances -------------------------------------------------
    out.push_str("  \"dist_sq\": [\n");
    let mut first = true;
    for (a, b) in [(0i32, 0i32), (3, 4), (-3, 4), (100, -250), (i32::MIN, i32::MAX)] {
        for (c, d) in [(0i32, 0i32), (1, 1), (-7, 12)] {
            if !first { out.push_str(",\n"); }
            first = false;
            out.push_str(&format!(
                "    {{\"a\":[{a},{b}],\"b\":[{c},{d}],\"z2\":\"{}\",\"hex\":\"{}\"}}",
                Z2::new(a, b).dist_sq(Z2::new(c, d)),
                Hex::new(a, b).dist_sq(Hex::new(c, d))));
        }
    }
    out.push_str("\n  ],\n");

    // --- Z1 and Z3 -----------------------------------------------------------
    // These were computed and thrown away in the first version of this emitter,
    // so no other substrate was ever held to them. Z3 matters most: it is the
    // only dimension where three squared terms are summed, which is exactly the
    // case a 64-bit port has to bound.
    out.push_str("  \"dist_sq_z1\": [\n");
    let mut first = true;
    for a in [0i32, 1, -1, 7, -7, 1000, i32::MIN, i32::MAX] {
        for b in [0i32, 3, -3, i32::MIN, i32::MAX] {
            if !first { out.push_str(",\n"); }
            first = false;
            out.push_str(&format!("    {{\"a\":{a},\"b\":{b},\"d2\":\"{}\"}}",
                Z1::new(a).dist_sq(Z1::new(b))));
        }
    }
    out.push_str("\n  ],\n");

    out.push_str("  \"dist_sq_z3\": [\n");
    let mut first = true;
    for (x, y, z) in [(0i32, 0i32, 0i32), (1, 2, 3), (-1, -2, -3), (5, -5, 5),
                      (1000, -2000, 3000), (i32::MIN, i32::MAX, 0),
                      (i32::MAX, i32::MAX, i32::MAX), (i32::MIN, i32::MIN, i32::MIN)] {
        for (p, q, r) in [(0i32, 0i32, 0i32), (1, 1, 1), (-4, 9, -16)] {
            if !first { out.push_str(",\n"); }
            first = false;
            out.push_str(&format!(
                "    {{\"a\":[{x},{y},{z}],\"b\":[{p},{q},{r}],\"d2\":\"{}\"}}",
                Z3::new(x, y, z).dist_sq(Z3::new(p, q, r))));
        }
    }
    out.push_str("\n  ],\n");

    // --- Banded narrow ------------------------------------------------------
    out.push_str("  \"banded_narrow\": [\n");
    let mut first = true;
    for cx in [-10i32, -3, 0, 1, 5, 12] {
        for r1 in [0u32, 1, 4, 9] {
            for r2 in [0u32, 2, 4, 7] {
                let a = Banded::new(Z1::new(0), r1);
                let b = Banded::new(Z1::new(cx), r2);
                if !first { out.push_str(",\n"); }
                first = false;
                let res = match a.narrow(b) {
                    Narrowed::Tightened(t) =>
                        format!("{{\"kind\":\"tightened\",\"value\":{},\"radius\":{}}}", t.value.0, t.radius),
                    Narrowed::Contradiction { gap_sq } =>
                        format!("{{\"kind\":\"contradiction\",\"gap_sq\":\"{gap_sq}\",\"gap\":\"{}\"}}",
                                a.narrow(b).gap().unwrap()),
                };
                out.push_str(&format!(
                    "    {{\"a\":{{\"v\":0,\"r\":{r1}}},\"b\":{{\"v\":{cx},\"r\":{r2}}},\
                     \"overlaps\":{},\"result\":{res}}}", a.overlaps(b)));
            }
        }
    }
    out.push_str("\n  ],\n");

    // --- IBox exact intersection -------------------------------------------
    out.push_str("  \"ibox_narrow\": [\n");
    let mut first = true;
    for l1 in [-5i64, 0, 3] { for h1 in [-1i64, 4, 9] {
    for l2 in [-8i64, 1, 6] { for h2 in [0i64, 5, 11] {
        let a = IBox::<1>::new([l1], [h1]);
        let b = IBox::<1>::new([l2], [h2]);
        if !first { out.push_str(",\n"); }
        first = false;
        let res = match a.narrow(b) {
            Some(n) => format!("{{\"kind\":\"box\",\"lo\":{},\"hi\":{}}}", n.lo[0], n.hi[0]),
            None => match a.disagreement(b) {
                Some((ax, gap)) => format!("{{\"kind\":\"disjoint\",\"axis\":{ax},\"gap\":{gap}}}"),
                None => "{\"kind\":\"disjoint\",\"axis\":null,\"gap\":null}".to_string(),
            },
        };
        out.push_str(&format!(
            "    {{\"a\":[{l1},{h1}],\"b\":[{l2},{h2}],\"a_empty\":{},\"b_empty\":{},\"result\":{res}}}",
            a.is_empty(), b.is_empty()));
    }}}}
    out.push_str("\n  ],\n");

    // --- Banded::within ------------------------------------------------------
    // Containment is NOT symmetric and NOT the same as overlap, and it is the
    // one predicate whose rearrangement (`r1 <= r2` first, so the subtraction is
    // safe) a port can get subtly wrong without any vector noticing.
    out.push_str("  \"banded_within\": [\n");
    let mut first = true;
    for cx in [-14i32, -7, -1, 0, 1, 6, 13] {
        for r1 in [0u32, 1, 3, 6, 10] {
            for r2 in [0u32, 2, 6, 9, 10] {
                let a = Banded::new(Z1::new(0), r1);
                let b = Banded::new(Z1::new(cx), r2);
                if !first { out.push_str(",\n"); }
                first = false;
                out.push_str(&format!(
                    "    {{\"a\":{{\"v\":0,\"r\":{r1}}},\"b\":{{\"v\":{cx},\"r\":{r2}}},\
                     \"a_within_b\":{},\"b_within_a\":{}}}",
                    a.within(b), b.within(a)));
            }
        }
    }
    out.push_str("\n  ],\n");

    // --- Banded::from_basis --------------------------------------------------
    // The bisection that ties a lattice basis to the band it induces. Its answer
    // is the smallest integer r with 4r^2 >= n*b^2 -- soundness depends on
    // rounding UP, and a port that bisected to the floor would understate every
    // band it produced.
    out.push_str("  \"from_basis\": [\n");
    let mut first = true;
    for basis in [0u32, 1, 2, 3, 5, 8, 13, 100, 1000, 65535] {
        let r1 = Banded::from_basis(Z1::new(0), basis).radius;
        let r2 = Banded::from_basis(Z2::new(0, 0), basis).radius;
        let r3 = Banded::from_basis(Z3::new(0, 0, 0), basis).radius;
        if !first { out.push_str(",\n"); }
        first = false;
        out.push_str(&format!(
            "    {{\"basis\":{basis},\"radius_dim1\":{r1},\"radius_dim2\":{r2},\
             \"radius_dim3\":{r3}}}"));
    }
    out.push_str("\n  ],\n");

    // --- IBox in two dimensions ----------------------------------------------
    // At N=1 `disagreement` has no choice to make. At N=2 it must return the
    // WORST axis, and that selection was untested across substrates: every
    // earlier ibox vector was one-dimensional.
    out.push_str("  \"ibox2_narrow\": [\n");
    let mut first = true;
    for ax in [-4i64, 0, 5] { for ay in [-9i64, 2, 7] {
    for bx in [-2i64, 3, 8] { for by in [-6i64, 0, 11] {
        // Boxes of fixed extent, placed at those corners: enough disjoint pairs
        // for the axis choice to matter, in both orders.
        let a = IBox::<2>::new([ax, ay], [ax + 4, ay + 9]);
        let b = IBox::<2>::new([bx, by], [bx + 3, by + 2]);
        if !first { out.push_str(",\n"); }
        first = false;
        let res = match a.narrow(b) {
            Some(n) => format!(
                "{{\"kind\":\"box\",\"lo\":[{},{}],\"hi\":[{},{}]}}",
                n.lo[0], n.lo[1], n.hi[0], n.hi[1]),
            None => match a.disagreement(b) {
                Some((axis, gap)) => format!("{{\"kind\":\"disjoint\",\"axis\":{axis},\"gap\":{gap}}}"),
                None => "{\"kind\":\"disjoint\",\"axis\":null,\"gap\":null}".to_string(),
            },
        };
        out.push_str(&format!(
            "    {{\"a\":{{\"lo\":[{ax},{ay}],\"hi\":[{},{}]}},\
             \"b\":{{\"lo\":[{bx},{by}],\"hi\":[{},{}]}},\"result\":{res}}}",
            ax + 4, ay + 9, bx + 3, by + 2));
    }}}}
    out.push_str("\n  ],\n");

    // --- Phase on odd and even circles -------------------------------------
    // Odd rings are here deliberately: a truncating `n / 2` comparison made the
    // original `offset_to` flip already-shortest offsets the long way round, and
    // every earlier vector used N=360, so nothing could see it.
    out.push_str("  \"phase\": [\n");
    let mut first = true;
    macro_rules! emit_ring {
        ($n:expr) => {{
            for a in 0..($n as i64) {
                for b in 0..($n as i64) {
                    let (p, q) = (Phase::<$n>::new(a), Phase::<$n>::new(b));
                    if !first { out.push_str(",\n"); }
                    first = false;
                    out.push_str(&format!(
                        "    {{\"n\":{},\"a\":{a},\"b\":{b},\"distance\":{},\"offset\":{}}}",
                        $n, p.distance(q), p.offset_to(q)));
                }
            }
        }};
    }
    emit_ring!(2);
    emit_ring!(3);
    emit_ring!(5);
    emit_ring!(7);
    emit_ring!(12);
    out.push_str("\n  ]\n}\n");

    print!("{out}");
}
