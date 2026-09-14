# capnproto (cmake+make, ~187 .c++ TUs across kj/capnp, template-heavy
# C++20 coroutine code). BLOCKED: every real per-TU compile AND every
# real link succeeds (confirmed: `buildPhase completed in 39 seconds`,
# every one of `libkj.so`/`libcapnp.so`/`libcapnp-rpc.so`/`capnp`/etc
# actually built, via real dynamic derivations), but the accelerated
# build fails in `installPhase`, in phase 2 (`dyndrv.phases.split`'s
# ordinary-derivation replay stage) -- a NEW dyn-drvs bug, distinct from
# the already-documented `discovertree-cmake-source-path-bug.md`
# (that one is a COMPILE-time failure on out-of-tree cmake layouts
# xxHash/re2/tinycbor hit; this one is an INSTALL-time failure that
# happens even though every compile/link already succeeded).
#
# 1. Not a plain `.override { stdenv = ... }` package: nixpkgs' by-name
#    `capnproto` recipe (`pkgs/by-name/ca/capnproto/package.nix`) is
#    written against `clangStdenv.mkDerivation` directly, not
#    `stdenv.mkDerivation` -- its function signature takes a
#    `clangStdenv` argument, not `stdenv` (confirmed:
#    `pkgs.capnproto.override { stdenv = ...; }` fails at eval time with
#    "function 'anonymous lambda' called with unexpected argument
#    'stdenv'"). Intentional upstream, not an accident: the package's own
#    header comment cites
#    https://gcc.gnu.org/bugzilla/show_bug.cgi?id=102051 -- GCC is known
#    to miscompile/ICE on capnproto's C++20 coroutine code, so the
#    package pins clang specifically. Worked around at the PACKAGE level
#    here (not a dyn-drvs change): `mkAcceleratedStdenv` itself is
#    compiler-agnostic (derives its real-compiler paths from `stdenv.cc`,
#    whatever that resolves to), so this file accelerates `clangStdenv`
#    and overrides the `clangStdenv` argument name capnproto's recipe
#    actually reads, instead of `stdenv`.
#
# 2. BLOCKED, root-caused, NOT package-fixable: `installPhase` fails with
#      CMake Error: The source directory "/build/source" does not exist.
#      make: *** [Makefile:383: cmake_check_build_system] Error 1
#    Root cause: cmake's own generated `Makefile`'s `cmake_check_build_
#    system` target re-invokes `cmake --check-build-system` against the
#    ABSOLUTE source directory it was originally configured with
#    (`CMAKE_HOME_DIRECTORY`, baked into `CMakeCache.txt` during phase
#    1's own `configurePhase`) -- confirmed directly in phase 1's own
#    log: `-- Build files have been written to: /build/source/build`,
#    i.e. `/build/source` is the exact absolute path cmake cached.
#    `dyndrv.phases.split`'s phase 2 (`nix/lib/phases/split.nix`)
#    unconditionally forces `sourceRoot = "."`, so phase 2's own
#    `unpackPhase` copies phase 1's resolved tree flat into `/build`
#    itself, never recreating a `/build/source` subdirectory at all --
#    that exact same file's `dyndrvCdToBuildDir` phase DOES reconstruct
#    an equivalent absolute nesting, but ONLY when it finds a
#    `.dyndrv-build-relpath` marker, which `shim/collectStubs.nix` only
#    ever writes when it detects a `build.ninja` (meson's own
#    out-of-tree marker) -- a cmake+make build has no `build.ninja` at
#    all, so that whole reconstruction path is silently skipped, and
#    `make install` (which reads the already-generated `Makefile`
#    unmodified, exactly like the analogous `$out`-placeholder restore
#    problem this same file documents for autotools) immediately fails
#    the `cmake_check_build_system` bootstrap step before `install:`'s
#    own targets ever run. No `cmakeFlags`/`postPatch`/`dontUseCmake
#    BuildDir` knob avoids this -- the missing absolute directory is
#    `CMAKE_HOME_DIRECTORY` (the ORIGINAL, non-relocatable source root
#    cmake bootstraps from), not the separate build subdirectory
#    `cmakeBuildDir`/`dontUseCmakeBuildDir` control. Real fix belongs in
#    `phases/split.nix`'s `dyndrvCdToBuildDir`: generalize the existing
#    meson-only "reconstruct phase 1's absolute build-dir position"
#    logic to also trigger for a cmake+make build (e.g. detect
#    `CMakeCache.txt`/`Makefile.cmake` the same way `.dyndrv-build-
#    relpath` detects `build.ninja`, and recreate the `source/` (or
#    whatever `sourceRoot` phase 1 actually used) parent directory phase
#    1's own `CMAKE_HOME_DIRECTORY` still points at).
#
# nixpkgs' capnproto is single-output (`outputs = [ "out" "debug" ]`;
# `separateDebugInfo` is on, no separate `bin`/`lib`/`dev` split the way
# some other multi-output cmake packages do) -- irrelevant to the
# failure above, which never reaches multi-output redistribution at all.

{
  pkgs,
  dyndrv,
  nixPackage ? pkgs.nix,
  dyndrvShim ? null,
}:

let
  acceleratedClangStdenv = dyndrv.accelerate.mkAcceleratedStdenv {
    stdenv = pkgs.clangStdenv;
    inherit nixPackage dyndrvShim;
  };
in
pkgs.capnproto.override { clangStdenv = acceleratedClangStdenv; }
