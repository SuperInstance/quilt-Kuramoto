// q_hebb_edge.v -- hebbian_edge_update, one edge (quilt-verilog v1).
// Two decay engines behind one interface (scorecard steal 1):
//   MODE=0 (glm ladder): K bucket counters of B bits; a cofire increments
//     bucket 0 (saturating, sticky o_ovf); each half-life (i_hl ticks) the
//     ladder shifts one class older. Bucket i carries implied weight 2^-i.
//     Readout W-hat = sum_i C_i * 2^-i via a REGISTERED sequential loop
//     (adder tree restructured per scorecard fix list: no UNOPTFLAT).
//     Proven bound: W_exact <= W-hat <= 2*W_exact.
//     Readout scale: bucket i is placed at bit offset (K-i) in a
//     (K+B+1)-bit accumulator, so one fresh cofire reads 2^{K}... with
//     K=8,B=8: fresh cofire = 256, and the sum saturates at PW bits
//     (saturate-never-wrap). Weight map in docs/SYNTHESIS.md.
//   MODE=1 (zeroclaw hyperbola): integer W + age. Each tick: age++; when
//     age >= P0 >> (2*msb(W)) (floor 1) and W>0: W--, age=0. Integrates to
//     W(t) = W0/(1+W0*t/P0) with interval within [1,4)x the exact P0/W^2.
// Readout scale (docs/SYNTHESIS.md): top PW bits of the K*B adder word, so
// one fresh cofire (K=8,B=8) reads 2^8=256; hyperbolic W reads W*256 (sat).
// o_w = saturate(base + engine_readout). Integer state throughout: the
// state is never fixed-point, so it never drifts (zeroclaw §2.1 rule 6).
// Commands (i_sel && i_cmd): 001=train, 010=tick, 011=read, 100=set-base,
//   101=graded train (v2 echo gate): ladder mode lands the cofire in
//   bucket clamp(i_gclass, K-1) instead of bucket 0 -- an event born
//   g trace half-lives old, the same object the staircase bound covers;
//   hyperbola mode is identical to 001 (the gate is binary in MODE=1).
//   cmd 001 keeps its exact v1 semantics: the graded path is a NEW
//   engine command, not a rewiring of the old one, so existing cores/TBs
//   that never issue 101 (or leave i_gclass unconnected) are bit-exact.
module q_hebb_edge #(
    parameter PW   = 16,
    parameter K    = 8,   // ladder buckets
    parameter B    = 8,   // bits per bucket
    parameter AGEW = 24   // hyperbola age counter width
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          i_sel,
    input  wire [2:0]    i_cmd,
    input  wire          i_mode,
    input  wire [PW-1:0] i_base,
    input  wire [PW-1:0] i_hl,
    input  wire [4:0]    i_p0e,
    input  wire [3:0]    i_gclass,   // v2: graded-train bucket (cmd 101 only)
    output reg           o_done,
    output reg  [PW-1:0] o_w,
    output reg           o_ovf    // sticky: train-time saturation
);
    localparam AW = K + B + 1;   // readout accumulator width

    // priority encode of W (hyperbolic interval exponent)
    function [3:0] msb16;
        input [PW-1:0] v;
        integer j;
        begin
            msb16 = 4'd0;
            for (j = 0; j < PW; j = j + 1)
                if (v[j] == 1'b1)
                    msb16 = j[3:0];
        end
    endfunction

    // ladder state
    reg [B-1:0]  c    [0:K-1];
    reg [PW-1:0] hl_cnt;
    // hyperbolic state
    reg [PW-1:0]   wh;
    reg [AGEW-1:0] age;
    // shared
    reg [PW-1:0]  base;
    // readout sequencer
    reg           rstate;
    reg [4:0]     ridx;
    reg [AW-1:0]  acc;

    integer j;

    // hyperbolic interval: P0 >> 2*msb(W), floored at 1
    wire [3:0]  wmsb  = msb16(wh);

    // graded-train placement: clamp class to K-1 (bucket index width safe)
    localparam [3:0] K4 = K;
    wire [3:0]  gcl   = (i_gclass >= K4) ? (K4 - 4'd1) : i_gclass;
    wire [4:0]  shl2  = {1'b0, wmsb} + {1'b0, wmsb};
    wire [31:0] p0    = 32'd1 << i_p0e;
    wire [31:0] ivr   = p0 >> shl2;
    wire [31:0] ival  = (ivr == 32'd0) ? 32'd1 : ivr;
    wire [31:0] agen  = {8'd0, age} + 32'd1;
    wire        decn  = (wh != {PW{1'b0}}) && (agen >= ival);

    // ladder half-life compare (i_hl >= 1 by dial contract)
    wire [PW:0] hlc   = {1'b0, hl_cnt} + {{(PW+1-16){1'b0}}, 16'd1};
    wire [PW:0] hlth  = {1'b0, i_hl};
    wire        hlend = (hlc >= hlth);

    // readout addend: bucket ridx carries weight 2^-ridx: placed at bit
    // offset (K - ridx) so adjacent buckets differ by one power of two
    localparam IIW = (K <= 2) ? 1 : (K <= 4) ? 2 : (K <= 8) ? 3 : 4;
    wire [31:0]   ridx32 = {27'd0, ridx};
    wire [31:0]   rsh = K - ridx32;
    wire [AW-1:0] addw = {{(AW-B){1'b0}}, c[ridx[IIW-1:0]]} << rsh;

    // readout value of the active engine (saturating top PW bits / W*256)
    // (round-3 fix: K=4/B=4-class configs have AW = K+B+1 < PW -- the
    // saturate-and-take-top-PW collapse must widen instead of truncate;
    // iverilog rejects the old acc[AW-1:PW] part select outright there)
    wire [PW-1:0] lad;
    generate
        if (AW > PW) begin : g_lad_sat
            wire sat = |acc[AW-1:PW];
            assign lad = sat ? {PW{1'b1}} : acc[PW-1:0];
        end else begin : g_lad_wide
            assign lad = {{(PW-AW){1'b0}}, acc};
        end
    endgenerate
    wire [PW-1:0] whs  = (wh > 16'd255) ? 16'hFFFF : {wh[7:0], 8'h00};
    wire [PW-1:0] eng  = i_mode ? whs : lad;
    wire [PW:0]   wfin = {1'b0, base} + {1'b0, eng};
    wire [PW-1:0] wout = wfin[PW] ? {PW{1'b1}} : wfin[PW-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            o_done  <= 1'b0;
            o_w     <= {PW{1'b0}};
            o_ovf   <= 1'b0;
            for (j = 0; j < K; j = j + 1)
                c[j] <= {B{1'b0}};
            hl_cnt  <= {PW{1'b0}};
            wh      <= {PW{1'b0}};
            age     <= {AGEW{1'b0}};
            base    <= {PW{1'b0}};
            rstate  <= 1'b0;
            ridx    <= 5'd0;
            acc     <= {AW{1'b0}};
        end else begin
            o_done <= 1'b0;
            // readout sequencer has priority over new commands: an active
            // read must complete even while i_sel is held high with no cmd
            if (rstate) begin
                if (ridx == K) begin
                    o_w    <= wout;
                    o_done <= 1'b1;
                    rstate <= 1'b0;
                end else begin
                    acc <= acc + addw;
                    ridx <= ridx + 5'd1;
                end
            end else if (i_sel) begin
                case (i_cmd)
                  3'b001: begin // train (cofire potentiation)
                    if (!i_mode) begin
                        if (c[0] == {B{1'b1}})
                            o_ovf <= 1'b1;
                        else
                            c[0] <= c[0] + 1'b1;
                    end else begin
                        if (wh == {PW{1'b1}})
                            o_ovf <= 1'b1;
                        else
                            wh <= wh + 1'b1;
                    end
                    o_done <= 1'b1;
                  end
                  3'b101: begin // graded train (v2 echo gate, opencode §4.2)
                    if (!i_mode) begin
                        if (gcl >= K4) begin
                            if (c[K-1] == {B{1'b1}})
                                o_ovf <= 1'b1;
                            else
                                c[K-1] <= c[K-1] + 1'b1;
                        end else begin
                            if (c[gcl[IIW-1:0]] == {B{1'b1}})
                                o_ovf <= 1'b1;
                            else
                                c[gcl[IIW-1:0]] <= c[gcl[IIW-1:0]] + 1'b1;
                        end
                    end else begin
                        // hyperbola: no fractional buckets; binary gate only
                        if (wh == {PW{1'b1}})
                            o_ovf <= 1'b1;
                        else
                            wh <= wh + 1'b1;
                    end
                    o_done <= 1'b1;
                  end
                  3'b010: begin // tick (advance decay one tick)
                    if (!i_mode) begin
                        if (hlend) begin
                            for (j = K-1; j > 0; j = j - 1)
                                c[j] <= c[j-1];
                            c[0]    <= {B{1'b0}};
                            hl_cnt  <= {PW{1'b0}};
                        end else begin
                            hl_cnt <= hl_cnt + 1'b1;
                        end
                    end else begin
                        if (decn) begin
                            wh  <= wh - 1'b1;
                            age <= {AGEW{1'b0}};
                        end else begin
                            age <= age + 1'b1;
                        end
                    end
                    o_done <= 1'b1;
                  end
                  3'b100: begin // set bind-time base weight
                    base   <= i_base;
                    o_done <= 1'b1;
                  end
                  3'b011: begin // readout (sequenced, K+1 cycles)
                    ridx   <= 5'd0;
                    acc    <= {AW{1'b0}};
                    rstate <= 1'b1;
                  end
                  default: begin
                    // no command: nothing
                  end
                endcase
            end
        end
    end

endmodule
