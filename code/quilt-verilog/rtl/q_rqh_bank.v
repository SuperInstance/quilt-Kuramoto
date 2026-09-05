// q_rqh_bank.v -- Residual-Quantum Hebb residue bank (quilt-verilog v2).
// Design: proposals/innovations/flash.md, AS CORRECTED by
// docs/academic/error-envelopes.md Theorem 3c (correction C3); merged per
// docs/INNOVATION-JUDGEMENT.md §5 fold-in item 2 (ships in the same merge
// as the echo gate -- the pair is worth strictly more than either alone:
// the gate's gclass grades every cofire, the bank returns what the graded
// placement drops).
//
// Banks the dyadic placement residue of each graded cofire into a per-edge
// quantum reservoir R; returns a sub-count readout credit (o_credit, in
// readout LSBs) and a tick-aligned anticipation strobe (o_antic, pulses
// when the selected edge's credit increments). Wraps the q_hebb_edge
// engines without touching the ladder buckets or the hyperbola counter
// (Law 5 preserved). RQEN=0 (i_en=0) is bit-exact v1 passthrough: credit
// 0, antic 0, reservoirs frozen.
//
// THE DEPOSIT IS THE CORRECTED CONDITION, not the proposal's 2^g.
// The envelope paper falsified the original deposit: the as-proposed 2^g
// misses the exact convergence condition by ~2^(K+QDW-2g)*0.28 (class 0:
// ~9100x) and inverts the class dependence. Theorem 3c's exact condition
// (uniform ages, base-2 ladder):
//
//     deposit(g) = 2^QDW * E[ 2^(K-g) - 2^(K-A/H) | A in bucket g ]
//                = 2^(K+QDW-g) * (1 - 1/(2 ln 2))   =  2^(K+QDW-g) * 0.27865
//
// This module implements the corrected magnitude as the dyadic
// approximation the paper itself notes is "still shifts and saturating
// adds":
//
//     deposit(g) = (2^(K+QDW-g) >> 2) + (2^(K+QDW-g) >> 5)
//                = 2^(K+QDW-g) * 9/32     (9/32 = 0.28125, +0.9% over exact)
//
// What this buys (T3 provables): bounded perturbation (credit <= 2^(RW-QDW)-1
// readout LSBs, never wraps, saturating add), envelope preservation, and
// rate tracking -- the credit's long-run rate equals the band-overstatement
// rate, the strongest property a one-sided credit can deliver (a one-sided
// credit can CENTER the band, never close it; mis-phased readouts, the one
// place a positive credit genuinely reduces error, are directionally
// covered). o_antic's cadence under the corrected deposit is ~2^(g-K)/0.28
// cofires per credit (~3.6 fresh cofires), not the proposal's 2^(QDW-g).
//
// Scoped to MODE=0 (ladder): the hyperbola's dominant error is temporal
// (the [1,4) interval band, T2), which a train-side deposit cannot correct;
// MODE=1 deposits remain bounded and harmless (experimental, no claim).
//
// Deadband leak on tick (glm pattern, load-bearing per flash limit 6:
// without snap-to-0 a stale 1-unit residue could later cross a credit
// boundary with no fresh cofire -- a false anticipation).
//
// Cost: RW FF per edge, two shifts, one saturating add, one carry compare;
// zero multipliers/dividers. Pure Verilog-2005.
module q_rqh_bank #(
    parameter RW      = 16,   // reservoir width (quanta)
    parameter K       = 8,    // ladder buckets / max placement class
    parameter PW      = 16,   // readout width
    parameter EDGES_N = 4,    // edges in the bank
    parameter EIW     = 2     // edge index width (log2 EDGES_N)
)(
    input  wire                clk,
    input  wire                rst_n,

    // sync with the wrapped engine's command slot (one-hot edge select,
    // held through the op exactly like q_hebb_edge's i_sel)
    input  wire                i_train,    // strobe: graded cofire committed (hb_cmd==101)
    input  wire                i_tick,     // strobe: this edge ticked          (hb_cmd==010)
    input  wire [EDGES_N-1:0]  i_sel,      // one-hot edge select
    input  wire [3:0]          i_gclass,   // class this cofire landed in (raw, clamped here)
    input  wire [3:0]          i_qdw,      // quanta-per-credit shift (dial 14[3:0])
    input  wire [3:0]          i_qleak,    // deadband leak shift     (dial 15[3:0])
    input  wire                i_en,       // RQEN; 0 = bit-exact v1 passthrough

    output wire [PW-1:0]       o_credit,   // selected edge's credit (readout LSBs)
    output wire                o_antic     // pulse: selected edge's credit increments
);
    localparam [3:0] K4 = K;

    reg [RW-1:0] R [0:EDGES_N-1];

    // one-hot decode: selected edge index and value
    reg [EIW-1:0] esel;
    integer i, j;
    reg [RW-1:0] rsel;
    always @* begin
        esel = {EIW{1'b0}};
        rsel = {RW{1'b0}};
        for (i = 0; i < EDGES_N; i = i + 1)
            if (i_sel[i]) begin
                esel = i[EIW-1:0];
                rsel = R[i];
            end
    end

    // ---- corrected deposit (error-envelopes.md T3c) ----
    // clamp class to K-1, mirroring q_hebb_edge's graded-train placement
    wire [3:0] gcl = (i_gclass >= K4) ? (K4 - 4'd1) : i_gclass;
    // base quantum 2^(K+QDW-g); clamp keeps the shift in [QDW+1, K+QDW]
    wire [5:0]  dsh   = {2'b00, K4} + {2'b00, i_qdw} - {2'b00, gcl};
    wire [31:0] qbase = 32'd1 << dsh;
    // deposit = 9/32 of the band mass: two shifts + one add (no multiply)
    wire [31:0] dep   = (qbase >> 2) + (qbase >> 5);

    // saturating deposit (33-bit guard; dep can exceed the reservoir when
    // QDW is dialed large -- saturation is the honest, never-wrap answer)
    wire [32:0]  rsum  = {17'd0, rsel} + {1'b0, dep};
    wire [32:0]  rfull = {{(33-RW){1'b0}}, {RW{1'b1}}};
    wire         rsat  = (rsum > rfull);
    wire [RW-1:0] rdepn = rsat ? {RW{1'b1}} : rsum[RW-1:0];

    // deadband leak on tick; train wins the (unreachable) same-cycle case.
    // snap = terminal residue OR no-progress (R < 2^QLEAK leaks by zero and
    // would park in [2, 2^QLEAK-1] forever -- a stale base that could later
    // cross a credit boundary with no fresh cofire: a false anticipation;
    // the load-bearing deadband of flash limit 6, closed at the tail too)
    wire [RW-1:0] rleak  = rsel - (rsel >> i_qleak);
    wire          rsnap  = (rleak <= {{(RW-1){1'b0}}, 1'b1}) || (rleak >= rsel);
    wire [RW-1:0] rleakn = rsnap ? {RW{1'b0}} : rleak;

    // credit = reservoir >> QDW (readout LSBs); antic = credit increment
    wire [31:0] cred_cur = {16'd0, rsel}  >> i_qdw;
    wire [31:0] cred_new = {16'd0, rdepn} >> i_qdw;

    assign o_credit = i_en ? cred_cur[PW-1:0] : {PW{1'b0}};
    assign o_antic  = i_en && i_train && (cred_new > cred_cur);

    always @(posedge clk) begin
        if (!rst_n) begin
            for (j = 0; j < EDGES_N; j = j + 1)
                R[j] <= {RW{1'b0}};
        end else if (i_en) begin
            if (i_train)
                R[esel] <= rdepn;      // corrected deposit path
            else if (i_tick)
                R[esel] <= rleakn;     // deadband leak path
            // i_en == 0: quiesced (frozen) -- bit-exact v1 passthrough
        end
    end

endmodule
