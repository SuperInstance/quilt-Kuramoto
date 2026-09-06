# The conformance stream — a specification

`vectors.json` pins **chosen** cases: boundaries, extremes, the exact inputs that
once exposed a bug. That is what a golden fixture is good at, and it is why the
odd rings are in there.

What it cannot do is cover cases nobody thought of. 801 vectors is 801 opinions
about where the bugs are.

The **conformance stream** covers the rest. Each substrate walks the same
deterministic pseudo-random sequence, applies the same operations, and folds
every answer into a 64-bit checksum. If the checksums match, every case in the
stream agreed — at a cost of one number per substrate rather than one record per
case, so the case count can be raised to millions without a file growing at all.

A single differing bit anywhere changes the checksum. That is the point: the
stream cannot tell you *which* case diverged, only that one did. It is a tripwire,
not a diagnostic. When it fires, bisect with `--print-first-divergence`, or narrow
by iteration count.

This file is the specification. All three implementations are written from it,
and it is deliberately explicit about the arithmetic, because "obvious" choices —
which way `%` rounds a negative, whether a shift is logical or arithmetic — are
exactly where three substrates quietly part company.

## The generator

`xorshift64`, all operations in unsigned 64-bit with wraparound:

```
next(state):
    state ^= state << 13     (mod 2^64)
    state ^= state >> 7      (logical shift, zero-fill)
    state ^= state << 17     (mod 2^64)
    return state
```

Seeded with `0x2545F4914F6CDD1D`. The seed is nonzero, which xorshift requires:
zero is a fixed point.

Python must mask after every step (`& 0xFFFF_FFFF_FFFF_FFFF`); Rust must use
`wrapping_shl`-equivalent semantics via `<<` on `u64`, which already wraps in
release and panics on overflow only for arithmetic, not shifts, so plain `<<` on
`u64` is correct. C's `uint64_t` wraps by definition.

## The checksum

FNV-1a-style folding, again in unsigned 64-bit:

```
mix(h, v):
    h ^= v
    h *= 0x100000001B3     (mod 2^64)
    return h
```

Starting from `h = 0xCBF29CE484222325`. Booleans are mixed as `1` or `0`, signed
values by their **two's-complement bit pattern** reinterpreted as unsigned — never
by a decimal rendering, which would make the checksum depend on formatting.

## Drawing values

`scale` is chosen per iteration, so the stream spends time both where bands
overlap and where they are far apart:

```
scale_index = next() % 4
scale       = [16, 1024, 1000000, 1239850262][scale_index]
```

`1239850262` is `EB_COORD_MAX_Z3`, the tightest coordinate limit any of the three
substrates has — the C port's, from the hexagonal norm's three squared terms. The
stream stays inside every substrate's reach by construction, so nothing is ever
skipped and the checksums are directly comparable.

```
coord(u, scale) = (u mod (2*scale + 1)) - scale        as a signed value
```

`mod` here is on unsigned values, so it is unambiguous.

## One iteration

In this exact order — the order is part of the specification, because the
generator is consumed sequentially:

| # | draws | operations mixed in |
|---|---|---|
| 1 | `n` | `isqrt(n)`, `isqrt_ceil(n)` |
| 2 | `dim = 1 + next() % 3`, `basis = next() % 100000`, `eps = next() % 100000` | `basis_meets(dim, basis, eps)`, `max_basis(dim, eps)` |
| 3 | `scale_index`, then `ax ay az bx by bz` via `coord` | `dist_sq_z1(ax,bx)`, `dist_sq_z2`, `dist_sq_z3`, `dist_sq_hex` |
| 4 | `r1 = next() % (scale+1)`, `r2` likewise, both capped at `1073741823` | `overlaps(a,b)`, `within(a,b)`, `within(b,a)`, `narrow(a,b)` → kind, then radius+value or `gap_sq` |
| 5 | `basis2 = next() % 65536` | `from_basis` radius at dim 1, 2 and 3 |
| 6 | four `coord` draws, sorted into `lo <= hi` per axis | 2-axis `narrow` → per-axis `lo`,`hi`, or `disagreement` → axis, gap |
| 7 | `ring = RINGS[next() % 8]`, `pa`, `pb` as raw 64-bit signed | `distance(ring, pa, pb)`, `offset(ring, pa, pb)` |

`RINGS = [2, 3, 5, 7, 12, 360, 361, 1000]`. Both odd and even, because that is the
distinction that hid the `offset_to` bug for weeks.

Where `narrow` returns a box, the per-axis bounds are mixed. Where it does not,
the axis index and gap are mixed instead — and the *kind* is mixed either way, so
a substrate that returned a box where another returned a disagreement diverges
even if the numbers it produced happened to collide.

## The committed answer

For seed `0x2545F4914F6CDD1D`, the checksums are recorded in `stream.json` at
several iteration counts. All three substrates must reproduce all of them.

Several counts rather than one, so a divergence that first appears late is still
localised to a range rather than only to "somewhere in ten million".

## Does it actually catch anything?

A check that has never failed is a check nobody has tested. Four mutations were
introduced into the C library and the whole pipeline run against each:

| mutation | unit tests | vectors | stream |
|---|---|---|---|
| `isqrt_ceil` stops rounding up | **caught** | caught | caught |
| `from_basis` bisects to the floor | **caught** | caught | caught |
| `disagreement` returns the first axis, not the worst | **caught** | caught | caught |
| the odd-ring `offset_to` bug, reintroduced | caught | **caught** | caught |
| `basis_meets` wrong at one value in 100 000 | passes | passes | **caught** |

The first four are honest about something: for bugs the fixture was designed
around, the stream is a **second net, not the only one**. That is worth saying
plainly rather than implying the stream found them.

The last row is what the stream is for. The fixture's `basis` values are
`{0, 1, 2, 3, 5, 8, 13, 100, 1000, 65535}` and its `eps` never exceeds 255; the
unit tests sweep `basis` to 300 and `eps` to 400. A defect at basis 77 777 is
outside every one of those, and both other layers report PASS while the stream —
which draws `basis` uniformly from `[0, 100000)` — diverges immediately.

That mutation is synthetic. It is not a bug that occurred; it is a marker placed
to measure reach. The measurement is the point: **801 vectors is 801 opinions
about where the bugs are**, and the stream covers the space those opinions do not.

## Cost

At one million iterations the Rust and C substrates finish in under a second.
Python takes about half a minute, so `check-substrates.sh` runs it at 100 000 by
default — a speed decision, not a trust one. Its answer at the full million is
recorded in `stream.json` and matches the other two exactly.

Raise any of them with `STREAM_RS_ITERS`, `STREAM_C_ITERS`, `STREAM_PY_ITERS`.
