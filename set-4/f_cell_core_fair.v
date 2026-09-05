// formal/f_cell_core_fair.v -- bounded-liveness proof for q_cell_core:
// SYNTHESIS.md invariants I1 (op boundedness) and I2 (view answered).
//
//   I1a  PURE OP BOUND: when no tick strobe arrives during a low period,
//        the gap between consecutive ci_ready pulses never exceeds
//        MAX_OP_CYCLES (64) -- the run-to-completion FSM has no unbounded
//        wait. Structural worst case ~57 (view(1) = wsum over 4 edges,
//        engine contract below); the bound carries 7 cycles slack.
//   I1b  COMPOSITE BOUND: with the real tick scheduler's spacing (one
//        strobe per 2^TPW cycles, TPW>=7 modeled as >=128 here; the
//        shipped TPW=8 gives 256), a low period is at most one op plus
//        one tick service: gap <= 2*MAX_OP_CYCLES (128). Structural worst
//        ~92 (view + tick service chained at the op boundary). Adversarial
//        sub-service-interval strobes would chain services forever, which
//        is exactly why the scheduler spaces ticks; the assumption is the
//        documented fabric contract, not a proof convenience.
//   I2   every accepted bind/link/view (and the first flit of an unbound
//        cell, and any undefined opcode) is answered with a response flit
//        handshake within RESP_MAX (66) cycles, under ARBITRARY tick
//        strobing: responses are emitted inside the op (ST_RESP) and a
//        pending tick only dispatches at the following ST_IDLE, so ticks
//        can never preempt or delay a response.
//
// These bounds are honest only against the Q2-fixed RTL: ci_ready must
// never be offered while a tick is pending (formal/cell_core.tick.sby
// found the one-cycle hole where an upstream pipe popped a flit the
// dispatching core ignored -- silently dropped ingress).
//
// Bounded-liveness method (documented bound): shadow countdown counters +
// assert-within-N in BMC mode, depth 80. Unbounded liveness is NOT
// claimed. Environment contract (each weaker than the real system):
//   E1  egress always grants: lo_ready = lx_ready = 1 (ring-progress
//       backpressure is the fabric-level property, out of scope here).
//   E2  engine contract: while a slot is selected or a command strobe is
//       present, a readout command (011) is answered within 12 cycles,
//       any other within 4. The real q_hebb_edge answers readout (K=8)
//       in 10 and all others in 2, so every real trace satisfies E2;
//       idle periods are unconstrained (the engine is legitimately
//       silent when idle).
//   E3  dialfile responses follow real q_dialfile timing (stubbed data).
//   E4  tick scheduler spacing: s_tick strobes >= 128 cycles apart
//       (q_tick_sched default: 256).
// All other primary inputs (ci_*, s_tick timing within E4, dials, hb_w)
// are free.
module f_cell_core_fair(input clk, input rst_n);
    localparam OPW = 3, AIDW = 4, PW = 16, EDGES_N = 4, EIW = 2, K = 8;
    localparam [7:0] MAX_OP_CYCLES = 64, RESP_MAX = 66, GAP_MAX = 128;

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

    // E4: tick scheduler spacing (q_tick_sched: one strobe per 2^TPW, TPW>=7)
    reg [7:0] f_tsp = 0;
    always @(posedge clk) begin
        if (!rst_n)     f_tsp <= 8'd127;
        else if (s_tick) f_tsp <= 0;
        else if (f_tsp < 8'd127) f_tsp <= f_tsp + 1'b1;
    end
    always @(*)
        if (f_rstctr >= 2) assume (!s_tick || f_tsp >= 8'd127);

    // E3: dialfile stub with real q_dialfile timing
    always @(posedge clk) begin
        df_rstb <= df_rd;
        if (df_rd) df_rdata <= $anyseq;
    end

    // E2: engine responsiveness contract. f_lcmd remembers the last command
    // strobe; the wait bound is 12 for readout (real: 10), 4 for everything
    // else (real: 2). Counting only runs while an engine op is active.
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

    // I1: gap between consecutive ci_ready pulses, split by tick interference
    reg [7:0] f_gap = 0;    // cycles ci_ready has been low
    reg       f_gtick = 0;  // a tick interfered with this low period
    // Finding 3 (depth-130 re-run, devil nudge 2026-08-29): s_tick during
    // the gap is NOT the only interference. A strobe that arrived while
    // ci_ready was still high latches tick_pend, and the Q2 interlock
    // services that tick inside the NEXT gap before re-asserting ready.
    // The trace showed view(1)+deferred-tick = 65 cycles misclassified as
    // a "pure op" gap. Interference is therefore ALSO witnessed by the
    // DUT itself servicing a tick during the gap -- detected through
    // PORT-VISIBLE signals (the tick sweep's engine command 010, and the
    // fire fanout), NOT hierarchical refs (yosys silently leaves
    // dut.state unresolved, which cost one 37-minute re-run to learn).
    // Any tick service that can push a gap past MAX_OP_CYCLES necessarily
    // sweeps >=1 valid edge (cmd 010); a zero-edge service adds only 2
    // cycles, inside the pure-op bound.
    wire f_ticksvc = (hb_cmd == 3'b010)                 // tick decay sweep
                   || (lx_valid && (lx_op == OP_EFF));  // fire fanout
    always @(posedge clk) begin
        if (!rst_n) begin
            f_gap <= 0; f_gtick <= 0;
        end else if (ci_ready) begin
            f_gap <= 0; f_gtick <= 0;
        end else begin
            f_gap <= f_gap + 1'b1;
            if (s_tick || f_ticksvc) f_gtick <= 1'b1;
        end
    end

    // I2: response deadline. Responding ops: BIND/LINK/VIEW/undefined, plus
    // the very first flit of an unbound cell (any opcode -> ack or nak).
    wire f_accept = ci_valid && ci_ready;
    reg  f_ever = 0;      // has accepted a first flit (bound or naking regime)
    reg  f_rp = 0;        // response pending
    reg  [7:0] f_rc = 0;  // cycles since armed
    wire f_resp_op = (ci_op == OP_BIND) || (ci_op == OP_LINK) ||
                     (ci_op == OP_VIEW) || (ci_op == 3'd7);
    always @(posedge clk) begin
        if (!rst_n) begin
            f_ever <= 0; f_rp <= 0; f_rc <= 0;
        end else begin
            if (f_accept) f_ever <= 1'b1;
            if (!f_rp && f_accept && (f_resp_op || !f_ever)) begin
                f_rp <= 1'b1;
                f_rc <= 0;
            end else if (f_rp && lo_valid && lo_ready) begin
                f_rp <= 0;
            end else if (f_rp) begin
                f_rc <= f_rc + 1'b1;
            end
        end
    end

    always @(posedge clk) if (rst_n) begin
        // I1b: composite bound (op + at most one tick service, E4-spaced)
        assert (f_gap <= GAP_MAX);
        // I1a: pure op bound (no tick interfered with this low period)
        if (!f_gtick) assert (f_gap <= MAX_OP_CYCLES);
        // I2
        if (f_rp) assert (f_rc <= RESP_MAX);
        // sanity: responses are acks or naks
        if (lo_valid) assert (lo_op == OP_ACK || lo_op == OP_NAK);
        // covers: non-vacuity
        cover (f_accept && ci_op == OP_VIEW);
        cover (f_accept && ci_op == OP_EFF);
        cover (lo_valid && lo_ready);
        cover (lx_valid && lx_ready);          // a fire fanout happened
        cover (f_gap >= 40 && !f_gtick);       // deep pure op exercised
        cover (f_gtick && f_gap >= 60);        // op+tick composite exercised
    end
endmodule
