/*
 * evolution.c — The self-evolving machinery.
 *
 * The substrate calls all registered evolution functions at
 * boot. Each function returns a list of candidate messages.
 * Each candidate is checked against the algebraic laws by
 * prove_composition(); candidates that pass are added to the
 * message set.
 *
 * The substrate supports up to 8 evolution functions. The
 * first 3 are reserved for the built-in derivations (CALL,
 * GROUP, TICK_ALL); the cowboy can register 5 more.
 *
 * This file is Layer 4 (evolution layer). It depends on
 * Layer 3 (opcodes.h, opcodes.c) and Layer 2 (cell.h, cell.c).
 */

#include "evolution.h"

#include <stdlib.h>
#include <string.h>

/* The maximum number of evolution functions. */
#define QUILT_EVOLUTION_MAX 8

/* The maximum number of derived messages. */
#define QUILT_DERIVED_MAX 64

/* The evolution functions. */
static struct {
    evolution_fn fn;
    void        *user;
} evolution_fns[QUILT_EVOLUTION_MAX];

static uint32_t evolution_fn_count = 0;

/* The derived messages. The substrate starts with the 5
 * primitives and grows. The 5 primitives are at indices 0..4;
 * derived messages are at indices 5..5+count. */
static quilt_message_t derived_messages[QUILT_DERIVED_MAX];
static uint32_t       derived_count = 0;

quilt_err_t evolution_init(void) {
    for (uint32_t i = 0; i < QUILT_EVOLUTION_MAX; i++) {
        evolution_fns[i].fn = NULL;
        evolution_fns[i].user = NULL;
    }
    evolution_fn_count = 0;
    derived_count = 0;
    /* The first 3 slots are reserved for the built-in
     * derivations. We register them here. */
    evolution_fns[0].fn = derive_builtin_call;
    evolution_fns[1].fn = derive_builtin_group;
    evolution_fns[2].fn = derive_builtin_tick_all;
    evolution_fn_count = 3;
    /* Run them. */
    return evolution_tick();
}

void evolution_shutdown(void) {
    for (uint32_t i = 0; i < QUILT_EVOLUTION_MAX; i++) {
        evolution_fns[i].fn = NULL;
        evolution_fns[i].user = NULL;
    }
    evolution_fn_count = 0;
    derived_count = 0;
}

quilt_err_t evolution_register(evolution_fn fn, void *user) {
    if (!fn) return QUILT_ERR_INVALID_ARG;
    if (evolution_fn_count >= QUILT_EVOLUTION_MAX) return QUILT_ERR_FULL;
    evolution_fns[evolution_fn_count].fn = fn;
    evolution_fns[evolution_fn_count].user = user;
    evolution_fn_count++;
    return evolution_tick();
}

uint32_t evolution_count(void) {
    return evolution_fn_count;
}

uint32_t evolution_derived_count(void) {
    return derived_count;
}

void evolution_reset(void) {
    derived_count = 0;
}

quilt_err_t evolution_tick(void) {
    /* Reset the derived messages. The cowboy is responsible for
     * not double-registering messages; the prover will catch
     * duplicates anyway. */
    derived_count = 0;
    for (uint32_t i = 0; i < evolution_fn_count; i++) {
        if (!evolution_fns[i].fn) continue;
        quilt_message_t candidates[16];
        uint32_t n = evolution_fns[i].fn(evolution_fns[i].user,
                                           candidates, 16);
        for (uint32_t j = 0; j < n; j++) {
            /* The built-in derivations return single messages;
             * user derivations return compositions (in the
             * first message's arg). We handle both cases. */
            if (j == 0 && candidates[j].op == QUILT_MSG_BIND) {
                /* A user-supplied composition. */
                uint32_t n_msgs = candidates[j].arg.len / sizeof(quilt_message_t);
                if (n_msgs == 0) continue;
                quilt_message_t *msgs = (quilt_message_t *)candidates[j].arg.data;
                if (prove_composition(msgs, n_msgs) != QUILT_OK) {
                    continue;
                }
                if (derived_count + n_msgs > QUILT_DERIVED_MAX) return QUILT_ERR_FULL;
                for (uint32_t k = 0; k < n_msgs; k++) {
                    derived_messages[5 + derived_count] = msgs[k];
                    derived_count++;
                }
            } else {
                /* A single built-in message. Accept it. */
                if (prove_composition(&candidates[j], 1) != QUILT_OK) {
                    continue;
                }
                if (derived_count >= QUILT_DERIVED_MAX) return QUILT_ERR_FULL;
                derived_messages[5 + derived_count] = candidates[j];
                derived_count++;
            }
        }
    }
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* Built-in derivations                                               */
/* ------------------------------------------------------------------ */

/*
 * derive_builtin_call — The CALL derivation.
 *
 * CALL(a, b) is a 2-message composition:
 *   1. VIEW(b)            — read arguments from b
 *   2. EFFECT(a)          — run a's effect with the arguments
 *
 * This composition is a valid CALL: it reads from b and applies
 * the result to a. The composition satisfies all 5 laws.
 */
uint32_t derive_builtin_call(void *user, quilt_message_t *out,
                              uint32_t out_max) {
    (void)user;
    if (out_max < 1) return 0;
    /* We use a placeholder cell ref; the cowboy must set the
     * actual refs before applying. The derivation returns a
     * "spec" message; the substrate fills in the refs. */
    out[0] = msg_bind(QUILT_CELL_NONE, NULL);
    out[0].arg.data[0] = QUILT_MSG_VIEW;
    out[0].arg.data[1] = QUILT_MSG_EFFECT;
    out[0].arg.len = 2;
    return 1;
}

/*
 * derive_builtin_group — The GROUP derivation.
 *
 * GROUP(a, b) is a 3-message composition:
 *   1. BIND(a, value_of(b))   — set a to b's value
 *   2. LINK(a, b, "grouped")  — record the group relation
 *   3. EFFECT(a)              — run a's effect
 */
uint32_t derive_builtin_group(void *user, quilt_message_t *out,
                                uint32_t out_max) {
    (void)user;
    if (out_max < 1) return 0;
    out[0] = msg_bind(QUILT_CELL_NONE, NULL);
    out[0].arg.data[0] = QUILT_MSG_BIND;
    out[0].arg.data[1] = QUILT_MSG_LINK;
    out[0].arg.data[2] = QUILT_MSG_EFFECT;
    out[0].arg.len = 3;
    return 1;
}

/*
 * derive_builtin_tick_all — The TICK_ALL derivation.
 *
 * TICK_ALL() ticks all cells. The composition is:
 *   For each cell c: TICK(c, 1.0)
 *
 * The substrate implements this by iterating all cells at
 * apply time. The derivation returns a single "marker"
 * message; the runtime expands it.
 */
uint32_t derive_builtin_tick_all(void *user, quilt_message_t *out,
                                  uint32_t out_max) {
    (void)user;
    if (out_max < 1) return 0;
    out[0] = msg_bind(QUILT_CELL_NONE, NULL);
    out[0].arg.data[0] = QUILT_MSG_TICK;
    out[0].arg.len = 1;
    return 1;
}

quilt_message_t derive_call(quilt_cell_ref_t a, quilt_cell_ref_t b) {
    quilt_message_t m = msg_bind(QUILT_CELL_NONE, NULL);
    m.a = a;
    m.b = b;
    m.arg.data[0] = QUILT_MSG_VIEW;
    m.arg.data[1] = QUILT_MSG_EFFECT;
    m.arg.len = 2;
    return m;
}

quilt_message_t derive_group(quilt_cell_ref_t a, quilt_cell_ref_t b) {
    quilt_message_t m = msg_bind(QUILT_CELL_NONE, NULL);
    m.a = a;
    m.b = b;
    m.arg.data[0] = QUILT_MSG_BIND;
    m.arg.data[1] = QUILT_MSG_LINK;
    m.arg.data[2] = QUILT_MSG_EFFECT;
    m.arg.len = 3;
    return m;
}

quilt_err_t derive_tick_all(void) {
    /* Iterate all cells and send a TICK(1.0) to each.
     * Skip hidden cells (those whose names start with "_"). */
    extern uint32_t cell_capacity_internal(void);
    extern const char *cell_name_internal(uint32_t);
    uint32_t cap = cell_capacity_internal();
    for (uint32_t i = 0; i < cap; i++) {
        const char *n = cell_name_internal(i);
        if (!n) continue;
        if (n[0] == '_') continue;  /* Skip hidden cells. */
        quilt_message_t m = msg_tick(i, 1.0);
        quilt_err_t err = opcodes_apply(&m);
        if (err) return err;
    }
    return QUILT_OK;
}
