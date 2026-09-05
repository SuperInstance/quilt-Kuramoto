/*
 * opcodes.h — The 5 messages.
 *
 * A message is a unit of behavior sent to a cell. There are
 * exactly 5 message types: BIND, LINK, EFFECT, VIEW, TICK. They
 * are jointly exhaustive and mutually exclusive for cell
 * transformations; see docs/MATHEMATICS.md §2 for the proof.
 *
 * The 5 messages are the substrate's complete API at the cell
 * level. Everything else in the substrate is a composition of
 * these 5.
 *
 * This file is Layer 3 (message layer). It depends on Layer 2
 * (cell.h).
 */

#ifndef QUILT_OPCODES_H
#define QUILT_OPCODES_H

#include "cell.h"

/* ------------------------------------------------------------------ */
/* Message types                                                      */
/* ------------------------------------------------------------------ */

/*
 * The 5 message types.
 *
 * Why an enum? Because messages are first-class values in the
 * substrate. The cowboy can pass them around, store them in
 * cells, and compose them. An enum is the natural C99 way to
 * represent a small, closed set of alternatives.
 *
 * IMPORTANT: The substrate guarantees that the set of message
 * types is closed under composition. Adding a 6th type is
 * possible via evolution (see include/evolution.h), but the 5
 * below are the only ones the substrate understands natively.
 */
typedef enum {
    QUILT_MSG_BIND   = 0,  /* Set the value of a cell. */
    QUILT_MSG_LINK   = 1,  /* Record a relation between two cells. */
    QUILT_MSG_EFFECT = 2,  /* Run a forward function and record the inverse. */
    QUILT_MSG_VIEW   = 3,  /* Read a value (or a projection of it). */
    QUILT_MSG_TICK   = 4   /* Advance the cell's clock. */
} quilt_msg_type_t;

/*
 * The 5 message types as a count. Useful for iteration.
 */
#define QUILT_MSG_COUNT 5

/*
 * The 5 message types as a string array. Useful for debugging.
 */
extern const char *quilt_msg_type_name[QUILT_MSG_COUNT];

/* ------------------------------------------------------------------ */
/* Message structure                                                  */
/* ------------------------------------------------------------------ */

/*
 * A message. A first-class value that can be sent to a cell.
 *
 * The 5 fields below cover the 5 message types. Not every field
 * is used by every message; the table below shows which fields
 * are used by which.
 *
 *   Type     | Fields used
 *   ---------|--------------------------------------------
 *   BIND     | a (target cell), arg (new value)
 *   LINK     | a (source), b (target), arg (relation string)
 *   EFFECT   | a (target), forward_fn, inverse_fn (from arg)
 *   VIEW     | a (target), arg (projection spec)
 *   TICK     | a (target), arg (delta)
 *
 * The substrate is responsible for interpreting the fields
 * correctly. The cowboy is responsible for setting the right
 * fields for the right message type.
 */
typedef struct {
    quilt_msg_type_t    op;        /* The message type. */
    quilt_cell_ref_t    a;         /* The primary cell. */
    quilt_cell_ref_t    b;         /* The secondary cell (LINK only). */
    quilt_value_t       arg;       /* The argument (type-dependent). */
} quilt_message_t;

/* ------------------------------------------------------------------ */
/* Message construction                                               */
/* ------------------------------------------------------------------ */

/*
 * msg_bind — Construct a BIND message.
 *
 * BIND sets the value of cell `a` to the bytes in `arg`. The
 * cell's identity (if any) is preserved. The previous value of
 * the cell is journaled so that the BIND can be rolled back.
 *
 * @param a    The target cell.
 * @param arg  The new value. Copied by the message; the caller
 *             may free or reuse the buffer.
 * @return     A BIND message.
 */
quilt_message_t msg_bind(quilt_cell_ref_t a, const quilt_value_t *arg);

/*
 * msg_link — Construct a LINK message.
 *
 * LINK records that cell `a` is related to cell `b` by the
 * relation named in `arg`. The relation is a null-terminated
 * string. The cell's link set is updated to include `(b,
 * relation)`. The previous link set is journaled.
 *
 * The relation string is copied into the cell's link set. The
 * caller may free or reuse the buffer.
 *
 * @param a         The source cell.
 * @param b         The target cell.
 * @param relation  The relation. A null-terminated string of at
 *                  most QUILT_NAME_MAX-1 bytes.
 * @return          A LINK message.
 */
quilt_message_t msg_link(quilt_cell_ref_t a, quilt_cell_ref_t b,
                          const char *relation);

/*
 * msg_effect — Construct an EFFECT message.
 *
 * EFFECT runs the cell's forward function on its current value
 * and stores the result. The inverse function is recorded so the
 * effect can be rolled back. Both functions come from the cell's
 * identity (set at registration time).
 *
 * If the cell has no identity, EFFECT is a no-op (the value is
 * unchanged).
 *
 * @param a  The target cell.
 * @return   An EFFECT message.
 */
quilt_message_t msg_effect(quilt_cell_ref_t a);

/*
 * msg_view — Construct a VIEW message.
 *
 * VIEW reads the cell's value (or a projection of it) and
 * returns the result. The projection is a function pointer
 * stored in the cell's identity. If the cell has no projection,
 * VIEW returns the full value.
 *
 * VIEW is pure: it has no side effects. The substrate does not
 * journal VIEWs.
 *
 * @param a    The target cell.
 * @param arg  An optional projection spec. May be NULL for
 *             "no projection" (return the full value).
 * @return     A VIEW message.
 */
quilt_message_t msg_view(quilt_cell_ref_t a, const quilt_value_t *arg);

/*
 * msg_tick — Construct a TICK message.
 *
 * TICK advances the cell's clock by `arg` (interpreted as a
 * double in the range [0, 1], representing the fraction of a
 * cycle). The cell's clock is monotonically non-decreasing.
 *
 * @param a    The target cell.
 * @param dt   The time delta. Must be in [0, 1].
 * @return     A TICK message.
 */
quilt_message_t msg_tick(quilt_cell_ref_t a, double dt);

/* ------------------------------------------------------------------ */
/* Message application                                                */
/* ------------------------------------------------------------------ */

/*
 * opcodes_apply — Apply a message to a cell.
 *
 * This is the core of the substrate. The cowboy calls this
 * function to send a message to a cell. The substrate
 * interprets the message according to its type and updates the
 * cell accordingly.
 *
 * The message is journaled (except for VIEW) so that it can be
 * rolled back. See opcodes_rollback() in src/opcodes.c.
 *
 * @param msg  The message to apply.
 * @return     QUILT_OK on success, or a negative error code.
 *
 * See also: opcodes_rollback(), opcodes_apply_composition()
 */
quilt_err_t opcodes_apply(const quilt_message_t *msg);

/*
 * opcodes_apply_composition — Apply a sequence of messages in order.
 *
 * Applies each message in the array in turn. If any message
 * fails, the composition stops and the substrate rolls back the
 * messages that succeeded. The returned error code is the
 * error code of the failing message.
 *
 * This is the substrate's composition primitive. The cowboy
 * can build higher-level messages by composing sequences of
 * the 5 primitives.
 *
 * @param msgs    The array of messages.
 * @param n       The number of messages.
 * @return        QUILT_OK on success, or a negative error code.
 */
quilt_err_t opcodes_apply_composition(const quilt_message_t *msgs,
                                       uint32_t n);

/*
 * opcodes_rollback — Roll back the last `n` messages.
 *
 * Applies the inverses of the last `n` messages in reverse
 * order. The substrate keeps a journal of applied messages;
 * opcodes_rollback() consumes the journal.
 *
 * @param n  The number of messages to roll back.
 * @return   QUILT_OK on success, QUILT_ERR_INVALID_ARG if n is
 *           greater than the journal size.
 */
quilt_err_t opcodes_rollback(uint32_t n);

/*
 * opcodes_journal_size — Return the number of messages currently
 * in the journal.
 *
 * @return  The journal size.
 */
uint32_t opcodes_journal_size(void);

/*
 * opcodes_journal_get — Return a copy of the message at index i
 * in the journal.
 *
 * @param i  The index. Must be < opcodes_journal_size().
 * @return   A copy of the i-th message. The caller owns the
 *           copy.
 */
quilt_message_t opcodes_journal_get(uint32_t i);

/* ------------------------------------------------------------------ */
/* Algebraic law prover (forward-declared; implemented in src/prove.c)*/
/* ------------------------------------------------------------------ */

/*
 * prove_composition — Check that a composition satisfies the 5
 * algebraic laws.
 *
 * This is the substrate's safety check for self-evolution. The
 * cowboy can synthesize a new message as a composition of the 5
 * primitives and pass it to prove_composition(); if the
 * composition passes, the cowboy can register it as a new
 * message via evolution_register().
 *
 * The 5 laws are:
 *   1. BIND idempotence: BIND(x); BIND(x) ≡ BIND(x)
 *   2. LINK transitivity: LINK(a,b,r); LINK(b,c,r) ⊃ LINK(a,c,r)
 *   3. EFFECT associativity: EFFECT(f); EFFECT(g) ≡ EFFECT(g∘f)
 *   4. VIEW purity: VIEW(a) does not modify the journal
 *   5. TICK monotonicity: TICK(a, dt1); TICK(a, dt2) is valid
 *
 * See docs/MATHEMATICS.md §2 and §5 for the full statements.
 *
 * @param msgs  The composition to prove.
 * @param n     The number of messages in the composition.
 * @return      QUILT_OK if the composition is valid,
 *              QUILT_ERR_LAW_VIOLATION otherwise.
 */
quilt_err_t prove_composition(const quilt_message_t *msgs, uint32_t n);

#endif /* QUILT_OPCODES_H */
