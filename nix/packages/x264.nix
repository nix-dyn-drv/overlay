# x264 -- autotools-style `./configure` + hand-written Makefile (NOT
# cmake, unlike zstd/tinycbor's real recipe). Explicitly RULED OUT ahead
# of time as a cmake-based candidate (see task background); tried
# anyway per explicit instruction, to see whether the accelerator's
# generic cc/ar targeting tolerates x264's own configure+Makefile shape
# or hits a new bug regardless of build-system family.
#
# RESULT: PASS, with two package-level workarounds for two NEW dyn-drvs
# bugs (neither previously documented against zstd/mosh/tinycbor/
# openssl). Real per-TU compiles, a real `cc`-driven `libx264.so.165`
# link (NOT the discoverTree link-step bug -- x264's link step got
# through cleanly, see finding 2's own note on why), and a real,
# runnable `bin/x264` (`x264 --version` prints "x264 0.165.x ..."),
# confirmed directly against this repo's own build.

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
  accelerated = pkgs.x264.override { stdenv = acceleratedStdenv; };
in
# See finding 1 above (the DIAGNOSTIC-PROBE PASSTHROUGH GAP): x264's own
# ./configure unconditionally runs `if gcc-ranlib --version; then ...`/
# `if gcc-ar --version; then ...` (LTO-plugin detection) BEFORE
# `$AR`/`$RANLIB`'s own `${AR-...}`/`${RANLIB-...}` parameter-expansion
# defaults are even consulted -- so pre-setting AR/RANLIB as env vars
# doesn't skip the probe itself, only what it's later overridden by.
# postPatch neutralizes the probe directly (a legitimate, x264-specific
# fix, same shape as zstd.nix's own postPatch): force the plain,
# non-LTO-plugin `ar`/`ranlib` names, skipping the diagnostic `gcc-ar
# --version`/`gcc-ranlib --version` invocations entirely.
#
# See finding 2 above (the "lib" OUTPUT NEVER GETS POPULATED bug): once
# finding 1 is worked around, real compiles and the real `libx264.so`
# link both succeed -- but the build still fails, this time because
# `phases.split` forces phase 1 to a SINGLE output (`$out` only, see
# `nix/lib/phases/split.nix`'s own header comment), which makes
# nixpkgs' own `multiple-outputs.sh` compute `outputLib="out"` (its
# `_overrideFirst outputLib "lib" "out"` fallback -- `$lib` isn't
# exported when only `$out` exists), so x264's real `--libdir` lands
# under `$out/lib` during phase 1's real build, not the eventual `$lib`
# output. `dyndrvRestoreOutput` copies phase 1's `$out` content into
# the real derivation's own `$out` and calls nixpkgs'
# `_multioutDevs`/`_multioutDocs` to redistribute headers/pkgconfig/docs
# into `$dev` -- but neither hook knows how to redistribute ordinary
# "lib" output content (`.so`/`.a` files), since in a REAL,
# unaccelerated multi-output build that content is written straight to
# `$lib` by `--libdir=$lib/lib` at configure time, never physically
# relocated after the fact. The result: `$lib` is never created at
# all, and Nix's builder fails outright ("failed to produce output
# path for output 'lib'") once `installPhase` finishes. Confirmed this
# is package-shape-specific, not something zstd/tinycbor/giflib/mosh
# exercised: none of them declare a literal, non-fallback `"lib"`
# output (zstd's `outputs = [bin dev man out]` has no `"lib"` at all,
# so its own shared library already lands in `$out` even in an
# ordinary build) -- x264 is the first package in this survey whose
# main build product is specifically routed to a named `lib` output.
#
# Worked around at the package level below: a `preFixup` hook (runs
# during `fixupPhase`, AFTER `dyndrvRestoreOutput` already ran
# `_multioutDevs`/`_multioutDocs` and populated the real `$out`) moves
# whatever's left under `$out/lib` into `$lib/lib`, mirroring exactly
# what `--libdir=$lib/lib` would have done directly in an unaccelerated
# build. This is a real result AND a real, scoped package-level fix --
# not a dyn-drvs change -- so left in as the final, working recipe.
#
# Note on the zstd/pcre2/mpfr discoverTree link-step bug (still open,
# see `nix/packages/zstd.nix`): x264's own `libx264.so.165` link step
# (`$(LD)$@ $(OBJS) ... -o libx264.so.165`, `LD="$CC -o "`) is exactly
# the `cc`-driven-link-with-`.o`-positional-args shape that bug
# describes, yet it built cleanly here. Consistent with zstd.nix's own
# finding 3 note that the bug is "not universal" -- some invocation
# shapes hit it, some don't -- x264's link happens to be one that
# doesn't, for reasons not fully isolated in this pass (single flat
# `.o` list, no libtool/cmake-generated indirection, may be relevant).
accelerated.overrideAttrs (old: {
  postPatch =
    (old.postPatch or "")
    + ''
      substituteInPlace configure \
        --replace-fail \
          'if ${"$"}{cross_prefix}gcc-ar --version >/dev/null 2>&1; then' \
          'if false; then' \
        --replace-fail \
          'if ${"$"}{cross_prefix}gcc-ranlib --version >/dev/null 2>&1; then' \
          'if false; then'
    '';
  preFixup =
    (old.preFixup or "")
    + ''
      if [ -n "${"$"}{lib:-}" ] && [ "$lib" != "$out" ] && [ -d "$out/lib" ]; then
        mkdir -p "$lib/lib"
        mv "$out"/lib/* "$lib/lib"/
        rmdir "$out/lib" 2>/dev/null || true
      fi
    '';
})
