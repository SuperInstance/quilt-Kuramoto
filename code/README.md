# Code

Re-nested into each artifact's original repository layout (see
`docs/PROVENANCE.md` for the evidence behind every placement).

**Nothing here builds as-is.** Testbenches, several formal harnesses, build
directory structure and some generator inputs were never uploaded — see
`docs/MISSING.md`. Read it; don't expect to run it.

Ordered by how much is actually built and measured:

| Repo | Language | State |
|---|---|---|
| `quilt-verilog` | Verilog-2005 | **Synthesised and measured on real toolchains.** Partly formally proven. Honest negative results committed. |
| `quilt-esp32` | C/C++/Python | **Flashed on real hardware** (2026-08-26). 5 lanes, each with a desktop host harness. |
| `nmea-quilt-cell` | Python | **Genuinely tested.** Byte-exact replay + SIGKILL crash canary. |
| `scrap-quilt` | TypeScript | Coherent, complete Cloudflare Workers app. |
| `quilt-substrate-meta` | C99 | Complete library; all includes resolve. Untested here. |
| `quilt-vm-c` | C99 | Small, complete, vendored downstream. |
| `quilt-foundation` | Python | A ~200-line VM plus 10 rounds of LLM brainstorming. |
| `quilt-id` | Python | Single module; its tests 404'd. |
| `quilt-cuda` | CUDA | **Written, never compiled** — author's own stamp. One source file missing. |
| `quilt-esp32-rust-sketch` | Rust | **Not an implementation.** Author calls it a design sketch. |
| `quilt-llvm` | — | Doctrine and glossary only. |

Note `quilt-substrate-meta` (C99, here) is a different thing from
`quilt-substrate` (Python, README only in `repo-readmes/`), despite the names.
