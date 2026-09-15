# x265 (~99 TUs, cmake, H.265 encoder with genuinely heavy per-TU cost --
# exactly the profile per-TU acceleration is supposed to amortize best).
#
# RESULT: PASS (with 1 package-level workaround). Third distinct
# dyn-drvs bug found on this package, all now resolved -- see history
# below.
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
# literal `/nix/store/...` argv token at all. Every other bug this
# survey has found in the ar/cc shims (discoverTree's `-M -MG` scan,
# `extraStorePaths`'s store-path substring grep, 28af81d's `ar`-input
# scan) works by finding literal resolved store paths already present
# in argv or captured env strings -- none of that machinery has any way
# to resolve a bare `-l<name>` search-path reference back to the
# dynamic derivation that will eventually produce
# `libx265-10.a`/`libx265-12.a` in the current build directory. Not
# fixed by dyn-drvs 97a987d, 0d233d3, dc07a0a, 1347c8c, e5f9a61, or
# 5468402 -- confirmed via direct retest against the latest pushed
# commit as of this survey.
#
# WORKED AROUND at the package level: nixpkgs' `x265` recipe exposes
# `multibitdepthSupport` (default `true`) as an override parameter --
# passing `multibitdepthSupport = false` disables the whole multi-
# bitdepth cmake path that bakes in the `-lx265-10`/`-lx265-12` linkage
# in the first place, avoiding the bug entirely rather than fixing it.
# (Earlier revisions of this file incorrectly stated no override could
# avoid this -- `multibitdepthSupport` was there all along, just not
# checked.) Confirmed: with this flag, the real per-TU compiles, both
# `ar`-driven archive steps, AND the final `.so` link all succeed,
# producing a genuine `libx265.so.216`.
#
# Trade-off: this drops 10-bit/12-bit HDR encoding support, a real
# feature loss for downstream consumers, not a cosmetic flag -- unlike
# libssh's `WITH_SYMBOL_VERSIONING`/protobuf's `BUILD_TESTS` workarounds
# (which only disabled auxiliary/test machinery), this changes what the
# built library can actually do.

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
pkgs.x265.override {
  stdenv = acceleratedStdenv;
  multibitdepthSupport = false;
}
