/* json.h -- a minimal JSON reader, for the conformance runner only.
 *
 * Deliberately NOT part of the library: exact_band.c depends on nothing but
 * <stdint.h>, and that property is worth more than code reuse. This parser
 * exists solely so the C substrate can read the same vectors.json the Rust and
 * Python substrates read, rather than a hand-transcribed copy of it -- a
 * transcription is exactly the place a conformance suite goes quietly wrong.
 *
 * Scope: enough JSON for a machine-generated vector file. No \u escapes, no
 * floats (there are none in the file, by construction). Numbers are kept as
 * their source text so a value too wide for uint64_t is REPORTED rather than
 * silently truncated -- vectors.json contains u128::MAX, which this substrate
 * cannot represent, and that must surface as a skip, not as a wrong answer.
 */

#ifndef EB_JSON_H
#define EB_JSON_H

#include <stddef.h>
#include <stdint.h>

typedef enum {
    JS_NULL = 0, JS_BOOL, JS_NUM, JS_STR, JS_ARR, JS_OBJ
} js_kind_t;

typedef struct js_doc js_doc_t;

/** Parse a whole file. Returns NULL on error, with `err` set to a message. */
js_doc_t *js_parse_file(const char *path, const char **err);
void      js_free(js_doc_t *d);

/** Index of the root value. */
int js_root(const js_doc_t *d);

js_kind_t js_kind(const js_doc_t *d, int v);

/** Array length, or object member count. -1 if `v` is neither. */
int js_len(const js_doc_t *d, int v);
/** i-th array element, or -1. */
int js_at(const js_doc_t *d, int v, int i);
/** Object member by key, or -1 if absent. */
int js_get(const js_doc_t *d, int v, const char *key);

/** Raw source text of a number or string (NUL-terminated). */
const char *js_text(const js_doc_t *d, int v);
/** Boolean value; 0 if `v` is not a bool. */
int js_bool(const js_doc_t *d, int v);

/** Decimal text -> uint64_t. Returns 1 on success, 0 if it does not fit or is
 *  not a non-negative integer. Accepts JS_NUM and JS_STR alike, because the
 *  generator quotes the wide ones. */
int js_u64(const js_doc_t *d, int v, uint64_t *out);
/** Decimal text -> int64_t, same contract. */
int js_i64(const js_doc_t *d, int v, int64_t *out);

#endif /* EB_JSON_H */
