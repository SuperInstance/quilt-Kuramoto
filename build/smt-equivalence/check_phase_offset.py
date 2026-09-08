#!/usr/bin/env python3
"""
Bounded SMT equivalence check: eb_phase_offset (C) vs Phase::offset_to (Rust).

This is the function the spec names as having a REAL historical bug: an
earlier version left the raw difference unnormalised and folded it with two
truncating comparisons against n/2, which on an odd ring "undid itself" and
returned the long way around the circle. See circular.rs lines 81-96 for the
worked N=7 example this script reproduces as its fail-first case.

SOURCE MODELLED
----------------
C   (exact_band.c:340-351, 367-387):

    uint32_t eb_phase_new(uint32_t n, int64_t slot) {
        if (n == 0) return 0;
        int64_t r = slot % (int64_t)n;
        if (r < 0) r += (int64_t)n;
        return (uint32_t)r;
    }
    int64_t eb_phase_offset(uint32_t n, int64_t a, int64_t b) {
        if (n == 0) return 0;
        int64_t nn = (int64_t)n;
        int64_t d = (int64_t)eb_phase_new(n, b) - (int64_t)eb_phase_new(n, a);
        if (d < 0) d += nn;
        if (2 * d > nn) d -= nn;
        return d;
    }

Rust (circular.rs:36-41, 98-105), composed as Phase::new(a).offset_to(Phase::new(b)):

    pub const fn new(slot: i64) -> Self {
        let n = N as i64;
        let mut r = slot % n;
        if r < 0 { r += n; }
        Self { slot: r as u32 }
    }
    pub const fn offset_to(self, other: Self) -> i64 {
        let n = N as i64;
        let mut d = other.slot as i64 - self.slot as i64;
        if d < 0 { d += n; }
        if 2 * d > n { d -= n; }
        d
    }

These are structurally the same algorithm and are EXPECTED to agree. The
interesting edge is N == 0: C's eb_phase_offset checks for it and returns 0;
Rust's Phase<0> panics inside `new` on the `% 0`. That is a divergence in
*failure mode* (silent zero vs. a panic/trap), not a divergence in returned
value, and bitvector equality can't represent "traps" as a return value, so
it is checked and reported separately, not folded into the main verdict.

THE HISTORICAL BUG (--bug), reproduced verbatim from circular.rs's own
worked example: applying the two-branch, unnormalised-d comparison
    if d >  n/2 { d -= n }
    if d <= -n/2 { d += n }
directly to d = other.slot - self.slot (which is already in (-N, N) but NOT
yet folded into [0, N)) instead of first doing `if d < 0 { d += n }`. The
doc comment's own example is N=7, d=4, giving the wrong answer +4 (long way
round) instead of the correct -3 (short way round). This script's --bug
flag asks the solver to find that divergence itself, rather than replaying
the hand-picked example -- if it can't, the checker is worthless per this
repo's whole discipline.
"""
import argparse
import z3
from common import solve, report


def eb_phase_new(n32, slot64):
    """C: uint32_t eb_phase_new(uint32_t n, int64_t slot), modelled with n
    widened to i64 to match the source's own (int64_t)n cast, and slot as
    native i64. Result kept as i64 (caller narrows to u32 only at the end,
    same as the source does)."""
    n = z3.SignExt(32, n32)   # n32 is unsigned but always small enough that
                               # sign vs zero extend doesn't matter here since
                               # top bit of a uint32_t used as n is never set
                               # in-bounds; use ZeroExt for correctness anyway
    n = z3.ZeroExt(32, n32)
    r = z3.SRem(slot64, n)     # C99 %: truncates toward zero, same sign as dividend
    r = z3.If(r < 0, r + n, r)
    return r


def rust_phase_new(n32, slot64):
    """Rust: Phase::<N>::new(slot: i64), N as i64. Bit-for-bit the same
    reduction as eb_phase_new; kept as a separate function so a future
    divergence between the two sources shows up even if someone edits only
    one of the two files this script's docstring was written against."""
    n = z3.ZeroExt(32, n32)
    r = z3.SRem(slot64, n)
    r = z3.If(r < 0, r + n, r)
    return r


def eb_phase_offset(n32, a64, b64):
    """C: int64_t eb_phase_offset(uint32_t n, int64_t a, int64_t b).
    n == 0 short-circuit modelled with z3.If; the caller adds n != 0 as a
    solver constraint for the main proof and checks n == 0 separately."""
    nn = z3.ZeroExt(32, n32)
    sa = eb_phase_new(n32, a64)
    sb = eb_phase_new(n32, b64)
    d = sb - sa
    d = z3.If(d < 0, d + nn, d)
    d = z3.If(2 * d > nn, d - nn, d)
    return z3.If(n32 == 0, z3.BitVecVal(0, 64), d)


def rust_offset_to(n32, a64, b64, bug=False):
    """Rust: Phase::<N>::new(a).offset_to(Phase::<N>::new(b)).
    N == 0 is not modelled as "return 0" here -- it's not what the real code
    does (it panics in `new`'s `% 0`); the caller must exclude n32 == 0 from
    this model's domain and check that edge separately.

    --bug reproduces circular.rs's own documented "earlier version": the
    two-branch comparison against unnormalised d, taken verbatim from the
    doc comment rather than paraphrased.
    """
    nn = z3.ZeroExt(32, n32)
    sa = rust_phase_new(n32, a64)
    sb = rust_phase_new(n32, b64)
    d = sb - sa   # already in (-N, N) since sa, sb in [0, N)
    if bug:
        # if d >  n/2  { d -= n }
        # if d <= -n/2 { d += n }
        half = nn / 2  # bvsdiv truncates toward zero, matching Rust/C integer /
        d = z3.If(d > half, d - nn, d)
        d = z3.If(d <= -half, d + nn, d)
        return d
    d = z3.If(d < 0, d + nn, d)
    d = z3.If(2 * d > nn, d - nn, d)
    return d


def build_solver(bug, n_bits, val_bits):
    """n_bits/val_bits bound the SEARCH DOMAIN (n in [1, 2^n_bits - 1], a,b in
    [-2^val_bits, 2^val_bits - 1]) by constraining otherwise-full-width BV32/
    BV64 symbols -- the arithmetic itself always runs at the real 32/64-bit
    width the source uses, only the search range is narrowed for tractability."""
    n32 = z3.BitVec("n", 32)
    a64 = z3.BitVec("a", 64)
    b64 = z3.BitVec("b", 64)

    s = z3.Solver()
    s.add(n32 != 0)  # n == 0 is checked separately (panic vs. silent 0, not a value divergence)
    # CAUTION (found by this script's own self-check, kept as a comment on
    # purpose): BitVecVal(1 << n_bits, 32) WRAPS TO 0 when n_bits >= 32,
    # which would turn "n < 2^32" into "n < 0" -- vacuously false, making
    # every "equivalent" verdict below meaningless (UNSAT for the wrong
    # reason: no n satisfies the domain at all, not because none diverges).
    # So n_bits >= 32 means "full unconstrained u32 range", no ULT needed.
    if n_bits < 32:
        s.add(z3.ULT(n32, z3.BitVecVal(1 << n_bits, 32)))
    lo = -(1 << val_bits)
    hi = (1 << val_bits) - 1
    if val_bits < 63:
        s.add(a64 >= lo, a64 <= hi)
        s.add(b64 >= lo, b64 <= hi)
    # val_bits >= 63 means full i64 range -- BV64_MIN/MAX bounds are already
    # every representable value, so no constraint is added (and none needed).

    c_result = eb_phase_offset(n32, a64, b64)
    rust_result = rust_offset_to(n32, a64, b64, bug=bug)
    s.add(c_result != rust_result)
    return s, (n32, a64, b64)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bug", action="store_true",
                     help="inject the historical two-branch-unnormalised-d bug into the Rust model and confirm a counterexample is found")
    ap.add_argument("--n-bits", type=int, default=16, help="search n in [1, 2^n_bits - 1] (default 16 -> n < 65536)")
    ap.add_argument("--val-bits", type=int, default=20, help="search a,b in [-2^val_bits, 2^val_bits-1] (default 20)")
    ap.add_argument("--timeout-ms", type=int, default=60000)
    args = ap.parse_args()

    label = "eb_phase_offset vs Phase::offset_to" + (" [BUG INJECTED]" if args.bug else "")
    s, (n32, a64, b64) = build_solver(args.bug, args.n_bits, args.val_bits)
    status, elapsed, model = solve(s, timeout_ms=args.timeout_ms, label=label)

    def interpret(m):
        n_v = m[n32].as_signed_long() if m[n32].as_signed_long() >= 0 else m[n32].as_long()
        n_v = m[n32].as_long()
        a_v = m[a64].as_signed_long()
        b_v = m[b64].as_signed_long()
        c_val = eb_phase_offset(z3.BitVecVal(n_v, 32), z3.BitVecVal(a_v, 64), z3.BitVecVal(b_v, 64))
        rust_val = rust_offset_to(z3.BitVecVal(n_v, 32), z3.BitVecVal(a_v, 64), z3.BitVecVal(b_v, 64), bug=args.bug)
        c_val = z3.simplify(c_val).as_signed_long()
        rust_val = z3.simplify(rust_val).as_signed_long()
        print(f"    n = {n_v}, a = {a_v}, b = {b_v}")
        print(f"    C   eb_phase_offset(n, a, b)          = {c_val}")
        print(f"    Rust Phase::new(a).offset_to(new(b))  = {rust_val}"
              + (" [buggy model]" if args.bug else ""))

    bound_desc = f"n in [1, 2^{args.n_bits}-1], a,b in [-2^{args.val_bits}, 2^{args.val_bits}-1]"
    verdict = report(label, status, elapsed, model, interpret, bound_desc)

    if args.bug:
        if verdict == "sat":
            print("\n  FAIL-FIRST CHECK PASSED: the checker catches the reintroduced")
            print("  historical bug. A checker that has never failed proves nothing --")
            print("  this one just did.")
            return 0
        else:
            print("\n  FAIL-FIRST CHECK FAILED: the bug was reintroduced but the solver")
            print("  did NOT find a counterexample in this domain. The checker or the")
            print("  bug model is broken -- do not trust the non-bug verdict until this")
            print("  is fixed.")
            return 1
    else:
        c0 = z3.simplify(eb_phase_offset(z3.BitVecVal(0, 32), z3.BitVecVal(5, 64), z3.BitVecVal(9, 64)))
        print(f"\n  NOTE (not solver-checked -- a panic has no bitvector value to compare):")
        print(f"    n == 0 is a real divergence in FAILURE MODE, not return value:")
        print(f"    C:    eb_phase_offset(0, a, b) returns {c0} for every a, b (checked in source).")
        print(f"    Rust: Phase::<0>::new(a) panics on `slot % 0` before offset_to ever runs.")
        print(f"    Excluded from the domain above (n != 0 is a solver constraint); see README.")
        return 0 if status == "unsat" else (1 if status == "sat" else 3)


if __name__ == "__main__":
    raise SystemExit(main())
