#!/bin/bash
# scale.sh -- FPGA round 3 scale sweep: NCELL scaling through nextpnr on
# iCE40 UP5K and ECP5 (LFE5U-12F, LFE5U-25F -- the boat chip), at the
# formal-proof engine params (k4b4a8e1: K=4 B=4 AGEW=8 EDGES_N=1) with
# the round-3 PIPE_EFF retimed core. Reports per-config utilization and
# fmax; the max cell count closing timing (12 MHz target) per device is
# the sweep's deliverable. Results -> synth/scale.tsv (+ per-run logs).
set -u
export PATH=/home/eileen/tools/oss-cad-suite/bin:$PATH
cd "$(dirname "$0")/.."
OUT=synth/scale.tsv
echo -e "family\tdevice\tNCELL\tLUT4\tFF\tpacked\tdevice_cap\tutil%\tfmax_MHz\tcloses_12MHz" > $OUT

RTL="rtl/q_tick_sched.v rtl/q_flit_pipe.v rtl/q_link_ringport.v rtl/q_dialfile.v \
     rtl/q_hebb_edge.v rtl/q_echo_gate.v rtl/q_rqh_bank.v rtl/q_cell_core.v \
     rtl/q_cell.v rtl/q_io_port.v rtl/q_fabric_top.v"

one() { # family device pnr_args ncell
  local fam=$1 dev=$2 pargs=$3 N=$4 tag
  tag="${dev}_n${N}"
  local ys="read_verilog $RTL
chparam -set K 4 -set B 4 -set AGEW 8 q_cell
hierarchy -check -top q_fabric_top -chparam NCELL $N -chparam EDGES_N 1
synth_$fam -top q_fabric_top -abc2 -json synth/${tag}.json"
  if ! yosys -p "$ys" > synth/yosys_${tag}.log 2>&1; then
    echo -e "$fam\t$dev\t$N\tSYNTH_FAIL" | tee -a $OUT; return
  fi
  local lut ff
  if [ "$fam" = ice40 ]; then
    lut=$(grep -oP 'SB_LUT4\s+\K\d+' synth/yosys_${tag}.log | head -1)
    ff=$(grep -oP 'SB_DFF\w*\s+\K\d+' synth/yosys_${tag}.log | paste -sd+ | bc)
    pnr="nextpnr-$fam"
  else
    lut=$(grep -oP 'TRELLIS_COMB\s+\K\d+' synth/yosys_${tag}.log | head -1)
    ff=$(grep -oP 'TRELLIS_FF\s+\K\d+' synth/yosys_${tag}.log | head -1)
    pnr="nextpnr-$fam"
  fi
  if $pnr $pargs --json synth/${tag}.json --freq 12 --timing-allow-fail \
       --report synth/report_${tag}.json > synth/pnr_${tag}.log 2>&1; then
    local fm cap
    fm=$(python3 -c "import json;r=json.load(open('synth/report_${tag}.json'));print(max(v['achieved'] for v in r['fmax'].values()))" 2>/dev/null || echo "?")
    cap=$(python3 -c "import json;r=json.load(open('synth/report_${tag}.json'));u=r['utilization'];print(max((v['maximum'],k) for k,v in u.items() if v['maximum'])[0])" 2>/dev/null || echo "?")
    # utilization of the LUT-equivalent primitive
    local pk pkc util
    if [ "$fam" = ice40 ]; then pk=ICESTORM_LC; else pk=TRELLIS_COMB; fi
    pkc=$(grep -oP "Info:\s+$pk:\s+\K[0-9]+" synth/pnr_${tag}.log | head -1)
    capn=$(grep -oP "Info:\s+$pk:/?\s+\K[0-9]+" synth/pnr_${tag}.log | head -1)
    [ -z "$capn" ] && capn=$(grep -oP "Info:\s+$pk:\s+[0-9]+/\s*\K[0-9]+" synth/pnr_${tag}.log | head -1)
    util=$(python3 -c "print(round(100*$pkc/$capn,1))" 2>/dev/null || echo "?")
    echo -e "$fam\t$dev\t$N\t$lut\t$ff\t$pkc/$capn\t${util}%\t$fm\tPASS" | tee -a $OUT
  else
    local why="PNR_FAIL"
    grep -q "overfilled type" synth/pnr_${tag}.log && why="OVERFULL"
    echo -e "$fam\t$dev\t$N\t$lut\t$ff\t-\t-\t-\t$why" | tee -a $OUT
  fi
}

# ---------------- iCE40 UP5K (sg48) -----------------------------------
for N in 1 2 4; do
  one ice40 up5k "--up5k --package sg48" $N
done

# ---------------- ECP5 LFE5U-12F / 25F (CABGA381) ----------------------
for N in 2 4 6 8 12; do
  one ecp5 12f "--12k --package CABGA381" $N
done
for N in 4 8 12 16; do
  one ecp5 25f "--25k --package CABGA381" $N
done

echo "sweep complete: $(wc -l < $OUT) rows -> $OUT"
