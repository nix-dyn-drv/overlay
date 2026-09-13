# giflib (plain Makefile, no configure script, `ar`-based static lib --
# no cc-driven link step) builds cleanly with no workarounds needed.
# A second real-package proof point beyond freetype, and useful contrast
# with zstd/pcre2: both of those hit the discoverTree link-step bug
# (see ~/dyn-drvs/docs/discovertree-link-step-bug.md) because their link
# steps drive cc/c++ directly (cmake, libtool respectively); giflib's
# link step is a plain `ar cr` archive, which goes through
# wrapCommand's separate non-discoverTree path and isn't affected.

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
pkgs.giflib.override { stdenv = acceleratedStdenv; }
