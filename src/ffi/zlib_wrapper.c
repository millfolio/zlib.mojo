/*
 * zlib.mojo — minimal zlib wrapper for Mojo FFI.
 *
 * Mirrors flare/http/ffi/zlib_wrapper.c: a single-call inflate/deflate API so
 * Mojo never has to read back z_stream fields after a foreign call (the JIT can
 * serve stale stack-slot values for memory a C call modified). Pointer args are
 * void* (Int on the Mojo side); integers are C int (c_int / Int32). The caller
 * pre-allocates the output buffer; the return is bytes-written (>=0) or a
 * negative zlib error code.
 *
 * Build: ffi/build.sh -> $CONDA_PREFIX/lib/libzlibmojo.so
 */

#include <zlib.h>
#include <string.h>

/*
 * Inflate `in_len` bytes from `in_buf` into `out_buf` (capacity `out_cap`).
 *   window_bits: 15 = zlib, -15 = raw deflate, 47 = auto gzip/zlib.
 * Returns bytes written (>=0) or a negative zlib error. Z_BUF_ERROR (output too
 * small) still returns the partial count, so the caller grows + retries.
 */
int zlibm_inflate(const void *in_buf, int in_len,
                  void *out_buf, int out_cap, int window_bits) {
    z_stream s;
    memset(&s, 0, sizeof(z_stream));
    s.next_in  = (Bytef *)in_buf;
    s.avail_in = (uInt)in_len;

    int rc = inflateInit2(&s, window_bits);
    if (rc != Z_OK) return rc;

    s.next_out  = (Bytef *)out_buf;
    s.avail_out = (uInt)out_cap;

    rc = inflate(&s, Z_SYNC_FLUSH);
    int written = out_cap - (int)s.avail_out;
    inflateEnd(&s);

    if (rc == Z_STREAM_END || rc == Z_OK || rc == Z_BUF_ERROR) return written;
    return rc;  /* negative zlib error */
}

/*
 * Inflate trying zlib-wrapped (windowBits 15) first, then raw deflate (-15).
 * Covers both PDF /FlateDecode spellings.
 */
int zlibm_inflate_auto(const void *in_buf, int in_len,
                       void *out_buf, int out_cap) {
    int rc = zlibm_inflate(in_buf, in_len, out_buf, out_cap, 15);
    if (rc >= 0) return rc;
    return zlibm_inflate(in_buf, in_len, out_buf, out_cap, -15);
}

/*
 * Deflate to a zlib container (windowBits 15) — the round-trip partner of
 * zlibm_inflate_auto (not needed for PDF reading, but rounds out the binding).
 */
int zlibm_deflate(const void *in_buf, int in_len,
                  void *out_buf, int out_cap, int level) {
    z_stream s;
    memset(&s, 0, sizeof(z_stream));

    int rc = deflateInit2(&s, level, Z_DEFLATED, 15, 8, Z_DEFAULT_STRATEGY);
    if (rc != Z_OK) return rc;

    s.next_in   = (Bytef *)in_buf;
    s.avail_in  = (uInt)in_len;
    s.next_out  = (Bytef *)out_buf;
    s.avail_out = (uInt)out_cap;

    rc = deflate(&s, Z_FINISH);
    int written = out_cap - (int)s.avail_out;
    deflateEnd(&s);

    if (rc == Z_STREAM_END || rc == Z_OK || rc == Z_BUF_ERROR) return written;
    return rc;
}
