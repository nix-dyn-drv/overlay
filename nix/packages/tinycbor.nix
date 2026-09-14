# tinycbor -- BLOCKED against this repo's pinned nixpkgs (26.05, tinycbor
# 7.0). Independently spot-checked as a PASS earlier in this investigation
# against a different (older, qmake-based tinycbor 0.6.1) nixpkgs channel,
# but this repo's actual pin ships a cmake-based 7.0 recipe that hits the
# same discoverTree cmake-source-path bug as xxHash/re2 -- every real TU
# compile fails with `cc1: fatal error: /build/source/src/*.c: No such
# file or directory`. See ~/dyn-drvs/docs/discovertree-cmake-source-path-bug.md.
#
# Left here (not deleted) since it's a real, reproducible negative result
# tied to a specific nixpkgs version boundary -- worth tracking if
# upstream dyn-drvs fixes discoverTree's cmake path handling, or if this
# flake's nixpkgs pin moves back to a qmake-based tinycbor.

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
pkgs.tinycbor.override { stdenv = acceleratedStdenv; }
