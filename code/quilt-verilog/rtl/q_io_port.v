// q_io_port.v -- streaming IO contract module (quilt-verilog v1, Law 4):
// the boundary where any external stream enters the fabric. Thin and dumb
// by law: a ring node whose id is EXTID, so external ingress is ring inject
// and external egress is ring deliver. Devices plug into the same contract
// cells speak to each other; the fabric cannot tell the difference.
module q_io_port #(
    parameter OPW   = 3,
    parameter AIDW  = 4,
    parameter PW    = 16,
    parameter EXTID = 4'hF
)(
    // ring side
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

    // external ingress (same contract as an intercell link)
    input  wire               i_val,
    output wire               o_rdy,
    input  wire [OPW-1:0]     i_op,
    input  wire [AIDW-1:0]    i_src,
    input  wire [AIDW-1:0]    i_dst,
    input  wire [PW-1:0]      i_a0,
    input  wire [PW-1:0]      i_a1,
    input  wire [PW-1:0]      i_a2,
    input  wire [PW-1:0]      i_dat,

    // external egress: flits delivered to EXTID
    output wire               o_val,
    input  wire               i_rdy,
    output wire [OPW-1:0]     o_op,
    output wire [AIDW-1:0]    o_src,
    output wire [AIDW-1:0]    o_dst,
    output wire [PW-1:0]      o_a0,
    output wire [PW-1:0]      o_a1,
    output wire [PW-1:0]      o_a2,
    output wire [PW-1:0]      o_dat
);
    q_link_ringport #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_rp (
        .i_myid(EXTID[AIDW-1:0]),
        .ri_valid(ri_valid), .ri_ready(ri_ready),
        .ri_op(ri_op), .ri_src(ri_src), .ri_dst(ri_dst),
        .ri_a0(ri_a0), .ri_a1(ri_a1), .ri_a2(ri_a2), .ri_dat(ri_dat),
        .ro_valid(ro_valid), .ro_ready(ro_ready),
        .ro_op(ro_op), .ro_src(ro_src), .ro_dst(ro_dst),
        .ro_a0(ro_a0), .ro_a1(ro_a1), .ro_a2(ro_a2), .ro_dat(ro_dat),
        .li_valid(i_val), .li_ready(o_rdy),
        .li_op(i_op), .li_src(i_src), .li_dst(i_dst),
        .li_a0(i_a0), .li_a1(i_a1), .li_a2(i_a2), .li_dat(i_dat),
        .ld_valid(o_val), .ld_ready(i_rdy),
        .ld_op(o_op), .ld_src(o_src), .ld_dst(o_dst),
        .ld_a0(o_a0), .ld_a1(o_a1), .ld_a2(o_a2), .ld_dat(o_dat)
    );

endmodule
