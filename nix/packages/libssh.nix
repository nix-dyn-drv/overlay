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
# That workaround exposed a SECOND, distinct, still-open bug: `fixupPhase`'s
# `postFixup` (nixpkgs' own libssh recipe: `substituteInPlace
# $dev/lib/cmake/libssh/libssh-config.cmake ...`) fails --
#
#   substitute(): ERROR: file '.../libssh-0.12.2-dev/lib/cmake/libssh/libssh-config.cmake' does not exist
#
# NOT the same bug as leveldb's `split-postinstall-before-restore-bug.md`
# (fixed by dyn-drvs 1347c8c): `dyndrvRestoreOutput` already runs BEFORE
# `fixupPhase` for this package (confirmed via the build log's own
# phase-order trace), so ordering isn't the issue here. `libssh`'s `$dev`
# output is never populated with `lib/cmake/libssh` content at all --
# `_multioutDevs`'s own `moveToOutput lib/cmake "${!outputDev}"` call
# (declared by nixpkgs' `multiple-outputs.sh`, invoked unconditionally by
# `dyndrvRestoreOutput`) produces no visible "Moving ..." log output,
# meaning it silently found nothing under `$out/lib/cmake` to move.
# Root cause not yet isolated (plausibly interacts with `dyndrvMoveFromOut`'s
# newer bin/lib/libexec restructuring from dyn-drvs e5f9a61, but not
# confirmed). Still BLOCKED even with the linker-script workaround
# applied -- no package-level workaround found for this second bug (the
# `$dev`/`lib/cmake` split happens entirely inside `dyndrvRestoreOutput`,
# nothing libssh's own recipe controls).

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
