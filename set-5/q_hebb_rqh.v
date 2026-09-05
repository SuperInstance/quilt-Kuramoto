// q_hebb_rqh.v -- Residual-Quantum Hebb companion (proposals/innovations/flash.md
// 4.1), first compiled commit + the corrected deposit of
// docs/academic/error-envelopes.md Theorem 3c.
//
//   as-built deposit (flash.md, i_corr=0): 2^g quanta per class-g cofire.
//     PROVED WRONG by error-envelopes Thm 3c: the exact convergence condition
//     is deposit(g) = 2^QDW * E[overstatement|g]; as-built is too small by
//     2^(K+QDW-2g)*(1-1/(2 ln 2)) (~18,262x at class 0, K=QDW=8) and its
//     class-dependence is inverted (largest where the residue is smallest).
//   corrected deposit (i_corr=1, this module): round(2^(K+QDW-g)*(1-1/(2ln2)))
//       = (4565 * 2^(K+QDW-g) + 8192) >> 14   [4565 = round(0.278652*2^14)]
//     shifts + one constant multiply (synthesizes to shift-adds); still no
//     divider, no runtime multiplier.
//
// Two sketch bugs fixed here (noted in tb_rqh_saturation.v findings):
//   (a) flash.md's o_credit tapped the combinational candidate R+dep (phantom
//       credit on idle/tick cycles); this module registers the credit off R.
//   (b) the deadband snap "Rleak <= 1" leaves a sticky floor at
//       R in [2, 2^QLEAK] (R>>QLEAK == 0 => leak is a no-op); the snap here
//       fires when the leak fails to reduce R, so the reservoir always
//       reaches exactly 0 on a no-train idle run.
//
// Envelope honesty (Thm 3a/3b): credit >= 0 and <= 2^(RW-QDW)-1 (saturating
// add, never wraps); the credit can only widen the worst-case upper band --
// the tightening claim is scoped to the mis-phased regime and validated by
// tb/tb_rqh_saturation.v, not asserted by this module.
//
// Pure Verilog-2005. Never touches the wrapped engine's state (Law 5).
`timescale 1ns/1ps
module q_hebb_rqh #(
    parameter RW = 16,     // reservoir width (quanta)
    parameter K  = 8,      // ladder buckets / max class (matches engine)
    parameter PW = 16      // credit output width
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          i_train,   // strobe: cofire this cycle (engine cmd 001)
    input  wire          i_tick,    // strobe: tick this cycle       (cmd 010)
    input  wire  [3:0]   i_gclass,  // placement class of the cofire (0..K-1)
    input  wire  [3:0]   i_qdw,     // dial RQD: quanta per credit = 2^QDW
    input  wire  [3:0]   i_qleak,   // dial RQLEAK: deadband leak shift
    input  wire          i_corr,    // 1 = corrected deposit, 0 = as-built 2^g
    input  wire          i_en,      // RQEN: 0 = off, o_credit/o_antic = 0
    output wire [PW-1:0] o_credit,  // sub-count readout credit (R >> QDW)
    output wire          o_antic,   // 1-cycle pulse: a credit was just earned
    output wire          o_sat,     // 1-cycle pulse: a deposit saturated R
    output wire [RW-1:0] o_r        // reservoir probe (viewable, RRES)
);
    localparam [3:0] KMAX = K - 1;

    reg [RW-1:0] R;
    reg          antic_r;
    reg          sat_r;

    // class clamp at K-1
    wire [3:0] gcl = (i_gclass > KMAX) ? KMAX : i_gclass;

    // corrected deposit: round(2^(K+QDW-g)*(1-1/(2 ln 2)))
    //   = round(4565 * 2^(s-14)),  4565 = round(0.278652*2^14), s = 8+QDW-g
    // staged entirely at RW bits (two cases, no 32-bit temp):
    //   s >= 14 : dep = 4565 << (s-14)              (s in [14,16], shift <= 2)
    //   s <  14 : dep = (4565 + 2^(13-s)) >> (14-s) (round-half-up)
    // s clamped to 16 so the shift never exceeds the staged width
    wire [5:0]  sraw  = 6'd8 + {2'b00, i_qdw} - {2'b00, gcl};
    wire [5:0]  scl   = (sraw > 6'd16) ? 6'd16 : sraw;
    wire [5:0]  shu   = {1'b0, scl[4:0]} - 6'd14;   // s-14 mod 64, valid when s >= 14
    wire [5:0]  shd   = 6'd14 - {1'b0, scl[4:0]};   // 14-s mod 64, valid when s < 14
    wire [15:0] dep_up = 16'd4565 << shu;
    wire [15:0] dep_dn = (16'd4565 + (16'd1 << (shd - 6'd1))) >> shd;
    wire [15:0] dep_c  = (scl >= 6'd14) ? dep_up : dep_dn;

    wire [RW-1:0] dep = i_corr ? dep_c : (16'd1 << {12'd0, gcl});

    // saturating deposit: never wraps
    wire [RW-1:0] Radd = R + dep;
    wire          rsat = (Radd < R);
    wire [RW-1:0] Rnxt = rsat ? {RW{1'b1}} : Radd;

    // deadband leak on tick (applies to the STORED R, not the phantom
    // candidate): R <- R - (R >> QLEAK), snap to 0 when the leak can no
    // longer reduce R (R < 2^QLEAK) -- the sticky-residue fix (b).
    wire [RW-1:0] Rleak  = R - (R >> {26'd0, i_qleak});
    wire [RW-1:0] Rleakn = (Rleak >= R) ? {RW{1'b0}} : Rleak;

    // credit = R >> QDW (registered, stable); anticipation = a credit
    // boundary was crossed by this cycle's deposit (registered pulse the
    // cycle after the earning train)
    wire [RW-1:0] cnow  = R >> {26'd0, i_qdw};
    wire [RW-1:0] cnxt  = Rnxt >> {26'd0, i_qdw};
    wire          carry = (cnxt > cnow);

    assign o_credit = i_en ? cnow : {PW{1'b0}};
    assign o_antic  = antic_r;
    assign o_sat    = sat_r;
    assign o_r      = R;

    always @(posedge clk) begin
        if (!rst_n) begin
            R       <= {RW{1'b0}};
            antic_r <= 1'b0;
            sat_r   <= 1'b0;
        end else begin
            antic_r <= 1'b0;
            sat_r   <= 1'b0;
            if (i_train) begin
                R       <= Rnxt;
                antic_r <= i_en && carry;
                sat_r   <= rsat;
            end else if (i_tick) begin
                R <= Rleakn;
            end
        end
    end

endmodule
