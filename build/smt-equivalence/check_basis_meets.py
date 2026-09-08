#!/usr/bin/env python3
"""
Full-domain SMT equivalence check: eb_basis_meets (C) vs covering::basis_meets (Rust).

Does basis b on a dim-dimensional lattice meet tolerance eps? Exactly
`dim * b^2 <= 4 * eps^2`. No loop, no rounding, no sign -- just multiplication
and comparison of unsigned values -- which makes this the CHEAPEST of the
four target functions for a bitvector solver: bitvector multiplication by
itself is the hard case for SMT (see README, "where this stops scaling"),
but here the operands are fixed-width u32 inputs widened into a fixed-width
accumulator, so it is a single decidable bit-blasting problem, not an
open-ended nonlinear search.

SOURCE MODELLED
----------------
C   (exact_band.c:48-63), everything computed in uint64_t:

    int eb_basis_meets(uint32_t dim, uint32_t basis, uint32_t eps) {
        if (dim == 0 || dim > 3) return 0;
        if (basis > EB_SCALE_MAX || eps > EB_SCALE_MAX) return 0;
        uint64_t b = basis, e = eps;
        return (uint64_t)dim * b * b <= 4u * e * e;
    }

Rust (covering.rs:20-36), everything computed in u128, NO guard on dim or on
EB_SCALE_MAX -- it is a general n-dimensional formula, not restricted to the
1/2/3-D lattices this crate actually uses:

    pub const fn covering_radius_sq_x4(basis: u32, dim: u32) -> u128 {
        (dim as u128) * (basis as u128) * (basis as u128)
    }
    pub const fn basis_meets(dim: u32, basis: u32, eps: u32) -> bool {
        let e = eps as u128;
        covering_radius_sq_x4(basis, dim) <= 4 * e * e
    }

THE INTERESTING PART: these are NOT total-domain-equivalent as written --
the C port's early-return guards (dim==0, dim>3, basis/eps>EB_SCALE_MAX)
have no counterpart in the Rust formula, which just evaluates the (always
well-defined, u128-safe) inequality for any u32 inputs. This script checks
BOTH domains: first the full unrestricted u32 domain (expected SAT: the
guards are real differences), then the documented shared domain --
dim in {1,2,3}, basis/eps <= EB_SCALE_MAX -- the only domain the two
functions are actually meant to agree on (expected UNSAT).

No historical bug is named for this function in the brief, so --bug injects
a plausible off-by-one: comparing `<` instead of `<=` (a boundary case any
port could get wrong when squaring "meets or exceeds" language), to make
sure the checker can still fail when asked to.
"""
import argparse
import z3
from common import solve, report

SCALE_MAX = (1 << 31) - 1  # EB_SCALE_MAX = 2^31 - 1


def c_basis_meets(dim32, basis32, eps32, bug=False):
    """int eb_basis_meets(uint32_t dim, uint32_t basis, uint32_t eps),
    modelled at native uint64_t width (the header states this fits: dim<=3,
    operands <=2^31-1, so 4*eps^2 <= 4*(2^31-1)^2 < 2^64)."""
    guard_ok = z3.And(dim32 != 0, z3.ULE(dim32, 3),
                       z3.ULE(basis32, SCALE_MAX), z3.ULE(eps32, SCALE_MAX))
    dim = z3.ZeroExt(32, dim32)
    b = z3.ZeroExt(32, basis32)
    e = z3.ZeroExt(32, eps32)
    lhs = dim * b * b
    rhs = 4 * e * e
    cmp = z3.ULT(lhs, rhs) if bug else z3.ULE(lhs, rhs)
    return z3.If(guard_ok, cmp, z3.BoolVal(False))


def rust_basis_meets(dim32, basis32, eps32):
    """pub const fn basis_meets(dim, basis, eps) -> bool, modelled at native
    u128 width (the doc comment's own claim: no overflow for any u32 input,
    since 3 * (2^32-1)^2 << 2^128, so a full u128 width is exact, not a
    'bounded' approximation of this one function's own arithmetic)."""
    dim = z3.ZeroExt(96, dim32)
    b = z3.ZeroExt(96, basis32)
    e = z3.ZeroExt(96, eps32)
    lhs = dim * b * b
    rhs = 4 * e * e
    return z3.ULE(lhs, rhs)


def build_solver(bug, shared_domain_only, timeout_ms):
    dim32 = z3.BitVec("dim", 32)
    basis32 = z3.BitVec("basis", 32)
    eps32 = z3.BitVec("eps", 32)
    s = z3.Solver()
    if shared_domain_only:
        s.add(dim32 != 0, z3.ULE(dim32, 3))
        s.add(z3.ULE(basis32, SCALE_MAX), z3.ULE(eps32, SCALE_MAX))
    c_res = c_basis_meets(dim32, basis32, eps32, bug=bug)
    rust_res = rust_basis_meets(dim32, basis32, eps32)
    s.add(c_res != rust_res)
    return s, (dim32, basis32, eps32)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bug", action="store_true", help="inject a strict-inequality off-by-one into the C model")
    ap.add_argument("--full-u32-domain", action="store_true",
                     help="check the FULL unrestricted u32 domain instead of the documented shared domain (expected to find the guard-clause divergence)")
    ap.add_argument("--timeout-ms", type=int, default=60000)
    args = ap.parse_args()

    shared_only = not args.full_u32_domain
    label = "eb_basis_meets vs basis_meets" + (" [BUG INJECTED]" if args.bug else "") \
            + (" (shared domain)" if shared_only else " (full u32 domain)")
    s, (dim32, basis32, eps32) = build_solver(args.bug, shared_only, args.timeout_ms)
    status, elapsed, model = solve(s, timeout_ms=args.timeout_ms, label=label)

    def interpret(m):
        dv, bv, ev = m[dim32].as_long(), m[basis32].as_long(), m[eps32].as_long()
        c_val = z3.simplify(c_basis_meets(z3.BitVecVal(dv, 32), z3.BitVecVal(bv, 32), z3.BitVecVal(ev, 32), bug=args.bug))
        r_val = z3.simplify(rust_basis_meets(z3.BitVecVal(dv, 32), z3.BitVecVal(bv, 32), z3.BitVecVal(ev, 32)))
        print(f"    dim = {dv}, basis = {bv}, eps = {ev}")
        print(f"    C   eb_basis_meets  = {c_val}")
        print(f"    Rust basis_meets    = {r_val}")

    bound_desc = ("dim in {1,2,3}, basis,eps in [0, EB_SCALE_MAX] -- the documented shared domain"
                  if shared_only else "the full unrestricted u32 x u32 x u32 domain (no guard clauses assumed)")
    verdict = report(label, status, elapsed, model, interpret, bound_desc)

    if args.bug:
        if verdict == "sat":
            print("\n  FAIL-FIRST CHECK PASSED.")
            return 0
        print("\n  FAIL-FIRST CHECK FAILED: bug reintroduced but no counterexample found.")
        return 1
    if not shared_only:
        if verdict == "sat":
            print("\n  EXPECTED: the two functions have different domains-of-agreement by")
            print("  design (C rejects dim==0/dim>3/out-of-range basis or eps outright;")
            print("  Rust's formula is unguarded and just evaluates). Re-run without")
            print("  --full-u32-domain to check the domain they ARE meant to agree on.")
            return 0
        else:
            print("\n  UNEXPECTED: no divergence found even over the full u32 domain --")
            print("  the guard clauses turned out not to matter. Worth double-checking")
            print("  the guard-clause transcription above.")
            return 2
    return 0 if status == "unsat" else (1 if status == "sat" else 3)


if __name__ == "__main__":
    raise SystemExit(main())
