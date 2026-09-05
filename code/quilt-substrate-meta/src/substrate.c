/*
 * substrate.c — The runtime.
 *
 * The runtime ties together the cell layer, the message layer,
 * and the evolution layer. It exposes a small, simple API to
 * the cowboy: init, shutdown, tick, send, bind, link, view.
 *
 * This file is Layer 1 (runtime layer). It depends on all the
 * other layers.
 *
 * The runtime is intentionally tiny. Most of the work is done
 * by the other layers. The runtime is the conductor, not the
 * orchestra.
 */

#include "substrate.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* The cowboy's maxim. Kept as a string for the substrate_maxim()
 * function. The cowboy can print it at startup. */
static const char COWBOY_MAXIM[] =
    "The unit of foundation is the cell, not the opcode. "
    "The 5 opcodes are the 5 messages a cell can receive. "
    "The messages are closed under composition. "
    "Composition is evolution. "
    "Evolution is the cowboy.";

const char *substrate_maxim(void) { return COWBOY_MAXIM; }

/* The warning flag. Defaults to off. */
static int debug_warnings_on = 0;

quilt_err_t substrate_init(uint32_t capacity) {
    quilt_err_t err = cell_init(capacity);
    if (err) return err;
    err = evolution_init();
    if (err) {
        cell_shutdown();
        return err;
    }
    return QUILT_OK;
}

void substrate_shutdown(void) {
    evolution_shutdown();
    cell_shutdown();
    debug_warnings_on = 0;
}

quilt_err_t substrate_tick(void) {
    /* Ticking: for the simple implementation, ticking is a
     * no-op. The cowboy is responsible for sending TICK
     * messages to specific cells. The runtime simply ensures
     * the evolution layer is up to date. */
    return evolution_tick();
}

quilt_err_t substrate_send(const char *name, const quilt_message_t *msg) {
    if (!name || !msg) return QUILT_ERR_INVALID_ARG;
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) return QUILT_ERR_NOT_FOUND;
    quilt_message_t m = *msg;
    m.a = ref;
    return opcodes_apply(&m);
}

/*
 * substrate_bind — Set a cell's value, creating the cell if it
 * doesn't exist. The cell is auto-registered with no identity
 * (a pure value cell). This is the "key-value store" mode:
 * the cowboy doesn't need to register cells before binding.
 *
 * The lower-level `opcodes_apply(msg_bind(...))` requires a
 * pre-registered cell. Use `substrate_bind` when you want
 * the substrate to act like a key-value store; use
 * `opcodes_apply` directly when you want full control.
 */
quilt_err_t substrate_bind(const char *name, const quilt_value_t *value) {
    if (!name) return QUILT_ERR_INVALID_ARG;
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) {
        /* Auto-register the cell. */
        ref = cell_register(name, NULL, NULL);
        if (ref == QUILT_CELL_NONE) return QUILT_ERR_FULL;
    }
    quilt_message_t m = msg_bind(ref, value);
    return opcodes_apply(&m);
}

/*
 * substrate_link — Record a relation between two cells,
 * auto-registering the cells if they don't exist. Same
 * key-value-store convenience as substrate_bind.
 */
quilt_err_t substrate_link(const char *a_name, const char *b_name,
                            const char *relation) {
    if (!a_name || !b_name || !relation) return QUILT_ERR_INVALID_ARG;
    quilt_cell_ref_t a = cell_lookup(a_name);
    if (a == QUILT_CELL_NONE) {
        a = cell_register(a_name, NULL, NULL);
        if (a == QUILT_CELL_NONE) return QUILT_ERR_FULL;
    }
    quilt_cell_ref_t b = cell_lookup(b_name);
    if (b == QUILT_CELL_NONE) {
        b = cell_register(b_name, NULL, NULL);
        if (b == QUILT_CELL_NONE) return QUILT_ERR_FULL;
    }
    quilt_message_t m = msg_link(a, b, relation);
    return opcodes_apply(&m);
}

const quilt_value_t *substrate_view(const char *name) {
    if (!name) return NULL;
    return cell_value(cell_lookup(name));
}

void substrate_debug_dump(void) {
    /* A simple dump that uses the internal accessors. The
     * cowboy can redirect stdout to a file for offline
     * inspection. */
    printf("=== Substrate dump (%u cells) ===\n", cell_count());
    uint32_t cap = cell_capacity_internal();
    for (uint32_t i = 0; i < cap; i++) {
        const char *n = cell_name_internal(i);
        if (!n) continue;
        const quilt_value_t *v = cell_value_internal(i);
        printf("  [%u] %s (len=%u)", i, n, v ? v->len : 0);
        if (v && v->len > 0) {
            printf(" = ");
            for (uint32_t j = 0; j < v->len && j < 32; j++) {
                unsigned char c = v->data[j];
                if (c >= 32 && c < 127) printf("%c", c);
                else printf("\\x%02x", c);
            }
            if (v->len > 32) printf("...");
        }
        printf("\n");
    }
    printf("=== End dump ===\n");
}

void substrate_debug_journal(uint32_t n) {
    uint32_t total = opcodes_journal_size();
    if (n == 0 || n > total) n = total;
    printf("=== Journal (last %u of %u) ===\n", n, total);
    for (uint32_t i = total - n; i < total; i++) {
        quilt_message_t m = opcodes_journal_get(i);
        printf("  [%u] %s", i, quilt_msg_type_name[m.op]);
        if (m.op == QUILT_MSG_BIND || m.op == QUILT_MSG_EFFECT ||
            m.op == QUILT_MSG_VIEW) {
            printf(" a=?");
        }
        if (m.op == QUILT_MSG_LINK) {
            printf(" a=? b=?");
        }
        printf("\n");
    }
    printf("=== End journal ===\n");
}

void substrate_debug_warnings(int on) {
    debug_warnings_on = on;
}
