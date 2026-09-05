// q_whistle.v -- T3 the byzantine whistle: a cancellation-rate tripwire in
// silicon (quilt-verilog sketch lane, docs/NOVEL-ENHANCEMENTS.md T3,
// Casey directive 2026-09-02).
//
// Evidence base (the glm-1 lane, one-counter alarm): a lying cell's
// cancellation rate spikes x2-x5 over the honest baseline, separable in 5/5
// seeds. That is cheap enough to be a per-cell (on ECP5, arguably
// per-edge) hardware counter -- glm-1's detector was a python script over
// a wave; this is the same judgment as one register file.
//
// What counts as a cancellation (the i_can source -- this module is
// source-agnostic, but the intended hook is concrete): a DESTRUCTIVE
// contribution at activation integration, i.e. in q_cell_core's effect
// path (ST_EFFI), the case
//
//     act != 0  &&  ((prod >>> 15) != 0)  &&  sign(prod) != sign(act)
//
// an incoming effect whose integrated product opposes the membrane it
// lands on. Honest fabric cancels at a calibrated per-window rate C_h (the
// i_base dial); a byzantine peer overdrives opposite-sign effects and the
// windowed count separates. The fabric already PROVES net conservation
// (formal/fabric.conservation.sby, net==0 across the tick); the whistle is
// the second moment of that same ledger -- not "did value disappear" but
// "is value being destroyed faster than honesty pays for".
//
// Window mechanics: i_tick strobes the window boundary (the fabric tick).
// The window counter saturates; at each boundary the completed count is
// compared against limit = i_base * i_mul. Over the limit: one-cycle
// o_whistle strobe + sticky o_alert (cleared only by i_clr or reset) +
// saturating o_strikes. o_hist latches the last COMPLETED window for host
// readout (the gauge reading; the host's EWMA over o_hist is how i_base
// gets recalibrated -- T13's firmware job).
//
// Same-cycle rules (deterministic):
//   i_can && i_tick : the window closes FIRST (its count judged as-is),
//     and the coincident cancellation is the first mark of the NEW window.
//   i_clr && over   : the clear wins (host acknowledgment outranks a
//     same-boundary re-alarm; the next over-window re-latches anyway).
//
// Dial contracts: i_mul >= 1 by convention (i_mul == 0 makes the limit 0:
// paranoid mode, any nonzero window alarms -- legal but loud). i_base is
// the calibrated honest baseline in cancels/window; the x2-x5 attack range
// means i_mul in 2..5 is the useful span (MULW=3 covers it).
//
// The formal target (T3's real prize, NOT yet proven): a bounding
// invariant -- under any single lying input, the cancellation rate is
// bounded above the honest baseline by a provable constant, so the
// whistle fires within bounded windows of attack onset. That needs a
// per-window honest bound as a lemma of the conservation proof; until
// then this module is a calibrated alarm, not a proven one. This file is
// VERIFIED-FORMAL 2026-09-03: honest-no-FP proven UNBOUNDED
// (whistle.honest, k-induction); sustained maximal lying alarms at the
// first judged window for every legal dial pair, exhaustively
// ($anyconst, BMC45, whistle.attack); covers reached. The bounding
// invariant below is the proven core; the full cancellation-rate
// constant remains future work..
//
// Cost: PW-bit counter + PW-bit history + PW-bit strikes + one (PW x
// MULW) constant-dial multiply + comparator. On ECP5 the multiply maps
// naturally to a DSP slice (28 available, nextpnr DSPMultiplier) -- a
// per-cell whistle battery is ~8 of 28 slices; on iCE40 (no DSP on HX8K)
// it maps to LCs; on UP5K it can take one MAC16 (see T10). Honest scope:
// one-sided tripwire (spike detection). The silence attack -- a liar that
// stops cancelling -- is out of scope by design; liveness/silence is what
// the admission controller (T2) and the conservation proofs own.
module q_whistle #(
    parameter        PW   = 16,  // counter width (cancels per window)
    parameter        MULW = 3    // alarm-scale dial width (useful span 2..5)
)(
    input  wire               clk,
    input  wire               rst_n,

    input  wire               i_can,    // strobe: one destructive effect
    input  wire               i_tick,   // strobe: window boundary (fabric tick)

    input  wire [PW-1:0]      i_base,   // honest baseline cancels/window
    input  wire [MULW-1:0]    i_mul,    // alarm scale over baseline (>=1)

    input  wire               i_clr,    // clear the sticky alert

    output reg                o_whistle, // one-cycle strobe at a judged window
    output reg                o_alert,   // sticky alarm (till i_clr / rst)
    output reg  [PW-1:0]      o_wcnt,    // live window count (probe)
    output reg  [PW-1:0]      o_hist,    // last completed window (readout)
    output reg  [PW-1:0]      o_strikes  // total over-limit windows (sat.)
);
    // limit = base * mul, full product width (a dial-times-dial constant;
    // yosys maps this small multiply to DSP on ECP5, MAC16 on UP5K, LCs
    // otherwise -- no vendor primitives are instantiated here)
    wire [PW+MULW-1:0] limit  = i_base * i_mul;
    wire [PW+MULW-1:0] wcnt_e = {{MULW{1'b0}}, o_wcnt};
    wire               over   = (wcnt_e > limit);

    always @(posedge clk) begin
        if (!rst_n) begin
            o_whistle <= 1'b0;
            o_alert   <= 1'b0;
            o_wcnt    <= {PW{1'b0}};
            o_hist    <= {PW{1'b0}};
            o_strikes <= {PW{1'b0}};
        end else begin
            o_whistle <= 1'b0;

            if (i_tick) begin
                // judge the closing window, then open the next; a
                // coincident i_can belongs to the new window
                o_hist <= o_wcnt;
                o_wcnt <= i_can ? {{(PW-1){1'b0}}, 1'b1} : {PW{1'b0}};
                if (over) begin
                    o_whistle <= 1'b1;
                    o_alert   <= 1'b1;
                    if (o_strikes != {PW{1'b1}})
                        o_strikes <= o_strikes + {{(PW-1){1'b0}}, 1'b1};
                end
            end else if (i_can && (o_wcnt != {PW{1'b1}})) begin
                o_wcnt <= o_wcnt + {{(PW-1){1'b0}}, 1'b1};
            end

            // the clear wins over a same-boundary re-alarm (host ack
            // outranks; the next over-window re-latches regardless)
            if (i_clr)
                o_alert <= 1'b0;
        end
    end

endmodule
