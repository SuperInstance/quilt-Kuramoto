# WORLD-CLASS BRIEF — quilt-verilog as a primary repo

Casey's directive (2026-08-29): this repo is PRIMARY. It must be world class, including documentation. Built and respected by teams of iterators.

## The standard (what "world class" means here)
- **The README sells nothing and proves everything.** A first-time visitor — a Verilog engineer who has never heard of the quilt — must go from the five opcodes to a bitstream on iCE40 in under 30 minutes, using only files in this repo. (UNDERSLL, OVERDELIVER: the fact in the README, the trail in the docs.)
- **Every claim traceable.** Docs cite tests, formal proofs (formal/*.sby), or synthesis results. No prose claim without an artifact behind it.
- **One command works.** `make test` (sim), `make formal` (sby proofs), `make synth` (iCE40 flow). Missing targets are bugs.
- **Docs have an index.** 77 .md files with no map is a maze. docs/INDEX.md: every document, one line, sorted by reader intent (I want to understand X / verify Y / build Z).
- **Failures first-class.** proposals/ and review-*.md are the tapestry — keep them, present them, date them.

## Known gaps (found 2026-08-29 audit)
1. README.md is 19 lines — no quickstart, no results table, no links into docs/.
2. No root Makefile; `make test` fails. Entry points scattered (sim/, formal/, synth/).
3. No docs/INDEX.md; docs/academic/ vs docs/ split unexplained.
4. Stray build/scratch artifacts untracked (obj_dir/, __pycache__, tb/scratch) — .gitignore needed.
5. rtl/ README points at proposals competition; actual state of rtl/ modules vs proposals undocumented.
6. No CONTRIBUTING/verification guide for a new iterator (how to run iverilog, verilator, sby, nextpnr locally).

## Iterator protocol (teams of iterators)
Each iterator lane: AUDIT → FIX → MEASURE → COMMIT. One theme per pass (README/quickstart; Makefile/CI; docs index; formal-proof writeups; synthesis results table). Every commit states what it verified. Different models rotate through lanes (deepseek, kimi, opencode, claude) — a tapestry of iterations, each told why it changed. Never destroy: archive-by-rename.
