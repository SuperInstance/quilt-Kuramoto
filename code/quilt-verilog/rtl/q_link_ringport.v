// q_link_ringport.v -- one ring node: deliver / transit / inject.
// Pure comb (opencode RTL-SKETCH §1, reused per scorecard steal 3 advice:
// "skeletons compile clean, correct ready logic"). Registered slices
// (q_flit_pipe) are inserted by fabric_top for timing; ports identical.
// Single-ring liveness: transit never blocks unless downstream blocks;
// delivery consumes the slot and frees a bubble for injection. A hit
// parked at ld (full ingress) does NOT block injection (F3 fix): a hit
// never claims ro (its exit is ld), so li may use ro while the hit waits.
module q_link_ringport #(
    parameter OPW  = 3,
    parameter AIDW = 4,
    parameter PW   = 16
)(
    input  wire [AIDW-1:0]    i_myid,

    input  wire               ri_valid,
    output wire               ri_ready,
    input  wire [OPW-1:0]     ri_op,
    input  wire [AIDW-1:0]    ri_src,
    input  wire [AIDW-1:0]    ri_dst,
    input  wire [PW-1:0]      ri_a0,
    input  wire [PW-1:0]      ri_a1,
    input  wire [PW-1:0]      ri_a2,
    input  wire [PW-1:0]      ri_dat,

    output wire               ro_valid,
    input  wire               ro_ready,
    output wire [OPW-1:0]     ro_op,
    output wire [AIDW-1:0]    ro_src,
    output wire [AIDW-1:0]    ro_dst,
    output wire [PW-1:0]      ro_a0,
    output wire [PW-1:0]      ro_a1,
    output wire [PW-1:0]      ro_a2,
    output wire [PW-1:0]      ro_dat,

    input  wire               li_valid,
    output wire               li_ready,
    input  wire [OPW-1:0]     li_op,
    input  wire [AIDW-1:0]    li_src,
    input  wire [AIDW-1:0]    li_dst,
    input  wire [PW-1:0]      li_a0,
    input  wire [PW-1:0]      li_a1,
    input  wire [PW-1:0]      li_a2,
    input  wire [PW-1:0]      li_dat,

    output wire               ld_valid,
    input  wire               ld_ready,
    output wire [OPW-1:0]     ld_op,
    output wire [AIDW-1:0]    ld_src,
    output wire [AIDW-1:0]    ld_dst,
    output wire [PW-1:0]      ld_a0,
    output wire [PW-1:0]      ld_a1,
    output wire [PW-1:0]      ld_a2,
    output wire [PW-1:0]      ld_dat
);
    wire hit       = ri_valid && (ri_dst == i_myid);
    // F3 escape-lane fix (silicon lane, 2026-08-30, root-caused by
    // sim/vlt/tb_quiesce_repro.cpp: saturation self-deadlock -- a cell in
    // ST_FIRE holds ci_ready=0, its inbuf fills, a flit addressed to the
    // cell parks at its OWN ringport (ld_ready=0), and the old
    // `inject_ok = !ri_valid || consumed` then held the cell's fire flits
    // out of the ring forever: its own blocked delivery gated its own
    // injection -- a closed wait cycle inside ONE cell, no second cell
    // required; everything behind the parked hit froze too (measured:
    // occ=14 stuck through 500k cycles, ledger intact). Fix: a hit flit
    // NEVER uses ro -- delivered hits exit via ld, and a blocked hit
    // simply waits in the upstream slice (ri_ready=0, no clone: the F2
    // clone was transit claiming ro while ri was held; injection popping
    // its own li on acceptance keeps push/pop paired). So li may use ro
    // whenever the input flit is a hit or absent; only a transit (a flit
    // that must claim ro to move) blocks injection. Strictly simpler
    // boolean than the old consumed form. Overtaking is limited to this
    // node's injections passing flits addressed to this node; ring order
    // among transit flits is unchanged (per-flow order preserved; the
    // streams that reorder were never in a delivered-order contract --
    // each op is independent and ack-correlated by a2).
    wire inject_ok = !ri_valid || hit;
    // clone fix (silicon lane, 2026-08-30, found by sim/vlt/tb_scale_vlt.cpp
    // ENTRY-IDENTITY trap + per-pipe push/pop witnesses): `transit` used
    // to include hit-but-not-consumed flits, so a delivery blocked by a
    // full ingress buffer drove ro_valid=1 while ri_ready=0 held the
    // original in the upstream slice -- the ringport PUSHED A COPY
    // downstream every stalled cycle (measured: +1 phantom ring
    // entry/cycle at a full inbuf; the ring fills with clones and the
    // ledger identity breaks by exactly the clone count). The unit
    // contract (tb_link_ringport case 2: "stalls ring, no ro progress")
    // is HOLD: a blocked hit occupies the slice; pass-through is
    // non-hit only, so push and pop stay paired everywhere.
    wire transit   = ri_valid && !hit;

    assign ld_valid = hit;
    assign ld_op    = ri_op;
    assign ld_src   = ri_src;
    assign ld_dst   = ri_dst;
    assign ld_a0    = ri_a0;
    assign ld_a1    = ri_a1;
    assign ld_a2    = ri_a2;
    assign ld_dat   = ri_dat;

    assign ro_valid = transit || (li_valid && inject_ok);
    assign ro_op    = transit ? ri_op  : li_op;
    assign ro_src   = transit ? ri_src : li_src;
    assign ro_dst   = transit ? ri_dst : li_dst;
    assign ro_a0    = transit ? ri_a0  : li_a0;
    assign ro_a1    = transit ? ri_a1  : li_a1;
    assign ro_a2    = transit ? ri_a2  : li_a2;
    assign ro_dat   = transit ? ri_dat : li_dat;

    // a hit pops via ld (delivered) or holds its upstream slice (blocked);
    // pass-through pops when downstream takes it
    assign ri_ready = hit ? ld_ready : ro_ready;
    assign li_ready = inject_ok && ro_ready;

endmodule
