# dav1d -- PASS. meson build (not cmake or autotools). Tried per
# explicit instruction despite being RULED OUT ahead of time on paper --
# same caveat as x264: dyn-drvs had no meson-specific tooling, only
# generic cc/ar argv-sniffing shims (until this package's own retest
# added meson-probe detection, see below).
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
# THEN blocked by a different bug, further into the build: a real
# (non-probe) compile failed with
#
# ```
# gcc: error: unrecognized command-line option '-Wshorten-64-to-32'
# ```
#
# Root cause: dav1d's `meson.build` does a `cc.get_supported_arguments
# ([..., '-Wshorten-64-to-32'])` compiler-flag-support probe (a
# Clang-only flag GCC rejects) using meson's own `testfile.<suffix>`
# probe naming convention -- confirmed directly from meson's own source
# (`mesonbuild/compilers/compilers.py`: every compiler-check primitive
# unconditionally names its scratch source file `testfile.<suffix>`,
# meson's exact analog to autoconf's `conftest` convention). This wasn't
# caught by any of `mkAcceleratedStdenv.nix`'s `isProbe` heuristics
# (`isConftest` recognized autoconf's naming, `isCMakeProbe` recognized
# CMake's, neither recognized meson's), since the invocation has a real
# `-c` flag and a real positional source. So the probe got deferred into
# a batched node that always reports success, meson concluded GCC
# supports the flag, baked it into every real TU's compile flags, and
# every real `cc -c ... .c` invocation genuinely failed on that
# unrecognized option.
#
# Not a package-level fix: no `mesonFlags`/`postPatch` on dav1d's own
# side can skip meson's own flag-support probe (unconditional, part of
# its own `meson.build`).
#
# RETESTED against dyn-drvs 2cb6b4d (includes 227b1a6, 97a987d,
# 28af81d, dc07a0a, 1347c8c, and the newer __structuredAttrs fix from
# task #143) -- still open at that point, identical failure.
#
# FIXED upstream in dyn-drvs caa7c5d ("Fix meson compiler-check probes
# not recognized as passthrough-eligible (task #146)") -- adds
# `isMesonProbe`, checking `sourcePath`/positional args' basenames for
# the `testfile.` prefix, mirroring `isConftest`'s BASENAME-only
# convention. Confirmed directly: `dyndrv-dav1d` now builds clean end to
# end -- every real TU (cdef_tmpl, ipred_tmpl, mc_tmpl, msac, obu,
# picture, decode, getbits, etc.) compiles and links for real, producing
# a genuine `libdav1d.so.7.0.0` (verified ELF shared object).

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
