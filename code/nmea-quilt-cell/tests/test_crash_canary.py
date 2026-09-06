#!/usr/bin/env python3
"""CRASH CANARY: SIGKILL the journal writer mid-stream, over and over.

For each of KILLS kills:
  1. start the gateway (it resumes from the journal), paced like a
     live 10 Hz feed
  2. wait until the journal holds >= target events, then kill -9
  3. on odd kills, simulate a torn final write, then run the exact
     recovery the writer runs on startup
  4. assert: seq contiguous with no gaps, replay #1 == replay #2
     byte-exact (idempotent rebuild)

Finally: run to completion with a concurrent lock-free reader scanning
the journal the whole time, then check totals against the generator's
manifest. Plain python3, no docker:
    python3 tests/test_crash_canary.py
"""
import json
import os
import random
import signal
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from nmea_quilt import journal, nmea_gen, views  # noqa: E402

BUILD = os.path.join(ROOT, "build", "crash-canary")
TICKS = 4000
PACE_MS = 2
KILLS = 10


def spawn(stream, jp, pace_ms):
    env = dict(os.environ, PYTHONPATH=ROOT)
    return subprocess.Popen(
        [sys.executable, "-m", "nmea_quilt.gateway",
         "--input", stream, "--journal", jp, "--pace-ms", str(pace_ms)],
        cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def verify(jp):
    seqs = [ev["seq"] for ev in journal.iter_events(jp)]
    gaps = [i for i, s in enumerate(seqs) if s != i]
    v1, v2 = views.replay(jp), views.replay(jp)
    h1, h2 = views.hashes(v1), views.hashes(v2)
    return gaps, seqs, v1, h1, h1 == h2


def main():
    os.makedirs(BUILD, exist_ok=True)
    stream = os.path.join(BUILD, "stream.nmea")
    meta = nmea_gen.generate(ticks=TICKS, seed=7, p_malformed=0.008, out=stream)
    jp = os.path.join(BUILD, "journal.jsonl")
    if os.path.exists(jp):
        os.remove(jp)

    rnd = random.Random(20260903)
    print("=== CRASH CANARY -- %d x kill -9 on the journal writer ===" % KILLS)
    print("stream: %d ticks, %d lines, %d malformed, %d out-of-order times, %d bytes"
          % (meta["ticks"], meta["lines"], meta["malformed"],
             meta["out_of_order"], meta["bytes"]))
    rows = []
    for k in range(1, KILLS + 1):
        have = journal.scan(jp)["events"]
        target = have + rnd.randrange(25, 320)   # relative: every kill must land mid-write
        p = spawn(stream, jp, PACE_MS)
        t0 = time.time()
        while True:
            sc = journal.scan(jp)
            if sc["events"] >= target or p.poll() is not None:
                break
            time.sleep(0.01)
        alive = p.poll() is None
        if alive:
            os.kill(p.pid, signal.SIGKILL)
        rc = p.wait()
        dt = time.time() - t0
        torn_inj = (k % 2 == 1)
        if torn_inj:
            with open(jp, "ab") as f:
                f.write(b'{"seq":999999,"tor":')   # torn write, no newline
        rec = journal.recover(jp)                   # same recovery the writer runs on startup
        gaps, seqs, v1, h1, idem = verify(jp)
        assert alive, "writer died on its own at kill %d (rc=%s)" % (k, rc)
        assert not gaps, "seq gaps after kill %d: %s" % (k, gaps[:5])
        assert idem, "replay #1 != replay #2 after kill %d" % k
        m = json.loads(v1["meta"])
        rows.append((k, dt, rc, len(seqs) - have, len(seqs), seqs[-1] if seqs else -1,
                     torn_inj, rec["truncated_bytes"], h1))
        print("KILL %02d/%d need=+%3dev @ +%.3fs writer=RUNNING rc=%-4d | journal %4d ev seq 0..%-4d | torn_inj=%-3s healed=%3dB | gaps=0 | replay#1==#2 OK | fix=%s.. depth=%s.. wind=%s.."
              % (k, KILLS, target - have, dt, rc, len(seqs), seqs[-1] if seqs else -1,
                 "yes" if torn_inj else "no", rec["truncated_bytes"],
                 h1["latest-fix"][:8], h1["depth-trace"][:8], h1["wind-rose"][:8]))

    # ---- final run to completion, with a concurrent lock-free reader ----
    p = spawn(stream, jp, 1)
    reads = bad_reads = 0
    while p.poll() is None:
        sc = journal.scan(jp)                      # read-only, lock-free
        if sc["seq_gap"] or sc["bad_complete_line"]:
            bad_reads += 1
        reads += 1
        time.sleep(0.02)
    out, err = p.communicate()
    assert p.returncode == 0, err.decode()[:500]
    stats = json.loads(out.decode().strip().splitlines()[-1])
    assert stats["complete"] and stats["consumed"] == os.path.getsize(stream), stats

    gaps, seqs, v1, h1, idem = verify(jp)
    assert not gaps and idem
    m = json.loads(v1["meta"])
    assert len(seqs) == TICKS and seqs[-1] == TICKS - 1, (len(seqs), seqs[-1])
    assert m["skipped"] == meta["malformed"], (m["skipped"], meta["malformed"])
    assert m["ts_backwards"] == meta["out_of_order"], (m["ts_backwards"], meta["out_of_order"])
    assert m["depth_points"] == 2 * TICKS, m

    print("FINAL: writer completed rc=0 -- %d/%d events, seq 0..%d, consumed %d/%d bytes (%.1f%%)"
          % (len(seqs), TICKS, seqs[-1], stats["consumed"], os.path.getsize(stream),
             100.0 * stats["consumed"] / os.path.getsize(stream)))
    print("FINAL: skipped %d == injected malformed %d | out-of-order times absorbed %d == emitted %d"
          % (m["skipped"], meta["malformed"], m["ts_backwards"], meta["out_of_order"]))
    print("READER: %d lock-free scans during the final write, %d saw gaps/corruption"
          % (reads, bad_reads))
    print()
    print("kill  delay_s   rc  gained  events  seq_last  torn_inj  healed_B  gaps  idempotent")
    for k, dt, rc, gained, n, last, torn_inj, torn_b, _ in rows:
        print("%3d  %7.3f  %-4d  %6d  %6d  %8d  %-8s  %8d     0  OK"
              % (k, dt, rc, gained, n, last, "yes" if torn_inj else "no", torn_b))
    print()
    print("VERDICT: PASS -- %d/%d SIGKILLs survived, no seq gaps, byte-identical view rebuilds every time"
          % (KILLS, KILLS))


if __name__ == "__main__":
    main()
