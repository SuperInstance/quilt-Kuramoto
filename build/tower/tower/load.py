"""Load a `*.cell.yaml` spec. A strict, tiny subset — no PyYAML dependency.

The subset is deliberately small: scalars, nested maps by indentation, inline
`{...}` maps and `[...]` lists, `#` comments, and `>`-folded blocks. Anything
outside it is an error rather than a silent misreading, because a spec that is
quietly misparsed produces confidently wrong firmware.
"""

from __future__ import annotations

import re
from pathlib import Path

from .spec import CellSpec, SpecError, parse_basis, parse_equation

__all__ = ["load_spec", "loads_spec"]

_KEY_RE = re.compile(r"^(?P<indent>\s*)(?P<key>[A-Za-z_][A-Za-z0-9_-]*)\s*:(?P<rest>.*)$")
_ITEM_RE = re.compile(r"^(?P<indent>\s*)-\s*(?P<rest>.*)$")


def _strip_comment(line: str) -> str:
    out, quote = [], None
    for ch in line:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#":
            break
        else:
            out.append(ch)
    return "".join(out).rstrip()


def _scalar(text: str):
    t = text.strip()
    if not t:
        return None
    if t[0] in "\"'" and t[-1] == t[0] and len(t) >= 2:
        return t[1:-1]
    if t.startswith("[") and t.endswith("]"):
        inner = t[1:-1].strip()
        return [_scalar(x) for x in inner.split(",")] if inner else []
    if t.startswith("{") and t.endswith("}"):
        out = {}
        inner = t[1:-1].strip()
        if inner:
            for part in inner.split(","):
                if ":" not in part:
                    raise SpecError("inline map item %r lacks ':'" % part)
                k, v = part.split(":", 1)
                out[k.strip()] = _scalar(v)
        return out
    if re.fullmatch(r"-?\d+", t):
        return int(t)
    return t


def _parse(lines: list[tuple[int, str]], i: int, indent: int):
    """Parse a block at `indent`. Returns (value, next_index)."""
    if i < len(lines) and _ITEM_RE.match(lines[i][1]) and \
            len(_ITEM_RE.match(lines[i][1]).group("indent")) >= indent:
        items = []
        while i < len(lines):
            m = _ITEM_RE.match(lines[i][1])
            if not m or len(m.group("indent")) < indent:
                break
            rest = m.group("rest").strip()
            child_indent = len(m.group("indent")) + 2
            if ":" in rest and not rest.startswith(("{", "[")):
                sub_lines = [(lines[i][0], " " * child_indent + rest)] + lines[i + 1:]
                val, consumed = _parse(sub_lines, 0, child_indent)
                items.append(val)
                i += consumed
            else:
                items.append(_scalar(rest))
                i += 1
        return items, i

    out: dict = {}
    start = i
    while i < len(lines):
        m = _KEY_RE.match(lines[i][1])
        if not m:
            raise SpecError("line %d: cannot parse %r" % (lines[i][0], lines[i][1]))
        cur = len(m.group("indent"))
        if cur < indent:
            break
        if cur > indent:
            raise SpecError("line %d: unexpected indent" % lines[i][0])
        key, rest = m.group("key"), m.group("rest").strip()
        i += 1
        if rest == ">":
            folded = []
            while i < len(lines) and len(lines[i][1]) - len(lines[i][1].lstrip()) > indent:
                folded.append(lines[i][1].strip())
                i += 1
            out[key] = " ".join(folded)
        elif rest:
            out[key] = _scalar(rest)
        else:
            child, i = _parse(lines, i, indent + 2)
            out[key] = child
    if i == start:
        raise SpecError("empty block")
    return out, i


def loads_spec(text: str, name_hint: str = "cell") -> CellSpec:
    """Parse spec text into a checked `CellSpec`."""
    lines = []
    for n, raw in enumerate(text.splitlines(), 1):
        s = _strip_comment(raw)
        if s.strip():
            lines.append((n, s))
    doc, _ = _parse(lines, 0, 0)
    return _build(doc, name_hint)


def load_spec(path: str | Path) -> CellSpec:
    """Load and check a `*.cell.yaml` spec from disk."""
    p = Path(path)
    return loads_spec(p.read_text(), p.name)


def _need(doc: dict, key: str, where: str):
    if key not in doc or doc[key] is None:
        raise SpecError("%s: missing '%s'" % (where, key))
    return doc[key]


def _build(doc: dict, where: str) -> CellSpec:
    name = _need(doc, "name", where)
    rendering = _need(doc, "rendering", where)
    out_name, in_name, offset, num, den = parse_equation(_need(rendering, "equation", "rendering"))
    basis_den, unit = parse_basis(str(_need(rendering, "basis", "rendering")))

    # Accept the generic `range:` and the upstream unit-suffixed `range_psi:`
    # form, so existing specs load unmodified.
    rng = rendering.get("range")
    if rng is None:
        suffixed = [k for k in rendering if k.startswith("range_")]
        if len(suffixed) > 1:
            raise SpecError("rendering has several range keys: %s" % sorted(suffixed))
        if suffixed:
            rng = rendering[suffixed[0]]
            key_unit = suffixed[0][len("range_"):]
            if key_unit and key_unit != unit:
                raise SpecError(
                    "rendering.%s disagrees with basis unit %r -- the range key "
                    "names a different unit from the one being reported"
                    % (suffixed[0], unit))
    if rng is None:
        raise SpecError("rendering: missing 'range' (or 'range_<unit>')")
    if not (isinstance(rng, list) and len(rng) == 2):
        raise SpecError("rendering.range must be [min, max]")

    deadband = _need(rendering, "deadband", "rendering")
    whole = deadband["whole"] if isinstance(deadband, dict) else deadband

    raw = doc.get("raw") or {}
    prefilter = raw.get("prefilter") or {}
    window = prefilter.get("window", 1) if isinstance(prefilter, dict) else 1

    tick = doc.get("tick") or {}
    period = tick.get("period_ms", 100) if isinstance(tick, dict) else 100

    return CellSpec(
        name=name, cname=str(name).replace("-", "_"),
        in_name=in_name, out_name=out_name, unit=unit,
        offset=offset, num=num, den=den, basis_den=basis_den,
        out_min=int(rng[0]), out_max=int(rng[1]),
        deadband=int(whole), median_window=int(window), tick_ms=int(period),
        description=str(doc.get("description", "")).strip(),
    )
