# dav1d -- meson build (not cmake or autotools). Tried per explicit
# instruction despite being RULED OUT ahead of time on paper -- same
# caveat as x264: dyn-drvs has no meson-specific tooling, only generic
# cc/ar argv-sniffing shims. meson's own build backend is ninja, so every
# real compile/link still ultimately runs through plain `cc`/`ar`
# invocations the way an autotools or cmake build would; nothing
# meson-SPECIFIC should matter to `discoverTree`/`collectStubs` in
# principle. In practice, dav1d fails before a single real TU compiles,
# hitting a NEW `ar`-shim bug, distinct from all five documented in
# `~/dyn-drvs/docs/*.md`.
#
# RESULT: BLOCKED. Fails during meson's own `configurePhase`, before
# `buildPhase` starts:
#
# ```
# meson.build:25:0: ERROR: Unknown linker(s): [['ar']]
# ```
#
# Root cause: meson's own linker-detection probe (part of every native
# build's `configurePhase`, unconditional -- unrelated to dav1d's own
# `meson.build`) runs `ar --version` to identify which archiver flavor
# `$AR` resolves to (GNU ar vs. llvm-ar vs. MSVC lib.exe etc., branching
# on the probe's real stdout/stderr/exit code -- see nixpkgs' vendored
# `mesonbuild/compilers/detect.py`, `defaults['static_linker']` probing
# with `arg = '--version'`). `mkAcceleratedStdenv.nix`'s `arShim`
# (`arToNode` in that file) has NO passthrough/probe-detection case at
# all -- its own header comment (~line 1007) says so explicitly: "ALWAYS
# defers -- there is no passthrough case for `ar` ... if one ever does,
# it would need the same absolute-path check `cc`'s `toNode` uses."
# `arToNode` unconditionally assumes argv[0] is the modifiers string and
# argv[1] is the archive path (`inputs = genList (...) (len - 2)`); a
# 1-arg probe invocation like `ar --version` makes `len - 2 = -1`, and
# `builtins.genList` throws outright on a negative size:
#
# ```
# error: cannot create list of size -1
# ```
#
# Confirmed directly: extracted the actual generated `ar` wrapper script
# from a real sandboxed build attempt (`nix derivation show`'d the
# `dav1d` phase-1 `.drv`, found the `dyndrv-cc-shim` input, ran its
# `bin/ar --version` standalone) -- reproduces the identical
# `nix-instantiate` failure ("cannot create list of size -1") outside
# meson entirely, isolating this to `arToNode`'s own argv-shape
# assumption, not anything meson- or dav1d-specific. meson swallows the
# nested Nix error and reports it up as its own generic "Unknown
# linker(s)" message, since from meson's point of view the probe process
# just exited non-zero with no usable stdout.
#
# Why this didn't surface on giflib/tree/figlet/nnn/zstd/mosh/tinycbor:
# none of those build systems ever probe `ar --version`/`-h`/`-?`
# standalone the way meson's own linker-detection step does -- a plain
# Makefile's `$(AR) cr lib.a *.o` or cmake's generated archive rule
# always passes real modifiers + a real archive path, matching
# `arToNode`'s assumed 2-plus-positional-args shape. This is the FIRST
# meson-based package this survey has tried against
# `accelerate.mkAcceleratedStdenv`.
#
# Not a package-level fix: no `mesonFlags`/`postPatch` on dav1d's own
# side can skip meson's own linker-detection probe (it's unconditional,
# happens before any user-controlled build option is read at all), and
# this repo's role is to document findings, not patch dyn-drvs. A real
# fix belongs in `arToNode` itself: recognize a probe invocation (e.g.
# fewer than 2 positional args, or a leading `-`/`--` flag where a plain
# modifiers-string is expected) and pass it through synchronously to the
# real `ar`, mirroring `toNode`'s own `isConftest`/`isCMakeProbe`/
# `isInfoQuery` passthrough logic for `cc`.

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
