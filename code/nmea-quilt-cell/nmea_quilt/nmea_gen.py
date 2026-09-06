#!/usr/bin/env python3
"""Realistic NMEA 0183 log generator for shore testing.

Nominal 10 Hz boat: each tick emits
  $PQTLK,<tick>      tick marker (cell-local convention)
  $GPGGA ...         position fix
  $GPGSA ...         active satellites / DOP
  $SDDBT, $SDDPT     depth below transducer
  $WIMWV ...         relative wind
  $IIXDR ... x2      engine RPM + coolant temp
plus deliberate warts: ~p malformed lines per tick and occasional
backwards GGA timestamps. Wall clock is advisory; seq is truth.
"""
import argparse
import json
import math
import os
import random


def checksum(body):
    c = 0
    for ch in body:
        c ^= ord(ch)
    return "%02X" % c


def sentence(body):
    return "$%s*%s" % (body, checksum(body))


def dmtolat(lat):
    d = int(abs(lat))
    m = (abs(lat) - d) * 60.0
    return "%02d%07.4f" % (d, m), "N" if lat >= 0 else "S"


def dmtolon(lon):
    d = int(abs(lon))
    m = (abs(lon) - d) * 60.0
    return "%03d%07.4f" % (d, m), "E" if lon >= 0 else "W"


def hms(t):
    """Seconds-since-midnight -> hhmmss.ss, rounding-safe (no :60.00)."""
    t = round(max(0.0, t), 2)
    h = int(t // 3600)
    m = int((t % 3600) // 60)
    s = t - (h * 3600 + m * 60)
    si = int(s)
    frac = round(s - si, 2)
    if frac >= 1.0:
        si += 1
        frac = 0.0
    if si >= 60:
        si -= 60
        m += 1
    if m >= 60:
        m -= 60
        h += 1
    return "%02d%02d%02d.%02d" % (h % 24, m, si, int(frac * 100))


class Boat:
    """Tiny dead-reckoned state machine: enough realism to exercise the cell."""

    def __init__(self, seed, p_malformed):
        self.r = random.Random(seed)
        self.p_malformed = p_malformed
        self.lat = 59.6025          # Kachemak Bay, AK
        self.lon = -151.4230
        self.hdg = 137.0
        self.clock = 18 * 3600.0    # advisory wall clock, seconds since midnight
        self.last_t = self.clock
        self.depth = 24.0
        self.wind_dir = 214.0
        self.wind_kts = 12.0
        self.rpm = 1500.0
        self.temp = 80.0
        self.sats = [4, 5, 9, 12, 17, 19, 23, 24, 26, 31]
        self.malformed = 0
        self.out_of_order = 0

    def step(self):
        r = self.r
        self.hdg = (self.hdg + r.uniform(-4, 4)) % 360.0
        rad = math.radians(self.hdg)
        self.lat += 0.0000037 * math.cos(rad)     # ~4 m/s, ~8 kn
        self.lon += 0.0000073 * math.sin(rad)
        self.clock += 0.1                          # 10 Hz ticks
        self.depth = 24.0 + 5.0 * math.sin(self.clock / 120.0) + r.uniform(-0.4, 0.4)
        self.wind_dir = (self.wind_dir + r.uniform(-6, 6)) % 360.0
        self.wind_kts = max(4.0, min(23.0, self.wind_kts + r.uniform(-0.8, 0.8)))
        self.rpm = 1500.0 + 220.0 * math.sin(self.clock / 60.0)
        self.temp = 78.0 + (self.rpm - 1500.0) / 90.0 + r.uniform(-0.5, 0.5)

    def gga_time(self):
        """Normally the advisory clock ticks +0.1; ~2% of fixes jump BACKWARDS."""
        r = self.r
        if r.random() < 0.02:
            t = max(0.0, self.last_t - r.uniform(0.1, 0.5))
            self.out_of_order += 1
        else:
            t = self.clock
        self.last_t = t
        return hms(t)

    def malformed_line(self):
        k = self.r.randrange(4)
        if k == 0:
            return "$GPGGA,180001.00,5936.1500,N*00"          # bad checksum
        if k == 1:
            return "$$GARBAGE,not,a,sentence"                  # junk
        if k == 2:
            return "$GPGGA,180001.00,5936"                     # truncated
        return "serial overrrun -- dropped 0x%02x bytes" % self.r.randrange(256)

    def tick(self, n):
        self.step()
        lines = [sentence("PQTLK,%06d" % n)]
        la, ns_ = dmtolat(self.lat)
        lo, ew = dmtolon(self.lon)
        hdop = round(self.r.uniform(0.8, 1.6), 1)
        alt = 3.0 + self.r.uniform(-1.5, 1.5)
        lines.append(sentence(
            "GPGGA,%s,%s,%s,%s,%s,1,%02d,%.1f,%.1f,M,-9.8,M,,"
            % (self.gga_time(), la, ns_, lo, ew, len(self.sats), hdop, alt)))
        sv = [str(x) for x in self.sats] + ["", ""]
        lines.append(sentence(
            "GPGSA,A,3,%s,%.1f,%.1f,%.1f"
            % (",".join(sv), hdop * 1.9, hdop, hdop * 1.6)))
        m = self.depth
        lines.append(sentence("SDDBT,%.1f,%.1f,%.1f" % (m * 3.28084, m, m * 0.546807)))
        lines.append(sentence("SDDPT,%.1f,0.4" % m))
        lines.append(sentence("WIMWV,%.1f,R,%.1f,N,A" % (self.wind_dir, self.wind_kts)))
        lines.append(sentence("IIXDR,A,%.0f,r,ENGINE1" % self.rpm))
        lines.append(sentence("IIXDR,C,%.1f,C,ENGTEMP" % self.temp))
        if self.r.random() < self.p_malformed:
            i = self.r.randrange(1, len(lines))
            lines.insert(i, self.malformed_line())
            self.malformed += 1
        return lines


def generate(ticks, seed, p_malformed, out):
    b = Boat(seed, p_malformed)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    nlines = 0
    with open(out, "w", encoding="ascii") as f:
        for n in range(ticks):
            for ln in b.tick(n):
                f.write(ln + "\n")
                nlines += 1
    meta = {"ticks": ticks, "lines": nlines, "malformed": b.malformed,
            "out_of_order": b.out_of_order, "bytes": os.path.getsize(out),
            "seed": seed, "p_malformed": p_malformed}
    with open(out + ".meta.json", "w") as f:
        json.dump(meta, f, indent=1)
    return meta


def main():
    ap = argparse.ArgumentParser(description="generate a recorded NMEA log")
    ap.add_argument("--ticks", type=int, default=4000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--p-malformed", type=float, default=0.01)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    print(json.dumps(generate(a.ticks, a.seed, a.p_malformed, a.out)))


if __name__ == "__main__":
    main()
