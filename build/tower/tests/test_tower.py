"""Tower's own tests. The gate is only worth having if it can fail."""

import pathlib
import subprocess
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from tower.emit import emit_c            # noqa: E402
from tower.load import load_spec, loads_spec  # noqa: E402
from tower.spec import CellSpec, SpecError, parse_basis, parse_equation  # noqa: E402
from tower.verify import find_compiler, verify  # noqa: E402

EX = pathlib.Path(__file__).resolve().parents[1] / "examples"


def oil():
    return load_spec(EX / "oil-pressure-port.cell.yaml")


# --- compatibility with the generator this was lifted from ----------------

# The 17 anchors from quilt-verilog/tools/tower/verify.py, hand-computed there
# and independent of both generators.
HAND_GOLDEN = [
    (500, 0), (900, 15), (1300, 30), (1700, 45), (2100, 60), (2500, 75),
    (2900, 90), (3300, 105), (3700, 120), (4100, 135), (4500, 150),
    (750, 9), (1000, 19), (2750, 84), (4499, 150), (475, 0), (4600, 150),
]


def test_reproduces_the_original_generators_hand_golden_table():
    sp = oil()
    for mv, want in HAND_GOLDEN:
        assert sp.render(mv) == want, f"{mv} mV should render to {want} psi"


def test_loads_the_upstream_spec_file_unmodified():
    """The upstream .cell.yaml is copied in verbatim; it must still parse."""
    sp = oil()
    assert (sp.name, sp.unit, sp.offset, sp.num, sp.den) == \
        ("oil-pressure-port", "psi", 500, 3, 80)
    assert (sp.out_min, sp.out_max, sp.deadband) == (0, 150, 1)
    assert (sp.median_window, sp.tick_ms) == (5, 100)


def test_the_basis_trick_every_400mv_is_exactly_15_psi():
    """The claim the spec file makes about itself."""
    sp = oil()
    for k in range(11):
        assert sp.render(500 + 400 * k) == 15 * k


# --- the exactness gate ----------------------------------------------------

def test_gate_rejects_an_inexact_basis():
    with pytest.raises(SpecError, match="basis not exact"):
        load_spec(EX / "depth-fathoms.cell.yaml")


def test_gate_accepts_only_when_the_span_lands_on_the_lattice():
    def build(num, den, out_max):
        return CellSpec(name="t", cname="t", in_name="x", out_name="y", unit="u",
                        offset=0, num=num, den=den, basis_den=den,
                        out_min=0, out_max=out_max, deadband=1,
                        median_window=1, tick_ms=10)
    build(3, 80, 150)                       # 150*80 % 3 == 0
    with pytest.raises(SpecError):
        build(7, 80, 150)                   # 150*80 % 7 != 0
    build(1, 10, 165)                       # always exact when num == 1


def test_gate_rejects_malformed_specs():
    bad = [
        ("even median window", dict(median_window=4)),
        ("negative deadband", dict(deadband=-1)),
        ("zero tick", dict(tick_ms=0)),
        ("oversized window", dict(median_window=99)),
        ("inverted range", dict(out_min=10, out_max=0)),
    ]
    for label, over in bad:
        kw = dict(name="t", cname="t", in_name="x", out_name="y", unit="u",
                  offset=0, num=1, den=1, basis_den=1, out_min=0, out_max=10,
                  deadband=1, median_window=1, tick_ms=10)
        kw.update(over)
        with pytest.raises(SpecError):
            CellSpec(**kw)


def test_equation_and_basis_grammar():
    assert parse_equation("psi = (mV - 500) * 3 / 80") == ("psi", "mV", 500, 3, 80)
    assert parse_equation("y = (x) * 2") == ("y", "x", 0, 2, 1)
    assert parse_equation("y = (x + 40) * 1 / 10") == ("y", "x", -40, 1, 10)
    assert parse_basis("1/80 psi") == (80, "psi")
    assert parse_basis("1 degC") == (1, "degC")
    for bad in ["psi = mV * 3", "psi = (mV - 500) / 80", "no equals sign"]:
        with pytest.raises(SpecError):
            parse_equation(bad)


def test_range_key_unit_must_agree_with_the_basis():
    text = (EX / "oil-pressure-port.cell.yaml").read_text()
    assert "range_psi" in text
    with pytest.raises(SpecError, match="disagrees with basis unit"):
        loads_spec(text.replace("range_psi", "range_bar"))


# --- generalisation beyond the original ------------------------------------

def test_negative_range_which_the_original_rejected_outright():
    sp = load_spec(EX / "coolant-temp.cell.yaml")
    assert sp.out_min == -40 and sp.unit == "degC"
    assert sp.render(100) == -40
    assert sp.render(500) == 0
    assert sp.render(1750) == 125


def test_rounding_is_symmetric_about_zero():
    """Negative values must round away from zero exactly like positive ones."""
    sp = CellSpec(name="t", cname="t", in_name="x", out_name="y", unit="u",
                  offset=0, num=1, den=2, basis_den=2, out_min=-100, out_max=100,
                  deadband=1, median_window=1, tick_ms=10)
    assert sp.render(1) == 1 and sp.render(-1) == -1      # ±0.5 → ±1
    assert sp.render(3) == 2 and sp.render(-3) == -2      # ±1.5 → ±2
    for x in range(-200, 201):
        assert sp.render(x) == -sp.render(-x), f"asymmetric at {x}"


def test_render_matches_exact_rational_arithmetic_everywhere():
    from fractions import Fraction
    for sp in (oil(), load_spec(EX / "coolant-temp.cell.yaml")):
        for raw in range(-500, 5000, 7):
            f: Fraction = sp.exact_fraction(raw)
            n, d = f.numerator, f.denominator
            q = (2 * n + d) // (2 * d) if n >= 0 else -((-2 * n + d) // (2 * d))
            assert sp.render(raw) == max(sp.out_min, min(sp.out_max, q))


# --- the generated C -------------------------------------------------------

def test_generated_c_has_no_floating_point_type():
    """Uses `verify`'s own detector, so the test and the gate cannot drift.

    A naive substring check would trip on the file's own comment saying "No
    floating-point type appears in this file" -- the word-boundary regex is
    what makes the check mean what it says.
    """
    from tower.verify import _FLOAT_RE
    for sp in (oil(), load_spec(EX / "coolant-temp.cell.yaml")):
        c = emit_c(sp, [1, 2, 3])
        hits = [m.group(0) for m in _FLOAT_RE.finditer(c)]
        assert not hits, f"floating-point type reached the generated C: {hits}"
        assert "floating-point" in c, "the prose claim should still be present"


def test_the_float_detector_would_catch_a_real_float():
    """The detector must be able to fire, or it proves nothing."""
    from tower.verify import _FLOAT_RE
    assert _FLOAT_RE.search("double x = 1;")
    assert _FLOAT_RE.search("float y;")
    assert not _FLOAT_RE.search("/* no floating-point here */")


@pytest.mark.skipif(find_compiler() is None, reason="no C compiler")
def test_full_gate_passes_for_every_accepted_example():
    vectors = [500, 520, 900, 905, 1300, 4500, 4400, 2500, 2505, 475, 4600]
    for sp in (oil(), load_spec(EX / "coolant-temp.cell.yaml")):
        res = verify(sp, vectors)
        assert res.ok, f"{sp.name} failed the gate:\n{res.report()}"


@pytest.mark.skipif(find_compiler() is None, reason="no C compiler")
def test_the_gate_actually_catches_a_broken_generator():
    """Mutation: if the emitted C rounds differently, the gate must fail.

    A gate that only ever passes proves nothing.

    (The emitter lives in `tower.emit`, not `tower.emit_c`, precisely so the
    exported `emit_c` function does not shadow its own module — a collision
    this test caught the moment the package `__init__` was added.)
    """
    import tower.emit as ec
    sp = oil()
    original = ec._TEMPLATE
    try:
        # Truncate toward zero instead of rounding half away from zero.
        ec._TEMPLATE = original.replace(
            "q = (2 * n + d) / (2 * d);", "q = n / d;")
        res = verify(sp, [750, 1000, 2750])
        assert not res.ok, "the gate passed a generator that rounds wrongly"
        assert any("rendering" in name and not ok for name, ok, _ in res.checks)
    finally:
        ec._TEMPLATE = original
    assert verify(sp, [750, 1000, 2750]).ok, "restore failed"
