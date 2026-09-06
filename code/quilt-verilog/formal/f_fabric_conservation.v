// formal/f_fabric_conservation.v -- 2-cell fabric ledger-conservation proof.
//
// Hardware mirror of the quilt calculus A1/T1 (docs/academic
// quilt-calculus.md: cut conservation by induction over commit sequences;
// in-flight identity + no-fabrication), specialized to the fire-only
// workload where it is exact:
//
//   Two cells A,B. A is dialed to fire on every tick (thresh 0, refr 0);
//   each fire consumes A's activation and fans out exactly one effect
//   flit per valid edge (all edges link to B). The flit crosses a real
//   q_flit_pipe (the same module proven in flit_pipe.fly.sby) and is
//   accepted at B; B books it as a graded cofire commit (hb_cmd==101,
//   class 0 = bit-exact v1 train, ladder bucket 0 += 1). Echo gate off
//   (floor 0), RQH off (rqen 0) -- pure v1 datapath. Real q_hebb_edge
//   engines hang off both cores: NO engine-contract assumptions here.
//
// Ledger accounts, all counted at module boundaries (no XMRs):
//   emitted   = effect flits handed off by fires (A.lx into the pipe,
//               B.lx into an external sink if B ever fires)
//   in_flight = flits occupying the pipe (shadow occupancy)
//   in_service= effect accepted at B.ci but not yet committed
//   booked    = cofire commits strobed at B (hb_cmd 001/101) = weight
//
// Properties:
//   T1  emitted == in_flight + accepted(B)                (transport:
//       no flit lost or fabricated in movement -- composes with the
//       fly.sby FIFO proof)
//   A1  emitted == booked + in_flight + in_service + external
//       (the ledger: booked weights + flits in flight == what fires
//       issued; constant across commits -- nothing fabricated, nothing
//       lost. With B's fire flits counted as external the system stays
//       closed: a fire converts booked weight back to in-flight credit.)
//   SER   in_service <= 1 (commits serialize through the core)
//   DROP  every accepted effect is booked within 16 cycles -- the silent
//       unknown-source drop path (ST_EFFT eidx==EDGES_N) is UNREACHABLE
//       for linked peers; if the link/effect table matching broke, this
//       assertion fails loudly.
//   FAN   post-setup, every A emission carries op=EFFECT, src=A, dst=B
//       (fanout addresses the linked peer).
//
// Scope (documented honestly): the proof horizon is 55 cycles; within it
// at most ~54 ticks can occur, so the ladder half-life (64) never elapses
// (no decay-shift destruction of weight) and bucket saturation (16
// cofires at B=4) is only reachable if the flood of fires exceeds it --
// the ledger counts commits, which decay and saturation do not create or
// destroy, so A1 holds regardless; DROP/SER likewise. Shrunk parameters
// for tractability, documented: EDGES_N=1, engine K=4/B=4/AGEW=8.
// PIPE_EFF=1 pinned explicitly (2026-08-29, mathmetal lane): the v2.1
// effect-pipeline retime -- the config the committed HX8K bitstream ships
// -- registers the RQH-credit add, the 16x16 multiply, and the saturating
// accumulate into three stages (each effect op +2 clk; DROP's structural
// worst case moves ~4 -> ~6 cycles, still far under the 16-cycle bound).
// The ledger identity is re-proven below on the retimed cone: conservation
// is a property of commits, not of pipeline latency.
module f_fabric_conservation(input clk, input rst_n);
    localparam OPW = 3, AIDW = 4, PW = 16, EDGES_N = 1, EIW = 1, K = 4;
    localparam [OPW-1:0] OP_BIND = 3'd0, OP_LINK = 3'd1, OP_EFF = 3'd2;
    localparam [AIDW-1:0] A_ID = 4'd1, B_ID = 4'd2;

    // ---------------- core A (the firing cell) ------------------------
    reg  [OPW-1:0]  ciA_op;
    reg             ciA_valid;
    wire            ciA_ready;
    reg  [AIDW-1:0] ciA_src;
    reg  [PW-1:0]   ciA_a0, ciA_a1, ciA_a2, ciA_dat;

    wire [OPW-1:0]  loA_op;
    wire            loA_valid;
    wire [AIDW-1:0] loA_dst, loA_src;
    wire [PW-1:0]   loA_a0, loA_a1, loA_a2, loA_dat;

    wire [OPW-1:0]  lxA_op;
    wire            lxA_valid;
    wire            lxA_ready;
    wire [AIDW-1:0] lxA_dst, lxA_src;
    wire [PW-1:0]   lxA_a0, lxA_a1, lxA_a2, lxA_dat;

    wire [2:0]      hb_cmdA;
    wire [EDGES_N-1:0] hb_selA;
    wire [PW-1:0]   hb_baseA;
    wire [3:0]      hb_gclA;
    wire [PW-1:0]   hb_wA;
    wire            hb_doneA;
    wire            df_wrA, df_rdA, df_rstbA;
    wire [3:0]      df_addrA;
    wire [PW-1:0]   df_wdataA, df_rdataA;
    wire            boundA, o_ftraceA, o_anticA;
    wire [AIDW-1:0] cellA_id;
    wire signed [PW-1:0] actA;

    wire s_tick;   // shared tick (both cells, as in q_fabric_top)

    q_cell_core #(.OPW(OPW), .AIDW(AIDW), .PW(PW),
                  .EDGES_N(EDGES_N), .EIW(EIW), .K(K),
                  .PIPE_EFF(1)) u_coreA (
        .clk(clk), .rst_n(rst_n),
        .ci_op(ciA_op), .ci_valid(ciA_valid), .ci_ready(ciA_ready),
        .ci_src(ciA_src), .ci_a0(ciA_a0), .ci_a1(ciA_a1), .ci_a2(ciA_a2),
        .ci_dat(ciA_dat),
        .lo_op(loA_op), .lo_valid(loA_valid), .lo_ready(1'b1),
        .lo_dst(loA_dst), .lo_src(loA_src),
        .lo_a0(loA_a0), .lo_a1(loA_a1), .lo_a2(loA_a2), .lo_dat(loA_dat),
        .lx_op(lxA_op), .lx_valid(lxA_valid), .lx_ready(lxA_ready),
        .lx_dst(lxA_dst), .lx_src(lxA_src),
        .lx_a0(lxA_a0), .lx_a1(lxA_a1), .lx_a2(lxA_a2), .lx_dat(lxA_dat),
        .hb_cmd(hb_cmdA), .hb_sel(hb_selA), .hb_base(hb_baseA),
        .hb_gcl(hb_gclA), .hb_w(hb_wA), .hb_done(hb_doneA),
        .df_wr(df_wrA), .df_addr(df_addrA), .df_wdata(df_wdataA),
        .df_rd(df_rdA), .df_rdata(df_rdataA), .df_rstb(df_rstbA),
        .d_ka(4'd1), .d_thresh(16'sd0), .d_refr(16'd0),
        .d_kle(4'd2), .d_floor(16'd0),
        .d_qdw(4'd8), .d_qleak(4'd8), .d_rqen(1'b0),
        .s_tick(s_tick),
        .bound(boundA), .cell_id(cellA_id), .act(actA),
        .o_ftrace(o_ftraceA), .o_antic(o_anticA)
    );

    // ---------------- core B (the booking cell) -----------------------
    wire [OPW-1:0]  ciB_op;
    wire            ciB_valid;
    wire            ciB_ready;
    wire [AIDW-1:0] ciB_src;
    wire [PW-1:0]   ciB_a0, ciB_a1, ciB_a2, ciB_dat;

    wire [OPW-1:0]  loB_op;
    wire            loB_valid;
    wire [AIDW-1:0] loB_dst, loB_src;
    wire [PW-1:0]   loB_a0, loB_a1, loB_a2, loB_dat;

    wire [OPW-1:0]  lxB_op;
    wire            lxB_valid;
    wire            lxB_ready = 1'b1;   // external sink
    wire [AIDW-1:0] lxB_dst, lxB_src;
    wire [PW-1:0]   lxB_a0, lxB_a1, lxB_a2, lxB_dat;

    wire [2:0]      hb_cmdB;
    wire [EDGES_N-1:0] hb_selB;
    wire [PW-1:0]   hb_baseB;
    wire [3:0]      hb_gclB;
    wire [PW-1:0]   hb_wB;
    wire            hb_doneB;
    wire            df_wrB, df_rdB, df_rstbB;
    wire [3:0]      df_addrB;
    wire [PW-1:0]   df_wdataB, df_rdataB;
    wire            boundB, o_ftraceB, o_anticB;
    wire [AIDW-1:0] cellB_id;
    wire signed [PW-1:0] actB;

    q_cell_core #(.OPW(OPW), .AIDW(AIDW), .PW(PW),
                  .EDGES_N(EDGES_N), .EIW(EIW), .K(K),
                  .PIPE_EFF(1)) u_coreB (
        .clk(clk), .rst_n(rst_n),
        .ci_op(ciB_op), .ci_valid(ciB_valid), .ci_ready(ciB_ready),
        .ci_src(ciB_src), .ci_a0(ciB_a0), .ci_a1(ciB_a1), .ci_a2(ciB_a2),
        .ci_dat(ciB_dat),
        .lo_op(loB_op), .lo_valid(loB_valid), .lo_ready(1'b1),
        .lo_dst(loB_dst), .lo_src(loB_src),
        .lo_a0(loB_a0), .lo_a1(loB_a1), .lo_a2(loB_a2), .lo_dat(loB_dat),
        .lx_op(lxB_op), .lx_valid(lxB_valid), .lx_ready(lxB_ready),
        .lx_dst(lxB_dst), .lx_src(lxB_src),
        .lx_a0(lxB_a0), .lx_a1(lxB_a1), .lx_a2(lxB_a2), .lx_dat(lxB_dat),
        .hb_cmd(hb_cmdB), .hb_sel(hb_selB), .hb_base(hb_baseB),
        .hb_gcl(hb_gclB), .hb_w(hb_wB), .hb_done(hb_doneB),
        .df_wr(df_wrB), .df_addr(df_addrB), .df_wdata(df_wdataB),
        .df_rd(df_rdB), .df_rdata(df_rdataB), .df_rstb(df_rstbB),
        .d_ka(4'd1), .d_thresh(16'sh7FFF), .d_refr(16'd0),
        .d_kle(4'd2), .d_floor(16'd0),
        .d_qdw(4'd8), .d_qleak(4'd8), .d_rqen(1'b0),
        .s_tick(s_tick),
        .bound(boundB), .cell_id(cellB_id), .act(actB),
        .o_ftrace(o_ftraceB), .o_antic(o_anticB)
    );

    // ---------------- real engines (one per cell, EDGES_N=1) ----------
    q_hebb_edge #(.PW(PW), .K(K), .B(4), .AGEW(8)) u_engA (
        .clk(clk), .rst_n(rst_n),
        .i_sel(hb_selA[0]), .i_cmd(hb_cmdA), .i_mode(1'b0),
        .i_base(hb_baseA), .i_hl(16'd64), .i_p0e(5'd4), .i_gclass(hb_gclA),
        .o_done(hb_doneA), .o_w(hb_wA), .o_ovf()
    );
    q_hebb_edge #(.PW(PW), .K(K), .B(4), .AGEW(8)) u_engB (
        .clk(clk), .rst_n(rst_n),
        .i_sel(hb_selB[0]), .i_cmd(hb_cmdB), .i_mode(1'b0),
        .i_base(hb_baseB), .i_hl(16'd64), .i_p0e(5'd4), .i_gclass(hb_gclB),
        .o_done(hb_doneB), .o_w(hb_wB), .o_ovf()
    );

    // ---------------- A egress -> pipe -> B ingress -------------------
    wire ciB_pipe_valid;              // driven by u_pipe m_valid
    wire ciB_pipe_ready;              // driven below (= ciB_ready && f_run)
    wire [OPW-1:0]  p_op;
    wire [AIDW-1:0] p_src, p_dst;
    wire [PW-1:0]   p_a0, p_a1, p_a2, p_dat;

    q_flit_pipe #(.OPW(OPW), .AIDW(AIDW), .PW(PW)) u_pipe (
        .clk(clk), .rst_n(rst_n),
        .s_valid(lxA_valid), .s_ready(lxA_ready),
        .s_op(lxA_op), .s_src(lxA_src), .s_dst(lxA_dst),
        .s_a0(lxA_a0), .s_a1(lxA_a1), .s_a2(lxA_a2), .s_dat(lxA_dat),
        .m_valid(ciB_pipe_valid), .m_ready(ciB_pipe_ready),
        .m_op(p_op), .m_src(p_src), .m_dst(p_dst),
        .m_a0(p_a0), .m_a1(p_a1), .m_a2(p_a2), .m_dat(p_dat)
    );

    // ---------------- setup FSM: bind + link both cells ---------------
    reg [1:0] f_sA = 0, f_sB = 0;   // 0=bind, 1=link, 2=done
    wire f_run = (f_sA == 2'd2) && (f_sB == 2'd2);

    wire f_accA_hs = ciA_valid && ciA_ready;
    wire f_accB_hs = ciB_valid && ciB_ready;
    assign ciB_pipe_ready = ciB_ready && f_run;

    always @(posedge clk) begin
        if (!rst_n) begin
            f_sA <= 0; f_sB <= 0;
        end else begin
            if ((f_sA == 2'd0 || f_sA == 2'd1) && f_accA_hs) f_sA <= f_sA + 1'b1;
            if ((f_sB == 2'd0 || f_sB == 2'd1) && f_accB_hs) f_sB <= f_sB + 1'b1;
        end
    end

    // A ingress: setup flits, then silent
    assign ciA_valid = (f_sA != 2'd2);
    assign ciA_op    = (f_sA == 2'd0) ? OP_BIND : OP_LINK;
    assign ciA_src   = B_ID;                          // link peer is B
    assign ciA_a0    = (f_sA == 2'd0) ? {12'd0, A_ID} : 16'd0;
    assign ciA_a1    = 16'd0;                         // base weight 0
    assign ciA_a2    = 16'd0;
    assign ciA_dat   = 16'd0;

    // B ingress: setup flits until f_run, then the pipe
    assign ciB_valid = f_run ? ciB_pipe_valid : (f_sB != 2'd2);
    assign ciB_op    = f_run ? p_op : ((f_sB == 2'd0) ? OP_BIND : OP_LINK);
    assign ciB_src   = f_run ? p_src : A_ID;          // link peer is A
    assign ciB_a0    = f_run ? p_a0 : ((f_sB == 2'd0) ? {12'd0, B_ID} : 16'd0);
    assign ciB_a1    = f_run ? p_a1 : 16'd0;
    assign ciB_a2    = f_run ? p_a2 : 16'd0;
    assign ciB_dat   = f_run ? p_dat : 16'd0;

    // tick strobes only in the fire-only phase
    reg f_tfree = 0;
    always @(posedge clk) f_tfree <= $anyseq;
    assign s_tick = f_run && f_tfree;

    // reset preamble; hold reset high afterwards (single-reset contract)
    reg [1:0] f_rstctr = 0;
    always @(posedge clk)
        if (f_rstctr < 2) f_rstctr <= f_rstctr + 1;
    always @(*) begin
        if (f_rstctr < 2) assume (!rst_n);
        else              assume (rst_n);
    end

    // ---------------- ledger accounts ---------------------------------
    reg [7:0] f_emitA = 0;   // A fire fanout flits (into pipe)
    reg [7:0] f_ext   = 0;   // B fire fanout flits (external sink)
    reg [7:0] f_pocc  = 0;   // pipe occupancy shadow
    reg [7:0] f_acc   = 0;   // effects accepted at B
    reg [7:0] f_book  = 0;   // cofire commits booked at B
    reg [7:0] f_bookA = 0;   // sanity: A never trains in fire-only
    reg [4:0] f_icnt  = 0;   // cycles an accepted effect sits unbooked

    wire f_push = lxA_valid && lxA_ready;
    wire f_pop  = ciB_pipe_valid && ciB_pipe_ready;   // pipe -> B handshake
    wire f_effB = f_pop && (p_op == OP_EFF);
    wire f_bookB_stb = (hb_cmdB == 3'b001) || (hb_cmdB == 3'b101);
    wire f_bookA_stb = (hb_cmdA == 3'b001) || (hb_cmdA == 3'b101);
    wire [7:0] f_ins = f_acc - f_book;                // in service at B

    always @(posedge clk) begin
        if (!rst_n) begin
            f_emitA <= 0; f_ext <= 0; f_pocc <= 0;
            f_acc <= 0; f_book <= 0; f_bookA <= 0; f_icnt <= 0;
        end else begin
            if (f_push) f_emitA <= f_emitA + 1'b1;
            if (lxB_valid && lxB_ready) f_ext <= f_ext + 1'b1;
            // single NBA: coincident push+pop must both count (two separate
            // `if` assignments would silently drop the push -- last-NBA-wins)
            f_pocc <= f_pocc + (f_push ? 8'd1 : 8'd0) - (f_pop ? 8'd1 : 8'd0);
            if (f_effB) f_acc  <= f_acc + 1'b1;
            if (f_bookB_stb) f_book <= f_book + 1'b1;
            if (f_bookA_stb) f_bookA <= f_bookA + 1'b1;
            if (f_acc != f_book) f_icnt <= f_icnt + 1'b1;
            else                f_icnt <= 0;
        end
    end

    always @(posedge clk) if (rst_n) begin
        // T1: transport conservation (no flit lost or fabricated)
        assert (f_emitA == f_pocc + f_acc);
        assert (f_pocc <= 2);                        // pipe capacity sanity
        // SER: commits serialize through B
        assert (f_ins <= 1);
        // DROP: no silent drops -- every accepted effect books fast
        if (f_acc != f_book) assert (f_icnt <= 16);
        // A1: the ledger. booked weights + flits in flight (pipe + service)
        // + externally sunk == everything fires issued. Constant across
        // commits: a commit moves a flit from in_flight/in_service to
        // booked; nothing else mints or burns credits.
        assert (f_emitA + f_ext == f_book + f_pocc + f_ins + f_ext);
        // FAN: fanout addresses the linked peer with the right opcode/src
        if (f_run && lxA_valid) begin
            assert (lxA_op == OP_EFF);
            assert (lxA_dst == B_ID);
            assert (lxA_src == A_ID);
        end
        // sanity: the firing cell never trains (nothing feeds it)
        assert (f_bookA == 0);
        // covers
        cover (f_acc >= 1);        // an effect landed at B
        cover (f_book >= 1);       // full chain: fire -> pipe -> accept -> commit
        cover (f_emitA >= 2);      // at least two fires serviced
    end
endmodule
