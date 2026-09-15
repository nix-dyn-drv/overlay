# re2 -- PASS. cmake+ninja build (~51 real per-TU compile-unit
# derivations registered), Google's RE2 regex engine.
#
# Originally hit a bug reported as distinct from the four confirmed
# instances of the discoverTree cmake-source-path bug already documented
# at that point (xxHash/tinycbor@7.0/leveldb/brotli, all cmake+MAKE):
# 20 of ~51 real compile-unit derivations failed at the COMPILE step
# (not link), for real PRIMARY source files (not headers):
#
#   cc1plus: fatal error: <src>.cc: No such file or directory
#
# RETESTED and root-caused precisely, isolating each fix by pinning
# `dyndrv` at successive commits:
#
# 1. Against `97a987d` alone ("discoverTree: cmake's -MT/-MF values
#    misidentified as the source file") -- confirmed this WAS the exact
#    same bug: every real per-TU compile now succeeds (cmake+ninja was
#    never a distinguishing factor from the cmake+make instances; the
#    original survey's "distinct bug" classification was simply never
#    retested against this fix at the time). Then blocked by a
#    DIFFERENT, cmake+ninja-specific install-time bug:
#
#      CMake Error: The source directory "/build/source" does not
#      appear to contain CMakeLists.txt.
#      FAILED: [code=1] build.ninja /build/source/build/cmake_install.cmake ...
#      ninja: error: rebuilding 'build.ninja': subcommand failed
#
# 2. Against `0d233d3` ("Fix phases.split cmake+make out-of-tree install
#    failure (task #138)") -- confirmed this ALSO fixes the cmake+ninja
#    variant of the same install-time gap (that fix's own
#    `dyndrvCdToBuildDir` reconstruction generalizes to any build system
#    whose generated install step re-invokes a `--check-build-system`-
#    style regeneration against the absolute source directory baked in
#    at phase-1 configure time -- ninja's own `build.ninja: ... cmake
#    --regenerate-during-build` is the exact same shape as cmake+make's
#    `cmake_check_build_system`, just through a different generator).
#
# Confirmed PASS with both fixes in place (either commit alone leaves
# the second bug open) -- no package-level workaround needed. Real
# `libre2.so.11.0.0` verified as a genuine ELF shared object.

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
pkgs.re2.override { stdenv = acceleratedStdenv; }
