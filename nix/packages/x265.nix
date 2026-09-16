# x265 (~99 TUs, cmake, H.265 encoder with genuinely heavy per-TU cost --
# exactly the profile per-TU acceleration is supposed to amortize best).
#
# RESULT: PASS, full multi-bitdepth support restored. Fourth distinct
# dyn-drvs-adjacent issue found on this package, all now resolved -- see
# history below.
#
# ## Originally INCONCLUSIVE: a pre-existing nixpkgs/nasm bug, not dyn-drvs
#
# The first attempts failed deterministically at a nasm assembler error
# (`label-redef-late` on `common/x86/intrapred16.asm`), confirmed via a
# direct A/B rebuild to be a pre-existing nixpkgs/nasm-3.02 issue
# affecting `pkgs.x265` PLAIN too, unrelated to `mkAcceleratedStdenv`
# (which never wraps `nasm`, only `cc`/`c++`/`ar`/`ranlib`).
#
# ## Then: the ar/ranlib dependency-wiring bug (same class as
# libwebp/openjpeg), FIXED
#
# Retesting later, the nasm error did NOT recur -- all ~92 real
# `.asm.o` files (including `intrapred16.asm`) now assemble successfully
# (likely due to an unrelated nixpkgs/nasm update in the interim, not a
# dyn-drvs change). With that resolved, the build genuinely exercised
# `mkAcceleratedStdenv` and hit a real bug: archiving into
# `libx265_a.a`/`libhdr10plus_a.a` via `ar`/`ranlib` failed:
#
#   ar: /nix/store/<hash>-analysis.cpp.o: No such file or directory
#   ranlib: '/nix/store/<hash>-dyndrv-libx265_a': No such file
#
# (identical shape for `dyndrv-libhdr10plus_a` with `json11.cpp.o`).
# `nix derivation show` on the failing `.drv`s showed `inputs.drvs = {}`
# -- none of the `.o` file store paths referenced in `ar`'s own argv
# were declared as build inputs. FIXED upstream in dyn-drvs 28af81d
# ("Fix ar shim: declare its own real .o/archive inputs as derivation
# deps") -- confirmed directly: both `libx265_a.a`/`libhdr10plus_a.a`
# archive steps now succeed for real.
#
# ## Then: a third, distinct bug: `-l<name>`-style link args never
# resolved
#
# With the ar/ranlib bug fixed, the shared-lib link
# (`dyndrv-libx265_so_216`) ran for real but failed at the linker:
#
#   ld.bfd: cannot find -lx265-10: No such file or directory
#   ld.bfd: cannot find -lx265-12: No such file or directory
#   collect2: error: ld returned 1 exit status
#
# `nix derivation show` on the failing link's `.drv` confirmed
# `inputs.drvs = {}` again, but this time for a genuinely different
# reason: cmake's own multi-bitdepth build links `libx265.so` against
# two sibling static libs (`libx265-10.a`/`libx265-12.a`, the 10-bit/
# 12-bit encoder variants) purely by `-Wl,-Bstatic -lx265-10 -lx265-12`
# -- a bare `-l<name>` plus `-L.` (search the current build dir), not a
# literal `/nix/store/...` argv token at all. FIXED upstream in dyn-drvs
# (task #149, "Fix wrapCommand: resolve bare -l<name> against relative
# -L<dir> search paths") -- confirmed: `-lx265-10`/`-lx265-12` now
# correctly resolve to their real relative symlink targets.
#
# ## Then: a fourth, distinct bug: the sibling `build-10bits`/
# `build-12bits` cmake trees' own stubs were never discovered at all
#
# With the `-l<name>` fix in place, the link step's own resolved target
# (`../build-10bits/libx265.a`) turned out to have never been
# registered as a stub in the first place -- `shim.collectStubs`'s own
# stub-discovery only ever scanned the MAIN build directory, never the
# sibling trees x265's own `preConfigure` creates before the main
# configure even runs. FIXED upstream in dyn-drvs (task #150, "Fix
# collectStubs: discover stubs in sibling build dirs too") -- confirmed:
# `dyndrv-libx265_so_215.drv` (the exact derivation this bug blocked)
# now links successfully.
#
# ## Then: a fifth, distinct issue: `EXPORT_C_API`/`X265_NS` silently
# lost for the sibling cmake configures, WORKED AROUND HERE (package
# level, not a dyn-drvs bug)
#
# With both of the above fixed, real x265 (multibitdepth + unittests)
# progressed all the way to `test_TestBench`'s own link step, which
# failed with undefined references to `x265_10bit::`/`x265_12bit::`-
# namespaced symbols:
#
#   undefined reference to `x265_10bit::x265_api_get_215(int)'
#   undefined reference to `x265_12bit::x265_api_query(int, int, int*)'
#
# Root-caused via `nix log`: `build-10bits/encoder/CMakeFiles/
# encoder.dir/flags.make` showed `-DEXPORT_C_API=1 -DX265_NS=x265` (the
# UNSET DEFAULTS) instead of the requested `-DEXPORT_C_API=0
# -DX265_NS=x265_10bit`. This is NOT a dyn-drvs stub-discovery bug --
# it's a structural conflict between two things `dyn-drvs`'s
# `phases.split` and x265's own recipe each need:
#
#   - `phases.split` forces `__structuredAttrs = false` on its sandboxed
#     phase 1, unconditionally -- required so its own `out =
#     dyndrvPlaceholderOut` derivation-attribute override actually takes
#     effect (confirmed: under `__structuredAttrs = true`, Nix computes
#     `$out` from the real CA hash and ignores that literal attribute
#     entirely, defeating the whole placeholder-then-restore mechanism).
#     Moving that override later (e.g. a plain `export out=...` as the
#     first line of a custom `buildCommand`) is ALSO unsafe in general:
#     nixpkgs' own built-in setup hooks (`multiple-outputs.sh`'s
#     `_addRpathPrefix "${!outputLib}"`, `reproducible-builds.sh`'s
#     `-frandom-seed=$(...)`) eagerly bake the REAL, not-yet-overridden
#     `$out`'s value into `NIX_LDFLAGS`/`NIX_CFLAGS_COMPILE` while
#     `nativeBuildInputs`/`buildInputs` setup hooks are sourced --
#     BEFORE `genericBuild` ever reaches a `buildCommand` attribute's
#     own first line (confirmed by direct source reading of
#     `pkgs/stdenv/generic/setup.sh`/`default-builder.sh`: `source
#     $stdenv/setup` runs to completion, sourcing every dependency's own
#     setup hook unconditionally, strictly BEFORE `genericBuild` is even
#     called).
#   - x265's own `preConfigure` (`multibitdepthSupport`'s cmake
#     invocations) uses REAL bash-array syntax
#     (`"${cmakeStaticLibFlags[@]}"`) on `cmakeFlags`/
#     `cmakeStaticLibFlags`/`cmakeFlagsArray` -- Nix list-typed
#     attributes that only become genuine bash ARRAYS under
#     `__structuredAttrs = true`. Forced OFF (per above), each becomes a
#     plain, space-joined STRING instead -- `"${cmakeStaticLibFlags[@]}"`
#     on a scalar variable expands to exactly ONE argument (the whole
#     string, `-DHIGH_BIT_DEPTH:BOOL=TRUE -DENABLE_CLI:BOOL=FALSE
#     -DENABLE_SHARED:BOOL=FALSE -DEXPORT_C_API:BOOL=FALSE`, all four
#     flags glued together) instead of four separate ones -- cmake
#     receives it as one nonsensical positional argument and silently
#     ignores it entirely, leaving every one of those four options at
#     its own UNSET DEFAULT (`EXPORT_C_API` defaults to `ON`, `X265_NS`
#     then defaults to plain `x265`, matching the exact symbols observed
#     in the sibling trees' own real `.o` files: `x265_10bit`/
#     `x265_12bit`-namespaced symbols never got compiled at all, only
#     plain, unmangled `x265_api_get_215`/`x265_api_query`).
#
# WORKED AROUND HERE, at the package level (NOT a dyn-drvs fix, since
# resolving the general `__structuredAttrs`-vs-placeholder-`$out`
# conflict for every possible package is a much larger, structural
# change with its own regression surface -- see the analysis above):
# `preConfigure` is overridden to defensively reconstruct real bash
# arrays for `cmakeFlags`/`cmakeStaticLibFlags` immediately before
# using them, tolerating EITHER shape (a real array already, the
# ordinary unaccelerated-build case; or a flattened string, this
# accelerated-build case) via a `declare -p`-based type check -- a
# no-op under `__structuredAttrs = true`, and a correct re-split under
# `__structuredAttrs = false`. Confirmed via direct reproduction (a
# standalone bash snippet mirroring this exact `preConfigure` shape)
# that this produces the correct, separately-quoted `-DFOO:BOOL=...`
# arguments in both cases, and via a real rebuild: `build-10bits`'s own
# `flags.make` now shows the correctly-requested `-DEXPORT_C_API=0
# -DX265_NS=x265_10bit`, and `test_TestBench` links and passes.

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
  # Reconstructs real bash arrays for `cmakeFlags`/`cmakeStaticLibFlags`
  # before x265's own `preConfigure` (which indexes them via
  # `"${cmakeStaticLibFlags[@]}"`) runs -- see this file's own header
  # comment for why: dyn-drvs' `phases.split` forces `__structuredAttrs
  # = false` on its sandboxed phase 1, which silently flattens these
  # Nix-list-typed attributes into plain, space-joined strings instead
  # of real bash arrays. `declare -p ... == "declare -a"*` distinguishes
  # the two shapes; only re-splits (via unquoted expansion, ordinary
  # bash word-splitting) when NOT already a real array, so this stays a
  # no-op for an ordinary, unaccelerated build (`__structuredAttrs =
  # true` there, or unset entirely -- either way already a real array).
  fixCmakeArraysPreConfigure = ''
    if [[ "$(declare -p cmakeFlags 2>/dev/null)" != "declare -a"* ]]; then
      cmakeFlags=( $cmakeFlags )
    fi
    if [[ "$(declare -p cmakeStaticLibFlags 2>/dev/null)" != "declare -a"* ]]; then
      cmakeStaticLibFlags=( $cmakeStaticLibFlags )
    fi
  '';
in
(pkgs.x265.override {
  stdenv = acceleratedStdenv;
}).overrideAttrs
  (old: {
    preConfigure = fixCmakeArraysPreConfigure + old.preConfigure;
  })
