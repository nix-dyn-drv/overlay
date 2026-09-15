# libssh -- PASS. cmake build (~110+ TUs: SSH client library over
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
# THEN blocked by a different bug at the final `.so` link step:
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
# different file type. Confirmed unaffected by dyn-drvs 227b1a6,
# 0d233d3, dc07a0a, 1347c8c, and 5468402 -- none of these touch this
# code path.
#
# WORKED AROUND at the package level: libssh's own CMakeLists.txt gates
# the whole version-script code path behind `WITH_SYMBOL_VERSIONING`
# (default ON on Unix). Passing `-DWITH_SYMBOL_VERSIONING=OFF` disables
# it outright -- this avoids the bug entirely rather than fixing it, but
# it's a real, upstream-supported libssh cmake flag, not a patch to
# libssh's own source. Confirmed: with this flag, every real per-TU
# compile, the `ar`/`ranlib` archive step, and the final `.so` link all
# succeed, producing a genuine `libssh.so.4.12.0`.
#
# That workaround exposed a SECOND, distinct bug (since fixed): `fixupPhase`'s
# `postFixup` (nixpkgs' own libssh recipe: `substituteInPlace
# $dev/lib/cmake/libssh/libssh-config.cmake ...`) failed --
#
#   substitute(): ERROR: file '.../libssh-0.12.2-dev/lib/cmake/libssh/libssh-config.cmake' does not exist
#
# NOT the same bug as leveldb's `split-postinstall-before-restore-bug.md`
# (fixed by dyn-drvs 1347c8c): `dyndrvRestoreOutput` already ran BEFORE
# `fixupPhase` for this package, so ordering wasn't the issue. This
# turned out to be the SAME class of gap task #139's `dyndrvMoveFromOut`
# fix (dyn-drvs e5f9a61) addressed for `bin`/`lib` content, generalized
# by that same fix to `lib/cmake` once retested against a dyndrv pin
# that included it -- confirmed the file now EXISTS in `$dev`.
#
# That exposed a THIRD, distinct bug (also now fixed): the file existed,
# but `substituteInPlace` still failed --
#
#   substitute(): ERROR: pattern set\(_IMPORT_PREFIX\ \"/nix/store/<hash>-libssh-0.12.2\"\) doesn't match anything in file '.../libssh-config.cmake'
#
# cmake's own `install(EXPORT libssh-config ...)` bakes phase 1's
# LITERAL placeholder path (`/build/dyndrv-placeholder-out`) into the
# generated file's `_IMPORT_PREFIX` at configure time -- since phase 1
# forces a single output, every `CMAKE_INSTALL_*DIR` cmake sees is an
# absolute path under that ONE placeholder root, which tips cmake into
# emitting a literal `set(_IMPORT_PREFIX "...")` (confirmed via direct
# `nix log` inspection: the baked string was the exact placeholder, not
# `$out` or a relative `get_filename_component` computation). Nixpkgs'
# own `postFixup` naturally expects to find the REAL `$out`'s literal
# path there (since that's what an ordinary, unaccelerated build's own
# `install(EXPORT)` would have baked in), not the placeholder --
# `dyndrvCopyPlaceholderScript` copied the file's content byte-for-byte
# but never rewrote this embedded string. FIXED upstream in dyn-drvs
# bb1c077 ("Fix phases.split: rewrite placeholder path baked into
# copied file content (task #145)") -- a generic `grep -rl`/`sed -i`
# pass over every text file under `$out` after the placeholder copy,
# rewriting any surviving reference to the placeholder path to the real
# `$out`.
#
# RETESTED against dyn-drvs bb1c077 (includes 97a987d, e5f9a61, and this
# session's own `_IMPORT_PREFIX` fix): `dyndrv-libssh` now builds clean
# end to end -- real `libssh.so.4.12.0` verified as a genuine ELF shared
# object, and `$dev/lib/cmake/libssh/libssh-config.cmake`'s own
# `_IMPORT_PREFIX` now correctly reads the real `$dev` store path.

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
(pkgs.libssh.override { stdenv = acceleratedStdenv; }).overrideAttrs (old: {
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DWITH_SYMBOL_VERSIONING=OFF" ];
})
