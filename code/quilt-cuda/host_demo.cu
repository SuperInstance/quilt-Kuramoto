// ============================================================
// host_demo.cu — three cells, two TICK paths, one witness chain
//
// The graph:  input --LINK--> rsi --LINK--> filter
//   cell 0 "input"  : BIND 2.0, body SET 2.0
//   cell 1 "rsi"    : body SCALE x3        (2.0 -> 6.0)
//   cell 2 "filter" : body CLAMP [0, 5]    (6.0 -> 5.0)
//
// Path A: the compiled cell graph (cudaGraph). BIND the cells as
//         kernel nodes, LINK via cudaGraphAddDependencies, instantiate
//         (compile), launch one TICK. The scheduler IS the wavefront.
// Path B: the device-resident wavefront (tick_wavefront_kernel over
//         the edge list, Kahn-style) — the path a persistent kernel
//         uses when there is no host in the loop.
//
// Then VIEW (pure readback), the witness chain, the arena witness
// union, and the warp votes (the consensus cells). FORGET at the end.
//
// STATUS: written, UNCOMPILED and UNRUN — no nvcc in this WSL and the
// dxgk bridge is unstable tonight (no GPU runs, by directive). The
// expected-output block below is a hand-computed prediction, clearly
// labeled as such, not a transcript.
// ============================================================

#include <cstdio>
#include "src/quilt_cells.cuh"
#include "src/quilt_graph.cuh"

static const char* fringe_name(uint8_t f) {
    switch (f) {
        case FRINGE_HIGH: return "HIGH  (>= 0.9989 — fleet fringe)";
        case FRINGE_LOW:  return "LOW   (>= 0.9004 — passing fringe)";
        default:          return "SPLIT";
    }
}

static const char* op_name(uint8_t o) {
    switch (o) {
        case QOP_BIND:   return "BIND";
        case QOP_LINK:   return "LINK";
        case QOP_EFFECT: return "EFFECT";
        case QOP_VIEW:   return "VIEW";
        case QOP_TICK:   return "TICK";
        case QOP_FORGET: return "FORGET";
        default:         return "NOP";
    }
}

#define QCHECK(e) do { cudaError_t _e = (e); if (_e != cudaSuccess) { \
    printf("quilt-cuda: CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
           cudaGetErrorString(_e)); return 1; } } while (0)

static void print_chain(const char* tag, const float* v, const uint32_t* w,
                        const uint64_t* l, const uint8_t* o, uint32_t n) {
    printf("  %s witness chain:\n", tag);
    for (uint32_t c = 0; c < n; ++c) {
        printf("    [cell %u] value=%8.3f  witness=0x%08X  lamport=%llu  %s\n",
               c, (double)v[c], w[c], (unsigned long long)l[c], op_name(o[c]));
    }
}

int main() {
    const uint32_t    N_CELLS = 3u;
    const uint32_t    N_EDGES = 2u;
    const char*       names[3] = { "input", "rsi", "filter" };

    QuiltArena arena;
    QCHECK(quilt_arena_create(&arena, N_CELLS));

    // ------------------------------------------------------------
    // PATH A — the compiled cell graph
    // ------------------------------------------------------------
    printf("quilt-cuda host_demo — the GPU already thinks in cell graphs\n");
    printf("path A: cudaGraph as the compiled cell graph (input -> rsi -> filter)\n");

    // BIND cell 0 first (allocation + label, tick 1).
    QCHECK(quilt_bind(&arena, 0u, 2.0f, 1ull));

    QuiltGraphBuilder b;
    QCHECK(quilt_graph_begin(&b));
    // Cells as kernel nodes; per-node args carry the body.
    //   cell 0: SET 2.0 (src=self)   cell 1: SCALE 3 (src=0)   cell 2: CLAMP 0..5 (src=1)
    QCHECK(quilt_graph_add_cell(&b, 0u, &arena, 0u, EFF_SET,   2.0f, 0.0f, 2ull, NULL));
    QCHECK(quilt_graph_add_cell(&b, 1u, &arena, 0u, EFF_SCALE, 3.0f, 0.0f, 2ull, NULL));
    QCHECK(quilt_graph_add_cell(&b, 2u, &arena, 1u, EFF_CLAMP, 0.0f, 5.0f, 2ull, NULL));

    // The LINKs: 0->1, 1->2.
    QuiltEdge edges[N_EDGES] = { {0u, 1u}, {1u, 2u} };
    uint32_t  cells[N_CELLS] = { 0u, 1u, 2u };
    QCHECK(quilt_graph_link(&b, edges, N_EDGES, cells, N_CELLS));

    cudaGraphExec_t exec;
    QCHECK(quilt_graph_instantiate(&b, &exec));
    printf("  compiled cell graph: %u nodes, %u LINKs -> cudaGraphExec\n",
           b.count, N_EDGES);

    // One TICK = one launch. The wavefront IS the GPU scheduler.
    QCHECK(quilt_graph_tick(exec, nullptr));   // default stream
    QCHECK(cudaDeviceSynchronize());
    printf("  TICK: one cudaGraphLaunch — wavefront resolved by hardware\n");

    // VIEW — pure readback, no device write in the path.
    float    hv[3]; uint32_t hw[3]; uint64_t hl[3]; uint8_t ho[3];
    QCHECK(quilt_view(&arena, hv, hw, hl, ho));
    print_chain("path A", hv, hw, hl, ho, N_CELLS);

    // Witness union (the L1 law at arena scale).
    uint32_t* d_union = NULL;
    uint32_t  h_union = 0u;
    QCHECK(cudaMalloc((void**)&d_union, sizeof(uint32_t)));
    QCHECK(cudaMemset(d_union, 0, sizeof(uint32_t)));
    witness_union_kernel<<<1, 32>>>(arena, d_union);
    QCHECK(cudaGetLastError());
    QCHECK(cudaDeviceSynchronize());
    QCHECK(cudaMemcpy(&h_union, d_union, sizeof(uint32_t), cudaMemcpyDeviceToHost));
    printf("  witness union (OR, idempotent): 0x%08X\n", h_union);

    // Warp votes — one warp = one consensus cell.
    WarpVote* d_votes = NULL;
    WarpVote  h_votes[3];
    QCHECK(cudaMalloc((void**)&d_votes, 3 * sizeof(WarpVote)));
    warp_vote_kernel<<<1, 96>>>(arena, d_votes);   // 3 warps, one per cell
    QCHECK(cudaGetLastError());
    QCHECK(cudaDeviceSynchronize());
    QCHECK(cudaMemcpy(h_votes, d_votes, 3 * sizeof(WarpVote), cudaMemcpyDeviceToHost));
    for (uint32_t c = 0; c < N_CELLS; ++c) {
        printf("    [%s] consensus cell %u: ballot=0x%08X  consensus=%.5f  %s\n",
               names[c], c, h_votes[c].ballot, (double)h_votes[c].consensus,
               fringe_name(h_votes[c].fringe));
    }

    // FORGET the compiled graph.
    QCHECK(quilt_graph_forget(&exec, &b));
    printf("  FORGET: graph exec destroyed, graph destroyed\n");

    // ------------------------------------------------------------
    // PATH B — the device-resident wavefront (Kahn-style, edge list)
    // ------------------------------------------------------------
    printf("path B: device-resident wavefront over the edge list\n");

    // Fresh arena; body arrays ride in device memory this time.
    QCHECK(quilt_arena_destroy(&arena));
    QCHECK(quilt_arena_create(&arena, N_CELLS));

    uint32_t h_body[3]  = { EFF_SET, EFF_SCALE, EFF_CLAMP };
    float    h_p0[3]    = { 2.0f, 3.0f, 0.0f };
    float    h_p1[3]    = { 0.0f, 0.0f, 5.0f };
    QCHECK(cudaMemcpy(arena.body_op, h_body, 3 * sizeof(uint32_t), cudaMemcpyHostToDevice));
    QCHECK(cudaMemcpy(arena.body_p0, h_p0,   3 * sizeof(float),    cudaMemcpyHostToDevice));
    QCHECK(cudaMemcpy(arena.body_p1, h_p1,   3 * sizeof(float),    cudaMemcpyHostToDevice));

    uint32_t h_indeg[3] = { 0u, 1u, 1u };
    uint32_t *d_indeg = NULL, *d_done = NULL, *d_completed = NULL, *d_released = NULL;
    QuiltEdge* d_edges = NULL;
    QCHECK(cudaMalloc((void**)&d_indeg,     3 * sizeof(uint32_t)));
    QCHECK(cudaMalloc((void**)&d_completed, 3 * sizeof(uint32_t)));
    QCHECK(cudaMalloc((void**)&d_released,  N_EDGES * sizeof(uint32_t)));
    QCHECK(cudaMalloc((void**)&d_done,      sizeof(uint32_t)));
    QCHECK(cudaMalloc((void**)&d_edges,     N_EDGES * sizeof(QuiltEdge)));
    QCHECK(cudaMemcpy(d_indeg,  h_indeg, 3 * sizeof(uint32_t), cudaMemcpyHostToDevice));
    QCHECK(cudaMemcpy(d_edges,  edges,   N_EDGES * sizeof(QuiltEdge), cudaMemcpyHostToDevice));
    QCHECK(cudaMemset(d_completed, 0, 3 * sizeof(uint32_t)));
    QCHECK(cudaMemset(d_released, 0, N_EDGES * sizeof(uint32_t)));
    QCHECK(cudaMemset(d_done,     0, sizeof(uint32_t)));

    // TICK = loop passes to quiescence. One pass = one wavefront level.
    uint32_t done = 0u; uint64_t pass = 0ull;
    while (done < N_CELLS && pass < (uint64_t)N_CELLS + 2ull) {
        pass++;
        tick_wavefront_kernel<<<1, 32>>>(arena, d_edges, N_EDGES, d_indeg,
                                         d_completed, d_released, pass,
                                         d_done);
        QCHECK(cudaGetLastError());
        QCHECK(cudaDeviceSynchronize());
        QCHECK(cudaMemcpy(&done, d_done, sizeof(uint32_t), cudaMemcpyDeviceToHost));
        printf("  TICK pass %llu: %u/%u cells fired\n",
               (unsigned long long)pass, done, N_CELLS);
    }

    QCHECK(quilt_view(&arena, hv, hw, hl, ho));
    print_chain("path B", hv, hw, hl, ho, N_CELLS);

    // ------------------------------------------------------------
    // FORGET the cells, free everything.
    // ------------------------------------------------------------
    for (uint32_t c = 0; c < N_CELLS; ++c) QCHECK(quilt_forget_cell(&arena, c));
    QCHECK(cudaDeviceSynchronize());
    QCHECK(quilt_view(&arena, hv, hw, hl, ho));
    printf("  after FORGET: opcodes = %s %s %s (witnesses cleared, values zeroed)\n",
           op_name(ho[0]), op_name(ho[1]), op_name(ho[2]));

    cudaFree(d_union); cudaFree(d_votes); cudaFree(d_indeg);
    cudaFree(d_completed); cudaFree(d_released); cudaFree(d_done);
    cudaFree(d_edges);
    QCHECK(quilt_arena_destroy(&arena));

    printf("done. the wavefront was the scheduler all along.\n");

    // ------------------------------------------------------------
    // EXPECTED OUTPUT (hand-computed prediction — UNCOMPILED, UNRUN;
    // no nvcc in this WSL, no GPU runs tonight):
    //
    //   path A: cell0 value=2.000  witness=0xC0000000*  lamport=2  EFFECT|BIND
    //           cell1 value=6.000  witness=0x80C00000   lamport=2  EFFECT
    //           cell2 value=5.000  witness=0x80A00000   lamport=2  EFFECT
    //   union   = 0xC0E00000
    //   consensus cells: ballot == the witness word re-derived;
    //           consensus = popc/32 (2/32, 3/32, 3/32 -> all SPLIT;
    //           a lit word is mostly dark — the fringes are fleet
    //           statements, see docs/QUILT-CUDA.md §8)
    //   path B: same values/witnesses (minus W_BOUND on cell 0, which
    //           only path A's explicit bind plants), lamports 1..3
    //   (*2.0f = 0x40000000, whose trit bits 0..29 are all zero —
    //    the W marks alone light the word; the state carries its own
    //    witness, and 2.0's witness is its two marks.)
    // ------------------------------------------------------------
    return 0;
}
