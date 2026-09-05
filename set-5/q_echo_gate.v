// q_echo_gate.v -- per-cell fire trace: the echo gate (quilt-verilog v2).
// Design: proposals/innovations/opencode.md §4.1 (q_echo_trace, the only
// pre-verified module on the innovation ballot), merged as the winner per
// docs/INNOVATION-JUDGEMENT.md §5 fold-in item 1.
//
// One register, three rules:
//   fire : F <- max            (fire wins over a same-cycle leak)
//   tick : F <- F - (F >> KLE) (snap to 0 at/below FLOOR or residue <= 1)
//   gate : live = F >= FLOOR (FLOOR == 0 = disabled = v1 semantics);
//          gclass = 15 - msb(F) = ladder bucket for a gated cofire.
//
// Semantics: an effect trains an edge only inside a causal window of
// W_E ~ ln(Fmax/FLOOR)/ln((1-2^-KLE)^-1) ticks after the receiving cell's
// own last fire ("I fired, then you echoed me"). The graded class puts the
// cofire into ladder bucket g as an event born ~g trace half-lives old:
// with k(d) = F(d)/Fmax, g = 15 - msb(F) gives 2^-g in (k, 2k] -- the same
// aligned-phase overstatement staircase the ladder's proven 2x envelope
// (docs/academic/error-envelopes.md Theorem 1) already covers. Silence
// earns nothing: F = 0 gates every train off (reception is not cofire).
//
// Dials (q_dialfile): 11 = KLE (leak shift, >=1, default 2),
// 12 = FLOOR (gate floor; 0 = disabled = bit-exact v1 -- the A/B referee
// switch; NOTE default is 0, not the proposal's 0x0080, so the v1
// acceptance gate stays bit-exact until the operator opts in),
// 13 = FTRACE (read-only probe of o_f via view(2)).
//
// Cost: 17 FF, one barrel shift, two comparators, one priority encoder;
// zero multipliers/dividers; +0 cycles on every opcode (combinational on
// the cycle ST_EFFT already spends on the edge hit). Cell-local, no
// timestamps, GALS-safe (local-order time reference).
module q_echo_gate #(
    parameter PW = 16              // trace width; class scale assumes PW <= 16
)(
    input  wire          clk,
    input  wire          rst_n,

    input  wire          i_fire,     // strobe: this cell fired this tick
    input  wire          i_tick,     // strobe: once per tick service (leak)
    input  wire [3:0]    i_kle,      // trace leak shift, >=1 by dial contract
    input  wire [PW-1:0] i_floor,    // gate floor; 0 = gate disabled (v1 mode)

    output wire [PW-1:0] o_f,        // trace value (viewable via dial 13)
    output wire          o_live,     // gate open: effects may train edges
    output wire [3:0]    o_gclass    // ladder bucket index for the cofire
);
    // PW-1 as a 4-bit constant (class scale); the truncation is exact for
    // PW <= 16, which the class output width requires anyway
    /* verilator lint_off WIDTHTRUNC */
    localparam [3:0] TOPJ = PW - 1;  // 15 for PW=16
    /* verilator lint_on WIDTHTRUNC */

    reg [PW-1:0] f;

    function [3:0] msb_idx;          // same pattern as q_hebb_edge's msb16
        input [PW-1:0] v;
        integer j;
        begin
            msb_idx = 4'd0;
            for (j = 0; j < PW; j = j + 1)
                if (v[j] == 1'b1)
                    msb_idx = j[3:0];
        end
    endfunction

    // leak with deadband snap: below-floor values, terminal residues, and
    // no-progress values (F < 2^KLE leaks by exactly zero and would
    // otherwise park immortally in [2, 2^KLE-1], leaving the gate open
    // for pathological small-FLOOR/large-KLE dial combos) go to exactly
    // zero (kills the leak-floor sticky artifact; glm deadband pattern,
    // hardened one step past the opencode sketch).
    wire [PW-1:0] fleak = f - (f >> i_kle);
    wire          fsnap = (fleak <= i_floor) ||
                          (fleak <= {{(PW-1){1'b0}}, 1'b1}) ||
                          (fleak >= f);

    always @(posedge clk) begin
        if (!rst_n)
            f <= {PW{1'b0}};
        else if (i_fire)
            f <= {PW{1'b1}};
        else if (i_tick)
            f <= fsnap ? {PW{1'b0}} : fleak;
    end

    assign o_f      = f;
    // floor == 0 disables the gate entirely: always live (v1 semantics)
    assign o_live   = (i_floor == {PW{1'b0}}) || (f >= i_floor);
    // disabled or dead trace: class 0 (fresh) -- the gate, not the class,
    // is what suppresses training when the trace is dead
    assign o_gclass = (i_floor == {PW{1'b0}}) || (f == {PW{1'b0}})
                        ? 4'd0
                        : (TOPJ - msb_idx(f));
endmodule
