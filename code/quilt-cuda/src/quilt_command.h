// ============================================================
// quilt_command.h — the quilt opcode stream riding cudaclaw's
// lock-free SPSC queue, as an overlay (nothing existing modified)
//
// The organ: kernels/shared_types.h in SuperInstance/cudaclaw —
// CommandQueue with volatile head/tail (offsets 48992/48996),
// producer writes head, consumer (persistent kernel, lane 0) polls
// behind __threadfence_system(), acknowledges via tail. Volatile
// ops ~2-5ns; no locks, no atomic RMW on the hot path.
//
// This header defines how a quilt op is packed into ONE u64 word —
// usable as the persistent agent's doorbell (quilt_cells.cuh) or as
// a namespace on the queue's auxiliary word. The existing CMD_*
// enum in shared_types.h is UNTOUCHED.
//
// Latency targets (from src/volatile_dispatcher.rs:14-15, the organ):
//   submit 50-100ns | round-trip 1-5us | >10M ops/s theoretical
//
// STATUS: written, UNCOMPILED (no nvcc in this WSL). Host+device
// safe: pure integer packing, no CUDA API calls.
// ============================================================

#ifndef QUILT_COMMAND_H
#define QUILT_COMMAND_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Quilt opcodes on the wire (namespace-extended; QOP_* in
// quilt_cells.cuh remain the arena-side values).
#define QCMD_BIND    0x51u   // label a value at a cell
#define QCMD_EFFECT  0x52u   // mutate through the body op
#define QCMD_VIEW    0x53u   // request telemetry readback
#define QCMD_TICK    0x54u   // drain one wavefront level
#define QCMD_FORGET  0x55u   // retire a cell
#define QCMD_VOTE    0x56u   // run the consensus cell (warp vote)
#define QCMD_MERGE   0x57u   // CRDT merge (aux carries the op index)
#define QCMD_NOP     0x50u
#define QCMD_SHUTDOWN 0x5Fu

// QuiltCommand word layout (u64):
//   [63..56] opcode   QCMD_*
//   [55..32] cell_id  24 bits — 16,777,216 cells (cudaclaw's 1M-cell
//                     target fits with room; a GPU's worth of cells)
//   [31..0]  aux      param bits: float bits for BIND/EFFECT, tick
//                     low bits for TICK, op index for MERGE
//
// Pack/unpack are plain integer ops — usable from Rust (the volatile
// producer), C, and CUDA device code alike.

static inline uint64_t quilt_pack(uint8_t opcode, uint32_t cell_id,
                                  uint32_t aux) {
    return ((uint64_t)(opcode & 0xFFu) << 56) |
           ((uint64_t)(cell_id & 0x00FFFFFFu) << 32) |
           (uint64_t)aux;
}

static inline uint8_t  quilt_cmd_opcode(uint64_t w)  { return (uint8_t)(w >> 56); }
static inline uint32_t quilt_cmd_cell(uint64_t w)    { return (uint32_t)((w >> 32) & 0x00FFFFFFu); }
static inline uint32_t quilt_cmd_aux(uint64_t w)     { return (uint32_t)(w & 0xFFFFFFFFu); }

// aux as float bits (BIND/EFFECT payloads) — byte-copy bit-cast,
// host+device safe.
static inline uint32_t quilt_float_bits(float v) {
    uint32_t u;
    const unsigned char* p = (const unsigned char*)&v;
    unsigned char* q = (unsigned char*)&u;
    q[0] = p[0]; q[1] = p[1]; q[2] = p[2]; q[3] = p[3];
    return u;
}

static inline float quilt_bits_float(uint32_t u) {
    float v;
    const unsigned char* p = (const unsigned char*)&u;
    unsigned char* q = (unsigned char*)&v;
    q[0] = p[0]; q[1] = p[1]; q[2] = p[2]; q[3] = p[3];
    return v;
}

#ifdef __cplusplus
}
#endif

#endif // QUILT_COMMAND_H
