"""Single-writer append-only journal (JSONL) with crash recovery.

Protocol:
  - Exactly one process ever appends (the gateway). Readers only read,
    lock-free: they never take a lock and never block the writer.
  - One event per line, canonical JSON, flushed on append.
  - `seq` is contiguous from 0; `pos` is the input byte offset covered.
  - A torn final line (crash mid-write) is healed by truncation on the
    writer's next startup. Readers simply skip a torn tail.

Anything other than a torn tail (a seq gap, mid-file corruption) raises
JournalCorrupt instead of silently destroying data.
"""
import json
import os


class JournalCorrupt(RuntimeError):
    pass


def dump_event(ev: dict) -> bytes:
    return (json.dumps(ev, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def scan(path):
    """Read-only integrity scan. Memory O(line), never blocks anyone."""
    res = {"exists": os.path.exists(path), "valid_bytes": 0, "events": 0,
           "last_seq": None, "tail_partial": False, "bad_complete_line": False,
           "seq_gap": False}
    if not res["exists"]:
        return res
    cur = 0
    last_seq = None
    n = 0
    with open(path, "rb") as f:
        for raw in f:
            if not raw.endswith(b"\n"):
                res["tail_partial"] = True
                break
            try:
                ev = json.loads(raw)
                seq = ev["seq"]
            except Exception:
                res["bad_complete_line"] = True
                break
            if not isinstance(seq, int) or (last_seq is not None and seq != last_seq + 1):
                res["seq_gap"] = True
                break
            last_seq = seq
            n += 1
            cur += len(raw)
    res["valid_bytes"] = cur
    res["events"] = n
    res["last_seq"] = last_seq
    return res


def iter_events(path):
    """Lock-free read of every complete, parseable event. Skips a torn tail."""
    if not os.path.exists(path):
        return
    with open(path, "rb") as f:
        for raw in f:
            if not raw.endswith(b"\n"):
                break  # torn tail: consistent prefix, reader never blocks
            try:
                yield json.loads(raw)
            except Exception:
                break


def read_last_event(path):
    last = None
    for ev in iter_events(path):
        last = ev
    return last


def recover(path):
    """Writer-startup recovery: heal a torn tail, refuse real corruption."""
    size = os.path.getsize(path) if os.path.exists(path) else 0
    sc = scan(path)
    if sc["seq_gap"] or sc["bad_complete_line"]:
        raise JournalCorrupt("journal %s: gap/corruption (scan=%s)" % (path, sc))
    truncated = size - sc["valid_bytes"]
    if truncated > 0:
        with open(path, "r+b") as f:
            f.truncate(sc["valid_bytes"])
    sc["truncated_bytes"] = truncated
    sc["size_before"] = size
    sc["last_event"] = read_last_event(path) if sc["events"] else None
    return sc
