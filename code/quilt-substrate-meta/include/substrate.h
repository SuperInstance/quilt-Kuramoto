/*
 * substrate.h — The runtime API.
 *
 * The runtime is the entry point to the substrate. It is the
 * only file that knows about all the other layers. The cowboy
 * calls substrate_init() to start the substrate and
 * substrate_shutdown() to stop it.
 *
 * This file is Layer 1 (runtime layer). It depends on all the
 * other layers.
 *
 * See docs/CODING-AGENT-GUIDE.md ("The 30-second map") for the
 * role of this file in the larger system.
 */

#ifndef QUILT_SUBSTRATE_H
#define QUILT_SUBSTRATE_H

#include "cell.h"
#include "opcodes.h"
#include "evolution.h"

/* ------------------------------------------------------------------ */
/* Runtime lifecycle                                                  */
/* ------------------------------------------------------------------ */

/*
 * substrate_init — Initialize the substrate.
 *
 * Initializes the cell table (Layer 2), the message layer
 * (Layer 3), and the evolution layer (Layer 4). The substrate
 * is then ready to accept messages.
 *
 * Must be called once at the start of the program, before any
 * other substrate_* function.
 *
 * @param capacity  The number of cells to allocate. Pass
 *                  QUILT_CELL_DEFAULT_CAPACITY for the default
 *                  size.
 * @return          QUILT_OK on success.
 */
quilt_err_t substrate_init(uint32_t capacity);

/*
 * substrate_shutdown — Shut down the substrate.
 *
 * Frees all cells, clears the journal, and unregisters all
 * evolution functions. After this call, the substrate is in an
 * uninitialized state; substrate_init() must be called again
 * before any other substrate_* function.
 */
void substrate_shutdown(void);

/*
 * substrate_tick — Advance the substrate by one cycle.
 *
 * Ticks all cells, runs all evolution functions, and advances
 * the global clock. The cowboy should call this once per
 * cycle; the cycle period is application-dependent.
 */
quilt_err_t substrate_tick(void);

/* ------------------------------------------------------------------ */
/* High-level message API                                             */
/* ------------------------------------------------------------------ */

/*
 * substrate_send — Send a message.
 *
 * A convenience wrapper around opcodes_apply() that takes a
 * cell name instead of a cell reference. The substrate looks
 * up the cell by name and applies the message.
 *
 * @param name  The name of the target cell.
 * @param msg   The message to send (the `a` field is ignored;
 *              the cell is looked up by name).
 * @return      QUILT_OK on success.
 */
quilt_err_t substrate_send(const char *name, const quilt_message_t *msg);

/*
 * substrate_bind — Bind a cell by name.
 *
 * The most common substrate operation. The cowboy calls this
 * to set the value of a cell.
 *
 * @param name   The name of the cell.
 * @param value  The new value. May be NULL (in which case the
 *               cell is set to empty).
 * @return       QUILT_OK on success.
 */
quilt_err_t substrate_bind(const char *name, const quilt_value_t *value);

/*
 * substrate_link — Link two cells by name.
 *
 * @param a_name    The source cell's name.
 * @param b_name    The target cell's name.
 * @param relation  The relation (a null-terminated string).
 * @return          QUILT_OK on success.
 */
quilt_err_t substrate_link(const char *a_name, const char *b_name,
                            const char *relation);

/*
 * substrate_view — Read a cell by name.
 *
 * @param name  The cell's name.
 * @return      A pointer to the cell's value, or NULL if the
 *              cell does not exist. The pointer is owned by
 *              the substrate; the caller should not free it.
 */
const quilt_value_t *substrate_view(const char *name);

/* ------------------------------------------------------------------ */
/* Debugging                                                          */
/* ------------------------------------------------------------------ */

/*
 * substrate_debug_dump — Print all cells to stdout.
 *
 * The output format is human-readable. The cowboy can redirect
 * stdout to a file for offline inspection.
 */
void substrate_debug_dump(void);

/*
 * substrate_debug_journal — Print the last `n` journal entries.
 *
 * @param n  The number of entries to print. Pass 0 to print
 *           all entries.
 */
void substrate_debug_journal(uint32_t n);

/*
 * substrate_debug_warnings — Toggle warning prints.
 *
 * @param on  1 to enable warnings, 0 to disable.
 */
void substrate_debug_warnings(int on);

/* ------------------------------------------------------------------ */
/* The cowboy's maxim                                                 */
/* ------------------------------------------------------------------ */

/*
 * substrate_maxim — Return the cowboy's maxim as a string.
 *
 * The maxim is a single sentence that summarizes the
 * substrate. The cowboy can print it at startup as a kind of
 * "blessing" for the program.
 *
 * @return  A pointer to a static string. The caller should
 *          not free it.
 */
const char *substrate_maxim(void);

#endif /* QUILT_SUBSTRATE_H */
