# SMT bounded-equivalence checks for exact-band's C/Rust arithmetic core.
#
# Prototype, not CI-hardened: this exists to answer "is bounded SMT
# equivalence checking tractable here", and the answer plus its evidence
# live in README.md and ../../research/09-SMT-EQUIVALENCE.md. Read those
# before trusting any of these targets' verdicts.

PY ?= python3

.PHONY: check env phase-offset div-nearest basis-meets isqrt isqrt-wide clean

# Default target: everything a `make check` in this directory should run --
# mirrors the top-level check-substrates.sh convention of one command that
# gives a pass/fail verdict. Skips gracefully (exit 2, clear message) if
# z3-solver is not installed; does not fail the whole repo's build.
check: env
	$(PY) run_all.py

# Confirms the solver is actually present before running anything, with the
# same message run_all.py itself gives -- useful on its own when setting up
# a new machine.
env:
	@$(PY) -c "import z3; print('z3-solver', z3.get_version_string(), 'found -- OK')" \
		|| (echo "z3-solver not installed: pip install z3-solver"; echo "(every other target below will skip gracefully with the same message)"; exit 0)

# Individual targets, each self-contained: fail-first bug injection, then
# the real check. Useful when iterating on one function without paying for
# the whole suite (isqrt-wide especially -- see its own comment below).

phase-offset: env
	$(PY) check_phase_offset.py --bug --n-bits 10 --val-bits 14
	$(PY) check_phase_offset.py --n-bits 32 --val-bits 63 --timeout-ms 60000

div-nearest: env
	$(PY) check_div_nearest.py --bug --val-bits 10 --timeout-ms 30000
	$(PY) check_div_nearest.py --val-bits 63 --timeout-ms 60000

basis-meets: env
	$(PY) check_basis_meets.py --bug --timeout-ms 30000
	$(PY) check_basis_meets.py --full-u32-domain --timeout-ms 30000
	$(PY) check_basis_meets.py --timeout-ms 30000

isqrt: env
	$(PY) check_isqrt.py --check-convergence --width 16 --unroll 10 --timeout-ms 30000
	$(PY) check_isqrt.py --width 16 --rust-extra-bits 16 --unroll 10 --timeout-ms 60000

# NOT part of `make check` -- this attempts the real crate widths (u32-native
# C vs u64-native Rust, a smaller proxy for the true u64-vs-u128) and is
# EXPECTED to report UNKNOWN/timeout at the default budget. It exists so the
# "where this stops scaling" claim in the README is something you can run,
# not just read. Give it minutes, not seconds, if you raise --timeout-ms.
isqrt-wide: env
	$(PY) check_isqrt.py --check-convergence --width 32 --unroll 12 --timeout-ms 90000
	$(PY) check_isqrt.py --width 32 --rust-extra-bits 32 --unroll 12 --timeout-ms 90000

clean:
	rm -rf __pycache__
