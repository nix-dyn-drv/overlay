# Generalized from ~/dyn-drvs/try-it-out/benchmarks/real-package-lib.nix
# (hardcoded to freetype). Takes plainPkg/acceleratedPkg directly, rather
# than dyn-drvs' single pkg + variant param, because each package's
# override wiring (nix/packages/*.nix) differs enough per-package (e.g.
# zstd's gen_html fix only applies to the accelerated side) that building
# both variants from one shared expression isn't worth it here.

{
  variant ? "plain" # "plain" | "accelerated"
  ,
  patch ? null # optional path: a one-file patch to apply before building
  ,
  patches ? null # optional list of paths: multiple patches (mutually exclusive with `patch`)
  ,
  plainPkg # the unaccelerated derivation
  ,
  acceleratedPkg # the dyndrv-accelerated derivation (already wired to the right nixPackage/dyndrvShim)
  ,
  lib,
}:

let
  base = if variant == "accelerated" then acceleratedPkg else plainPkg;

  extraPatches =
    if patches != null then
      patches
    else if patch != null then
      [ patch ]
    else
      [ ];
in
base.overrideAttrs (
  old:
  {
    doCheck = false;
  }
  // lib.optionalAttrs (extraPatches != [ ]) {
    patches = (old.patches or [ ]) ++ extraPatches;
  }
)
