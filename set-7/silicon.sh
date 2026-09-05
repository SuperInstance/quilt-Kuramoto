#!/bin/bash
# silicon.sh -- SILICON EXPERIMENT LANE (docs/SILICON-EXPERIMENTS.md).
#
# Fresh single-session measurements, every number from THIS run's logs
# (silicon_*.log; nothing copied from the 2026-08-29 sweeps):
#
#   A. yosys synth_ice40 of the canonical PnR-converged top (the Makefile
#      `synth` config: q_fabric_top, K=4 B=4 AGEW=8, NCELL=2, EDGES_N=1,
#      PIPE_EFF=1 -- the exact parameters of the committed HX8K bitstream
#      and the formal conservation proof).
#   B. nextpnr-ice40 place & route of A on the SMALLEST iCE40 UP5K package
#      (sg48). Expected: FIT-FAIL. The failing resource is the headline.
#   C. nextpnr-ice40 of the serialized front-end (q_serfabric_top,
#      SER_BOOT_QUF=0, NCELL=1, same engine params) on the same sg48 --
#      the smallest legal fabric that closes on UP5K, for a real fmax.
#
# Usage: bash synth/silicon.sh   (writes synth/silicon.tsv, ~4 min)
set -u
export PATH=/home/eileen/tools/oss-cad-suite/bin:$PATH
cd "$(dirname "$0")/.."

echo "== A: yosys synth_ice40, canonical k4b4a8e1 (Makefile synth config)"
yosys -s synth/fpga-converged.ice40 > synth/yosys_silicon_k4b4a8e1.log 2>&1 \
  || { echo "YOSYS_FAIL"; exit 1; }
grep -E "SB_LUT4|SB_DFF|SB_RAM|SB_CARRY|ICESTORM_LC" \
  synth/stat_fabric2_k4b4a8e1.txt | head -8

echo "== B: nextpnr-ice40 UP5K sg48, canonical parallel top (expect FAIL)"
nextpnr-ice40 --up5k --package sg48 \
  --json synth/fabric2_k4b4a8e1_ice40.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained \
  --report synth/report_silicon_up5k_k4b4a8e1.json \
  > synth/pnr_silicon_up5k_k4b4a8e1.log 2>&1
B_RC=$?
echo "nextpnr exit: $B_RC"
grep -E "ICESTORM_LC:|SB_IO:|SB_RAM|Error|ERROR|overfilled" \
  synth/pnr_silicon_up5k_k4b4a8e1.log | head -8

echo "== C: serf front-end NCELL=1 on UP5K sg48 (the one that closes)"
RTL="rtl/q_tick_sched.v rtl/q_flit_pipe.v rtl/q_link_ringport.v rtl/q_dialfile.v \
     rtl/q_hebb_edge.v rtl/q_echo_gate.v rtl/q_rqh_bank.v rtl/q_cell_core.v \
     rtl/q_cell.v rtl/q_io_port.v rtl/q_fabric_top.v \
     rtl/q_uf_loader.v rtl/quf_boot.v \
     rtl/q_tick_sched_rt.v rtl/q_boot_gate.v rtl/q_serfabric_top.v"
yosys -p "read_verilog $RTL
chparam -set K 4 -set B 4 -set AGEW 8 q_cell
hierarchy -check -top q_serfabric_top -chparam NCELL 1 -chparam EDGES_N 1 -chparam SER_BOOT_QUF 0
synth_ice40 -top q_serfabric_top -abc2 -json synth/silicon_up5k_serf_n1.json" \
  > synth/yosys_silicon_up5k_serf_n1.log 2>&1 \
  || { echo "YOSYS_FAIL_C"; exit 1; }
nextpnr-ice40 --up5k --package sg48 \
  --json synth/silicon_up5k_serf_n1.json --freq 12 \
  --timing-allow-fail --pcf-allow-unconstrained \
  --asc synth/silicon_up5k_serf_n1.asc \
  --report synth/report_silicon_up5k_serf_n1.json \
  > synth/pnr_silicon_up5k_serf_n1.log 2>&1
C_RC=$?
echo "nextpnr exit: $C_RC"
grep -E "ICESTORM_LC:|SB_IO:|SB_RAM40" synth/pnr_silicon_up5k_serf_n1.log | head -4
grep -E "Max frequency" synth/pnr_silicon_up5k_serf_n1.log | tail -1

# ---------------- summary tsv (this session's numbers) ----------------
lut=$(grep -oP 'SB_LUT4\s+\K\d+' synth/stat_fabric2_k4b4a8e1.txt | head -1)
ff=$(grep -oP 'SB_DFF\w*\s+\K\d+' synth/stat_fabric2_k4b4a8e1.txt | paste -sd+ | bc)
bram=$(grep -oP 'SB_RAM40_\S*\s+(\d+)' synth/stat_fabric2_k4b4a8e1.txt | head -1)
lut_c=$(grep -oP 'SB_LUT4\s+\K\d+' synth/yosys_silicon_up5k_serf_n1.log | head -1)
ff_c=$(grep -oP 'SB_DFF\w*\s+\K\d+' synth/yosys_silicon_up5k_serf_n1.log | paste -sd+ | bc)
lc_c=$(grep -oP 'ICESTORM_LC:\s+\K[0-9]+' synth/pnr_silicon_up5k_serf_n1.log | head -1)
io_c=$(grep -oP 'SB_IO:\s+\K[0-9]+' synth/pnr_silicon_up5k_serf_n1.log | head -1)
fm_c=$(python3 -c "import json;r=json.load(open('synth/report_silicon_up5k_serf_n1.json'));print(max(v['achieved'] for v in r['fmax'].values()))" 2>/dev/null || echo "?")
printf "build\tLUT4\tFF\tLC\tIO\tfmax_MHz\tverdict\n" > synth/silicon.tsv
printf "canonical k4b4a8e1 NCELL=2 (yosys)\t%s\t%s\t-\t-\t-\tUP5K sg48 PnR exit %s\n" \
  "$lut" "$ff" "$B_RC" >> synth/silicon.tsv
printf "serf NCELL=1 sg48\t%s\t%s\t%s/5280\t%s\t%s\t%s\n" \
  "$lut_c" "$ff_c" "$lc_c" "$io_c" "$fm_c" \
  "$( [ "$C_RC" = 0 ] && echo PNR_PASS || echo PNR_FAIL )" >> synth/silicon.tsv
echo "== summary:"; cat synth/silicon.tsv
