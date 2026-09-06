#include "json.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    js_kind_t kind;
    int       start;   /* into doc->text: number/string body, NUL-terminated */
    int       first;   /* first child slot index, or -1 */
    int       count;   /* children (array elements, or object members) */
    int       bval;
} node_t;

/* One member of an object, or one element of an array. */
typedef struct {
    int key;   /* node index of the key string, or -1 for array elements */
    int val;
} slot_t;

struct js_doc {
    char   *text;    /* mutable copy of the source; strings NUL-terminated in place */
    node_t *nodes;
    size_t  nnodes, capnodes;
    slot_t *slots;
    size_t  nslots, capslots;
    /* Members are collected here first. Containers nest, so members of an
     * outer object are NOT contiguous in `slots` as they are produced -- an
     * inner array's elements land between them. Stack discipline fixes that:
     * a container's members always occupy the TOP of this pending stack when
     * it closes (every inner container has already been popped), so they can
     * be moved into `slots` as one contiguous run. */
    slot_t *pend;
    size_t  npend, cappend;
    size_t  pos;
    size_t  len;
    const char *err;
};

static int push_node(js_doc_t *d, js_kind_t k)
{
    if (d->nnodes == d->capnodes) {
        size_t cap = d->capnodes ? d->capnodes * 2 : 1024;
        node_t *n = (node_t *)realloc(d->nodes, cap * sizeof *n);
        if (!n) { d->err = "out of memory"; return -1; }
        d->nodes = n; d->capnodes = cap;
    }
    d->nodes[d->nnodes].kind  = k;
    d->nodes[d->nnodes].start = -1;
    d->nodes[d->nnodes].first = -1;
    d->nodes[d->nnodes].count = 0;
    d->nodes[d->nnodes].bval  = 0;
    return (int)d->nnodes++;
}

static int push_pend(js_doc_t *d, int key, int val)
{
    if (d->npend == d->cappend) {
        size_t cap = d->cappend ? d->cappend * 2 : 256;
        slot_t *s = (slot_t *)realloc(d->pend, cap * sizeof *s);
        if (!s) { d->err = "out of memory"; return -1; }
        d->pend = s; d->cappend = cap;
    }
    d->pend[d->npend].key = key;
    d->pend[d->npend].val = val;
    d->npend++;
    return 0;
}

/* Move pend[base..npend) into `slots` as one contiguous run. */
static int commit_pend(js_doc_t *d, size_t base, int node)
{
    size_t n = d->npend - base, i;
    if (n == 0) { d->nodes[node].first = -1; d->nodes[node].count = 0; return 0; }
    if (d->nslots + n > d->capslots) {
        size_t cap = d->capslots ? d->capslots : 1024;
        slot_t *s;
        while (cap < d->nslots + n) { cap *= 2; }
        s = (slot_t *)realloc(d->slots, cap * sizeof *s);
        if (!s) { d->err = "out of memory"; return -1; }
        d->slots = s; d->capslots = cap;
    }
    d->nodes[node].first = (int)d->nslots;
    d->nodes[node].count = (int)n;
    for (i = 0; i < n; i++) { d->slots[d->nslots + i] = d->pend[base + i]; }
    d->nslots += n;
    d->npend = base;
    return 0;
}

static void skip_ws(js_doc_t *d)
{
    while (d->pos < d->len) {
        char c = d->text[d->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { d->pos++; }
        else { break; }
    }
}

static int parse_value(js_doc_t *d);

static int parse_string(js_doc_t *d)
{
    int n;
    size_t w;
    if (d->text[d->pos] != '"') { d->err = "expected string"; return -1; }
    d->pos++;
    n = push_node(d, JS_STR);
    if (n < 0) { return -1; }
    d->nodes[n].start = (int)d->pos;
    /* Unescape in place: the result is never longer than the source. */
    w = d->pos;
    while (d->pos < d->len && d->text[d->pos] != '"') {
        char c = d->text[d->pos++];
        if (c == '\\') {
            if (d->pos >= d->len) { d->err = "unterminated escape"; return -1; }
            c = d->text[d->pos++];
            switch (c) {
            case 'n': c = '\n'; break;
            case 't': c = '\t'; break;
            case 'r': c = '\r'; break;
            case 'b': c = '\b'; break;
            case 'f': c = '\f'; break;
            case '"': case '\\': case '/': break;
            default: d->err = "unsupported escape"; return -1;
            }
        }
        d->text[w++] = c;
    }
    if (d->pos >= d->len) { d->err = "unterminated string"; return -1; }
    d->pos++;              /* consume the closing quote */
    d->text[w] = '\0';     /* safe: w <= the quote's index */
    return n;
}

static int parse_number(js_doc_t *d)
{
    int n = push_node(d, JS_NUM);
    size_t s = d->pos;
    if (n < 0) { return -1; }
    if (d->pos < d->len && (d->text[d->pos] == '-' || d->text[d->pos] == '+')) { d->pos++; }
    while (d->pos < d->len) {
        char c = d->text[d->pos];
        if ((c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' ||
            c == '-' || c == '+') { d->pos++; }
        else { break; }
    }
    if (d->pos == s) { d->err = "expected number"; return -1; }
    d->nodes[n].start = (int)s;
    /* The terminator is a delimiter (',', '}', ']', or whitespace) that the
     * caller re-reads only after skip_ws, so overwriting it is not safe --
     * instead the accessors bound the text by re-scanning. Mark the end by
     * remembering the length in `count`, which numbers do not otherwise use. */
    d->nodes[n].count = (int)(d->pos - s);
    return n;
}

static int parse_literal(js_doc_t *d, const char *lit, js_kind_t k, int bval)
{
    size_t l = strlen(lit);
    int n;
    if (d->len - d->pos < l || memcmp(d->text + d->pos, lit, l) != 0) {
        d->err = "bad literal"; return -1;
    }
    d->pos += l;
    n = push_node(d, k);
    if (n < 0) { return -1; }
    d->nodes[n].bval = bval;
    return n;
}

static int parse_array(js_doc_t *d)
{
    int n = push_node(d, JS_ARR);
    size_t base = d->npend;
    if (n < 0) { return -1; }
    d->pos++;   /* '[' */
    skip_ws(d);
    if (d->pos < d->len && d->text[d->pos] == ']') { d->pos++; return n; }
    for (;;) {
        int v;
        skip_ws(d);
        v = parse_value(d);
        if (v < 0) { return -1; }
        if (push_pend(d, -1, v) < 0) { return -1; }
        skip_ws(d);
        if (d->pos < d->len && d->text[d->pos] == ',') { d->pos++; continue; }
        if (d->pos < d->len && d->text[d->pos] == ']') { d->pos++; break; }
        d->err = "expected ',' or ']'"; return -1;
    }
    if (commit_pend(d, base, n) < 0) { return -1; }
    return n;
}

static int parse_object(js_doc_t *d)
{
    int n = push_node(d, JS_OBJ);
    size_t base = d->npend;
    if (n < 0) { return -1; }
    d->pos++;   /* '{' */
    skip_ws(d);
    if (d->pos < d->len && d->text[d->pos] == '}') { d->pos++; return n; }
    for (;;) {
        int k, v;
        skip_ws(d);
        k = parse_string(d);
        if (k < 0) { return -1; }
        skip_ws(d);
        if (d->pos >= d->len || d->text[d->pos] != ':') { d->err = "expected ':'"; return -1; }
        d->pos++;
        skip_ws(d);
        v = parse_value(d);
        if (v < 0) { return -1; }
        if (push_pend(d, k, v) < 0) { return -1; }
        skip_ws(d);
        if (d->pos < d->len && d->text[d->pos] == ',') { d->pos++; continue; }
        if (d->pos < d->len && d->text[d->pos] == '}') { d->pos++; break; }
        d->err = "expected ',' or '}'"; return -1;
    }
    if (commit_pend(d, base, n) < 0) { return -1; }
    return n;
}

static int parse_value(js_doc_t *d)
{
    char c;
    skip_ws(d);
    if (d->pos >= d->len) { d->err = "unexpected end of input"; return -1; }
    c = d->text[d->pos];
    switch (c) {
    case '{': return parse_object(d);
    case '[': return parse_array(d);
    case '"': return parse_string(d);
    case 't': return parse_literal(d, "true",  JS_BOOL, 1);
    case 'f': return parse_literal(d, "false", JS_BOOL, 0);
    case 'n': return parse_literal(d, "null",  JS_NULL, 0);
    default:  return parse_number(d);
    }
}

js_doc_t *js_parse_file(const char *path, const char **err)
{
    js_doc_t *d;
    FILE *f;
    long size;
    size_t got;
    int root;

    if (err) { *err = NULL; }
    f = fopen(path, "rb");
    if (!f) { if (err) { *err = "cannot open file"; } return NULL; }
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); if (err) { *err = "seek failed"; } return NULL; }
    size = ftell(f);
    if (size < 0) { fclose(f); if (err) { *err = "tell failed"; } return NULL; }
    rewind(f);

    d = (js_doc_t *)calloc(1, sizeof *d);
    if (!d) { fclose(f); if (err) { *err = "out of memory"; } return NULL; }
    d->text = (char *)malloc((size_t)size + 1);
    if (!d->text) { fclose(f); free(d); if (err) { *err = "out of memory"; } return NULL; }
    got = fread(d->text, 1, (size_t)size, f);
    fclose(f);
    d->text[got] = '\0';
    d->len = got;
    d->pos = 0;

    root = parse_value(d);
    if (root < 0) {
        if (err) { *err = d->err ? d->err : "parse error"; }
        js_free(d);
        return NULL;
    }
    skip_ws(d);
    if (d->pos != d->len) {
        if (err) { *err = "trailing content after root value"; }
        js_free(d);
        return NULL;
    }
    return d;
}

void js_free(js_doc_t *d)
{
    if (!d) { return; }
    free(d->text);
    free(d->nodes);
    free(d->slots);
    free(d->pend);
    free(d);
}

int js_root(const js_doc_t *d) { (void)d; return 0; }

js_kind_t js_kind(const js_doc_t *d, int v)
{
    if (v < 0 || (size_t)v >= d->nnodes) { return JS_NULL; }
    return d->nodes[v].kind;
}

int js_len(const js_doc_t *d, int v)
{
    js_kind_t k = js_kind(d, v);
    if (k != JS_ARR && k != JS_OBJ) { return -1; }
    return d->nodes[v].count;
}

int js_at(const js_doc_t *d, int v, int i)
{
    if (js_kind(d, v) != JS_ARR) { return -1; }
    if (i < 0 || i >= d->nodes[v].count) { return -1; }
    return d->slots[d->nodes[v].first + i].val;
}

int js_get(const js_doc_t *d, int v, const char *key)
{
    int i;
    if (js_kind(d, v) != JS_OBJ) { return -1; }
    for (i = 0; i < d->nodes[v].count; i++) {
        slot_t *s = &d->slots[d->nodes[v].first + i];
        if (strcmp(d->text + d->nodes[s->key].start, key) == 0) { return s->val; }
    }
    return -1;
}

const char *js_text(const js_doc_t *d, int v)
{
    js_kind_t k = js_kind(d, v);
    if (k != JS_STR && k != JS_NUM) { return NULL; }
    return d->text + d->nodes[v].start;
}

int js_bool(const js_doc_t *d, int v)
{
    return js_kind(d, v) == JS_BOOL ? d->nodes[v].bval : 0;
}

/* Length of the token: strings are NUL-terminated in place, numbers are not. */
static size_t token_len(const js_doc_t *d, int v)
{
    if (d->nodes[v].kind == JS_NUM) { return (size_t)d->nodes[v].count; }
    return strlen(d->text + d->nodes[v].start);
}

int js_u64(const js_doc_t *d, int v, uint64_t *out)
{
    const char *p = js_text(d, v);
    size_t n, i;
    uint64_t acc = 0;

    if (!p) { return 0; }
    n = token_len(d, v);
    if (n == 0) { return 0; }
    for (i = 0; i < n; i++) {
        uint64_t dig;
        if (p[i] < '0' || p[i] > '9') { return 0; }
        dig = (uint64_t)(p[i] - '0');
        /* Reject rather than wrap: vectors.json carries u128 values this
         * substrate genuinely cannot hold, and the runner must skip them. */
        if (acc > (UINT64_MAX - dig) / 10u) { return 0; }
        acc = acc * 10u + dig;
    }
    *out = acc;
    return 1;
}

int js_i64(const js_doc_t *d, int v, int64_t *out)
{
    const char *p = js_text(d, v);
    size_t n;
    int neg = 0;
    uint64_t acc = 0, limit;
    size_t i;

    if (!p) { return 0; }
    n = token_len(d, v);
    if (n == 0) { return 0; }
    i = 0;
    if (p[0] == '-') { neg = 1; i = 1; }
    else if (p[0] == '+') { i = 1; }
    if (i >= n) { return 0; }
    limit = neg ? (uint64_t)INT64_MAX + 1u : (uint64_t)INT64_MAX;
    for (; i < n; i++) {
        uint64_t dig;
        if (p[i] < '0' || p[i] > '9') { return 0; }
        dig = (uint64_t)(p[i] - '0');
        if (acc > (limit - dig) / 10u) { return 0; }
        acc = acc * 10u + dig;
    }
    if (acc > limit) { return 0; }
    *out = neg ? -(int64_t)(acc - 1u) - 1 : (int64_t)acc;
    return 1;
}
