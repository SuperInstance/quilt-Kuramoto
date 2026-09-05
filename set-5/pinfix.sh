#!/bin/bash
# pinfix.sh -- PIN-FIX LANE scale re-measure: the serialized fabric
# front-end (rtl/q_serfabric_top.v) through nextpnr-ice40 on UP5K sg48
# and HX8K ct256, at the formal-proof engine params (k4b4a8e1), against
# the parallel q_fabric_top baseline (synth/scale.tsv rows + the
# committed before-logs). The deliverable: IO before/after and max cells
# closing 12 MHz per device with the narrow front-end.
#
# Rows measured here (tag scheme: <dev>_ser{f|q}_n<N>):
#   serf = SER_BOOT_QUF=0  flit-mode front-end (q_boot_gate release word;
#         QUF parsed host-side; dials stream as qm_bind flits)
#   serq = SER_BOOT_QUF=1  on-chip QUF boot (one quf_boot per cell, §7
#         broadcast; epoch latch + dial rows land over the narrow port)
# Results -> synth/scale-pinfix.tsv (+ per-run logs, same names as tags).
set -u
export PATH=/home/eileen/tools/oss-cad-suite/bin:$PATH
cd "$(dirname "$0")/.."
OUT=synth/scale-pinfix.tsv
echo -e "family\tdevice\tfront_end\tNCELL\tLUT4\tFF\tLC_used\tLC_cap\tSB_IO_used\tSB_IO_cap\tutil%\tfmax_MHz\tcloses_12MHz" > $OUT

RTL="rtl/q_tick_sched.v rtl/q_flit_pipe.v rtl/q_link_ringport.v rtl/q_dialfile.v \
     rtl/q_hebb_edge.v rtl/q_echo_gate.v rtl/q_rqh_bank.v rtl/q_cell_core.v \
     rtl/q_cell.v rtl/q_io_port.v rtl/q_fabric_top.v \
     rtl/q_uf_loader.v rtl/quf_boot.v \
     rtl/q_tick_sched_rt.v rtl/q_boot_gate.v rtl/q_serfabric_top.v"

one() { # family device pnr_args ncell bootquf tag_prefix
  local fam=$1 dev=$2 pargs=$3 N=$4 quf=$5 pfx=$6 tag
  tag="${pfx}_n${N}"
  # resume support: a finished report skips the (slow) synth+PnR
  if [ -f synth/report_${tag}.json ] && grep -q "Max frequency" synth/pnr_${tag}.log 2>/dev/null; then
    lut=$(grep -oP 'SB_LUT4\s+\K\d+' synth/yosys_${tag}.log | head -1)
    ff=$(grep -oP 'SB_DFF\w*\s+\K\d+' synth/yosys_${tag}.log | paste -sd+ | bc)
    python3 - "$fam" "$dev" "$N" "$quf" "$lut" "$ff" "synth/report_${tag}.json" "$OUT" <<'PY'
import json, sys
fam, dev, n, quf, lut, ff, rep, out = sys.argv[1:9]
r = json.load(open(rep))
fm = max(v['achieved'] for v in r['fmax'].values())
u = r['utilization']
iou, ioc = u['SB_IO']['used'], u['SB_IO']['available']
lc = 'ICESTORM_LC' if 'ICESTORM_LC' in u else 'TRELLIS_COMB'
lcu, lcc = u[lc]['used'], u[lc]['available']
fe = 'serq' if quf == '1' else 'serf'
with open(out, 'a') as f:
    f.write(f"{fam}\t{dev}\t{fe}\t{n}\t{lut}\t{ff}\t{lcu}\t{lcc}\t{iou}\t{ioc}\t"
            f"{round(100*lcu/lcc,1)}%\t{fm}\t{'PASS' if fm >= 12 else 'FAIL'}\n")
PY
    return
  fi
  local ys="read_verilog $RTL
chparam -set K 4 -set B 4 -set AGEW 8 q_cell
hierarchy -check -top q_serfabric_top -chparam NCELL $N -chparam EDGES_N 1 -chparam SER_BOOT_QUF $quf
synth_$fam -top q_serfabric_top -abc2 -json synth/${tag}.json"
  if ! yosys -p "$ys" > synth/yosys_${tag}.log 2>&1; then
    echo -e "$fam\t$dev\t$( [ $quf = 1 ] && echo serq || echo serf )\t$N\tSYNTH_FAIL" | tee -a $OUT; return
  fi
  local lut ff
  lut=$(grep -oP 'SB_LUT4\s+\K\d+' synth/yosys_${tag}.log | head -1)
  ff=$(grep -oP 'SB_DFF\w*\s+\K\d+' synth/yosys_${tag}.log | paste -sd+ | bc)
  if nextpnr-$fam $pargs --json synth/${tag}.json --freq 12 --timing-allow-fail \
       --report synth/report_${tag}.json > synth/pnr_${tag}.log 2>&1; then
    python3 - "$fam" "$dev" "$N" "$quf" "$lut" "$ff" "synth/report_${tag}.json" "$OUT" <<'PY'
import json, sys
fam, dev, n, quf, lut, ff, rep, out = sys.argv[1:9]
r = json.load(open(rep))
fm = max(v['achieved'] for v in r['fmax'].values())
io_u = r['utilization']['SB_IO']['used']; io_c = r['utilization']['SB_IO']['available']
lc = None
for k in ('ICESTORM_LC', 'TRELLIS_COMB'):
    if k in r['utilization']:
        lc = k; break
lcu = r['utilization'][lc]['used']; lcc = r['utilization'][lc]['available']
fe = 'serq' if quf == '1' else 'serf'
with open(out, 'a') as f:
    f.write(f"{fam}\t{dev}\t{fe}\t{n}\t{lut}\t{ff}\t{lcu}\t{lcc}\t{io_u}\t{io_c}\t"
            f"{round(100*lcu/lcc,1)}%\t{fm}\t{'PASS' if fm >= 12 else 'FAIL'}\n")
PY
    grep -E "Max frequency" synth/pnr_${tag}.log | tail -1 | sed "s/^Info: /RESULT $tag /"
  else
    local why="PNR_FAIL"
    grep -q "overfilled type" synth/pnr_${tag}.log && why="OVERFULL"
    local io_line
    io_line=$(grep -oP 'SB_IO:\s+\K[0-9]+/\s*[0-9]+' synth/pnr_${tag}.log | head -1 | tr -d ' ')
    echo -e "$fam\t$dev\t$( [ $quf = 1 ] && echo serq || echo serf )\t$N\t$lut\t$ff\t-\t-\t${io_line:-?}\t-\t-\t-\t$why" | tee -a $OUT
  fi
}

# ---------------- iCE40 UP5K (sg48, 96 IO): the IO-gated device -------
one ice40 up5k "--up5k --package sg48" 1 0 up5k_serf
one ice40 up5k "--up5k --package sg48" 1 1 up5k_serq
one ice40 up5k "--up5k --package sg48" 2 0 up5k_serf

# ---------------- iCE40 HX8K (ct256, 256 IO): re-measure --------------
one ice40 hx8k "--hx8k --package ct256" 1 0 hx8k_serf
one ice40 hx8k "--hx8k --package ct256" 1 1 hx8k_serq
one ice40 hx8k "--hx8k --package ct256" 2 0 hx8k_serf

echo "pinfix sweep complete -> $OUT"
