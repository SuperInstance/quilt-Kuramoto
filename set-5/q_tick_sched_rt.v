// q_tick_sched_rt.v -- tick strobe generator with a RUNTIME period
// (quilt-verilog v2.1, pin-fix lane companion to rtl/quf_boot.v).
//
// This is the docs/FPGA-BOOT.md §6 seam, second of the two sanctioned
// RTL forms ("the harness instantiates it ... and compares a masked
// counter -- spec decision for the RTL lane, both are <=~20 LCs"):
// q_tick_sched's TPW is a synthesis-time parameter, but the QUF loader
// captures o_tick_tpw[4:0] from the ticks section and quf_boot latches
// it once at release (latch-once-at-release epoch semantics). This
// module is that latch made real: period exponent i_tpw, latched at the
// epoch pulse, frozen for the run.
//
// Cycle-exactness contract (load-bearing for the differential TB,
// tb/tb_serfabric.v): after the epoch pulse this module is cycle-identical
// to q_tick_sched #(.TPW(T)) with T == i_tpw at release. q_tick_sched
// released at cycle R has cnt=0 under reset; its first free posedge does
// cnt 0->1 and pulses tick (cnt==0). The epoch branch therefore loads
// cnt<=1/tick<=1 -- "one free posedge already elapsed" -- so a fabric
// clocked by this module and a q_fabric_top released the same cycle tick
// on the same edges forever after.
//
// Pre-epoch ticks (POR high, epoch not yet seen) are emitted but ignored:
// every core the tick reaches is FSM-frozen in fabric reset until release
// (the same argument quf_boot makes for dial writes). v1 cap: period
// exponents 0..TPWMAX-1; quf_boot's o_tick_tpw is 5 bits, so TPWMAX<=16
// truncates exponents >15 (none exist in any committed container; noted
// here rather than hidden).
module q_tick_sched_rt #(
    parameter TPWMAX = 16
)(
    input  wire               clk,
    input  wire               rst_n,      // POR
    input  wire               i_epoch,    // 1-cycle pulse at fabric release
    input  wire [TPWMAX-1:0]  i_tpw,      // period exponent (stable after epoch)
    output wire               o_tick
);
    reg [TPWMAX-1:0] cnt;
    reg              tick;

    wire [TPWMAX-1:0] mask = (({{TPWMAX{1'b0}}, 1'b1} << i_tpw) - 1'b1);

    always @(posedge clk) begin
        if (!rst_n) begin
            cnt  <= {TPWMAX{1'b0}};
            tick <= 1'b0;
        end else if (i_epoch) begin
            cnt  <= {{(TPWMAX-1){1'b0}}, 1'b1};   // see header: one posedge
            tick <= 1'b1;                          // already elapsed
        end else begin
            cnt  <= (cnt + {{(TPWMAX-1){1'b0}}, 1'b1}) & mask;
            tick <= (cnt == {{TPWMAX{1'b0}}});
        end
    end

    assign o_tick = tick;

endmodule
