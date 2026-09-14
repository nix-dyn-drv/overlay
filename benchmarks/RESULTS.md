# Benchmark results

Numbers this repo's README cites. All measured on a specific machine;
losses are reported alongside wins.

Two mechanisms compared:

- **nixgg's `splitStdenv`/`dynDrvStdenv`** -- Go-based shim, already proven
  at nixpkgs scale (`openssl`/`openssl-3_5`/`hello`/`mosh`/`zstd` outputs).
- **dyn-drvs' `accelerate.mkAcceleratedStdenv`** -- Nix-language library
  (`dyndrv-*` outputs). See `nix/packages/*.nix` headers for per-package
  status.

## nixgg mechanism (`splitStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock | Notes |
|---|---|---|---|---|
| openssl (~2200 TUs) | one-file patch (`crypto/mem.c`) | 2/2213 | -- | From nixgg's README; not re-measured here. |
| openssl | version bump (3.6.3->3.5.7) | 2153/2192 (98%) | -- | Version baked into `opensslv.h`, included nearly everywhere. |
| openssl, hello, mosh, zstd | cold build | -- | -- | All four build cleanly end to end in CI (`.github/workflows/ci.yml`, real `/nix/store`, real per-TU `tu-*.o.drv` derivations submitted). |

## dyn-drvs mechanism (`accelerate.mkAcceleratedStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock (plain vs accelerated) | Speedup | Notes |
|---|---|---|---|---|---|
| freetype (~45 TUs) | one-file patch | 2/45 | 4.43s vs 78.86s | **0.06x (17x slower)** | `dyndrv-freetype` builds real `libfreetype.so`, 93 dynamic derivations registered. Per-TU compile cost too small to amortize the ~80ms/derivation registration tax (known loss, dyn-drvs BASELINE.md). |
| freetype | version bump (3 files) | 6/45 | 18.24s vs 52.01s | **0.35x** | Same cause, smaller magnitude (dyn-drvs number, not re-measured here). |
| giflib | cold build | -- | pass | -- | `dyndrv-giflib` builds clean end to end. Plain Makefile, `ar`-based static lib -- no `cc`-driven link step, so it doesn't exercise the discoverTree link-step bug. |
| tinycbor | cold build | **BLOCKED** | -- | -- | This flake's pinned nixpkgs (26.05) ships tinycbor 7.0, a cmake build: every real TU compile fails with `cc1: fatal error: /build/source/src/*.c: No such file or directory` -- the same discoverTree cmake-source-path bug as xxHash/re2 below. (An older, qmake-based tinycbor 0.6.1 from a different nixpkgs channel built cleanly during initial spot-checking, including cc-driven `.so`/executable links -- but that's not what this repo's pin actually resolves to.) See `nix/packages/tinycbor.nix`. |
| zstd | cold build | **BLOCKED** | -- | -- | `discoverTree` mode (used unconditionally by the `cc`/`c++` shim) runs `cc <args> -M -MG` to find extra paths to stage; on a link invocation `.o`/`-o <exe>` args make gcc treat it as unused linker input and print nothing, so `.o` inputs are never staged or resolved. Link derivations end up with empty `inputs.drvs` (confirmed via `nix derivation show`). Root-caused; two other bugs also fixed here (gen_html self-exec, a CMake compiler-flag-probe false positive). Details in `nix/packages/zstd.nix`. |
| mosh | cold build | **BLOCKED** | -- | -- | `dyndrv.phases.split`'s `sandboxedPhases` is a static list that omits `autoreconfHook`'s dynamically `appendToVar`'d `autoreconfPhase` (`configurePhase` logs "no configure script, doing nothing"). `mkAcceleratedStdenv` doesn't expose a `sandboxedPhases` override, so there's no package-level workaround; needs a dyn-drvs change. Details in `nix/packages/mosh.nix`. |
| brotli (~38 TUs, cmake, 3-output) | cold build | **BLOCKED** | -- | -- | Every real per-TU compile fails identically: `cc1: fatal error: /build/source/c/common/dictionary.c: No such file or directory`. Same `discoverTree` cmake-source-path bug as xxHash/re2/tinycbor below, now confirmed a fourth time -- and against the plainest possible cmake layout (in-tree cmake project, cmake+make generator, no out-of-tree `cmakeDir`, no custom target), ruling out several previously-suspected contributing factors. Confirmed directly via `nix derivation show`/`nix store ls -R` on the staged per-TU sandbox tree: it contains only an empty `./-I/build/source/c` directory (from the `-I` compiler flag being mis-staged as a path) and `CMakeFiles/...` bookkeeping -- the real `.c` sources were never staged. Details in `nix/packages/brotli.nix`. |
| openssl | Checkpoint A (baseline cold) | -- | pass, substituted | -- | Cold plain openssl-3.6.3 substitutes fully from cache.nixos.org. |
| openssl | Checkpoint B (accelerated evaluates/builds) | -- | **NO-GO** | -- | Fails at eval time: `error: attribute 'finalPackage' missing`. `mkAcceleratedStdenv`'s `finalAttrs` shim doesn't inject `finalPackage` the way nixpkgs' `makeOverridable` does; openssl's recipe reads `finalAttrs.finalPackage.doCheck` at 3 call sites. freetype never hits this since it doesn't reference `finalPackage`. Details in `nix/packages/openssl.nix`. |
| openssl | Checkpoint C (argv inspection) | -- | NOT REACHED | -- | Blocked by B's eval-time failure; the `-DOPENSSLDIR=`/placeholder risk remains untested. |
| openssl | Checkpoint D (patch rebuild count) | -- | NOT REACHED | -- | Gated on C. |

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

## Wider package survey (xxHash, re2, libb64, mpfr, tinycbor, brotli)

A follow-up sweep against more nixpkgs packages, beyond the ones wired
into this flake's outputs, turned up three more distinct failure modes
not seen before (findings not wired into flake outputs; not
package-fixable at this layer):

- **xxHash: FAIL, new bug.** Every real TU compile fails identically:
  `cc1: fatal error: /build/source/xxhash.c: No such file or directory`.
  nixpkgs builds xxHash via cmake on a `build/cmake` subdirectory one
  level below the sources; `discoverTree`'s per-TU sandbox doesn't
  resolve the cmake-relative source path correctly for this layout.
- **tinycbor: same cmake-source-path bug against this repo's actual
  nixpkgs pin.** Wired into this flake as `dyndrv-tinycbor` (see table
  above) -- BLOCKED, not a pass, once checked against the pinned
  nixpkgs's real (cmake-based, v7.0) recipe.
- **brotli: same cmake-source-path bug, fourth confirmed instance.**
  Wired into this flake as `dyndrv-brotli` (see table above) -- BLOCKED.
  Unlike xxHash (out-of-tree `build/cmake`) and re2 (cmake+ninja),
  brotli's cmake project is in-tree and uses the plain cmake+make
  generator, so this rules out "out-of-tree cmakeDir" and "ninja
  generator" as necessary conditions -- any cmake-generated absolute
  `/build/source/...` compile path seems to trip discoverTree's staging.
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

## The break-even lesson

Per-TU acceleration pays off only when per-unit compile cost is high
enough to amortize the registration tax (~80ms/derivation for
`nix derivation add`, per dyn-drvs' `registration-overhead.sh`). A 30-file
synthetic library with real per-file compile weight shows a 2.90x win;
the same mechanism against freetype's small, fast-compiling TUs shows a
17x loss. Both TU count and per-unit compile cost matter -- wins and
losses don't generalize by mechanism alone.

## How to reproduce

```console
$ ./benchmarks/patch-rebuild.sh packages.x86_64-linux.dyndrv-openssl-baseline \
    packages.x86_64-linux.dyndrv-openssl
```

See `benchmarks/patch-rebuild.sh`'s header for usage, and
`try-it-out/run-nix.sh` for how the `builder-rpc-v0`-capable Nix gets
bootstrapped.
