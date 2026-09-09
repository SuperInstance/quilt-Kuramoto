#!/usr/bin/env python3
"""
Run every check in this directory and print one consolidated verdict table.

Chooses bounds that finish in roughly a minute total on a typical machine.
For the exact commands, timings, and what each verdict actually means, read
README.md -- this script is a convenience runner, not a substitute for it.

Exits nonzero if z3 is unavailable, or if any fail-first (--bug) check
failed to produce a counterexample (which would mean the checker itself is
broken and nothing else here should be trusted).
"""
import subprocess
import sys
import time

HERE = __file__.rsplit("/", 1)[0]

try:
    import z3  # noqa: F401
except ImportError:
    print("z3-solver is not installed in this Python environment.")
    print("  pip install z3-solver")
    print()
    print("Skipping all SMT equivalence checks -- nothing below was proved or")
    print("disproved. This is the honest outcome when the solver is absent,")
    print("not a silent no-op.")
    sys.exit(2)

STEPS = [
    ("phase_offset fail-first (historical bug reintroduced)",
     ["check_phase_offset.py", "--bug", "--n-bits", "10", "--val-bits", "14"], "sat", None),
    ("phase_offset equivalence (FULL domain: all u32 n, all i64 a,b)",
     ["check_phase_offset.py", "--n-bits", "32", "--val-bits", "63", "--timeout-ms", "60000"], "unsat", None),
    ("div_nearest fail-first (naive truncating-division bug)",
     ["check_div_nearest.py", "--bug", "--val-bits", "10", "--timeout-ms", "30000"], "sat", None),
    ("div_nearest equivalence (FULL i64 x i64 domain -- expect a REAL divergence at the overflow boundary)",
     ["check_div_nearest.py", "--val-bits", "63", "--timeout-ms", "60000"], "sat",
     "NOT a checker bug: this is a REAL divergence, confirmed against actual\n"
     "    `gcc -O2`, `clang -O2`, and `rustc -O` output (not just the two z3\n"
     "    models) -- C's native int64 arithmetic wraps near i64::MIN/MAX, Rust's\n"
     "    i128 intermediate never does for i64-range inputs. It sits far outside\n"
     "    every value this crate's real callers pass (bounded by EB_SCALE_MAX,\n"
     "    ~2^31) -- see README, 'A genuine divergence, not a modelling artifact'."),
    ("basis_meets fail-first (< instead of <= off-by-one)",
     ["check_basis_meets.py", "--bug", "--timeout-ms", "30000"], "sat", None),
    ("basis_meets: full u32 domain (expect a REAL divergence: differing guard clauses)",
     ["check_basis_meets.py", "--full-u32-domain", "--timeout-ms", "30000"], "sat",
     "Expected: C rejects dim==0/dim>3/out-of-range basis,eps outright; Rust's\n"
     "    formula is unguarded. See README for the documented shared domain."),
    ("basis_meets equivalence (documented shared domain: dim in 1..3, basis/eps <= EB_SCALE_MAX)",
     ["check_basis_meets.py", "--timeout-ms", "30000"], "unsat", None),
    ("isqrt convergence check (u16 domain, 10-step unroll)",
     ["check_isqrt.py", "--check-convergence", "--width", "16", "--unroll", "10", "--timeout-ms", "30000"], "unsat", None),
    ("isqrt equivalence (u16-native C model vs u32-native Rust model, all n < 2^16)",
     ["check_isqrt.py", "--width", "16", "--rust-extra-bits", "16", "--unroll", "10", "--timeout-ms", "60000"], "unsat",
     "Scaled proxy for the real u64-vs-u128 functions -- see README for why\n"
     "    the real widths are not attempted by default (they don't finish)."),
]

STATUS_WORD = {"sat": "SAT", "unsat": "UNSAT", "unknown": "UNKNOWN/TIMEOUT"}


def run_step(name, args, expect):
    t0 = time.time()
    proc = subprocess.run(
        [sys.executable, f"{HERE}/{args[0]}"] + args[1:],
        capture_output=True, text=True,
    )
    elapsed = time.time() - t0
    out = proc.stdout + proc.stderr
    if "RESULT: EQUIVALENT" in out or "RESULT: CONVERGES" in out:
        got = "unsat"
    elif "RESULT: DIVERGENCE FOUND" in out or "RESULT: NON-CONVERGENCE FOUND" in out:
        got = "sat"
    elif "RESULT: UNKNOWN" in out:
        got = "unknown"
    else:
        got = "error"
    ok = (got == expect)
    return ok, got, elapsed, out


def main():
    print("=" * 78)
    print("SMT equivalence checks -- build/smt-equivalence/")
    print("Modelled semantics, not compiled code -- see README.md before trusting")
    print("any verdict below.")
    print("=" * 78)

    results = []
    any_fail_first_broken = False
    for name, args, expect, note in STEPS:
        ok, got, elapsed, out = run_step(name, args, expect)
        results.append((name, ok, got, expect, elapsed))
        mark = "OK" if ok else "** UNEXPECTED **"
        print(f"\n[{mark}] {name}")
        print(f"    expected {STATUS_WORD[expect]}, got {STATUS_WORD.get(got, got)}  ({elapsed:.1f}s)")
        if ok and note:
            print(f"    NOTE: {note}")
        if not ok:
            any_fail_first_broken = any_fail_first_broken or ("fail-first" in name)
            print("    ---- full output ----")
            print("    " + out.replace("\n", "\n    "))

    print("\n" + "=" * 78)
    n_ok = sum(1 for *rest, in results if rest[0])
    print(f"{n_ok}/{len(results)} checks matched their expected result.")
    if any_fail_first_broken:
        print("\nAt least one fail-first (--bug) check did NOT produce a counterexample.")
        print("That means a checker in this directory cannot currently prove anything --")
        print("do not trust any 'equivalent' verdict above until this is fixed.")
        return 1
    if n_ok < len(results):
        print("\nSome checks did not match expectations -- see the full output above")
        print("before trusting the summary.")
        return 1
    print("\nAll fail-first checks caught their reintroduced bug, and every")
    print("equivalence check that was expected to hold, held, within the domain")
    print("printed for that check. See README.md for exactly what that does and")
    print("does not prove.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
