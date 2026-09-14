# x265 (~99 TUs, cmake, H.265 encoder with genuinely heavy per-TU cost --
# exactly the profile per-TU acceleration is supposed to amortize best).
#
# RESULT: BLOCKED (real dyn-drvs bug, distinct from an earlier unrelated
# finding described below).
#
# ## Originally INCONCLUSIVE: a pre-existing nixpkgs/nasm bug, not dyn-drvs
#
# The first attempts failed deterministically at a nasm assembler error
# (`label-redef-late` on `common/x86/intrapred16.asm`), confirmed via a
# direct A/B rebuild to be a pre-existing nixpkgs/nasm-3.02 issue
# affecting `pkgs.x265` PLAIN too, unrelated to `mkAcceleratedStdenv`
# (which never wraps `nasm`, only `cc`/`c++`/`ar`/`ranlib`).
#
# ## Retested: the nasm issue is gone, real dyn-drvs bug found underneath
#
# Retesting later, that nasm error did NOT recur -- all ~92 real
# `.asm.o` files (including `intrapred16.asm`) now assemble successfully
# (likely due to an unrelated nixpkgs/nasm update in the interim, not a
# dyn-drvs change). With that resolved, the build now genuinely exercises
# `mkAcceleratedStdenv` and hits a real bug: archiving into
# `libx265_a.a`/`libhdr10plus_a.a` via `ar`/`ranlib` fails:
#
#   ar: /nix/store/<hash>-analysis.cpp.o: No such file or directory
#   ranlib: '/nix/store/<hash>-dyndrv-libx265_a': No such file
#
# (identical shape for `dyndrv-libhdr10plus_a` with `json11.cpp.o`).
# Confirmed the referenced `.o` files genuinely exist as valid ELF
# relocatable objects on disk (`file` shows non-stripped x86-64 ELF
# `.o`), but `nix derivation show` on the failing `.drv`s shows
# `inputs.drvs = {}` and `inputs.srcs` only listing `binutils-2.46` --
# none of the `.o` file store paths referenced in `ar`'s own argv are
# declared as build inputs, so they're never mounted into the sandbox.
# Same bug class as libwebp/openjpeg's own `ar`/`ranlib` failures: the
# dependency-wiring gap is in how `arToNode`/`collectStubs` resolve a
# real archive step's positional `.o` inputs into `inputs.drvs`, not
# something x265's own cmake project controls. Not fixed by either
# dyn-drvs 97a987d (cmake -MT/-MF misdetection) or 0d233d3 (cmake+make
# out-of-tree install) -- confirmed via direct retest against both.
#
# ## Status: BLOCKED on the ar/ranlib dependency-wiring bug (same class
# as libwebp/openjpeg). No package-level workaround exists.

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
pkgs.x265.override { stdenv = acceleratedStdenv; }
