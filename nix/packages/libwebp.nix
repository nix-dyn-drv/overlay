# libwebp -- PASS. Single-output (`out`), cmake-based, ~171 TUs -- picked
# specifically to avoid the multi-output gaps hit elsewhere (openssl's
# `finalPackage`, libpng/libtasn1's `outputBin`).
#
# Originally hit the discoverTree cmake-source-path bug already tracked
# in ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md (xxHash, re2,
# tinycbor): every real per-TU compile failed identically with
#
#   cc1: fatal error: /build/source/examples/dwebp.c: No such file or directory
#
# FIXED upstream in dyn-drvs 97a987d ("discoverTree: cmake's -MT/-MF
# values misidentified as the source file") -- confirmed directly: every
# per-TU compile across every one of libwebp's cmake targets now
# succeeds (no more "No such file or directory" for any TU).
#
# THEN blocked by a second, distinct bug at the archive step: `ar: /nix/
# store/<hash>-example_util.c.o: No such file or directory` /
# `ranlib: '/nix/store/<hash>-dyndrv-libexampleutil_a': No such file`
# (also reproduced against a different object on a second run,
# `image_dec.c.o`). `nix derivation show` on the failing `.drv` confirmed
# `inputs.drvs = {}` -- `ar`'s own positional `.o` inputs were never
# scanned for resolved store paths the way `ccToNode`'s `extraStorePaths`
# already did. FIXED upstream in dyn-drvs 28af81d ("Fix ar shim: declare
# its own real .o/archive inputs as derivation deps") -- confirmed
# directly: all `ar`/`ranlib` archive steps now succeed for real.
#
# THEN blocked by a third, distinct bug at a `cc -shared` link step:
# `ld.bfd: cannot open dependency file CMakeFiles/webpdecoder.dir/
# link.d: No such file or directory` -- wrapCommand's output-dirname
# precreation logic didn't unglue `-Wl,`-style flags before scanning
# argv for an output directory to precreate, so a linker dependency-file
# path glued onto a `-Wl,` flag never got its containing directory made.
# FIXED upstream in dyn-drvs dc07a0a ("Fix wrapCommand's output-dirname
# precreation: unglue -Wl,-style flags first (task #142)") -- confirmed
# directly: `dyndrv-libwebp` now builds clean end to end, real
# `libwebp.so.7.2.0`/`bin/cwebp`/`bin/dwebp` etc all verified as genuine
# ELF binaries.
#
# Left the full bug history here (not deleted) since this package
# exercised three DISTINCT, sequentially-uncovered dyn-drvs bugs on the
# way to a real pass -- each fix exposed the next real bug rather than
# recurring, which is itself informative about how deep this mechanism's
# rough edges go on an ordinary cmake C project.

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
pkgs.libwebp.override { stdenv = acceleratedStdenv; }
