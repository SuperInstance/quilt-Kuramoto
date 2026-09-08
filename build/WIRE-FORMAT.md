# The canonical wire format

Everything else here makes agreement decidable *inside* a process. This makes it
decidable *across* one — for a value that has crossed a network, a flash
boundary, or twelve years, and must still mean exactly what it meant.

## Canonical, not merely deterministic

The encoding is **bijective on the value space**: every value has exactly one
valid encoding, and the decoder **rejects** everything else.

That is much stronger than "the encoder is deterministic", and it is the
property that matters. It makes **hashing the bytes equivalent to hashing the
value**. A format in which two byte strings can mean the same thing cannot carry
provenance: two honest parties would compute different digests for the same
measurement and conclude they disagreed.

Three rules carry it:

| rule | why | enforced by |
|---|---|---|
| varints minimally encoded | `0x81 0x00` and `0x01` both "mean" 1 | decoder rejects the padded form |
| terms strictly ascending by symbol id | a form must not be writable in two orders | **the format**: ids are delta-encoded as `id − prev − 1`, so the smallest legal step is +1 |
| no zero coefficients | `x − x` must have one encoding, not many | decoder rejects them |

The middle one is the nice one. Ordering is not a rule a writer has to remember
and a reader has to check — a descending or repeated id has **no byte string at
all**. `tests/wire.rs` verifies the consequence directly: over a sweep of
hand-built inputs, every byte string the decoder *accepts* yields strictly
ascending ids.

## Layout

```
Banded          0x01  zigzag(value)  varint(radius)

Zonotope        0x10  zigzag(centre)  varint(n)
                then n × [ varint(id delta)  zigzag(coefficient) ]
                where the first delta is the id itself and each later
                one is  id − prev − 1
```

Varints are LEB128. Signed fields are zigzagged, so `−1` costs one byte rather
than ten. A one-term zonotope fits in 8 bytes; a `Banded` of `(−1, ±1)` in 3.

## Why not CBOR or Protobuf

Both are non-canonical by default and only approximately canonical in their
strict profiles, and both admit float types — the thing this crate exists to
keep out of the room. This encoder is about thirty lines of varint and **cannot
represent a float at all**.

## What the tests check

Round-tripping proves an encoder and decoder agree; it says nothing about
canonicality. So most of `exact-band/tests/wire.rs` is about **refusal**:
non-minimal varints, zero coefficients, trailing bytes, bad tags, every
truncation point, and more terms than capacity — the last rejected rather than
silently condensed, because a value that changes on the way in is not a
canonical encoding of anything.

Two tests carry the real property:

- **the same value reached by two different routes encodes to identical bytes**,
  and a genuinely different value does not collide;
- **decoding advances the symbol pool past every id it saw**, so a symbol minted
  afterwards cannot collide with a decoded one. A collision would assert a
  dependency that does not exist and could make a later difference too *narrow*
  — the one failure mode that matters here, and the one a real bug in
  condensation already produced once.

## Status

Rust only, so far. The C and Python ports and a wire section in the conformance
stream are the next step — a canonical format verified in one substrate is a
format with one opinion about what canonical means.
