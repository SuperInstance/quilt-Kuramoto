#!/usr/bin/env python3
"""Cross-substrate check of the agreement result itself.

`exact-band/examples/agreement.rs` is the headline claim of the zonotope work:
after consensus on a ring, the enclosure of `x0 - x1` collapses to zero while
interval arithmetic stays pinned forever. It was measured in Rust only.

This emits the width sequence from the Python substrate. The C and Rust
harnesses emit the same sequence, and `check-substrates.sh` compares all three,
so the claim is held to the same standard as the rest of the algebra rather than
resting on one implementation.

Usage: python3 agree_check.py [rounds]
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "tminus-band"))

from tminus_band.zono import Fixed, Symbols, Zono  # noqa: E402

N = 3
CENTER = 1000
RADIUS = 12


def widths(rounds: int) -> list[int]:
    pool = Symbols()
    syms = [pool.fresh() for _ in range(N)]
    z = [Fixed(Zono.from_symbol(CENTER, syms[i], RADIUS)) for i in range(N)]
    out = []
    for _ in range(rounds + 1):
        d = z[0].sub(z[1], pool)
        out.append(1000 * d.width_scaled() // (1 << d.shift))
        prev = list(z)
        for i in range(N):
            z[i] = (prev[i].scale(2)
                    .add(prev[(i + N - 1) % N], pool)
                    .add(prev[(i + 1) % N], pool)
                    .div_pow2(2))
    return out


if __name__ == "__main__":
    r = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    print("agreement_widths=" + ",".join(str(w) for w in widths(r)))
