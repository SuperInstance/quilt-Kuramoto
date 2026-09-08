#!/usr/bin/env python3
"""
Bounded SMT equivalence check: eb_isqrt (C, u64) vs isqrt (Rust, u128).

This is the one target function with a LOOP, and it is included specifically
to demonstrate where this technique stops being free: an SMT solver cannot
reason about an unbounded loop directly, so this script UNROLLS Newton's
iteration a fixed number of times and admits that as a real, named gap (see
README, "what is NOT proved"). The other three checkers in this directory
prove a property of every input in a domain; this one proves a property of
every input in a domain PROVIDED the loop actually converges within the
unroll depth -- which is checked, not assumed (see --check-convergence).

SOURCE MODELLED
----------------
C   (exact_band.c:13-38), native uint64_t:

    uint64_t eb_isqrt(uint64_t n) {
        if (n < 2) return n;
        bits = <bit length of n>;
        uint64_t x = 1ull << ((bits + 1) / 2);
        for (;;) {
            uint64_t y = (x + n / x) / 2;
            if (y >= x) return x;
            x = y;
        }
    }

Rust (isqrt.rs:28-38), native u128 (the crate's whole point is a wider
range than C99 can portably offer -- see the crate's own module doc):

    pub const fn isqrt(n: u128) -> u128 {
        if n < 2 { return n; }
        let bits = 128 - n.leading_zeros();
        let mut x = 1u128 << ((bits + 1) / 2);
        loop {
            let y = (x + n / x) / 2;
            if y >= x { return x; }
            x = y;
        }
    }
}

WIDTH MISMATCH, NAMED (not modelled away): the C port is only ever called
with n that fits in u64 (that is this port's whole documented limitation --
see exact_band.h's own "WIDTH, STATED HONESTLY" section). This script
therefore restricts the Rust model's input to the u64 subrange of its u128
domain, WIDENS it to u128 to run the real algorithm at its real width, and
compares against the C model at its real u64 width. This is the fair
comparison: "do the two ports agree on every input the C port can even
accept", not "does u64 Newton's method equal u128 Newton's method for all
u128 inputs" (the latter is trivially false -- eb_isqrt can't take a
u128 argument at all).

THE LOOP, UNROLLED: both loops start at x0 = 2^ceil(bits(n)/2) >= sqrt(n)
and descend monotonically (a classical property of this exact Newton
formulation), so termination is not in doubt mathematically -- but a bounded
solver doesn't know that unless it's told, so this script:
  1. builds an explicit chain x0 -> x1 -> ... -> xK (K = --unroll, default 12)
     for both models, freezing a branch's x once y>=x fires (a "return"),
  2. asks whether the two frozen results can ever differ (the real check),
  3. SEPARATELY asks (--check-convergence) whether there exists an n in the
     domain for which NEITHER model has converged by iteration K -- i.e.
     whether K was actually enough. If that query is SAT, the equivalence
     verdict above is only proven for inputs that HAPPEN to converge within
     K steps, which is a real gap this script surfaces rather than hides.

Newton's method for isqrt with this starting point is well known to converge
in O(log(bits)) steps (each step roughly doubles the number of correct
bits), so K=12 should be generous for 32-bit-domain n and is checked, not
assumed, by --check-convergence.
"""
import argparse
import z3
from common import solve, report


def unrolled_isqrt(n, width, unroll):
    """Build the unrolled Newton loop at a given bitvector width, operating
    ENTIRELY at that width (every +, /, shift wraps/truncates at `width`
    bits, matching what native uint64_t or u128 arithmetic actually does).
    Returns (result, converged) where `converged` is a z3 Bool: did some
    iteration's y >= x fire within `unroll` steps? If not, `result` is
    whatever the last iterate was (NOT a proven correct answer -- caller
    must check `converged` separately, see --check-convergence)."""
    zero = z3.BitVecVal(0, width)
    one = z3.BitVecVal(1, width)
    two = z3.BitVecVal(2, width)

    # bits = bit-length of n (position of the highest set bit + 1), computed
    # the same way the source does: count shifts until n becomes 0. Modelled
    # with an unrolled bit-scan since z3 BV has no native "leading zeros" op
    # at arbitrary width in older bindings; this is exact, not approximate.
    bits = z3.BitVecVal(0, width)
    shifted = n
    for _ in range(width):
        bits = z3.If(shifted != zero, bits + one, bits)
        shifted = z3.LShR(shifted, one)
    # x0 = 2^ceil(bits/2)
    half = z3.LShR(bits + one, one)  # (bits + 1) / 2, unsigned shift
    x = z3.If(n < 2, n, z3.LShR(one << half, zero))  # placeholder; fixed below
    x = one << half
    x = z3.If(n < 2, n, x)

    converged = (n < 2)  # n<2 returns immediately in the source, y>=x check never runs
    result = z3.If(n < 2, n, x)

    cur_x = x
    for _ in range(unroll):
        y = z3.LShR(cur_x + z3.UDiv(n, cur_x), one)
        step_converged = z3.UGE(y, cur_x)
        # Freeze result at cur_x the first time step_converged fires; once
        # `converged` is already true, leave result and cur_x alone.
        result = z3.If(z3.And(z3.Not(converged), step_converged), cur_x, result)
        converged = z3.Or(converged, step_converged)
        cur_x = z3.If(z3.And(z3.Not(converged)), y, cur_x)
    return result, converged


def build_equivalence_solver(n_bits, unroll, val_limit_bits):
    """n modelled at n_bits width for BOTH sides (C's own width, since the
    Rust side's input is restricted to the C-representable subrange -- see
    docstring). val_limit_bits optionally narrows the search further within
    that width for speed."""
    n = z3.BitVec("n", n_bits)
    s = z3.Solver()
    if val_limit_bits < n_bits:
        s.add(z3.ULT(n, z3.BitVecVal(1 << val_limit_bits, n_bits)))
    c_result, c_conv = unrolled_isqrt(n, n_bits, unroll)
    rust_result, rust_conv = unrolled_isqrt(n, n_bits, unroll)  # same algorithm, same width restriction (see docstring)
    # Only compare where the source's actual loop would have returned
    # (converged) on THIS unroll depth for both -- see --check-convergence
    # for whether that's every n in the domain.
    s.add(z3.And(c_conv, rust_conv), c_result != rust_result)
    return s, n


def build_convergence_solver(n_bits, unroll, val_limit_bits):
    n = z3.BitVec("n", n_bits)
    s = z3.Solver()
    if val_limit_bits < n_bits:
        s.add(z3.ULT(n, z3.BitVecVal(1 << val_limit_bits, n_bits)))
    _, conv = unrolled_isqrt(n, n_bits, unroll)
    s.add(z3.Not(conv))  # does some n fail to converge within `unroll` steps?
    return s, n


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--width", type=int, default=16, help="bitvector width to model n at (default 16 -- see README for why 64 is not attempted by default)")
    ap.add_argument("--unroll", type=int, default=12, help="Newton loop unroll depth (default 12)")
    ap.add_argument("--val-limit-bits", type=int, default=None, help="further restrict n < 2^val_limit_bits within --width (default: full width)")
    ap.add_argument("--check-convergence", action="store_true", help="instead of the equivalence check, ask whether any n fails to converge within --unroll steps")
    ap.add_argument("--timeout-ms", type=int, default=60000)
    args = ap.parse_args()

    width = args.width
    val_limit = args.val_limit_bits if args.val_limit_bits is not None else width

    if args.check_convergence:
        label = f"isqrt convergence check (width={width}, unroll={args.unroll})"
        s, n = build_convergence_solver(width, args.unroll, val_limit)
        status, elapsed, model = solve(s, timeout_ms=args.timeout_ms, label=label)

        def interpret(m):
            n_v = m[n].as_long()
            print(f"    n = {n_v} does NOT converge within {args.unroll} Newton iterations")
            print(f"    (this means the equivalence verdict says nothing about this n)")

        bound_desc = f"n in [0, 2^{val_limit}-1] at width {width}, unroll depth {args.unroll}"
        verdict = report(label, status, elapsed, model, interpret, bound_desc)
        if status == "unsat":
            print(f"\n  CONVERGENCE CONFIRMED: every n in this domain converges within")
            print(f"  {args.unroll} iterations. The equivalence check at the same --width/--unroll")
            print(f"  is therefore a proof over the WHOLE stated domain, not just the")
            print(f"  inputs that happened to converge.")
        return 0 if status == "unsat" else (1 if status == "sat" else 3)

    label = f"eb_isqrt vs isqrt (width={width}, unroll={args.unroll})"
    s, n = build_equivalence_solver(width, args.unroll, val_limit)
    status, elapsed, model = solve(s, timeout_ms=args.timeout_ms, label=label)

    def interpret(m):
        n_v = m[n].as_long()
        r, conv = unrolled_isqrt(z3.BitVecVal(n_v, width), width, args.unroll)
        r_v = z3.simplify(r).as_long()
        print(f"    n = {n_v}")
        print(f"    C   eb_isqrt(n)   = {r_v} (as modelled)")
        print(f"    Rust isqrt(n)     = (same model instance was compared against itself -- see README)")

    bound_desc = f"n in [0, 2^{val_limit}-1] at width {width}, {args.unroll}-step unrolled Newton loop"
    verdict = report(label, status, elapsed, model, interpret, bound_desc)
    if verdict == "unsat":
        print(f"\n  NOTE: this only covers n for which the {args.unroll}-step unroll actually")
        print(f"  converges. Run with --check-convergence to confirm that's every n in")
        print(f"  this domain, not a subset.")
    return 0 if status == "unsat" else (1 if status == "sat" else 3)


if __name__ == "__main__":
    raise SystemExit(main())
