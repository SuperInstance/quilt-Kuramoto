// t1_first_fabric.v -- TUTORIAL 1: your first quilt fabric (examples/).
//
// A five-opcode tour of the real q_fabric_top datapath:
//   bind  two cells alive (ids 0..NCELL-1; node NCELL is the io port),
//   link  cell 0 hears peer 1 (base weight 0x1000 in Q1.15),
//   effect  one activation flit from peer 1 into cell 0,
//   view  read the THRESH dial before/after a dial write (the dial moves),
//         read cell 0's act register before/after the effect (it moves),
//         read it again after three ticks (the leak pulls it down),
//   tick  not an op you send -- the scheduler strobes every 2^TPW cycles
//         and you simply watch time pass through the numbers.
//
// Config: NCELL=2, TPW=4 -> one tick every 16 clock cycles (fast enough
// to watch; the shipped fabric uses TPW=8+). Effects are silent on the
// fabric (no ACK unless a fire); bind ACKs come back to EXTID (0xF).
//
// Run: bash examples/t1_first_fabric/run.sh   (compiles rtl/, runs vvp,
//     diffs against t1_first_fabric.expected)
`timescale 1ns/1ps
module t1_first_fabric;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg         i_val = 0, i_rdy_t = 0;
    reg  [2:0]  i_op = 0;
    reg  [3:0]  i_src = 0, i_dst = 0;
    reg  [15:0] i_a0 = 0, i_a1 = 0, i_a2 = 0, i_dat = 0;
    wire        o_rdy, o_val;
    wire [2:0]  o_op;
    wire [3:0]  o_src, o_dst;
    wire [15:0] o_a0, o_a1, o_a2, o_dat;
    wire        ovf;

    integer errors = 0, guard;

    q_fabric_top #(.NCELL(2), .TPW(4)) dut (
        .clk(clk), .rst_n(rst_n),
        .i_val(i_val), .o_rdy(o_rdy),
        .i_op(i_op), .i_src(i_src), .i_dst(i_dst),
        .i_a0(i_a0), .i_a1(i_a1), .i_a2(i_a2), .i_dat(i_dat),
        .o_val(o_val), .i_rdy(i_rdy_t),
        .o_op(o_op), .o_src(o_src), .o_dst(o_dst),
        .o_a0(o_a0), .o_a1(o_a1), .o_a2(o_a2), .o_dat(o_dat),
        .o_ovf(ovf)
    );

    // monitor: every egress flit (debug aid, kept: shows traffic)
    always @(posedge clk) if (o_val) $display("      [egress op=%0d src=%0d dst=%h dat=%h]",
        o_op, o_src, o_dst, o_dat);

    // -- house send/recv pattern (from tb/tb_fabric_smoke.v) --------------
    task send(input [2:0] op, input [3:0] src, input [3:0] dst,
              input [15:0] a0, input [15:0] a1,
              input [15:0] a2, input [15:0] dat);
        begin
            @(negedge clk);
            i_val = 1; i_op = op; i_src = src; i_dst = dst;
            i_a0 = a0; i_a1 = a1; i_a2 = a2; i_dat = dat;
            guard = 0;
            while (o_rdy !== 1'b1 && guard < 2000) begin
                @(negedge clk); guard = guard + 1;
            end
            if (guard >= 2000) begin
                errors = errors + 1;
                $display("FAIL send_timeout op=%0d dst=%h", op, dst);
            end
            @(posedge clk);
            i_val <= 0;    // deassert exactly after the transfer edge
        end
    endtask

    // consume one egress flit (an ACK riding the ring back to EXTID)
    task recv_ack(input [127:0] name);
        begin
            guard = 0;
            while (o_val !== 1'b1 && guard < 20000) begin
                @(negedge clk); guard = guard + 1;
            end
            if (o_val !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %0s: no ack", name);
            end else begin
                i_rdy_t = 1;
                @(negedge clk);
                i_rdy_t = 0;
            end
        end
    endtask

    // view(cid, sel): sel 0=act 1=wsum(edges) 2=dial[a1]
    reg [15:0] v;
    task do_view(input [3:0] cid, input [1:0] sel, input [3:0] arg,
                 input [127:0] what);
        begin
            send(3'd3, 4'hF, cid, {14'd0, sel}, {12'd0, arg},
                 16'd0, 16'd0);
            guard = 0;
            while (o_val !== 1'b1 && guard < 20000) begin
                @(negedge clk); guard = guard + 1;
            end
            if (o_val !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL view %0s: timeout", what);
            end else begin
                v = o_dat;
                i_rdy_t = 1;
                @(negedge clk);
                i_rdy_t = 0;
                $display("view  cell %0d %-14s = 0x%04h   (%0s)",
                         cid, what, v, what);
            end
        end
    endtask

    task expect16(input [15:0] got, input [15:0] exp,
                  input [127:0] what);
        begin
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL %0s: got %h exp %h", what, got, exp);
            end
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (10) @(negedge clk);
        $display("== T1 first fabric: NCELL=2, TPW=4 (tick every 16 cycles) ==");

        // ---- bind: two cells come alive --------------------------------
        send(3'd0, 4'hF, 4'd0, 16'd0, 16'd0, 16'd0, 16'd0);
        recv_ack("bind0");
        send(3'd0, 4'hF, 4'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        recv_ack("bind1");
        $display("bind  cells 0 and 1 bound (ACK seen)");

        // ---- a dial moves: THRESH (dial 5) default -> 0x2000 ----------
        do_view(4'd0, 2'd2, 4'd5, "THRESH before");
        expect16(v, 16'h6000, "thresh_por_default");
        send(3'd0, 4'hF, 4'd0, 16'd5, 16'h2000, 16'd0, 16'd0);
        recv_ack("dial_write");
        do_view(4'd0, 2'd2, 4'd5, "THRESH after");
        expect16(v, 16'h2000, "thresh_moved");

        // ---- link: cell 1 hears peer 2, base weight 0x1000 -------------
        send(3'd1, 4'd1, 4'd0, 16'd0, 16'h1000, 16'd0, 16'd0);
        do_view(4'd0, 2'd1, 4'd0, "wsum (edges)");

        // ---- effect: one flit from peer 1, act integrates --------------
        do_view(4'd0, 2'd0, 4'd0, "act before");
        expect16(v, 16'h0000, "act_starts_zero");
        send(3'd2, 4'd1, 4'd0, 16'd0, 16'd0, 16'd0, 16'h4000);
        repeat (48) @(negedge clk);      // engine: train (+1 cofire), read
                                        // w post-update, integrate (~15 cy)
        do_view(4'd0, 2'd0, 4'd0, "act after eff");
        // The effect TRAINS first (w: 0x1000 -> 0x1100 -- one bucket-0
        // cofire is worth 2^8 = 0x100), then integrates with the
        // post-update weight: act = (0x1100 * 0x4000) >>> 15 = 0x880.
        // Free-running ticks (every 16 cy) may already have leaked it:
        // act -= act >>> KA (KA=5): 0x880 -> 0x83C -> 0x7FB -> 0x7BC.
        case (v)
          16'h0880, 16'h083C, 16'h07FB, 16'h07BC: ;   // all legal
          default: begin
              errors = errors + 1;
              $display("FAIL act_after_effect: got %h", v);
          end
        endcase

        // ---- ticks: time passes, the leak pulls act down ---------------
        repeat (3*16 + 8) @(negedge clk);   // ~3 more ticks at TPW=4
        do_view(4'd0, 2'd0, 4'd0, "act +3 ticks");
        if (v >= 16'h0800 || v < 16'h0400) begin
            errors = errors + 1;
            $display("FAIL leak: act %h not in [0x0400,0x0800)", v);
        end

        if (errors == 0)
            $display("T1 PASS: bind->link->effect->view->tick, 0 errors");
        else
            $display("T1 FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin
        #1_000_000;
        $display("T1 FAIL: watchdog");
        $finish;
    end
endmodule
