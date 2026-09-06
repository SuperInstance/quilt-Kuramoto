"""The cell spec: a physical quantity, an exact conversion, and a deadband.

Generalised from `quilt-verilog/tools/tower/emith.py`, which compiled exactly
one shape — an affine millivolts-to-psi transform on a zero-based range. The
doctrine is kept intact; the hardcoding is not.

What is kept
------------
* **The exactness gate.** The generator refuses to emit code when the chosen
  basis does not land the range on the integer lattice exactly. It does not
  approximate and then apologise in a comment.
* **The basis trick.** Choose the report unit so the calibration constant comes
  out whole. `psi = (mV - 500) * 3/80` is exact on a 1/80-psi basis because
  4000 mV of span times 3/80 is exactly 150.
* **Squared-form judging.** The deadband comparison is `d² > D²` in integers, so
  no square root and no float ever enters the loop.

What is generalised
-------------------
* Any unit, not just psi.
* Any range, including negative and non-zero minimums (temperature, depth
  relative to a datum, signed angles).
* Optional offset, optional divisor.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from fractions import Fraction

__all__ = ["CellSpec", "SpecError", "parse_equation", "parse_basis"]


class SpecError(Exception):
    """A spec that cannot be compiled exactly. Never a warning."""


# out = (in - offset) * num / den   — offset and /den both optional.
_EQ_RE = re.compile(
    r"^(?P<out>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
    r"\(\s*(?P<in>[A-Za-z_][A-Za-z0-9_]*)\s*"
    r"(?:(?P<sign>[-+])\s*(?P<offset>\d+)\s*)?\)\s*"
    r"\*\s*(?P<num>\d+)\s*(?:/\s*(?P<den>\d+))?$"
)

# "1/80 psi", "1/1 m", "1 degC"  — the reporting lattice.
_BASIS_RE = re.compile(r"^(?:1/(?P<den>\d+)|1)\s*(?P<unit>[A-Za-z_µ°][A-Za-z0-9_/°µ-]*)$")


def parse_equation(text: str) -> tuple[str, str, int, int, int]:
    """`out = (in - offset) * num / den` → (out, in, offset, num, den)."""
    m = _EQ_RE.match(text.strip())
    if not m:
        raise SpecError(
            "equation %r is not of the supported affine form "
            "'out = (in - offset) * num / den'" % text)
    offset = int(m.group("offset") or 0)
    if m.group("sign") == "+":
        offset = -offset
    den = int(m.group("den") or 1)
    if den == 0:
        raise SpecError("equation divides by zero")
    return (m.group("out"), m.group("in"), offset, int(m.group("num")), den)


def parse_basis(text: str) -> tuple[int, str]:
    """`1/80 psi` → (80, 'psi'). The denominator is the reporting lattice."""
    m = _BASIS_RE.match(text.strip())
    if not m:
        raise SpecError("basis %r is not of the form '1/N unit' or '1 unit'" % text)
    return (int(m.group("den") or 1), m.group("unit"))


@dataclass(frozen=True)
class CellSpec:
    """A compiled, exactness-checked cell.

    Constructing one is the gate: if the basis does not land the range on the
    lattice exactly, this raises rather than rounding.
    """

    name: str
    cname: str
    in_name: str
    out_name: str
    unit: str
    offset: int
    num: int
    den: int
    basis_den: int
    out_min: int
    out_max: int
    deadband: int
    median_window: int
    tick_ms: int
    description: str = ""

    # ---- the gate --------------------------------------------------------

    @staticmethod
    def _check_exact(out_min: int, out_max: int, num: int, den: int,
                     basis_den: int, unit: str) -> int:
        """Refuse any basis that does not represent the range exactly.

        The span in output units must land on the `1/basis_den` lattice, and
        the corresponding input span must be a whole number of input units.
        Both are integer divisibility tests — no float, no tolerance.

        Returns the input span.
        """
        span_out = out_max - out_min
        if span_out <= 0:
            raise SpecError("range must be increasing: [%d, %d]" % (out_min, out_max))

        # The span must be expressible on the reporting lattice.
        if (span_out * basis_den) % 1 != 0:      # integers: always true, kept explicit
            raise SpecError("span does not land on the 1/%d %s lattice"
                            % (basis_den, unit))

        # Inverting out = in * num/den, the input span is span_out * den / num.
        if (span_out * den) % num != 0:
            raise SpecError(
                "basis not exact: a span of %d %s does not land on the 1/%d-%s "
                "lattice under *%d/%d. Choose report units so the calibration "
                "constant comes out whole, rather than approximating."
                % (span_out, unit, basis_den, unit, num, den))
        return span_out * den // num

    def __post_init__(self) -> None:
        if not re.fullmatch(r"[a-z][a-z0-9-]*", self.name):
            raise SpecError("name %r must be lowercase hyphen-words" % self.name)
        if self.median_window % 2 == 0 or self.median_window < 1:
            raise SpecError("median window must be odd and positive, got %d"
                            % self.median_window)
        if self.median_window > 15:
            raise SpecError("median window %d exceeds the 15-sample cap"
                            % self.median_window)
        if self.deadband < 0:
            raise SpecError("deadband must be non-negative")
        if self.tick_ms <= 0:
            raise SpecError("tick period must be positive")
        object.__setattr__(self, "span_in",
                           self._check_exact(self.out_min, self.out_max, self.num,
                                             self.den, self.basis_den, self.unit))

    # ---- the model, in exact integers ------------------------------------

    def render(self, raw: int) -> int:
        """Convert one raw reading, exactly, rounding half away from zero.

        Symmetric about zero, so a negative range behaves exactly like a
        positive one — which matters the moment the quantity is a temperature
        or a depth relative to a datum. Pure integer arithmetic:
        `(2n + d) // 2d` with the sign carried out and back.

        This is the reference the generated C must match on every vector.
        """
        n = (raw - self.offset) * self.num
        d = self.den
        if n >= 0:
            q = (2 * n + d) // (2 * d)
        else:
            q = -((-2 * n + d) // (2 * d))
        return max(self.out_min, min(self.out_max, q))

    def exact_fraction(self, raw: int) -> Fraction:
        """The unrounded value, for tests that need to see the true quantity."""
        return Fraction((raw - self.offset) * self.num, self.den)

    def within_deadband(self, a: int, b: int) -> bool:
        """The squared-form judge: `d² ≤ D²`, exact integers, no root."""
        d = a - b
        return d * d <= self.deadband * self.deadband
