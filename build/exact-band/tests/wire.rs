//! The canonical encoding. Most of this file is about REFUSAL.
//!
//! Round-tripping proves an encoder and decoder agree. It says nothing about
//! canonicality, which is the property that actually matters: that no OTHER
//! byte string decodes to the same value. Only a decoder that rejects the
//! alternatives can give you that, and only then is hashing the bytes the same
//! as hashing the value — which is what provenance needs.

use exact_band::wire::{read_banded, read_zono, write_banded, write_zono, Reader, WireError, Writer};
use exact_band::{Banded, Symbols, Zono, Z1};

type Z = Zono<16>;

fn enc_banded(b: &Banded<Z1>) -> Vec<u8> {
    let mut buf = [0u8; 64];
    let n = { let mut w = Writer::new(&mut buf); write_banded(&mut w, b).unwrap(); w.len() };
    buf[..n].to_vec()
}

fn enc_zono(z: &Z) -> Vec<u8> {
    let mut buf = [0u8; 512];
    let n = { let mut w = Writer::new(&mut buf); write_zono(&mut w, z).unwrap(); w.len() };
    buf[..n].to_vec()
}

fn dec_zono(bytes: &[u8]) -> Result<Z, WireError> {
    let mut pool = Symbols::new();
    let mut r = Reader::new(bytes);
    let z = read_zono::<16>(&mut r, &mut pool)?;
    r.finish()?;
    Ok(z)
}

// ---- round trips ----------------------------------------------------------

#[test]
fn banded_round_trips_over_the_extremes() {
    for v in [0i32, 1, -1, 127, -128, i32::MIN, i32::MAX] {
        for radius in [0u32, 1, 255, 256, u32::MAX] {
            let b = Banded::new(Z1::new(v), radius);
            let bytes = enc_banded(&b);
            let mut r = Reader::new(&bytes);
            let got = read_banded(&mut r).expect("decode");
            r.finish().expect("no trailing bytes");
            assert_eq!(got.value.0, v);
            assert_eq!(got.radius, radius);
        }
    }
}

#[test]
fn zonotope_round_trips_and_preserves_every_term() {
    let mut pool = Symbols::new();
    let mut z = Z::exact(-4242);
    for k in 1..=8i64 {
        z = z.add(Z::from_symbol(0, k as u64 * 3, k * 17 * if k % 2 == 0 { -1 } else { 1 }),
                  &mut pool);
    }
    let bytes = enc_zono(&z);
    let got = dec_zono(&bytes).expect("decode");
    assert_eq!(got.center(), z.center());
    assert_eq!(got.terms(), z.terms());
    for i in 0..z.terms() {
        assert_eq!(got.term(i), z.term(i), "term {i} changed across the wire");
    }
    assert_eq!(got.radius(), z.radius());
}

#[test]
fn the_encoding_is_compact() {
    // A small band should not cost what a large one does. Zigzag exists so a
    // value of -1 is one byte rather than ten.
    let small = enc_banded(&Banded::new(Z1::new(-1), 1));
    assert_eq!(small.len(), 3, "tag + 1 + 1");
    let mut pool = Symbols::new();
    let z = Z::uncertain(1000, 12, &mut pool);
    assert!(enc_zono(&z).len() <= 8, "one-term zonotope should be tiny");
}

// ---- canonicality: the decoder must REFUSE the alternatives ---------------

#[test]
fn a_non_minimal_varint_is_rejected() {
    // 0x81 0x00 and 0x01 would both mean 1 under a permissive reader. Accepting
    // both would mean one value has two encodings, and hashing the bytes would
    // stop being equivalent to hashing the value.
    let good = vec![0x01u8, 0x02, 0x01];         // tag, zigzag(1), radius 1
    let mut r = Reader::new(&good);
    assert!(read_banded(&mut r).is_ok(), "the canonical form must decode");

    let padded = vec![0x01u8, 0x02, 0x81, 0x00]; // radius 1, written the long way
    let mut r = Reader::new(&padded);
    assert_eq!(read_banded(&mut r), Err(WireError::NonMinimalVarint));
}

#[test]
fn out_of_order_and_duplicate_ids_are_unrepresentable() {
    // Stronger than "rejected": ids are stored as `id - prev - 1`, so the
    // smallest legal step is +1 and there is NO byte string that means "the
    // same id twice" or "a lower id next". Non-canonical orderings are not
    // refused by a check that could be forgotten -- they cannot be written down.
    //
    // The consequence, verified by construction below: every input the decoder
    // ACCEPTS yields strictly ascending ids, whatever bytes are fed to it.
    let mut accepted = 0;
    for a in 0u8..40 {
        for b in 0u8..40 {
            let bytes = vec![0x10u8, 0x00, 0x02, a, 0x02, b, 0x02];
            if let Ok(z) = dec_zono(&bytes) {
                accepted += 1;
                let mut prev = None;
                for i in 0..z.terms() {
                    let (id, _) = z.term(i).unwrap();
                    if let Some(p) = prev {
                        assert!(id > p, "decoder produced non-ascending ids {p} then {id}");
                    }
                    prev = Some(id);
                }
            }
        }
    }
    assert!(accepted > 100, "the sweep should accept plenty, got {accepted}");

    // A delta of zero is the CONSECUTIVE case, not a duplicate: ids 9 then 10.
    let consecutive = vec![0x10u8, 0x00, 0x02, 0x09, 0x02, 0x00, 0x02];
    let z = dec_zono(&consecutive).expect("consecutive ids are legal");
    assert_eq!(z.term(0).unwrap().0, 9);
    assert_eq!(z.term(1).unwrap().0, 10);
}

#[test]
fn a_zero_coefficient_is_not_representable() {
    // A term contributing nothing must be absent, or `x - x` would have many
    // encodings instead of one.
    let with_zero = vec![0x10u8, 0x00, 0x01, 0x05, 0x00];   // id 5, coeff 0
    assert_eq!(dec_zono(&with_zero), Err(WireError::ZeroCoefficient));
}

#[test]
fn trailing_bytes_are_rejected() {
    let mut pool = Symbols::new();
    let mut bytes = enc_zono(&Z::uncertain(7, 3, &mut pool));
    bytes.push(0x00);
    assert_eq!(dec_zono(&bytes), Err(WireError::TrailingBytes));
}

#[test]
fn truncation_and_bad_tags_are_rejected() {
    let mut pool = Symbols::new();
    let bytes = enc_zono(&Z::uncertain(1234, 56, &mut pool));
    for cut in 1..bytes.len() {
        assert!(dec_zono(&bytes[..cut]).is_err(), "truncation at {cut} must fail");
    }
    assert_eq!(dec_zono(&[0x99, 0x00, 0x00]), Err(WireError::BadTag(0x99)));
}

#[test]
fn more_terms_than_capacity_is_rejected_not_silently_condensed() {
    // Condensing on decode would change the value, and a value that changes on
    // the way in is not a canonical encoding of anything.
    let mut body = vec![0x10u8, 0x00, 0x20];    // tag, centre 0, 32 terms
    for _ in 0..32 { body.push(0x00); body.push(0x02); }
    assert_eq!(dec_zono(&body), Err(WireError::TooManyTerms));
}

// ---- the property that makes it usable for provenance ---------------------

#[test]
fn equal_values_encode_identically_and_different_ones_do_not() {
    // The whole point: bytes may stand in for the value when hashing.
    let mut p1 = Symbols::new();
    let mut p2 = Symbols::new();

    // Built by different routes, ending at the same value.
    let a = Z::from_symbol(100, 7, 5).add(Z::from_symbol(0, 9, 3), &mut p1);
    let b = Z::from_symbol(0, 9, 3).add(Z::from_symbol(100, 7, 5), &mut p2);
    assert_eq!(enc_zono(&a), enc_zono(&b),
        "the same value reached two ways must encode to the same bytes");

    // And a genuinely different value must not collide.
    let c = Z::from_symbol(100, 7, 5).add(Z::from_symbol(0, 9, 4), &mut p1);
    assert_ne!(enc_zono(&a), enc_zono(&c));
}

#[test]
fn decoding_advances_the_symbol_pool_past_every_id_seen() {
    // A symbol minted after a decode must not collide with a decoded one.
    // Colliding would assert a dependency that does not exist, and could make a
    // later difference too NARROW -- the one failure mode that matters here.
    let bytes = {
        let mut pool = Symbols::new();
        let z = Z::from_symbol(0, 500, 9).add(Z::from_symbol(0, 900, 4), &mut pool);
        enc_zono(&z)
    };
    let mut pool = Symbols::new();
    let mut r = Reader::new(&bytes);
    let decoded = read_zono::<16>(&mut r, &mut pool).unwrap();
    r.finish().unwrap();

    let fresh = pool.fresh();
    assert!(fresh > 900, "fresh symbol {fresh} collides with a decoded id");
    // And the collision would have been observable: subtracting a form built on
    // the fresh symbol must not cancel anything in the decoded value.
    let probe = Z::from_symbol(0, fresh, 9);
    let diff = decoded.sub(probe, &mut pool);
    assert_eq!(diff.radius(), decoded.radius() + 9,
        "an independent symbol must add, not cancel");
}
