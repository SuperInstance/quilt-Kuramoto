# Bounded SMT equivalence checking: tractable, and it found a real bug

Commissioned after `06-CONFORMANCE-SOTA.md` identified bounded equivalence
checking as the frontier beyond differential testing, citing a 2025 precedent
that did exactly this between a Rust libm port and musl C.

**Verdict: tractable at this scale, with a sharp caveat.** The prototype lives at
`build/smt-equivalence/` and runs in about 30 seconds.

## It found a defect that a million random cases could not

`eb_div_nearest`'s `(2*n + d) / (2*d)` overflows past `i64::MAX/2` — undefined
behaviour in C, and `gcc -O2` returned the **wrong sign** where Rust (widening to
`i128`) was correct. Confirmed against real compiled binaries and named by UBSan
before being believed.

The conformance streams draw bounded inputs, so they exercise that function only
where both ports agree. **After the fix every committed checksum is unchanged** —
which is precisely the evidence that sampling could never have reached it.

This is the first defect in the repository found by verification rather than by
testing, and it is a small, real, undramatic one: unreachable from current
callers, but undefined behaviour in a public function, in a repository whose
entire premise is exactness.

## The asymmetry is the finding

| | |
|---|---|
| find a counterexample (SAT) | **4.4s** |
| prove none exists (UNSAT), full domain | timeout at 60s |
| prove none exists, bounded to 2^31 | **still unknown after 153s** |

Division is hard for bitvector solvers. Meanwhile `phase_offset` — comparisons
and one modulo — proves equivalent over its **entire** domain (all `u32` moduli,
all `i64` inputs) in 0.2 seconds.

So this technique is not one thing. For simple integer functions it is a genuine
proof. For anything with division it is an excellent bug-finder that will not
close. Positioning it as "we prove our code correct" would be false; positioning
it as "another test" would undersell the four functions where it genuinely
quantifies over all inputs.

## Recommended scope

1. **Adopt for the comparison-and-modulo functions.** `phase_offset` proving out
   over its full domain in 0.2s is a real, cheap, permanent result. Add it to CI.
2. **Keep division under the bug-finder framing.** Run it unconstrained
   periodically; treat SAT as a lead, never treat timeout as reassurance.
3. **Do not attempt full-width `isqrt`.** It does not finish; the `u16` proxy is
   honest evidence and should stay labelled as a proxy.
4. **The next real step up is not a bigger solver.** It is narrowing the
   model-versus-binary gap — the checkers compare *models* of C and Rust, and the
   bug found was UB, exactly where a bitvector model and a real compiler are
   least alike. Every result here was confirmed against real binaries for that
   reason, and that discipline is what makes it trustworthy, not the solver.

## Provenance

Built by a background agent that hit a rate limit before writing this up. The
harness, the four checkers and the nine expectations are its work; the `d > 0`
contract constraint, the model update to the fixed C, the corrected timeout
expectation, the README, and the independent confirmation against real compilers
are the dispatching session's. `HARNESS-NOTE.md` — a false positive the agent
caught and recorded before it could be believed — is its work and the reason its
other results are credible.
