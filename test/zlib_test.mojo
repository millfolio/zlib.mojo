"""Round-trip gate: deflate(x) then inflate -> x, byte-for-byte."""

from zlib import deflate, inflate


def _bytes(s: String) -> List[UInt8]:
    var out = List[UInt8]()
    var p = s.unsafe_ptr()
    for i in range(s.byte_length()):
        out.append(p[i])
    return out^


def main() raises:
    var msg = String("")
    for _ in range(64):
        msg += "Hello, zlib from Mojo! FlateDecode is just RFC-1950 zlib.\n"
    var src = _bytes(msg)

    var comp = deflate(src)
    var back = inflate(comp)

    if len(back) != len(src):
        raise Error(
            "length mismatch: " + String(len(back)) + " != " + String(len(src))
        )
    for i in range(len(src)):
        if back[i] != src[i]:
            raise Error("byte mismatch at index " + String(i))

    print(
        "zlib round-trip OK: ",
        len(src),
        " bytes -> ",
        len(comp),
        " compressed -> ",
        len(back),
        " back",
        sep="",
    )
