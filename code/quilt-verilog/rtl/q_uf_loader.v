// q_uf_loader.v -- synthesizable streaming QUF container loader (v1).
//
// Doctrine item 3: state is a file. This module is the silicon mouth: it
// eats a QUF byte stream and populates the runtime state a cell needs --
// the q_dialfile image, the edge RAM slice, the route RAM, and the tick
// period exponent. Pure Verilog-2005, no vendor primitives; the same
// loader runs in simulation, on a soft core, and on an FPGA fabric.
//
// Stream contract: the q_io_port external-ingress handshake shape
// (valid/ready + 16-bit dat). Bytes arrive little-endian, low byte of
// each word first. The reference writer pads QUF files to `align` (>= 8),
// so the stream is always an integral number of words; o_rdy depends only
// on local state (skid discipline, no ready-chain loops).
//
// Loader profile (docs/QUF-SPEC.md §9): parses the fixed header, skips
// unknown KV pairs (skip is safe: every value's size follows from its
// type), captures `edge.k`, walks the section table, then streams the
// dials / edges / routing / ticks payloads. Edge walk state (wh, age,
// buckets) is consumed but not restored -- the v1 q_hebb_edge engines
// have no load port; the Python reference implements full state restore.
// Limits: file < 4 GiB (u64 high words must be zero), names <= 255 bytes,
// edge.k in 1..16.
//
// Error codes (o_err, sticky): 1 bad magic, 2 bad version, 3 layout
// overrun, 4 bad endian word, 5 known KV not u32, 6 unknown value type,
// 7 nonzero u64 high word, 8 name too long, 9 edge.k out of range,
// 12 crc32 digest mismatch (§12.2; the digest-blindness closure -- a
// corrupted-but-structural payload can no longer boot silently).
module q_uf_loader #(
    parameter AIDW = 4
)(
    input  wire               clk,
    input  wire               rst_n,

    // QUF byte stream (word-serialized; see header comment)
    input  wire               i_val,
    output wire               o_rdy,
    input  wire [15:0]        i_dat,

    // cell selector: dials row and edges with src == i_mycell are loaded
    input  wire [AIDW-1:0]    i_mycell,

    // populated: q_dialfile write port (byte-exact row image)
    output reg                o_dial_wr,
    output reg  [3:0]         o_dial_addr,
    output reg  [15:0]        o_dial_wdata,

    // populated: edge RAM word {base[15:0], dst[7:0], mode[7:0]} by slot
    output reg                o_edge_wr,
    output reg  [3:0]         o_edge_addr,
    output reg  [31:0]        o_edge_data,

    // populated: route RAM {dst, via} nibbles
    output reg                o_route_wr,
    output reg  [3:0]         o_route_dst,
    output reg  [3:0]         o_route_via,

    // populated: tick period exponent (ticks section, -> q_tick_sched TPW)
    output reg  [4:0]         o_tick_tpw,

    output reg                o_done,
    output reg  [7:0]         o_err
);
    localparam [7:0] E_MAGIC = 8'd1, E_VER = 8'd2, E_LAYOUT = 8'd3,
                     E_ENDIAN = 8'd4, E_KVTYPE = 8'd5, E_VTYPE = 8'd6,
                     E_BIG = 8'd7, E_NAME = 8'd8, E_EK = 8'd9,
                     E_CRC = 8'd12;

    // GGUF-compatible value-type ids
    localparam [3:0] VT_STR = 4'd8, VT_ARR = 4'd9;

    localparam [4:0] S_MAGIC = 5'd0,  S_VER    = 5'd1,  S_ENDIAN = 5'd2,
                     S_KVCNT  = 5'd3,  S_KVNL   = 5'd4,  S_KVNM   = 5'd5,
                     S_KVTP   = 5'd6,  S_KVVAL  = 5'd7,  S_STRN   = 5'd8,
                     S_ARRT   = 5'd9,  S_ARRC   = 5'd10, S_SKIP   = 5'd11,
                     S_SECNT  = 5'd12, S_SECNL  = 5'd13, S_SECNM  = 5'd14,
                     S_SECK   = 5'd15, S_SECO   = 5'd16, S_SECS   = 5'd17,
                     S_DATA   = 5'd18, S_DIALS  = 5'd19, S_EDGES  = 5'd20,
                     S_ROUTE  = 5'd21, S_TICKS  = 5'd22, S_DONE   = 5'd23,
                     S_ERRX   = 5'd24, S_FIN   = 5'd25;

    reg [4:0]   state;

    // ------------------------------------------------------------ stream --
    // one byte consumed every 1-of-3 cycles; o_rdy is local-only
    reg [1:0]   bph;      // 0 = accept word, 1 = low byte, 2 = high byte
    reg [15:0]  wbuf;

    wire        run    = (state != S_DONE) && (state != S_ERRX);
    wire        be_adv = (bph != 2'd0);
    wire [7:0]  be_b   = bph[1] ? wbuf[15:8] : wbuf[7:0];

    assign o_rdy = run && (bph == 2'd0);

    always @(posedge clk) begin
        if (!rst_n) begin
            bph  <= 2'd0;
            wbuf <= 16'd0;
        end else if (bph == 2'd0) begin
            if (run && i_val) begin
                wbuf <= i_dat;
                bph  <= 2'd1;
            end
        end else begin
            bph <= (bph == 2'd1) ? 2'd2 : 2'd0;
        end
    end

    // ------------------------------------------------------------ parse -- -
    reg [31:0]  pos;       // absolute byte position
    wire [31:0] posn = pos + 32'd1;   // index of the NEXT byte to consume
    reg [23:0]  v32;       // little-endian u32 shift tail (low byte via be_b)
    wire [31:0] v32n = {be_b, v32};         // first byte lands in [7:0]
    reg [1:0]   bc;        // byte-in-u32 counter
    reg [2:0]   bc8;       // byte-in-u64 counter
    reg [31:0]  skipcnt;
    reg [31:0]  kv_left, sec_left;

    // name capture (up to 16 bytes buffered; longer names -> no match)
    reg [127:0] nb;
    reg [4:0]   nlen;
    reg         nlong;
    reg [7:0]   nrem;
    wire [127:0] nbn   = (nlen < 5'd16) ? {nb[119:0], be_b} : nb;
    wire [4:0]   nlenn = (nlen < 5'd16) ? (nlen + 5'd1)     : nlen;

    wire [2:0]  kid = nlong ? 3'd0 :
                      (nlenn == 5'd6 && nbn[47:0] == "edge.k") ? 3'd1 :
                      (nlenn == 5'd5 && nbn[39:0] == "crc32")  ? 3'd2 : 3'd0;
    reg  [2:0]  kv_id;     // 0 none, 1 edge.k, 2 crc32

    // ----------------------------------------------------- crc32 digest --
    // §12.2: IEEE CRC32 (reflected, poly EDB88320, init/xor 0xFFFFFFFF)
    // over section PAYLOAD bytes in table order. Bit-serial combinational
    // step per consumed byte; one payload byte arrives per cycle (be_adv),
    // which the unrolled 8-step function keeps up with. KV/table/padding
    // bytes are excluded (the writer computes over the same byte set).
    function [31:0] crc32_next;
        input [31:0] c;
        input [7:0]  b;
        integer k;
        reg [31:0] x;
        begin
            x = c ^ {24'd0, b};
            for (k = 0; k < 8; k = k + 1)
                x = (x >> 1) ^ (x[0] ? 32'hEDB88320 : 32'd0);
            crc32_next = x;
        end
    endfunction

    reg [31:0]  crc_cur;
    reg [31:0]  crc_exp;
    reg         crc_have;   // crc32 KV present in this container
    wire        in_payload  = (state == S_DIALS) || (state == S_EDGES) ||
                              (state == S_ROUTE) || (state == S_TICKS);
    wire        payload_adv = in_payload && be_adv;

    // finish gate: a captured digest must match before the load is done.
    // crc_cur holds the RAW register; §12.2 stores the FINALIZED CRC32
    // (zlib convention, final xor 0xFFFFFFFF) -- finalize on compare.
    // NBA-order note: finish_ok must NOT check crc_cur in the same cycle
    // as the last payload byte -- the crc accumulator block commits that
    // byte's update via NBA and would be read stale (found by tb case 5:
    // the check compared a digest missing its final byte). One-cycle
    // S_FIN resolution state lets the accumulator land first.
    task finish_ok; begin
        state <= S_FIN;
    end endtask

    wire [2:0]  sid = nlong ? 3'd0 :
                      (nlenn == 5'd5  && nbn[39:0] == "dials")   ? 3'd1 :
                      (nlenn == 5'd5  && nbn[39:0] == "edges")   ? 3'd2 :
                      (nlenn == 5'd7  && nbn[55:0] == "routing") ? 3'd3 :
                      (nlenn == 5'd5  && nbn[39:0] == "ticks")   ? 3'd4 : 3'd0;
    reg  [2:0]  sec_id;    // 0 none, 1 dials, 2 edges, 3 routing, 4 ticks
    wire [1:0]  sec_idx = sec_id[1:0] - 2'd1;  // table slot of sec_id 1..4

    // section table (known sections only; unknown sections are skipped
    // implicitly because their bytes are never claimed)
    reg [3:0]   have;
    reg [31:0]  sec_off [0:3];
    reg [31:0]  sec_sz  [0:3];
    reg [31:0]  offtmp, sztmp;
    reg [3:0]   arrt;
    reg [31:0]  pleft;

    reg [4:0]   eK;        // edge.k ladder bucket count
    reg [4:0]   dcell;     // dials: current cell row
    reg [3:0]   dword;     // dials: word within row (dial address)
    reg [7:0]   dtmp;      // dials: first byte of word
    reg [5:0]   rbo;       // edges: byte within record
    reg [AIDW-1:0] e_src;
    reg [7:0]   e_dst, e_mode, etmp;
    reg [3:0]   e_slot;
    reg [15:0]  e_base;
    reg         rt_first;
    reg [3:0]   rt_tmp;
    reg         tphase;    // ticks: tpw captured, phases skipped

    // ------------------------------------------------------- dispatch ----
    function [31:0] mn32;
        input [31:0] a;
        input [31:0] b;
        mn32 = (a < b) ? a : b;
    endfunction

    wire [31:0] q0 = have[0] ? sec_off[0] : 32'hFFFFFFFF;
    wire [31:0] q1 = have[1] ? sec_off[1] : 32'hFFFFFFFF;
    wire [31:0] q2 = have[2] ? sec_off[2] : 32'hFFFFFFFF;
    wire [31:0] q3 = have[3] ? sec_off[3] : 32'hFFFFFFFF;
    wire [31:0] qmin = mn32(mn32(q0, q1), mn32(q2, q3));
    wire        qany = |have;
    wire [1:0]  qsec = (have[0] && qmin == q0) ? 2'd0 :
                       (have[1] && qmin == q1) ? 2'd1 :
                       (have[2] && qmin == q2) ? 2'd2 : 2'd3;
    wire [4:0]  pstate = (qsec == 2'd0) ? S_DIALS :
                         (qsec == 2'd1) ? S_EDGES :
                         (qsec == 2'd2) ? S_ROUTE : S_TICKS;
    // dispatch: the byte AFTER the one being consumed is at index posn;
    // a payload state must own exactly the bytes [offset, offset+size)
    wire        qok   = qany && (posn == qmin);
    wire        qwait = qany && (posn < qmin);

    // fuzz-fix (backend lane, 2026-08-29): table-end dispatch must see
    // the entry registered in THIS cycle (sec_id/offtmp/sztmp) -- the
    // committed have[] view is one NBA behind, so a single-section file
    // took the !qany branch and booted WITHOUT loading its only section,
    // and a truncated stream could reach done before its tail arrived
    // (released half-image). Same view as q0..3/pstate, plus candidate.
    wire        regv  = (sec_id != 3'd0) && (sztmp != 32'd0);
    wire [1:0]  ridx  = sec_idx;
    wire [31:0] qv0   = (regv && ridx == 2'd0) ? offtmp :
                        (have[0] ? sec_off[0] : 32'hFFFFFFFF);
    wire [31:0] qv1   = (regv && ridx == 2'd1) ? offtmp :
                        (have[1] ? sec_off[1] : 32'hFFFFFFFF);
    wire [31:0] qv2   = (regv && ridx == 2'd2) ? offtmp :
                        (have[2] ? sec_off[2] : 32'hFFFFFFFF);
    wire [31:0] qv3   = (regv && ridx == 2'd3) ? offtmp :
                        (have[3] ? sec_off[3] : 32'hFFFFFFFF);
    wire [31:0] qminX = mn32(mn32(qv0, qv1), mn32(qv2, qv3));
    wire        qanyX = (qv0 != 32'hFFFFFFFF) || (qv1 != 32'hFFFFFFFF) ||
                        (qv2 != 32'hFFFFFFFF) || (qv3 != 32'hFFFFFFFF);
    wire [1:0]  widx  = (qminX == qv0) ? 2'd0 : (qminX == qv1) ? 2'd1 :
                        (qminX == qv2) ? 2'd2 : 2'd3;
    wire [4:0]  pstateX = (widx == 2'd0) ? S_DIALS : (widx == 2'd1) ? S_EDGES :
                          (widx == 2'd2) ? S_ROUTE : S_TICKS;
    wire [31:0] psizeX  = (regv && ridx == widx) ? sztmp : sec_sz[widx];

    // array element byte-size shift: 1/2/4/8 are powers of two
    wire [31:0] ash = (arrt == 4'd0 || arrt == 4'd1 || arrt == 4'd7) ? 32'd0 :
                      (arrt == 4'd2 || arrt == 4'd3)                 ? 32'd1 :
                      (arrt == 4'd4 || arrt == 4'd5 || arrt == 4'd6) ? 32'd2
                                                                     : 32'd3;

    // edge record length - 1 (last byte offset): (12 + eK) - 1
    wire [5:0]  recl1 = {1'b0, eK} + 6'd11;

    task enter_payload; begin
        state       <= pstate;
        pleft       <= sec_sz[qsec];
        have[qsec]  <= 1'b0;
        dcell       <= 5'd0;
        dword       <= 4'd0;
        rbo         <= 6'd0;
        rt_first    <= 1'b1;
        bc          <= 2'd0;
        tphase      <= 1'b0;
    end endtask

    task goto_data; begin
        if (!qany) begin
            finish_ok;
        end else if (qok) begin
            enter_payload;
        end else if (qwait) begin
            state <= S_DATA;
        end else begin
            state <= S_ERRX;
            o_err <= E_LAYOUT;
        end
    end endtask

    task kv_done; begin
        kv_left <= kv_left - 32'd1;
        if (kv_left == 32'd1)
            state <= S_SECNT;
        else
            state <= S_KVNL;
    end endtask

    // crc32 accumulator (own block: payload bytes are the ONLY bytes it
    // sees, one per be_adv cycle; no other process assigns crc_cur)
    always @(posedge clk) begin
        if (!rst_n)
            crc_cur <= 32'hFFFFFFFF;
        else if (payload_adv)
            crc_cur <= crc32_next(crc_cur, be_b);
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= S_MAGIC;
            pos         <= 32'd0;
            v32         <= 24'd0;
            bc          <= 2'd0;
            bc8         <= 3'd0;
            skipcnt     <= 32'd0;
            kv_left     <= 32'd0;
            sec_left    <= 32'd0;
            nb          <= 128'd0;
            nlen        <= 5'd0;
            nlong       <= 1'b0;
            nrem        <= 8'd0;
            kv_id       <= 3'd0;
            sec_id      <= 3'd0;
            have        <= 4'd0;
            offtmp      <= 32'd0;
            sztmp       <= 32'd0;
            arrt        <= 4'd0;
            pleft       <= 32'd0;
            eK          <= 5'd8;
            dcell       <= 5'd0;
            dword       <= 4'd0;
            dtmp        <= 8'd0;
            rbo         <= 6'd0;
            e_src       <= {AIDW{1'b0}};
            e_dst       <= 8'd0;
            e_mode      <= 8'd0;
            etmp        <= 8'd0;
            e_slot      <= 4'd0;
            e_base      <= 16'd0;
            rt_first    <= 1'b1;
            rt_tmp      <= 4'd0;
            tphase      <= 1'b0;
            crc_exp     <= 32'd0;
            crc_have    <= 1'b0;
            o_dial_wr   <= 1'b0;
            o_dial_addr <= 4'd0;
            o_dial_wdata<= 16'd0;
            o_edge_wr   <= 1'b0;
            o_edge_addr <= 4'd0;
            o_edge_data <= 32'd0;
            o_route_wr  <= 1'b0;
            o_route_dst <= 4'd0;
            o_route_via <= 4'd0;
            o_tick_tpw  <= 5'd0;
            o_done      <= 1'b0;
            o_err       <= 8'd0;
        end else begin
            // one-cycle write pulses, cleared every cycle
            o_dial_wr  <= 1'b0;
            o_edge_wr  <= 1'b0;
            o_route_wr <= 1'b0;

            if (state == S_FIN) begin
                // digest check now that the final crc update has landed
                if (crc_have && ((crc_cur ^ 32'hFFFFFFFF) != crc_exp)) begin
                    state <= S_ERRX;
                    o_err <= E_CRC;
                end else begin
                    state  <= S_DONE;
                    o_done <= 1'b1;
                end
            end else if (be_adv) begin
                pos <= posn;

                case (state)
                  // ------------------------------------------------ header
                  S_MAGIC: begin
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n != 32'h00465551) begin  // "QUF\0" LE
                              state <= S_ERRX; o_err <= E_MAGIC;
                          end else begin
                              state <= S_VER;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_VER: begin
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n != 32'd1) begin
                              state <= S_ERRX; o_err <= E_VER;
                          end else begin
                              state <= S_ENDIAN;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_ENDIAN: begin
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n != 32'd1) begin
                              state <= S_ERRX; o_err <= E_ENDIAN;
                          end else begin
                              state <= S_KVCNT;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_KVCNT: begin
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc      <= 2'd0;
                          kv_left <= v32n;
                          if (v32n == 32'd0)
                              state <= S_SECNT;
                          else
                              state <= S_KVNL;
                      end else bc <= bc + 2'd1;
                  end

                  // ------------------------------------------------ KV ---
                  S_KVNL: begin  // name length (u32)
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc    <= 2'd0;
                          nlen  <= 5'd0;
                          nlong <= 1'b0;
                          nb    <= 128'd0;
                          if (v32n > 32'd255) begin
                              state <= S_ERRX; o_err <= E_NAME;
                          end else begin
                              nrem  <= v32n[7:0];
                              kv_id <= 3'd0;
                              if (v32n == 32'd0)
                                  state <= S_KVTP;
                              else
                                  state <= S_KVNM;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_KVNM: begin  // name bytes; match at last byte
                      nrem <= nrem - 8'd1;
                      if (nlen < 5'd16) begin
                          nb   <= nbn;
                          nlen <= nlenn;
                      end else begin
                          nlong <= 1'b1;
                      end
                      if (nrem == 8'd1) begin
                          kv_id <= kid;
                          state <= S_KVTP;
                      end
                  end
                  S_KVTP: begin  // value type (u32)
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (kv_id != 3'd0 && v32n != 32'd4) begin
                              state <= S_ERRX; o_err <= E_KVTYPE;
                          end else if (kv_id != 3'd0) begin
                              state <= S_KVVAL;
                          end else if (v32n == {28'd0, VT_STR}) begin
                              state <= S_STRN;
                          end else if (v32n == {28'd0, VT_ARR}) begin
                              state <= S_ARRT;
                          end else begin
                              case (v32n[3:0])
                                4'd0, 4'd1, 4'd7: begin
                                    skipcnt <= 32'd1; state <= S_SKIP;
                                end
                                4'd2, 4'd3: begin
                                    skipcnt <= 32'd2; state <= S_SKIP;
                                end
                                4'd4, 4'd5, 4'd6: begin
                                    skipcnt <= 32'd4; state <= S_SKIP;
                                end
                                4'd10, 4'd11, 4'd12: begin
                                    skipcnt <= 32'd8; state <= S_SKIP;
                                end
                                default: begin
                                    state <= S_ERRX; o_err <= E_VTYPE;
                                end
                              endcase
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_KVVAL: begin  // captured u32 value
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (kv_id == 3'd1) begin
                              if (v32n == 32'd0 || v32n > 32'd16) begin
                                  state <= S_ERRX; o_err <= E_EK;
                              end else begin
                                  eK <= v32n[4:0];
                                  kv_done;
                              end
                          end else begin  // kv_id == 2: crc32 (§12.2)
                              crc_exp  <= v32n;
                              crc_have <= 1'b1;
                              kv_done;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_STRN: begin  // string length (u32) -> skip
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n == 32'd0) begin
                              kv_done;
                          end else begin
                              skipcnt <= v32n;
                              state   <= S_SKIP;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_ARRT: begin  // array element type (u32)
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n > 32'd12 || v32n == 32'd8 ||
                              v32n == 32'd9) begin
                              state <= S_ERRX; o_err <= E_VTYPE;
                          end else begin
                              arrt  <= v32n[3:0];
                              state <= S_ARRC;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_ARRC: begin  // array element count (u32) -> skip
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc <= 2'd0;
                          if (v32n == 32'd0) begin
                              kv_done;
                          end else begin
                              skipcnt <= v32n << ash;
                              state   <= S_SKIP;
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_SKIP: begin  // skip skipcnt bytes
                      if (skipcnt > 32'd1)
                          skipcnt <= skipcnt - 32'd1;
                      else
                          kv_done;
                  end

                  // ------------------------------------------- section table
                  S_SECNT: begin  // section count (u32)
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc       <= 2'd0;
                          sec_left <= v32n;
                          if (v32n == 32'd0)
                              goto_data;
                          else
                              state <= S_SECNL;
                      end else bc <= bc + 2'd1;
                  end
                  S_SECNL: begin  // section name length (u32)
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc    <= 2'd0;
                          nlen  <= 5'd0;
                          nlong <= 1'b0;
                          nb    <= 128'd0;
                          if (v32n > 32'd255) begin
                              state <= S_ERRX; o_err <= E_NAME;
                          end else begin
                              nrem <= v32n[7:0];
                              if (v32n == 32'd0) begin
                                  sec_id <= 3'd0;
                                  state  <= S_SECK;
                              end else begin
                                  state <= S_SECNM;
                              end
                          end
                      end else bc <= bc + 2'd1;
                  end
                  S_SECNM: begin  // section name bytes
                      nrem <= nrem - 8'd1;
                      if (nlen < 5'd16) begin
                          nb   <= nbn;
                          nlen <= nlenn;
                      end else begin
                          nlong <= 1'b1;
                      end
                      if (nrem == 8'd1) begin
                          sec_id <= sid;
                          state  <= S_SECK;
                      end
                  end
                  S_SECK: begin  // kind (u32): 0 = raw bytes; ignored
                      v32 <= v32n[31:8];
                      if (bc == 2'd3) begin
                          bc    <= 2'd0;
                          bc8   <= 3'd0;
                          state <= S_SECO;
                      end else bc <= bc + 2'd1;
                  end
                  S_SECO: begin  // offset (u64): low 32 kept, high must be 0
                      v32 <= v32n[31:8];
                      if (bc8 == 3'd3) begin
                          offtmp <= v32n;
                          bc8    <= bc8 + 3'd1;
                      end else if (bc8 == 3'd7) begin
                          if (v32n != 32'd0) begin
                              state <= S_ERRX; o_err <= E_BIG;
                          end else begin
                              bc8   <= 3'd0;
                              state <= S_SECS;
                          end
                      end else bc8 <= bc8 + 3'd1;
                  end
                  S_SECS: begin  // size (u64): same shape
                      v32 <= v32n[31:8];
                      if (bc8 == 3'd3) begin
                          sztmp <= v32n;
                          bc8   <= bc8 + 3'd1;
                      end else if (bc8 == 3'd7) begin
                          if (v32n != 32'd0) begin
                              state <= S_ERRX; o_err <= E_BIG;
                          end else begin
                              bc8 <= 3'd0;
                              if (sec_id != 3'd0) begin
                              // fuzz-fix (backend lane, 2026-08-29): a
                              // zero-size known section must be SKIPPED,
                              // never entered -- enter_payload with
                              // pleft==0 underflowed (0-1 = 2^32-1) and
                              // the loader swallowed the rest of the file
                              // as payload bytes (split-brain vs quf.py,
                              // which treats an empty section as absent)
                              if (sztmp != 32'd0) begin
                                  sec_off[sec_idx] <= offtmp;
                                  sec_sz[sec_idx]  <= sztmp;
                                  have[sec_idx]    <= 1'b1;
                              end
                          end
                              sec_left <= sec_left - 32'd1;
                          if (sec_left == 32'd1) begin
                              // fuzz-fix: registration-aware dispatch (see
                              // qv0..3/qminX above). Mirrors goto_data +
                              // enter_payload, but with THIS cycle's entry
                              // in view; have[widx] clear wins the NBA
                              // ordering when the winner IS the entry
                              // being registered (consumed on entry).
                              if (!qanyX) begin
                                  finish_ok;
                              end else if (qminX == posn) begin
                                  state    <= pstateX;
                                  pleft    <= psizeX;
                                  have[widx] <= 1'b0;
                                  dcell    <= 5'd0;
                                  dword    <= 4'd0;
                                  rbo      <= 6'd0;
                                  rt_first <= 1'b1;
                                  bc       <= 2'd0;
                                  tphase   <= 1'b0;
                              end else if (qminX > posn) begin
                                  state <= S_DATA;
                              end else begin
                                  state <= S_ERRX; o_err <= E_LAYOUT;
                              end
                          end else
                              state <= S_SECNL;
                          end
                      end else bc8 <= bc8 + 3'd1;
                  end

                  // --------------------------------------------- payloads --
                  S_DATA: begin  // consume padding until next known section
                      if (!qany) begin
                          finish_ok;
                      end else if (posn == qmin) begin
                          enter_payload;
                      end else if (posn > qmin) begin
                          state <= S_ERRX; o_err <= E_LAYOUT;
                      end
                      // else: padding byte, stay
                  end
                  S_DIALS: begin  // cell_count rows x 16 x u16
                      if (bph == 2'd2) begin  // high byte completes a word
                          if (dcell[AIDW-1:0] == i_mycell) begin
                              o_dial_wr    <= 1'b1;
                              o_dial_addr  <= dword;
                              o_dial_wdata <= {be_b, dtmp};
                          end
                          if (dword == 4'd15) begin
                              dword <= 4'd0;
                              dcell <= dcell + 5'd1;
                          end else begin
                              dword <= dword + 4'd1;
                          end
                      end else begin
                          dtmp <= be_b;
                      end
                      pleft <= pleft - 32'd1;
                      if (pleft == 32'd1)
                          goto_data;
                  end
                  S_EDGES: begin  // records of 12 + eK bytes
                      case (rbo)
                        6'd0: e_src  <= be_b[AIDW-1:0];
                        6'd1: e_dst  <= be_b;
                        6'd2: e_mode <= be_b;
                        6'd3: e_slot <= be_b[3:0];
                        6'd4: etmp   <= be_b;
                        6'd5: e_base <= {be_b, etmp};
                        default: ;  // wh / age / buckets: skipped (profile)
                      endcase
                      if (rbo == recl1) begin
                          rbo <= 6'd0;
                          if (e_src == i_mycell) begin
                              o_edge_wr   <= 1'b1;
                              o_edge_addr <= e_slot;
                              o_edge_data <= {e_base, e_dst, e_mode};
                          end
                      end else begin
                          rbo <= rbo + 6'd1;
                      end
                      pleft <= pleft - 32'd1;
                      if (pleft == 32'd1)
                          goto_data;
                  end
                  S_ROUTE: begin  // records of u8 dst, u8 via
                      if (rt_first) begin
                          rt_tmp   <= be_b[3:0];
                          rt_first <= 1'b0;
                      end else begin
                          o_route_wr  <= 1'b1;
                          o_route_dst <= rt_tmp;
                          o_route_via <= be_b[3:0];
                          rt_first    <= 1'b1;
                      end
                      pleft <= pleft - 32'd1;
                      if (pleft == 32'd1)
                          goto_data;
                  end
                  S_TICKS: begin  // u32 tpw, then cell_count u32 phases
                      if (!tphase) begin
                          v32 <= v32n[31:8];
                          if (bc == 2'd3) begin
                              bc         <= 2'd0;
                              o_tick_tpw <= v32n[4:0];
                              tphase     <= 1'b1;
                          end else begin
                              bc <= bc + 2'd1;
                          end
                      end
                      pleft <= pleft - 32'd1;
                      if (pleft == 32'd1)
                          goto_data;
                  end

                  default: ;  // S_DONE / S_ERRX: hold
                endcase
            end
        end
    end

endmodule
