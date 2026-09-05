"""Derived views, rebuilt from scratch by replaying the journal.

Views are pure functions of journal content:
  latest-fix   last fix by SEQ (wall clock never decides anything)
  depth-trace  every depth report, in seq order
  wind-rose    16-sector counts of valid relative wind
  meta         bookkeeping (events, skipped, backwards timestamps)

Rendering is canonical JSON (sorted keys, compact separators), so
sha256(view) is stable for a given journal -- that is the byte-exact
contract the tests hold us to. Replay is idempotent by construction:
it rebuilds from zero every time.
"""
import hashlib
import json

from . import journal

SECTORS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
           "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]


def _canon(obj) -> bytes:
    return (json.dumps(obj, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def replay(path):
    fix = None
    fix_seq = None
    depth = []
    wind = [0] * 16
    events = 0
    skipped = 0
    ts_backwards = 0
    last_time = None
    for ev in journal.iter_events(path):
        events += 1
        skipped += int(ev.get("skipped", 0))
        for s in ev.get("sents", []):
            t = s.get("type")
            if t == "GGA" and s.get("fix"):
                ft = s["fix"].get("time", "")
                if ft and last_time is not None and ft < last_time:
                    ts_backwards += 1      # advisory clock lied; seq order won
                if ft:
                    last_time = ft
                fix = s["fix"]
                fix_seq = ev["seq"]
            elif t in ("DBT", "DPT") and s.get("depth"):
                depth.append({"seq": ev["seq"], "m": s["depth"]["m"],
                              "src": s["depth"]["src"]})
            elif t == "MWV" and s.get("wind") and s["wind"].get("valid"):
                ang = float(s["wind"]["deg"]) % 360.0
                idx = int((ang + 11.25) // 22.5) % 16
                wind[idx] += 1
    return {
        "latest-fix": _canon({"seq": fix_seq, "fix": fix}),
        "depth-trace": b"".join(_canon(d) for d in depth),
        "wind-rose": _canon({"sectors": SECTORS, "counts": wind, "total": sum(wind)}),
        "meta": _canon({"depth_points": len(depth), "events": events,
                        "skipped": skipped, "ts_backwards": ts_backwards}),
    }


def hashes(v):
    return {k: hashlib.sha256(b).hexdigest() for k, b in v.items()}


def main():
    import argparse
    ap = argparse.ArgumentParser(description="replay journal -> view hashes")
    ap.add_argument("--journal", required=True)
    a = ap.parse_args()
    h = hashes(replay(a.journal))
    for k in sorted(h):
        print("%-12s sha256:%s" % (k, h[k]))


if __name__ == "__main__":
    main()
