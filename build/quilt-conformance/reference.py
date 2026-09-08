#!/usr/bin/env python3
"""Reference implementation and conformance corpus for the Quilt cell state hash.

WHY THIS EXISTS
---------------
Several SuperInstance ports advertise a `byte-exact` badge carrying the hash
`0xe435d91d6d92a1d8`. Auditing them found the hash present only in the README of
`quilt-c`, `quilt-verilog` and `quf-vhdl` -- never in their source -- while
`quilt-cell` claims byte-exactness with five ports without the hash appearing
anywhere in the repository at all. Three of those READMEs share a copy-paste
artefact on the same line number (`C99 (C99)` / `C99 (Verilog)` / `C99 (VHDL)`),
which is what a template pass looks like rather than a verification pass.

The protocol itself is real. This file reproduces the published hash from the
written spec alone, so the problem is not the design -- it is that "conformance"
was asserted rather than demonstrated, and that a single hardcoded hash for a
single fixed cell could not have demonstrated it anyway.

One vector proves one cell. A port can pass it while being wrong about
negative dials, empty neighbour lists, wraparound, or byte order on any value
that happens not to appear in that one cell. This emits a corpus that exercises
those, plus a checksum fold over many generated cells in the style of
`../CONFORMANCE-STREAM.md`, so a port can prove conformance instead of claiming
it.

THE SPEC, restated
------------------
Canonical serialization, little-endian throughout:

    type(1) || id(8) || dials(16 x 2) || neighbours(N x 8)      = 41 + 8N bytes

  * `type`  one byte; 1 for a cell
  * `id`    u64
  * `dials` exactly 16 signed Q1.15 values, i16 each
  * `neighbours` N u64 ids, in the order given -- NOT sorted, so a port that
    reorders them will diverge, which is intentional: order is part of the value

State hash is FNV-1a 64-bit (offset 0xcbf29ce484222325, prime 0x100000001b3)
over exactly those bytes.

Verified: the published test cell (id=1, dials=[1..16], neighbours=[2,3,4])
serializes to 65 bytes and hashes to 0xe435d91d6d92a1d8.
"""

import json
import pathlib
import struct
import sys

FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3
MASK = (1 << 64) - 1

TYPE_CELL = 1
N_DIALS = 16


def fnv1a64(data: bytes) -> int:
    h = FNV_OFFSET
    for b in data:
        h ^= b
        h = (h * FNV_PRIME) & MASK
    return h


def serialize(cell_id: int, dials, neighbours, type_byte: int = TYPE_CELL) -> bytes:
    """Canonical bytes for a cell. Raises rather than truncating or padding.

    A serializer that quietly accepted 15 dials, or clamped an out-of-range one,
    would let two ports agree on a hash while disagreeing about the value — the
    exact failure a conformance corpus exists to expose.
    """
    if len(dials) != N_DIALS:
        raise ValueError(f"need exactly {N_DIALS} dials, got {len(dials)}")
    for d in dials:
        if not -32768 <= d <= 32767:
            raise ValueError(f"dial {d} outside i16")
    for n in neighbours:
        if not 0 <= n <= MASK:
            raise ValueError(f"neighbour id {n} outside u64")
    out = bytes([type_byte]) + struct.pack("<Q", cell_id)
    out += b"".join(struct.pack("<h", d) for d in dials)
    out += b"".join(struct.pack("<Q", n) for n in neighbours)
    return out


def state_hash(cell_id: int, dials, neighbours) -> int:
    return fnv1a64(serialize(cell_id, dials, neighbours))


# --- the corpus -----------------------------------------------------------
#
# Each case names what it is for. A vector that exists only to be numerous
# teaches nothing; these are chosen so a port failing any ONE of them has a
# specific, nameable bug.

def corpus():
    cases = []

    def add(name, cell_id, dials, neighbours, why):
        cases.append({
            "name": name,
            "why": why,
            "id": cell_id,
            "dials": list(dials),
            "neighbours": list(neighbours),
            "bytes": len(serialize(cell_id, dials, neighbours)),
            "hash": f"0x{state_hash(cell_id, dials, neighbours):016x}",
        })

    add("published", 1, range(1, 17), [2, 3, 4],
        "the single cell every existing badge cites; kept so this corpus is a "
        "superset of what is already claimed")
    add("zero", 0, [0] * 16, [],
        "empty neighbour list and an all-zero body -- catches a port that "
        "special-cases emptiness or omits the length-zero tail")
    add("negative-dials", 7, [-d for d in range(1, 17)], [1],
        "every dial negative -- catches unsigned/signed confusion in Q1.15")
    add("dial-extremes", 9, [-32768, 32767] * 8, [5],
        "i16 endpoints -- catches clamping and off-by-one range checks")
    add("alternating", 3, [(-1) ** i * (i + 1) for i in range(16)], [9, 8, 7],
        "mixed signs -- catches sign handling that only works uniformly")
    add("neighbour-order", 4, range(1, 17), [3, 2, 4],
        "same neighbours as `published` in a DIFFERENT order; a port that "
        "sorts them will produce the published hash here and be wrong")
    add("big-id", 0xFFFFFFFFFFFFFFFF, range(1, 17), [0xFFFFFFFFFFFFFFFF],
        "u64 maximum -- catches a port using a signed or 32-bit id")
    add("many-neighbours", 11, range(1, 17), list(range(1, 33)),
        "32 neighbours -- catches fixed-size buffers and length assumptions")
    return cases


def stream_checksum(iterations: int = 10000) -> int:
    """Fold many generated cells into one checksum.

    Same discipline as ../CONFORMANCE-STREAM.md: a corpus proves the cases
    someone thought of; this covers the ones nobody did, at a cost of one
    number. xorshift64 so every substrate can reproduce the sequence exactly.
    """
    state = 0x2545F4914F6CDD1D
    h = FNV_OFFSET

    def nxt():
        nonlocal state
        x = state
        x ^= (x << 13) & MASK
        x ^= x >> 7
        x ^= (x << 17) & MASK
        state = x
        return x

    for _ in range(iterations):
        cell_id = nxt()
        dials = [((nxt() % 65536) - 32768) for _ in range(N_DIALS)]
        n_nb = nxt() % 9
        neighbours = [nxt() for _ in range(n_nb)]
        h ^= state_hash(cell_id, dials, neighbours)
        h = (h * FNV_PRIME) & MASK
    return h


if __name__ == "__main__":
    published = state_hash(1, range(1, 17), [2, 3, 4])
    assert published == 0xE435D91D6D92A1D8, f"got 0x{published:016x}"
    assert len(serialize(1, range(1, 17), [2, 3, 4])) == 65

    cases = corpus()
    doc = {
        "_": "Conformance corpus for the Quilt cell state hash. See reference.py.",
        "spec": "type(1) || id(8 LE) || dials(16 x i16 LE) || neighbours(N x u64 LE); FNV-1a 64",
        "cases": cases,
        "stream": {
            "algorithm": "xorshift64 seeded 0x2545F4914F6CDD1D; fold each cell's "
                         "state hash with FNV-1a",
            "10000": f"0x{stream_checksum(10000):016x}",
        },
    }
    pathlib.Path("vectors.json").write_text(json.dumps(doc, indent=2) + "\n")

    print(f"published cell: 0x{published:016x}  (matches the badge)")
    for c in cases:
        print(f"  {c['name']:<18} {c['bytes']:>4}B  {c['hash']}")
    print(f"stream(10000):  {doc['stream']['10000']}")
    print("wrote vectors.json")
    sys.exit(0)
