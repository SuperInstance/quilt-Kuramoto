// formal/f_echo_gate_dyadic.v -- echo-gate staircase-bracket proof.
//
// Hardware mirror of THE-BREAKDOWN §2(c) / q_echo_gate.v:18-22: the graded
// class rule g = 15 - msb(F) puts the gated cofire into the SAME aligned-
// phase dyadic staircase the ladder's proven 2x envelope (error-envelopes.md
// Theorem 1) covers. The integer core of that claim is the bracket
//
//     2^-g in (k, 2k],  k = F/Fmax,  Fmax = 2^PW
//  == 2^(PW-1) <= F << g < 2^PW          (exact integer form)
//
// i.e. the class g places the trace value F in its dyadic octave: bucket g
// of the ladder overstates the true weight by a factor in [1,2) -- the
// staircase the ladder bound already prices. This harness proves the
// bracket AT EVERY CYCLE over the real q_echo_gate FSM, for any trace the
// solver can drive, plus the gate's structural safety properties:
//
//   DYAD   live trace, any cycle: F << gclass lands in [2^(PW-1), 2^PW)
//   PRIORITY  fire beats a same-cycle leak: fire&&tick -> F' = all-ones
//   MONO   without fire the trace never grows (leak/snap only decrease)
//   ZEROABSORB  F = 0 is absorbing until the next fire (dead stays dead)
//   DEAD   dead trace gates every train off (live=0), class frozen 0
//   DISABLED  FLOOR = 0 = v1: always live (the A/B referee switch)
//
// Dials are anyconst per run (kle in [1,8] per the dial contract; floor
// free), strobes are anyseq -- the solver owns the trace. BMC depth 25
// spans >5 leak generations at kle=1.
module f_echo_gate_dyadic(input clk, input rst_n);
    localparam PW = 16;

    reg  [3:0]    d_kle;
    reg  [PW-1:0] d_floor;
    wire [PW-1:0] f;
    wire          live;
    wire [3:0]    gclass;

    q_echo_gate #(.PW(PW)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .i_fire(f_fire), .i_tick(f_tick),
        .i_kle(d_kle), .i_floor(d_floor),
        .o_f(f), .o_live(live), .o_gclass(gclass)
    );

    // unconstrained strobes; constrained dials (anyconst via steady regs)
    reg f_fire, f_tick;
    always @(posedge clk) begin
        f_fire <= $anyseq;
        f_tick <= $anyseq;
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            d_kle   <= $anyconst;
            d_floor <= $anyconst;
        end
    end
    always @(*) begin
        assume (d_kle >= 4'd1 && d_kle <= 4'd8);
    end

    // reset preamble (single-reset contract, as fabric.conservation)
    reg [1:0] f_rstctr = 0;
    always @(posedge clk)
        if (f_rstctr < 2) f_rstctr <= f_rstctr + 1;
    always @(*) begin
        if (f_rstctr < 2) assume (!rst_n);
        else              assume (rst_n);
    end

    // the bracket, integer form: F << g in [2^(PW-1), 2^PW)
    wire [31:0] fsh = {16'd0, f} << gclass;
    wire [31:0] lo  = 32'd32768;      // 2^(PW-1)
    wire [31:0] hi  = 32'd65536;      // 2^PW

    always @(posedge clk) if (rst_n) begin
        // DYAD: any live nonzero trace sits in its dyadic octave
        if (d_floor != {PW{1'b0}} && f != {PW{1'b0}})
            assert (fsh >= lo && fsh < hi);
        // equivalent half-power form (the TB's encoding): 2^(15-g) <= F < 2^(16-g)
        // (17-bit literal: 2^(16-g) at g=0 needs bit 16)
        if (d_floor != {PW{1'b0}} && f != {PW{1'b0}}) begin
            assert (f >= (17'd1 << (15 - gclass)));
            assert (f <  (17'd1 << (16 - gclass)));
        end
        // PRIORITY: fire wins over a same-cycle leak (checked one cycle
        // after the clash strobe: the refill lands at that edge)
        if ($past(f_fire) && $past(f_tick) && $past(rst_n))
            assert (f == {PW{1'b1}});
        // MONO: no fire -> trace never grows (leak or snap only decrease)
        if (!$past(f_fire) && $past(rst_n))
            assert (f <= $past(f));
        // ZEROABSORB: dead trace stays dead until the next fire
        if (!$past(f_fire) && $past(f) == {PW{1'b0}} && $past(rst_n))
            assert (f == {PW{1'b0}});
        // DEAD: dead trace gates training off, class frozen 0
        if (d_floor != {PW{1'b0}} && f == {PW{1'b0}}) begin
            assert (!live);
            assert (gclass == 4'd0);
        end
        // DISABLED: floor 0 = gate off = v1 semantics: always live
        if (d_floor == {PW{1'b0}})
            assert (live);
    end

    // covers: non-vacuity -- the bracket must be exercised in several octaves
    always @(posedge clk) if (rst_n) begin
        cover (d_floor != 0 && f != 0 && gclass == 4'd0);
        cover (d_floor != 0 && f != 0 && gclass >= 4'd1 && gclass <= 4'd7);
        cover (d_floor != 0 && f != 0 && gclass >= 4'd8);
        cover (f == {PW{1'b0}} && d_floor != 0);        // a dead trace exists
        cover (f_fire && f_tick);                       // the priority clash
    end
endmodule
