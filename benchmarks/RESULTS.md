# Benchmark results

Numbers this repo's README cites. All measured on a specific machine;
losses are reported alongside wins. Full bug narratives (repro, root
cause, fix commit) live in each package's `nix/packages/*.nix` header,
not duplicated here.

Four mechanisms compared, all implementing the same underlying Nix
feature (`builtins.outputOf`, dynamic derivations) independently:

- **nixgg's `splitStdenv`** -- Go-based shim, proven at nixpkgs scale
  (`openssl`/`openssl-3_5`/`hello`/`mosh`/`zstd` outputs).
- **dyn-drvs' `accelerate.mkAcceleratedStdenv`** -- Nix-language library
  (`dyndrv-*` outputs). See `nix/packages/*.nix` headers for per-package
  status.
- **nix-ninja's `mkMesonPackage`** -- drop-in `ninja` replacement
  (`nixninja-argp` output), reconstructs a meson build directly rather
  than overriding an existing package's stdenv.
- **drowse's `callPackage`** -- defers a whole package's *evaluation*
  into a nested `nix-instantiate` (via `recursive-nix`), not a per-TU
  *build* split (`drowse-hello` output). The "avoid IFD" half of the
  dynamic-derivations story.

## nixgg mechanism (`splitStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock | Notes |
|---|---|---|---|---|
| openssl (~2200 TUs) | one-file patch (`crypto/mem.c`) | 2/2213 | -- | From nixgg's README; not re-measured here. |
| openssl | version bump (3.6.3->3.5.7) | 2153/2192 (98%) | -- | Version baked into `opensslv.h`, included nearly everywhere. |
| openssl, hello, mosh, zstd | cold build | -- | -- | All four build cleanly end to end in CI (`.github/workflows/ci.yml`, real `/nix/store`, real per-TU `tu-*.o.drv` derivations submitted). |
| lua (~30 TUs, one archive) | build phase, unbatched vs `batchGroups` | 34 -> 2 derivations | 3.91s vs 2.29s | **1.71x**. `batchGroups` collapses 24 per-TU compiles + 1 `ar` step into a single `batch-liblua.a.drv`. Timed as build-phase-only (excludes one-time toolchain substitution, which is identical for both variants and swamps the signal if included -- a whole-`nix build` timing found only 1.02-1.07x). See `benchmarks/nixgg-batch-rebuild.sh`. |

## dyn-drvs mechanism (`accelerate.mkAcceleratedStdenv`)

| Package | Result | Notes |
|---|---|---|
| freetype (~45 TUs) | **0.15x cold build, 0.35x patch rebuild** | Per-TU compile cost too small to amortize the ~80ms/derivation registration tax. Re-measured directly (`benchmarks/patch-rebuild.sh dyndrv-freetype-baseline dyndrv-freetype`). |
| giflib, tree, figlet, nnn | **PASS** | Plain hand-written Makefiles, no configure/cmake -- the only packages that "just worked" with no bugs hit. |
| dav1d | **PASS** (fixed 227b1a6 + caa7c5d) | First meson package tried; hit `ar --version` probe crash, then a meson compiler-flag-probe misclassification. Both fixed upstream. |
| brotli | **PASS** (fixed 97a987d + 2cb6b4d) | cmake-source-path bug, then `__structuredAttrs = true` silently defeating the placeholder-output override. Both fixed upstream. |
| re2 (~51 TUs, cmake+ninja) | **PASS** (fixed 97a987d + 0d233d3) | Same cmake-source-path bug as tinycbor/zstd/brotli (cmake+ninja vs cmake+make was never the distinguishing factor), then a cmake+ninja-specific variant of the install-time regeneration bug. Both fixed upstream. |
| libssh | **PASS** (fixed 97a987d + e5f9a61 + bb1c077, 1 workaround) | cmake-source-path bug, linker version-script never staged (worked around via `-DWITH_SYMBOL_VERSIONING=OFF`), then a placeholder path baked into a copied cmake file. |
| protobuf | **PASS** (2 workarounds) | Self-exec of freshly-linked `protoc` hits the permanent exec-bit limitation (worked around: `-Dprotobuf_BUILD_TESTS=FALSE`); also hit libssh's version-script bug (worked around: `-Dprotobuf_HAVE_LD_VERSION_SCRIPT=FALSE`). |
| x265 (~99 TUs) | **PASS** (fixed 28af81d, 1 workaround) | `ar`/`ranlib` missing `inputs.drvs` (fixed), then a bare `-lx265-10`/`-lx265-12` link arg no resolution machinery can follow (worked around: `multibitdepthSupport = false`, drops HDR support -- still open at the dyn-drvs level, see `docs/showcase-remaining-open-findings.md` in dyn-drvs). |
| leveldb | **PASS** (fixed 97a987d + 0d233d3 + 1347c8c) | cmake-source-path bug, install-time cmake error, `postInstall` running before output restore. All fixed upstream. |
| x264 | **PASS** (2 workarounds) | `gcc-ranlib --version` LTO probe misclassified (postPatch skips it); single-output phase 1 loses real `$lib` content on restore (preFixup moves it manually). |
| libwebp (~171 TUs) | **PASS** (fixed 97a987d + 28af81d + dc07a0a) | Three sequential bugs: cmake-source-path, `ar` missing inputs, `-Wl,`-glued link.d path. All fixed upstream. |
| openjpeg | **PASS** (fixed 28af81d) | `ar`/`ranlib` never declared their own `.o` inputs as `inputs.drvs`. |
| capnproto | **PASS** (fixed 0d233d3) | Install-time cmake+make out-of-tree failure; also required `clangStdenv` (GCC ICEs on this package's C++20). |
| gperf (~20 TUs, autotools) | **PASS** (fixed 9dc8037) | Automake's `-MF .deps/$*.Tpo` depfile side-output never round-tripped out of the per-TU sandbox, so the following `mv` always failed. Fixed upstream by touching an empty depfile at defer time (content is irrelevant -- Nix always rebuilds from scratch). |
| libpng, libtasn1 | **BLOCKED** (1 bug fixed, 1 new bug found) | Both set `outputBin = "dev"` explicitly; `phases.split`'s forced single-output setup didn't clear that, crashing before any compile ran -- fixed upstream (0a8b174). With that fixed, every real compile succeeds, but the next link step (referencing libtool's plain, unversioned `.so` symlink rather than the real versioned `.so.N.N.N` file that's actually tracked) fails: `ld.bfd: cannot find ./.libs/libpng16.so`. New, still-open bug -- see `docs/libtool-so-symlink-bug.md` in dyn-drvs. |
| tinycbor, zstd | **BLOCKED** | This flake's pinned nixpkgs builds both via cmake, hitting the still-open cmake-source-path bug (`cc1: fatal error: /build/source/<file>: No such file or directory`). |
| mosh | **BLOCKED** | `autoreconfHook` phase-injection bug fixed (8aa6b86), but `postInstall`'s `wrapProgram` now runs before `phases.split` restores `$out` -- new, still-open bug. |
| openssl | **NO-GO at eval time** | `mkAcceleratedStdenv` doesn't provide `finalAttrs.finalPackage`, which openssl's recipe reads. Never reached the interesting `-DOPENSSLDIR=` risk. |

16 distinct bugs found beyond dyn-drvs' own freetype proof point; 12 fixed
upstream during this survey, 4 remain open (mosh's restore-ordering bug,
the cmake-source-path bug on tinycbor/zstd/xxHash, x265's bare
`-l<name>` link arg, libpng/libtasn1's libtool `.so`-symlink gap). Full
repro/root-cause/fix detail for each is in the relevant
`nix/packages/*.nix` header -- not duplicated here.

## Wider package survey (not wired into flake outputs)

A follow-up sweep against more nixpkgs packages, beyond what's wired into
this flake, for breadth of evidence:

| Package | Result |
|---|---|
| xxHash | FAIL -- cmake-source-path bug (same as tinycbor/zstd above). |
| libb64 | FAIL -- exec-bit limitation (same class as protobuf), on a plain Makefile self-test. |
| mpfr | FAIL -- confirms the discoverTree link-step gap (bug #3, same shape as pcre2). |

Every package tried outside the four hand-written-Makefile passes
(giflib/tree/figlet/nnn) hit an autotools- or cmake-shaped bug -- the
autotools depcomp idiom and cmake's generated build systems are both
landmines for `mkAcceleratedStdenv` as currently implemented.

## nix-ninja mechanism (`mkMesonPackage`)

`nixninja-argp` (meson, 7 C files) builds a real `libargp.a` (verified via
`ar t` listing all 7 real `.o` TUs) when it succeeds, but fails
intermittently in CI against the real `/nix/store`: ninja's own generated
install rule appears to write to a literal placeholder path
(`PermissionError: [Errno 13] Permission denied: '/nonexistent'`), not yet
root-caused. Not reproduced locally against the redirected alt-store;
marked informational/non-blocking in `ci.yml`.

## drowse mechanism (`callPackage`)

`drowse-hello` builds a real, runnable `bin/hello` using drowse's own
tested example (`tests/hello.nix`) verbatim. Demonstrates "avoid IFD"
rather than fine-grained per-TU caching, distinct from the other three
mechanisms.

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
