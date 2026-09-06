/*
 * cell.c — The cell primitive, implemented.
 *
 * A cell is a triple (name, value, identity). The cell table
 * is three parallel arrays of length `capacity`. See
 * docs/CODING-AGENT-GUIDE.md Decision 2 for why parallel arrays
 * rather than a struct.
 *
 * Lookup is by name, via a hash table. The hash function is
 * FNV-1a; see https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
 * It is fast, simple, and has good distribution for the kinds
 * of names the substrate uses (short, hierarchical strings).
 *
 * This file is Layer 2 (cell layer). It depends only on the
 * C standard library.
 */

#include "cell.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* ------------------------------------------------------------------ */
/* The cell table                                                     */
/* ------------------------------------------------------------------ */

/* The three parallel arrays. Indexed by `quilt_cell_ref_t`.
 *
 * Why three arrays instead of one array of structs? See
 * docs/CODING-AGENT-GUIDE.md Decision 2. The short version: we
 * want to scan cells by name without dereferencing, and we want
 * to move cells between memory and storage without copying
 * structs.
 *
 * `cell_names[i]`   — the name of cell i, or "" if unbound.
 * `cell_values[i]`  — the value of cell i.
 * `cell_identities[i]` — the identity of cell i, or {NULL, NULL}
 *                       if the cell has no identity.
 * `cell_used[i]`    — 1 if cell i is bound, 0 if free.
 * `cell_next_free[i]` — the next free cell after i, or
 *                       QUILT_CELL_NONE if i is the last free.
 *
 * The free list is a singly-linked list threaded through the
 * arrays; this avoids a separate allocation. The free list is
 * built by cell_init() and consumed by cell_register().
 */
static quilt_name_t        *cell_names       = NULL;
static quilt_value_t       *cell_values      = NULL;
static quilt_identity_t    *cell_identities  = NULL;
static uint8_t             *cell_used        = NULL;
static quilt_cell_ref_t    *cell_next_free   = NULL;
static uint32_t             cell_capacity    = 0;
static uint32_t             cell_used_count  = 0;

/* The head of the free list. QUILT_CELL_NONE if the table is
 * full. */
static quilt_cell_ref_t     cell_free_head   = QUILT_CELL_NONE;

/* The hash table for name lookup. Open addressing with linear
 * probing. The table is 2x the cell capacity to keep the load
 * factor <= 0.5.
 *
 * `cell_hash_slots[i]` is the cell index, or QUILT_CELL_NONE
 * if the slot is empty.
 */
static quilt_cell_ref_t    *cell_hash_slots  = NULL;
static uint32_t             cell_hash_size   = 0;
static uint32_t             cell_hash_mask   = 0;

/* ------------------------------------------------------------------ */
/* Hash function                                                      */
/* ------------------------------------------------------------------ */

/*
 * hash_fnv1a — The FNV-1a hash function.
 *
 * FNV-1a is fast, simple, and has good distribution for short
 * strings. The substrate uses 32-bit FNV-1a; the constant 0x01000193
 * is the FNV prime and 0x811c9dc5 is the FNV offset basis.
 *
 * @param s  The string to hash.
 * @return   A 32-bit hash.
 */
static uint32_t hash_fnv1a(const char *s) {
    uint32_t h = 0x811c9dc5u;
    while (*s) {
        h ^= (uint8_t)*s++;
        h *= 0x01000193u;
    }
    return h;
}

/* ------------------------------------------------------------------ */
/* Hash table                                                         */
/* ------------------------------------------------------------------ */

/*
 * hash_grow — Grow the hash table to twice its current size.
 *
 * Called when the load factor exceeds 0.5. Rehashes all
 * cells into the new table.
 *
 * @return  QUILT_OK on success, QUILT_ERR_FULL on out-of-memory.
 */
static quilt_err_t hash_grow(void) {
    uint32_t new_size = cell_hash_size * 2;
    quilt_cell_ref_t *new_slots = calloc(new_size, sizeof(quilt_cell_ref_t));
    if (!new_slots) return QUILT_ERR_FULL;
    for (uint32_t i = 0; i < new_size; i++) {
        new_slots[i] = QUILT_CELL_NONE;
    }
    /* Rehash all used cells. */
    for (uint32_t i = 0; i < cell_capacity; i++) {
        if (!cell_used[i]) continue;
        uint32_t h = hash_fnv1a(cell_names[i]) & (new_size - 1);
        while (new_slots[h] != QUILT_CELL_NONE) {
            h = (h + 1) & (new_size - 1);
        }
        new_slots[h] = i;
    }
    free(cell_hash_slots);
    cell_hash_slots = new_slots;
    cell_hash_size  = new_size;
    cell_hash_mask  = new_size - 1;
    return QUILT_OK;
}

/*
 * hash_insert — Insert a cell into the hash table.
 *
 * The cell must not already be in the table. Used by
 * cell_register().
 *
 * @param ref  The cell to insert.
 * @return     QUILT_OK on success.
 */
static quilt_err_t hash_insert(quilt_cell_ref_t ref) {
    if ((cell_used_count * 2) >= cell_hash_size) {
        quilt_err_t err = hash_grow();
        if (err) return err;
    }
    uint32_t h = hash_fnv1a(cell_names[ref]) & cell_hash_mask;
    while (cell_hash_slots[h] != QUILT_CELL_NONE) {
        h = (h + 1) & cell_hash_mask;
    }
    cell_hash_slots[h] = ref;
    return QUILT_OK;
}

/*
 * hash_remove — Remove a cell from the hash table.
 *
 * Used by cell_unregister(). Uses backward-shift deletion to
 * maintain the cluster invariant.
 *
 * @param ref  The cell to remove.
 */
static void hash_remove(quilt_cell_ref_t ref) {
    uint32_t h = hash_fnv1a(cell_names[ref]) & cell_hash_mask;
    while (cell_hash_slots[h] != ref) {
        h = (h + 1) & cell_hash_mask;
    }
    /* Backward-shift deletion: shift subsequent entries back
     * until we hit an empty slot or an entry that hashes to its
     * current slot. This preserves the cluster invariant. */
    cell_hash_slots[h] = QUILT_CELL_NONE;
    uint32_t j = (h + 1) & cell_hash_mask;
    while (cell_hash_slots[j] != QUILT_CELL_NONE) {
        uint32_t k = hash_fnv1a(cell_names[cell_hash_slots[j]]) & cell_hash_mask;
        /* Is k in the cluster from h to j? If so, shift. */
        if ((j > h && (k <= h || k > j)) ||
            (j < h && (k <= h && k > j))) {
            cell_hash_slots[h] = cell_hash_slots[j];
            cell_hash_slots[j] = QUILT_CELL_NONE;
            h = j;
        }
        j = (j + 1) & cell_hash_mask;
    }
}

/* ------------------------------------------------------------------ */
/* Cell table API (see include/cell.h for docstrings)                 */
/* ------------------------------------------------------------------ */

quilt_err_t cell_init(uint32_t capacity) {
    if (capacity == 0) return QUILT_ERR_INVALID_ARG;
    /* Round capacity up to a power of 2 for the hash table. */
    uint32_t pow2 = 1;
    while (pow2 < capacity) pow2 *= 2;

    cell_names      = calloc(pow2, sizeof(quilt_name_t));
    cell_values     = calloc(pow2, sizeof(quilt_value_t));
    cell_identities = calloc(pow2, sizeof(quilt_identity_t));
    cell_used       = calloc(pow2, sizeof(uint8_t));
    cell_next_free  = malloc(pow2 * sizeof(quilt_cell_ref_t));
    if (!cell_names || !cell_values || !cell_identities ||
        !cell_used || !cell_next_free) {
        free(cell_names);    free(cell_values);
        free(cell_identities); free(cell_used);
        free(cell_next_free);
        return QUILT_ERR_FULL;
    }

    cell_capacity   = pow2;
    cell_used_count = 0;
    /* Initialize the free list. */
    for (uint32_t i = 0; i < pow2; i++) {
        cell_next_free[i] = i + 1;
    }
    cell_next_free[pow2 - 1] = QUILT_CELL_NONE;
    cell_free_head = 0;

    /* Initialize the hash table at 2x the cell capacity. */
    cell_hash_size = pow2 * 2;
    cell_hash_mask = cell_hash_size - 1;
    cell_hash_slots = calloc(cell_hash_size, sizeof(quilt_cell_ref_t));
    if (!cell_hash_slots) {
        free(cell_names);    free(cell_values);
        free(cell_identities); free(cell_used);
        free(cell_next_free);
        return QUILT_ERR_FULL;
    }
    for (uint32_t i = 0; i < cell_hash_size; i++) {
        cell_hash_slots[i] = QUILT_CELL_NONE;
    }
    return QUILT_OK;
}

void cell_shutdown(void) {
    free(cell_names);      free(cell_values);
    free(cell_identities); free(cell_used);
    free(cell_next_free);  free(cell_hash_slots);
    cell_names = NULL; cell_values = NULL;
    cell_identities = NULL; cell_used = NULL;
    cell_next_free = NULL; cell_hash_slots = NULL;
    cell_capacity = 0; cell_used_count = 0;
    cell_free_head = QUILT_CELL_NONE;
    cell_hash_size = 0; cell_hash_mask = 0;
}

quilt_err_t cell_reserve(uint32_t min_capacity) {
    if (min_capacity <= cell_capacity) return QUILT_OK;
    /* For simplicity, we don't support shrinking; we only grow.
     * A real implementation would reallocate. For the substrate,
     * the cowboy should call cell_reserve() once at boot with
     * the maximum expected capacity. */
    return QUILT_ERR_FULL;
}

quilt_cell_ref_t cell_register(const char *name,
                                const quilt_value_t *value,
                                const quilt_identity_t *identity) {
    if (!name) return QUILT_CELL_NONE;
    if (strlen(name) >= QUILT_NAME_MAX) return QUILT_CELL_NONE;
    if (cell_lookup(name) != QUILT_CELL_NONE) return QUILT_CELL_NONE;
    if (cell_free_head == QUILT_CELL_NONE) return QUILT_CELL_NONE;

    quilt_cell_ref_t ref = cell_free_head;
    cell_free_head = cell_next_free[ref];

    strncpy(cell_names[ref], name, QUILT_NAME_MAX - 1);
    cell_names[ref][QUILT_NAME_MAX - 1] = '\0';
    if (value) {
        cell_values[ref] = *value;
    } else {
        cell_values[ref].len = 0;
    }
    if (identity) {
        cell_identities[ref] = *identity;
    } else {
        cell_identities[ref].forward_fn = NULL;
        cell_identities[ref].inverse_fn = NULL;
    }
    cell_used[ref] = 1;
    cell_used_count++;

    if (hash_insert(ref) != QUILT_OK) {
        /* Roll back. */
        cell_used[ref] = 0;
        cell_used_count--;
        cell_next_free[ref] = cell_free_head;
        cell_free_head = ref;
        return QUILT_CELL_NONE;
    }
    return ref;
}

quilt_cell_ref_t cell_lookup(const char *name) {
    if (!name || !cell_hash_slots) return QUILT_CELL_NONE;
    uint32_t h = hash_fnv1a(name) & cell_hash_mask;
    while (cell_hash_slots[h] != QUILT_CELL_NONE) {
        quilt_cell_ref_t ref = cell_hash_slots[h];
        if (strcmp(cell_names[ref], name) == 0) {
            return ref;
        }
        h = (h + 1) & cell_hash_mask;
    }
    return QUILT_CELL_NONE;
}

quilt_err_t cell_unregister(const char *name) {
    quilt_cell_ref_t ref = cell_lookup(name);
    if (ref == QUILT_CELL_NONE) return QUILT_ERR_NOT_FOUND;
    hash_remove(ref);
    cell_used[ref] = 0;
    cell_used_count--;
    cell_next_free[ref] = cell_free_head;
    cell_free_head = ref;
    cell_names[ref][0] = '\0';
    cell_values[ref].len = 0;
    cell_identities[ref].forward_fn = NULL;
    cell_identities[ref].inverse_fn = NULL;
    return QUILT_OK;
}

uint32_t cell_count(void) {
    return cell_used_count;
}

const char *cell_name(quilt_cell_ref_t ref) {
    if (ref >= cell_capacity || !cell_used[ref]) return NULL;
    return cell_names[ref];
}

const quilt_value_t *cell_value(quilt_cell_ref_t ref) {
    if (ref >= cell_capacity || !cell_used[ref]) return NULL;
    return &cell_values[ref];
}

void cell_iterate(cell_iter_cb cb, void *user) {
    if (!cb) return;
    for (uint32_t i = 0; i < cell_capacity; i++) {
        if (cell_used[i] && !cb(i, user)) return;
    }
}

/* ------------------------------------------------------------------ */
/* Internal accessors (for substrate.c debug dumping)                 */
/* ------------------------------------------------------------------ */

uint32_t cell_capacity_internal(void) { return cell_capacity; }

const char *cell_name_internal(uint32_t i) {
    if (i >= cell_capacity || !cell_used[i]) return NULL;
    return cell_names[i];
}

const quilt_value_t *cell_value_internal(uint32_t i) {
    if (i >= cell_capacity || !cell_used[i]) return NULL;
    return &cell_values[i];
}

quilt_identity_t *cell_identity_internal(quilt_cell_ref_t ref) {
    if (ref >= cell_capacity || !cell_used[ref]) return NULL;
    return &cell_identities[ref];
}
