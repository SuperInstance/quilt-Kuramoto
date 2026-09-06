/*
 * derive.h — The opcode synthesizer.
 *
 * The synthesizer takes a spec (a finite automaton) and
 * produces a composition of the 5 primitives that implements
 * the spec. The cowboy uses the synthesizer to add new
 * opcodes to the substrate at runtime.
 *
 * See src/derive.c for the implementation and
 * docs/MATHEMATICS.md §5 for the formal treatment.
 */

#ifndef QUILT_DERIVE_H
#define QUILT_DERIVE_H

#include "cell.h"
#include "opcodes.h"

uint32_t derive_from_spec(const uint8_t *spec, uint32_t spec_len,
                            quilt_cell_ref_t target,
                            quilt_message_t *out, uint32_t out_max);

quilt_err_t derive_register(const char *name, const uint8_t *spec,
                              uint32_t spec_len);

#endif /* QUILT_DERIVE_H */
