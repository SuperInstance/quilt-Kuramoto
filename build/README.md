# build/ — new work, staged for extraction

Code written here that does **not** belong in this archive long-term. Each
directory is a complete standalone project waiting for its own repository.

## `exact-band/`

**Ready to extract.** A `no_std` Rust crate: exact lattice values carrying an
integer tolerance band, where confirmation narrows the band instead of returning
pass/fail. No floating point, no square roots.

- 38 tests, clippy-clean under `-D warnings` in both feature configurations
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

## `tminus-band/`

**Ready to extract.** The Python half: exact tolerance bands wired into
`swarm-tminus`'s predict-and-confirm loop, so a countdown fires on *what is
known* rather than on a head-count.

- 23 tests, none skipped, including 5 live integration tests against the real
  installed `swarm-tminus` (0.2.2)
- **240 golden vectors** shared with `exact-band` — the Python port is held to
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
