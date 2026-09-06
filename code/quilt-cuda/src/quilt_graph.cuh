// ============================================================
// quilt_graph.cuh — a CUDA Graph IS a compiled cell graph
//
// BIND'd cells become kernel nodes. LINKs become graph edges.
// Instantiate = the LINK set, compiled. Launch = one TICK.
// Destroy = FORGET. The GPU's own dependency scheduler walks the
// wavefront — quilt's TICK is the hardware's day job.
//
// STATUS: written, UNCOMPILED — no nvcc in this WSL (see README).
// ============================================================

#ifndef QUILT_GRAPH_CUH
#define QUILT_GRAPH_CUH

#include <cuda_runtime.h>
#include <cstdint>
#include "quilt_cells.cuh"

#define QUILT_GRAPH_MAX_NODES 1024u

// Builder: holds the graph plus the node handles (a cell's kernel
// instance is identified by its cudaGraphNode_t).
typedef struct QuiltGraphBuilder {
    cudaGraph_t     graph;
    cudaGraphNode_t nodes[QUILT_GRAPH_MAX_NODES];
    uint32_t        count;
} QuiltGraphBuilder;

// The per-cell step kernel used as a graph node. Uniform signature so
// every cell is one kernel instance; deps (the LINKs) order them.
//   op selects the body (QuiltEffectOp); src is the cell whose value
//   feeds this one (src == cell for a source cell).
__global__ void graph_cell_step_kernel(QuiltArena arena, uint32_t cell,
                                       uint32_t src, uint32_t op,
                                       float p0, float p1, uint64_t tick);

#ifdef __cplusplus
extern "C" {
#endif

// Create an empty graph.
cudaError_t quilt_graph_begin(QuiltGraphBuilder* b);

// BIND a cell into the graph as a kernel node. `args` is an array of
// pointers to the kernel's arguments (arena, cell, src, op, p0, p1,
// tick) — the pointed-to values must stay alive until after
// quilt_graph_instantiate (params are captured there). Node index ==
// cell id in the demo; returns the node handle via `node_out` (may be
// NULL).
cudaError_t quilt_graph_add_cell(QuiltGraphBuilder* b, uint32_t cell,
                                 const QuiltArena* arena, uint32_t src,
                                 uint32_t op, float p0, float p1,
                                 uint64_t tick,
                                 cudaGraphNode_t* node_out);

// LINK: compile the edge list into graph dependencies. `cells` maps
// edge endpoints (cell ids) to the node handles recorded at add time.
cudaError_t quilt_graph_link(QuiltGraphBuilder* b, const QuiltEdge* edges,
                             uint32_t edge_count, const uint32_t* cells,
                             uint32_t cell_count);

// Instantiate — the LINK set, compiled. (WithFlags: CUDA >= 11.4.)
cudaError_t quilt_graph_instantiate(QuiltGraphBuilder* b,
                                    cudaGraphExec_t* exec);

// One TICK = one launch of the compiled cell graph.
cudaError_t quilt_graph_tick(cudaGraphExec_t exec, cudaStream_t stream);

// FORGET: destroy the compiled graph, then the graph itself.
cudaError_t quilt_graph_forget(cudaGraphExec_t* exec,
                               QuiltGraphBuilder* b);

#ifdef __cplusplus
}
#endif

#endif // QUILT_GRAPH_CUH
