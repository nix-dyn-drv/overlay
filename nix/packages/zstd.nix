# zstd built with dyn-drvs' `accelerate.mkAcceleratedStdenv` (cmake, unlike
# freetype's autotools). Two build-breaking bugs found and fixed below.
# The original link-step bug (empty inputs.drvs on a cc-driven link) is
# now fixed upstream (dyn-drvs commit 26cf7b9); zstd still hits a
# different, still-open cmake-source-path bug (see below).
#
# 1. gen_html mid-build self-exec. `build/cmake/contrib/CMakeLists.txt`
#    unconditionally `add_subdirectory(gen_html)`; its
#    `add_custom_target(... DEPENDS gen_html)` compiles a helper and execs it
#    synchronously inside the same cmake build. A `builder-rpc-v0` sandbox
#    can't resolve another dynamic derivation's output mid-build, so
#    `./gen_html` fails "Permission denied" (an unresolved placeholder
#    stub). No cmakeFlags knob avoids this -- `BUILD_CONTRIB` only gates
#    `contrib/pzstd`. Fix: build `gen_html` as an ordinary (non-accelerated)
#    derivation first, then patch
#    `build/cmake/contrib/gen_html/CMakeLists.txt` to drop the
#    `add_executable`/`DEPENDS` self-build edge and point `GENHTML_BINARY`
#    at the prebuilt path.
#
# 2. `-Qunused-arguments` false positive. zstd's
#    `build/cmake/CMakeModules/AddZstdCompilationFlags.cmake` probes for
#    this Clang-only flag via `check_c_compiler_flag`/
#    `check_cxx_compiler_flag`. `mkAcceleratedStdenv`'s passthrough
#    detection recognizes autoconf's `conftest`-named probes but not
#    CMake's `CMakeFiles/<check-name>/CheckCCompilerFlag/...` naming, so the
#    probe gets deferred, and a deferred stub always exits 0. CMake
#    concludes gcc supports the flag, bakes it into
#    `CMAKE_C_FLAGS`/`CMAKE_CXX_FLAGS`, and every real compile then fails
#    with "unrecognized command-line option '-Qunused-arguments'". Fix:
#    pre-seed `C_FLAG_QUNUSED_ARGUMENTS`/`CXX_FLAG_QUNUSED_ARGUMENTS` to
#    `OFF` via `-D...:INTERNAL=OFF` -- `check_*_compiler_flag` skips its
#    probe once the cache var is already set.
#
# 3. OPEN, ROOT-CAUSED: cmake-source-path bug. Every real per-TU compile
#    (`lib/`, `programs/`, `tests/`, `contrib/pzstd/`) fails with
#    `cc1: fatal error: /build/source/<own-source-file>: No such file
#    or directory` -- discoverTree's per-TU sandbox never stages the
#    primary source file itself. Same bug already documented against
#    xxHash/re2/tinycbor's real recipe (see
#    ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md); still open
#    as of dyn-drvs 1e9610f. `benchmarks/RESULTS.md` is marked BLOCKED
#    on this fix.

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

  # Small, non-accelerated derivation: must be a resolved store path
  # before phase 1 starts (a builder-rpc-v0 sandbox can't resolve
  # another dynamic derivation's output mid-build).
  genHtml = pkgs.stdenv.mkDerivation {
    pname = "zstd-gen-html";
    version = pkgs.zstd.version;
    src = pkgs.zstd.src;
    buildPhase = ''
      runHook preBuild
      g++ -O2 -c contrib/gen_html/gen_html.cpp -o gen_html.o
      g++ gen_html.o -o gen_html
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp gen_html $out/bin/gen_html
      runHook postInstall
    '';
  };

  accelerated = pkgs.zstd.override { stdenv = acceleratedStdenv; };
in
accelerated.overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      substituteInPlace build/cmake/contrib/gen_html/CMakeLists.txt \
        --replace-fail \
          'add_executable(gen_html ''${GENHTML_DIR}/gen_html.cpp)' \
          "" \
        --replace-fail \
          'DEPENDS gen_html COMMENT "Update zstd manual")' \
          'COMMENT "Update zstd manual")' \
        --replace-fail \
          'set(GENHTML_BINARY ''${PROJECT_BINARY_DIR}/gen_html''${CMAKE_EXECUTABLE_SUFFIX})' \
          'set(GENHTML_BINARY ${genHtml}/bin/gen_html)'
    '';
  # See finding 2 above: pre-seeding these skips the broken compiler-flag probe.
  cmakeFlags = (old.cmakeFlags or [ ]) ++ [
    "-DC_FLAG_QUNUSED_ARGUMENTS:INTERNAL=OFF"
    "-DCXX_FLAG_QUNUSED_ARGUMENTS:INTERNAL=OFF"
  ];
})
