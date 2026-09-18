# Benchmark results

Numbers this repo's README cites. All measured on a specific machine;
losses are reported alongside wins. Full bug narratives (repro, root
cause, fix commit) live in each package's `nix/packages/*.nix` header,
not duplicated here.

Five mechanisms compared, all implementing the same underlying Nix
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
- **cargo-dyndrv's `buildDynamicCrate`** -- per-crate dynamic
  derivations for Rust (`hyperfine-cargo-dyndrv` output). The first
  mechanism in this survey targeting a language other than C/C++.

## Direct head-to-head: nixgg vs. dyn-drvs, same package, same edit

Every other number in this file measures ONE mechanism in isolation
(against plain `stdenv.mkDerivation`, or against itself
batched/unbatched) -- nothing before this compared nixgg's own
`splitStdenv`/`mkNixggBuild` against dyn-drvs' own
`accelerate.mkAcceleratedStdenv` on the SAME workload. This section is
that comparison.

**Workload**: real, unmodified Lua 5.4.7 (`https://www.lua.org/ftp/lua-5.4.7.tar.gz`,
34 real `.c` translation units), built via the IDENTICAL command both
sides' own fixtures already use (`cd src && make linux CC=cc` --
nixgg's own `examples/lua/default.nix`), then a one-line comment-only
edit to `src/lmathlib.c` (nixgg's own `tests/perf-regression.sh`
fixture, reused verbatim) rebuilt from a warm store.

**Methodology, controlling for confounds found during setup**:
- `--builders ''` on both sides -- without this, some builds route to
  a remote builder over SSH, adding large, highly variable network
  latency (confirmed directly: one run measured 27s with a remote
  builder in play vs. ~19s local-only for the identical rebuild).
  Wall-clock numbers below are LOCAL-ONLY.
- `--option substituters ''` on the timed rebuild only (matching each
  project's own existing perf test methodology --
  `tests/perf-regression.sh` for nixgg, `real-package-bench-lib.sh`
  for dyn-drvs) -- so a cache hit can't quietly substitute a
  derivation without it actually running, while still allowing the
  warm-up build beforehand to substitute freely.
- Each side's own one-time patched-Nix substitution (`nix build
  .#patched-nix` for nixgg, `try-it-out/patched-nix.nix` for dyn-drvs)
  and the initial cold `.#lua`-equivalent build are OUTSIDE the timed
  window -- only the patch-rebuild itself is timed, matching both
  projects' own existing benchmark conventions.
- 3-4 independent runs each, fresh alt store per run (a shared store
  would just substitute the SAME already-built output on repeat runs,
  timing nothing).

| Mechanism | Run 1 | Run 2 | Run 3 | Run 4 | Mean | Derivations rebuilt |
|---|---|---|---|---|---|---|
| nixgg (`mkNixggBuild`) | 7.99s | 8.11s | 8.05s | -- | **8.05s** | 4 (`lua-src-edited`, `nixgg-0`, `nixgg-lua`, `tu-lmathlib.o`) |
| dyn-drvs, bash shim (default) | 19.86s | 30.90s | 21.22s | 18.87s | **22.71s** | 5 (`lua-5.4.7-edited`, `lua-bench.drv.drv`, `dyndrv-src_lmathlib_o`, `lua-bench.drv`, `lua-bench` [replay]) |
| dyn-drvs, compiled shim (`dyndrvShim`) | 8.10s | 9.01s | 6.53s | -- | **7.88s** | 5 (same shape, different naming convention) |

**With dyn-drvs' default (bash `toNodeBash`/`collectStubs`) shim, nixgg
is ~2.8x faster** on this identical one-file patch rebuild, and roughly
3-4x more consistent run-to-run (dyn-drvs' 30.90s outlier vs. its own
18.87s best run is a much wider spread than nixgg's tight 7.99-8.11s
band).

**With dyn-drvs' COMPILED shim (`dyndrvShim`, `rust/dyndrv-shim.nix`,
passed via `dyndrvShimPath`), the gap disappears entirely** -- 7.88s
mean vs. nixgg's 8.05s, essentially a tie. This was root-caused by
DIRECT INVESTIGATION of the initial hypothesis, then disproven and
re-tested:

- **Initial (WRONG) hypothesis**: the extra `lua-bench` "replay"
  derivation (5 `building '...'` lines vs. nixgg's 4 -- dyn-drvs'
  `phases.split` architecture runs a sandboxed `builder-rpc-v0` phase
  1, THEN an ordinary phase 2 derivation that reruns `installPhase`/
  `fixupPhase` against phase 1's resolved output) was assumed to be
  the cause. Investigation showed this derivation-count difference is
  REAL but not the actual driver of the wall-clock gap: nixgg's OWN
  general-purpose mechanism (`splitStdenv`, not the narrower
  `mkNixggBuild` this benchmark's `.#lua` output actually uses) pays
  the IDENTICAL extra "assemble tree" + "replay install/fixup"
  registration round-trip, for the identical structural reason (an
  ordinary, eval-time-constructed derivation can't declare a
  dependency on a drvPath only discovered at build time inside the
  sandbox). `examples/lua/default.nix` uses the lighter
  `mkNixggBuild`, which never models `installPhase`/`fixupPhase`/
  multi-output splitting at all -- an apples-to-oranges comparison on
  derivation count specifically, though the WALL-CLOCK numbers
  themselves are still a fair, real comparison of "what each project
  ships as its own easiest path to accelerate a package."
- **Actual cause**: dyn-drvs' DEFAULT shim path (`toNodeBash`,
  `nix/lib/shim/wrapCommand.nix`'s bash wrapper script) spawns
  `nix-instantiate`/`jq`/`nix` CLI subprocesses PER intercepted `cc`/
  `ar` invocation. nixgg's Go shim talks to the sandbox over a
  persistent RPC connection instead of per-call fork+exec
  (`NIXGG_RPC=1`, per its own `dynDrvShared.nix` comment). dyn-drvs'
  own compiled shim (`rust/dyndrv-shim`, wired via the SAME
  `dyndrvShim`/`dyndrvShimPath` parameter `try-it-out/benchmarks/
  real-package-patch-rebuild.sh` already uses to re-measure this
  exact axis) exists for precisely this reason and, once actually
  measured against nixgg here, closes the gap completely.

**Practical implication**: dyn-drvs' default bash shim path is fine
for correctness/prototyping, but the compiled `dyndrvShim` path is the
one to use whenever wall-clock matters -- confirmed via this benchmark
to be the dominant factor, not `phases.split`'s own extra
registration round-trip (which is real, but small: ~80ms/call per
`registration-overhead.sh`, nowhere near enough to explain a
multi-second gap on its own).

**Caveat**: this is ONE fixture (lua, 34 small/fast-compiling TUs) on
ONE machine, with real run-to-run variance observed on both sides
(nixgg's own `mkNixggBuild` path spiked to 16.46s in one later,
single-sample automated run, vs. its own 7.99-8.11s band across the 3
manual runs above -- machine noise cuts both ways, not just against
dyn-drvs). Per this file's own "break-even lesson" below, per-TU
acceleration's wall-clock outcome depends heavily on per-unit compile
cost vs. registration overhead -- a heavier-per-TU package might shift
this further in either direction. Reproduce via
`benchmarks/nixgg-vs-dyndrv-lua-bench.sh DYNDRV_SHIM=1` (see "How to
reproduce" below) before drawing conclusions beyond this one workload.

## nixgg mechanism (`splitStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock | Notes |
|---|---|---|---|---|
| openssl (~2200 TUs) | one-file patch (`crypto/mem.c`) | 2/2213 | -- | From nixgg's README; not re-measured here. |
| openssl | version bump (3.6.3->3.5.7) | 2153/2192 (98%) | -- | Version baked into `opensslv.h`, included nearly everywhere. |
| openssl, hello, mosh, zstd | cold build | -- | -- | All four build cleanly end to end in CI (`.github/workflows/ci.yml`, real `/nix/store`, real per-TU `tu-*.o.drv` derivations submitted). |
| lua (~30 TUs, one archive) | build phase, unbatched vs `batchGroups` | 34 -> 2 derivations | 3.91s vs 2.29s | **1.71x**. `batchGroups` collapses 24 per-TU compiles + 1 `ar` step into a single `batch-liblua.a.drv`. Timed as build-phase-only (excludes one-time toolchain substitution, which is identical for both variants and swamps the signal if included -- a whole-`nix build` timing found only 1.02-1.07x). See `benchmarks/nixgg-batch-rebuild.sh`. |
| libb64 (self-exec mid-build) | two-phase split vs dyn-drvs' single-buildPhase limit | -- | -- | **PASS**, contrasting with dyn-drvs' permanent limitation on the SAME package (`discovertree-exec-bit-bug.md`). A one-phase `mkNixggBuild` hits the identical wall dyn-drvs does (`Permission denied` execing a just-linked, still-deferred binary) -- nixgg's own DESIGN.md names this "the synchronous-realize wall," inherent to `builder-rpc-v0` having no synchronous build op. But nixgg's two-phase pattern (phase 2 = an ORDINARY `stdenv.mkDerivation`, not another `mkNixggBuild`, with `buildInputs` forcing phase 1 to resolve to real bytes first) sidesteps it entirely: phase 1 accelerates libb64's 2 real per-TU compiles into their own dynamic derivations; phase 2 links `c-example1` against the real, resolved `libb64.a` and runs it directly. Confirmed via the build log's own real output (`encoded: aGVsbG8gd29ybGQ=` / `decoded: hello world`, not a stub). Real caveat: this only works because libb64's self-exec has a clean phase boundary reachable via `buildInputs` -- nixgg's own DESIGN.md is explicit that a build whose synchronous read-back is interleaved with acceleration-needing work on BOTH sides of that boundary remains unsolved even for nixgg. See `nix/packages/libb64-nixgg.nix`. |

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
| x265 (~99 TUs) | **PASS** (fixed 28af81d + task #149 + task #150, 1 workaround) | Four sequential bugs: `ar`/`ranlib` missing `inputs.drvs` (fixed), a bare `-lx265-10`/`-lx265-12` link arg (fixed, task #149), the sibling `build-10bits`/`build-12bits` cmake trees' own stubs never discovered at all (fixed, task #150). With all three fixed, full `multibitdepthSupport` (10/12-bit HDR) now builds -- `multibitdepthSupport = false` is no longer needed. Remaining workaround: a `preConfigure` override that reconstructs real bash arrays for `cmakeFlags`/`cmakeStaticLibFlags`, since `phases.split`'s forced `__structuredAttrs = false` silently flattens them into space-joined strings, which x265's own `"${cmakeStaticLibFlags[@]}"` usage then mis-expands as one argument -- a structural conflict, not a dyn-drvs bug (see `nix/packages/x265.nix`'s own header for the full analysis). |
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

17 distinct bugs found beyond dyn-drvs' own freetype proof point; 14 fixed
upstream during this survey, 3 remain open (mosh's restore-ordering bug,
the cmake-source-path bug on tinycbor/zstd/xxHash, libpng/libtasn1's
libtool `.so`-symlink gap). Full repro/root-cause/fix detail for each is
in the relevant `nix/packages/*.nix` header -- not duplicated here.

## Wider package survey (not wired into flake outputs)

A follow-up sweep against more nixpkgs packages, beyond what's wired into
this flake, for breadth of evidence:

| Package | Result |
|---|---|
| xxHash | FAIL -- cmake-source-path bug (same as tinycbor/zstd above). |
| libb64 | FAIL -- exec-bit limitation (same class as protobuf), on a plain Makefile self-test. **Contrast**: nixgg's two-phase split PASSES on this exact package -- see the nixgg-mechanism table above (`libb64-nixgg`). |
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

## cargo-dyndrv mechanism (per-crate dynamic derivations for Rust)

Fifth independent mechanism in this survey, and the first targeting a
language other than C/C++: [cargo-dyndrv](https://github.com/obsidiansystems/cargo-dyndrv)
turns Cargo's own unit graph into one dynamic derivation per crate
(the direct Rust equivalent of nixgg/dyn-drvs' per-translation-unit
splitting, since Cargo's compilation unit is the crate, not the file).
Same `builtins.outputOf`/`builder-rpc-v0` primitive as the other four
mechanisms; confirmed working via this repo's own `try-it-out/run-nix.sh`
bootstrap with no modification needed.

| Package | Result | Notes |
|---|---|---|
| cargo-dyndrv (self-build, ~50 crates) | **PASS** | `cargo-dyndrv-dyn` builds itself via its own mechanism, real per-crate dynamic derivations, genuine ELF binary confirmed. |
| hyperfine (~173 crates, real nixpkgs package) | **BLOCKED** | Picked for a clean first attempt: zero external C buildInputs (no pkg-config/extern.json wiring, unlike e.g. ripgrep's `pcre2` dependency), plain filesystem-only `build.rs`. Blocked anyway: compiling `portable-atomic`'s own build script (a transitive dependency via `indicatif`, hyperfine's ordinary, non-optional progress-bar library) fails with `environment variable 'CARGO_PKG_NAME' not defined at compile time` -- root-caused directly in cargo-dyndrv's own source (`add_metadata_env` in `cargo-dyndrv/src/main.rs`): it populates `CARGO_PKG_VERSION` and its `MAJOR`/`MINOR`/`PATCH`/`PRE` components for a build-script invocation, but not `CARGO_PKG_NAME` -- the function's own trailing comment, `// TODO: more of these`, is an acknowledged, not-yet-filled gap. No package-level workaround: `portable-atomic` is a transitive, non-optional dependency, and `env!("CARGO_PKG_NAME")` is a common, standard idiom in real `build.rs` scripts -- likely blocks a large fraction of real-world crate graphs, not just this one package. Details in `nix/packages/hyperfine-cargo-dyndrv.nix`.

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

For the direct nixgg-vs-dyndrv head-to-head above:

```console
$ DYNDRV_ROOT=~/dyn-drvs NIXGG_ROOT=~/nixgg ./benchmarks/nixgg-vs-dyndrv-lua-bench.sh
# add DYNDRV_SHIM=1 to measure dyn-drvs' compiled shim path instead of
# its default bash path -- this is the axis that actually explains the
# gap, see the section above
```

See that script's own header for the full methodology (why `--builders
""`/`--option substituters ""` matter, what's timed vs. excluded as
one-time setup).
