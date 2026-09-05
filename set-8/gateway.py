#!/usr/bin/env python3
"""NMEA 0183 -> quilt cell gateway.

Reads a recorded NMEA log, parses sentences with pynmea2 (no hand-rolled
parsing here), groups them into ticks (PQTLK markers), and appends one
canonical JSON event per tick to a single-writer append-only journal.

Restartable: on startup it heals a torn journal tail and resumes from the
last journaled input byte offset -- no data lost, no seq gaps, no
duplicates. Malformed sentences are skipped+counted, never fatal.
Ordering truth is `seq`; wall-clock time (GGA timestamps, arrival ts) is
advisory only.

Known pynmea2 quirks handled here (verified against pynmea2 1.19):
  - DBT's `.depth_meters` attribute is mislabeled (it returns fathoms),
    DPT has no depth attribute at all -> we index `data[]` per the
    NMEA 0183 field order instead ($SDDBT,feet,METERS,fathoms).
  - GGA's `.horizontal_dop` can be None even when present -> fall back
    to data[7].
"""
import argparse
import json
import os
import time

import pynmea2

from . import journal


def _num(x, conv=float, default=None):
    try:
        if x is None or x == "":
            return default
        return conv(x)
    except Exception:
        return default


def extract(sent, raw):
    """pynmea2 sentence -> canonical dict for the journal (None if unusable)."""
    t = getattr(sent, "sentence_type", "") or ""
    data = getattr(sent, "data", None) or []
    out = {"type": t, "raw": raw}
    try:
        if t == "GGA":
            lat = getattr(sent, "latitude", None)
            lon = getattr(sent, "longitude", None)
            if lat is None or lon is None:
                return None
            hdop = _num(getattr(sent, "horizontal_dop", None))
            if hdop is None:
                hdop = _num(data[7]) if len(data) > 7 else None
            out["fix"] = {
                "time": str(data[0]) if data else "",
                "lat": float(lat), "lon": float(lon),
                "sats": _num(getattr(sent, "num_sats", None), int, 0) or 0,
                "hdop": hdop if hdop is not None else 0.0,
                "alt": _num(getattr(sent, "altitude", None), float, 0.0),
            }
        elif t == "DBT":  # $--DBT,feet,meters,fathoms
            m = _num(data[1]) if len(data) > 1 else None
            if m is None:
                return None
            out["depth"] = {"m": m, "src": "DBT"}
        elif t == "DPT":  # $--DPT,depth_m,offset
            m = _num(data[0]) if data else None
            if m is None:
                return None
            out["depth"] = {"m": m, "src": "DPT"}
        elif t == "MWV":
            ang = _num(getattr(sent, "wind_angle", None))
            spd = _num(getattr(sent, "wind_speed", None))
            if ang is None or spd is None:
                return None
            out["wind"] = {"deg": ang, "kts": spd,
                           "ref": getattr(sent, "reference", "") or "",
                           "valid": (getattr(sent, "status", "") or "") == "A"}
        elif t == "XDR":
            out["xdr"] = [str(x) for x in data]
            if len(data) >= 4 and data[3] == "ENGINE1":
                out["engine"] = {"rpm": _num(data[1], float, 0.0)}
            elif len(data) >= 4 and data[3] == "ENGTEMP":
                out["engine"] = {"temp_c": _num(data[1], float, 0.0)}
        else:
            out["data"] = [str(x) for x in data]
    except Exception:
        return None
    return out


def run(input_path, journal_path, pace_ms=0.0, fsync=False, quiet=False):
    size = os.path.getsize(input_path)
    rec = journal.recover(journal_path)   # heal torn tail; refuse corruption
    last = rec["last_event"]
    seq = int(last["seq"]) + 1 if last else 0
    pos = int(last["pos"]) if last else 0
    if pos > size:
        raise SystemExit("journal pos %d is beyond input size %d (wrong input?)"
                         % (pos, size))
    stats = {"resumed_seq": seq, "resumed_pos": pos,
             "healed_tail_bytes": rec["truncated_bytes"],
             "ticks": 0, "sentences": 0, "skipped": 0}
    t0 = time.time()
    with open(input_path, "rb") as inp, open(journal_path, "ab") as jf:
        inp.seek(pos)
        tick = None
        parts = []
        skip = 0
        end_pos = pos

        def flush(tick_end):
            """Journal one event; `pos` points BEFORE the next tick's marker,
            so a restart re-reads that marker and never loses mid-tick lines."""
            nonlocal tick, parts, skip, seq
            if tick is None:
                return
            ev = {"seq": seq, "tick": tick, "pos": tick_end, "n": len(parts),
                  "skipped": skip, "ts": time.time(), "sents": parts}
            jf.write(journal.dump_event(ev))
            jf.flush()
            if fsync:
                os.fsync(jf.fileno())
            stats["ticks"] += 1
            stats["sentences"] += len(parts)
            stats["skipped"] += skip
            seq += 1
            parts = []
            skip = 0
            if pace_ms:
                time.sleep(pace_ms / 1000.0)

        while True:
            line_start = inp.tell()
            raw_line = inp.readline()
            if not raw_line:
                break
            end_pos = inp.tell()
            line = raw_line.decode("ascii", "replace").strip()
            if not line:
                skip += 1
                continue
            if line.startswith("$PQTLK,"):
                flush(line_start)      # previous tick ended before this marker
                try:
                    tick = int(line.split(",")[1].split("*")[0])
                except Exception:
                    skip += 1
                    tick = None        # malformed marker: skip+count, no crash
                continue
            if tick is None:
                skip += 1              # sentence outside any tick
                continue
            try:
                s = pynmea2.parse(line)
            except Exception:
                skip += 1              # malformed: count it, keep going
                continue
            ex = extract(s, line)
            if ex is None:
                skip += 1              # parsed but unusable
                continue
            parts.append(ex)
        flush(end_pos)
    stats["skipped"] += skip   # anything counted outside a flushed tick
    stats["seq_last"] = seq - 1
    stats["consumed"] = end_pos
    stats["input_bytes"] = size
    stats["complete"] = end_pos == size
    stats["journal_bytes"] = os.path.getsize(journal_path)
    stats["elapsed_s"] = round(time.time() - t0, 3)
    if not quiet:
        print(json.dumps(stats))
    return stats


def main():
    ap = argparse.ArgumentParser(description="NMEA log -> journal gateway")
    ap.add_argument("--input", required=True)
    ap.add_argument("--journal", required=True)
    ap.add_argument("--pace-ms", type=float, default=0.0,
                    help="sleep per tick (simulates a live ~10Hz feed)")
    ap.add_argument("--fsync", action="store_true",
                    help="fsync each event (durable vs power loss, not just process kill)")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    run(a.input, a.journal, pace_ms=a.pace_ms, fsync=a.fsync, quiet=a.quiet)


if __name__ == "__main__":
    main()
