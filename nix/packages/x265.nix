# x265 (~99 TUs, cmake, H.265 encoder with genuinely heavy per-TU cost --
# exactly the profile per-TU acceleration is supposed to amortize best).
#
# RESULT: INCONCLUSIVE FOR dyn-drvs -- x265-4.2 fails to build on this
# repo's own nixpkgs pin REGARDLESS of dyn-drvs, so this package can't
# actually exercise `mkAcceleratedStdenv` at all right now. Confirmed a
# genuine, pre-existing nixpkgs/nasm bug, NOT a dyn-drvs bug -- see below.
#
# ## What was tried
#
# `dyndrv-x265` (this file, `pkgs.x265.override { stdenv =
# accelerate.mkAcceleratedStdenv { ... }; }`) fails deterministically,
# every attempt (4 independent runs, identical failure each time), at
# the exact same nasm invocation:
#
#   /build/x265_4.2/source/common/x86/intrapred16.asm:24641: error: label
#   `x265_10bit_intra_pred_ang32_31_sse4.loop' changed during code
#   generation (offset 0x1b4f2 -> 0x1b112) [-w+error=label-redef-late]
#   ...(dozens more of the same shape, same file)...
#   make[2]: *** [common/CMakeFiles/common.dir/build.make:138:
#   common/CMakeFiles/common.dir/x86/intrapred16.asm.o] Error 1
#
# `nasm`'s `label-redef-late` diagnostic (promoted to a hard error by
# x265's own `-w+error=label-redef-late` nasm flag) means a label's
# address changed between nasm's optimization passes while assembling
# `common/x86/intrapred16.asm` for the `build-10bits` variant
# (`X265_NS=x265_10bit`) -- a nasm multi-pass-optimizer issue on this
# specific `.asm` file, not anything to do with a C/C++ translation unit.
#
# ## Confirmed NOT a dyn-drvs bug -- direct A/B
#
# Built `pkgs.x265` PLAIN (no `mkAcceleratedStdenv` involved at all) from
# this exact same flake's nixpkgs pin, forcing a real local rebuild
# (`nix build --rebuild --option substituters ""`, not a cache
# substitution): it ALSO fails, at the identical `intrapred16.asm` label,
# in the identical `build-10bits` configuration. Confirmed identical
# source tarball
# (`/nix/store/kbw177m7rkd2pfjqgbclqqk917vnmzdj-x265_4.2.tar.gz`, same
# hash in both logs), identical `cmake-4.3.4`, identical
# `gcc-wrapper-15.3.0`, identical `nasm-3.02` in both the accelerated and
# the plain build. `mkAcceleratedStdenv`'s shims only wrap `cc`/`c++`/
# `ar`/`ranlib` -- `nasm` is never touched at all, so there is no
# mechanism by which acceleration could even be involved in an
# `ASM_NASM`-language target's failure. This is a bug in nixpkgs' x265
# recipe/nasm-3.02 interaction (or in nasm 3.02 itself) that blocks ANY
# build of `pkgs.x265` on this nixpkgs pin, dyn-drvs or not.
#
# ## Why left in this repo anyway
#
# Genuinely can't tell whether `mkAcceleratedStdenv` would work on x265
# until this pre-existing, unrelated breakage is fixed upstream (in
# nixpkgs' x265 recipe or in nasm itself). Left in as an accurate,
# reproducible INCONCLUSIVE result rather than deleted -- per this
# repo's convention of documenting real findings, including "the
# baseline package doesn't build here at all" as a valid, if unglamorous,
# outcome. No dyn-drvs docs under `~/dyn-drvs/docs/*.md` mention `nasm`/
# `label-redef-late`/any assembler issue, so this isn't a rediscovery of
# an already-known dyn-drvs bug -- it's simply orthogonal to dyn-drvs
# entirely.
#
# ## Status: INCONCLUSIVE (blocked on an unrelated nixpkgs/nasm bug, not
# a dyn-drvs bug). Revisit once `pkgs.x265` builds plain on whatever
# nixpkgs pin this repo uses.

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
