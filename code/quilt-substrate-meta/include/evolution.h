/*
 * evolution.h — The self-evolving API.
 *
 * The substrate can derive new messages from the 5 primitives
 * via composition. A new message is a finite composition of the
 * 5 primitives that satisfies the 5 algebraic laws. The
 * derivation algorithm is in src/derive.c; the law prover is
 * in src/prove.c.
 *
 * The cowboy writes an `evolution_fn` and registers it. The
 * substrate calls the function at boot and accepts any new
 * messages that pass the prover. The substrate is then
 * self-extended: it has 5 + N opcodes, where N is the number
 * of derived messages.
 *
 * This file is Layer 4 (evolution layer). It depends on
 * Layer 3 (opcodes.h) and Layer 2 (cell.h).
 *
 * See docs/MATHEMATICS.md §5 ("Closure: the 6th opcode") and §6
 * ("The self-evolution theorem") for the formal treatment.
 */

#ifndef QUILT_EVOLUTION_H
#define QUILT_EVOLUTION_H

#include "opcodes.h"

/* ------------------------------------------------------------------ */
/* Evolution function                                                 */
/* ------------------------------------------------------------------ */

/*
 * An evolution function. The cowboy's hook into the substrate's
 * self-evolution machinery.
 *
 * The substrate calls all registered evolution functions at
 * boot, in registration order. Each function returns a list of
 * candidate messages. The substrate checks each candidate
 * against the algebraic laws; candidates that pass are added to
 * the message set.
 *
 * The function should not have side effects. It is called once
 * per boot; the substrate does not retry. If the function
 * fails, the substrate skips the candidate and continues.
 *
 * @param user     An opaque pointer set at registration time.
 * @param out      The output array. The function should fill
 *                 this with candidate messages.
 * @param out_max  The maximum number of messages the function
 *                 can write to `out`.
 * @return         The number of messages written, or 0 if the
 *                 function has no candidates.
 */
typedef uint32_t (*evolution_fn)(void *user,
                                  quilt_message_t *out,
                                  uint32_t out_max);

/* ------------------------------------------------------------------ */
/* Evolution lifecycle                                                 */
/* ------------------------------------------------------------------ */

/*
 * evolution_init — Initialize the evolution layer.
 *
 * Must be called once at substrate boot, after cell_init() and
 * before any other evolution_* function.
 */
quilt_err_t evolution_init(void);

/*
 * evolution_shutdown — Release the evolution layer.
 *
 * Must be called once at substrate shutdown, before
 * cell_shutdown().
 */
void evolution_shutdown(void);

/* ------------------------------------------------------------------ */
/* Evolution registration                                             */
/* ------------------------------------------------------------------ */

/*
 * evolution_register — Register an evolution function.
 *
 * The function is called by the substrate at boot. It may
 * return any number of candidate messages; each is checked
 * against the algebraic laws and either accepted or rejected.
 *
 * The substrate supports up to 8 evolution functions. The 8th
 * is a no-op; the cowboy should not register more than 7.
 *
 * @param fn    The evolution function.
 * @param user  An opaque user pointer.
 * @return      QUILT_OK on success, QUILT_ERR_FULL if 8
 *              functions are already registered.
 */
quilt_err_t evolution_register(evolution_fn fn, void *user);

/*
 * evolution_count — Return the number of registered evolution
 * functions.
 */
uint32_t evolution_count(void);

/*
 * evolution_derived_count — Return the number of derived
 * messages currently in the message set.
 *
 * The message set starts with the 5 primitives. Each accepted
 * derived message is appended. The total message set size is
 * 5 + evolution_derived_count().
 */
uint32_t evolution_derived_count(void);

/*
 * evolution_reset — Discard all derived messages.
 *
 * Removes all derived messages from the message set. The 5
 * primitives remain. The evolution functions are not
 * unregistered; they are simply not re-applied until the next
 * evolution_tick() call.
 */
void evolution_reset(void);

/*
 * evolution_tick — Re-run all evolution functions.
 *
 * By default, evolution functions are called once at boot. The
 * cowboy can call evolution_tick() to re-run them. This is
 * useful for applications that load new code at runtime: after
 * loading the new code, the cowboy calls evolution_tick() and
 * the new code's evolution functions are applied.
 *
 * @return  QUILT_OK on success.
 */
quilt_err_t evolution_tick(void);

/* ------------------------------------------------------------------ */
/* Built-in derivations                                               */
/* ------------------------------------------------------------------ */

/*
 * The substrate ships with 3 built-in derivations. They are
 * available without any user-supplied evolution function.
 *
 *   1. CALL(a, b)  — invoke cell a with arguments from cell b
 *   2. GROUP(a, b) — merge two cells into a single new cell
 *   3. TICK_ALL()  — tick all cells in the substrate
 *
 * The cowboy can use these as-is, or use them as templates for
 * further derivations.
 *
 * See src/derive.c for the derivations.
 */
quilt_message_t derive_call(quilt_cell_ref_t a, quilt_cell_ref_t b);
quilt_message_t derive_group(quilt_cell_ref_t a, quilt_cell_ref_t b);
quilt_err_t derive_tick_all(void);

/*
 * The internal derivation functions used by evolution_init().
 * The cowboy should not call these directly; they are called
 * automatically by the evolution layer.
 */
uint32_t derive_builtin_call(void *user, quilt_message_t *out, uint32_t out_max);
uint32_t derive_builtin_group(void *user, quilt_message_t *out, uint32_t out_max);
uint32_t derive_builtin_tick_all(void *user, quilt_message_t *out, uint32_t out_max);

#endif /* QUILT_EVOLUTION_H */
