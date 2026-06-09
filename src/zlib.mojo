"""zlib — Mojo inflate/deflate via a thin C shim (libzlibmojo.so).

Mirrors flare's FFI pattern (flare/http/encoding.mojo): a single-call C wrapper
(ffi/zlib_wrapper.c, built to $CONDA_PREFIX/lib/libzlibmojo.so by ffi/build.sh)
loaded through an `OwnedDLHandle`. The handle is passed as a BORROWED `read`
param to the worker, so Mojo's ASAP destruction can't `dlclose` the library
before the C call runs — the flare gotcha (a function-local handle is reclaimed
right after `get_function`, dangling the cached pointer and crashing the JIT).

Headline use: PDF `/FlateDecode` (RFC-1950 zlib) — see pdftotext.mojo.
"""

from std.os import getenv
from std.ffi import OwnedDLHandle, c_int


def _find_lib() -> String:
    """Path to libzlibmojo.so: `$CONDA_PREFIX/lib` (built by ffi/build.sh), else
    `build/` for a bare checkout. Mirrors flare.utils.dylib.find_flare_lib."""
    var prefix = getenv("CONDA_PREFIX", "")
    if prefix == "":
        return String("build/libzlibmojo.so")
    var out = String("")
    out += prefix
    out += "/lib/libzlibmojo.so"
    return out^


def _do_inflate(read lib: OwnedDLHandle, data: List[UInt8]) raises -> List[UInt8]:
    # `lib` borrowed -> stays mapped across the C call (flare ASAP-destruction fix).
    var inflate_fn = lib.get_function[
        def (Int, c_int, Int, c_int) thin abi("C") -> c_int
    ]("zlibm_inflate_auto")

    var cap = len(data) * 4
    if cap < 4096:
        cap = 4096
    while True:
        var out = List[UInt8](capacity=cap)
        out.resize(cap, 0)
        var written = inflate_fn(
            Int(data.unsafe_ptr()), c_int(len(data)),
            Int(out.unsafe_ptr()), c_int(cap),
        )
        var w = Int(written)
        if w < 0:
            raise Error("zlib.inflate failed (rc=" + String(w) + ")")
        if w < cap:
            out.resize(w, 0)
            return out^
        cap *= 2  # buffer filled exactly — may be truncated; grow + retry


def inflate(data: List[UInt8]) raises -> List[UInt8]:
    """Decompress an RFC-1950 zlib (or raw deflate) buffer — e.g. a PDF
    /FlateDecode stream. Grows the output buffer until the data fits."""
    if len(data) == 0:
        return List[UInt8]()
    var lib = OwnedDLHandle(_find_lib())
    return _do_inflate(lib, data)


def _do_deflate(
    read lib: OwnedDLHandle, data: List[UInt8], level: c_int
) raises -> List[UInt8]:
    var deflate_fn = lib.get_function[
        def (Int, c_int, Int, c_int, c_int) thin abi("C") -> c_int
    ]("zlibm_deflate")

    var cap = len(data) + (len(data) >> 10) + 64  # worst-case zlib overhead
    var out = List[UInt8](capacity=cap)
    out.resize(cap, 0)
    var written = deflate_fn(
        Int(data.unsafe_ptr()), c_int(len(data)),
        Int(out.unsafe_ptr()), c_int(cap), level,
    )
    var w = Int(written)
    if w < 0:
        raise Error("zlib.deflate failed (rc=" + String(w) + ")")
    out.resize(w, 0)
    return out^


def deflate(data: List[UInt8], level: Int = 6) raises -> List[UInt8]:
    """Compress to an RFC-1950 zlib buffer (round-trip partner of `inflate`)."""
    if len(data) == 0:
        return List[UInt8]()
    var lib = OwnedDLHandle(_find_lib())
    return _do_deflate(lib, data, c_int(level))
