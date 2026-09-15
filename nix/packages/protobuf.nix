# protobuf -- PASS (with 2 package-level workarounds). cmake, ~221 TUs
# across the runtime library + protoc + the `gtest`/`abseil-cpp`-backed
# test suite. Flagged ahead of time as the riskiest survey candidate so
# far: heaviest cmake build attempted in this repo, real cross-package
# build deps (gtest, zlib, abseil-cpp pulled in via
# `-Dprotobuf_ABSL_PROVIDER:STRING=package`), multi-component build
# (library + `protoc` + tests). Tried anyway per explicit instruction;
# hit two real, distinct dyn-drvs bugs, both worked around.
#
# 1. Same root cause as the already-documented discoverTree exec-bit bug
#    (libb64, see ~/dyn-drvs/docs/discovertree-exec-bit-bug.md, later
#    root-caused in dyn-drvs 5468402 as a permanent architectural
#    limitation, not a fixable bug -- a freshly `cc`/`c++`-linked
#    executable is a still-unresolved `#!dyndrv-batch-pending` stub
#    until `collectStubs`'s whole-build-tree pass runs at the very end
#    of `buildPhase`; any package that self-execs a binary it just
#    linked, in that SAME buildPhase invocation, hits exit 126). Here it
#    was protobuf's own CMake build re-executing its just-linked
#    `protoc` binary directly (`./protoc`, no shell/loader indirection)
#    as a code generator, mid-build, for hundreds of `.proto` files in
#    its OWN test suite (`upb-test`'s `descriptor.proto`/`any.proto`/
#    `edition_unittest.proto`/etc, all under
#    `-Dprotobuf_BUILD_TESTS:BOOL=TRUE`, nixpkgs' own forced default):
#
#      /nix/store/.../bash: line 1: ./protoc: Permission denied
#      make[2]: *** [CMakeFiles/upb-test.dir/build.make:1165: upb/wire/encode_test.upbdefs.h] Error 126
#
#    WORKED AROUND: `-Dprotobuf_BUILD_TESTS:BOOL=FALSE` skips
#    `cmake/tests.cmake` (and the whole `upb-test`/self-exec-during-
#    build code path) entirely -- a real, upstream-supported cmake
#    option, gated behind `if (protobuf_BUILD_TESTS) ... include(
#    ${protobuf_SOURCE_DIR}/cmake/tests.cmake) ... endif()` in
#    protobuf's own root `CMakeLists.txt`, not a patch to protobuf's
#    source. `doCheck` is already disabled in this survey's environment
#    (`ctest` never runs anyway), so this loses nothing this repo was
#    already exercising.
#
# 2. With the exec-bit bug avoided, the build hits libssh's exact
#    linker-script staging bug next: `libprotobuf`/`libprotobuf-lite`/
#    `libprotoc` each link with `-Wl,--version-script=.../libprotobuf.map`
#    (an absolute-path linker version-script `discoverTree` never
#    stages) --
#
#      ld.bfd: cannot open linker script file /build/source/src/libprotobuf.map: No such file or directory
#
#    WORKED AROUND: unlike libssh (a real `WITH_SYMBOL_VERSIONING` cmake
#    *option*), protobuf's own root `CMakeLists.txt` computes this via
#    `check_linker_flag(CXX -Wl,--version-script=... protobuf_HAVE_LD_VERSION_SCRIPT)`
#    -- a CMake `check_*`-module compile-time PROBE, not a plain option,
#    but CMake's `check_*` modules cache their result and skip
#    re-probing if the same-named CACHE variable is already defined --
#    confirmed passing `-Dprotobuf_HAVE_LD_VERSION_SCRIPT:BOOL=FALSE` on
#    the command line pre-seeds that cache entry and the probe is
#    skipped, so every `target_link_options(... -Wl,--version-script=...)`
#    call (gated on the same variable in `cmake/libprotobuf.cmake`/
#    `libprotobuf-lite.cmake`/`libprotoc.cmake`) never fires.
#
# Confirmed with BOTH workarounds together: `dyndrv-protobuf` builds
# clean end to end -- real `libprotobuf.so.36.1.0`/`libprotoc.so.36.1.0`/
# `protoc` all verified as genuine ELF binaries (not stubs). Real,
# working `protoc` confirms the exec-bit bug is genuinely avoided, not
# just hidden. `benchmarks/RESULTS.md` updated from BLOCKED to PASS.

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
(pkgs.protobuf.override { stdenv = acceleratedStdenv; }).overrideAttrs (old: {
  cmakeFlags = (builtins.filter (
    f: !(pkgs.lib.hasInfix "protobuf_BUILD_TESTS" f)
  ) (old.cmakeFlags or [ ])) ++ [
    "-Dprotobuf_BUILD_TESTS:BOOL=FALSE"
    "-Dprotobuf_HAVE_LD_VERSION_SCRIPT:BOOL=FALSE"
  ];
})
