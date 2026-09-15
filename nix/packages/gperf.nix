# gperf (~20 TUs, autotools/automake, plain Makefile.in).
#
# RESULT: PASS. Originally BLOCKED by the automake depcomp side-output
# bug: every real per-TU compile succeeded, but the immediately
# following Makefile line always failed --
#
#   g++ ... -MT hash.o -MD -MP -MF .deps/hash.Tpo -c -o hash.o hash.cc
#   mv -f .deps/hash.Tpo .deps/hash.Po
#   mv: cannot stat '.deps/hash.Tpo': No such file or directory
#
# `-MF <path>` names a SECOND file the same compile invocation writes as
# a byproduct; only the primary `-o` output was tracked/staged back out
# of the per-TU sandbox, so the depfile never reached the outer `mv`.
# FIXED upstream in dyn-drvs 9dc8037 ("Fix wrapCommand: touch empty -MF
# depfile at defer time (task #148)") -- since Nix always rebuilds fully
# from scratch (no incremental depfile reuse the way a real `make` re-run
# would exploit), the depfile's CONTENT never matters, only its
# EXISTENCE for the following `mv`; `finalizeTail` now touches an empty
# file at the `-MF` path directly. Confirmed directly: all ~20 real
# per-TU compiles now succeed end to end, producing a genuine, runnable
# `bin/gperf`. See `~/dyn-drvs/docs/depfile-side-output-bug.md`.

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
pkgs.gperf.override { stdenv = acceleratedStdenv; }
