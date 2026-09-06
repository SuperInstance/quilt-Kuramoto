/*
 * cell.h — The cell primitive.
 *
 * A cell is the ONLY state in the substrate. A cell is a triple
 * (name, value, identity). The cell is the substrate's atomic unit.
 * Everything else in the substrate is a function on cells.
 *
 * See docs/MATHEMATICS.md §1 ("The cell") for the formal definition.
 * See docs/GLOSSARY.md ("cell", "binding", "identity") for terminology.
 *
 * This file is Layer 2 (cell layer). It has no dependencies on
 * other substrate files. It depends only on the C standard library.
 */

#ifndef QUILT_CELL_H
#define QUILT_CELL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ------------------------------------------------------------------ */
/* Constants                                                          */
/* ------------------------------------------------------------------ */

/* The maximum length of a cell name in bytes.
 *
 * Why 256? Long enough for hierarchical names like
 * "user/alice/email/inbox/count". Short enough to fit in two cache
 * lines on most CPUs. The substrate treats names as opaque strings;
 * the cowboy is free to use any convention.
 *
 * If a name exceeds QUILT_NAME_MAX, the cell_register() function
 * returns QUILT_ERR_NAME_TOO_LONG and the cell is not registered.
 */
#define QUILT_NAME_MAX 256

/* The maximum length of a cell value in bytes.
 *
 * Why 64KB? Large enough to hold a small document, an image, or a
 * serialized object graph. Small enough to be copied in a single
 * memcpy. For larger values, the cowboy should store a pointer in
 * the cell and keep the actual data elsewhere.
 *
 * If a value exceeds QUILT_VALUE_MAX, the cell_bind() function
 * returns QUILT_ERR_VALUE_TOO_LARGE and the cell is not updated.
 */
#define QUILT_VALUE_MAX (64 * 1024)

/* The default number of cells the substrate can hold.
 *
 * Why 4096? Enough for most applications. A substrate instance can
 * be resized with cell_reserve() if more cells are needed. The
 * substrate holds cells in three parallel arrays (see Decision 2 in
 * docs/CODING-AGENT-GUIDE.md), so the cost of a cell is 3 pointers.
 */
#define QUILT_CELL_DEFAULT_CAPACITY 4096

/* ------------------------------------------------------------------ */
/* Types                                                              */
/* ------------------------------------------------------------------ */

/* A cell name. A null-terminated byte string of at most
 * QUILT_NAME_MAX-1 bytes. Names are compared with strcmp(). */
typedef char quilt_name_t[QUILT_NAME_MAX];

/* A cell value. A byte buffer of at most QUILT_VALUE_MAX bytes,
 * stored alongside its length. The buffer is not null-terminated;
 * use the length to read it. */
typedef struct {
    uint8_t  data[QUILT_VALUE_MAX];
    uint32_t len;
} quilt_value_t;

/* A cell identity. A partial function from value to value, stored
 * as a pair of (forward_fn, inverse_fn) function pointers. The
 * forward_fn is applied on BIND and EFFECT; the inverse_fn is
 * applied on rollback.
 *
 * The forward_fn and inverse_fn are user-supplied. The substrate
 * does not interpret them. The substrate does, however, require
 * that the two functions are mutual inverses: applying
 * inverse_fn after forward_fn returns the original value. This is
 * the algebraic law of EFFECT; see docs/MATHEMATICS.md §2.
 *
 * If a cell has no identity (i.e., the cell is a pure value with
 * no transformation), the forward_fn and inverse_fn are NULL. The
 * substrate treats a NULL identity as the identity function.
 */
typedef struct {
    /* The forward function. May be NULL.
     * Takes the current value (in `in`) and writes the new value
     * (in `out`). Returns true on success, false on error. */
    bool (*forward_fn)(const quilt_value_t *in, quilt_value_t *out);

    /* The inverse function. May be NULL.
     * Same signature as forward_fn. Must be the inverse of
     * forward_fn. */
    bool (*inverse_fn)(const quilt_value_t *in, quilt_value_t *out);
} quilt_identity_t;

/* A cell index. An opaque integer that refers to a cell in the
 * substrate's cell table. The cowboy never sees the raw index; the
 * cowboy always uses names. The index is used internally for
 * performance. */
typedef uint32_t quilt_cell_ref_t;

/* Sentinel for "no cell." Used as a return value when a lookup
 * fails. */
#define QUILT_CELL_NONE ((quilt_cell_ref_t)0xFFFFFFFFu)

/* A return code. The substrate uses positive integers for success
 * (0 is success), negative integers for errors. */
typedef enum {
    QUILT_OK                    =  0,  /* Success. */
    QUILT_ERR_NAME_TOO_LONG     = -1,  /* Name exceeds QUILT_NAME_MAX. */
    QUILT_ERR_VALUE_TOO_LARGE   = -2,  /* Value exceeds QUILT_VALUE_MAX. */
    QUILT_ERR_NOT_FOUND         = -3,  /* Cell with that name does not exist. */
    QUILT_ERR_ALREADY_EXISTS    = -4,  /* Cell with that name already exists. */
    QUILT_ERR_FULL              = -5,  /* Substrate is at capacity. */
    QUILT_ERR_INVALID_ARG       = -6,  /* NULL pointer or invalid argument. */
    QUILT_ERR_LAW_VIOLATION     = -7,  /* A composed message violates an algebraic law. */
    QUILT_ERR_IO                = -8,  /* Storage I/O failed. */
    QUILT_ERR_INTERNAL          = -9   /* An internal invariant was violated. */
} quilt_err_t;

/* ------------------------------------------------------------------ */
/* Cell table API                                                     */
/* ------------------------------------------------------------------ */

/*
 * cell_init — Initialize the cell table.
 *
 * Allocates three parallel arrays (names, values, identities) of
 * `capacity` cells each. The cells are initially unbound.
 *
 * Must be called once at substrate boot, before any other cell_*
 * function.
 *
 * @param capacity  The number of cells to allocate. Pass
 *                  QUILT_CELL_DEFAULT_CAPACITY for the default
 *                  size.
 * @return          QUILT_OK on success, QUILT_ERR_INVALID_ARG if
 *                  capacity is 0.
 *
 * See also: cell_shutdown(), cell_reserve()
 */
quilt_err_t cell_init(uint32_t capacity);

/*
 * cell_shutdown — Release all cells and free the cell table.
 *
 * Frees the three parallel arrays. After this call, the cell
 * table is empty and must be re-initialized with cell_init()
 * before any other cell_* function is called.
 *
 * Must be called once at substrate shutdown.
 */
void cell_shutdown(void);

/*
 * cell_reserve — Grow the cell table to hold at least `min_capacity` cells.
 *
 * If the current capacity is already >= min_capacity, this is a
 * no-op. Otherwise, the three parallel arrays are reallocated to
 * the new size. Existing cells are preserved; new cells are
 * unbound.
 *
 * @param min_capacity  The new minimum capacity.
 * @return              QUILT_OK on success, QUILT_ERR_FULL on
 *                      out-of-memory.
 */
quilt_err_t cell_reserve(uint32_t min_capacity);

/*
 * cell_register — Register a new cell with a given name.
 *
 * Allocates a slot in the cell table and initializes the cell
 * with the given name, value, and identity. The cell is now
 * resident. The cowboy can then BIND, LINK, EFFECT, VIEW, or
 * TICK the cell.
 *
 * The name is copied into the cell's name slot. The value is
 * copied into the cell's value slot. The identity is copied into
 * the cell's identity slot.
 *
 * @param name        The name. Must be a valid C string of at
 *                    most QUILT_NAME_MAX-1 bytes.
 * @param value       The initial value. May be NULL (in which
 *                    case the cell starts empty).
 * @param identity    The identity. May be NULL (in which case
 *                    the cell is a pure value).
 * @return            The cell's reference on success,
 *                    QUILT_CELL_NONE on error.
 *
 * See also: cell_lookup(), cell_unregister()
 */
quilt_cell_ref_t cell_register(const char *name,
                                const quilt_value_t *value,
                                const quilt_identity_t *identity);

/*
 * cell_lookup — Look up a cell by name.
 *
 * Searches the cell table for a cell with the given name. Returns
 * the cell's reference if found, or QUILT_CELL_NONE if not.
 *
 * This is the most-called function in the substrate. The
 * implementation is a hash table lookup. The cowboy should not
 * call this in a tight loop; the cowboy should call it once and
 * cache the reference.
 *
 * @param name  The name to look up.
 * @return      The cell's reference, or QUILT_CELL_NONE.
 *
 * See also: cell_register()
 */
quilt_cell_ref_t cell_lookup(const char *name);

/*
 * cell_unregister — Unregister a cell, removing it from the table.
 *
 * Frees the cell's name, value, and identity. The cell's slot
 * is marked as free and may be reused by a subsequent
 * cell_register() call.
 *
 * After this call, any cell_ref that referred to this cell is
 * invalid. The cowboy should not use the cell_ref again.
 *
 * @param name  The name of the cell to unregister.
 * @return      QUILT_OK on success, QUILT_ERR_NOT_FOUND if no
 *              cell with that name exists.
 */
quilt_err_t cell_unregister(const char *name);

/*
 * cell_count — Return the number of currently registered cells.
 *
 * @return  The number of cells.
 */
uint32_t cell_count(void);

/*
 * cell_name — Return the name of a cell by reference.
 *
 * The returned pointer is owned by the substrate. The cowboy
 * should not free it. The pointer is valid until the cell is
 * unregistered or the substrate is shut down.
 *
 * @param ref  The cell reference.
 * @return     The name, or NULL if the ref is invalid.
 */
const char *cell_name(quilt_cell_ref_t ref);

/*
 * cell_value — Return the value of a cell by reference.
 *
 * The returned pointer is owned by the substrate. The cowboy
 * should not free it. The pointer is valid until the cell is
 * BINDed or the substrate is shut down.
 *
 * @param ref  The cell reference.
 * @return     A pointer to the cell's value, or NULL if the ref
 *             is invalid.
 */
const quilt_value_t *cell_value(quilt_cell_ref_t ref);

/*
 * cell_iterate — Iterate over all cells.
 *
 * Calls the callback for each cell in the table, in registration
 * order. The cowboy can use this to dump all cells (debugging),
 * to scan for cells matching a pattern, or to checkpoint the
 * substrate.
 *
 * The callback should return true to continue the iteration, or
 * false to stop.
 *
 * @param cb       The callback function.
 * @param user     An opaque user pointer passed to the callback.
 *
 * See also: substrate_debug_dump() in include/substrate.h
 */
typedef bool (*cell_iter_cb)(quilt_cell_ref_t ref, void *user);
void cell_iterate(cell_iter_cb cb, void *user);

/* ------------------------------------------------------------------ */
/* Internal accessors (used by substrate.c for debug dumping)         */
/* ------------------------------------------------------------------ */

/*
 * cell_capacity_internal — Return the current cell table capacity.
 *
 * This is for the substrate's debug dump. The cowboy should
 * use cell_count() instead.
 */
uint32_t cell_capacity_internal(void);

/*
 * cell_name_internal — Return the name of the cell at slot `i`,
 * or NULL if the slot is free.
 *
 * This is for the substrate's debug dump. The cowboy should
 * use cell_name(ref) instead.
 */
const char *cell_name_internal(uint32_t i);

/*
 * cell_value_internal — Return the value of the cell at slot
 * `i`, or NULL if the slot is free.
 *
 * This is for the substrate's debug dump. The cowboy should
 * use cell_value(ref) instead.
 */
const quilt_value_t *cell_value_internal(uint32_t i);

/*
 * cell_identity_internal — Return a pointer to the cell's
 * identity at slot `ref`, or NULL if the slot is free.
 *
 * This is for the message layer (opcodes.c) which needs to
 * apply the cell's forward and inverse functions for EFFECT.
 * The cowboy should not need this function.
 */
quilt_identity_t *cell_identity_internal(quilt_cell_ref_t ref);

#endif /* QUILT_CELL_H */
