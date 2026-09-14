# mosh uses autotools + autoreconfHook, unlike the freetype proof point
# (pre-generated configure) and exercises real cross-package -I/-L inputs
# (openssl/ncurses/zlib/protobuf). It's currently BLOCKED, not measured,
# in benchmarks/RESULTS.md.
#
# The original autoreconfHook phase-dropping bug (phases.split's static
# sandboxedPhases list overriding genericBuild's dynamic $phases
# computation) is FIXED as of dyn-drvs 8aa6b86 -- configurePhase/
# buildPhase both run for real now, and mosh-client/mosh-server link and
# install correctly.
#
# OPEN, ROOT-CAUSED (different bug, found once the build got this far):
# mosh's own postInstall (`wrapProgram $out/bin/mosh ...`) runs as part
# of nixpkgs' installPhase itself (postInstall is a hook, not a separate
# phase), but phases.split's synthesized dyndrvRestoreOutput phase --
# which copies phase 1's placeholder-rooted tree into the real $out --
# is inserted as a SEPARATE phase AFTER installPhase. So postInstall's
# `wrapProgram $out/bin/mosh` looks for $out/bin/mosh before the restore
# copy ever runs, even though bin/mosh really was installed (just still
# under the placeholder root). Fails with "Cannot wrap ... because it
# does not exist". See
# ~/dyn-drvs/docs/split-postinstall-before-restore-bug.md.

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
