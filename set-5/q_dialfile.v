// q_dialfile.v -- runtime dial register file (quilt-verilog v1).
// Map per opencode RTL-SKETCH §3 (steal 2 of the scorecard), extended with
// the v1 decay-engine dials P0E / MODE / HL. One sync write port (qm_bind),
// one sync read port (qm_view); reset loads defaults (no `initial`).
// ETA_F/ETA_S/KF/KS/COS_MIN are reserved for post-v1 engines; they are
// readable fabric state via view(2). Pure Verilog-2005.
module q_dialfile #(
    parameter DW = 16,
    parameter ND = 16,
    parameter AW = 4
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 i_wr,
    input  wire [AW-1:0]        i_addr,
    input  wire [DW-1:0]        i_wdata,
    input  wire                 i_rd,
    output reg  [DW-1:0]        o_rdata,
    output reg                  o_rstb,

    // combinational datapath fan-outs
    output wire [DW-1:0]        o_eta_f,
    output wire [DW-1:0]        o_eta_s,
    output wire [3:0]           o_kf,
    output wire [3:0]           o_ks,
    output wire [3:0]           o_ka,
    output wire signed [DW-1:0] o_thresh,
    output wire [DW-1:0]        o_refr,
    output wire [DW-1:0]        o_cosmin,
    output wire [4:0]           o_p0e,     // log2(P0): hyperbolic horizon
    output wire                 o_mode,    // 0=ladder, 1=hyperbolic decay
    output wire [DW-1:0]        o_hl,      // ladder half-life (ticks)
    // v2 feature dials (echo gate + RQH)
    input  wire [DW-1:0]        i_probe,   // live value aliased at dial 13 (ro)
    output wire [3:0]           o_kle,     // 11: echo-trace leak shift
    output wire [DW-1:0]        o_floor,   // 12: echo gate floor (0 = v1)
    output wire [3:0]           o_qdw,     // 14[3:0]: RQH quanta/credit shift
    output wire [3:0]           o_qleak,   // 15[3:0]: RQH deadband leak shift
    output wire                 o_rqen     // 14[15]: RQH master enable
);
    localparam [AW-1:0] D_ETA_F  = 4'd0,  D_ETA_S  = 4'd1,  D_KF     = 4'd2,
                        D_KS     = 4'd3,  D_KA     = 4'd4,  D_THRESH = 4'd5,
                        D_REFR   = 4'd6,  D_COSMIN = 4'd7,  D_P0E    = 4'd8,
                        D_MODE   = 4'd9,  D_HL     = 4'd10,
                        D_KLE    = 4'd11, D_FLOOR  = 4'd12, D_FTRACE = 4'd13,
                        D_RQ     = 4'd14, D_RQL    = 4'd15;

    reg [DW-1:0] dial [0:ND-1];

    always @(posedge clk) begin
        if (!rst_n) begin
            dial[D_ETA_F]  <= 16'h0800;  // 0.0625
            dial[D_ETA_S]  <= 16'h0080;  // 0.0031
            dial[D_KF]     <= 16'd6;     // tau_f = 64 ticks
            dial[D_KS]     <= 16'd12;    // tau_s = 4096 ticks
            dial[D_KA]     <= 16'd5;     // act leak shift
            dial[D_THRESH] <= 16'h6000;  // 0.75
            dial[D_REFR]   <= 16'd4;
            dial[D_COSMIN] <= 16'h2CCD;  // 0.35
            dial[D_P0E]    <= 16'd20;    // P0 = 2^20 ticks
            dial[D_MODE]   <= 16'd0;     // glm ladder
            dial[D_HL]     <= 16'd64;    // ladder half-life
            // v2: both features DEFAULT OFF = bit-exact v1 (the A/B referee)
            dial[D_KLE]    <= 16'd2;     // echo trace tau ~ 4*ln2 ticks
            dial[D_FLOOR]  <= 16'h0000;  // echo gate OFF (0 = v1 semantics;
                                         // opencode proposed 0x0080 default;
                                         // 0 keeps the v1 acceptance gate
                                         // bit-exact until opted in)
            dial[D_FTRACE] <= 16'h0000;  // storage unused: probe alias
            dial[D_RQ]     <= 16'h0008;  // RQEN=0 (off), QDW=8
            dial[D_RQL]    <= 16'h0008;  // QLEAK=8
            o_rdata <= {DW{1'b0}};
            o_rstb  <= 1'b0;
        end else begin
            // dial 13 is a read-only probe alias (the live echo trace);
            // writes to it are ignored (no storage to clobber)
            if (i_wr && (i_addr != D_FTRACE))
                dial[i_addr] <= i_wdata;
            o_rstb <= i_rd;
            if (i_rd)
                o_rdata <= (i_addr == D_FTRACE) ? i_probe
                                                : dial[i_addr]; // read-old on wr/rd collision
        end
    end

    assign o_eta_f  = dial[D_ETA_F];
    assign o_eta_s  = dial[D_ETA_S];
    assign o_kf     = dial[D_KF][3:0];
    assign o_ks     = dial[D_KS][3:0];
    assign o_ka     = dial[D_KA][3:0];
    assign o_thresh = dial[D_THRESH];
    assign o_refr   = dial[D_REFR];
    assign o_cosmin = dial[D_COSMIN];
    assign o_p0e    = dial[D_P0E][4:0];
    assign o_mode   = dial[D_MODE][0];
    assign o_hl     = dial[D_HL];
    assign o_kle    = dial[D_KLE][3:0];
    assign o_floor  = dial[D_FLOOR];
    assign o_qdw    = dial[D_RQ][3:0];
    assign o_qleak  = dial[D_RQL][3:0];
    assign o_rqen   = dial[D_RQ][15];

endmodule
