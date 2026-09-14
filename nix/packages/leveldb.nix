# leveldb -- BLOCKED. cmake+make, ~39 real per-TU compile-unit derivations
# registered (db/*.cc, table/*.cc, util/*.cc, plus leveldbutil's own TU),
# LSM-tree engine, moderate-heavy per-file cost.
#
# Originally, every single one of those 39 real compiles failed
# identically with the discoverTree cmake-source-path bug:
#
#   cc1plus: fatal error: db/c.cc: No such file or directory
#
# a fourth confirmed instance of that bug (xxHash, re2, tinycbor@7.0,
# leveldb) -- notably leveldb's `CMakeLists.txt` lives at the repo root
# (no out-of-tree `build/cmake` subdir like xxHash), confirming
# "out-of-tree cmake dir" isn't a precondition. FIXED upstream in
# dyn-drvs 97a987d ("discoverTree: cmake's -MT/-MF values misidentified
# as the source file") -- confirmed directly: all 39 real per-TU
# compiles now succeed, plus `make install` (cmake+make's own
# `cmake_check_build_system`/`/build/source` install-time error,
# separately fixed by dyn-drvs 0d233d3, also doesn't recur).
#
# NOW BLOCKED by a different, already-documented bug: leveldb's own
# `postInstall` runs `substituteInPlace
# "$out"/lib/cmake/leveldb/leveldbTargets.cmake ...`, and fails:
#
#   substitute(): ERROR: file '.../leveldb-1.23/lib/cmake/leveldb/leveldbTargets.cmake' does not exist
#
# This is a second confirmation of
# ~/dyn-drvs/docs/split-postinstall-before-restore-bug.md (previously
# only confirmed via mosh's `wrapProgram $out/bin/mosh`): `postInstall`
# fires as part of nixpkgs' `installPhase` itself, strictly before
# `phases.split`'s synthesized `dyndrvRestoreOutput` phase (which copies
# the placeholder-rooted tree into the real `$out`) ever runs -- so any
# `postInstall` that reads/writes `$out` directly finds it still missing
# whatever `make install` wrote under the placeholder root.
#
# No package-level workaround exists for either bug's remaining
# blocker: the postInstall-ordering gap is a phases.split issue, not
# something leveldb's own recipe controls.

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
pkgs.leveldb.override { stdenv = acceleratedStdenv; }
