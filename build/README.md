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
