"""
Shared helpers for the bounded SMT equivalence checks in this directory.

Every model in this package is a hand-transcribed z3py encoding of a C
function's or a Rust function's *semantics*, built by reading the source in
build/exact-band-c/src/exact_band.c and build/exact-band/src/*.rs -- not by
compiling either language. That means every "equivalent" verdict below is
"my model of the C function agrees with my model of the Rust function", not
"the compiled .o and the compiled .rlib agree". See README.md, section
"What is NOT proved", before trusting any verdict past that.
"""
import sys
import time

try:
    import z3
except ImportError:
    print("z3-solver is not installed in this Python environment.")
    print("  pip install z3-solver")
    print("Skipping SMT equivalence checks -- nothing was proved or disproved.")
    sys.exit(2)


def solve(solver, timeout_ms=60000, label=""):
    """Run solver.check(), return (status_str, elapsed_seconds, model_or_none)."""
    solver.set("timeout", timeout_ms)
    t0 = time.time()
    result = solver.check()
    elapsed = time.time() - t0
    if result == z3.sat:
        return "sat", elapsed, solver.model()
    elif result == z3.unsat:
        return "unsat", elapsed, None
    else:
        return "unknown", elapsed, None


def report(name, status, elapsed, model, interpret_sat, bound_desc,
           unsat_msg="EQUIVALENT over the checked domain (UNSAT -- no counterexample exists)",
           sat_msg="DIVERGENCE FOUND (SAT -- counterexample below)"):
    """Print one function's verdict in the fixed, honest format this repo's
    discipline requires: what was checked, over what range, how long it took,
    and (if sat) the actual counterexample values."""
    print(f"\n=== {name} ===")
    print(f"  domain checked : {bound_desc}")
    print(f"  solver time    : {elapsed:.3f}s")
    if status == "unsat":
        print(f"  RESULT: {unsat_msg}")
    elif status == "sat":
        print(f"  RESULT: {sat_msg}")
        interpret_sat(model)
    else:
        print(f"  RESULT: UNKNOWN -- solver timed out or gave up. This is a result,")
        print(f"          not a proof either way. Report the timeout, don't round it")
        print(f"          up to 'probably fine'.")
    return status


BV64_MIN = -(1 << 63)
BV64_MAX = (1 << 63) - 1
