# brotli -- PASS. cmake build (~38 real per-TU compile derivations
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
# Confirmed still open against dyn-drvs 5468402 (includes 1347c8c's
# postInstall-before-restore fix and e5f9a61's multi-output bin/lib/etc
# redistribution fix, neither of which resolved this).
#
# ROOT CAUSE (turned out deeper than the surface symptom suggested):
# nixpkgs' real brotli recipe sets `__structuredAttrs = true;`. Under
# `structuredAttrs`, Nix's own builder generates the sandboxed shell's
# env vars FROM the derivation's real, computed CA output path (via
# `NIX_ATTRS_SH_FILE`, sourced before `stdenv/setup` even runs) --
# completely IGNORING `phases.split`'s own `out = dyndrvPlaceholderOut`
# attribute override on `sandboxedDrv`. So phase 1's `cmake`/`make
# install` never wrote to the placeholder at all -- every `-- Installing:
# ...` log line showed the REAL computed store path directly, meaning
# NOTHING ever went through this file's own "install into a fake path
# now, copy into the real `$out` later" mechanism. The flat top-level
# layout (`$out/libbrotlicommon.pc` instead of `$out/lib/...`) that was
# previously blamed on a `dyndrvRestoreOutput` tree-flattening bug was
# actually just `dyndrvCopyPlaceholderScript` finding NOTHING under
# `dyndrvPlaceholderOut` to copy at all (since nothing was ever written
# there), leaving whatever partial/stale content happened to already
# exist at `$out`'s root from an earlier stage.
#
# FIXED upstream in dyn-drvs 2cb6b4d ("Fix phases.split: force
# __structuredAttrs = false on sandboxedDrv (task #143)") -- forces this
# off on phase 1's own synthetic derivation regardless of what the
# caller's `sandboxed` attrset sets, the same way `outputs`/
# `separateDebugInfo` are already forced there. Confirmed directly:
# `dyndrv-brotli` now builds clean end to end -- real
# `libbrotlicommon.so.1.2.0`/`libbrotlienc.so.1.2.0`/
# `libbrotlidec.so.1.2.0` (all three verified as genuine ELF shared
# objects) correctly land under `$lib/lib/`, headers under `$dev/
# include/`, and `bin/brotli` under `$out/bin/`, no package-level
# workaround needed at all.

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
