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
# NOW BLOCKED by a different, new bug further into the build:
# `installPhase`'s `make install` succeeds (dyn-drvs 0d233d3 separately
# fixed the cmake+make `cmake_check_build_system`/`/build/source`
# install-time error too), but `fixupPhase` then fails:
#
#   find: '/nix/store/...-brotli-1.2.0-dev': No such file or directory
#
# Root cause: the generalized cmake+make out-of-tree restore path in
# `dyndrvRestoreOutput` (added by 0d233d3) copies content into `$out`
# only, never invoking `_multioutDevs`/`_multioutDocs` the way the
# original placeholder-restore branch does -- so this 3-output
# (`out`/`dev`/`lib`) package's `$dev`/`$lib` never get populated before
# `fixupPhase` runs and tries to iterate them.
#
# Not fixed here -- would mean patching dyn-drvs' phases.split itself,
# out of scope for this repo. No package-level workaround exists (the
# multi-output split happens entirely inside dyndrvRestoreOutput,
# nothing brotli's own recipe controls).

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
