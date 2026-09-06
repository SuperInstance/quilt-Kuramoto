"""Compile the generated C, run it, and cross-check every line it prints.

Three independent things must agree before a cell is accepted:

1. the **generated C**, actually compiled and executed;
2. an independent **Python model** of the same spec;
3. exact **rational arithmetic** (`fractions.Fraction`), which has no rounding
   at all and so cannot share a rounding bug with either of the others.

Plus a property that is checked rather than claimed: the generated C contains no
floating-point type. That check is the reason to trust the rest.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path

from .emit import emit_c
from .spec import CellSpec

__all__ = ["verify", "VerifyResult", "find_compiler"]

_FLOAT_RE = re.compile(r"\b(float|double|long\s+double)\b")


class VerifyResult:
    """What the gate found. Falsy when anything failed."""

    def __init__(self) -> None:
        self.checks: list[tuple[str, bool, str]] = []

    def add(self, name: str, ok: bool, detail: str = "") -> None:
        self.checks.append((name, ok, detail))

    @property
    def ok(self) -> bool:
        return all(ok for _, ok, _ in self.checks)

    def __bool__(self) -> bool:
        return self.ok

    def report(self) -> str:
        lines = []
        for name, ok, detail in self.checks:
            mark = "ok  " if ok else "FAIL"
            lines.append(f"  {mark} {name}" + (f" -- {detail}" if detail else ""))
        lines.append(f"  {'PASS' if self.ok else 'FAILED'}")
        return "\n".join(lines)


def find_compiler() -> str | None:
    for cc in ("cc", "gcc", "clang"):
        if shutil.which(cc):
            return cc
    return None


def _python_ticks(spec: CellSpec, vectors: list[int]):
    """Simulate the cell in Python: median, render, judge, snap, debt."""
    buf: list[int] = []
    twin: int | None = None
    debt = 0
    out = []
    for raw in vectors:
        buf.append(raw)
        if len(buf) > spec.median_window:
            buf.pop(0)
        filtered = sorted(buf)[len(buf) // 2]
        value = spec.render(filtered)
        if twin is None:
            twin, snapped = value, 1
        elif not spec.within_deadband(value, twin):
            debt += abs(value - twin)
            twin, snapped = value, 1
        else:
            snapped = 0
        out.append((raw, value, snapped, debt))
    return out


def verify(spec: CellSpec, vectors: list[int]) -> VerifyResult:
    """Run the full gate. Returns a `VerifyResult`; check `.ok`."""
    res = VerifyResult()
    c_text = emit_c(spec, vectors)

    # --- property 1: no floating-point type in the generated C -------------
    hits = [m.group(0) for m in _FLOAT_RE.finditer(c_text)]
    res.add("no floating-point type in generated C", not hits,
            f"found {hits}" if hits else "")

    # --- property 2: the Python model agrees with exact rational arithmetic -
    mismatches = 0
    lo = spec.offset - spec.span_in
    hi = spec.offset + 2 * spec.span_in
    for raw in range(lo, hi + 1):
        f: Fraction = spec.exact_fraction(raw)
        n, d = f.numerator, f.denominator
        q = (2 * n + d) // (2 * d) if n >= 0 else -((-2 * n + d) // (2 * d))
        want = max(spec.out_min, min(spec.out_max, q))
        if spec.render(raw) != want:
            mismatches += 1
    res.add("Python model matches exact rational arithmetic", mismatches == 0,
            f"{mismatches} mismatches over {hi - lo + 1} inputs"
            if mismatches else f"{hi - lo + 1} inputs")

    # --- property 3: the C compiles cleanly --------------------------------
    cc = find_compiler()
    if cc is None:
        res.add("generated C compiles", False, "no C compiler found")
        return res

    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / f"{spec.cname}.c"
        exe = Path(td) / spec.cname
        src.write_text(c_text)
        proc = subprocess.run(
            [cc, "-std=c99", "-Wall", "-Wextra", "-Werror", "-O2",
             f"-D{spec.cname.upper()}_SELFTEST", str(src), "-o", str(exe)],
            capture_output=True, text=True)
        res.add("generated C compiles with -Wall -Wextra -Werror",
                proc.returncode == 0, proc.stderr.strip()[:400])
        if proc.returncode != 0:
            return res

        run = subprocess.run([str(exe)], capture_output=True, text=True)
        res.add("self-test runs", run.returncode == 0, run.stderr.strip()[:200])
        if run.returncode != 0:
            return res

    # --- property 4: every printed line matches the Python model -----------
    lines = run.stdout.strip().splitlines()
    bad: list[str] = []

    rendered = [l for l in lines if l.startswith("RENDER ")]
    for l in rendered:
        _, raw, got = l.split()
        if int(got) != spec.render(int(raw)):
            bad.append(f"{l} (model says {spec.render(int(raw))})")
    res.add("C rendering matches the model", not bad,
            "; ".join(bad[:3]) if bad else f"{len(rendered)} rows")

    bad = []
    for l in [l for l in lines if l.startswith("WITHIN ")]:
        _, a, _d, got = l.split()
        want = 1 if spec.within_deadband(int(a), 0) else 0
        if int(got) != want:
            bad.append(f"{l} (model says {want})")
    res.add("C deadband judge matches the model", not bad,
            "; ".join(bad[:3]) if bad else "")

    bad = []
    ticks = [l for l in lines if l.startswith("TICK ")]
    model = _python_ticks(spec, vectors)
    if len(ticks) != len(model):
        bad.append(f"C printed {len(ticks)} ticks, model expects {len(model)}")
    for l, (raw, value, snapped, debt) in zip(ticks, model):
        _, c_raw, c_val, c_snap, c_debt = l.split()
        if (int(c_raw), int(c_val), int(c_snap), int(c_debt)) != (raw, value, snapped, debt):
            bad.append(f"{l} (model says {raw} {value} {snapped} {debt})")
    res.add("C cell simulation matches the model", not bad,
            "; ".join(bad[:3]) if bad else f"{len(ticks)} ticks")

    return res
