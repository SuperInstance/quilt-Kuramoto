"""`python -m tower` — compile and verify a cell spec.

    python -m tower examples/oil-pressure-port.cell.yaml -o out.c
    python -m tower examples/coolant-temp.cell.yaml --check

Exit status is 0 only when every check passes. A spec whose basis is not exact
never produces a file.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .emit import emit_c
from .load import load_spec
from .spec import SpecError
from .verify import verify


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="tower", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("spec", help="path to a *.cell.yaml spec")
    ap.add_argument("-o", "--out", help="write the C here (default: stdout)")
    ap.add_argument("--check", action="store_true",
                    help="run the full gate and print the report")
    ap.add_argument("--vectors", default="",
                    help="comma-separated raw inputs for the self-test")
    args = ap.parse_args(argv)

    try:
        spec = load_spec(args.spec)
    except SpecError as e:
        print(f"tower: {args.spec}: {e}", file=sys.stderr)
        return 2

    if args.vectors:
        vectors = [int(v) for v in args.vectors.split(",")]
    else:
        step = max(1, spec.span_in // 8)
        vectors = [spec.offset + step * k for k in range(9)]

    if args.check:
        res = verify(spec, vectors)
        print(f"tower: {spec.name}")
        print(res.report())
        return 0 if res.ok else 1

    text = emit_c(spec, vectors)
    if args.out:
        Path(args.out).write_text(text)
        print(f"tower: wrote {args.out} ({len(text)} bytes)", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
