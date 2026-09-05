// q_boot_gate.v -- commissioning gate for the serialized fabric front-end
// in flit mode (quilt-verilog v2.1, pin-fix lane).
//
// rtl/quf_boot.v's FSM discipline, lifted without its parser: byte-stream
// ingress, fail-static, latch-once epoch. Where quf_boot eats a whole QUF
// container (1.5k LUT of parser next to it), this gate eats exactly two
// bytes -- the release word 0x51 0x46 ("QF") -- and exists for the
// devices where the parser does not fit next to even one cell (UP5K:
// loader 1488 LUT + 1-cell fabric 3958 LC > 5280). In that mode the QUF
// parse runs host-side (rtl/q_uf_loader.v is pure portable Verilog; the
// reference implementation tools/quf.py already proves the format), and
// cell configuration streams over the SAME narrow port as qm_bind flits
// -- the documented runtime dial path. The gate keeps what the boot
// discipline actually buys:
//
//   * the fabric is FSM-frozen until the host says go (deterministic
//     run start; the host owns commissioning order),
//   * a wrong word is a sticky HOLD_ERR (err 11) -- never a half-live
//     fabric; recovery is POR, same as quf_boot,
//   * the tick exponent (TPW0 parameter) latches ONCE at release:
//     Q2 deadline semantics against a stable epoch, refused by
//     construction,
//   * o_brdy depends only on local state (skid discipline).
//
// State encoding matches quf_boot exactly (o_state is a status contract):
// POR 0 / HOLD 1 / LOAD 2 / LATCH 3 / REL 4 / RUN 5 / HOLD_ERR 6.
// E_TRUNC(10) is raised on i_eod before the word completes (stream cut
// mid-word -> fail-static, same taxonomy as quf_boot).
module q_boot_gate #(
    parameter [4:0] TPW0 = 5'd6      // epoch tick exponent, latched once
)(
    input  wire               clk,
    input  wire               rst_n,      // POR

    input  wire               i_bval,
    output wire               o_brdy,
    input  wire [7:0]         i_byte,
    input  wire               i_eod,

    output wire [4:0]         o_tpw,      // latched at release
    output wire               o_epoch,    // 1-cycle pulse entering RUN
    output wire               o_rst_n,    // fabric reset: low until RUN
    output wire               o_boot_ok,  // 1-cycle pulse entering RUN
    output wire [2:0]         o_state,
    output wire [7:0]         o_err       // sticky; 10 trunc, 11 bad word
);
    localparam [7:0] E_TRUNC = 8'd10, E_WORD = 8'd11;
    localparam [7:0] W0 = 8'h51, W1 = 8'h46;   // 'Q', 'F'

    localparam [2:0] S_POR = 3'd0, S_HOLD = 3'd1, S_LOAD = 3'd2,
                     S_LATCH = 3'd3, S_REL = 3'd4, S_RUN = 3'd5,
                     S_HERR = 3'd6;

    reg [2:0] state;
    reg [7:0] err_q;
    reg [4:0] tpw_q;
    reg       boot_ok_q, epoch_q;

    // taking: the word bytes; discard: everything after (quf_boot's
    // end-of-stream rule -- stalling the host on residue would wedge it)
    wire taking  = (state == S_HOLD) || (state == S_LOAD);
    wire discard = (state == S_RUN)  || (state == S_HERR) ||
                   (state == S_LATCH) || (state == S_REL);

    assign o_brdy = taking || discard;   // local-only ready

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
                  if (i_eod && !i_bval) begin
                      err_q <= E_TRUNC;          // empty stream cut
                      state <= S_HERR;
                  end else if (i_bval && o_brdy) begin
                      if (i_byte == W0) state <= S_LOAD;
                      else begin
                          err_q <= E_WORD;       // not a release word
                          state <= S_HERR;
                      end
                  end
              end
              S_LOAD: begin
                  if (i_eod && !i_bval) begin
                      err_q <= E_TRUNC;          // cut mid-word
                      state <= S_HERR;
                  end else if (i_bval && o_brdy) begin
                      if (i_byte == W1) state <= S_LATCH;
                      else begin
                          err_q <= E_WORD;
                          state <= S_HERR;
                      end
                  end
              end
              S_LATCH: begin
                  tpw_q <= TPW0;                 // latch-ONCE-at-release
                  state <= S_REL;
              end
              S_REL: begin
                  epoch_q   <= 1'b1;
                  boot_ok_q <= 1'b1;
                  state     <= S_RUN;
              end
              S_RUN: begin
                  // steady state: bytes below belong to the flit
                  // deserializer; the gate is done and silent
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
