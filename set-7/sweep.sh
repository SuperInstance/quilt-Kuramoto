#!/bin/bash
# synth/sweep.sh -- W-parameterization sweep: how the fabric's silicon
# footprint scales with the weight-state knobs (K ladder buckets, B bits
# per bucket, AGEW hyperbola age width, E edges per cell; NCELL fixed at 2
# by the topology requirement). Synthesis only (fast); PnR is run
# separately for the chosen points. Results -> synth/sweep.tsv
set -u
export PATH=/home/eileen/tools/oss-cad-suite/bin:$PATH
cd "$(dirname "$0")/.."
OUT=synth/sweep.tsv
echo -e "config\tK\tB\tAGEW\tE\tNCELL\tLUT4\tFF\tCARRY" > $OUT

run() { # name K B AGEW E NCELL
  local name=$1 K=$2 B=$3 A=$4 E=$5 N=$6
  local ys
  ys="read_verilog rtl/q_tick_sched.v rtl/q_flit_pipe.v rtl/q_link_ringport.v rtl/q_dialfile.v rtl/q_hebb_edge.v rtl/q_echo_gate.v rtl/q_rqh_bank.v rtl/q_cell_core.v rtl/q_cell.v rtl/q_io_port.v rtl/q_fabric_top.v
chparam -set K $K -set B $B -set AGEW $A q_cell
hierarchy -check -top q_fabric_top -chparam NCELL $N -chparam EDGES_N $E
synth_ice40 -top q_fabric_top -abc2"
  local r
  r=$(yosys -p "$ys" 2>/dev/null | sed -n '/Printing statistics/,$p')
  local l f c
  l=$(echo "$r" | grep -oP 'SB_LUT4\s+\K\d+' | head -1)
  f=$(echo "$r" | grep -oP 'SB_DFF\w*\s+\K\d+' | paste -sd+ | bc)
  c=$(echo "$r" | grep -oP 'SB_CARRY\s+\K\d+' | head -1)
  echo -e "$name\t$K\t$B\t$A\t$E\t$N\t${l:-?}\t${f:-?}\t${c:-?}" | tee -a $OUT
}

#                name        K B AGE E N
run full         8  8   24 4 2   # fabric default = the wall point
run e2           8  8   24 2 2   # engine array halved
run e2k4         4  8   24 2 2
run k4           4  8   24 4 2
run k4a12        4  8   12 4 2
run k4b4a12e2    4  4   12 2 2
run k4b4a8e1     4  4    8 1 2   # formal-proof params on the real top
run k8a12        8  8   12 4 2   # AGEW alone
run n4k4e2       4  8   24 2 4   # cell-count scaling probe
