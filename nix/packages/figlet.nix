# figlet (plain hand-written Makefile, no configure script, no cmake --
# same shape as giflib/tree) builds cleanly with no workarounds needed.

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
pkgs.figlet.override { stdenv = acceleratedStdenv; }
