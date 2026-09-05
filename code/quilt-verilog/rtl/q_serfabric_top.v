// q_serfabric_top.v -- SERIALIZED FABRIC FRONT-END (quilt-verilog v2.1,
// pin-fix lane). The fabric behind the narrow port.
//
// Why this exists (the measured wall, synth/pnr_up5k_n1.log): the
// parallel q_fabric_top exposes the whole 75-bit flit contract twice --
// 77 ingress pins + 77 egress pins + 3 control = 157 IO -- which does
// not fit a 48-pin package (UP5K sg48: 96 IO, 157/96 = 163% overfull at
// ONE cell, LCs only 74% used). The cells were IO-gated, not LUT-gated.
// This front-end moves the whole contract onto one 8-bit byte port:
// 157 IO -> 37 IO (measured in synth/pnr_*ser*.log), trading wire width
// for time exactly like quf_boot trades it for the QUF container.
//
// The narrow port carries three phases over the same 8 pins (the quf_boot
// loader FSM discipline: byte-stream, fail-static, latch-once epoch):
//
//   BOOT  bytes are a QUF container (SER_BOOT_QUF=1: one quf_boot per
//         cell on the SAME broadcast stream, each pinned to its cell --
//         docs/FPGA-BOOT.md §7 multi-cell boot; dial rows land in the
//         cells' dialfiles through the boot dial port while the fabric
//         is FSM-frozen, epoch tpw latched once at release) or a 2-byte
//         release word 0x51 0x46 (SER_BOOT_QUF=0: the parser does not
//         fit beside even one cell on UP5K -- 1488 LUT loader + 3958 LC
//         fabric > 5280 -- so the QUF parse runs host-side and cell
//         configuration streams as qm_bind flits, the documented
//         runtime dial path; q_boot_gate keeps the fail-static +
//         latch-once discipline without the parser).
//   RUN   bytes are serialized flits, 10 bytes per flit. The padded
//         80-bit word is transmitted MOST-significant byte first, so the
//         flit header rides byte 0 and the pad rides byte 9:
//           word[79:0] = {op[2:0], src[3:0], dst[3:0], a0, a1, a2, dat,
//                          pad[4:0]}
//           byte[0] = word[79:72] (header)  ...  byte[9] = word[7:0]
//         (field boundaries cross byte edges -- the accumulator shifts
//         left, so slices are fixed bit positions of the accumulated
//         word, documented once here). The egress serializer emits the
//         same frame with pad bits driven zero (the differential TB
//         tb/tb_serfabric.v checks them).
//
// Cost discipline (the honest numbers, synth/scale-pinfix.tsv): the
// deserializer is one 80-bit accumulator + a 4-bit counter (a full flit
// must exist somewhere before the io node sees it); the egress side is
// a 75-bit capture register + byte mux + counter -- e_rdy depends only
// on local state (skid discipline, no comb ready chain into the ring).
// ~200 LC at NCELL=1. Throughput: one flit per >=10 accepted byte
// cycles each way; the ring's own elasticity absorbs the rest.
//
// Ring structure: mirrors q_fabric_top EXACTLY (same generate, same
// pipes, same io node) so the differential TB is comparing like with
// like; the only deltas are (a) cell reset topology per quf_boot §2:
// cores/pipes/tick on the BOOT reset (o_rst_n), dialfiles on POR
// (i_por_n) so boot dial writes land under fabric reset, (b) the tick
// scheduler is q_tick_sched_rt (runtime period from the latched epoch,
// cycle-exact with q_tick_sched at the same exponent), (c) the external
// ingress/egress contract lives behind the serdes instead of on pins.
//
// Edge/route loader writes have NO sink in v1 (q_hebb_edge engines have
// no load port; consumed-but-not-restored per q_uf_loader's header) --
// they are left unconnected here, pruned by synthesis, and probed
// hierarchically by the TB. Nothing pretends otherwise.
//
// Pure Verilog-2005, no vendor primitives.
module q_serfabric_top #(
    parameter OPW         = 3,
    parameter AIDW        = 4,
    parameter PW          = 16,
    parameter NCELL       = 2,
    parameter EDGES_N     = 4,
    parameter EXTID       = 4'hF,
    parameter SER_BOOT_QUF = 1,  // 1: on-chip quf_boot per cell (QUF boot)
                                 // 0: q_boot_gate commissioning word (host
                                 //    parses QUF; dials stream as binds)
    parameter TPW0        = 6    // SER_BOOT_QUF=0 epoch exponent (latch-once)
)(
    input  wire               clk,
    input  wire               rst_n,      // POR (this module + dialfiles)

    // ---------------- the narrow port (37 IO total) ------------------
    // shared byte ingress: QUF container / release word, then flits
    input  wire               i_sval,
    output wire               o_srdy,
    input  wire [7:0]         i_sbyte,
    input  wire               i_eod,      // transport end-of-stream (boot)

    // serialized egress: 10 bytes per flit, same frame as ingress
    output wire               o_stx_val,
    input  wire               i_strdy,
    output wire [7:0]         o_stx,

    // boot/run status (quf_boot contract)
    output wire               o_boot_ok,  // 1-cycle pulse entering RUN
    output wire               o_epoch,    // 1-cycle pulse entering RUN
    output wire [2:0]         o_state,    // quf_boot state encoding
    output wire [7:0]         o_err,      // sticky boot error
    output wire               o_ovf       // any-cell engine overflow
);
    localparam NB = NCELL + 1;   // nodes: cells 0..NCELL-1, io = NCELL

    // ------------------------------------------------ boot control --
    wire [2:0] boot_state;
    wire [7:0] boot_err;
    wire       boot_ok, boot_epoch, boot_brdy;
    wire [4:0] boot_tpw;
    wire       boot_rst_n;       // THE fabric reset (cores/pipes/tick)
    wire       run = (boot_state == 3'd5);

    // per-cell boot dial fan-out (driven by whichever boot lane is built)
    wire [NCELL-1:0]    bdf_wr;
    wire [NCELL*4-1:0]  bdf_addr;
    wire [NCELL*16-1:0] bdf_wdata;

    generate
    if (SER_BOOT_QUF) begin : qufmode
        // §7 broadcast: N loaders, one stream, i_mycell selects the row.
        // All instances see the same bytes in the same cycles, so their
        // FSMs run in lockstep; cell 0's control outputs drive the
        // fabric (identical by determinism -- same code, same inputs).
        wire [NCELL*3-1:0]  b_state;
        wire [NCELL*5-1:0]  b_tpw;
        wire [NCELL*8-1:0]  b_err;
        wire [NCELL-1:0]    b_rst, b_ok, b_ep, b_brdy;
        genvar b;
        for (b = 0; b < NCELL; b = b + 1) begin : boots
            quf_boot #(.AIDW(AIDW)) u_boot (
                .clk(clk), .rst_n(rst_n),
                .i_bval(i_sval), .o_brdy(b_brdy[b]),
                .i_byte(i_sbyte), .i_eod(i_eod),
                .i_mycell(b[AIDW-1:0]),
                // runtime dial writes live on the ring as qm_bind flits
                .i_qm_wr(1'b0), .i_qm_addr(4'd0), .i_qm_wdata(16'd0),
                .o_df_wr(bdf_wr[b]),
                .o_df_addr(bdf_addr[b*4 +: 4]),
                .o_df_wdata(bdf_wdata[b*16 +: 16]),
                // v1 engines have no load port: consumed, not restored
                .o_edge_wr(), .o_edge_addr(), .o_edge_data(),
                .o_route_wr(), .o_route_dst(), .o_route_via(),
                .o_tpw(b_tpw[b*5 +: 5]), .o_epoch(b_ep[b]),
                .o_rst_n(b_rst[b]), .o_boot_ok(b_ok[b]),
                .o_state(b_state[b*3 +: 3]), .o_err(b_err[b*8 +: 8])
            );
        end
        assign boot_brdy  = b_brdy[0];
        assign boot_rst_n = b_rst[0];
        assign boot_state  = b_state[2:0];
        assign boot_ok     = b_ok[0];
        assign boot_epoch  = b_ep[0];
        assign boot_err    = b_err[7:0];
        assign boot_tpw    = b_tpw[4:0];
    end else begin : gatemode
        localparam [4:0] TPW0Q = TPW0;
        q_boot_gate #(.TPW0(TPW0Q)) u_gate (
            .clk(clk), .rst_n(rst_n),
            .i_bval(i_sval), .o_brdy(boot_brdy), .i_byte(i_sbyte),
            .i_eod(i_eod),
            .o_tpw(boot_tpw), .o_epoch(boot_epoch), .o_rst_n(boot_rst_n),
            .o_boot_ok(boot_ok), .o_state(boot_state), .o_err(boot_err)
        );
        assign bdf_wr   = {NCELL{1'b0}};
        assign bdf_addr = {(NCELL*4){1'b0}};
        assign bdf_wdata = {(NCELL*16){1'b0}};
    end
    endgenerate

    // ---------------- ingress deserializer (bytes -> flit) -----------
    // One 80-bit accumulator; o-side ready is local-only (!pend). While
    // a flit awaits grant the byte port backpressures (ring elasticity
    // is the buffer). word[4:0] pad bits are ignored on ingress.
    //
    // ARMED discipline (the hard lesson, kept in silicon): the QUF
    // writer's align padding can exceed ten bytes AFTER ld_done -- in
    // QUF mode those bytes keep arriving once the boot FSM reaches RUN,
    // and ten zero pad bytes assemble into a perfectly valid BIND flit
    // (op=0, dst=0) that binds cell 0 before the host's i_eod lands
    // (found by the differential TB, reproduced standalone). So the
    // boot->flit boundary is a FRONT-END epoch, not a timing hope:
    // bytes are flits only once armed -- by i_eod (QUF mode host
    // contract: strobe it with the container's end; padding rides with
    // it) or by the release word itself (gate mode: the word IS the
    // boundary). Until armed, run-phase bytes are accepted and dropped,
    // exactly like quf_boot's own discard path.
    reg        armed;
    reg [3:0]  nby;
    reg [79:0] shacc;
    reg        pend;

    wire       ing_rdy;   // io node external-ingress ready (li side)

    wire       deser_rdy = run && armed && !pend;

    always @(posedge clk) begin
        if (!rst_n) begin
            armed <= 1'b0;
            nby   <= 4'd0;
            shacc <= 80'd0;
            pend  <= 1'b0;
        end else begin
            if (i_eod)
                armed <= 1'b1;               // the barrier, latched once
            else if (!SER_BOOT_QUF && run)
                armed <= 1'b1;               // gate mode: word = boundary
            if (!run || i_eod) begin
                // no boot byte ever leaks into a flit; eod also flushes
                // any partial frame built from padding
                nby   <= 4'd0;
                shacc <= 80'd0;
                pend  <= 1'b0;
            end else begin
                if (pend && ing_rdy)
                    pend <= 1'b0;            // flit granted to ring
                if (i_sval && deser_rdy) begin
                    shacc <= {shacc[71:0], i_sbyte};
                    if (nby == 4'd9) begin
                        nby  <= 4'd0;
                        pend <= 1'b1;
                    end else
                        nby <= nby + 4'd1;
                end
            end
        end
    end

    // in RUN the boot lane is a discard sink (always ready); armed, the
    // port ready is the deserializer's; UNARMED run-phase bytes (QUF
    // align padding still in flight after release) are accepted and
    // dropped -- the port never stalls the host on boot residue, the
    // same end-of-stream rule quf_boot itself obeys
    assign o_srdy = run ? (armed ? deser_rdy : 1'b1) : boot_brdy;

    // ---------------- egress serializer (flit -> bytes) --------------
    // 75-bit capture on the io node's delivery handshake; bytes 0..9
    // shifted out under the host handshake; pad bits driven zero.
    // e_rdy = local-only (!tbusy): never a function of i_strdy.
    wire              egr_val;   // io node delivery valid
    wire [OPW-1:0]    egr_op;
    wire [AIDW-1:0]   egr_src, egr_dst;
    wire [PW-1:0]     egr_a0, egr_a1, egr_a2, egr_dat;
    wire              egr_rdy;

    wire [79:0]       eword = {egr_op, egr_src, egr_dst, egr_a0, egr_a1,
                               egr_a2, egr_dat, 5'd0};
    reg [3:0]         tby;
    reg               tbusy;
    reg [79:0]        tcap;

    assign egr_rdy  = run && !tbusy;
    assign o_stx_val = run && tbusy;
    assign o_stx    = tcap[79 - 8*tby -: 8];   // header byte first

    always @(posedge clk) begin
        if (!rst_n) begin
            tby   <= 4'd0;
            tbusy <= 1'b0;
            tcap  <= 80'd0;
        end else begin
            if (run && !tbusy && egr_val) begin
                tcap  <= eword;                  // pad [4:0] = 0
                tbusy <= 1'b1;
                tby   <= 4'd0;
            end else if (tbusy && i_strdy) begin
                if (tby == 4'd9) begin
                    tbusy <= 1'b0;               // flit fully serialized
                    tby   <= 4'd0;
                end else
                    tby <= tby + 4'd1;
            end
        end
    end

    // ---------------- the ring (mirrors q_fabric_top) ----------------
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

    q_tick_sched_rt #(.TPWMAX(16)) u_ts (
        .clk(clk), .rst_n(rst_n), .i_epoch(boot_epoch),
        .i_tpw({{11{1'b0}}, boot_tpw}), .o_tick(tick)
    );

    genvar g;
    generate
        for (g = 0; g < NB; g = g + 1) begin : nodes
            if (g == 0) begin : conn0
                q_cell #(
                    .OPW(OPW), .AIDW(AIDW), .PW(PW), .EDGES_N(EDGES_N)
                ) u_cell (
                    .clk(clk), .rst_n(boot_rst_n), .i_por_n(rst_n),
                    .i_bdf_wr(bdf_wr[g]), .i_bdf_addr(bdf_addr[g*4 +: 4]),
                    .i_bdf_wdata(bdf_wdata[g*16 +: 16]),
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
                    .clk(clk), .rst_n(boot_rst_n), .i_por_n(rst_n),
                    .i_bdf_wr(bdf_wr[g]), .i_bdf_addr(bdf_addr[g*4 +: 4]),
                    .i_bdf_wdata(bdf_wdata[g*16 +: 16]),
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
                    // external contract lives behind the serdes
                    // (field slices = the accumulated frame word, above)
                    .i_val(pend), .o_rdy(ing_rdy),
                    .i_op(shacc[79:77]),
                    .i_src(shacc[76:73]),
                    .i_dst(shacc[72:69]),
                    .i_a0(shacc[68:53]), .i_a1(shacc[52:37]),
                    .i_a2(shacc[36:21]), .i_dat(shacc[20:5]),
                    .o_val(egr_val), .i_rdy(egr_rdy),
                    .o_op(egr_op), .o_src(egr_src), .o_dst(egr_dst),
                    .o_a0(egr_a0), .o_a1(egr_a1), .o_a2(egr_a2),
                    .o_dat(egr_dat)
                );
            end

            q_flit_pipe #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_pipe (
                .clk(clk), .rst_n(boot_rst_n),
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

    assign o_ovf     = |ovf_cells;
    assign o_boot_ok = boot_ok;
    assign o_epoch   = boot_epoch;
    assign o_state   = boot_state;
    assign o_err     = boot_err;

endmodule
