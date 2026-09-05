// ============================================================
// quilt_cells.cuh — the quilt substrate on CUDA
//
// A cell = a slice of device memory + its W13 witness word.
// The 5+1 opcodes: BIND, LINK, EFFECT, VIEW, TICK (+ FORGET).
//
// Part of SuperInstance/quilt-cuda. Wired to the cudaclaw organs
// (persistent kernel pattern, SmartCRDT LWW discipline) — referenced,
// never modified. See docs/QUILT-CUDA.md.
//
// STATUS: written, UNCOMPILED — no nvcc in this WSL (see README).
// ============================================================

#ifndef QUILT_CELLS_CUH
#define QUILT_CELLS_CUH

#include <cuda_runtime.h>
#include <cstdint>

// ------------------------------------------------------------
// Constants
// ------------------------------------------------------------

#define QUILT_WARP_SIZE 32u
#define QUILT_FULL_MASK 0xFFFFFFFFu

// W13 witness word layout:
//   bits  0..29 : trit witnesses (bit i set <=> bit i of the raw state
//                 word is set — the state carries its own witness)
//   bit  30     : W_BOUND  — allocation witnessed (BIND)
//   bit  31     : W_DIRTY  — mutation witnessed (EFFECT since BIND)
#define QUILT_W_TRIT_MASK 0x3FFFFFFFu
#define QUILT_W_BOUND     (1u << 30)
#define QUILT_W_DIRTY     (1u << 31)

// Consensus fringes (named, from the canon). A single warp resolves
// consensus in steps of 1/32; the high fringe is by construction a
// multi-warp (>= 909 lanes) statement. See docs/QUILT-CUDA.md §8.
#define QUILT_FRINGE_HIGH 0.9989f
#define QUILT_FRINGE_LOW  0.9004f

// ------------------------------------------------------------
// Opcodes (the 5 + the quiet sixth)
// ------------------------------------------------------------

enum QuiltOpcode : uint8_t {
    QOP_NOP    = 0,
    QOP_BIND   = 1,  // label a value at a key
    QOP_LINK   = 2,  // relate two cells
    QOP_EFFECT = 3,  // run a function
    QOP_VIEW   = 4,  // project state (pure — host side)
    QOP_TICK   = 5,  // advance time (wavefront)
    QOP_FORGET = 6   // retire the cell
};

// ------------------------------------------------------------
// Cell body ops (what fires when the cell TICKs — the MuscleFiber
// pattern from cudaclaw: a cell is assigned its kernel by role)
// ------------------------------------------------------------

enum QuiltEffectOp : uint32_t {
    EFF_NOP   = 0,
    EFF_SET   = 1,   // value = p0                      (the BIND body)
    EFF_SCALE = 2,   // value *= p0
    EFF_ADD   = 3,   // value += p0
    EFF_CLAMP = 4,   // value = clamp(value, p0, p1)
    EFF_RSI   = 5,   // one-step smoothing: value = value*(1-1/p0) + p1/p0
    EFF_PTX   = 6    // future: body is Flux-compiled PTX loaded via
                     // cudaclaw's NVRTC path (roadmap item 3)
};

// ------------------------------------------------------------
// The arena (SoA — coalesced, same discipline as SmartCRDT)
// ------------------------------------------------------------

typedef struct QuiltArena {
    float*     value;    // cell state
    uint32_t*  witness;  // W13 witness word, one u32 per cell
    uint64_t*  lamport;  // per-cell Lamport clock (TICK_monotonicity)
    uint32_t*  node_id;  // last writer — LWW tiebreak, as CRDTCell
    uint8_t*   opcode;   // last opcode that touched the cell (telemetry)
    uint32_t*  body_op;  // the cell's effect body
    float*     body_p0;  // body param 0
    float*     body_p1;  // body param 1
    uint32_t   count;
} QuiltArena;

// ------------------------------------------------------------
// The edge (LINK as data — the device-resident representation)
// ------------------------------------------------------------

typedef struct QuiltEdge {
    uint32_t src;
    uint32_t dst;
} QuiltEdge;

// Consensus report, one per consensus cell (one warp)
typedef struct WarpVote {
    uint32_t ballot;     // the witness word re-derived from 32 lane votes
    float    consensus;  // popc(ballot) / 32
    uint8_t  fringe;     // QuiltFringe
    uint8_t  _pad[3];
} WarpVote;

enum QuiltFringe : uint8_t {
    FRINGE_SPLIT = 0,
    FRINGE_LOW   = 1,
    FRINGE_HIGH  = 2
};

// A CRDT merge op — mirrors cudaclaw CRDTCell's (timestamp, node_id)
// LWW ordering. The witness of a losing merge still unions in:
// observation is never discarded.
typedef struct MergeOp {
    uint32_t cell_id;
    float    value;
    uint64_t lamport;
    uint32_t node_id;
    uint32_t witness;
} MergeOp;

// ------------------------------------------------------------
// Device helpers
// ------------------------------------------------------------

// Trit witnesses: bits of the raw state word. Host+device safe
// (byte-copy bit-cast; no strict-aliasing UB, no device-only intrinsic).
__host__ __device__ static inline uint32_t quilt_trits_of(float v) {
    uint32_t u;
    const unsigned char* p = (const unsigned char*)&v;
    unsigned char* q = (unsigned char*)&u;
    q[0] = p[0]; q[1] = p[1]; q[2] = p[2]; q[3] = p[3];
    return u & QUILT_W_TRIT_MASK;
}

// Apply a body op to a state value (the algorithmic cell body).
__host__ __device__ static inline float quilt_apply_body(uint32_t op,
                                                         float v,
                                                         float p0,
                                                         float p1) {
    switch (op) {
        case EFF_SET:   return p0;
        case EFF_SCALE: return v * p0;
        case EFF_ADD:   return v + p0;
        case EFF_CLAMP: return v < p0 ? p0 : (v > p1 ? p1 : v);
        case EFF_RSI: {
            float inv = 1.0f / p0;
            return v * (1.0f - inv) + p1 * inv;
        }
        default:        return v;
    }
}

// ------------------------------------------------------------
// Kernels (defined in quilt_cells.cu)
// ------------------------------------------------------------

// BIND: write the value, plant W_BOUND + trit witnesses, stamp the clock.
// Idempotent: bind(c,v);bind(c,v) leaves the same words (L1).
__global__ void bind_kernel(QuiltArena arena, uint32_t cell_id, float value,
                            uint64_t tick);

// EFFECT: mutate one cell's state through its body op. Sets W_DIRTY.
__global__ void cell_effect_kernel(QuiltArena arena, uint32_t cell_id,
                                   uint32_t op, float p0, float p1,
                                   uint64_t tick);

// The L1 law at fleet scale: union every witness word in the arena.
// Grid-stride OR + warp shuffle-OR reduce + one atomicOr per warp.
// out_union must be pre-zeroed.
__global__ void witness_union_kernel(const QuiltArena arena,
                                     uint32_t* out_union);

// The consensus cell: one warp = one cell. Lane i votes bit i of the
// cell's witness word (trits at lanes 0-29, W marks at lanes 30-31).
// __ballot_sync re-derives the witness word from 32 independent lane
// observations; popc/32 is the consensus fraction. Launch with
// blockDim a multiple of 32; global warp index w votes on cell w.
__global__ void warp_vote_kernel(const QuiltArena arena, WarpVote* votes);

// TICK, device-resident path: Kahn-style wavefront over the edge list.
// One launch = one pass (one wavefront level). Fire phase: cells with
// indegree 0 apply their body. Release phase: edges out of completed
// cells push value (atomicAdd) and decrement successor indegree.
// All cross-block state is touched via atomics — L1 is not coherent
// across SMs, and this kernel must not read a stale line. Same-pass
// release may lag one pass (no grid-wide barrier inside a launch);
// the host loops until done_count == arena.count.
__global__ void tick_wavefront_kernel(QuiltArena arena, QuiltEdge* edges,
                                      uint32_t edge_count,
                                      uint32_t* indegree,
                                      uint32_t* completed,
                                      uint32_t* edge_released,
                                      uint64_t tick,
                                      uint32_t* done_count);

// CRDT merge, simplified LWW surface (see caveat in the .cu). Ordered
// by (lamport, node_id) exactly like cudaclaw's CRDTCell; witnesses
// union unconditionally.
__global__ void crdt_merge_kernel(QuiltArena arena, const MergeOp* ops,
                                  uint32_t op_count);

// FORGET, device side: zero the state, clear the witness, plant the
// opcode. The archive gesture before the free.
__global__ void forget_kernel(QuiltArena arena, uint32_t cell_id);

// Persistent cell agent — a SKETCH of the cudaclaw executor.cu pattern
// (one warp, launched once, polls a unified-memory doorbell; ops arrive,
// __shfl_sync broadcasts, the warp executes against the arena).
// DO NOT launch blind: it only exits when doorbell == SHUTDOWN.
// Roadmap item 4 — the real doorbell is the cudaclaw SPSC queue ABI
// from kernels/shared_types.h.
#define QCA_OP_NOP     0ull
#define QCA_OP_BIND    1ull
#define QCA_OP_EFFECT  2ull
#define QCA_OP_MERGE   3ull
#define QCA_OP_SHUTDOWN 0xFFFFFFFFFFFFFFFFull
__global__ void persistent_cell_agent_kernel(QuiltArena arena,
                                             volatile uint64_t* doorbell);

// ------------------------------------------------------------
// Host helpers — implemented in quilt_cells.cu
// ------------------------------------------------------------

#ifdef __cplusplus
extern "C" {
#endif

cudaError_t quilt_arena_create(QuiltArena* arena, uint32_t count);
cudaError_t quilt_arena_destroy(QuiltArena* arena);

// BIND (host path). Idempotent.
cudaError_t quilt_bind(QuiltArena* arena, uint32_t cell_id, float value,
                       uint64_t tick);

// VIEW: pure device->host readback of telemetry. No device write occurs
// anywhere in this path — VIEW_purity is structural.
cudaError_t quilt_view(const QuiltArena* arena, float* h_value,
                       uint32_t* h_witness, uint64_t* h_lamport,
                       uint8_t* h_opcode);

// FORGET (host path): zero state on device, plant QOP_FORGET.
cudaError_t quilt_forget_cell(QuiltArena* arena, uint32_t cell_id);

#ifdef __cplusplus
}
#endif

#endif // QUILT_CELLS_CUH
