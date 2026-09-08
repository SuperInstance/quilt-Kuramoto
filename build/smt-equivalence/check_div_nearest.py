#!/usr/bin/env python3
"""
Bounded/full-domain SMT equivalence check: eb_div_nearest (C) vs div_nearest (Rust).

Round-half-away-from-zero integer division: the spec calls this out because
a floor (round-toward-negative-infinity) implementation biases one direction
over many steps -- a bug this repo already fixed once in phase_lock's centre
pull.

SOURCE MODELLED
----------------
C   (exact_band.c:394-398), native int64_t, no wider type available in C99:

    int64_t eb_div_nearest(int64_t n, int64_t d) {
        if (n >= 0) { return (2 * n + d) / (2 * d); }
        return -((-2 * n + d) / (2 * d));
    }

Rust (zono.rs:443-457), widens to i128 before the arithmetic, then clamps:

    fn clamp_i64(v: i128) -> i64 {
        if v > i64::MAX as i128 { i64::MAX }
        else if v < i64::MIN as i128 { i64::MIN }
        else { v as i64 }
    }
    fn div_nearest(n: i64, d: i64) -> i64 {
        let (n128, d128) = (n as i128, d as i128);
        let q = if n128 >= 0 { (2 * n128 + d128) / (2 * d128) }
                else { -((-2 * n128 + d128) / (2 * d128)) };
        clamp_i64(q)
    }

THE INTERESTING PART, found by building this rather than by reading the
diff: the two functions are only equivalent because `n` and `d` are both
already-i64-range values. C computes `2 * n` in native int64_t -- for n
near i64::MAX/MIN that arithmetic OVERFLOWS 64-bit two's complement.
Signed overflow is UB in the C standard, but every mainstream compiler at
-O0/-O1/-O2 without UB-exploiting reassociation gives you wraparound in
practice (the common "-fwrapv semantics" outcome), so this script models
WRAPPING 64-bit arithmetic for the C side, not "anything can happen" --
and says so loudly here and in the README. Rust's i128 intermediate never
overflows for i64-range inputs (2*n128 needs at most 65 bits), so it never
wraps. That is a genuine, structural difference in HOW the two are safe,
not just an implementation accident, and it is exactly the kind of thing
bounded SMT equivalence checking is supposed to surface: the search below
covers the full i64 domain, including the boundary where this would bite.

THE HISTORICAL-SHAPED BUG (--bug): the spec asks for "a floor division"
substituted for round-to-nearest. C's plain `/` truncates toward zero, not
floors -- so the literal bug this script injects is the naive, no-rounding
implementation `return n / d;`, which a first-draft port might reach for
without thinking about the half-way case at all. It diverges from
round-half-away-from-zero immediately (e.g. n=3, d=2: correct rounds to 2,
truncating division gives 1), so the solver should find a counterexample on
essentially the first constraint pass.
"""
import argparse
import z3
from common import solve, report


def c_div_nearest(n, d):
    """int64_t eb_div_nearest(int64_t n, int64_t d), native BV64 (wrapping)
    arithmetic, matching the -fwrapv-style compiled behaviour named above."""
    two_n = n * 2
    two_d = d * 2
    q_pos = (two_n + d) / two_d   # bvsdiv: truncates toward zero, like C's /
    q_neg = (-two_n + d) / two_d
    return z3.If(n >= 0, q_pos, -q_neg)


def c_div_nearest_buggy(n, d):
    """The naive port: plain truncating division, no rounding at all."""
    return n / d


def rust_div_nearest(n64, d64):
    """fn div_nearest(n: i64, d: i64) -> i64, modelled in BV128 (i128),
    then clamp_i64'd back into i64 range before returning."""
    n = z3.SignExt(64, n64)
    d = z3.SignExt(64, d64)
    two_n = n * 2
    two_d = d * 2
    q_pos = (two_n + d) / two_d
    q_neg = (-two_n + d) / two_d
    q = z3.If(n >= 0, q_pos, -q_neg)
    i64_max = z3.BitVecVal((1 << 63) - 1, 128)
    i64_min = z3.BitVecVal(-(1 << 63), 128)
    clamped = z3.If(q > i64_max, i64_max, z3.If(q < i64_min, i64_min, q))
    return z3.Extract(63, 0, clamped)


def build_solver(bug, val_bits, timeout_ms):
    n64 = z3.BitVec("n", 64)
    d64 = z3.BitVec("d", 64)
    s = z3.Solver()
    s.add(d64 != 0)  # division by zero excluded -- both languages trap/UB on it, not a value comparison
    if val_bits < 63:
        lo, hi = -(1 << val_bits), (1 << val_bits) - 1
        s.add(n64 >= lo, n64 <= hi)
        s.add(d64 >= lo, d64 <= hi)
    c_fn = c_div_nearest_buggy if bug else c_div_nearest
    s.add(c_fn(n64, d64) != rust_div_nearest(n64, d64))
    return s, (n64, d64)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bug", action="store_true", help="inject the naive truncating-division bug into the C model")
    ap.add_argument("--val-bits", type=int, default=63, help="search n,d in [-2^val_bits, 2^val_bits-1]; 63 = full i64 domain (default)")
    ap.add_argument("--timeout-ms", type=int, default=60000)
    args = ap.parse_args()

    label = "eb_div_nearest vs div_nearest" + (" [BUG INJECTED]" if args.bug else "")
    s, (n64, d64) = build_solver(args.bug, args.val_bits, args.timeout_ms)
    status, elapsed, model = solve(s, timeout_ms=args.timeout_ms, label=label)

    def interpret(m):
        n_v = m[n64].as_signed_long()
        d_v = m[d64].as_signed_long()
        c_fn = c_div_nearest_buggy if args.bug else c_div_nearest
        c_val = z3.simplify(c_fn(z3.BitVecVal(n_v, 64), z3.BitVecVal(d_v, 64))).as_signed_long()
        rust_val = z3.simplify(rust_div_nearest(z3.BitVecVal(n_v, 64), z3.BitVecVal(d_v, 64))).as_signed_long()
        print(f"    n = {n_v}, d = {d_v}")
        print(f"    C   eb_div_nearest(n, d){'  [buggy: plain n/d]' if args.bug else ''} = {c_val}")
        print(f"    Rust div_nearest(n, d)                    = {rust_val}")

    bound_desc = ("n,d in the full i64 domain [-2^63, 2^63-1]" if args.val_bits >= 63
                  else f"n,d in [-2^{args.val_bits}, 2^{args.val_bits}-1]")
    verdict = report(label, status, elapsed, model, interpret, bound_desc)

    if args.bug:
        if verdict == "sat":
            print("\n  FAIL-FIRST CHECK PASSED: the checker catches the reintroduced bug.")
            return 0
        else:
            print("\n  FAIL-FIRST CHECK FAILED: bug reintroduced but no counterexample found.")
            return 1
    return 0 if status == "unsat" else (1 if status == "sat" else 3)


if __name__ == "__main__":
    raise SystemExit(main())
