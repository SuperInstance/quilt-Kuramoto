// q_tern_dice.v -- per-cell balanced-ternary noise unit (quilt-verilog,
// ternary lane). Port of SuperInstance/ternary-dice's weighted {-1,0,+1}
// roll onto the quilt harness's standard PRNG; plan:
// docs/TERNARY-VERILOG-PLAN.md section 1.
//
// One register pair, three rules:
//   seed : x <- seed                       (seed write wins over tick)
//   tick : x <- (1103515245*x + 12345) mod 2^31   (glibc LCG, integer-only)
//   draw : r = x_next[30:16] (the high-quality slice); bucket by bands:
//            r < band_neg          -> -1
//            r >= 32768 - band_pos -> +1
//            else                  ->  0
//          P(-1) = band_neg/32768, P(+1) = band_pos/32768; balanced
//          default is band_neg = band_pos = 10923 (~1/3 each).
//          Overlap (band_neg + band_pos > 32768) resolves toward -1:
//          the negative band is checked first, deterministically.
//
// Semantics (RD-PHYSICAL-SUBSTRATES.md lanes 3/7: "deterministic tick by
// default, stochastic tick as a mode"): the bias perturbs the fire test
// in q_cell_core's ST_TLEAK in sampling mode only. EN gates the OUTPUT,
// not the stream: the LCG advances on every tick service regardless, so
// stream position stays a pure function of tick count and seed (replay
// determinism), and disabling mid-run does not resync the sequence.
// EN=0 -> o_bias = 0 forever -> the fire test is bit-exact v1.
//
// Seeding: per-cell, at bind time. Recommended derivation (ternary-dice's
// prime spreader): seed = SEED_DIAL + cell_id*7919, computed by the
// binding parent/host and written through i_seed/i_seed_wr. Seed 0 is
// legal (c != 0, no fixed point: the sequence starts at 12345).
//
// Period (EXPERT cross-exam 2026-09-03): x lives mod 2^31 with c = 12345
// odd and a = 1103515245 = 1 (mod 4), so x cycles ALL 2^31 states --
// Hull-Dobell full period, no shorter cycle from the constant-multiply
// structure. The draw IS x_next[30:16]: no state bits are discarded
// before bucketing, so bucketing cannot shrink the period either; each
// 15-bit draw value appears exactly 2^16 times per period and the bands
// are contiguous draw ranges. Spectral quality is TESTED, not assumed:
// tb T8 asserts 3x3 symbol-transition uniformity (chi-square, 8 dof,
// 95% band) at lag-1 and lag-2 -- the marginal thirds of the stat
// envelope cannot see serial correlation, transitions are what an
// admission policy actually consumes.
//
// Cost: 33 FF, one constant multiply (1103515245 is a fixed coefficient:
// shift-add network, no general multiplier), two 15-bit compares, one
// 16-bit subtract. Zero dividers, zero floats. Cell-local, GALS-safe.
module q_tern_dice #(
    parameter PW = 16              // seed port width (matches dial width)
)(
    input  wire             clk,
    input  wire             rst_n,

    input  wire             i_tick,     // strobe: once per tick service
    input  wire             i_seed_wr,  // strobe: load per-cell seed
    input  wire [PW-1:0]    i_seed,

    input  wire             i_en,       // sampling mode enable (0 = v1)
    input  wire [14:0]      i_band_neg, // P(-1) = band_neg / 32768
    input  wire [14:0]      i_band_pos, // P(+1) = band_pos / 32768

    output reg  signed [1:0] o_bias,    // {-1,0,+1}, held until next tick
    output wire [30:0]       o_state    // LCG state probe
);

    reg [30:0] x;

    // LCG advance; the 31-bit truncation IS the mod 2^31
    wire [30:0] x_next = 31'd1103515245 * x + 31'd12345;

    // bucket the draw: negative band first (documented overlap priority),
    // then positive; band_pos = 0 makes pos_lo = 32768 > any draw -> never
    wire [14:0] draw   = x_next[30:16];
    wire [15:0] pos_lo = 16'd32768 - {1'b0, i_band_pos};
    wire        hit_neg = (draw < i_band_neg);
    wire        hit_pos = ({1'b0, draw} >= pos_lo);

    always @(posedge clk) begin
        if (!rst_n) begin
            x      <= 31'd0;
            o_bias <= 2'sd0;
        end else if (i_seed_wr) begin
            x      <= {{(31-PW){1'b0}}, i_seed};
            o_bias <= 2'sd0;
        end else if (i_tick) begin
            x      <= x_next;
            o_bias <= !i_en    ? 2'sd0  :
                      hit_neg    ? -2'sd1 :
                      hit_pos    ?  2'sd1 : 2'sd0;
        end
    end

    assign o_state = x;

endmodule
