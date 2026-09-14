# Benchmark results

Numbers this repo's README cites. All measured on a specific machine;
losses are reported alongside wins.

Four mechanisms compared, all implementing the same underlying Nix
feature (`builtins.outputOf`, dynamic derivations) independently:

- **nixgg's `splitStdenv`/`dynDrvStdenv`** -- Go-based shim, already proven
  at nixpkgs scale (`openssl`/`openssl-3_5`/`hello`/`mosh`/`zstd` outputs).
- **dyn-drvs' `accelerate.mkAcceleratedStdenv`** -- Nix-language library
  (`dyndrv-*` outputs). See `nix/packages/*.nix` headers for per-package
  status.
- **nix-ninja's `mkMesonPackage`** -- a drop-in `ninja` replacement
  (`$NINJA=nix-ninja`) that turns a meson-generated `build.ninja`'s real
  build graph into dynamic derivations (`nixninja-argp` output). Doesn't
  override an existing package's stdenv like the other three -- it
  reconstructs the meson invocation directly from `src`/
  `nativeBuildInputs`/a ninja target name, since `mkMesonPackage` isn't
  exported as a `lib` output.
- **drowse's `callPackage`** -- defers a whole package's *evaluation*
  into a nested `nix-instantiate` (via `recursive-nix`), not a per-TU
  *build* split like the other three (`drowse-hello` output). The "avoid
  IFD" half of the dynamic-derivations story, distinct from fine-grained
  build splitting.

## nixgg mechanism (`splitStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock | Notes |
|---|---|---|---|---|
| openssl (~2200 TUs) | one-file patch (`crypto/mem.c`) | 2/2213 | -- | From nixgg's README; not re-measured here. |
| openssl | version bump (3.6.3->3.5.7) | 2153/2192 (98%) | -- | Version baked into `opensslv.h`, included nearly everywhere. |
| openssl, hello, mosh, zstd | cold build | -- | -- | All four build cleanly end to end in CI (`.github/workflows/ci.yml`, real `/nix/store`, real per-TU `tu-*.o.drv` derivations submitted). |

## dyn-drvs mechanism (`accelerate.mkAcceleratedStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock (plain vs accelerated) | Speedup | Notes |
|---|---|---|---|---|---|
| freetype (~45 TUs) | cold build | 93 registered | 11.8-11.9s vs 77-81s | **0.15x (~6.7x slower)** | Re-measured directly in this repo (`benchmarks/patch-rebuild.sh dyndrv-freetype-baseline dyndrv-freetype`, two runs, both ~0.15x). `dyndrv-freetype` builds real `libfreetype.so`, 93 dynamic derivations registered. Per-TU compile cost too small to amortize the ~80ms/derivation registration tax (same conclusion as dyn-drvs' own BASELINE.md, but that repo's 17x/0.06x figure is a DIFFERENT scenario -- a one-file patch rebuild, not a cold build -- and was never itself re-verified here; the CI benchmark step that was supposed to produce this repo's own patch-rebuild number had a bug comparing `dyndrv-freetype` against itself, fixed alongside this remeasurement). |
| freetype | version bump (3 files) | 6/45 | 18.24s vs 52.01s | **0.35x** | Same cause, smaller magnitude (dyn-drvs number, not re-measured here). |
| giflib | cold build | -- | pass | -- | `dyndrv-giflib` builds clean end to end. Plain Makefile, `ar`-based static lib -- no `cc`-driven link step, so it doesn't exercise the discoverTree link-step bug. |
| tree | cold build | -- | pass | -- | `dyndrv-tree` builds clean end to end. Plain hand-written Makefile, no configure/cmake, real `bin/tree` verified runnable. |
| figlet | cold build | -- | pass | -- | `dyndrv-figlet` builds clean end to end. Plain hand-written Makefile, no configure/cmake, real `bin/figlet` verified runnable. |
| nnn | cold build | -- | pass | -- | `dyndrv-nnn` builds clean end to end, including nixpkgs' `makeWrapper`-generated shell shim. Plain hand-written Makefile, no configure/cmake. |
| tinycbor | cold build | **BLOCKED** | -- | -- | This flake's pinned nixpkgs (26.05) ships tinycbor 7.0, a cmake build: every real TU compile fails with `cc1: fatal error: /build/source/src/*.c: No such file or directory` -- the same discoverTree cmake-source-path bug as xxHash/re2 below. (An older, qmake-based tinycbor 0.6.1 from a different nixpkgs channel built cleanly during initial spot-checking, including cc-driven `.so`/executable links -- but that's not what this repo's pin actually resolves to.) See `nix/packages/tinycbor.nix`. |
| zstd | cold build | **BLOCKED** | -- | -- | Original link-step bug (empty `inputs.drvs` on a `cc`-driven link) is fixed upstream (dyn-drvs 26cf7b9). Still hits the cmake-source-path bug: every real per-TU compile fails with `cc1: fatal error: /build/source/<file>: No such file or directory` -- same bug as xxHash/re2/tinycbor below, still open. Two other bugs also fixed here (gen_html self-exec, a CMake compiler-flag-probe false positive). Details in `nix/packages/zstd.nix`. |
| mosh | cold build | **BLOCKED** | -- | -- | Original autoreconfHook phase-dropping bug is fixed upstream (dyn-drvs 8aa6b86) -- `configurePhase`/`buildPhase` now run for real, `mosh-client`/`mosh-server` link and install correctly. Now blocked by a different, new bug: `postInstall` (`wrapProgram $out/bin/mosh`) runs as part of nixpkgs' `installPhase` itself, but `phases.split`'s `dyndrvRestoreOutput` phase (copies the placeholder-rooted tree into the real `$out`) is inserted AFTER `installPhase`, so `wrapProgram` looks for `$out/bin/mosh` before the restore ever runs. Details in `nix/packages/mosh.nix`. |
| openssl | Checkpoint A (baseline cold) | -- | pass, substituted | -- | Cold plain openssl-3.6.3 substitutes fully from cache.nixos.org. |
| openssl | Checkpoint B (accelerated evaluates/builds) | -- | **NO-GO** | -- | Fails at eval time: `error: attribute 'finalPackage' missing`. `mkAcceleratedStdenv`'s `finalAttrs` shim doesn't inject `finalPackage` the way nixpkgs' `makeOverridable` does; openssl's recipe reads `finalAttrs.finalPackage.doCheck` at 3 call sites. freetype never hits this since it doesn't reference `finalPackage`. Details in `nix/packages/openssl.nix`. |
| openssl | Checkpoint C (argv inspection) | -- | NOT REACHED | -- | Blocked by B's eval-time failure; the `-DOPENSSLDIR=`/placeholder risk remains untested. |
| openssl | Checkpoint D (patch rebuild count) | -- | NOT REACHED | -- | Gated on C. |

## nix-ninja mechanism (`mkMesonPackage`)

| Package | Scenario | Notes |
|---|---|---|
| argp-standalone (meson, 7 C files) | cold build | `nixninja-argp` builds real `libargp.a`, verified via `ar t` listing all 7 real `.o` translation units. No configure script, no cmake -- meson+ninja only, closest analog to giflib/tree/figlet's "plain build system" simplicity. |

## drowse mechanism (`callPackage`)

| Package | Scenario | Notes |
|---|---|---|
| hello | cold build | `drowse-hello` builds a real, runnable `bin/hello` (verified: prints "Hello, world!"). Uses drowse's own tested example (`tests/hello.nix`) verbatim. Distinct mechanism from the other three: defers the whole package's *evaluation* into a nested `nix-instantiate` (recursive-nix), rather than splitting an already-evaluated package's *build* into checkpoints -- demonstrating "avoid IFD" rather than "fine-grained per-TU caching." |

## Findings fed back to dyn-drvs

Four bugs in `accelerate.mkAcceleratedStdenv`/`phases.split`, beyond what
its own freetype proof point exercises. Not fixed here (would mean
patching dyn-drvs' source); documented in the relevant
`nix/packages/*.nix` header:

1. **CMake compiler-flag probes aren't passthrough-eligible** (zstd) --
   `check_c_compiler_flag`/`check_cxx_compiler_flag` don't follow
   autoconf's `conftest` naming convention, so a deferred shim stub
   always "succeeds," which can falsely enable unsupported flags.
2. **`autoreconfHook` phase injection is silently dropped** (mosh) --
   `phases.split`'s static `sandboxedPhases` list overrides nixpkgs'
   dynamic `$phases` computation, discarding any setup-hook's
   `appendToVar preConfigurePhases ...`. No workaround without a new
   `mkAcceleratedStdenv`-level parameter.
3. **`discoverTree`'s `-M -MG` scan can't see link-step inputs** (zstd)
   -- `.o`/`-o <exe>` args make gcc treat the invocation as a no-op link
   with nothing to discover, so a `cc`/`c++`-driven link step's object
   files are never staged or resolved (empty `inputs.drvs`). Confirmed a
   second and third time on pcre2 (libtool) and mpfr (libtool) -- but not
   universal: an older qmake-based tinycbor 0.6.1 build (from a different
   nixpkgs channel than this repo's pin) had `cc`/`c++`-driven `.so`/
   executable links that built fine, so it's specific to some invocation
   shapes, not "any cc-driven link."
4. **`finalAttrs.finalPackage` self-reference missing** (openssl) --
   `mkAcceleratedStdenv`'s custom `mkDerivation` supports the
   `finalAttrs: {...}` call convention but doesn't provide the
   `finalPackage` attribute nixpkgs' `makeOverridable` injects, which
   real packages (openssl, likely others) read.

Every tier attempted beyond freetype found a distinct, previously-unknown
gap -- `mkAcceleratedStdenv` generalizes less readily than its README
implies.

## Wider package survey (xxHash, re2, libb64, mpfr, tinycbor, libpng, libtasn1, gperf)

A follow-up sweep against more nixpkgs packages, beyond the ones wired
into this flake's outputs, turned up five distinct new failure modes
plus a repeat confirmation of a known one (findings not wired into
flake outputs; not package-fixable at this layer):

- **xxHash: FAIL, new bug.** Every real TU compile fails identically:
  `cc1: fatal error: /build/source/xxhash.c: No such file or directory`.
  nixpkgs builds xxHash via cmake on a `build/cmake` subdirectory one
  level below the sources; `discoverTree`'s per-TU sandbox doesn't
  resolve the cmake-relative source path correctly for this layout.
- **tinycbor: same cmake-source-path bug against this repo's actual
  nixpkgs pin.** Wired into this flake as `dyndrv-tinycbor` (see table
  above) -- BLOCKED, not a pass, once checked against the pinned
  nixpkgs's real (cmake-based, v7.0) recipe.
- **re2: FAIL, new bug.** 20 of ~51 compile-unit derivations fail with
  `cc1plus: fatal error: <src>.cc: No such file or directory` -- at the
  *compile* step, not link, and for real primary source files, not
  headers. Doesn't match any of the four bugs above; looks like a
  cmake+ninja-specific variant of source materialization failing for
  some compile invocations.
- **libb64: FAIL, new bug.** Compiles and links cleanly (giflib-like `ar`
  path plus direct `gcc`/`g++` links, neither hits bug #3) but fails at
  `make[1]: *** [Makefile:36: test-c-example1] Error 126` -- the
  just-linked example binary lacks its executable bit, and the upstream
  Makefile's self-test runs it immediately after linking. Looks like a
  file-mode/permission-bit gap specific to discoverTree's link-output
  handling.
- **mpfr: FAIL, confirms known bug #3** (`.libs/*.o` not found at the
  `libmpfr.so` link step, identical shape to pcre2).
- **libpng, libtasn1: FAIL, same new bug on both.** Fails immediately at
  phase 1 setup, before any compile runs: `error: _assignFirst: could
  not find a non-empty variable whose name to assign to outputMan. The
  following variables were all unset or empty: man dev`. Both packages'
  real nixpkgs recipes set `outputBin = "dev";` explicitly;
  `phases.split` forces phase 1 to single-output but doesn't clear that
  inherited literal override, so nixpkgs' own multi-output bookkeeping
  looks for a `$dev`/`$man` that was never exported. Independently
  reproduced. Likely affects any package that sets `outputBin`/
  `outputMan`/`outputDev` explicitly -- a common pattern for small
  libraries whose only binary is a dev-only helper.
- **gperf: FAIL, new bug.** Gets much further than libpng/libtasn1: real
  per-TU compiles succeed, then every single one fails at the very next
  Makefile line: `mv: cannot stat '.deps/hash.Tpo': No such file or
  directory`. Automake's classic depcomp idiom (`-MD -MP -MF
  .deps/$*.Tpo` alongside `-c -o $@`) writes a SECOND file per compile
  invocation that dyn-drvs doesn't track or stage back -- only the
  primary `-o` output round-trips out of the per-TU sandbox. Independently
  reproduced. Extremely common pattern across autotools C/C++ projects.

Eight for eight of the packages above hit an autotools- or cmake-shaped
bug. The common factor in every actual PASS so far (giflib, tree,
figlet, nnn) is a plain, hand-written Makefile with no `configure`
script and no cmake -- the autotools depcomp idiom and cmake's
generated build systems are both, independently, landmines for this
mechanism as currently implemented.

## The break-even lesson

Per-TU acceleration pays off only when per-unit compile cost is high
enough to amortize the registration tax (~80ms/derivation for
`nix derivation add`, per dyn-drvs' `registration-overhead.sh`). A 30-file
synthetic library with real per-file compile weight shows a 2.90x win;
the same mechanism against freetype's small, fast-compiling TUs shows a
~6.7x loss (measured directly here, cold build). Both TU count and
per-unit compile cost matter -- wins and losses don't generalize by
mechanism alone.

## How to reproduce

```console
$ ./benchmarks/patch-rebuild.sh packages.x86_64-linux.dyndrv-openssl-baseline \
    packages.x86_64-linux.dyndrv-openssl
```

See `benchmarks/patch-rebuild.sh`'s header for usage, and
`try-it-out/run-nix.sh` for how the `builder-rpc-v0`-capable Nix gets
bootstrapped.
