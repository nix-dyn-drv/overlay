# libwebp -- BLOCKED. Single-output (`out`), cmake-based, ~171 TUs -- picked
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
# NOW BLOCKED by a different, new bug, at the archive step: `ar: /nix/
# store/<hash>-example_util.c.o: No such file or directory` /
# `ranlib: '/nix/store/<hash>-dyndrv-libexampleutil_a': No such file`
# (also reproduced against a different object on a second run,
# `image_dec.c.o`). `nix derivation show` on the failing `.drv` confirms
# `inputs.drvs = {}` -- the compiled `.o`'s producing derivation is never
# wired as a real build dependency, only referenced as a literal
# store-path string in `args`, so Nix schedules/builds the `ar` step
# before (or without ever building) its object-file dependency. This
# looks like a cross-unit dependency-wiring gap in
# `nix/lib/shim/collectStubs.nix` (the generic dependency-discovery/
# unit-merging pass), distinct from both the now-fixed cmake-source-path
# bug and the separately-fixed ar/ranlib probe-crash bug (227b1a6) --
# this is a real static-lib link with real inputs, not a version probe.
#
# Not package-fixable at this layer (the dependency-wiring gap is in how
# collectStubs resolves `ar`'s own positional `.o` inputs into real
# `inputs.drvs`, not something libwebp's own cmake project controls).
# Left here (not deleted) as real forward progress from the original
# cmake-source-path bug, now confirmed a fourth instance of THIS
# different ar/ranlib dependency-wiring bug (also seen on x265,
# openjpeg).

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
