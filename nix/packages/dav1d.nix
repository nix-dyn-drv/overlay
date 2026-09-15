# dav1d -- meson build (not cmake or autotools). Tried per explicit
# instruction despite being RULED OUT ahead of time on paper -- same
# caveat as x264: dyn-drvs has no meson-specific tooling, only generic
# cc/ar argv-sniffing shims.
#
# ORIGINALLY BLOCKED: failed during meson's own `configurePhase`, before
# `buildPhase` started:
#
# ```
# meson.build:25:0: ERROR: Unknown linker(s): [['ar']]
# ```
#
# Root cause: meson's own linker-detection probe runs `ar --version` to
# identify which archiver flavor `$AR` resolves to. `mkAcceleratedStdenv
# .nix`'s `arShim` (`arToNode`) had NO passthrough/probe-detection case
# at all and unconditionally assumed argv[0]/argv[1] were modifiers/
# archive-path (`inputs = genList (...) (len - 2)`); a 1-arg probe
# invocation like `ar --version` made `len - 2 = -1`, and
# `builtins.genList` threw outright on a negative size (`error: cannot
# create list of size -1`).
#
# FIXED upstream in dyn-drvs 227b1a6 ("Fix ar/ranlib shims crashing/
# misclassifying on version-probe invocations") -- confirmed directly:
# `configurePhase` now succeeds, and the real ninja build starts, with
# dozens of real dav1d TUs (cdef_tmpl, ipred_tmpl, mc_tmpl, msac, obu,
# picture, etc.) actually compiling.
#
# NOW BLOCKED by a different, new bug, further into the build: a real
# (non-probe) compile fails with
#
# ```
# gcc: error: unrecognized command-line option '-Wshorten-64-to-32'
# ```
#
# Root cause: dav1d's `meson.build` does a `cc.get_supported_arguments
# ([..., '-Wshorten-64-to-32'])` compiler-flag-support probe (a
# Clang-only flag GCC rejects) using meson's own `testfile.<ext>`/
# `sanitycheck*` probe naming convention -- which isn't caught by any of
# `mkAcceleratedStdenv.nix`'s `isProbe` heuristics (`isConftest`
# recognizes autoconf's naming, `isCMakeProbe` recognizes CMake's,
# neither recognizes meson's), since the invocation has a real `-c` flag
# and a real positional source. So the probe gets deferred into a
# batched node that always reports success, meson concludes GCC
# supports the flag, bakes it into every real TU's compile flags, and
# every real `cc -c ... .c` invocation genuinely fails on that
# unrecognized option. A third, distinct dyn-drvs bug (meson
# non-conftest-named flag-support probes not recognized as
# passthrough-eligible), unrelated to the ar-probe-crash bug that's now
# fixed.
#
# Not a package-level fix: no `mesonFlags`/`postPatch` on dav1d's own
# side can skip meson's own flag-support probe (unconditional, part of
# its own `meson.build`), and this repo's role is to document findings,
# not patch dyn-drvs. A real fix belongs in `toNode`'s `isProbe`
# detection: recognize meson's own probe naming convention
# (`testfile.<ext>`/`sanitycheck*`), mirroring the existing
# `isConftest`/`isCMakeProbe` cases.
#
# RETESTED against dyn-drvs 2cb6b4d (includes 227b1a6, 97a987d,
# 28af81d, dc07a0a, 1347c8c, and the newer __structuredAttrs fix from
# task #143) -- still open, identical failure: real TUs
# (bitdepth_16/ipred_prepare_tmpl etc.) now compile for real (confirming
# the ar-probe-crash fix still holds), but the SAME
# `-Wshorten-64-to-32` unrecognized-option failure recurs verbatim.
# None of the intervening fixes touch meson-probe detection.

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
pkgs.dav1d.override { stdenv = acceleratedStdenv; }
