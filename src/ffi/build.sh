#!/bin/bash
#
# Build libzlibmojo.so — the zlib FFI shim for zlib.mojo (mirrors
# flare/http/ffi/build.sh). Compiles ffi/zlib_wrapper.c against the conda zlib
# into $CONDA_PREFIX/lib/libzlibmojo.so — the canonical location _find_lib()
# resolves. Idempotent. Run via `pixi run ffi`.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$ROOT/build"
TARGET="$BUILD_DIR/libzlibmojo.so"
SOURCE="$SCRIPT_DIR/zlib_wrapper.c"

if [ -z "${CONDA_PREFIX:-}" ]; then
    echo "CONDA_PREFIX not set — run via pixi." >&2
    exit 1
fi
INSTALLED="$CONDA_PREFIX/lib/libzlibmojo.so"

# Idempotency: skip if the shim is already current.
if [ -f "$TARGET" ] && [ -f "$INSTALLED" ] \
    && [ ! "$SOURCE" -nt "$TARGET" ] && [ ! "$TARGET" -nt "$INSTALLED" ]; then
    exit 0
fi

if [ ! -f "$CONDA_PREFIX/include/zlib.h" ]; then
    echo "zlib.h not found in $CONDA_PREFIX/include — run 'pixi install'." >&2
    exit 1
fi

mkdir -p "$BUILD_DIR"
CC="clang"; [ "$(uname)" = "Linux" ] && CC="gcc"

echo "building libzlibmojo.so..."
$CC -O2 -fPIC -shared -o "$TARGET" "$SOURCE" \
    -I"$CONDA_PREFIX/include" -L"$CONDA_PREFIX/lib" -lz \
    -Wl,-rpath,"$CONDA_PREFIX/lib"

mkdir -p "$CONDA_PREFIX/lib"
cp "$TARGET" "$INSTALLED"
echo "installed: $INSTALLED"
