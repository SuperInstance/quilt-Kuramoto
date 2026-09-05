// ============================================================
// quilt_cells.cu — the quilt substrate on CUDA (implementation)
//
// BIND / EFFECT / VIEW / TICK / FORGET kernels + the W13 witness
// layer (union + warp vote) + the CRDT merge surface + the
// persistent cell agent sketch.
//
// Wired to the cudaclaw organs by pattern and by reference:
//   - executor.cu  : persistent kernel, lane-0 poll, shfl broadcast
//   - crdt_engine.cuh : (timestamp, node_id) LWW ordering
//   - smartcrdt.cuh: atomicCAS cell updates, coalesced SoA layout
//
// STATUS: written, UNCOMPILED — no nvcc in this WSL. First roadmap
// item: `make ptx` (nvcc -c --ptx) as a syntax/ISA check.
// ============================================================

#include "quilt_cells.cuh"

// ============================================================
// BIND
// ============================================================

__global__ void bind_kernel(QuiltArena arena, uint32_t cell_id, float value,
                            uint64_t tick) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        arena.value[cell_id]    = value;
        arena.witness[cell_id]  = QUILT_W_BOUND | quilt_trits_of(value);
        arena.lamport[cell_id]  = tick;
        arena.node_id[cell_id]  = 0u;   // host is node 0
        arena.opcode[cell_id]   = QOP_BIND;
    }
}

// ============================================================
// EFFECT
// ============================================================

__global__ void cell_effect_kernel(QuiltArena arena, uint32_t cell_id,
                                   uint32_t op, float p0, float p1,
                                   uint64_t tick) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        float v = quilt_apply_body(op, arena.value[cell_id], p0, p1);
        arena.value[cell_id]   = v;
        // W_DIRTY ORs in; trit witnesses refresh. Idempotent under
        // replay to the same value — L1 holds at the witness layer.
        arena.witness[cell_id] |= QUILT_W_DIRTY | quilt_trits_of(v);
        // TICK_monotonicity: the clock never runs backwards.
        if (arena.lamport[cell_id] < tick) arena.lamport[cell_id] = tick;
        arena.opcode[cell_id]  = QOP_EFFECT;
    }
}

// ============================================================
// The W13 witness layer
// ============================================================

// Union of every witness word in the arena. OR is idempotent,
// commutative, associative — a semilattice in one instruction.
// This is the L1 law at fleet scale.
__global__ void witness_union_kernel(const QuiltArena arena,
                                     uint32_t* out_union) {
    uint32_t local = 0u;
    uint32_t i     = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t stride = gridDim.x * blockDim.x;
    for (uint32_t c = i; c < arena.count; c += stride) {
        local |= arena.witness[c];
    }
    // Warp-level OR reduce (shuffle tree — 5 shuffles per warp).
    for (int off = QUILT_WARP_SIZE / 2; off > 0; off >>= 1) {
        local |= __shfl_down_sync(QUILT_FULL_MASK, local, off);
    }
    if ((threadIdx.x & (QUILT_WARP_SIZE - 1u)) == 0u) {
        atomicOr(out_union, local);
    }
}

// The consensus cell: 32 lanes = one warp = one cell.
// Lane i votes bit i of the witness word. The ballot IS the witness
// word re-derived from 32 independent observations; consensus is
// popc/32. Fringes: 0.9989 (fleet — unreachable in one warp, by
// construction) and 0.9004 (29/32 = 0.90625 clears it).
__global__ void warp_vote_kernel(const QuiltArena arena, WarpVote* votes) {
    uint32_t lane   = threadIdx.x & (QUILT_WARP_SIZE - 1u);
    uint32_t gwarp  = (blockIdx.x * blockDim.x + threadIdx.x) / QUILT_WARP_SIZE;
    if (gwarp >= arena.count) return;

    uint32_t w = arena.witness[gwarp];      // same word every lane sees
    bool pred = ((w >> lane) & 1u) != 0u;   // lane i observes bit i

    uint32_t ballot = __ballot_sync(QUILT_FULL_MASK, pred);
    if (lane == 0u) {
        float consensus = (float)__popc(ballot) / (float)QUILT_WARP_SIZE;
        uint8_t fringe = FRINGE_SPLIT;
        if      (consensus >= QUILT_FRINGE_HIGH) fringe = FRINGE_HIGH;
        else if (consensus >= QUILT_FRINGE_LOW)  fringe = FRINGE_LOW;
        votes[gwarp].ballot    = ballot;
        votes[gwarp].consensus = consensus;
        votes[gwarp].fringe    = fringe;
    }
}

// ============================================================
// TICK — the device-resident wavefront (Kahn-style)
// ============================================================

// All cross-block reads/writes below go through atomics: L1 is not
// coherent across SMs and a stale line must never decide a fire.
// Atomic read = atomicAdd(ptr, 0).
__global__ void tick_wavefront_kernel(QuiltArena arena, QuiltEdge* edges,
                                      uint32_t edge_count,
                                      uint32_t* indegree,
                                      uint32_t* completed,
                                      uint32_t* edge_released,
                                      uint64_t tick,
                                      uint32_t* done_count) {
    uint32_t i      = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t stride = gridDim.x * blockDim.x;

    // ---- FIRE phase: ready cells apply their body ----------------
    for (uint32_t c = i; c < arena.count; c += stride) {
        uint32_t done = atomicAdd(&completed[c], 0u);
        uint32_t deg  = atomicAdd(&indegree[c], 0u);
        if (done == 0u && deg == 0u) {
            // Claim the fire with a CAS so exactly one thread fires it.
            uint32_t prev = atomicCAS(&completed[c], 0u, 1u);
            if (prev == 0u) {
                float v = atomicAdd(&arena.value[c], 0.0f);   // atomic read
                v = quilt_apply_body(arena.body_op[c], v,
                                     arena.body_p0[c], arena.body_p1[c]);
                arena.value[c] = v;                            // sole owner
                uint32_t trits = quilt_trits_of(v);
                atomicOr(&arena.witness[c], QUILT_W_DIRTY | trits);
                atomicMax((unsigned long long*)&arena.lamport[c],
                          (unsigned long long)tick);
                arena.opcode[c] = QOP_EFFECT;
                atomicAdd(done_count, 1u);

                // ---- RELEASE phase for this cell's out-edges ------
                // (owner releases: no second thread re-checks these
                //  edges, so edge_released stays exact)
                for (uint32_t e = 0; e < edge_count; ++e) {
                    uint32_t s = edges[e].src;
                    uint32_t d = edges[e].dst;
                    if (s == c && atomicExch(&edge_released[e], 1u) == 0u) {
                        // LINK carries the value forward...
                        atomicAdd(&arena.value[d], v);
                        // ...and unblocks the successor.
                        atomicSub(&indegree[d], 1u);
                    }
                }
            }
        }
    }
}

// ============================================================
// CRDT merge — simplified LWW surface
// ============================================================

// Ordering: (lamport, node_id), exactly cudaclaw's CRDTCell.
// CAVEAT (honest): this is a simplified surface. atomicMax picks the
// Lamport winner; the winner writes the value. A pathological
// interleave (two merges, the older winner slow to write its value
// while a newer winner arrives) can leave the older value last. The
// rigorous engine — warp-aggregated merge, bitonic sort by cell_idx,
// full RGA — is cudaclaw's crdt_engine.cuh (~3.4k lines), referenced,
// not duplicated. This kernel is the substrate-side illustration of
// the discipline; keep one merge per cell per batch and it is exact.
__global__ void crdt_merge_kernel(QuiltArena arena, const MergeOp* ops,
                                  uint32_t op_count) {
    uint32_t i      = blockIdx.x * blockDim.x + threadIdx.x;
    uint32_t stride = gridDim.x * blockDim.x;
    for (uint32_t k = i; k < op_count; k += stride) {
        uint32_t c      = ops[k].cell_id;
        uint64_t mine   = ops[k].lamport;
        uint32_t mynode = ops[k].node_id;

        unsigned long long old =
            atomicMax((unsigned long long*)&arena.lamport[c],
                      (unsigned long long)mine);

        bool i_won;
        if ((uint64_t)old < mine) {
            i_won = true;                          // strictly newer
        } else if ((uint64_t)old > mine) {
            i_won = false;                         // strictly older
        } else {
            // Tie: node_id decides (CRDTCell discipline). CAS claims it.
            uint32_t cur = atomicAdd(&arena.node_id[c], 0u);
            i_won = (mynode > cur) &&
                    (atomicCAS(&arena.node_id[c], cur, mynode) == cur);
        }

        if (i_won) {
            arena.value[c] = ops[k].value;         // LWW winner writes state
            if ((uint64_t)old < mine) {
                // node_id travels with the newer clock; on ties the CAS
                // already moved it.
                atomicExch(&arena.node_id[c], mynode);
            }
        }
        // The witness of a losing merge still counts: observation is
        // never discarded. Union is unconditional.
        atomicOr(&arena.witness[c], ops[k].witness | QUILT_W_DIRTY);
        arena.opcode[c] = QOP_EFFECT;
    }
}

// ============================================================
// FORGET
// ============================================================

__global__ void forget_kernel(QuiltArena arena, uint32_t cell_id) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        arena.value[cell_id]   = 0.0f;
        arena.witness[cell_id] = 0u;      // the marks retire with the cell
        arena.lamport[cell_id] = 0ull;    // (history lives in the journal)
        arena.opcode[cell_id]  = QOP_FORGET;
    }
}

// ============================================================
// The persistent cell agent — cudaclaw executor.cu pattern (SKETCH)
// ============================================================

// One warp, launched once <<<1, 32>>>. Lane 0 polls a doorbell in
// unified memory behind __threadfence_system(); ops broadcast to the
// warp via __shfl_sync; lanes execute against the arena. The kernel
// that stays resident, receives ops, and ticks in place IS the cell
// agent — no launch overhead per tick. This sketch uses a single u64
// doorbell; the production ABI is cudaclaw's SPSC queue
// (kernels/shared_types.h) with volatile writes from the host, which
// is where this pattern came from. NOT launched by host_demo tonight.
__global__ void persistent_cell_agent_kernel(QuiltArena arena,
                                             volatile uint64_t* doorbell) {
    uint32_t lane = threadIdx.x & (QUILT_WARP_SIZE - 1u);
    if (arena.count == 0u) return;   // nothing to tend
    while (true) {
        uint64_t op = 0ull;
        if (lane == 0u) {
            // Lane 0 is the queue manager (executor.cu discipline).
            op = *doorbell;                 // volatile load
            __threadfence_system();         // then make it stick
        }
        // Broadcast the op to all 32 lanes — one instruction.
        op = __shfl_sync(QUILT_FULL_MASK, op, 0);

        if (op == QCA_OP_SHUTDOWN) return;

        if (op != QCA_OP_NOP) {
            // All 32 lanes act on their slice of the arena: lane i
            // touches cell i % count. Real dispatch would decode a
            // full WarpCommand; this is the shape, not the ABI.
            uint32_t c = lane % arena.count;
            float v = quilt_apply_body(arena.body_op[c],
                                       atomicAdd(&arena.value[c], 0.0f),
                                       arena.body_p0[c], arena.body_p1[c]);
            arena.value[c] = v;
            atomicOr(&arena.witness[c], QUILT_W_DIRTY | quilt_trits_of(v));
        }

        if (lane == 0u) *doorbell = QCA_OP_NOP;   // consume

        __nanosleep(100);   // executor.cu's thermal-respect backoff
    }
}

// ============================================================
// Host helpers
// ============================================================

extern "C" {

cudaError_t quilt_arena_create(QuiltArena* arena, uint32_t count) {
    arena->count = count;
    cudaError_t e;
    e = cudaMalloc((void**)&arena->value,   (size_t)count * sizeof(float));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->witness, (size_t)count * sizeof(uint32_t));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->lamport, (size_t)count * sizeof(uint64_t));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->node_id, (size_t)count * sizeof(uint32_t));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->opcode,  (size_t)count * sizeof(uint8_t));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->body_op, (size_t)count * sizeof(uint32_t));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->body_p0, (size_t)count * sizeof(float));
    if (e != cudaSuccess) return e;
    e = cudaMalloc((void**)&arena->body_p1, (size_t)count * sizeof(float));
    if (e != cudaSuccess) return e;

    cudaMemset(arena->value,   0, (size_t)count * sizeof(float));
    cudaMemset(arena->witness, 0, (size_t)count * sizeof(uint32_t));
    cudaMemset(arena->lamport, 0, (size_t)count * sizeof(uint64_t));
    cudaMemset(arena->node_id, 0, (size_t)count * sizeof(uint32_t));
    cudaMemset(arena->opcode,  0, (size_t)count * sizeof(uint8_t));
    cudaMemset(arena->body_op, 0, (size_t)count * sizeof(uint32_t));
    cudaMemset(arena->body_p0, 0, (size_t)count * sizeof(float));
    cudaMemset(arena->body_p1, 0, (size_t)count * sizeof(float));
    return cudaSuccess;
}

cudaError_t quilt_arena_destroy(QuiltArena* arena) {
    cudaFree(arena->value);
    cudaFree(arena->witness);
    cudaFree(arena->lamport);
    cudaFree(arena->node_id);
    cudaFree(arena->opcode);
    cudaFree(arena->body_op);
    cudaFree(arena->body_p0);
    cudaFree(arena->body_p1);
    arena->count = 0u;
    return cudaSuccess;
}

cudaError_t quilt_bind(QuiltArena* arena, uint32_t cell_id, float value,
                       uint64_t tick) {
    bind_kernel<<<1, 1>>>(*arena, cell_id, value, tick);
    return cudaGetLastError();
}

// VIEW_purity is structural: this path contains no device write.
cudaError_t quilt_view(const QuiltArena* arena, float* h_value,
                       uint32_t* h_witness, uint64_t* h_lamport,
                       uint8_t* h_opcode) {
    size_t n = (size_t)arena->count;
    cudaError_t e;
    e = cudaMemcpy(h_value,   arena->value,   n * sizeof(float),    cudaMemcpyDeviceToHost);
    if (e != cudaSuccess) return e;
    e = cudaMemcpy(h_witness, arena->witness, n * sizeof(uint32_t), cudaMemcpyDeviceToHost);
    if (e != cudaSuccess) return e;
    e = cudaMemcpy(h_lamport, arena->lamport, n * sizeof(uint64_t), cudaMemcpyDeviceToHost);
    if (e != cudaSuccess) return e;
    e = cudaMemcpy(h_opcode,  arena->opcode,  n * sizeof(uint8_t),  cudaMemcpyDeviceToHost);
    return e;
}

cudaError_t quilt_forget_cell(QuiltArena* arena, uint32_t cell_id) {
    forget_kernel<<<1, 1>>>(*arena, cell_id);
    return cudaGetLastError();
}

} // extern "C"
