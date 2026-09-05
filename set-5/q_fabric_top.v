// q_fabric_top.v -- quilt-verilog v1 fabric: NCELL cells + one io node on
// a single ring, registered pipe slices between nodes, one tick scheduler.
// External ingress/egress is the generic streaming contract via q_io_port.
module q_fabric_top #(
    parameter OPW     = 3,
    parameter AIDW    = 4,
    parameter PW      = 16,
    parameter NCELL   = 4,
    parameter EDGES_N = 4,
    parameter EXTID   = 4'hF,
    parameter TPW     = 8
)(
    input  wire               clk,
    input  wire               rst_n,

    // external ingress
    input  wire               i_val,
    output wire               o_rdy,
    input  wire [OPW-1:0]     i_op,
    input  wire [AIDW-1:0]    i_src,
    input  wire [AIDW-1:0]    i_dst,
    input  wire [PW-1:0]      i_a0,
    input  wire [PW-1:0]      i_a1,
    input  wire [PW-1:0]      i_a2,
    input  wire [PW-1:0]      i_dat,

    // external egress
    output wire               o_val,
    input  wire               i_rdy,
    output wire [OPW-1:0]     o_op,
    output wire [AIDW-1:0]    o_src,
    output wire [AIDW-1:0]    o_dst,
    output wire [PW-1:0]      o_a0,
    output wire [PW-1:0]      o_a1,
    output wire [PW-1:0]      o_a2,
    output wire [PW-1:0]      o_dat,

    // status
    output wire               o_ovf
);
    localparam NB = NCELL + 1;   // nodes: cells 0..NCELL-1, io = NCELL

    // flat ring buses: node n output -> pipe n -> node (n+1)%NB input
    wire [NB-1:0]            nv;
    wire [NB-1:0]            nr;
    wire [NB*OPW-1:0]        nop;
    wire [NB*AIDW-1:0]       nsrc, ndst;
    wire [NB*PW-1:0]         na0, na1, na2, ndat;

    wire [NB-1:0]            pv;
    wire [NB-1:0]            pr;
    wire [NB*OPW-1:0]        pop;
    wire [NB*AIDW-1:0]       psrc, pdst;
    wire [NB*PW-1:0]         pa0, pa1, pa2, pdat;

    wire               tick;
    wire [NCELL-1:0]   ovf_cells;

    q_tick_sched #(.TPW(TPW)) u_ts (
        .clk(clk), .rst_n(rst_n), .o_tick(tick)
    );

    genvar g;
    generate
        for (g = 0; g < NB; g = g + 1) begin : nodes
            // upstream pipe index: (g + NB - 1) % NB, constant per node
            if (g == 0) begin : conn0
                q_cell #(
                    .OPW(OPW), .AIDW(AIDW), .PW(PW), .EDGES_N(EDGES_N)
                ) u_cell (
                    .clk(clk), .rst_n(rst_n),
                    .i_por_n(rst_n), .i_bdf_wr(1'b0), .i_bdf_addr(4'd0),
                    .i_bdf_wdata(16'd0),
                    .i_myid(g[AIDW-1:0]), .s_tick(tick), .o_ovf(ovf_cells[g]),
                    .ri_valid(pv[NB-1]), .ri_ready(pr[NB-1]),
                    .ri_op(pop[(NB-1)*OPW +: OPW]),
                    .ri_src(psrc[(NB-1)*AIDW +: AIDW]),
                    .ri_dst(pdst[(NB-1)*AIDW +: AIDW]),
                    .ri_a0(pa0[(NB-1)*PW +: PW]), .ri_a1(pa1[(NB-1)*PW +: PW]),
                    .ri_a2(pa2[(NB-1)*PW +: PW]), .ri_dat(pdat[(NB-1)*PW +: PW]),
                    .ro_valid(nv[g]), .ro_ready(nr[g]),
                    .ro_op(nop[g*OPW +: OPW]),
                    .ro_src(nsrc[g*AIDW +: AIDW]),
                    .ro_dst(ndst[g*AIDW +: AIDW]),
                    .ro_a0(na0[g*PW +: PW]), .ro_a1(na1[g*PW +: PW]),
                    .ro_a2(na2[g*PW +: PW]), .ro_dat(ndat[g*PW +: PW])
                );
            end else if (g < NCELL) begin : connc
                q_cell #(
                    .OPW(OPW), .AIDW(AIDW), .PW(PW), .EDGES_N(EDGES_N)
                ) u_cell (
                    .clk(clk), .rst_n(rst_n),
                    .i_por_n(rst_n), .i_bdf_wr(1'b0), .i_bdf_addr(4'd0),
                    .i_bdf_wdata(16'd0),
                    .i_myid(g[AIDW-1:0]), .s_tick(tick), .o_ovf(ovf_cells[g]),
                    .ri_valid(pv[g-1]), .ri_ready(pr[g-1]),
                    .ri_op(pop[(g-1)*OPW +: OPW]),
                    .ri_src(psrc[(g-1)*AIDW +: AIDW]),
                    .ri_dst(pdst[(g-1)*AIDW +: AIDW]),
                    .ri_a0(pa0[(g-1)*PW +: PW]), .ri_a1(pa1[(g-1)*PW +: PW]),
                    .ri_a2(pa2[(g-1)*PW +: PW]), .ri_dat(pdat[(g-1)*PW +: PW]),
                    .ro_valid(nv[g]), .ro_ready(nr[g]),
                    .ro_op(nop[g*OPW +: OPW]),
                    .ro_src(nsrc[g*AIDW +: AIDW]),
                    .ro_dst(ndst[g*AIDW +: AIDW]),
                    .ro_a0(na0[g*PW +: PW]), .ro_a1(na1[g*PW +: PW]),
                    .ro_a2(na2[g*PW +: PW]), .ro_dat(ndat[g*PW +: PW])
                );
            end else begin : connio
                q_io_port #(
                    .OPW(OPW), .AIDW(AIDW), .PW(PW), .EXTID(EXTID)
                ) u_io (
                    .ri_valid(pv[g-1]), .ri_ready(pr[g-1]),
                    .ri_op(pop[(g-1)*OPW +: OPW]),
                    .ri_src(psrc[(g-1)*AIDW +: AIDW]),
                    .ri_dst(pdst[(g-1)*AIDW +: AIDW]),
                    .ri_a0(pa0[(g-1)*PW +: PW]), .ri_a1(pa1[(g-1)*PW +: PW]),
                    .ri_a2(pa2[(g-1)*PW +: PW]), .ri_dat(pdat[(g-1)*PW +: PW]),
                    .ro_valid(nv[g]), .ro_ready(nr[g]),
                    .ro_op(nop[g*OPW +: OPW]),
                    .ro_src(nsrc[g*AIDW +: AIDW]),
                    .ro_dst(ndst[g*AIDW +: AIDW]),
                    .ro_a0(na0[g*PW +: PW]), .ro_a1(na1[g*PW +: PW]),
                    .ro_a2(na2[g*PW +: PW]), .ro_dat(ndat[g*PW +: PW]),
                    .i_val(i_val), .o_rdy(o_rdy),
                    .i_op(i_op), .i_src(i_src), .i_dst(i_dst),
                    .i_a0(i_a0), .i_a1(i_a1), .i_a2(i_a2), .i_dat(i_dat),
                    .o_val(o_val), .i_rdy(i_rdy),
                    .o_op(o_op), .o_src(o_src), .o_dst(o_dst),
                    .o_a0(o_a0), .o_a1(o_a1), .o_a2(o_a2), .o_dat(o_dat)
                );
            end

            q_flit_pipe #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_pipe (
                .clk(clk), .rst_n(rst_n),
                .s_valid(nv[g]), .s_ready(nr[g]),
                .s_op(nop[g*OPW +: OPW]),
                .s_src(nsrc[g*AIDW +: AIDW]),
                .s_dst(ndst[g*AIDW +: AIDW]),
                .s_a0(na0[g*PW +: PW]), .s_a1(na1[g*PW +: PW]),
                .s_a2(na2[g*PW +: PW]), .s_dat(ndat[g*PW +: PW]),
                .m_valid(pv[g]), .m_ready(pr[g]),
                .m_op(pop[g*OPW +: OPW]),
                .m_src(psrc[g*AIDW +: AIDW]),
                .m_dst(pdst[g*AIDW +: AIDW]),
                .m_a0(pa0[g*PW +: PW]), .m_a1(pa1[g*PW +: PW]),
                .m_a2(pa2[g*PW +: PW]), .m_dat(pdat[g*PW +: PW])
            );
        end
    endgenerate

    assign o_ovf = |ovf_cells;

endmodule
