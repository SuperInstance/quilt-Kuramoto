/* reference.c -- the Quilt cell state hash, C99 reference.
 *
 * The audit in README.md found `quilt-c` advertising this hash in its README
 * while never computing it in source. This file is the missing half: a C
 * implementation held to the same corpus as the Python and Rust references,
 * so the three can be compared rather than trusted.
 *
 * Spec: type(1) || id(8 LE) || dials(16 x i16 LE) || neighbours(N x u64 LE),
 * hashed with FNV-1a 64. No allocation; the largest case is 297 bytes.
 */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define FNV_OFFSET 0xCBF29CE484222325ULL
#define FNV_PRIME  0x100000001B3ULL
#define N_DIALS    16
#define MAX_NB     64
#define MAX_BYTES  (1 + 8 + N_DIALS * 2 + MAX_NB * 8)

static uint64_t fnv1a64(const uint8_t *p, size_t n)
{
    uint64_t h = FNV_OFFSET;
    size_t i;
    for (i = 0; i < n; i++) {
        h ^= (uint64_t)p[i];
        h *= FNV_PRIME;
    }
    return h;
}

/* Little-endian by explicit byte, never by memcpy of a native integer -- the
 * whole point is that a big-endian port must produce the same bytes. */
static size_t put_u64(uint8_t *out, uint64_t v)
{
    int i;
    for (i = 0; i < 8; i++) { out[i] = (uint8_t)((v >> (8 * i)) & 0xFF); }
    return 8;
}

static size_t put_i16(uint8_t *out, int16_t v)
{
    uint16_t u = (uint16_t)v;
    out[0] = (uint8_t)(u & 0xFF);
    out[1] = (uint8_t)((u >> 8) & 0xFF);
    return 2;
}

static size_t serialize(uint8_t *out, uint64_t id, const int16_t *dials,
                        const uint64_t *nb, size_t n_nb)
{
    size_t p = 0;
    int i;
    out[p++] = 1;                       /* type */
    p += put_u64(out + p, id);
    for (i = 0; i < N_DIALS; i++) { p += put_i16(out + p, dials[i]); }
    for (i = 0; i < (int)n_nb; i++) { p += put_u64(out + p, nb[i]); }
    return p;
}

static uint64_t state_hash(uint64_t id, const int16_t *dials,
                           const uint64_t *nb, size_t n_nb)
{
    uint8_t buf[MAX_BYTES];
    size_t n = serialize(buf, id, dials, nb, n_nb);
    return fnv1a64(buf, n);
}

static void emit(const char *name, uint64_t id, const int16_t *dials,
                 const uint64_t *nb, size_t n_nb)
{
    uint8_t buf[MAX_BYTES];
    size_t n = serialize(buf, id, dials, nb, n_nb);
    printf("  %-18s %4u  0x%016llx\n", name, (unsigned)n,
           (unsigned long long)fnv1a64(buf, n));
}

/* The stream: xorshift64, seeded identically in every substrate. */
static uint64_t rs;
static uint64_t nxt(void)
{
    uint64_t x = rs;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    rs = x;
    return x;
}

static uint64_t stream(unsigned long iters)
{
    uint64_t h = FNV_OFFSET;
    unsigned long t;
    rs = 0x2545F4914F6CDD1DULL;
    for (t = 0; t < iters; t++) {
        int16_t dials[N_DIALS];
        uint64_t nb[8];
        uint64_t id = nxt();
        size_t n_nb, i;
        for (i = 0; i < N_DIALS; i++) {
            dials[i] = (int16_t)((int64_t)(nxt() % 65536u) - 32768);
        }
        n_nb = (size_t)(nxt() % 9u);
        for (i = 0; i < n_nb; i++) { nb[i] = nxt(); }
        h ^= state_hash(id, dials, nb, n_nb);
        h *= FNV_PRIME;
    }
    return h;
}

int main(void)
{
    int16_t d[N_DIALS];
    uint64_t nb[32];
    int i;

    for (i = 0; i < N_DIALS; i++) { d[i] = (int16_t)(i + 1); }
    nb[0] = 2; nb[1] = 3; nb[2] = 4;
    printf("published cell: 0x%016llx\n",
           (unsigned long long)state_hash(1, d, nb, 3));

    emit("published", 1, d, nb, 3);

    { int16_t z[N_DIALS]; memset(z, 0, sizeof z); emit("zero", 0, z, nb, 0); }

    { int16_t n2[N_DIALS];
      for (i = 0; i < N_DIALS; i++) { n2[i] = (int16_t)(-(i + 1)); }
      nb[0] = 1; emit("negative-dials", 7, n2, nb, 1); }

    { int16_t e[N_DIALS];
      for (i = 0; i < N_DIALS; i++) { e[i] = (i % 2 == 0) ? -32768 : 32767; }
      nb[0] = 5; emit("dial-extremes", 9, e, nb, 1); }

    { int16_t a[N_DIALS];
      for (i = 0; i < N_DIALS; i++) {
          a[i] = (int16_t)(((i % 2 == 0) ? 1 : -1) * (i + 1));
      }
      nb[0] = 9; nb[1] = 8; nb[2] = 7; emit("alternating", 3, a, nb, 3); }

    nb[0] = 3; nb[1] = 2; nb[2] = 4;
    emit("neighbour-order", 4, d, nb, 3);

    nb[0] = 0xFFFFFFFFFFFFFFFFULL;
    emit("big-id", 0xFFFFFFFFFFFFFFFFULL, d, nb, 1);

    for (i = 0; i < 32; i++) { nb[i] = (uint64_t)(i + 1); }
    emit("many-neighbours", 11, d, nb, 32);

    printf("stream(10000):  0x%016llx\n", (unsigned long long)stream(10000));
    return 0;
}
