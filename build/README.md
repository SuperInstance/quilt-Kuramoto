# build/ — new work, staged for extraction

Code written here that does **not** belong in this archive long-term. Each
directory is a complete standalone project waiting for its own repository.

Run `./check-substrates.sh` to hold all five projects to the same arithmetic in
one command. It also checks something nothing checked before: that the committed
`vectors.json` is still what `emit_vectors` produces. A golden file that has
drifted from its generator makes every substrate agree on a stale answer, and
that failure is invisible from inside any one of them.

## `exact-band/`

**Ready to extract.** A `no_std` Rust crate: exact lattice values carrying an
integer tolerance band, where confirmation narrows the band instead of returning
pass/fail. No floating point, no square roots.

- 48 tests (52 with `--all-features`), clippy-clean under `-D warnings` in both
  feature configurations
- Builds for `thumbv7em-none-eabihf` (bare-metal Cortex-M4F)
- Mutation-tested: five deliberate bugs introduced, all five caught
- Zero dependencies (optional `eisenstein` interop behind a feature flag)

Two independent scouts confirmed nothing in the `SuperInstance` org already does
this, and that the name `exact-band` is unclaimed.

### To extract it

Repo creation from this session failed — `POST /orgs/SuperInstance/repos`
returned 404, i.e. the GitHub App installed here can read the org but is not
granted repository creation in it. Once an empty `SuperInstance/exact-band`
exists:

```bash
cd build/exact-band
git init && git add -A
git commit -m "exact-band v0.1.0"
git remote add origin https://github.com/SuperInstance/exact-band.git
git push -u origin main
```

Nothing else needs changing — `Cargo.toml` already points `repository` at that URL.

## `exact-band-c/`

**Ready to extract.** The C99 port of `exact-band`, and the third substrate.
One `.c` file, one header, **1,553 bytes of text at `-Os`** with zero `data` and
zero `bss`. No allocation, no dependency beyond `<stdint.h>`, no floating-point
type — and `make nofloat` checks that last claim rather than asserting it.

- Reads the *same* `vectors.json` the Rust and Python substrates read, parsing it
  rather than transcribing it. 471 vectors, 1,676 checks.
- 4,385,501 unit checks against definitions rather than against a sibling — a
  shared mistake reproduces perfectly across substrates, so agreement alone
  proves nothing.
- Every range limit (`EB_COORD_MAX`, `EB_RADIUS_MAX`, `EB_SCALE_MAX`) is the
  largest value whose square still fits in `uint64_t`, and the tests assert both
  that it fits and that one more does not. The four vectors beyond that reach are
  skipped, counted, and the count is asserted.
- Clean under gcc and clang, `-std=c99/c11/c17`, `-Werror -pedantic
  -Wconversion -Wsign-conversion`, and `-fsanitize=undefined,address`. A genuine
  32-bit build is **not** verified here — `-m32` needs multilib this container
  lacks.

Writing its negative control disproved the stated reason for its own fix: the
`Phase::offset_to` correction was the normalisation into `[0, N)`, not the
`2·d > n` comparison the commit message credited. Details in its README.

Same extraction procedure, with `SuperInstance/exact-band-c` as the remote.

## `tminus-band/`

**Ready to extract.** The Python half: exact tolerance bands wired into
`swarm-tminus`'s predict-and-confirm loop, so a countdown fires on *what is
known* rather than on a head-count.

- 23 tests, none skipped, including 5 live integration tests against the real
  installed `swarm-tminus` (0.2.2)
- **471 golden vectors** shared with `exact-band` — the Python port is held to
  the Rust crate byte-for-byte, and the vectors file is verified in sync with
  its generator
- Stdlib only, no dependencies; no float ever reaches the serialised state
- Works today with **no upstream change** (band rides in the existing
  `CountdownEvent.payload`); `upstream/swarm-tminus-knowledge-gate.patch`
  proposes the one-line change for proper integration

Same extraction procedure as above, with `SuperInstance/tminus-band` as the
remote. Regenerate the conformance vectors any time with:

```bash
cd ../exact-band && cargo run --release --example emit_vectors > ../tminus-band/tests/vectors.json
```

## `tower/`

**Ready to extract.** Lifted out of `quilt-verilog/tools/tower/emith.py`, which
had zero coupling to Verilog but was buried in an FPGA repo. Compiles a
physical-quantity cell spec into exact, float-free C — and **refuses to compile
it when the units don't work out**.

- 15 tests, including a mutation test proving the gate can fail
- Reproduces all **17 hand-computed golden anchors** from the original's
  `verify.py`, so compatibility is measured rather than asserted
- Loads the original `oil-pressure-port.cell.yaml` unmodified
- Generalised: any unit, any range including negative, optional offset/divisor —
  the original was psi-only and rejected non-zero minimums
- The gate compiles the generated C with `-Wall -Wextra -Werror`, runs it, and
  cross-checks every printed line against a Python model *and* exact `Fraction`
  arithmetic

Same extraction procedure, with `SuperInstance/tower` as the remote.

## `phase-lock/`

**The experiment this repository is named for.** Discrete-time Kuramoto
oscillators in exact integer arithmetic, where a collision is `==` rather than a
comparison against a chosen epsilon.

- **Frozen locking implies crossings stop: 2,600 runs, 1,069 locked, zero
  counterexamples.** An exact claim, observable only because both sides are
  equalities.
- Found and corrected two definitional errors: a *coincidence* (state) is not a
  *crossing* (event) — they measurably invert — and phase-locked is not
  synchronised, since the splay state is locked at maximum spread.
- Measured a sharp **upper critical coupling** near K=1.25, a discrete-map
  phenomenon with no continuous-Kuramoto counterpart.
- 24 tests, plus `run_study.py` and `run_band_study.py`, which together
  regenerate every number in the README.

Built on `exact-band`'s `Phase<N>`. Same extraction procedure, with
`SuperInstance/phase-lock` as the remote.
