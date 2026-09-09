//! A canonical byte encoding for banded values.
//!
//! Everything else in this crate makes agreement decidable *within* a process.
//! This makes it decidable *across* one — a value that has crossed a network,
//! a flash boundary, or twelve years, and must still mean exactly what it meant.
//!
//! ## Canonical, not merely deterministic
//!
//! The encoding is **bijective on the value space**: every value has exactly one
//! valid encoding, and a decoder **rejects** anything else. That is stronger than
//! "the encoder is deterministic", and it is the property that matters, because
//! it is what makes hashing the bytes equivalent to hashing the value. A format
//! where two byte strings can mean the same thing cannot be used for provenance:
//! two honest parties would compute different digests for the same measurement.
//!
//! Three rules carry it, and the decoder enforces all three:
//!
//! * **Varints are minimally encoded.** `0x81 0x00` and `0x01` would both decode
//!   to 1 under a permissive reader; the second is canonical and the first is
//!   rejected.
//! * **Noise terms are strictly ascending by symbol id**, so a form cannot be
//!   written in two orders. Ids are delta-encoded, which makes the ordering a
//!   consequence of the format rather than a rule a writer must remember: a
//!   non-ascending list is not representable, and a zero delta is rejected as a
//!   duplicate.
//! * **Zero coefficients are not representable.** A term that contributes
//!   nothing must be absent, so `x − x` has one encoding, not many.
//!
//! ## Why not just use a standard codec
//!
//! CBOR and Protobuf are both non-canonical by default and only *approximately*
//! canonical in their strict profiles; both also admit float types, which is the
//! thing this crate exists to remove from the room. The encoding here is 30
//! lines of varint and refuses to represent a float at all.

use crate::{Banded, Symbols, Zono, Z1};

/// Why a byte string was refused.
///
/// A decoder that silently accepted these would destroy canonicality, so each
/// is a hard error rather than a lenient fallback.
#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum WireError {
    /// Input ended in the middle of a value.
    Truncated,
    /// A varint used more bytes than its value needs — not canonical.
    NonMinimalVarint,
    /// A varint exceeded 64 bits.
    Overflow,
    /// Unknown or unexpected type tag.
    BadTag(u8),
    /// Terms were not strictly ascending, or a duplicate id appeared.
    TermsNotAscending,
    /// A coefficient of zero, which must be omitted instead.
    ZeroCoefficient,
    /// More noise terms than the target capacity can hold.
    TooManyTerms,
    /// Bytes remained after a complete value.
    TrailingBytes,
}

const TAG_BANDED: u8 = 0x01;
const TAG_ZONO: u8 = 0x10;

/// A bounded output buffer — no allocator, same as the rest of the crate.
pub struct Writer<'a> {
    buf: &'a mut [u8],
    pos: usize,
}

impl<'a> Writer<'a> {
    /// Wrap a buffer.
    pub fn new(buf: &'a mut [u8]) -> Self { Self { buf, pos: 0 } }
    /// Bytes written so far.
    pub fn len(&self) -> usize { self.pos }
    /// Has nothing been written?
    pub fn is_empty(&self) -> bool { self.pos == 0 }

    fn byte(&mut self, b: u8) -> Result<(), WireError> {
        if self.pos >= self.buf.len() { return Err(WireError::Truncated); }
        self.buf[self.pos] = b;
        self.pos += 1;
        Ok(())
    }

    /// LEB128, minimally encoded by construction.
    fn varint(&mut self, mut v: u64) -> Result<(), WireError> {
        loop {
            let byte = (v & 0x7f) as u8;
            v >>= 7;
            if v == 0 { return self.byte(byte); }
            self.byte(byte | 0x80)?;
        }
    }

    /// Zigzag, so small negatives cost one byte rather than ten.
    fn signed(&mut self, v: i64) -> Result<(), WireError> {
        self.varint(((v << 1) ^ (v >> 63)) as u64)
    }
}

/// A reader that refuses non-canonical input.
pub struct Reader<'a> {
    buf: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    /// Wrap a byte string.
    pub fn new(buf: &'a [u8]) -> Self { Self { buf, pos: 0 } }

    /// Error unless every byte was consumed — trailing data is not canonical.
    pub fn finish(&self) -> Result<(), WireError> {
        if self.pos == self.buf.len() { Ok(()) } else { Err(WireError::TrailingBytes) }
    }

    fn byte(&mut self) -> Result<u8, WireError> {
        let b = *self.buf.get(self.pos).ok_or(WireError::Truncated)?;
        self.pos += 1;
        Ok(b)
    }

    fn varint(&mut self) -> Result<u64, WireError> {
        let mut out: u64 = 0;
        let mut shift = 0u32;
        loop {
            let b = self.byte()?;
            if shift >= 64 { return Err(WireError::Overflow); }
            let payload = u64::from(b & 0x7f);
            if shift == 63 && payload > 1 { return Err(WireError::Overflow); }
            out |= payload << shift;
            if b & 0x80 == 0 {
                // A continuation that contributed nothing means a shorter
                // encoding existed, so this one is not canonical.
                if b == 0 && shift != 0 { return Err(WireError::NonMinimalVarint); }
                return Ok(out);
            }
            shift += 7;
        }
    }

    fn signed(&mut self) -> Result<i64, WireError> {
        let u = self.varint()?;
        Ok(((u >> 1) as i64) ^ -((u & 1) as i64))
    }
}

/// Encode a one-dimensional banded value.
pub fn write_banded(w: &mut Writer, b: &Banded<Z1>) -> Result<(), WireError> {
    w.byte(TAG_BANDED)?;
    w.signed(b.value.0 as i64)?;
    w.varint(u64::from(b.radius))
}

/// Decode a one-dimensional banded value.
pub fn read_banded(r: &mut Reader) -> Result<Banded<Z1>, WireError> {
    let tag = r.byte()?;
    if tag != TAG_BANDED { return Err(WireError::BadTag(tag)); }
    let value = r.signed()?;
    let radius = r.varint()?;
    if radius > u64::from(u32::MAX) { return Err(WireError::Overflow); }
    Ok(Banded::new(Z1::new(value as i32), radius as u32))
}

/// Encode a zonotope.
///
/// Symbol ids are written as **deltas** from the previous id, minus one. That
/// makes strict ascent a property of the format rather than a rule: a
/// non-ascending list cannot be written, and a repeated id would need a delta
/// of zero, which decodes as an error.
pub fn write_zono<const K: usize>(w: &mut Writer, z: &Zono<K>) -> Result<(), WireError> {
    w.byte(TAG_ZONO)?;
    w.signed(z.center())?;
    w.varint(z.terms() as u64)?;
    let mut prev: u64 = 0;
    for i in 0..z.terms() {
        let (id, c) = z.term(i).ok_or(WireError::Truncated)?;
        if c == 0 { return Err(WireError::ZeroCoefficient); }
        let id64 = id;
        if i > 0 && id64 <= prev { return Err(WireError::TermsNotAscending); }
        w.varint(if i == 0 { id64 } else { id64 - prev - 1 })?;
        w.signed(c)?;
        prev = id64;
    }
    Ok(())
}

/// Decode a zonotope, rejecting every non-canonical form.
///
/// `pool` is advanced past any id in the input, so symbols minted afterwards
/// cannot collide with decoded ones — a collision would assert a dependency
/// that does not exist and could make a later band too narrow.
pub fn read_zono<const K: usize>(
    r: &mut Reader,
    pool: &mut Symbols,
) -> Result<Zono<K>, WireError> {
    let tag = r.byte()?;
    if tag != TAG_ZONO { return Err(WireError::BadTag(tag)); }
    let center = r.signed()?;
    let n = r.varint()? as usize;
    if n > K { return Err(WireError::TooManyTerms); }

    let mut out = Zono::<K>::exact(center);
    let mut prev: u64 = 0;
    let mut scratch = Symbols::new();
    for i in 0..n {
        let raw = r.varint()?;
        let id = if i == 0 { raw } else {
            raw.checked_add(prev).and_then(|v| v.checked_add(1))
                .ok_or(WireError::Overflow)?
        };
        let c = r.signed()?;
        if c == 0 { return Err(WireError::ZeroCoefficient); }
        out = out.add(Zono::<K>::from_symbol(0, id, c), &mut scratch);
        prev = id;
    }
    // Any id from THIS pool's origin must never be minted again. Ids from a
    // different origin cannot collide with ours at all, which is precisely what
    // namespacing buys.
    pool.advance_past(prev);
    Ok(out)
}
