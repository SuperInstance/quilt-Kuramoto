#!/usr/bin/env python3
"""Do all three substrates encode the same value to the same BYTES?

`WIRE-FORMAT.md` claims the encoding is canonical — bijective on the value
space, so hashing the bytes is equivalent to hashing the value. That claim is
only meaningful across implementations: a format verified in one substrate is a
format with one opinion about what canonical means.

Emits the Python substrate's encoding of a fixed value set. The Rust and C
emitters print the same list; `check-substrates.sh` compares all three.

Usage: python3 wire_check.py
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "tminus-band"))

from tminus_band.wire import write_banded, write_zono  # noqa: E402
from tminus_band.zono import Symbols, Zono  # noqa: E402

I32_MIN, I32_MAX = -(1 << 31), (1 << 31) - 1
U32_MAX = (1 << 32) - 1


def emit(name: str, data: bytes) -> None:
    print(f"{name} {data.hex()}")


def main() -> None:
    emit("banded/zero", write_banded(0, 0))
    emit("banded/neg-one", write_banded(-1, 1))
    emit("banded/small", write_banded(127, 255))
    emit("banded/neg-small", write_banded(-128, 256))
    emit("banded/i32-min", write_banded(I32_MIN, 0))
    emit("banded/i32-max", write_banded(I32_MAX, U32_MAX))

    pool = Symbols()
    emit("zono/exact", write_zono(Zono.exact(0)))
    emit("zono/exact-neg", write_zono(Zono.exact(-123456789)))
    emit("zono/one-term", write_zono(Zono.from_symbol(1000, 7, 12)))

    # Consecutive ids exercise the zero-delta case; mixed signs exercise zigzag.
    acc = Zono.exact(-5)
    for k in range(1, 6):
        acc = acc.add(Zono.from_symbol(0, k, k * 100 * (-1 if k % 2 == 0 else 1)), pool)
    emit("zono/consecutive", write_zono(acc))

    # Sparse ids exercise large deltas.
    acc = Zono.exact(7)
    for k in (1, 1000, 70000, 4000000000):
        acc = acc.add(Zono.from_symbol(0, k, k % 977 + 1), pool)
    emit("zono/sparse", write_zono(acc))

    # Full capacity. k == 8 gives coefficient 0, which is dropped rather than
    # encoded — a zero term must be absent or the encoding would not be unique.
    acc = Zono.exact(1)
    for k in range(1, 17):
        acc = acc.add(Zono.from_symbol(0, k * 3, k - 8), pool)
    emit("zono/full", write_zono(acc))


if __name__ == "__main__":
    main()
