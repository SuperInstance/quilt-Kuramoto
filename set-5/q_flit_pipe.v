// q_flit_pipe.v -- registered flit slice for the ring spine (v1: skid form).
// Derived from opencode RTL-SKETCH §2, restructured: the 1-deep form's
// s_ready = !vq || m_ready closes a combinational loop around a full ring
// (verilator UNOPTFLAT, and a real hazard). The skid form's s_ready = !b_v
// depends only on local state, breaking the ready chain at every hop while
// keeping full throughput: accept into the main register, then the skid.
module q_flit_pipe #(
    parameter OPW  = 3,
    parameter AIDW = 4,
    parameter PW   = 16
)(
    input  wire               clk,
    input  wire               rst_n,

    input  wire               s_valid,
    output wire               s_ready,
    input  wire [OPW-1:0]     s_op,
    input  wire [AIDW-1:0]    s_src,
    input  wire [AIDW-1:0]    s_dst,
    input  wire [PW-1:0]      s_a0,
    input  wire [PW-1:0]      s_a1,
    input  wire [PW-1:0]      s_a2,
    input  wire [PW-1:0]      s_dat,

    output wire               m_valid,
    input  wire               m_ready,
    output wire [OPW-1:0]     m_op,
    output wire [AIDW-1:0]    m_src,
    output wire [AIDW-1:0]    m_dst,
    output wire [PW-1:0]      m_a0,
    output wire [PW-1:0]      m_a1,
    output wire [PW-1:0]      m_a2,
    output wire [PW-1:0]      m_dat
);
    localparam FW = OPW + 2*AIDW + 4*PW;

    reg          a_v;
    reg [FW-1:0] a_q;   // main output register
    reg          b_v;
    reg [FW-1:0] b_q;   // skid

    wire [FW-1:0] s_bus = {s_op, s_src, s_dst, s_a0, s_a1, s_a2, s_dat};

    assign {m_op, m_src, m_dst, m_a0, m_a1, m_a2, m_dat} = a_q;
    assign m_valid = a_v;
    assign s_ready = !b_v;   // local only: no ready-chain loop

    wire push = s_valid && !b_v;
    wire pop  = a_v && m_ready;

    always @(posedge clk) begin
        if (!rst_n) begin
            a_v <= 1'b0;
            b_v <= 1'b0;
            a_q <= {FW{1'b0}};
            b_q <= {FW{1'b0}};
        end else begin
            if (pop) begin
                a_v <= b_v;
                a_q <= b_q;
                b_v <= 1'b0;
            end
            if (push) begin
                if (a_v && !pop) begin
                    b_q <= s_bus;   // main stalled: new word goes to skid
                    b_v <= 1'b1;
                end else begin
                    a_q <= s_bus;   // main free (empty or popping)
                    a_v <= 1'b1;
                end
            end
        end
    end

endmodule
