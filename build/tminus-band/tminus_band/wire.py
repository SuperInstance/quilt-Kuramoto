"""Canonical byte encoding for banded values — Python substrate.

Bijective on the value space: every value has exactly one valid encoding and the
decoder **rejects** everything else. That is what makes hashing the bytes
equivalent to hashing the value; a format where two byte strings can mean the
same thing cannot carry provenance, because two honest parties would compute
different digests for one measurement.

Symbol ids are delta-encoded as ``id - prev - 1``, so the smallest legal step is
+1 and a descending or repeated id has **no byte string at all**. Ordering is a
property of the format rather than a rule someone must remember to check.

See ``build/WIRE-FORMAT.md``. The Rust and C ports must produce identical bytes,
which ``build/wire_check.py`` verifies.
"""

from __future__ import annotations

from typing import List, Sequence, Tuple

from .zono import CAP, Symbols, Zono

__all__ = ["WireError", "write_banded", "read_banded", "write_zono", "read_zono"]

TAG_BANDED = 0x01
TAG_ZONO = 0x10
U32_MAX = 0xFFFFFFFF
U64_MAX = (1 << 64) - 1
I32_MIN, I32_MAX = -(1 << 31), (1 << 31) - 1


class WireError(Exception):
    """A byte string was refused.

    Every one of these is a hard error rather than a lenient fallback: a decoder
    that silently accepted them would destroy canonicality.
    """


def _w_varint(out: bytearray, v: int) -> None:
    """LEB128, minimally encoded by construction."""
    while True:
        byte = v & 0x7F
        v >>= 7
        if v == 0:
            out.append(byte)
            return
        out.append(byte | 0x80)


def _w_signed(out: bytearray, v: int) -> None:
    """Zigzag, so -1 costs one byte rather than ten."""
    _w_varint(out, ((v << 1) ^ (v >> 63)) & U64_MAX)


class _Reader:
    __slots__ = ("buf", "pos")

    def __init__(self, buf: bytes) -> None:
        self.buf = buf
        self.pos = 0

    def byte(self) -> int:
        if self.pos >= len(self.buf):
            raise WireError("truncated")
        b = self.buf[self.pos]
        self.pos += 1
        return b

    def varint(self) -> int:
        acc = 0
        shift = 0
        while True:
            b = self.byte()
            if shift >= 64:
                raise WireError("overflow")
            payload = b & 0x7F
            if shift == 63 and payload > 1:
                raise WireError("overflow")
            acc |= payload << shift
            if not b & 0x80:
                # A continuation contributing nothing means a shorter encoding
                # existed, so this one is not canonical.
                if b == 0 and shift != 0:
                    raise WireError("non-minimal varint")
                return acc
            shift += 7

    def signed(self) -> int:
        u = self.varint()
        return (u >> 1) ^ -(u & 1)

    def finish(self) -> None:
        if self.pos != len(self.buf):
            raise WireError("trailing bytes")


def write_banded(value: int, radius: int) -> bytes:
    if not I32_MIN <= value <= I32_MAX:
        raise WireError("value outside i32")
    if not 0 <= radius <= U32_MAX:
        raise WireError("radius outside u32")
    out = bytearray([TAG_BANDED])
    _w_signed(out, value)
    _w_varint(out, radius)
    return bytes(out)


def read_banded(data: bytes) -> Tuple[int, int]:
    r = _Reader(data)
    if r.byte() != TAG_BANDED:
        raise WireError("bad tag")
    value = r.signed()
    radius = r.varint()
    if radius > U32_MAX or not I32_MIN <= value <= I32_MAX:
        raise WireError("overflow")
    r.finish()
    return value, radius


def write_zono(z: Zono) -> bytes:
    out = bytearray([TAG_ZONO])
    _w_signed(out, z.center)
    _w_varint(out, len(z.terms))
    prev = 0
    for i, (sid, c) in enumerate(z.terms):
        if c == 0:
            raise WireError("zero coefficient")
        if i > 0 and sid <= prev:
            raise WireError("terms not ascending")
        _w_varint(out, sid if i == 0 else sid - prev - 1)
        _w_signed(out, c)
        prev = sid
    return bytes(out)


def read_zono(data: bytes, pool: Symbols) -> Zono:
    r = _Reader(data)
    if r.byte() != TAG_ZONO:
        raise WireError("bad tag")
    center = r.signed()
    n = r.varint()
    if n > CAP:
        raise WireError("too many terms")
    terms: List[Tuple[int, int]] = []
    prev = 0
    for i in range(n):
        raw = r.varint()
        sid = raw if i == 0 else raw + prev + 1
        if sid > U32_MAX:
            raise WireError("overflow")
        c = r.signed()
        if c == 0:
            raise WireError("zero coefficient")
        terms.append((sid, c))
        prev = sid
    r.finish()
    # Any id from THIS pool's origin must never be minted again. Ids from a
    # different origin cannot collide with ours at all, which is what
    # namespacing buys.
    pool.advance_past(prev)
    return Zono(center=center, terms=terms, condensations=0)
