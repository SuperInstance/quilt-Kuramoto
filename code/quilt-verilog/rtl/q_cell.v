// q_cell.v -- one quilt cell (quilt-verilog v1): core FSM + dialfile +
// hebbian edge engine array + ring port + elastic ingress/egress buffers.
//
// Structure (deadlock fix, docs/SYNTHESIS.md Q1):
//   ring.ri -> ringport -> [ingress q_flit_pipe] -> core.ci
//   core.lo/lx -> inject mux -> [egress q_flit_pipe] -> ringport.li -> ring.ro
// Without the buffers, a core holding a response (or fire fanout) while an
// inbound flit awaits delivery deadlocks: inject_ok=0 (slot occupied by the
// undelivered hit-flit) and ld_ready=0 (core busy emitting) wait on each
// other. With them, the core always returns to IDLE (ci_ready reasserts),
// delivery frees a slot, and the egress buffer drains into the bubble.
module q_cell #(
    parameter OPW     = 3,
    parameter AIDW    = 4,
    parameter PW      = 16,
    parameter EDGES_N = 4,
    parameter EIW     = 2,
    parameter K       = 8,
    parameter B       = 8,
    parameter AGEW    = 24
)(
    input  wire               clk,
    input  wire               rst_n,
    // boot dial port (pin-fix lane, rtl/q_serfabric_top.v): the dialfile
    // rides the POR domain (i_por_n), NOT the fabric reset, so quf_boot's
    // writes land while the core is FSM-frozen (docs/FPGA-BOOT.md §2
    // reset topology). i_bdf_wr is strobed only in the boot FSM's
    // LOAD/LATCH states, where the core provably cannot emit df_wr
    // (exclusion by construction, not arbitration). Existing users tie
    // i_por_n to the same rst_n and i_bdf_wr to 0: bit-exact v1 behavior.
    input  wire               i_por_n,
    input  wire               i_bdf_wr,
    input  wire [3:0]         i_bdf_addr,
    input  wire [15:0]        i_bdf_wdata,
    input  wire [AIDW-1:0]    i_myid,
    input  wire               s_tick,
    output wire               o_ovf,

    // ring ingress (upstream pipe out)
    input  wire               ri_valid,
    output wire               ri_ready,
    input  wire [OPW-1:0]     ri_op,
    input  wire [AIDW-1:0]    ri_src,
    input  wire [AIDW-1:0]    ri_dst,
    input  wire [PW-1:0]      ri_a0,
    input  wire [PW-1:0]      ri_a1,
    input  wire [PW-1:0]      ri_a2,
    input  wire [PW-1:0]      ri_dat,

    // ring egress (downstream pipe in)
    output wire               ro_valid,
    input  wire               ro_ready,
    output wire [OPW-1:0]     ro_op,
    output wire [AIDW-1:0]    ro_src,
    output wire [AIDW-1:0]    ro_dst,
    output wire [PW-1:0]      ro_a0,
    output wire [PW-1:0]      ro_a1,
    output wire [PW-1:0]      ro_a2,
    output wire [PW-1:0]      ro_dat
);
    // ------------------------------------------------------ core ----
    wire [OPW-1:0]    ci_op;
    wire               ci_valid;
    wire               ci_ready_w;
    wire [AIDW-1:0]    ci_src;
    wire [PW-1:0]      ci_a0, ci_a1, ci_a2, ci_dat;

    wire [OPW-1:0]    lo_op;
    wire               lo_valid;
    wire               lo_grant;
    wire [AIDW-1:0]    lo_dst, lo_src;
    wire [PW-1:0]      lo_a0, lo_a1, lo_a2, lo_dat;

    wire [OPW-1:0]    lx_op;
    wire               lx_valid;
    wire               lx_grant;
    wire [AIDW-1:0]    lx_dst, lx_src;
    wire [PW-1:0]      lx_a0, lx_a1, lx_a2, lx_dat;

    wire [2:0]         hb_cmd;
    wire [EDGES_N-1:0] hb_sel;
    wire [PW-1:0]      hb_base;
    wire [3:0]         hb_gcl;
    wire [PW-1:0]      hb_w;
    wire               hb_done;
    wire [PW-1:0]      w_ftrace;

    wire               df_wr;
    wire [3:0]         df_addr;
    wire [PW-1:0]      df_wdata;
    wire               df_rd;
    wire [PW-1:0]      df_rdata;
    wire               df_rstb;

    // dial fan-in
    wire [3:0]           d_ka;
    wire signed [PW-1:0] d_thresh;
    wire [PW-1:0]        d_refr;
    wire [PW-1:0]        d_hl;
    wire [4:0]           d_p0e;
    wire                 d_mode;

    // v2 feature dial fan-in
    wire [3:0]           d_kle, d_qdw, d_qleak;
    wire [PW-1:0]        d_floor;
    wire                 d_rqen;

    // Reserved dial fan-outs (steal 2 map completeness): readable fabric
    // state via view(2), consumed by post-v1 engines. Suppressed from
    // lint only because nothing in v1 reads them combinationally.
    /* verilator lint_off UNUSEDSIGNAL */
    // ingress buffer m_dst: core has no dst port (routing already done)
    wire [AIDW-1:0]      w_indst;
    /* verilator lint_on UNUSEDSIGNAL */

    /* verilator lint_off UNUSEDSIGNAL */
    wire [PW-1:0]        d_eta_f, d_eta_s, d_cosmin;
    wire [3:0]           d_kf, d_ks;
    // status taps kept unconnected externally; TBs probe hierarchically
    wire                 w_bound;
    wire [AIDW-1:0]      w_cid;
    wire signed [PW-1:0] w_act;
    wire [AIDW-1:0]      w_lddst;
    wire                 w_antic;    // v2: RQH anticipation (status tap)
    /* verilator lint_on UNUSEDSIGNAL */

    q_cell_core #(
        .OPW(OPW), .AIDW(AIDW), .PW(PW),
        .EDGES_N(EDGES_N), .EIW(EIW), .K(K)
    ) u_core (
        .clk(clk), .rst_n(rst_n),
        .ci_op(ci_op), .ci_valid(ci_valid), .ci_ready(ci_ready_w),
        .ci_src(ci_src), .ci_a0(ci_a0), .ci_a1(ci_a1), .ci_a2(ci_a2),
        .ci_dat(ci_dat),
        .lo_op(lo_op), .lo_valid(lo_valid), .lo_ready(lo_grant),
        .lo_dst(lo_dst), .lo_src(lo_src),
        .lo_a0(lo_a0), .lo_a1(lo_a1), .lo_a2(lo_a2), .lo_dat(lo_dat),
        .lx_op(lx_op), .lx_valid(lx_valid), .lx_ready(lx_grant),
        .lx_dst(lx_dst), .lx_src(lx_src),
        .lx_a0(lx_a0), .lx_a1(lx_a1), .lx_a2(lx_a2), .lx_dat(lx_dat),
        .hb_cmd(hb_cmd), .hb_sel(hb_sel), .hb_base(hb_base),
        .hb_gcl(hb_gcl),
        .hb_w(hb_w), .hb_done(hb_done),
        .df_wr(df_wr), .df_addr(df_addr), .df_wdata(df_wdata),
        .df_rd(df_rd), .df_rdata(df_rdata), .df_rstb(df_rstb),
        .d_ka(d_ka), .d_thresh(d_thresh), .d_refr(d_refr),
        .d_kle(d_kle), .d_floor(d_floor),
        .d_qdw(d_qdw), .d_qleak(d_qleak), .d_rqen(d_rqen),
        .s_tick(s_tick),
        .bound(w_bound), .cell_id(w_cid), .act(w_act),
        .o_ftrace(w_ftrace), .o_antic(w_antic)
    );

    // dialfile write mux: core (qm_bind) vs boot port; windows disjoint
    wire        df_wr_g    = df_wr | i_bdf_wr;
    wire [3:0]  df_addr_g  = i_bdf_wr ? i_bdf_addr  : df_addr;
    wire [15:0] df_wdata_g = i_bdf_wr ? i_bdf_wdata : df_wdata;

    q_dialfile #(.DW(PW), .ND(16), .AW(4)) u_df (
        .clk(clk), .rst_n(i_por_n),
        .i_wr(df_wr_g), .i_addr(df_addr_g), .i_wdata(df_wdata_g),
        .i_rd(df_rd), .o_rdata(df_rdata), .o_rstb(df_rstb),
        .o_eta_f(d_eta_f), .o_eta_s(d_eta_s),
        .o_kf(d_kf), .o_ks(d_ks), .o_ka(d_ka),
        .o_thresh(d_thresh), .o_refr(d_refr), .o_cosmin(d_cosmin),
        .o_p0e(d_p0e), .o_mode(d_mode), .o_hl(d_hl),
        .i_probe(w_ftrace),
        .o_kle(d_kle), .o_floor(d_floor),
        .o_qdw(d_qdw), .o_qleak(d_qleak), .o_rqen(d_rqen)
    );

    // ------------------------------------------------ edge engines --
    wire [EDGES_N-1:0] done_vec;
    wire [EDGES_N-1:0] ovf_vec;
    wire [EDGES_N*PW-1:0] w_flat;

    genvar g;
    generate
        for (g = 0; g < EDGES_N; g = g + 1) begin : edges
            q_hebb_edge #(.PW(PW), .K(K), .B(B), .AGEW(AGEW)) u_hebb (
                .clk(clk), .rst_n(rst_n),
                .i_sel(hb_sel[g]), .i_cmd(hb_cmd),
                .i_mode(d_mode), .i_base(hb_base),
                .i_hl(d_hl), .i_p0e(d_p0e), .i_gclass(hb_gcl),
                .o_done(done_vec[g]), .o_w(w_flat[g*PW +: PW]),
                .o_ovf(ovf_vec[g])
            );
        end
    endgenerate

    assign hb_done = |done_vec;
    assign o_ovf   = |ovf_vec;

    // weight mux: selected slot's readout (hb_sel is held through readout).
    // fuzz-fix (backend lane, 2026-08-29, differential-found): was an
    // OR-tree over all engines -- valid only while unselected engines
    // hold o_w==0, but o_w is a REGISTER that keeps its last readout
    // forever, so after any engine was read once, every later view(1)
    // wsum ORed the stale weights in (4x0x2100=0x8400 instead of 0x8200)
    // and effect integration could OR stale bits into a fresh readback.
    // One-hot select, not an OR mask.
    reg [PW-1:0] hb_w_mux;
    integer i;
    always @* begin
        hb_w_mux = {PW{1'b0}};
        for (i = 0; i < EDGES_N; i = i + 1)
            if (hb_sel[i])
                hb_w_mux = w_flat[i*PW +: PW];
    end
    assign hb_w = hb_w_mux;

    // --------------------------------------------- ring port + bufs -
    wire               ld_valid, ld_ready;
    wire [OPW-1:0]     ld_op;
    wire [AIDW-1:0]    ld_src;
    wire [PW-1:0]      ld_a0, ld_a1, ld_a2, ld_dat;

    // ingress buffer: ringport deliver -> core (elastic, breaks the
    // emit-vs-deliver mutual wait)
    q_flit_pipe #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_inbuf (
        .clk(clk), .rst_n(rst_n),
        .s_valid(ld_valid), .s_ready(ld_ready),
        .s_op(ld_op), .s_src(ld_src), .s_dst(w_lddst),
        .s_a0(ld_a0), .s_a1(ld_a1), .s_a2(ld_a2), .s_dat(ld_dat),
        .m_valid(ci_valid), .m_ready(ci_ready_w),
        .m_op(ci_op), .m_src(ci_src), .m_dst(w_indst),
        .m_a0(ci_a0), .m_a1(ci_a1), .m_a2(ci_a2), .m_dat(ci_dat)
    );

    // egress: responses win the mux over fire fanout; both hold until
    // granted by the egress buffer (almost always ready)
    wire               eg_s_valid, eg_s_ready;
    wire [OPW-1:0]     eg_op;
    wire [AIDW-1:0]    eg_src, eg_dst;
    wire [PW-1:0]      eg_a0, eg_a1, eg_a2, eg_dat;

    assign eg_s_valid = lo_valid || lx_valid;
    assign eg_op      = lo_valid ? lo_op  : lx_op;
    assign eg_src     = lo_valid ? lo_src : lx_src;
    assign eg_dst     = lo_valid ? lo_dst : lx_dst;
    assign eg_a0      = lo_valid ? lo_a0  : lx_a0;
    assign eg_a1      = lo_valid ? lo_a1  : lx_a1;
    assign eg_a2      = lo_valid ? lo_a2  : lx_a2;
    assign eg_dat     = lo_valid ? lo_dat : lx_dat;
    assign lo_grant   = lo_valid ? eg_s_ready : 1'b1;
    assign lx_grant   = (!lo_valid) ? eg_s_ready : 1'b0;

    wire               li_valid_w, li_ready_w;
    wire [OPW-1:0]     li_op_w;
    wire [AIDW-1:0]    li_src_w, li_dst_w;
    wire [PW-1:0]      li_a0_w, li_a1_w, li_a2_w, li_dat_w;

    q_flit_pipe #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_egbuf (
        .clk(clk), .rst_n(rst_n),
        .s_valid(eg_s_valid), .s_ready(eg_s_ready),
        .s_op(eg_op), .s_src(eg_src), .s_dst(eg_dst),
        .s_a0(eg_a0), .s_a1(eg_a1), .s_a2(eg_a2), .s_dat(eg_dat),
        .m_valid(li_valid_w), .m_ready(li_ready_w),
        .m_op(li_op_w), .m_src(li_src_w), .m_dst(li_dst_w),
        .m_a0(li_a0_w), .m_a1(li_a1_w), .m_a2(li_a2_w), .m_dat(li_dat_w)
    );

    q_link_ringport #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_rp (
        .i_myid(i_myid),
        .ri_valid(ri_valid), .ri_ready(ri_ready),
        .ri_op(ri_op), .ri_src(ri_src), .ri_dst(ri_dst),
        .ri_a0(ri_a0), .ri_a1(ri_a1), .ri_a2(ri_a2), .ri_dat(ri_dat),
        .ro_valid(ro_valid), .ro_ready(ro_ready),
        .ro_op(ro_op), .ro_src(ro_src), .ro_dst(ro_dst),
        .ro_a0(ro_a0), .ro_a1(ro_a1), .ro_a2(ro_a2), .ro_dat(ro_dat),
        .li_valid(li_valid_w), .li_ready(li_ready_w),
        .li_op(li_op_w), .li_src(li_src_w), .li_dst(li_dst_w),
        .li_a0(li_a0_w), .li_a1(li_a1_w), .li_a2(li_a2_w), .li_dat(li_dat_w),
        .ld_valid(ld_valid), .ld_ready(ld_ready),
        .ld_op(ld_op), .ld_src(ld_src), .ld_dst(w_lddst),
        .ld_a0(ld_a0), .ld_a1(ld_a1), .ld_a2(ld_a2), .ld_dat(ld_dat)
    );

endmodule
