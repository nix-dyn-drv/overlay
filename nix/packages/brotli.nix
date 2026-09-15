# brotli -- BLOCKED. cmake build (~38 real per-TU compile derivations
# registered: brotlicommon/brotlidec/brotlienc + the `brotli` CLI).
#
# Originally blocked by the discoverTree cmake-source-path bug (every
# real compile failing with `cc1: fatal error:
# /build/source/c/common/dictionary.c: No such file or directory`) --
# this was the fourth confirmed instance of that bug (xxHash, re2,
# tinycbor, brotli), and the first with the plainest possible cmake
# layout (in-tree, cmake+make, no custom target, no out-of-tree build
# dir), ruling out several previously-considered contributing factors.
# FIXED upstream in dyn-drvs 97a987d ("discoverTree: cmake's -MT/-MF
# values misidentified as the source file") -- confirmed directly: all
# three per-TU shared-lib derivations (libbrotlicommon/libbrotlienc/
# libbrotlidec) now compile and link cleanly.
#
# THEN blocked by a different bug further into the build:
# `installPhase`'s `make install` succeeds (dyn-drvs 0d233d3 separately
# fixed the cmake+make `cmake_check_build_system`/`/build/source`
# install-time error too), but `fixupPhase` then fails:
#
#   find: '/nix/store/...-brotli-1.2.0-dev': No such file or directory
#
# Confirmed still open against the latest pushed dyn-drvs commit
# (5468402 -- includes 1347c8c's postInstall-before-restore fix and
# e5f9a61's multi-output bin/lib/etc redistribution fix, neither of
# which resolve this).
#
# Root-caused more precisely than previously documented, by direct
# inspection of the real build tree (not just the error message):
# brotli's own `make install` genuinely runs and reports installing
# real files (`-- Installing: .../lib/libbrotlienc.so...`), and those
# files DO exist for real -- but flat at `$out`'s top level
# (`$out/libbrotlicommon.pc`, `$out/libbrotlienc.so...`), not under
# `$out/lib/`, `$out/include/`, etc as cmake's own `install()` rules
# specify. `CMakeCache.txt`'s `CMAKE_INSTALL_LIBDIR`/
# `CMAKE_INSTALL_PREFIX` entries point at a DIFFERENT derivation output
# path (the phase-1 baked-in placeholder, e.g.
# `/nix/store/<hash>-brotli-1.2.0.drv/lib`) than the real, final `$out`
# this build actually resolves to -- `dyndrvRestoreOutput`'s generic
# tree-hoist/copy logic flattens that mismatched nested structure into
# `$out`'s root instead of preserving the `lib/`/`include/`
# subdirectories cmake's install rules wrote them under. Since the
# content never lands anywhere `_multioutDevs`/`dyndrvMoveFromOut`
# scan for (`lib/cmake`, `lib`, `include`, etc, all relative to `$out`
# directly), neither redistributes anything into `$dev`/`$lib`, so both
# stay empty and `fixupPhase`'s generic per-output iteration fails
# outright on the first one it touches.
#
# This is DISTINCT from (and deeper than) the "single-output phase 1
# loses outputLib content" bug documented for x264 (fixed there by
# dyn-drvs e5f9a61) -- x264's content landed under the CORRECT
# `$out/lib/` subdirectory, just in the wrong OUTPUT; brotli's content
# doesn't even preserve its subdirectory structure during restore. Same
# general shape independently confirmed on libssh (`$dev`/`lib/cmake`
# also never populated there, likewise still unresolved).
#
# No package-level workaround found: `BUILD_SHARED_LIBS`/`staticOnly`/
# `BROTLI_BUILD_FOR_PACKAGE` don't change brotli's output declaration
# or avoid this restore-path mismatch -- the flattening happens entirely
# inside `dyndrvRestoreOutput`, nothing brotli's own cmake recipe
# controls.

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
pkgs.brotli.override { stdenv = acceleratedStdenv; }
