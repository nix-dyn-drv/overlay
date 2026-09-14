# protobuf -- BLOCKED. cmake, ~221 TUs across the runtime library +
# protoc + the `gtest`/`abseil-cpp`-backed test suite. Flagged ahead of
# time as the riskiest survey candidate so far: heaviest cmake build
# attempted in this repo, real cross-package build deps (gtest, zlib,
# abseil-cpp pulled in via `-Dprotobuf_ABSL_PROVIDER:STRING=package`),
# multi-component build (library + `protoc` + tests). Tried anyway per
# explicit instruction; hits a real, already-known dyn-drvs bug, but at
# a scale/consequence this repo hadn't exercised before.
#
# 1. Same root cause as the already-documented discoverTree exec-bit bug
#    (libb64, see ~/dyn-drvs/docs/discovertree-exec-bit-bug.md -- a
#    freshly `cc`/`c++`-linked executable comes out of the sandbox
#    missing its execute bit). protobuf's own CMake build runs its own
#    just-linked `protoc` binary directly (`./protoc`, no shell/loader
#    indirection) as a *code generator* mid-build, immediately after
#    linking it, to turn every `.proto` file in the tree (descriptor.proto,
#    any.proto, api.proto, edition_unittest.proto, hundreds of test
#    .proto files, etc.) into its corresponding `.pb.h`/`.upb.h`/
#    `.upbdefs.h`/`.upb_minitable.h`. Every one of those generation steps
#    fails identically:
#
#      /nix/store/.../bash: line 1: ./protoc: Permission denied
#      make[2]: *** [CMakeFiles/upb-test.dir/build.make:1165: upb/wire/encode_test.upbdefs.h] Error 126
#
#    (repeated for descriptor/api/any/edition_unittest/
#    map_proto2_unittest/map_proto3_unittest/test_bad_identifiers_*/
#    test_large_enum_value/internal_metadata_locator_test and more --
#    dozens of distinct `.proto` targets, all Error 126, all "Permission
#    denied" on the same `./protoc`), which cascades into
#    `CMakeFiles/upb-test.dir/all`/`CMakeFiles/libtest_common.dir/all`
#    failing and the whole `make` aborting with `Error 2`. Reproduced
#    directly against this repo's real nixpkgs pin (protobuf 36.1) and
#    the latest pushed dyn-drvs commit (1e9610f) as of 2026-09-14 --
#    still fails identically after the giflib compile-and-link-in-one-
#    step regression fix (26cf7b9), confirming this is a distinct,
#    still-open bug, not a symptom of that already-fixed one.
#
# 2. Where libb64 only lost a `make check`-style self-test (a real but
#    contained failure -- the *library* itself had already built), this
#    is a full BLOCKED: protobuf's own runtime library and its test
#    suite both depend on `protoc`'s generated headers to compile at
#    all, so the missing exec bit takes down the whole build, not just
#    an optional check step. This is the clearest evidence yet that the
#    exec-bit bug isn't a narrow libb64 quirk -- it reproduces exactly
#    the same way on an entirely different, much larger, cmake-based
#    (not Makefile-based) codebase, and any package whose own build
#    process re-executes a binary it just linked (a common code-generator
#    pattern: protoc, flatc, and similar) will hit it identically.
#
# 3. No package-level workaround attempted or possible here: the fix has
#    to restore the execute bit dyn-drvs' own discoverTree link-output
#    staging drops, which is a dyn-drvs-internal fix (see libb64's own
#    doc), not something `protobuf.override`/`postPatch` can route
#    around from this repo.
#
# Current status: BLOCKED, confirming and substantially raising the
# stakes on the known discoverTree exec-bit bug (previously only seen on
# libb64's small self-test). See benchmarks/RESULTS.md.

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
pkgs.protobuf.override { stdenv = acceleratedStdenv; }
