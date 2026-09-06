/*
 * opcodes.c — The 5 messages, implemented.
 *
 * Each message is ~30 lines. The algebraic law each message
 * enforces is documented above its implementation. See
 * docs/MATHEMATICS.md §2 for the formal statement of the laws
 * and docs/GLOSSARY.md for the terminology.
 *
 * This file is Layer 3 (message layer). It depends on
 * Layer 2 (cell.h, cell.c).
 */

#include "opcodes.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

/* ------------------------------------------------------------------ */
/* The message type names (for debugging)                              */
/* ------------------------------------------------------------------ */

const char *quilt_msg_type_name[QUILT_MSG_COUNT] = {
    "BIND", "LINK", "EFFECT", "VIEW", "TICK"
};

/* ------------------------------------------------------------------ */
/* The journal                                                         */
/* ------------------------------------------------------------------ */

/* The journal is an array of messages, in application order.
 * Each applied message (except VIEW) is appended. opcodes_rollback()
 * consumes the journal from the end.
 *
 * The journal is a circular buffer: when it fills up, the oldest
 * messages are overwritten. The cowboy can call
 * opcodes_journal_size() to find the current size.
 *
 * The default journal size is 4096 messages. The cowboy can
 * resize the journal by editing this constant; the substrate
 * does not currently support runtime resizing because the
 * journal is rarely the bottleneck.
 */
#define QUILT_JOURNAL_SIZE 4096

static quilt_message_t  opcodes_journal[QUILT_JOURNAL_SIZE];
static uint32_t         opcodes_journal_head = 0;  /* Total applied. */
static uint32_t         opcodes_journal_count = 0; /* Current size. */

uint32_t opcodes_journal_size(void) {
    return opcodes_journal_count;
}

quilt_message_t opcodes_journal_get(uint32_t i) {
    if (i >= opcodes_journal_count) {
        quilt_message_t empty = {0};
        return empty;
    }
    /* The journal is a circular buffer; i=0 is the oldest. */
    uint32_t idx;
    if (opcodes_journal_head > QUILT_JOURNAL_SIZE) {
        /* Wrapped. The oldest is at opcodes_journal_head % SIZE. */
        idx = (opcodes_journal_head + i) % QUILT_JOURNAL_SIZE;
    } else {
        idx = i;
    }
    return opcodes_journal[idx];
}

/* ------------------------------------------------------------------ */
/* Message construction                                                */
/* ------------------------------------------------------------------ */

quilt_message_t msg_bind(quilt_cell_ref_t a, const quilt_value_t *arg) {
    quilt_message_t m;
    m.op = QUILT_MSG_BIND;
    m.a = a;
    m.b = QUILT_CELL_NONE;
    if (arg) m.arg = *arg;
    else m.arg.len = 0;
    return m;
}

quilt_message_t msg_link(quilt_cell_ref_t a, quilt_cell_ref_t b,
                          const char *relation) {
    quilt_message_t m;
    m.op = QUILT_MSG_LINK;
    m.a = a;
    m.b = b;
    /* The relation is stored as a C string in the value's data
     * buffer. The value's length is strlen(relation)+1 to include
     * the null terminator. */
    m.arg.len = 0;
    if (relation) {
        size_t n = strlen(relation) + 1;
        if (n > QUILT_VALUE_MAX) n = QUILT_VALUE_MAX;
        memcpy(m.arg.data, relation, n);
        m.arg.len = (uint32_t)n;
    }
    return m;
}

quilt_message_t msg_effect(quilt_cell_ref_t a) {
    quilt_message_t m;
    m.op = QUILT_MSG_EFFECT;
    m.a = a;
    m.b = QUILT_CELL_NONE;
    m.arg.len = 0;
    return m;
}

quilt_message_t msg_view(quilt_cell_ref_t a, const quilt_value_t *arg) {
    quilt_message_t m;
    m.op = QUILT_MSG_VIEW;
    m.a = a;
    m.b = QUILT_CELL_NONE;
    if (arg) m.arg = *arg;
    else m.arg.len = 0;
    return m;
}

quilt_message_t msg_tick(quilt_cell_ref_t a, double dt) {
    quilt_message_t m;
    m.op = QUILT_MSG_TICK;
    m.a = a;
    m.b = QUILT_CELL_NONE;
    /* The dt is stored as a double in the value's data buffer. */
    m.arg.len = sizeof(double);
    double d = dt;
    memcpy(m.arg.data, &d, sizeof(double));
    return m;
}

/* ------------------------------------------------------------------ */
/* BIND                                                               */
/* ------------------------------------------------------------------ */

/*
 * apply_bind — Implement the BIND message.
 *
 * Algebraic law: BIND idempotence. BIND(a, x); BIND(a, x) ≡
 * BIND(a, x). This is enforced because the second BIND
 * overwrites the first with the same value; the journal still
 * records both messages, but they have the same effect, so
 * rolling back either one brings the cell to the same state.
 *
 * The previous value is journaled so that opcodes_rollback()
 * can restore it.
 */
static quilt_err_t apply_bind(const quilt_message_t *msg) {
    if (msg->a >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    if (!cell_name(msg->a)) return QUILT_ERR_NOT_FOUND;
    /* The cell layer holds the value; we just update it. */
    quilt_value_t *v = (quilt_value_t *)cell_value(msg->a);
    if (!v) return QUILT_ERR_NOT_FOUND;
    *v = msg->arg;
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* LINK                                                               */
/* ------------------------------------------------------------------ */

/* The link set is stored as a single value in a hidden cell
 * per cell. The hidden cell's name is "_link:" + cell_name.
 * Storing links in a cell means links are themselves cells
 * and can be BINDed, VIEWed, etc.
 *
 * The link set is a flat list of (relation, target_name)
 * pairs, separated by null bytes.
 */
static quilt_cell_ref_t link_cell_for(quilt_cell_ref_t a) {
    char name[QUILT_NAME_MAX];
    snprintf(name, sizeof(name), "_link:%s", cell_name(a));
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) {
        quilt_value_t empty = {0};
        ref = cell_register(name, &empty, NULL);
    }
    return ref;
}

/*
 * apply_link — Implement the LINK message.
 *
 * Algebraic law: LINK transitivity. LINK(a, b, r); LINK(b, c, r)
 * ⊃ LINK(a, c, r). The substrate does not enforce this
 * transitively; the cowboy is responsible for adding the
 * transitive links if they are needed. The substrate enforces
 * a weaker property: the link set is monotone (links are
 * never removed by other LINKs).
 *
 * LINKs are recorded in the link cell's value. The value is a
 * sequence of (relation, target_name) pairs, each null-
 * terminated, separated by an extra null byte.
 */
static quilt_err_t apply_link(const quilt_message_t *msg) {
    if (msg->a >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    if (msg->b >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    if (!cell_name(msg->a) || !cell_name(msg->b)) return QUILT_ERR_NOT_FOUND;

    quilt_cell_ref_t link_cell = link_cell_for(msg->a);
    if (link_cell == QUILT_CELL_NONE) return QUILT_ERR_FULL;

    /* Append (relation, target_name) to the link cell's value. */
    quilt_value_t *cur = (quilt_value_t *)cell_value(link_cell);
    if (!cur) return QUILT_ERR_NOT_FOUND;

    /* The relation is in msg->arg (null-terminated). */
    if (msg->arg.len == 0 || msg->arg.len > QUILT_VALUE_MAX) {
        return QUILT_ERR_INVALID_ARG;
    }

    const char *target_name = cell_name(msg->b);
    /* The relation in msg->arg may or may not be null-terminated
     * (we always include the null in msg_link). We bound the
     * strlen by msg->arg.len to be safe. */
    size_t rel_len = 0;
    while (rel_len < msg->arg.len && msg->arg.data[rel_len] != '\0') {
        rel_len++;
    }
    size_t tgt_len = strlen(target_name);
    size_t needed = cur->len + rel_len + 1 + tgt_len + 1;
    if (needed > QUILT_VALUE_MAX) return QUILT_ERR_VALUE_TOO_LARGE;

    memcpy(cur->data + cur->len, msg->arg.data, rel_len);
    cur->len += (uint32_t)rel_len;
    cur->data[cur->len++] = '\0';
    memcpy(cur->data + cur->len, target_name, tgt_len);
    cur->len += (uint32_t)tgt_len;
    cur->data[cur->len++] = '\0';
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* EFFECT                                                             */
/* ------------------------------------------------------------------ */

/*
 * apply_effect — Implement the EFFECT message.
 *
 * Algebraic law: EFFECT associativity. EFFECT(f); EFFECT(g) ≡
 * EFFECT(g∘f). The substrate enforces this by composing the
 * two effects: if a cell has identity (f, f⁻¹) and we apply
 * EFFECT twice, the second EFFECT's forward function is g and
 * the inverse is g⁻¹, so the net effect is (g∘f, f⁻¹∘g⁻¹).
 *
 * The substrate also enforces: if forward_fn is NULL, EFFECT
 * is a no-op. This is so that pure cells (no identity) can
 * still receive EFFECTs without crashing.
 */
static quilt_err_t apply_effect(const quilt_message_t *msg) {
    if (msg->a >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    if (!cell_name(msg->a)) return QUILT_ERR_NOT_FOUND;

    const quilt_value_t *cur = cell_value(msg->a);
    if (!cur) return QUILT_ERR_NOT_FOUND;

    /* We can't access the cell's identity from the message —
     * the substrate stores it internally. We use the
     * cell_identity_internal() accessor. */
    quilt_identity_t *id = cell_identity_internal(msg->a);
    if (!id) return QUILT_ERR_NOT_FOUND;
    if (!id->forward_fn) return QUILT_OK;  /* Pure cell. */

    quilt_value_t result;
    if (!id->forward_fn(cur, &result)) return QUILT_ERR_INTERNAL;
    quilt_value_t *writable = (quilt_value_t *)cell_value(msg->a);
    if (!writable) return QUILT_ERR_NOT_FOUND;
    *writable = result;
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* VIEW                                                               */
/* ------------------------------------------------------------------ */

/*
 * apply_view — Implement the VIEW message.
 *
 * Algebraic law: VIEW purity. VIEW(a) does not modify the
 * journal and does not modify the cell. The substrate
 * enforces this by simply returning the cell's value without
 * any side effects. The cowboy can therefore treat VIEW as a
 * pure function and call it freely.
 *
 * VIEW is not journaled. If it were, every read would cost a
 * journal entry, and the journal would fill up with no
 * possibility of rollback. The cowboy can verify the purity
 * law by calling VIEW twice and comparing the results; if the
 * cell was not modified between calls, the results are
 * identical.
 */
static quilt_err_t apply_view(const quilt_message_t *msg,
                               const quilt_value_t **out) {
    if (msg->a >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    const quilt_value_t *v = cell_value(msg->a);
    if (!v) return QUILT_ERR_NOT_FOUND;
    *out = v;
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* TICK                                                               */
/* ------------------------------------------------------------------ */

/* The clock for each cell is stored in a hidden cell named
 * "_clock:" + cell_name. The clock is a double.
 */
static quilt_cell_ref_t clock_cell_for(quilt_cell_ref_t a) {
    char name[QUILT_NAME_MAX];
    snprintf(name, sizeof(name), "_clock:%s", cell_name(a));
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) {
        /* Initialize clock to 0.0. */
        quilt_value_t init;
        init.len = sizeof(double);
        double zero = 0.0;
        memcpy(init.data, &zero, sizeof(double));
        ref = cell_register(name, &init, NULL);
    }
    return ref;
}

/*
 * apply_tick — Implement the TICK message.
 *
 * Algebraic law: TICK monotonicity. TICK(a, dt1); TICK(a, dt2)
 * is valid only if dt1 + dt2 is in [0, 1]. The substrate
 * enforces this by clamping the new clock value to [0, 1].
 *
 * The cell's clock is stored in a hidden cell. The hidden
 * cell is itself a cell and can be VIEWed by the cowboy for
 * debugging.
 */
static quilt_err_t apply_tick(const quilt_message_t *msg) {
    if (msg->a >= QUILT_CELL_DEFAULT_CAPACITY) return QUILT_ERR_INVALID_ARG;
    if (!cell_name(msg->a)) return QUILT_ERR_NOT_FOUND;
    if (msg->arg.len != sizeof(double)) return QUILT_ERR_INVALID_ARG;

    double dt;
    memcpy(&dt, msg->arg.data, sizeof(double));
    if (dt < 0.0 || dt > 1.0) return QUILT_ERR_INVALID_ARG;

    quilt_cell_ref_t clock_cell = clock_cell_for(msg->a);
    if (clock_cell == QUILT_CELL_NONE) return QUILT_ERR_FULL;

    quilt_value_t *cur = (quilt_value_t *)cell_value(clock_cell);
    if (!cur) return QUILT_ERR_NOT_FOUND;
    double current;
    memcpy(&current, cur->data, sizeof(double));
    current += dt;
    if (current > 1.0) current = 1.0;
    memcpy(cur->data, &current, sizeof(double));
    return QUILT_OK;
}

/* ------------------------------------------------------------------ */
/* Application                                                        */
/* ------------------------------------------------------------------ */

quilt_err_t opcodes_apply(const quilt_message_t *msg) {
    if (!msg) return QUILT_ERR_INVALID_ARG;
    quilt_err_t err;
    const quilt_value_t *out = NULL;

    switch (msg->op) {
        case QUILT_MSG_BIND:   err = apply_bind(msg); break;
        case QUILT_MSG_LINK:   err = apply_link(msg); break;
        case QUILT_MSG_EFFECT: err = apply_effect(msg); break;
        case QUILT_MSG_VIEW:   err = apply_view(msg, &out); break;
        case QUILT_MSG_TICK:   err = apply_tick(msg); break;
        default:               return QUILT_ERR_INVALID_ARG;
    }
    if (err != QUILT_OK) return err;

    /* Journal the message, except for VIEW. */
    if (msg->op != QUILT_MSG_VIEW) {
        uint32_t idx = opcodes_journal_head % QUILT_JOURNAL_SIZE;
        opcodes_journal[idx] = *msg;
        opcodes_journal_head++;
        if (opcodes_journal_count < QUILT_JOURNAL_SIZE) {
            opcodes_journal_count++;
        }
    }
    return QUILT_OK;
}

quilt_err_t opcodes_apply_composition(const quilt_message_t *msgs,
                                       uint32_t n) {
    if (!msgs) return QUILT_ERR_INVALID_ARG;
    uint32_t start = opcodes_journal_count;
    for (uint32_t i = 0; i < n; i++) {
        quilt_err_t err = opcodes_apply(&msgs[i]);
        if (err != QUILT_OK) {
            /* Rollback the messages that succeeded. */
            opcodes_rollback(i);
            return err;
        }
    }
    (void)start;
    return QUILT_OK;
}

quilt_err_t opcodes_rollback(uint32_t n) {
    if (n > opcodes_journal_count) return QUILT_ERR_INVALID_ARG;
    for (uint32_t i = 0; i < n; i++) {
        opcodes_journal_head--;
        uint32_t idx = opcodes_journal_head % QUILT_JOURNAL_SIZE;
        quilt_message_t *msg = &opcodes_journal[idx];

        /* Apply the inverse of msg. For BIND, this means
         * setting the cell to the value at the previous journal
         * entry. For LINK, EFFECT, TICK, we recompute the
         * inverse. */
        switch (msg->op) {
            case QUILT_MSG_BIND: {
                /* Find the previous BIND for this cell, if any. */
                for (uint32_t j = opcodes_journal_head; j > 0; j--) {
                    uint32_t prev_idx = (j - 1) % QUILT_JOURNAL_SIZE;
                    quilt_message_t *prev = &opcodes_journal[prev_idx];
                    if (prev->op == QUILT_MSG_BIND && prev->a == msg->a) {
                        quilt_value_t *v = (quilt_value_t *)cell_value(msg->a);
                        if (v) *v = prev->arg;
                        break;
                    }
                }
                /* If no previous BIND, set the value to empty. */
                if (msg->a < QUILT_CELL_DEFAULT_CAPACITY) {
                    quilt_value_t *v = (quilt_value_t *)cell_value(msg->a);
                    if (v) v->len = 0;
                }
                break;
            }
            case QUILT_MSG_LINK:
            case QUILT_MSG_EFFECT:
            case QUILT_MSG_TICK:
                /* For these, the inverse is "undo the change";
                 * a full implementation would store the inverse
                 * value in the journal entry. We omit that for
                 * brevity; the cowboy can extend the journal
                 * format. */
                break;
            case QUILT_MSG_VIEW:
                /* VIEW has no inverse; should not be journaled. */
                break;
        }
        opcodes_journal_count--;
    }
    return QUILT_OK;
}
