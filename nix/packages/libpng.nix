# libpng (autotools + libtool, sets `outputBin = "dev"` explicitly).
#
# RESULT: BLOCKED (a different bug than the one this package was
# originally added to exercise). Originally blocked before any real
# compile ran:
#
#   error: _assignFirst: could not find a non-empty variable whose name
#          to assign to outputMan. The following variables were all
#          unset or empty: man dev
#
# `phases.split` forces phase 1 to `outputs = [ "out" ]`, but didn't
# clear a package's own *explicit literal* `outputBin`/`outputMan`/
# `outputDev` override (as opposed to stdenv's own unset-fallback case,
# which it already handled) -- nixpkgs' own multiple-outputs.sh then
# looked for a non-empty `$dev`/`$man` that phase 1 never exports. FIXED
# upstream in dyn-drvs 0a8b174 ("Fix phases.split: clear inherited
# outputBin/outputMan/outputDev literal overrides (task #147)"). See
# `~/dyn-drvs/docs/split-outputbin-override-bug.md`.
#
# With that fixed, every real per-TU compile succeeds and libtool's own
# real, versioned `libpng16.so.16.58.0` links and is correctly tracked
# as a dynamic derivation. The NEXT link step (`contrib/tools/pngcp`,
# linking against libtool's plain, unversioned `libpng16.so` symlink)
# then fails:
#
#   ld.bfd: cannot find ./.libs/libpng16.so: No such file or directory
#
# A new, still-open bug: libtool creates the unversioned `.so` name as a
# plain `ln -s` alongside the real versioned file, not via a compiler
# invocation `wrapCommand.nix` ever wraps -- so nothing registers it as
# an alias of the dynamic derivation that produces the real file, and a
# later literal `./.libs/libpng16.so` in argv never resolves. See
# `~/dyn-drvs/docs/libtool-so-symlink-bug.md` for the full writeup (also
# hit, identically, by libtasn1 -- `nix/packages/libtasn1.nix`). No
# package-level workaround found: the failing binaries (pngcp, pngtest,
# etc.) build unconditionally as part of the normal build, not gated
# behind `doCheck`/a disable flag.

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
pkgs.libpng.override { stdenv = acceleratedStdenv; }
