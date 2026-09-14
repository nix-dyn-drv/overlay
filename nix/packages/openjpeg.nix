# openjpeg (cmake, 2-output ["out" "dev"], ~76 real lib TUs) -- PASS.
# Was BLOCKED by a real dyn-drvs bug (`arToNode`/`ranlibToNode` never
# declaring their own `.o`/archive positional inputs as `inputs.drvs`),
# fixed upstream in dyn-drvs 28af81d -- confirmed directly, see below.
#
# nixpkgs' openjpeg recipe is otherwise unremarkable for this survey: a
# plain in-tree cmake build (no out-of-tree `cmakeDir`, no autotools
# depcomp, no `outputBin`/`outputMan` override -- none of the
# already-documented bugs in RESULTS.md apply here), buildInputs on
# libpng/libtiff/zlib/lcms2, `doCheck` gated off automatically in this
# environment (`ctest` never runs).
#
# 1. cmake's own configure-time probes (`CheckTypeSize`/`TestBigEndian`/
#    `CheckIncludeFile`, all funneling through `try_compile`) initially
#    failed outright: `CMake Error ... TestBigEndian.cmake:127 (message):
#    no suitable type found` -- every `CMAKE_SIZEOF_UNSIGNED_{SHORT,INT,
#    LONG}` probe got wrongly deferred into a batch-pending stub instead
#    of passing through synchronously, so its own `.bin` result file
#    never contained real content. Root-caused as ALREADY FIXED upstream
#    at the time of this survey (a stale flake.lock pin was the actual
#    cause here, not a live bug) -- `nix flake update dyndrv` alone
#    resolved it and configure now completes cleanly. Verified via a
#    plain, unaccelerated `pkgs.openjpeg` build against the identical
#    patched-nix/store setup succeeding throughout, isolating the issue
#    to the accelerated stdenv specifically, not the sandbox/environment.
#
# 2. FIXED (this survey's original finding): once configure succeeds,
#    every real per-TU C compile also succeeded -- but the FIRST
#    `ar`-driven static-lib link failed:
#
#      ar: /nix/store/<hash>-thread.c.o: No such file or directory
#      ranlib: '/nix/store/<hash>-dyndrv-bin_libopenjp2_a': No such file
#
#    `nix derivation show` on the registered `ar` derivation
#    (`dyndrv-bin_libopenjp2_a.drv`) confirmed `inputs.drvs` was an EMPTY
#    `{}`, and `inputs.srcs` contained only `binutils-2.46` -- none of
#    the 22 `.o` positional arguments `ar`'s own rendered command line
#    literally named (as resolved `/nix/store/<hash>-thread.c.o`-style
#    paths, each really a not-yet-realized OTHER dynamic derivation's
#    output) were wired as a build dependency at all. The identical gap
#    hit the SHARED-lib link too (`dyndrv-bin_libopenjp2_so_2_5_4.drv`,
#    a `cc -shared ... CMakeFiles/openjp2.dir/thread.c.o ...` invocation,
#    also `inputs.drvs = {}`).
#
#    Root cause: `arToNode`/`ranlibToNode` (`mkAcceleratedStdenv.nix`)
#    built their own deferred record's `srcs` list from ONLY
#    `stdenv.cc.bintools.bintools`'s own basename -- unlike `ccToNode`'s
#    parallel `extraStorePaths`/`findAllStorePaths` scan (which greps
#    every argv element AND every captured wrapper-env string for a
#    literal `${builtins.storeDir}/...` substring and folds each match's
#    basename into `srcsList`), neither `ar` nor `ranlib` shim had any
#    such scan over their own positional `.o`/archive arguments.
#
# FIXED upstream in dyn-drvs 28af81d ("Fix ar shim: declare its own real
# .o/archive inputs as derivation deps", task #141) -- confirmed
# directly: real `libopenjp2.so`/`bin/opj_decompress`/`bin/opj_compress`
# etc all build and are genuine ELF binaries. `benchmarks/RESULTS.md`
# updated from BLOCKED to PASS.

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
pkgs.openjpeg.override { stdenv = acceleratedStdenv; }
