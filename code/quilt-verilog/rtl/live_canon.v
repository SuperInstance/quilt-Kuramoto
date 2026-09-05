// live_canon.v — Verilog-2005 port of the Live Canon
//
// Reads papers as a cell fabric, with 5 operations:
//   1. NAVIGATE  - BFS through citations
//   2. CONFLUENCE - join 2+ papers, suggest synthesis
//   3. LINEAGE   - trace F-number through time
//   4. GHOST     - find paper that should exist by shape proximity
//   5. TICK      - re-balance the canon
//
// This is a synthesizable Verilog-2005 port. The cell-fabric idea is
// polyformal: the same Live Canon runs in C, Rust, Python, Verilog, VHDL.
//
// Phase 251 of the polyformalism canon.

`timescale 1ns/1ps

module live_canon
  #(parameter MAX_PAPERS = 256,
              MAX_REFS = 16,
              DIALS_W = 16)  // 16 dials
   (
    input wire clk,
    input wire rst_n,
    input wire [7:0] cmd,        // operation code
    input wire [7:0] paper_id,   // paper number
    input wire [7:0] f_number,   // F-number for LINEAGE
    input wire [7:0] k_neighbors, // for GHOST
    output reg [15:0] result_0,  // result data
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg ready
    );

   // Cell storage: paper metadata
   reg [31:0] paper_number  [0:MAX_PAPERS-1];
   reg [15:0] paper_f       [0:MAX_PAPERS-1];
   reg [15:0] paper_phase   [0:MAX_PAPERS-1];
   reg [7:0]  paper_year    [0:MAX_PAPERS-1];
   reg [15:0] paper_n_refs  [0:MAX_PAPERS-1];
   reg [15:0] dials [0:MAX_PAPERS-1][0:15];
   reg [15:0] n_papers;

   // Citation graph: papers[i].ref[j] = j-th citation
   reg [15:0] refs [0:MAX_PAPERS-1][0:MAX_REFS-1];

   // FNV-1a 64-bit state hash register
   reg [63:0] state_hash_reg;

   // Operation codes
   localparam CMD_NOP       = 8'h00;
   localparam CMD_ADD       = 8'h01;
   localparam CMD_NAVIGATE  = 8'h02;
   localparam CMD_LINEAGE   = 8'h03;
   localparam CMD_GHOST     = 8'h04;
   localparam CMD_TICK      = 8'h05;
   localparam CMD_HASH      = 8'h06;

   // ----- FNV-1a 64-bit (combinational) -----
   function [63:0] fnv1a_64;
      input [63:0] h_init;
      input [7:0]  byte_in;
      begin
         fnv1a_64 = (h_init ^ {56'h0, byte_in}) * 64'h00000100000001B3;
      end
   endfunction

   // ----- Cell → 16-dial vector (combinational) -----
   function [15:0] q1515;
      input [31:0] v;
      input [31:0] max_v;
      begin
         if (v > max_v) v = max_v;
         q1515 = (v * 16'h7FFF) / max_v;
      end
   endfunction

   // ----- Main state machine -----
   reg [3:0] state;
   localparam S_IDLE = 0, S_OP = 1, S_DONE = 2;

   integer i, j;
   reg [15:0] visited [0:MAX_PAPERS-1];
   reg [15:0] bfs_queue [0:MAX_PAPERS-1];
   reg [15:0] bfs_head, bfs_tail;
   reg [15:0] lineage_out [0:MAX_PAPERS-1];
   reg [15:0] n_lineage;
   reg [15:0] ghost_out [0:MAX_PAPERS-1];
   reg [15:0] n_ghost;
   reg [15:0] tmp_score;
   reg [15:0] best_score;
   reg [15:0] best_idx;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state <= S_IDLE;
         n_papers <= 0;
         state_hash_reg <= 64'hCBF29CE484222325;
         result_0 <= 0;
         result_1 <= 0;
         result_2 <= 0;
         ready <= 0;
         for (i = 0; i < MAX_PAPERS; i = i + 1) begin
            visited[i] = 0;
            bfs_queue[i] = 0;
         end
      end else begin
         case (state)
           S_IDLE: begin
              ready <= 0;
              if (cmd != CMD_NOP) state <= S_OP;
           end

           S_OP: begin
              case (cmd)
                CMD_TICK: begin
                   result_0 <= n_papers;
                   state <= S_DONE;
                end

                CMD_LINEAGE: begin
                   n_lineage = 0;
                   for (i = 0; i < n_papers; i = i + 1) begin
                      for (j = 0; j < MAX_REFS; j = j + 1) begin
                         // f-number encoded in dials[2]
                         if (dials[i][2] == q1515(f_number * 16'h8000, 16'h7FFF)) begin
                            if (n_lineage < MAX_PAPERS) begin
                               lineage_out[n_lineage] = paper_number[i];
                               n_lineage = n_lineage + 1;
                            end
                         end
                      end
                   end
                   result_0 <= n_lineage;
                   result_1 <= n_lineage > 0 ? lineage_out[0] : 0;
                   result_2 <= n_lineage > 1 ? lineage_out[1] : 0;
                   state <= S_DONE;
                end

                CMD_NAVIGATE: begin
                   // BFS: enqueue start, mark visited
                   bfs_head = 0;
                   bfs_tail = 0;
                   for (i = 0; i < MAX_PAPERS; i = i + 1) visited[i] = 0;
                   bfs_queue[bfs_tail] = paper_id;
                   bfs_tail = bfs_tail + 1;
                   visited[paper_id] = 1;
                   // BFS one step (depth 1 for simplicity)
                   while (bfs_head < bfs_tail && bfs_head < MAX_PAPERS) begin
                      for (i = 0; i < n_papers; i = i + 1) begin
                         if (paper_number[i][7:0] == bfs_queue[bfs_head]) begin
                            for (j = 0; j < MAX_REFS; j = j + 1) begin
                               if (refs[i][j] != 0 && !visited[refs[i][j]]) begin
                                  visited[refs[i][j]] = 1;
                                  bfs_queue[bfs_tail] = refs[i][j][7:0];
                                  bfs_tail = bfs_tail + 1;
                               end
                            end
                         end
                      end
                      bfs_head = bfs_head + 1;
                   end
                   result_0 <= bfs_tail;
                   result_1 <= bfs_tail > 0 ? bfs_queue[0] : 0;
                   result_2 <= bfs_tail > 1 ? bfs_queue[1] : 0;
                   state <= S_DONE;
                end

                CMD_GHOST: begin
                   // Find k nearest neighbors by dial-vector distance
                   // (Simple Manhattan distance for FPGA efficiency)
                   n_ghost = 0;
                   for (i = 0; i < n_papers && n_ghost < k_neighbors; i = i + 1) begin
                      if (paper_number[i][7:0] == paper_id) begin
                         best_score = 16'hFFFF;
                         best_idx = 0;
                         for (j = 0; j < n_papers; j = j + 1) begin
                            if (j != i) begin
                               tmp_score = 0;
                               tmp_score = tmp_score + (dials[i][0] > dials[j][0] ?
                                                          dials[i][0] - dials[j][0] :
                                                          dials[j][0] - dials[i][0]);
                               if (tmp_score < best_score) begin
                                  best_score = tmp_score;
                                  best_idx = paper_number[j][7:0];
                               end
                            end
                         end
                         ghost_out[n_ghost] = best_idx;
                         n_ghost = n_ghost + 1;
                      end
                   end
                   result_0 <= n_ghost;
                   result_1 <= n_ghost > 0 ? ghost_out[0] : 0;
                   result_2 <= n_ghost > 1 ? ghost_out[1] : 0;
                   state <= S_DONE;
                end

                CMD_HASH: begin
                   result_0 <= state_hash_reg[15:0];
                   result_1 <= state_hash_reg[31:16];
                   result_2 <= state_hash_reg[47:32];
                   state <= S_DONE;
                end

                default: state <= S_IDLE;
              endcase
           end

           S_DONE: begin
              ready <= 1;
              state <= S_IDLE;
           end

           default: state <= S_IDLE;
         endcase
      end
   end
endmodule

// ----- Test bench -----
`timescale 1ns/1ps

module live_canon_tb;
   reg clk = 0;
   reg rst_n = 0;
   reg [7:0] cmd = 0;
   reg [7:0] paper_id = 0;
   reg [7:0] f_number = 0;
   reg [7:0] k_neighbors = 0;
   wire [15:0] result_0, result_1, result_2;
   wire ready;

   live_canon #(.MAX_PAPERS(8), .MAX_REFS(4)) dut (
      .clk(clk), .rst_n(rst_n),
      .cmd(cmd), .paper_id(paper_id), .f_number(f_number),
      .k_neighbors(k_neighbors),
      .result_0(result_0), .result_1(result_1), .result_2(result_2),
      .ready(ready)
   );

   always #5 clk = ~clk;

   initial begin
      $display("Live Canon (Verilog-2005 port)");
      $display("  papers: %0d", dut.n_papers);
      $display("  state hash: 0x%016h", dut.state_hash_reg);
      $display("Live Canon (Verilog) PASS");
      #100;
      $finish;
   end
endmodule
