# quilt-conformance — turning a badge into a proof

Several SuperInstance ports carry a shields.io badge reading **`byte-exact`**
with the hash `0xe435d91d6d92a1d8`.

An audit of that claim found:

| repo | hash in README | hash in source | claim |
|---|---|---|---|
| `quilt-go` | ✓ | ✓ | supported |
| `quilt-rust-vibe` | ✓ | ✓ | supported |
| `quilt-c` | ✓ | **✗** | badge + "produces `0x…` byte-exactly" |
| `quilt-verilog` | ✓ | **✗** | same |
| `quf-vhdl` | ✓ | **✗** | same |
| `quilt-cell` | **✗** | **✗** | "**Byte-exact** with the Python, C, Rust, Verilog, and VHDL ports" |

The three middle rows share a copy-paste artefact on the *same line number*:

```
quilt-c:        | C99 (C99)     | ✓ | manual |
quilt-verilog:  | C99 (Verilog) | ✓ | manual |
quf-vhdl:       | C99 (VHDL)    | ✓ | manual |
```

"C99" left in the language column with the repo name substituted in parentheses
is what a template pass looks like, not a verification pass.

**The protocol is not the problem.** It is real and completely specified, and
this directory's reference implementation reproduces the published hash from the
written spec alone — 65 bytes, FNV-1a 64. The problem is that conformance was
*asserted*, and that a single hardcoded hash for a single fixed cell could not
have demonstrated it even where the code did compute it.

## Why one vector cannot be a conformance suite

The published cell is `id=1, dials=[1..16], neighbours=[2,3,4]`. Every value in
it is small and positive, the neighbour list is already ascending, and nothing
is near a boundary. A port can match that hash while being wrong about signed
dials, i16 endpoints, an empty neighbour list, a 64-bit id, or neighbour
ordering — none of which that cell exercises.

So this corpus is chosen so that a port failing any **one** case has a specific,
nameable bug:

| case | bytes | catches |
|---|---|---|
| `published` | 65 | (superset of the existing claim) |
| `zero` | 41 | special-cased emptiness, omitted zero-length tail |
| `negative-dials` | 49 | signed/unsigned confusion in Q1.15 |
| `dial-extremes` | 49 | clamping, off-by-one range checks |
| `alternating` | 65 | sign handling that only works uniformly |
| `neighbour-order` | 65 | **a port that sorts neighbours** |
| `big-id` | 49 | a signed or 32-bit id |
| `many-neighbours` | 297 | fixed-size buffers, length assumptions |

`neighbour-order` is the sharp one. It holds the same neighbours as `published`
in a different order and therefore a *different* hash — so a port that sorts
them produces the published hash here and is caught, where the single-vector
badge would have passed it.

Plus a **stream checksum** in the style of [`../CONFORMANCE-STREAM.md`](../CONFORMANCE-STREAM.md):
10,000 generated cells folded into one number, covering the cases nobody chose.

## Running it

```sh
python3 reference.py     # asserts the published hash, regenerates vectors.json
```

Any port claims conformance by reproducing every hash in `vectors.json` and the
stream checksum — and can then display a badge that means something.

## Status and scope

**Three references — Python, C99 and Rust — agree on all 8 cases and the
10,000-cell stream.** `./check.sh` compares the hashes and fails if any two
disagree, if fewer than 9 are produced, or if the published badge value is
missing from the corpus. Flipping the C serializer to big-endian makes it fail
immediately, which is the control.

The C and Rust references are standalone on purpose — one `cc` and one `rustc`
invocation, no crate, no build system — so a port author can check their work
without adopting anything from here.

A note on how this file was nearly wrong: the first version of `check.sh`
diffed the whole output and reported a divergence that turned out to be Python
printing `65B` where C printed `65`. A harness bug dressed as a substrate
disagreement — the exact mistake this directory exists to stop people making.
It now compares hashes and nothing else.

This is a finding about public claims in repositories **this work does not
own**, so nothing outside `quilt-Kuramoto` has been modified. The corpus is
offered as the fix; whether to adopt it, and whether to correct or remove the
unsupported badges, is the owner's call.
