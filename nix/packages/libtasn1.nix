# libtasn1 (autotools + libtool, sets `outputBin = "dev"` explicitly --
# same shape as libpng, independently confirmed).
#
# RESULT: BLOCKED. Hit the exact same `outputBin` override bug as libpng
# first (fixed upstream, dyn-drvs 0a8b174), then the exact same libtool
# unversioned-`.so`-symlink bug next -- see `nix/packages/libpng.nix`'s
# header for the full writeup of both. Here the failing link is
# `examples/CertificateExample` against `../lib/.libs/libtasn1.so`:
#
#   ld.bfd: cannot find ../lib/.libs/libtasn1.so: No such file or directory
#
# See `~/dyn-drvs/docs/split-outputbin-override-bug.md` and
# `~/dyn-drvs/docs/libtool-so-symlink-bug.md`.

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
pkgs.libtasn1.override { stdenv = acceleratedStdenv; }
