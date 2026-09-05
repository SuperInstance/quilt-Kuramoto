#!/usr/bin/env python3
"""rebuild_scale_tsv.py -- regenerate synth/scale.tsv from the yosys/nextpnr
logs written by synth/scale.sh (round-3 scale sweep). Parsing here, not in
the shell, because nextpnr-ecp5 utilization lines and yosys synth_ecp5 stat
formats differ from the ice40 ones the bash greps assumed.

NOTE on the 12F column: nextpnr-ecp5 --12k places against the LFE5U-25F
die (the 12F is the same silicon binned down; nextpnr does not restrict
it), so nextpnr reports /24288 for both. The honest physical 12F capacity
is 12144 LUTs -- util12f% uses that denominator.
"""
import re, glob, os, json, sys

# cwd-independent (fuzz-found: run from anywhere else the glob missed and
# the script printed a header-only table with exit 0 -- a silent wrong
# answer for a build-report tool)
_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__))))
_SYNTH = _ROOT

rows = []
seen = set()
for ylog in sorted(glob.glob(os.path.join(_SYNTH, "yosys_*_n*.log"))):
        m = re.match(r".*yosys_(\w+)_n(\d+)\.log$", ylog)
        if not m:
            continue
        dev, n = m.group(1), int(m.group(2))
        if (dev, n) in seen:
            continue
        seen.add((dev, n))
        fam_ = "ice40" if dev == "up5k" else "ecp5"
        tag = f"{dev}_n{n}"
        ys = open(ylog, errors="ignore").read()
        # last "Printing statistics" block
        stat = ys[ys.rfind("Printing statistics"):]
        if fam_ == "ice40":
            lut = re.search(r"SB_LUT4\s+(\d+)", stat)
            ff = sum(int(x) for x in re.findall(r"SB_DFF\w*\s+(\d+)", stat))
        else:
            lut = re.search(r"\bLUT4\s+(\d+)", stat)
            lut = int(lut.group(1)) if lut else 0
            ffl = re.findall(r"TRELLIS_FF\s+(\d+)", ys)
            ff = int(ffl[-1]) if ffl else 0
        if fam_ == "ice40":
            lut = int(lut.group(1)) if lut else 0

        plog = os.path.join(_SYNTH, f"pnr_{tag}.log")
        packed = cap = fmax = "-"
        closes = "PNR_FAIL"
        failed = True
        if os.path.exists(plog):
            pl = open(plog, errors="ignore").read()
            if fam_ == "ice40":
                mm = re.search(r"ICESTORM_LC:\s+(\d+)/\s*(\d+)", pl)
            else:
                mm = re.search(r"TRELLIS_COMB:\s+(\d+)/\s*(\d+)", pl)
            failed = ("ERROR" in pl) or ("overfilled" in pl)
            if mm:
                packed, cap = int(mm.group(1)), int(mm.group(2))
                if failed:
                    packed = f"~{packed}est"  # pre-placement estimate
            fm = re.findall(r"Max frequency for clock '.*?':\s+([0-9.]+) MHz \(PASS", pl)
            if fm and not failed and mm:
                fmax = f"{float(fm[-1]):.1f}"
                closes = "PASS"
            elif "ERROR" in pl:
                closes = "PNR_FAIL"
        # honest 12F denominator
        util = util12 = "-"
        if isinstance(packed, int) and cap:
            util = f"{100*packed/cap:.0f}%"
            if dev == "12f":
                util12 = f"{100*packed/12144:.0f}%"
        pk = f"{packed}/{cap}" if not isinstance(packed, str) or packed.startswith("~") else "-"
        rows.append((fam_, dev, n, lut, ff, pk,
                     util, util12, fmax, closes))

if not rows:
    print("rebuild_scale_tsv.py: error: no synth/yosys_*_n*.log found under "
          f"{_SYNTH} -- run synth/scale.sh first", file=sys.stderr)
    sys.exit(1)
print("family\tdevice\tNCELL\tLUT4\tFF\tpacked/cap\tutil%\tutil12f%\tfmax_MHz\tcloses_12MHz")
for r in sorted(rows, key=lambda r: (r[0], r[1], r[2])):
    print("\t".join(map(str, r)))
