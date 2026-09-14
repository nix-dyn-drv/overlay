# openjpeg (cmake, 2-output ["out" "dev"], ~76 real lib TUs) -- BLOCKED.
# NEW dyn-drvs bug: `arToNode`/`ranlibToNode` never declare their own
# `.o`/archive positional inputs as `inputs.drvs`, so a real, sandboxed
# `ar`/link build of any static or shared library fails once those
# inputs are genuinely resolved dynamic derivations.
#
# nixpkgs' openjpeg recipe is otherwise unremarkable for this survey: a
# plain in-tree cmake build (no out-of-tree `cmakeDir`, no autotools
# depcomp, no `outputBin`/`outputMan` override -- none of the
# already-documented bugs in RESULTS.md apply here), buildInputs on
# libpng/libtiff/zlib/lcms2, `doCheck` gated off automatically in this
# environment (`ctest` never runs). Cold sandboxed build attempted via
# `./try-it-out/run-nix.sh build --impure --no-link --print-out-paths
# .#dyndrv-openjpeg`.
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
# 2. OPEN, ROOT-CAUSED (this survey's actual finding): once configure
#    succeeds, every real per-TU C compile also succeeds -- but the
#    FIRST `ar`-driven static-lib link fails:
#
#      ar: /nix/store/<hash>-thread.c.o: No such file or directory
#      ranlib: '/nix/store/<hash>-dyndrv-bin_libopenjp2_a': No such file
#
#    `nix derivation show` on the registered `ar` derivation
#    (`dyndrv-bin_libopenjp2_a.drv`) confirms `inputs.drvs` is an EMPTY
#    `{}`, and `inputs.srcs` contains only `binutils-2.46` -- none of
#    the 22 `.o` positional arguments `ar`'s own rendered command line
#    literally names (as resolved `/nix/store/<hash>-thread.c.o`-style
#    paths, each really a not-yet-realized OTHER dynamic derivation's
#    output) are wired as a build dependency at all. The identical gap
#    hits the SHARED-lib link too (`dyndrv-bin_libopenjp2_so_2_5_4.drv`,
#    a `cc -shared ... CMakeFiles/openjp2.dir/thread.c.o ...` invocation,
#    also `inputs.drvs = {}`).
#
#    Root cause: `arToNode`/`ranlibToNode` (`mkAcceleratedStdenv.nix`)
#    build their own deferred record's `srcs` list from ONLY
#    `stdenv.cc.bintools.bintools`'s own basename -- unlike `ccToNode`'s
#    parallel `extraStorePaths`/`findAllStorePaths` scan (which greps
#    every argv element AND every captured wrapper-env string for a
#    literal `${builtins.storeDir}/...` substring and folds each match's
#    basename into `srcsList`), neither `ar` nor `ranlib` shim has any
#    such scan over their own positional `.o`/archive arguments. Once
#    `collectStubs.nix`'s dependency-resolution pass rewrites a still-
#    pending `.o` reference into its now-REAL, already-registered store
#    path (a normal, expected step once that upstream compile has
#    itself resolved), the `ar` record's OWN `srcs` never grew to cover
#    that resolved path, so the outer wrapper never declares the needed
#    `inputs.drvs` edge, and `builder-rpc-v0`'s sandbox genuinely has no
#    access to a `.o` it never declared. This is DISTINCT from the
#    already-documented, already-fixed link-step bug (`discoverTree`'s
#    `-M -MG` scan finding nothing for a link invocation, LESSONS-
#    LEARNED.md #16) -- that fix only ever touched the `cc`/`c++` shims'
#    OWN `extraStorePaths` scan; `ar`/`ranlib` are a wholly separate
#    code path in `mkAcceleratedStdenv.nix` that was never given an
#    equivalent scan at all.
#
#    `benchmarks/RESULTS.md` marks this BLOCKED until dyn-drvs adds the
#    same `extraStorePaths`-style scan (or equivalent) to `arToNode`/
#    `ranlibToNode`'s own `srcs` computation, covering resolved store
#    paths appearing among their positional inputs the same way
#    `ccToNode` already does for `cc`/`c++`.

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
