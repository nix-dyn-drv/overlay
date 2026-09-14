# libssh -- BLOCKED. cmake build (~110+ TUs: SSH client library over
# openssl/zlib/libsodium; `out`+`dev` outputs).
#
# Originally hit the discoverTree cmake-source-path bug already
# documented for xxHash/re2/tinycbor: every real TU compile failed
# identically --
#
#   cc1: fatal error: /build/libssh-0.12.2/src/agent.c: No such file or directory
#
# a fifth confirmed instance of that bug. FIXED upstream in dyn-drvs
# 97a987d ("discoverTree: cmake's -MT/-MF values misidentified as the
# source file") -- confirmed directly: all ~70 real per-TU compile
# derivations (agent.c.o, auth.c.o, etc.) now succeed.
#
# NOW BLOCKED by a different, new bug at the final `.so` link step:
#
#   ld.bfd: cannot open linker script file /build/libssh-0.12.2/src/libssh.map: No such file or directory
#   collect2: error: ld returned 1 exit status
#
# The link derivation (`dyndrv-lib_libssh_so_4_12_0.drv`) invokes
# `-Wl,--version-script,/build/libssh-0.12.2/src/libssh.map` -- an
# absolute-path auxiliary file (a linker version-script, not a compile
# TU source) that is never staged into the per-derivation build tree.
# Same root bug class as the now-fixed cmake-source-path bug
# (`discoverTree` failing to resolve/stage a file referenced by an
# absolute in-sandbox path), but manifesting at the link stage on a
# different file type. Confirmed twice (independently reproduced against
# both dyn-drvs 227b1a6 and 0d233d3 -- neither fix touches this code
# path). No package-level workaround exists (the linker script is
# libssh's own upstream `src/libssh.map`, referenced by libssh's own
# CMakeLists.txt; not something `cmakeFlags`/`postPatch` can route
# around, since the bug is in how `discoverTree` stages absolute-path
# auxiliary link inputs, not in libssh's own build description).

{
  pkgs,
  dyndrv,
  nixPackage ? pkgs.nix,
  dyndrvShim ? null,
}:

let
  acceleratedStdenv = dyndrv.accelerate.mkAcceleratedStdenv {
    stdenv = pkgs.stdenv;
    inherit nixPackage dyndrvShim;
  };
in
pkgs.libssh.override { stdenv = acceleratedStdenv; }
