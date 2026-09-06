// quf_boot.v -- boot harness: QUF byte stream -> cell state -> release
// (quilt-verilog v2.1, FPGA round 3; design docs/FPGA-BOOT.md §2, built on
// the proven rtl/q_uf_loader.v).
//
// Boot model (one paragraph, docs/FPGA-BOOT.md §1): power-on holds the
// fabric cores in reset while the loader consumes a QUF container and
// writes state through its ports; on clean done the harness latches the
// tick exponent (latch-ONCE-at-release: Q2's deadline semantics are
// defined against a stable epoch), pulses BOOT_OK, and releases the
// fabric. On ANY error the FSM parks sticky in HOLD_ERR with the fabric
// frozen -- the fabric is never booted into a half-image; recovery is POR
// (fail-static: the dialfile re-defaults at POR, so a failed boot leaves
// the bit-exact v1 configuration, never a partial QUF image).
//
// FSM:
//   POR -> HOLD -> LOAD -> LATCH -> RELEASE -> RUN
//               |    ^-(o_err!=0 / truncation)   |
//               +----+-> HOLD_ERR (sticky)       |
// Reset topology (the load-bearing detail): this module drives o_rst_n
// (the FABRIC reset: cores, pipes, tick scheduler). The dialfile/edge/
// route memories are NOT reset by o_rst_n -- they are POR-reset only
// (their rst_n is the same POR as this module), because q_dialfile holds
// its defaults under reset: boot writes must land while the fabric is
// frozen, and a failed boot must leave the POR defaults intact.
//
// Interfaces:
//   * byte-stream ingress i_bval/i_byte/o_brdy + i_eod (transport shim:
//     UART pairing happens upstream; bytes little-endian, low first, and
//     the QUF writer's align>=8 padding guarantees whole words). o_brdy
//     depends only on local state (skid discipline; the 1-word skid
//     absorbs the loader's 1-in-3 backpressure with zero ready chains).
//   * runtime dial-write port i_qm_* (qm_bind): muxed against the boot
//     dial writes with EXCLUSION BY CONSTRUCTION (doc §4): the boot port
//     is strobed only while the fabric is frozen in reset, so the two
//     write sources can never collide -- no arbitration, no bypass.
//   * epoch: o_tpw latches once at LATCH; after RELEASE it is frozen for
//     the run (changing cadence mid-run is a spec change, refused by
//     construction). o_epoch pulses once at RELEASE->RUN.
//
// Cost target ~300 LC (doc §9). Pure Verilog-2005, no vendor primitives.
module quf_boot #(
    parameter AIDW = 4
)(
    input  wire               clk,
    input  wire               rst_n,      // POR (this module + state RAMs)

    // byte-stream transport (docs/FPGA-BOOT.md §3)
    input  wire               i_bval,
    output wire               o_brdy,
    input  wire [7:0]         i_byte,
    input  wire               i_eod,      // transport end-of-stream strobe

    // which cell's dial row / edge records this instance claims
    input  wire [AIDW-1:0]    i_mycell,

    // runtime dial writes (qm_bind path) -- live only in RUN
    input  wire               i_qm_wr,
    input  wire [3:0]         i_qm_addr,
    input  wire [15:0]        i_qm_wdata,

    // dialfile port (the fabric's single sync write port, muxed here)
    output wire               o_df_wr,
    output wire [3:0]         o_df_addr,
    output wire [15:0]        o_df_wdata,

    // loader passthrough: edge / route RAM writes (fabric-global)
    output wire               o_edge_wr,
    output wire [3:0]         o_edge_addr,
    output wire [31:0]        o_edge_data,
    output wire               o_route_wr,
    output wire [3:0]         o_route_dst,
    output wire [3:0]         o_route_via,

    // epoch: tick period exponent, latched once at LATCH
    output wire [4:0]         o_tpw,
    output wire               o_epoch,    // 1-cycle pulse at release

    // fabric control + status
    output wire               o_rst_n,    // fabric reset (cores/pipes/sched)
    output wire               o_boot_ok,  // 1-cycle pulse entering RUN
    output wire [2:0]         o_state,
    output wire [7:0]         o_err       // sticky; 10 = truncated stream
);
    localparam [7:0] E_TRUNC = 8'd10;

    localparam [2:0] S_POR = 3'd0, S_HOLD = 3'd1, S_LOAD = 3'd2,
                     S_LATCH = 3'd3, S_REL = 3'd4, S_RUN = 3'd5,
                     S_HERR = 3'd6;

    reg [2:0] state;
    reg [7:0] err_q;        // sticky error (loader code or E_TRUNC)
    reg [4:0] tpw_q;        // the epoch latch (frozen after LATCH)
    reg       boot_ok_q, epoch_q;

    // ---------------- byte pairer + 1-word skid ------------------------
    reg        bphase;      // 0 = collecting low byte, 1 = high pending
    reg [7:0]  blo;
    reg        wvalid;      // a full 16-bit word is buffered
    reg [15:0] wbuf;

    // loader instance (byte-stream -> parsed state writes)
    wire       ld_rdy;
    wire       ld_dial_wr;
    wire [3:0] ld_dial_addr;
    wire [15:0] ld_dial_wdata;
    wire       ld_edge_wr;
    wire [3:0] ld_edge_addr;
    wire [31:0] ld_edge_data;
    wire       ld_route_wr;
    wire [3:0] ld_route_dst;
    wire [3:0] ld_route_via;
    wire [4:0] ld_tpw;
    wire       ld_done;
    wire [7:0] ld_err;

    // loader reset discipline: released in HOLD/LOAD/LATCH (it must hold
    // its parse state across those), re-frozen in RUN/HOLD_ERR so its
    // outputs are provably quiesced and the datapath is bypassed
    reg loading_present_q;

    wire       loading = (state == S_LOAD);
    // the pairer runs in HOLD too: the first byte that trips HOLD->LOAD
    // is container byte 0 and must land in the pairer, not be swallowed
    wire       taking = (state == S_HOLD) || loading;
    // after done (LATCH onward) or on HOLD_ERR: the QUF writer's align
    // padding (and any transport residue) is accepted and DISCARDED --
    // the loader is finished; stalling the transport on residue would
    // wedge the host (the QUF TB has the same end-of-stream rule)
    wire       discard = (state == S_LATCH) || (state == S_REL) ||
                         (state == S_RUN)  || (state == S_HERR);

    // local-only ready: never a function of upstream ready
    assign o_brdy = (taking && ((bphase == 1'b0) || !wvalid)) || discard;

    always @(posedge clk) begin
        if (!rst_n) begin
            bphase <= 1'b0;
            blo    <= 8'd0;
            wvalid <= 1'b0;
            wbuf   <= 16'd0;
        end else if (taking) begin
            if (wvalid && ld_rdy)
                wvalid <= 1'b0;              // word drained into loader
            // (ld_done mid-pair: leave bphase/wvalid to the discard state)
            if (i_bval && o_brdy) begin
                if (bphase == 1'b0) begin
                    blo    <= i_byte;
                    bphase <= 1'b1;
                end else begin
                    wbuf   <= {i_byte, blo}; // little-endian: low first
                    wvalid <= 1'b1;
                    bphase <= 1'b0;
                end
            end
        end else if (discard) begin
            wvalid <= 1'b0;                  // residue drained, dropped
            bphase <= 1'b0;
        end else begin
            wvalid <= 1'b0;
            bphase <= 1'b0;
        end
    end

    q_uf_loader #(.AIDW(AIDW)) u_ld (
        .clk(clk), .rst_n(rst_n && loading_present_q),
        .i_val(wvalid && loading), .o_rdy(ld_rdy), .i_dat(wbuf),
        .i_mycell(i_mycell),
        .o_dial_wr(ld_dial_wr), .o_dial_addr(ld_dial_addr),
        .o_dial_wdata(ld_dial_wdata),
        .o_edge_wr(ld_edge_wr), .o_edge_addr(ld_edge_addr),
        .o_edge_data(ld_edge_data),
        .o_route_wr(ld_route_wr), .o_route_dst(ld_route_dst),
        .o_route_via(ld_route_via),
        .o_tick_tpw(ld_tpw),
        .o_done(ld_done), .o_err(ld_err)
    );

    always @(posedge clk)
        if (!rst_n)
            loading_present_q <= 1'b0;
        else
            loading_present_q <= (state == S_HOLD) || (state == S_LOAD) ||
                                (state == S_LATCH);

    // ---------------- dial port mux: exclusion by construction ---------
    // boot writes strobe only while the fabric is frozen (S_LOAD/S_LATCH:
    // the cores cannot emit a bind in reset), qm writes only in RUN --
    // the windows are disjoint FSM states, not arbitrated priorities
    assign o_df_wr   = ((state == S_LOAD) || (state == S_LATCH))
                         ? ld_dial_wr
                         : ((state == S_RUN) ? i_qm_wr : 1'b0);
    assign o_df_addr = ((state == S_LOAD) || (state == S_LATCH))
                         ? ld_dial_addr : i_qm_addr;
    assign o_df_wdata = ((state == S_LOAD) || (state == S_LATCH))
                         ? ld_dial_wdata : i_qm_wdata;

    assign o_edge_wr   = ld_edge_wr;
    assign o_edge_addr = ld_edge_addr;
    assign o_edge_data = ld_edge_data;
    assign o_route_wr  = ld_route_wr;
    assign o_route_dst = ld_route_dst;
    assign o_route_via = ld_route_via;

    // ---------------- the FSM -------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= S_POR;
            err_q     <= 8'd0;
            tpw_q     <= 5'd0;
            boot_ok_q <= 1'b0;
            epoch_q   <= 1'b0;
        end else begin
            boot_ok_q <= 1'b0;
            epoch_q   <= 1'b0;
            case (state)
              S_POR: state <= S_HOLD;
              S_HOLD: begin
                  // host handshake may live here (§5); any byte starts us
                  if (i_bval) state <= S_LOAD;
              end
              S_LOAD: begin
                  if (ld_done && ld_err == 8'd0)
                      state <= S_LATCH;          // clean end of container
                  else if (ld_err != 8'd0) begin
                      err_q <= ld_err;           // loader taxonomy (1-9)
                      state <= S_HERR;
                  end else if (i_eod) begin
                      err_q <= E_TRUNC;          // stream ended mid-file
                      state <= S_HERR;
                  end
                  // else: keep streaming (host owns completion; no timeout)
              end
              S_LATCH: begin
                  tpw_q <= ld_tpw;               // latch-ONCE-at-release
                  state <= S_REL;
              end
              S_REL: begin
                  epoch_q <= 1'b1;               // tick epoch starts at 0
                  boot_ok_q <= 1'b1;
                  state  <= S_RUN;
              end
              S_RUN: begin
                  // steady state: fabric runs; loader bypassed; tpw frozen
              end
              S_HERR: begin
                  // sticky: status readable, no release, retry by POR
              end
              default: state <= S_HOLD;
            endcase
        end
    end

    assign o_tpw     = tpw_q;
    assign o_epoch   = epoch_q;
    assign o_rst_n   = (state == S_RUN);
    assign o_boot_ok = boot_ok_q;
    assign o_state   = state;
    assign o_err     = err_q;

endmodule
