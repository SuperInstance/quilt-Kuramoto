#!/usr/bin/env python3
"""Byte-exactness: replaying the journal must reproduce derived views
byte-identically, no matter how many times it is replayed, from any
copy of the journal, and after a no-op restart of the gateway.

Plain python3, no docker, no pytest. Run from anywhere:
    python3 tests/test_byte_exact.py
"""
import hashlib
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from nmea_quilt import gateway, journal, nmea_gen, views  # noqa: E402

BUILD = os.path.join(ROOT, "build", "byte-exact")


def main():
    os.makedirs(BUILD, exist_ok=True)
    stream = os.path.join(BUILD, "stream.nmea")
    meta = nmea_gen.generate(ticks=300, seed=3, p_malformed=0.01, out=stream)
    jp = os.path.join(BUILD, "journal.jsonl")
    if os.path.exists(jp):
        os.remove(jp)

    st = gateway.run(stream, jp)
    assert st["ticks"] == 300 and st["complete"], st

    v1 = views.replay(jp)
    h1 = views.hashes(v1)

    # 1) replay twice more, render each to disk -> byte-identical files
    d1 = os.path.join(BUILD, "views-a")
    d2 = os.path.join(BUILD, "views-b")
    for d in (d1, d2):
        os.makedirs(d, exist_ok=True)
        for k, b in views.replay(jp).items():
            with open(os.path.join(d, k.replace("-", "_") + ".jsonl"), "wb") as f:
                f.write(b)
    for k in v1:
        fn = k.replace("-", "_") + ".jsonl"
        a = open(os.path.join(d1, fn), "rb").read()
        b = open(os.path.join(d2, fn), "rb").read()
        assert a == b == v1[k], "view %s drifted between replays" % k

    # 2) replay from a byte-copy of the journal -> identical
    jp2 = jp + ".copy"
    shutil.copyfile(jp, jp2)
    assert views.hashes(views.replay(jp2)) == h1

    # 3) journal integrity: contiguous seq, clean tail, no corruption
    sc = journal.scan(jp)
    assert sc["events"] == 300 and sc["last_seq"] == 299, sc
    assert not sc["seq_gap"] and not sc["tail_partial"] and not sc["bad_complete_line"], sc

    # 4) restart the gateway at EOF: no-op, views unchanged
    st2 = gateway.run(stream, jp)
    assert st2["ticks"] == 0, st2
    assert views.hashes(views.replay(jp)) == h1

    # 5) content sanity: seq wins over wall clock; malformed counted, not fatal
    m = json.loads(v1["meta"])
    assert m["ts_backwards"] > 0, "generator was supposed to lie about time"
    assert m["ts_backwards"] == meta["out_of_order"], (m["ts_backwards"], meta["out_of_order"])
    assert m["skipped"] == meta["malformed"], (m["skipped"], meta["malformed"])
    assert m["depth_points"] == 600, m   # DBT + DPT every tick
    dseqs = [json.loads(ln)["seq"] for ln in v1["depth-trace"].decode().splitlines()]
    assert dseqs == sorted(dseqs), "depth trace must follow seq order"
    lf = json.loads(v1["latest-fix"])
    assert lf["seq"] == 299, "latest fix must be highest seq, not latest wall time"
    wr = json.loads(v1["wind-rose"])
    assert wr["total"] == 300, wr         # one valid MWV per tick

    print("BYTE-EXACT TEST: PASS")
    for k in sorted(h1):
        print("  %-11s sha256:%s" % (k, h1[k]))
    print("  events=300  skipped=%d (== injected %d)  ts_backwards=%d (== emitted %d)  depth_points=%d"
          % (m["skipped"], meta["malformed"], m["ts_backwards"], meta["out_of_order"],
             m["depth_points"]))


if __name__ == "__main__":
    main()
