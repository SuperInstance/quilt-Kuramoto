// q_tick_sched.v -- tick strobe generator (quilt-verilog v1).
// Free-running; one-cycle strobe every 2^TPW cycles. v1 single-clock
// backstop per docs/SYNTHESIS.md Q2 (the socratic "epoch reference"
// reading; GALS/metronome-cell forms are v2).
module q_tick_sched #(
    parameter TPW = 8
)(
    input  wire clk,
    input  wire rst_n,
    output reg  o_tick
);
    reg [TPW-1:0] cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt    <= {TPW{1'b0}};
            o_tick <= 1'b0;
        end else begin
            cnt    <= cnt + {{(TPW-1){1'b0}}, 1'b1};
            o_tick <= (cnt == {TPW{1'b0}});
        end
    end

endmodule
