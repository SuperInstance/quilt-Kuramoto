// formal/f_cell_core_tick.v -- Q2 proof for q_cell_core: non-deferrable
// time, under the adversarial environment: continuous ingress flood
// (ci_valid held high forever, free opcode mix) and ARBITRARY tick strobes
// (no spacing assumed -- stronger than the real scheduler).
//
// The tick interlock (SYNTHESIS.md Q2): s_tick latches tick_pend from any
// state; ST_IDLE services it BEFORE accepting new ingress; the Q2 fix
// (found by this proof's first run) additionally forces ci_ready low
// whenever a tick is pending or being set, so ready is never offered to a
// producer whose flit the dispatching FSM would silently drop.
//
// Properties (boundary-observable; no XMRs -- yosys frontend limitation).
// In the bound regime (past the first accepted flit), the Q2-fixed RTL
// guarantees pend => !ci_ready, hence:
//
//   Q2b  FRONT OF QUEUE: while a strobed tick has not yet entered service
//        (shadow f_blk, armed on strobe in the linked regime, cleared at
//        the sweep's first engine command or a post-service ready pulse),
//        ci_ready must stay LOW: no ingress accept can occur, even under
//        permanent flood. This is the ready-suppression half of the Q2
//        interlock -- and the exact property opencode's `tick_go &&
//        !ci_valid` skeleton violates (ADVOCACY.md SS1.2: accepts continue
//        with the tick pending). The first run of this proof caught the
//        RTL's one-ci_ready-hole variant of that failure (see below).
//
//   Q2a1 COMPOSITE DEADLINE: from any strobe to the next ci_ready pulse
//        (current op completes, tick serviced, core back to accepting) is
//        at most Q2_RISE (100) cycles. Structural worst ~92: strobe
//        landing on a view(1) accept (<=57 op) + tick service (~33:
//        2-entry + 4-edge sweep + leak + fire fanout). The deadline
//        restarts on a newer strobe, so chained services stay bounded.
//
//   Q2a2 ENTRY WITNESS: once the cell has linked at least one edge
//        (f_linked: a LINK accept was seen; edges are never unlinked in
//        v1, so ev[] stays set), the tick sweep's first engine command
//        (hb_cmd==010 -- issued ONLY by tick service) appears within
//        ENTRY_DL (66) cycles of any strobe: direct evidence that the
//        tick entered service within the in-flight op bound, i.e. it was
//        deferred by at most the op, never queued behind traffic. (With
//        zero linked edges no 010 strobe exists; that cell's service is
//        the 4-cycle empty sweep covered by Q2a1.)
//
// Scope: strobes before the first accepted flit (the ST_UNB birth phase)
// are not claimed; the first flit owns the queue by design.
//
// Bounded-liveness method: shadow countdowns + assert-within-N in BMC
// mode, depth 80. Environment E1/E2/E3 as in f_cell_core_fair.v.
module f_cell_core_tick(input clk, input rst_n);
    localparam OPW = 3, AIDW = 4, PW = 16, EDGES_N = 4, EIW = 2, K = 8;
    localparam [6:0] Q2_RISE = 100, ENTRY_DL = 66;

    localparam [OPW-1:0] OP_BIND = 3'd0, OP_LINK = 3'd1, OP_EFF  = 3'd2,
                         OP_VIEW = 3'd3, OP_TICK = 3'd4, OP_ACK  = 3'd5,
                         OP_NAK  = 3'd6;

    reg  [OPW-1:0]    ci_op;
    reg               ci_valid;
    wire              ci_ready;
    reg  [AIDW-1:0]   ci_src;
    reg  [PW-1:0]     ci_a0, ci_a1, ci_a2, ci_dat;

    wire [OPW-1:0]    lo_op;
    wire              lo_valid;
    wire              lo_ready = 1'b1;
    wire [AIDW-1:0]   lo_dst, lo_src;
    wire [PW-1:0]     lo_a0, lo_a1, lo_a2, lo_dat;

    wire [OPW-1:0]    lx_op;
    wire              lx_valid;
    wire              lx_ready = 1'b1;
    wire [AIDW-1:0]   lx_dst, lx_src;
    wire [PW-1:0]     lx_a0, lx_a1, lx_a2, lx_dat;

    wire [2:0]        hb_cmd;
    wire [EDGES_N-1:0] hb_sel;
    wire [PW-1:0]     hb_base;
    wire [3:0]        hb_gcl;
    reg  [PW-1:0]     hb_w;
    reg               hb_done;

    wire              df_wr;
    wire [3:0]        df_addr;
    wire [PW-1:0]     df_wdata;
    wire              df_rd;
    reg  [PW-1:0]     df_rdata;
    reg               df_rstb;

    reg  [3:0]        d_ka;
    reg  signed [PW-1:0] d_thresh;
    reg  [PW-1:0]     d_refr;
    reg  [3:0]        d_kle, d_qdw, d_qleak;
    reg  [PW-1:0]     d_floor;
    reg               d_rqen;

    reg               s_tick;

    wire              bound, o_ftrace, o_antic;
    wire [AIDW-1:0]   cell_id;
    wire signed [PW-1:0] act;

    q_cell_core #(.OPW(OPW), .AIDW(AIDW), .PW(PW),
                  .EDGES_N(EDGES_N), .EIW(EIW), .K(K)) dut (
        .clk(clk), .rst_n(rst_n),
        .ci_op(ci_op), .ci_valid(ci_valid), .ci_ready(ci_ready),
        .ci_src(ci_src), .ci_a0(ci_a0), .ci_a1(ci_a1), .ci_a2(ci_a2),
        .ci_dat(ci_dat),
        .lo_op(lo_op), .lo_valid(lo_valid), .lo_ready(lo_ready),
        .lo_dst(lo_dst), .lo_src(lo_src),
        .lo_a0(lo_a0), .lo_a1(lo_a1), .lo_a2(lo_a2), .lo_dat(lo_dat),
        .lx_op(lx_op), .lx_valid(lx_valid), .lx_ready(lx_ready),
        .lx_dst(lx_dst), .lx_src(lx_src),
        .lx_a0(lx_a0), .lx_a1(lx_a1), .lx_a2(lx_a2), .lx_dat(lx_dat),
        .hb_cmd(hb_cmd), .hb_sel(hb_sel), .hb_base(hb_base), .hb_gcl(hb_gcl),
        .hb_w(hb_w), .hb_done(hb_done),
        .df_wr(df_wr), .df_addr(df_addr), .df_wdata(df_wdata),
        .df_rd(df_rd), .df_rdata(df_rdata), .df_rstb(df_rstb),
        .d_ka(d_ka), .d_thresh(d_thresh), .d_refr(d_refr),
        .d_kle(d_kle), .d_floor(d_floor),
        .d_qdw(d_qdw), .d_qleak(d_qleak), .d_rqen(d_rqen),
        .s_tick(s_tick),
        .bound(bound), .cell_id(cell_id), .act(act),
        .o_ftrace(o_ftrace), .o_antic(o_antic)
    );

    // reset preamble
    reg [1:0] f_rstctr = 0;
    always @(posedge clk)
        if (f_rstctr < 2) f_rstctr <= f_rstctr + 1;
    always @(*)
        if (f_rstctr < 2) assume (!rst_n);

    // free inputs
    always @(posedge clk) begin
        ci_valid <= $anyseq;
        s_tick   <= $anyseq;
        {ci_op, ci_src, ci_a0, ci_a1, ci_a2, ci_dat} <= $anyseq;
        hb_w     <= $anyseq;
        hb_done  <= $anyseq;
        {d_ka, d_refr, d_kle, d_qdw, d_qleak, d_rqen} <= $anyseq;
        d_thresh <= $anyseq;
        d_floor  <= $anyseq;
    end

    // FLOOD: continuous ingress, the adversarial environment of Q2
    always @(*)
        if (f_rstctr >= 2 && rst_n) assume (ci_valid);

    // E3: dialfile stub with real q_dialfile timing
    always @(posedge clk) begin
        df_rstb <= df_rd;
        if (df_rd) df_rdata <= $anyseq;
    end

    // E2: engine responsiveness contract (as f_cell_core_fair.v)
    reg [2:0] f_lcmd = 3'b000;
    reg [4:0] f_hbc  = 0;
    wire f_eng_active = (hb_sel != {EDGES_N{1'b0}}) || (hb_cmd != 3'b000);
    wire [4:0] f_hblim = (f_lcmd == 3'b011) ? 5'd12 : 5'd4;
    always @(posedge clk) begin
        if (hb_cmd != 3'b000) f_lcmd <= hb_cmd;
        if (!rst_n)
            f_hbc <= 0;
        else if (!f_eng_active || hb_done || (lx_valid && lx_ready) || ci_ready)
            f_hbc <= 0;
        else
            f_hbc <= f_hbc + 1'b1;
    end
    always @(*)
        if (f_rstctr >= 2) assume (f_hbc <= f_hblim);

    // ---------------- Q2 shadow trackers ------------------------------
    wire f_accept  = ci_valid && ci_ready;
    reg  f_pub     = 0;                     // past-unbound (first response sent)
    reg  f_linked  = 0;                     // an edge exists: a set-base engine
                                             // cmd (100) was strobed -- issued
                                             // only by an EXECUTED link (a link
                                             // accepted while unbound is naked
                                             // and creates no edge)
    reg  f_blk     = 0;                     // strobe outstanding, service not entered
    reg  f_aw      = 0;                     // composite deadline armed
    reg  [6:0] f_dl = 0;                    // cycles since the newest strobe
    reg  f_eaw     = 0;                     // entry-witness deadline armed
    reg  [6:0] f_edl = 0;
    reg  [2:0] f_010n = 0;                  // tick sweep engine cmds seen
    wire f_sweepcmd = (hb_cmd == 3'b010);   // issued only by tick service

    always @(posedge clk) begin
        if (!rst_n) begin
            f_pub <= 0; f_linked <= 0; f_blk <= 0;
            f_aw <= 0; f_dl <= 0; f_eaw <= 0; f_edl <= 0; f_010n <= 0;
        end else begin
            if (lo_valid && lo_ready) f_pub <= 1'b1;
            if (hb_cmd == 3'b100) f_linked <= 1'b1;
            if (f_sweepcmd && f_010n < 3'd7) f_010n <= f_010n + 1'b1;

            // shadow A: strobe -> service entry. Entry is witnessed by the
            // sweep's first engine command, or by a ready pulse (which can
            // only follow a completed service). While set, ci_ready must be
            // low: this is the Q2 suppression -- ready is never offered to
            // a producer the dispatching core would strand (the hole the
            // first run of this proof found), and no accept can occur.
            // Armed only when an edge is linked (f_linked): the zero-edge
            // cell has no sweep strobe, so entry is not witnessable there
            // (its empty service is bounded by shadow B regardless).
            if (s_tick && f_pub && f_linked)  f_blk <= 1'b1;
            else if (f_blk && (f_sweepcmd || ci_ready)) f_blk <= 1'b0;

            // shadow B: strobe -> next ci_ready pulse (service completed)
            if (s_tick && f_pub) begin
                f_aw <= 1'b1;
                f_dl <= 0;
            end else if (f_aw) begin
                if (ci_ready) f_aw <= 1'b0;
                else          f_dl <= f_dl + 1'b1;
            end

            // shadow C: strobe -> first sweep engine cmd (entry witness;
            // meaningful only when an edge exists: f_linked)
            if (s_tick && f_pub && f_linked) begin
                f_eaw <= 1'b1;
                f_edl <= 0;
            end else if (f_eaw) begin
                if (f_sweepcmd) f_eaw <= 1'b0;
                else            f_edl <= f_edl + 1'b1;
            end
        end
    end

    always @(posedge clk) if (rst_n) begin
        // Q2b: while a strobed tick has not entered service, ready stays
        // low -- no accept possible, flood or not (this is the property
        // opencode's `tick_go && !ci_valid` skeleton violates)
        if (f_blk) assert (!ci_ready);
        // Q2a1: strobe -> next ci_ready pulse within Q2_RISE
        if (f_aw) assert (f_dl <= Q2_RISE);
        // Q2a2: with an edge linked, the sweep starts within ENTRY_DL
        if (f_eaw) assert (f_edl <= ENTRY_DL);
        // covers: non-vacuity under flood
        cover (f_sweepcmd && f_aw);      // tick sweep running despite flood
        cover (f_010n >= 3'd4);          // a full 4-edge sweep witnessed
        cover (f_aw && f_dl >= 40);      // long in-flight deferral exercised
        cover (f_eaw && f_edl >= 20);    // deep entry deferral exercised
        cover (f_accept && ci_op == OP_VIEW);  // flood includes views
    end
endmodule
