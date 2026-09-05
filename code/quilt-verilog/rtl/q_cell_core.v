// q_cell_core.v -- one quilt cell: the only interpreter of the five quilt
// opcodes (quilt-verilog v1, glm chassis). Cooperative run-to-completion FSM.
//
// Q1 (liveness, docs/SYNTHESIS.md): every op is bounded (MAX_OP_CYCLES);
// ci_ready reasserts after each op, so views/binds are never starved by
// effect traffic. No shared math tail exists in v1 (view(3) NAKs), so the
// grant-starvation surface is empty by construction.
//
// Q2 (non-deferrable time): s_tick latches tick_pend; ST_IDLE services
// tick_pend BEFORE accepting new ingress (ci_ready suppressed while
// pending). A tick is deferred by at most the in-flight op, never by
// traffic. This is curveball 8's pre-emption at the op boundary.
//
// Opcode semantics:
//   bind  : first bind sets cell_id (from a0) and binds the cell; later
//           binds write dial a0[3:0] <= a1. Ack.
//   link  : edge slot a0[EIW-1:0] := {peer=src, base weight=a1}. Ack.
//   effect: if src matches a valid edge slot, train that edge (cofire),
//           read the weight back, integrate act += sat((w*dat)>>>15).
//           Unknown src is dropped silently (link before effect).
//   view  : a0[1:0] 0=act 1=wsum(edges) 2=dial[a1[3:0]] 3=NAK (no cos in v1).
//           Response is an ack flit to src carrying the value in dat.
//   tick  : decay sweep over all valid edges, act leak (>>>ka), fire test
//           (act >= thresh && refr==0): fanout effects (dat=act) to all
//           valid edge peers, act:=0, refr:=d_refr.
//
// v2 features (INNOVATION-JUDGEMENT §5 fold-ins 1+2, shipped as a pair):
//   echo gate: q_echo_trace-style fire trace (q_echo_gate) gates effect
//     training -- a delivered effect trains only inside a causal window
//     after this cell's own fire, landing in ladder bucket 15-msb(F)
//     (engine cmd 101). Gate CLOSED: skip the train, read + integrate act
//     as usual (the gate prices learning, not activation). FLOOR=0 dial
//     = gate disabled = bit-exact v1 (cmd 101 with class 0 == cmd 001).
//   RQH residue bank: q_rqh_bank (corrected deposit, error-envelopes.md
//     T3c) banks the graded placement's dyadic residue per edge; its
//     credit is added to the weight at readback (act integration and
//     view wsum). RQEN=0 = credit 0 = bit-exact v1.
module q_cell_core #(
    parameter OPW     = 3,
    parameter AIDW    = 4,
    parameter PW      = 16,
    parameter EDGES_N = 4,
    parameter EIW     = 2,
    parameter K       = 8,   // ladder buckets (matches edge engines/bank)
    parameter PIPE_EFF = 1   // v2.1 retime: pipeline the effect-integration
                             // cone (RQH credit add -> 16x16 multiply ->
                             // saturating accumulate) into three registered
                             // stages. 0 = original single-cycle cone
                             // (differential-TB reference). Output values
                             // are bit-exact; each effect op costs +2 clk.
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // ingress flit (ring deliver)
    input  wire [OPW-1:0]       ci_op,
    input  wire                 ci_valid,
    output reg                  ci_ready,
    input  wire [AIDW-1:0]      ci_src,
    input  wire [PW-1:0]        ci_a0,
    input  wire [PW-1:0]        ci_a1,
    input  wire [PW-1:0]        ci_a2,
    input  wire [PW-1:0]        ci_dat,

    // local egress: ack/nak/view responses
    output reg  [OPW-1:0]       lo_op,
    output reg                  lo_valid,
    input  wire                 lo_ready,
    output reg  [AIDW-1:0]      lo_dst,
    output reg  [AIDW-1:0]      lo_src,
    output reg  [PW-1:0]        lo_a0,
    output reg  [PW-1:0]        lo_a1,
    output reg  [PW-1:0]        lo_a2,
    output reg  [PW-1:0]        lo_dat,

    // fabric egress: qm_effect fanout on fire
    output reg  [OPW-1:0]       lx_op,
    output reg                  lx_valid,
    input  wire                 lx_ready,
    output reg  [AIDW-1:0]      lx_dst,
    output reg  [AIDW-1:0]      lx_src,
    output reg  [PW-1:0]        lx_a0,
    output reg  [PW-1:0]        lx_a1,
    output reg  [PW-1:0]        lx_a2,
    output reg  [PW-1:0]        lx_dat,

    // hebbian edge engine array (one q_hebb_edge per slot, in q_cell)
    output reg  [2:0]           hb_cmd,
    output reg  [EDGES_N-1:0]   hb_sel,
    output reg  [PW-1:0]        hb_base,
    output reg  [3:0]           hb_gcl,   // v2: graded class (engine cmd 101)
    input  wire [PW-1:0]        hb_w,
    input  wire                 hb_done,

    // dial file ports
    output reg                  df_wr,
    output reg  [3:0]           df_addr,
    output reg  [PW-1:0]        df_wdata,
    output reg                  df_rd,
    input  wire [PW-1:0]        df_rdata,
    input  wire                 df_rstb,

    // dial fan-in (combinational views from q_dialfile)
    input  wire [3:0]           d_ka,
    input  wire signed [PW-1:0] d_thresh,
    input  wire [PW-1:0]        d_refr,

    // v2 feature dial fan-in
    input  wire [3:0]           d_kle,    // dial 11: echo-trace leak shift
    input  wire [PW-1:0]        d_floor,  // dial 12: gate floor (0 = v1)
    input  wire [3:0]           d_qdw,    // dial 14[3:0]: RQH quanta/credit
    input  wire [3:0]           d_qleak,  // dial 15[3:0]: RQH leak shift
    input  wire                 d_rqen,   // dial 14[15]: RQH master enable

    // scheduler
    input  wire                 s_tick,

    // status
    output reg                  bound,
    output reg  [AIDW-1:0]      cell_id,
    output reg  signed [PW-1:0] act,
    output wire [PW-1:0]        o_ftrace, // v2: echo trace (dial-13 probe)
    output wire                 o_antic  // v2: RQH anticipation strobe
);
    localparam [OPW-1:0] OP_BIND = 3'd0, OP_LINK = 3'd1, OP_EFF  = 3'd2,
                         OP_VIEW = 3'd3, OP_TICK = 3'd4, OP_ACK  = 3'd5,
                         OP_NAK  = 3'd6;

    localparam [4:0] ST_RST  = 5'd0,  ST_UNB  = 5'd1,  ST_IDLE = 5'd2,
                     ST_BIND = 5'd3,  ST_LINK = 5'd4,  ST_LNKW = 5'd5,
                     ST_EFF  = 5'd6,  ST_EFFT = 5'd7,  ST_EFFR = 5'd8,
                     ST_VIEW = 5'd9,  ST_VACC = 5'd10, ST_VACW = 5'd11,
                     ST_VRD  = 5'd12, ST_RESP = 5'd13, ST_TICK = 5'd14,
                     ST_TSW  = 5'd15, ST_TSWW = 5'd16, ST_TLEAK = 5'd17,
                     ST_FIRE = 5'd18, ST_EFFI = 5'd19,
                     ST_EFFP = 5'd20, ST_EFFM = 5'd21;

    reg [4:0]        state;
    reg              tick_pend;
    reg [AIDW-1:0]   lr_src;
    reg [3:0]        lr_a0;
    reg [PW-1:0]     lr_a1, lr_a2, lr_dat;
    reg [PW-1:0]     viewdat;
    reg              resp_nak;
    reg [EIW:0]      eidx;      // one bit wider: EDGES_N sentinel
    // fuzz-fix (backend lane, 2026-08-29, differential-found): wacc was
    // PW+1 bits -- EDGES_N readouts of up to 0xFFFF each sum past 2^(PW+1)
    // (4 edges -> 0x3FFFC) and WRAPPED, so a saturating wsum read small
    // (e.g. 0x20008 -> 0x0008). PW+EIW+1 holds the worst case plus guard;
    // the saturation test takes the whole range above PW.
    reg [PW+EIW:0]   wacc;
    reg [PW-1:0]     refr;
    reg [PW-1:0]     afire;
    reg [PW-1:0]     eff_w;          // pipe stage 1: sat(w + rq_credit)
    reg signed [32:0] eff_p;        // pipe stage 2: eff_w * lr_dat

    reg [AIDW-1:0] etab [0:EDGES_N-1];
    reg            ev   [0:EDGES_N-1];

    // ------------------------------- v2: echo gate + RQH bank ----------
    // fire trace: refill on fire (pulse entering ST_FIRE), leak once per
    // tick service (ST_TLEAK, the same place act leaks -- fire wins the
    // same-cycle ordering by construction: the pulse lands one cycle
    // after the leak strobe of the firing tick).
    reg           eg_fire;
    wire          eg_tick  = (state == ST_TLEAK);
    wire          eg_live;
    wire [3:0]    eg_gclass;

    q_echo_gate #(.PW(PW)) u_eg (
        .clk(clk), .rst_n(rst_n),
        .i_fire(eg_fire), .i_tick(eg_tick),
        .i_kle(d_kle), .i_floor(d_floor),
        .o_f(o_ftrace), .o_live(eg_live), .o_gclass(eg_gclass)
    );

    // residue bank: deposits on graded trains (hb_cmd==101), deadband
    // leak in the tick sweep (hb_cmd==010), credit muxed by hb_sel
    wire          rq_train = (hb_cmd == 3'b101);
    wire          rq_tick  = (hb_cmd == 3'b010);
    wire [PW-1:0] rq_credit;

    q_rqh_bank #(.RW(16), .K(K), .PW(PW),
                 .EDGES_N(EDGES_N), .EIW(EIW)) u_rq (
        .clk(clk), .rst_n(rst_n),
        .i_train(rq_train), .i_tick(rq_tick),
        .i_sel(hb_sel), .i_gclass(hb_gcl),
        .i_qdw(d_qdw), .i_qleak(d_qleak), .i_en(d_rqen),
        .o_credit(rq_credit), .o_antic(o_antic)
    );

    function [PW-1:0] sclip16;  // saturate to Q1.15 full scale, never wrap
        input signed [35:0] v;
        begin
            if (v > 36'sd32767)
                sclip16 = 16'h7FFF;
            else if (v < -36'sd32768)
                sclip16 = 16'h8000;
            else
                sclip16 = v[15:0];
        end
    endfunction

    // effect integration: act += sat((unsigned w * signed dat) >>> 15)
    // v2: the RQH credit folds into the weight first (saturating, never
    // wrap); d_rqen=0 forces credit 0, making this bit-exact v1
    wire [PW:0]   w_rq  = {1'b0, hb_w} + {1'b0, rq_credit};
    wire [PW-1:0] hb_wq = w_rq[PW] ? {PW{1'b1}} : w_rq[PW-1:0];
    wire signed [35:0] act_e  = {{20{act[PW-1]}}, act};
    wire signed [32:0] prod   = $signed({1'b0, hb_wq}) * $signed(lr_dat);
    wire signed [35:0] prod_e = {{3{prod[32]}}, prod};
    wire signed [35:0] eff_sum = act_e + (prod_e >>> 15);
    // PIPE_EFF stage-2 product: registered eff_w times the (stable) effect
    // dat -- the 16x16 multiplier gets its own register-to-register stage
    wire signed [32:0] prod_p = $signed({1'b0, eff_w}) * $signed(lr_dat);
    wire signed [35:0] eff_pe = {{3{eff_p[32]}}, eff_p};   // signed-extend
                                // (a concat is unsigned by rule; the
                                // >>> below needs this named signed wire)
    // tick leak: act = act - (act >>> ka)
    wire signed [35:0] leak_sum = act_e - (act_e >>> d_ka);

    integer i;

    // Flit contract keeps ci_a0 full-width; v1 consumes the low nibble
    // (dial address / edge slot). Upper bits are reserved operands.
    /* verilator lint_off UNUSEDSIGNAL */
    wire [11:0] ci_a0_rsvd = ci_a0[15:4];
    /* verilator lint_on UNUSEDSIGNAL */

    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= ST_RST;
            ci_ready  <= 1'b0;
            lo_valid  <= 1'b0;
            lo_op     <= {OPW{1'b0}};
            lo_dst    <= {AIDW{1'b0}};
            lo_src    <= {AIDW{1'b0}};
            lo_a0     <= {PW{1'b0}};
            lo_a1     <= {PW{1'b0}};
            lo_a2     <= {PW{1'b0}};
            lo_dat    <= {PW{1'b0}};
            lx_valid  <= 1'b0;
            lx_op     <= {OPW{1'b0}};
            lx_dst    <= {AIDW{1'b0}};
            lx_src    <= {AIDW{1'b0}};
            lx_a0     <= {PW{1'b0}};
            lx_a1     <= {PW{1'b0}};
            lx_a2     <= {PW{1'b0}};
            lx_dat    <= {PW{1'b0}};
            hb_cmd    <= 3'b000;
            hb_sel    <= {EDGES_N{1'b0}};
            hb_base   <= {PW{1'b0}};
            hb_gcl    <= 4'd0;
            eg_fire   <= 1'b0;
            df_wr     <= 1'b0;
            df_addr   <= 4'd0;
            df_wdata  <= {PW{1'b0}};
            df_rd     <= 1'b0;
            bound     <= 1'b0;
            cell_id   <= {AIDW{1'b0}};
            act       <= {PW{1'b0}};
            refr      <= {PW{1'b0}};
            eidx      <= {(EIW+1){1'b0}};
            wacc      <= {(PW+EIW+1){1'b0}};
            viewdat   <= {PW{1'b0}};
            resp_nak  <= 1'b0;
            afire     <= {PW{1'b0}};
            lr_src    <= {AIDW{1'b0}};
            lr_a0     <= 4'd0;
            lr_a1     <= {PW{1'b0}};
            lr_a2     <= {PW{1'b0}};
            lr_dat    <= {PW{1'b0}};
            eff_w     <= {PW{1'b0}};
            eff_p     <= 33'sd0;
            for (i = 0; i < EDGES_N; i = i + 1) begin
                etab[i] <= {AIDW{1'b0}};
                ev[i]   <= 1'b0;
            end
        end else begin
            // single-cycle strobes default low. hb_sel is intentionally
            // NOT pulsed: the engine's readout takes K+1 cycles and the
            // returning hb_w must stay muxed to the active slot until done.
            df_wr    <= 1'b0;
            df_rd    <= 1'b0;
            hb_cmd   <= 3'b000;
            eg_fire  <= 1'b0;
            lo_valid <= 1'b0;
            lx_valid <= 1'b0;

            case (state)
              // ---------------------------------------------- reset ---
              ST_RST: state <= ST_UNB;

              // ------------------- wait for first bind (any flit) ---
              ST_UNB: begin
                  ci_ready <= 1'b1;
                  if (ci_valid && ci_ready) begin
                      lr_src <= ci_src;
                      lr_a2  <= ci_a2;
                      if (ci_op == OP_BIND) begin
                          cell_id  <= ci_a0[AIDW-1:0];
                          bound    <= 1'b1;
                          resp_nak <= 1'b0;
                      end else begin
                          resp_nak <= 1'b1;  // not bound: nak
                      end
                      viewdat  <= {PW{1'b0}};
                      ci_ready <= 1'b0;
                      state    <= ST_RESP;
                  end
              end

              // --------------------------------------------- dispatch ---
              ST_IDLE: begin
                  if (tick_pend) begin
                      // Q2 hard deadline: service before any new ingress
                      ci_ready <= 1'b0;
                      hb_sel   <= {EDGES_N{1'b0}};
                      state    <= ST_TICK;
                  end else begin
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      hb_sel   <= {EDGES_N{1'b0}};
                      if (ci_valid && ci_ready) begin

                          lr_src <= ci_src;
                          lr_a0  <= ci_a0[3:0];
                          lr_a1  <= ci_a1;
                          lr_a2  <= ci_a2;
                          lr_dat <= ci_dat;
                          ci_ready <= 1'b0;
                          case (ci_op)
                            OP_BIND: state <= ST_BIND;
                            OP_LINK: state <= ST_LINK;
                            OP_EFF:  state <= ST_EFF;
                            OP_VIEW: state <= ST_VIEW;
                            OP_ACK, OP_NAK, OP_TICK:
                                     state <= ST_IDLE;  // consumed, no action
                            default: begin
                                resp_nak <= 1'b1;
                                viewdat  <= {PW{1'b0}};
                                state    <= ST_RESP;
                            end
                          endcase
                      end
                  end
              end

              // bind = dial write (or first-bind, handled in ST_UNB) -------
              ST_BIND: begin
                  df_wr    <= 1'b1;
                  df_addr  <= lr_a0;
                  df_wdata <= lr_a1;
                  resp_nak <= 1'b0;
                  viewdat  <= {PW{1'b0}};
                  state    <= ST_RESP;
              end

              // link = edge slot {peer=src, base=a1} -----------------------
              ST_LINK: begin
                  etab[lr_a0[EIW-1:0]] <= lr_src;
                  ev  [lr_a0[EIW-1:0]] <= 1'b1;
                  hb_sel   <= 1'b1 << lr_a0[EIW-1:0];
                  hb_cmd   <= 3'b100;            // set base in the engine
                  hb_base  <= lr_a1;
                  state    <= ST_LNKW;
              end
              ST_LNKW: begin
                  if (hb_done) begin
                      resp_nak <= 1'b0;
                      viewdat  <= {PW{1'b0}};
                      state    <= ST_RESP;
                  end
              end

              // effect: scan edge table for src -----------------------------
              ST_EFF: begin
                  eidx  <= {(EIW+1){1'b0}};
                  state <= ST_EFFT;
              end
              ST_EFFT: begin
                  if (eidx == EDGES_N) begin
                      // unknown source: dropped (link before effect)
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      state    <= ST_IDLE;
                  end else if (ev[eidx[EIW-1:0]] && (etab[eidx[EIW-1:0]] == lr_src)) begin
                      hb_sel <= 1'b1 << eidx[EIW-1:0];
                      // v2 echo gate: a cofire counts only if this cell
                      // fired recently (loop closure before potentiation).
                      // FLOOR=0 disables: live always, class 0, and cmd 101
                      // degenerates to the exact v1 cmd-001 train.
                      if (eg_live) begin
                          hb_cmd <= 3'b101;          // graded cofire train
                          hb_gcl <= eg_gclass;       // bucket 15 - msb(F)
                          state  <= ST_EFFR;
                      end else begin
                          hb_cmd <= 3'b011;          // gate closed: skip the
                          state  <= (PIPE_EFF != 0) ? ST_EFFP : ST_EFFI;
                                                      // train, read + integrate
                      end                             // act as usual (ungated)
                  end else begin
                      eidx <= eidx + 1'b1;
                  end
              end
              ST_EFFR: begin
                  if (hb_done) begin
                      hb_cmd <= 3'b011;          // weight readback
                      state  <= (PIPE_EFF != 0) ? ST_EFFP : ST_EFFI;
                  end
              end
              // PIPE_EFF stage 1: readback done -- register the credited
              // weight sat(w + rq_credit); cuts the credit-add + readout-mux
              // cone out of the multiplier path (SYNTHESIS-FPGA round 3)
              ST_EFFP: begin
                  if (hb_done) begin
                      eff_w <= hb_wq;
                      state <= ST_EFFM;
                  end
              end
              // PIPE_EFF stage 2: the 16x16 multiply against the (stable)
              // lr_dat, registered on its own stage
              ST_EFFM: begin
                  eff_p <= prod_p;
                  state <= ST_EFFI;
              end
              ST_EFFI: begin
                  // readout done: integrate with the post-update weight.
                  // PIPE_EFF: hb_done pulsed in ST_EFFP (consumed by the
                  // eff_w capture); the pipelined tail completes now.
                  if ((PIPE_EFF != 0) || hb_done) begin
                      act      <= sclip16((PIPE_EFF != 0)
                                  ? (act_e + (eff_pe >>> 15))
                                  : eff_sum);
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      state    <= ST_IDLE;
                  end
              end

              // view -------------------------------------------------------
              ST_VIEW: begin
                  if (!bound) begin
                      resp_nak <= 1'b1;
                      viewdat  <= {PW{1'b0}};
                      state    <= ST_RESP;
                  end else begin
                      case (lr_a0[1:0])
                        2'd0: begin
                            viewdat <= {PW{1'b0}} | act;
                            resp_nak <= 1'b0;
                            state   <= ST_RESP;
                        end
                        2'd1: begin
                            wacc  <= {(PW+EIW+1){1'b0}};
                            eidx  <= {(EIW+1){1'b0}};
                            state <= ST_VACC;
                        end
                        2'd2: begin
                            df_rd   <= 1'b1;
                            df_addr <= lr_a1[3:0];
                            state   <= ST_VRD;
                        end
                        default: begin // 3: cosine not provisioned in v1
                            resp_nak <= 1'b1;
                            viewdat  <= {PW{1'b0}};
                            state    <= ST_RESP;
                        end
                      endcase
                  end
              end
              ST_VACC: begin
                  if (eidx == EDGES_N) begin
                      viewdat  <= (|wacc[PW+EIW:PW]) ? {PW{1'b1}}
                                                    : wacc[PW-1:0];
                      resp_nak <= 1'b0;
                      state    <= ST_RESP;
                  end else if (ev[eidx[EIW-1:0]]) begin
                      hb_sel <= 1'b1 << eidx[EIW-1:0];
                      hb_cmd <= 3'b011;            // readout
                      state  <= ST_VACW;
                  end else begin
                      eidx <= eidx + 1'b1;
                  end
              end
              ST_VACW: begin
                  if (hb_done) begin
                      wacc <= wacc + {{EIW{1'b0}}, hb_w}
                                    + {{EIW{1'b0}}, rq_credit};
                      eidx <= eidx + 1'b1;
                      state <= ST_VACC;
                  end
              end
              ST_VRD: begin
                  if (df_rstb) begin
                      viewdat  <= df_rdata;
                      resp_nak <= 1'b0;
                      state    <= ST_RESP;
                  end
              end

              // one response flit to the requester --------------------------
              ST_RESP: begin
                  lo_op    <= resp_nak ? OP_NAK : OP_ACK;
                  lo_valid <= 1'b1;
                  lo_dst   <= lr_src;
                  lo_src   <= cell_id;
                  lo_a0    <= {PW{1'b0}};
                  lo_a1    <= {PW{1'b0}};
                  lo_a2    <= lr_a2;     // echo caller's a2 (correlation)
                  lo_dat   <= viewdat;
                  if (lo_valid && lo_ready) begin
                      lo_valid <= 1'b0;
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      // wedge fix (silicon lane, 2026-08-30, found by
                      // sim/vlt/tb_scale_vlt.cpp + tb/tb_wedge_repro.v on
                      // iverilog AND verilator): ST_RESP used to fall back
                      // to ST_IDLE unconditionally, so ONE non-bind flit
                      // delivered to an unbound cell (e.g. a peer's link
                      // ACK/NAK when linking before the peer is bound)
                      // kicked it out of ST_UNB forever -- every later
                      // bind executed as a dial write AND ACKED SUCCESS
                      // (silent misconfig; cell_id never set, views NAK
                      // forever). Return to ST_UNB while uncommissioned.
                      state    <= bound ? ST_IDLE : ST_UNB;
                  end
              end

              // tick: decay sweep over edges -------------------------------
              ST_TICK: begin
                  eidx  <= {(EIW+1){1'b0}};
                  state <= ST_TSW;
              end
              ST_TSW: begin
                  if (eidx == EDGES_N) begin
                      state <= ST_TLEAK;
                  end else if (ev[eidx[EIW-1:0]]) begin
                      hb_sel <= 1'b1 << eidx[EIW-1:0];
                      hb_cmd <= 3'b010;            // advance decay one tick
                      state  <= ST_TSWW;
                  end else begin
                      eidx <= eidx + 1'b1;
                  end
              end
              ST_TSWW: begin
                  if (hb_done) begin
                      eidx <= eidx + 1'b1;
                      state <= ST_TSW;
                  end
              end

              // leak activation, then fire test ------------------------------
              ST_TLEAK: begin
                  act <= sclip16(leak_sum);
                  if ((act >= d_thresh) && (refr == {PW{1'b0}})) begin
                      afire   <= act;
                      eidx    <= {(EIW+1){1'b0}};
                      eg_fire <= 1'b1;            // v2: refill the echo trace
                      state   <= ST_FIRE;
                  end else begin
                      if (refr != {PW{1'b0}})
                          refr <= refr - 1'b1;
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      state    <= ST_IDLE;
                  end
              end

              // fan out effects to valid edge peers --------------------------
              ST_FIRE: begin
                  if (eidx == EDGES_N) begin
                      act      <= {PW{1'b0}};
                      refr     <= d_refr;
                      ci_ready <= !(s_tick || tick_pend);  // Q2fix: never offer ready with a tick pending (or being set) -- a one-cycle hole here lets an upstream pipe pop a flit the dispatching FSM ignores (silent drop, found by formal cell_core.tick/fabric.conservation)
                      state    <= ST_IDLE;
                  end else if (ev[eidx[EIW-1:0]]) begin
                      lx_op    <= OP_EFF;
                      lx_valid <= 1'b1;
                      lx_dst   <= etab[eidx[EIW-1:0]];
                      lx_src   <= cell_id;
                      lx_dat   <= afire;
                      lx_a0    <= {PW{1'b0}};
                      lx_a1    <= {PW{1'b0}};
                      lx_a2    <= {PW{1'b0}};
                      if (lx_valid && lx_ready) begin
                          lx_valid <= 1'b0;
                          eidx     <= eidx + 1'b1;
                      end
                  end else begin
                      eidx <= eidx + 1'b1;
                  end
              end

              default: state <= ST_IDLE;
            endcase
        end
    end

    // Q2 interlock: the tick deadline register. s_tick latches from any
    // state; cleared exactly when ST_IDLE begins servicing it.
    always @(posedge clk) begin
        if (!rst_n)
            tick_pend <= 1'b0;
        else if (s_tick)
            tick_pend <= 1'b1;
        else if (state == ST_IDLE && tick_pend)
            tick_pend <= 1'b0;
    end

endmodule
