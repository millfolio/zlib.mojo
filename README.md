# zlib.mojo

> Part of [**millrace**](https://millrace.me) — local-first tooling in Mojo.

A thin Mojo binding to **zlib** — one-shot `inflate` / `deflate` — built the same
way [flare](https://github.com/millrace/flare) wraps zlib/OpenSSL: a small C shim
(`ffi/zlib_wrapper.c`) compiled to **`libzlibmojo.so`** and loaded through an
`OwnedDLHandle`. No per-consumer link flags; the shim is `dlopen`ed at runtime.

The headline use is **PDF `/FlateDecode`** (see
[pdftotext.mojo](https://github.com/millrace/pdftotext.mojo)): FlateDecode
streams are RFC-1950 zlib data, exactly what `inflate` decompresses (it also
falls back to raw deflate).

## Use

```mojo
from zlib import inflate, deflate

var raw = inflate(compressed)   # List[UInt8] -> List[UInt8]  (zlib or raw deflate)
var z   = deflate(raw)          # round-trip partner
```

Build the shim once, then build a consumer with this package on the import path:

```sh
pixi run ffi                                            # build libzlibmojo.so -> $CONDA_PREFIX/lib
mojo build your.mojo -I ../zlib.mojo/src -o your-bin    # no link flags needed
```

`_find_lib()` resolves the shim at `$CONDA_PREFIX/lib/libzlibmojo.so` (or
`build/` for a bare checkout). For distribution, bundle `libzlibmojo.so`
alongside the binary and relocate it with `@loader_path`, exactly like flare's
shims (see millrace/app's `package_headgate.sh`).

> **Why a C shim, not `external_call` to libz directly?** Two reasons, both from
> flare: (1) a single-call API means Mojo never reads back `z_stream` fields after
> a foreign call (the JIT can serve stale stack slots); (2) `external_call`
> resolves libz at *link* time, forcing every consumer to pass `-Xlinker -lz` —
> the `dlopen` shim is self-contained instead. The one gotcha: the `OwnedDLHandle`
> is passed as a **borrowed** `read` param to the worker, or Mojo's ASAP
> destruction `dlclose`s it before the call runs.

## Test

```sh
pixi run test     # builds the shim, then deflate -> inflate -> original, byte-for-byte
```

## Status / scope

- v1 is **one-shot** (whole buffer in memory) — fine for documents. A streaming
  API (`inflateInit`/`inflate`/`inflateEnd`) can come later.
- `inflate` auto-detects zlib vs raw deflate and grows the output buffer on
  overflow (PDF stream dicts don't reliably carry the decompressed size).
- macOS / Apple Silicon (`osx-arm64`), Mojo nightly `1.0.0b2.dev2026060706`.
