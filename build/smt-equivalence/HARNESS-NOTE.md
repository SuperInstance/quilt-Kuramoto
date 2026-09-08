# A false positive from this harness, recorded before it could be believed

`check_isqrt.py` reported, mid-development:

```
=== eb_isqrt (u16) vs isqrt (u32), unroll=12 ===
  domain checked : n in [0, 2^16-1], C at native u16, Rust at native u32
  RESULT: DIVERGENCE FOUND (SAT -- counterexample below)
    n = 33271
    C   eb_isqrt(n)  [native u16]  = 33271
    Rust isqrt(n)    [native u32]  = 182
```

**There is no bug in the library.** Tested against the real compiled code:

```
real C   eb_isqrt(33271) = 182
exhaustive n in [0,200000): eb_isqrt satisfies r^2 <= n < (r+1)^2 everywhere
```

The divergence is between two *models*, not two implementations. The harness
narrowed the C side to a native `u16` while leaving the Rust side at `u32`.
`eb_isqrt` takes a `uint64_t` and starts Newton's iteration at
`1 << ((bits + 1) / 2)`; at 16 bits that start value and the intermediate
`x + n / x` behave differently, so the model is not the function.

The domain line says so plainly — "C at native u16, Rust at native u32" — which
is an apples-to-oranges comparison, and the harness reported it as a divergence
anyway.

## Why this is worth a file rather than a fix-and-forget

This is the exact failure the brief for this work warned about: an SMT harness
proves that *your model of C* matches *your model of Rust*, and the gap between
model and compiled code is where a false result lives. A harness that reports a
counterexample is persuasive precisely when it is wrong, because the output
looks like a finding.

The rule this directory has to follow, therefore:

1. **Every counterexample gets executed against the real code before it is
   reported.** A SAT result is a hypothesis, not a bug.
2. **Both sides must be modelled at the same width**, and the width must be the
   one the source actually uses.
3. The README must always say which of these two statements it is making:
   "equivalent for all inputs of type T" or "equivalent for inputs under 2^k,
   solved in N seconds". They are very different claims.
