# tower

**Compile a physical-quantity cell spec into exact, float-free C — and refuse
to compile it when the units don't work out.**

```console
$ python -m tower examples/oil-pressure-port.cell.yaml --check
tower: oil-pressure-port
  ok   no floating-point type in generated C
  ok   Python model matches exact rational arithmetic -- 12001 inputs
  ok   generated C compiles with -Wall -Wextra -Werror
  ok   self-test runs
  ok   C rendering matches the model -- 9 rows
  ok   C deadband judge matches the model
  ok   C cell simulation matches the model -- 9 ticks
  PASS

$ python -m tower examples/depth-fathoms.cell.yaml --check
tower: basis not exact: a span of 200 fathoms does not land on the
1/1-fathoms lattice under *625/1143. Choose report units so the calibration
constant comes out whole, rather than approximating.
$ echo $?
2
```

That second case is the point. A generator that quietly rounds is worse than no
generator, because the rounding is invisible for the life of the firmware.

## Where this came from

Lifted out of `quilt-verilog/tools/tower/emith.py`, which had **zero coupling to
Verilog** — it is pure Python emitting C — but was buried in an FPGA repo where
nobody looking for a code generator would find it.

The doctrine is preserved verbatim; the hardcoding is not:

| | Original | tower |
|---|---|---|
| Units | psi only (`^1/(\d+)\s*psi$`) | any unit |
| Range | rejects non-zero minimum | any range, including negative |
| Quantize | `whole_psi` only | any whole unit |
| Equation | one shape | affine, with optional offset and divisor |
| Exactness gate | ✓ | ✓ **kept, unchanged in spirit** |
| Float-free output | ✓ checked, not claimed | ✓ same |
| Squared-form judge | ✓ | ✓ |

**Compatibility is measured, not asserted:** tower reproduces all **17
hand-computed golden anchors** from the original `verify.py` — anchors that were
computed independently of either generator.

## The exactness gate

The basis trick: choose the report unit so the calibration constant comes out
whole. `psi = (mV - 500) * 3/80` is exact on a 1/80-psi basis because 4000 mV of
span times 3/80 is exactly 150 — every 400 mV is exactly 15 psi, with no
rounding anywhere in the chain.

When that doesn't hold, tower refuses:

```python
if (span_out * den) % num != 0:
    raise SpecError("basis not exact: ...")
```

**Direction matters.** Fathoms → metres is a *multiplication* (1 fathom =
1 828 800 µm exactly) and is fine — `quilt-esp32`'s `nmea.c` already relies on
it. Metres → fathoms *divides* by 1.8288, giving `625/1143`, which never
reduces. Same physical relationship, exact one way and not the other. The gate
catches the direction that doesn't work.

## What it generates

One dependency-free C99 translation unit: a moving-median prefilter (odd window,
so the median is a real sample and no averaging division sneaks in), an affine
render rounding half away from zero *symmetrically* so negative ranges behave
like positive ones, a squared-form deadband judge (`d² ≤ D²`, exact integers, no
root), and a snap-debt ledger. Nothing allocates. No floating-point type appears.

## The gate

Three independent things must agree before a cell is accepted:

1. the **generated C**, actually compiled with `-Wall -Wextra -Werror` and executed;
2. an independent **Python model**;
3. exact **rational arithmetic** (`fractions.Fraction`), which has no rounding at
   all and so cannot share a rounding bug with either of the others.

Plus the float-free property, checked by regex rather than claimed in a comment.

**The gate can fail.** `test_the_gate_actually_catches_a_broken_generator`
mutates the emitter to truncate instead of rounding and asserts the gate rejects
it. A gate that only ever passes proves nothing.

## Honest limitations

- **Affine only.** No dyadic staircases for constants that refuse to be whole
  (SEMANTIC-TOWER §5.3's acknowledged fallback for things like `c/2` mm-per-ns).
  Such specs are rejected, not approximated — but rejection is not the same as
  support.
- **Circular quantities are not modelled.** Heading wraps at 360°, and a squared
  difference judges 359° and 1° as 358 apart rather than 2. `quilt-esp32` and
  `cocapn-marine` both handle this by hand today. Out of scope here, and it
  would need a different judge, not a different basis.
- **One worked spec existed to generalize from.** A survey of the whole
  `SuperInstance` org found `oil-pressure-port.cell.yaml` is the *only* cell spec
  anywhere. The generalization was therefore driven by real consumer code — five
  independent NMEA parsers, geofence longitudes, rudder angles — rather than by a
  family of existing specs.

## Two things the survey turned up

**Signed ranges are necessary, not theoretical.** The original's "0-based range"
restriction is contradicted by real data in the same ecosystem: a generated
geofence in `quilt-esp32/firmware/src/vessel_qm.h` carries
`lon_lo = -152500000, lon_hi = -152350000` — entirely negative. Rudder angle,
rate of turn and heading deviation are all signed by physical convention.

**A unit bug in shipped firmware.** `quilt-esp32/firmware/src/nmea/nmea.c`
converts km/h to knots with `* 5 / 18`. That is the km/h→**m/s** factor.
km/h→knots is `1000/1852 = 250/463`. Worth an upstream issue.

## Tests

15 tests, all passing, including compatibility with the original's hand-golden
table, the exactness gate accepting and rejecting, symmetric rounding across
zero verified against `Fraction` arithmetic, and the mutation test above.

```console
$ python -m pytest tests/ -q
15 passed
```

## License

MIT
