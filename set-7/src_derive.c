/*
 * derive.c — The opcode synthesizer.
 *
 * Given a spec for a desired message, derive a composition
 * of the 5 primitives that implements it. The spec is a
 * finite automaton; the derivation translates each state
 * transition to a message.
 *
 * This is the substrate's "auto-programmer." The cowboy can
 * describe a behavior in a small DSL (the spec) and the
 * substrate will compile it to a composition.
 *
 * The spec format is a sequence of bytes; each byte is a
 * message type. The composition is the sequence of those
 * messages applied to a single cell.
 *
 * For example, the spec [VIEW, EFFECT, TICK] compiles to the
 * composition "view the cell, then run its effect, then tick
 * it." This is a valid 3-message composition.
 *
 * The cowboy can also supply a "name" for the spec. The
 * derived message is then registered under that name in the
 * evolution layer.
 */

#include "derive.h"
#include "opcodes.h"
#include "evolution.h"

#include <stdlib.h>
#include <string.h>

/*
 * derive_from_spec — Derive a composition from a spec.
 *
 * @param spec      The spec (a sequence of message-type bytes).
 * @param spec_len  The length of the spec.
 * @param target    The cell the composition will be applied to.
 * @param out       The output array of messages.
 * @param out_max   The maximum number of messages to write.
 * @return          The number of messages written, or 0 on
 *                  error.
 */
uint32_t derive_from_spec(const uint8_t *spec, uint32_t spec_len,
                            quilt_cell_ref_t target,
                            quilt_message_t *out, uint32_t out_max) {
    if (!spec || !out) return 0;
    if (spec_len > out_max) return 0;
    for (uint32_t i = 0; i < spec_len; i++) {
        switch (spec[i]) {
            case QUILT_MSG_BIND:   out[i] = msg_bind(target, NULL); break;
            case QUILT_MSG_LINK:   out[i] = msg_link(target, target, "x"); break;
            case QUILT_MSG_EFFECT: out[i] = msg_effect(target); break;
            case QUILT_MSG_VIEW:   out[i] = msg_view(target, NULL); break;
            case QUILT_MSG_TICK:   out[i] = msg_tick(target, 0.5); break;
            default: return 0;  /* Invalid spec byte. */
        }
    }
    return spec_len;
}

/*
 * derive_register — Register a derived message by name.
 *
 * Derives a composition from the spec and registers it in
 * the evolution layer. The composition is checked against the
 * algebraic laws; if it fails, the registration is rejected.
 *
 * @param name      The name of the new message.
 * @param spec      The spec.
 * @param spec_len  The length of the spec.
 * @return          QUILT_OK on success, QUILT_ERR_LAW_VIOLATION
 *                  if the composition is invalid.
 */
quilt_err_t derive_register(const char *name, const uint8_t *spec,
                              uint32_t spec_len) {
    if (!name || !spec) return QUILT_ERR_INVALID_ARG;
    /* Find or create the cell. */
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) {
        ref = cell_register(name, NULL, NULL);
        if (ref == QUILT_CELL_NONE) return QUILT_ERR_FULL;
    }
    quilt_message_t composition[64];
    if (spec_len > 64) return QUILT_ERR_INVALID_ARG;
    uint32_t n = derive_from_spec(spec, spec_len, ref, composition, 64);
    if (n != spec_len) return QUILT_ERR_INVALID_ARG;
    return prove_composition(composition, n);
}
