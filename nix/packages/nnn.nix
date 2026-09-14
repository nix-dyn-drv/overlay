# nnn (plain hand-written Makefile, no configure script, no cmake --
# same shape as giflib/tree/figlet) builds cleanly with no workarounds
# needed, including nixpkgs' makeWrapper-generated shell shim.

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
pkgs.nnn.override { stdenv = acceleratedStdenv; }
