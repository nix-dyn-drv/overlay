# libb64 (~2 real TUs, plain Makefile, then two example binaries
# self-exec'd by the Makefile's own "test" target right after linking).
#
# This is the SAME package dyn-drvs documents as a permanent
# architectural limitation (~/dyn-drvs/docs/discovertree-exec-bit-bug.md):
# every dyn-drvs-shimmed cc/ar invocation defers to a placeholder text
# file, resolved into real bytes only once, at the very end of
# buildPhase -- so a Makefile recipe that execs a binary it JUST linked,
# in the SAME buildPhase invocation, finds unresolved placeholder text,
# not a lost permission bit. Root-caused as unfixable within dyn-drvs'
# single-buildPhase architecture (fixed in dyn-drvs 5468402).
#
# nixgg hits the IDENTICAL wall for the identical structural reason --
# confirmed directly: a one-phase `mkNixggBuild` attempting to compile,
# archive, link, AND self-exec c-example1 all in one buildCommand fails
# with the same `Permission denied` / `Error 127` (nixgg's own DESIGN.md
# calls this "the synchronous-realize wall": builder-rpc-v0's daemon
# connection has NO synchronous build op at all, by upstream design, not
# a gap nixgg's Go code could close).
#
# nixgg's mechanism DOES have a real escape hatch dyn-drvs has no
# equivalent for, though: mkNixggBuild's own two-phase pattern (see
# nixgg/examples/two-phase, built for LLVM's tblgen mid-build execution)
# splits a package into two Nix-LEVEL derivations, where phase 2 is an
# ORDINARY stdenv.mkDerivation (not another mkNixggBuild call) whose
# buildInputs forces phase 1's result to resolve to real bytes BEFORE
# phase 2's own script starts -- avoiding the synchronous-realize wall
# entirely, since phase 2 never runs through nixgg's own deferred shims.
#
# RESULT: PASS, via the two-phase split.
#   phase1 (mkNixggBuild) -- accelerates the real work: libb64's two
#     genuine per-TU compiles (cencode.c, cdecode.c), each its own
#     dynamic derivation, archived into libb64.a.
#   phase2 (plain runCommand) -- links c-example1.c against phase1's
#     REAL, already-resolved libb64.a, then runs it directly. Confirmed
#     directly: the build log shows the just-linked binary's own real
#     output (`encoded: aGVsbG8gd29ybGQ=` / `decoded: hello world`), not
#     a stub -- the exact self-exec dyn-drvs can never support.
#
# Real trade-off, not a free lunch: this only works because libb64's
# build has a clean phase boundary (the self-exec happens in a
# logically separate step from the accelerated compiles) that's
# reachable via buildInputs. nixgg's own DESIGN.md is explicit that a
# build whose synchronous read-back is interleaved with acceleration-
# needing work on BOTH sides of that boundary is a real, currently-
# unsolved gap even for nixgg -- this package's shape just happens to
# avoid that harder case.

{
  pkgs,
  mkNixggBuild,
}:

let
  src = pkgs.libb64.src;

  phase1 = mkNixggBuild {
    pname = "libb64-staticlib";
    version = "0";
    inherit src;
    targets = [ { name = "libb64"; path = "libb64.a"; } ];
    buildCommand = ''
      cd src
      make
    '';
  };
in
pkgs.runCommand "libb64-example1-selftest" {
  nativeBuildInputs = [ pkgs.gcc ];
  buildInputs = [ phase1.result ];
} ''
  cp ${src}/examples/c-example1.c .
  gcc -g -Werror -pedantic -I${src}/include c-example1.c ${phase1.result}/lib/libb64.a -o c-example1
  ./c-example1
  touch $out
''
