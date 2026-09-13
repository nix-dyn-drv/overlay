# mosh uses autotools + autoreconfHook, unlike the freetype proof point
# (pre-generated configure) and exercises real cross-package -I/-L inputs
# (openssl/ncurses/zlib/protobuf). It's currently BLOCKED, not measured,
# in benchmarks/RESULTS.md.
#
# autoreconfHook's setup-hook appends autoreconfPhase to preConfigurePhases;
# genericBuild computes the actual `phases` list dynamically at build time
# from unpackPhase/patchPhase/${preConfigurePhases[*]}/configurePhase/...
# (stdenv-linux/setup). dyndrv.phases.split, which mkAcceleratedStdenv is
# built on, instead sets phase 1's `phases` to a STATIC sandboxedPhases
# default (unpackPhase patchPhase configurePhase buildPhase, see
# nix/lib/phases/split.nix), overriding that dynamic computation, so
# autoreconfPhase never runs: configurePhase logs "no configure script,
# doing nothing", buildPhase logs "no Makefile ... doing nothing", and
# installPhase fails trying to wrap a binary that was never built.
#
# mkAcceleratedStdenv.nix calls self.phases.split without forwarding a
# sandboxedPhases/replayPhases argument, so there's no parameter here to
# work around it. Real fix is in dyn-drvs: read the package's own dynamic
# $phases instead of the static default, or plumb sandboxedPhases/
# replayPhases through mkAcceleratedStdenv's params.

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
pkgs.mosh.override { stdenv = acceleratedStdenv; }
