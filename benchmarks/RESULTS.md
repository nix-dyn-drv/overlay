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
| protobuf | cold build | all TUs compiled+linked | **PASS** (with 2 package-level workarounds) | -- | cmake, ~221 TUs, real cross-package deps (gtest/zlib/abseil-cpp). Originally BLOCKED: protobuf's own build re-executes its freshly-linked `protoc` binary directly (`./protoc`) as a code generator for every `.proto` file in its OWN test suite; every invocation failed with `bash: ./protoc: Permission denied` / `Error 126`, cascading into a full `make` failure. Same root cause as the already-documented discoverTree exec-bit bug (libb64), later root-caused by dyn-drvs 5468402 as a permanent architectural limitation, not a fixable bug. **Worked around**: `-Dprotobuf_BUILD_TESTS:BOOL=FALSE` (a real, upstream cmake option) skips the whole `cmake/tests.cmake`/`upb-test` code path that self-execs `protoc`, entirely avoiding the bug -- loses nothing this survey was already exercising (`doCheck` already disabled). With that fixed, hit libssh's exact linker-script staging bug next (`ld.bfd: cannot open linker script file .../libprotobuf.map`). **Also worked around**: `-Dprotobuf_HAVE_LD_VERSION_SCRIPT:BOOL=FALSE` pre-seeds the CMake cache variable protobuf's own `check_linker_flag` probe would otherwise set, skipping the probe and the `-Wl,--version-script=...` link flag entirely. Confirmed with BOTH workarounds together: `dyndrv-protobuf` builds clean end to end -- real `libprotobuf.so.36.1.0`/`libprotoc.so.36.1.0`/`protoc` all verified as genuine ELF binaries. Details in `nix/packages/protobuf.nix`. |
| x265 (~99 TUs) | cold build | all TUs compiled+linked | **PASS** (fixed by dyn-drvs 28af81d, worked around `multibitdepthSupport`) | -- | Originally reported INCONCLUSIVE (a pre-existing plain-nixpkgs nasm `label-redef-late` error assembling `common/x86/intrapred16.asm`, confirmed by an A/B rebuild independent of `mkAcceleratedStdenv`). Retested and that nasm error did NOT recur -- all ~92 real `.asm.o` files (including `intrapred16.asm`) now assemble successfully. Then genuinely BLOCKED by the ar/ranlib `inputs.drvs` gap (same bug as libwebp/openjpeg: `ar: /nix/store/<hash>-analysis.cpp.o: No such file or directory`), **FIXED by dyn-drvs 28af81d** -- confirmed both `libx265_a.a`/`libhdr10plus_a.a` archive steps now succeed for real. Then blocked by a third, distinct bug: the `libx265.so` shared-lib link failed with `ld.bfd: cannot find -lx265-10: No such file or directory` / `cannot find -lx265-12`. Unlike every other bug found in this survey's `ar`/`cc` shims, this one isn't a literal store-path argv token that went unresolved -- x265's cmake build links its 10-bit/12-bit encoder variants via a bare `-Wl,-Bstatic -lx265-10 -lx265-12` (search-path-relative `-l<name>`, not a full path), which none of discoverTree/extraStorePaths/28af81d's scanning machinery has any way to resolve back to the dynamic derivation that will produce those `.a` files. Confirmed still open against dyn-drvs dc07a0a/1347c8c/e5f9a61/5468402 (the latest pushed commit as of this retest). **Worked around** at the package level: nixpkgs' `x265` recipe exposes `multibitdepthSupport` (default `true`) as an override parameter -- `multibitdepthSupport = false` disables the whole multi-bitdepth cmake path that bakes in the `-lx265-10`/`-lx265-12` linkage, avoiding the bug entirely. Confirmed: with this flag, real per-TU compiles, both `ar` archive steps, and the final `.so` link all succeed, producing a genuine `libx265.so.216`. Trade-off: drops 10-bit/12-bit HDR encoding support, a real feature loss (unlike libssh/protobuf's workarounds, which only disabled auxiliary/test machinery). Details in `nix/packages/x265.nix`. |
| leveldb (~39 real TUs) | cold build | all TUs compiled+linked | **PASS** (fixed by dyn-drvs 97a987d + 0d233d3 + 1347c8c) | -- | Original cmake-source-path bug (every real per-TU compile failing with `cc1plus: fatal error: db/c.cc: No such file or directory`, a fourth confirmed instance) is fixed upstream (dyn-drvs 97a987d) -- confirmed all 39 real per-TU compiles now succeed, plus `make install` (cmake+make's own install-time error, separately fixed by dyn-drvs 0d233d3, also doesn't recur). Was then blocked by a second confirmation of the already-documented `split-postinstall-before-restore-bug.md`: leveldb's `postInstall` runs `substituteInPlace "$out"/lib/cmake/leveldb/leveldbTargets.cmake ...`, which failed with `substitute(): ERROR: file '.../leveldbTargets.cmake' does not exist` -- `postInstall` fires inside nixpkgs' `installPhase` itself, strictly before `phases.split`'s `dyndrvRestoreOutput` phase copies the placeholder-rooted tree into the real `$out`. Confirmed still open against dyn-drvs dc07a0a (unrelated to that fix's `-Wl,`-unglue mechanism). **FIXED upstream in dyn-drvs 1347c8c** ("Fix phases.split: dyndrvRestoreOutput ran too late for postInstall reading $out (task #140)") -- confirmed directly: `dyndrv-leveldb` now builds clean end to end, real `libleveldb.so.1.23.0` verified as a genuine ELF binary, and the previously-missing `leveldbTargets.cmake` now exists in the real `-dev` output. Details in `nix/packages/leveldb.nix`. |
| x264 | cold build | -- | pass (with 2 package-level workarounds) | -- | Autotools-style `./configure` + hand-written Makefile (NOT cmake -- explicitly ruled out ahead of time as a cmake candidate, tried anyway per instruction). Hit two NEW dyn-drvs bugs: (1) x264's own `configure` probes `gcc-ranlib --version`/`gcc-ar --version` for LTO-plugin detection, and the `ar`/`ranlib` shims (unlike `cc`'s) have no info-query passthrough, so the probe gets deferred and misparses `--version` as the archive-to-ranlib-in-place, registering a bogus `dyndrv-__version` stub that fails outright; (2) once patched around, real compiles and a real `cc`-driven `libx264.so.165` link both succeed (notably NOT hitting the open zstd/pcre2/mpfr discoverTree link-step bug), but `phases.split`'s single-output phase 1 makes nixpkgs' own `multiple-outputs.sh` fall back `outputLib -> out`, so x264's real `--libdir` content lands under phase 1's `$out/lib` and `dyndrvRestoreOutput`'s `_multioutDevs`/`_multioutDocs` calls never redistribute it into the real `$lib` output, so `$lib` is never created. Both worked around at the package level (postPatch to skip the probe, preFixup to move `$out/lib` into `$lib/lib`); real, runnable `bin/x264` confirmed (`x264 --version`). RETESTED against dyn-drvs 227b1a6/97a987d: still pass, both workarounds still required -- 227b1a6's own `isProbe` fix doesn't cover x264's specific `gcc-ranlib --plugin <path> --version` probe shape (the plugin path is itself a non-flag positional argument). Details in `nix/packages/x264.nix`. |
| libwebp (~171 TUs) | cold build | all TUs compiled+linked | **PASS** (fixed by dyn-drvs 97a987d + 28af81d + dc07a0a) | -- | Single-output, cmake build -- picked specifically to dodge the multi-output gaps (openssl/libpng). Hit THREE distinct, sequentially-uncovered bugs on the way to a real pass: (1) cmake-source-path bug (every real TU compile failing identically, e.g. `cc1: fatal error: /build/source/examples/dwebp.c: No such file or directory`), fixed by dyn-drvs 97a987d; (2) `ar`/`ranlib` archive step failing with `ar: /nix/store/<hash>-example_util.c.o: No such file or directory` (`inputs.drvs = {}`, same shape as openjpeg), fixed by dyn-drvs 28af81d; (3) a `cc -shared` link step failing with `ld.bfd: cannot open dependency file CMakeFiles/webpdecoder.dir/link.d: No such file or directory` (wrapCommand's output-dirname precreation not unglueing `-Wl,`-style flags first), fixed by dyn-drvs dc07a0a. Retested against dc07a0a: `dyndrv-libwebp` now builds clean end to end -- real `libwebp.so.7.2.0`/`bin/cwebp`/`bin/dwebp` etc, verified as genuine ELF binaries. See `nix/packages/libwebp.nix`. |
| openjpeg (~76 TUs, cmake, 2-output) | cold build | all TUs compiled+linked | **PASS** (fixed by dyn-drvs 28af81d) | -- | Retested against dyn-drvs 28af81d ("Fix ar shim: declare its own real .o/archive inputs as derivation deps"): `dyndrv-openjpeg` now builds clean end to end -- real `libopenjp2.so`/`bin/opj_decompress`/`bin/opj_compress`/etc, verified as genuine ELF binaries. Previously (last tested against dyn-drvs 0d233d3) every real per-TU compile succeeded but the first `ar`-driven static-lib link failed: `ar: /nix/store/<hash>-thread.c.o: No such file or directory`, `nix derivation show` confirming `inputs.drvs = {}` for the `ar` derivation -- `arToNode`/`ranlibToNode` never scanned their own positional args for resolved store paths the way `ccToNode`'s `extraStorePaths` already did; 28af81d fixes exactly this. Details in `nix/packages/openjpeg.nix`. |
| capnproto (~187 .c++ TUs) | cold build | all TUs compiled+linked | **PASS** (fixed by dyn-drvs 0d233d3) | -- | Retested against dyn-drvs 0d233d3 ("Fix phases.split cmake+make out-of-tree install failure (task #138)"): `dyndrv-capnproto` now builds clean end to end -- real `libkj.so`/`libcapnp.so`/`libcapnp-rpc.so`/`libkj-async.so`/etc and `bin/capnp`/`bin/capnpc-c++`/`bin/capnpc-capnp` all present, `capnp --version` prints `Cap'n Proto version 1.4.0`. Previously (as last tested against dyn-drvs 227b1a6) every real per-TU compile AND link succeeded (`buildPhase completed in 39 seconds`) but `installPhase` failed: `CMake Error: The source directory "/build/source" does not exist` / `make: *** [Makefile:383: cmake_check_build_system] Error 1` -- distinct from the compile-time discoverTree cmake-source-path bug (tinycbor/xxHash/re2): `phases.split`'s phase 2 forced `sourceRoot = "."`, so its `unpackPhase` never recreated the `/build/source` subdirectory cmake's own cached `CMAKE_HOME_DIRECTORY` (baked into `CMakeCache.txt` at phase 1 configure time) still pointed at -- the existing `dyndrvCdToBuildDir` reconstruction logic previously only triggered for meson's `build.ninja` marker, never for cmake+make; 0d233d3 generalizes it to cmake+make too. (Package itself still required a package-level workaround just to eval: nixpkgs' by-name `capnproto` takes a `clangStdenv` argument, not `stdenv`, since GCC ICEs on its C++20 coroutines -- worked around here by accelerating `clangStdenv` directly.) Details in `nix/packages/capnproto.nix`. |
| openssl | Checkpoint A (baseline cold) | -- | pass, substituted | -- | Cold plain openssl-3.6.3 substitutes fully from cache.nixos.org. |
| openssl | Checkpoint B (accelerated evaluates/builds) | -- | **NO-GO** | -- | Fails at eval time: `error: attribute 'finalPackage' missing`. `mkAcceleratedStdenv`'s `finalAttrs` shim doesn't inject `finalPackage` the way nixpkgs' `makeOverridable` does; openssl's recipe reads `finalAttrs.finalPackage.doCheck` at 3 call sites. freetype never hits this since it doesn't reference `finalPackage`. Details in `nix/packages/openssl.nix`. |
| openssl | Checkpoint C (argv inspection) | -- | NOT REACHED | -- | Blocked by B's eval-time failure; the `-DOPENSSLDIR=`/placeholder risk remains untested. |
| openssl | Checkpoint D (patch rebuild count) | -- | NOT REACHED | -- | Gated on C. |

## nix-ninja mechanism (`mkMesonPackage`)

| Package | Scenario | Notes |
|---|---|---|
| argp-standalone (meson, 7 C files) | cold build | `nixninja-argp` builds real `libargp.a` when it succeeds (verified via `ar t` listing all 7 real `.o` translation units), but fails intermittently against the real `/nix/store` in CI (not reproduced locally against the redirected alt-store): `PermissionError: [Errno 13] Permission denied: '/nonexistent'` -- looks like ninja's own generated "install" rule running and writing to `mkMesonPackage`'s literal placeholder path, not yet root-caused. Marked informational/non-blocking in `ci.yml` until understood. |

## drowse mechanism (`callPackage`)

| Package | Scenario | Notes |
|---|---|---|
| hello | cold build | `drowse-hello` builds a real, runnable `bin/hello` (verified: prints "Hello, world!"). Uses drowse's own tested example (`tests/hello.nix`) verbatim. Distinct mechanism from the other three: defers the whole package's *evaluation* into a nested `nix-instantiate` (recursive-nix), rather than splitting an already-evaluated package's *build* into checkpoints -- demonstrating "avoid IFD" rather than "fine-grained per-TU caching." |

## Findings fed back to dyn-drvs

Nine bugs in `accelerate.mkAcceleratedStdenv`/`phases.split`, beyond what
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
5. **A freshly-linked executable loses its execute bit under
   `discoverTree`** (protobuf) -- first found on libb64's small
   Makefile self-test (wider survey below), now confirmed on a wired-in
   flake output at real scale: protobuf's own build re-executes its
   just-linked `protoc` binary as a code generator for every `.proto`
   file in the tree, and every invocation fails with `Permission
   denied`/`Error 126`, taking down the whole build (not just an
   optional check step, since protoc's generated headers are required
   to compile). Confirms this bug generalizes across build systems
   (Makefile and cmake) and isn't specific to libb64's small case.
   ROOT-CAUSED in dyn-drvs 5468402 as a permanent architectural
   limitation, not a fixable bug: every deferred `cc`/`ar` invocation
   writes a plain placeholder text file that's only ever resolved into
   real code by `collectStubs`'s whole-build-tree pass at the very end
   of `buildPhase`, so a package that self-execs a binary it just
   linked, in the SAME `buildPhase` invocation, genuinely finds
   unresolved placeholder text, not a lost permission bit -- confirmed
   no permission-bit fix is possible. WORKED AROUND at the package
   level for protobuf specifically: `-Dprotobuf_BUILD_TESTS:BOOL=FALSE`
   skips the whole self-exec-during-build code path entirely (a real
   upstream cmake option, not a dyn-drvs fix) -- confirmed protobuf now
   builds clean end to end. Not every affected package will have an
   equivalent flag.
6. **`ar`/`ranlib` shims have no diagnostic-probe passthrough** (x264)
   -- `cc`'s shim recognizes `conftest`-named/CMake-scratch/info-query
   probes and runs them for real instead of deferring; `arShim`/
   `ranlibShim` have no equivalent, so a package whose own configure
   script probes `gcc-ar --version`/`gcc-ranlib --version` (a common
   LTO-plugin-detection idiom) gets a deferred stub that misparses
   `--version` as the archive argument, registering a nonsense
   derivation that fails outright. PARTIALLY FIXED upstream by dyn-drvs
   227b1a6 ("Fix ar/ranlib shims crashing/misclassifying on
   version-probe invocations") -- retested here after bumping to
   include it, and confirmed x264's own package-level `postPatch`
   workaround is still required: 227b1a6's `isProbe` heuristic treats
   any argv with a non-flag positional argument as "not a probe," but
   x264's actual invocation is `gcc-ranlib --plugin
   <path-to-liblto_plugin.so> --version` -- `--plugin`'s own value is a
   non-flag positional argument, so `isProbe` still misclassifies it,
   and the original failure (bogus `dyndrv-__version` stub, "No such
   file") still reproduces byte-for-byte with the `postPatch` removed.
7. **Single-output phase 1 loses real `outputLib`/etc. content on
   restore** (x264) -- `phases.split` forcing phase 1 to `outputs =
   ["out"]` makes nixpkgs' own `multiple-outputs.sh` fall back every
   output variable (including `outputLib`) to `"out"` during the real
   build, so content meant for a literal, non-fallback named output
   (e.g. `--libdir=$lib/lib`) physically lands under phase 1's `$out`
   instead. `dyndrvRestoreOutput`'s `_multioutDevs`/`_multioutDocs`
   calls only know how to redistribute doc/dev-shaped content (headers,
   pkgconfig, man/info/gtk-doc) into `$dev`/`$doc`/etc. -- neither
   redistributes ordinary library content into `$lib`, so that output
   is simply never created. A close cousin of bug already documented
   in `~/dyn-drvs/docs/split-outputbin-override-bug.md` (a scalar
   `outputBin` override reads a now-empty fallback variable and fails
   outright), but distinct: here the build doesn't fail at setup, it
   silently mis-routes real content and only fails much later, at
   Nix's own "failed to produce output path" check once `installPhase`
   already finished.
8. **`arToNode`/`ranlibToNode` never declare their own `.o`/archive
   inputs as `inputs.drvs`** (openjpeg) -- unlike `ccToNode`'s
   `extraStorePaths`/`findAllStorePaths` scan (which greps every argv
   element for a literal store-path substring and folds it into the
   deferred record's own `srcs`), neither the `ar` nor `ranlib` shim has
   an equivalent scan over their own positional inputs. Once an earlier
   compile's `.o` output resolves to a real store path, `ar`'s own
   record never picks it up, so the registered `ar`/link derivation ends
   up with an empty `inputs.drvs` and the sandbox has no access to a
   `.o` it never declared (`ar: /nix/store/<hash>-thread.c.o: No such
   file or directory`, confirmed via `nix derivation show`). Distinct
   from bug #3 above (that fix only touched `cc`/`c++`'s own scan; `ar`/
   `ranlib` are a separate code path that was never given one at all).
   **FIXED in dyn-drvs 28af81d.**
9. **`phases.split`'s phase 2 never reconstructed a cmake+make build's
   absolute source directory** (capnproto) -- every real per-TU compile
   and link succeeded, but `installPhase` then failed outright
   (`CMake Error: The source directory "/build/source" does not exist`)
   because phase 2 forced `sourceRoot = "."`, and the existing
   "reconstruct phase 1's absolute build-dir position" logic
   (`dyndrvCdToBuildDir`) only fired when it found meson's own
   `build.ninja` marker, never for a cmake-generated `Makefile`'s cached
   `CMAKE_HOME_DIRECTORY`. Distinct from the compile-time discoverTree
   cmake-source-path bug below (tinycbor/xxHash/re2) -- this one was an
   install-time failure that happened even after every compile/link
   already succeeded for real. **FIXED in dyn-drvs 0d233d3** ("Fix
   phases.split cmake+make out-of-tree install failure (task #138)");
   capnproto now builds clean end to end.
9. **Bare `-l<name>` link args are never resolved to their producing
   derivation** (x265) -- every previous link-step gap this survey found
   (bug #3 above, 28af81d's `ar`-input scan) works by scanning argv/env
   for a literal, already-resolved `/nix/store/...` substring. x265's
   cmake build links its 10-bit/12-bit encoder variants via a bare
   `-Wl,-Bstatic -lx265-10 -lx265-12` (a search-path-relative library
   name, not a full path), which none of that literal-substring
   machinery can resolve back to the dynamic derivation that will
   produce `libx265-10.a`/`libx265-12.a`:
   `ld.bfd: cannot find -lx265-10: No such file or directory`. Confirmed
   not fixed by dyn-drvs dc07a0a/1347c8c/e5f9a61/5468402 (none add
   `-l<name>` resolution). Still open at the dyn-drvs level -- worked
   around at the package level instead (x265's own
   `multibitdepthSupport = false` avoids the whole code path that bakes
   in this linkage, at the cost of dropping 10/12-bit HDR support).

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
  nixpkgs's real (cmake-based, v7.0) recipe. **libwebp** (~171 TUs,
  single-output) independently confirmed the same bug a fourth time,
  then went on to confirm two more distinct bugs (`ar`/`ranlib`
  `inputs.drvs` gap, `-Wl,`-glued link.d path) before landing a full
  **PASS** once all three fixes were in place (dyn-drvs 97a987d +
  28af81d + dc07a0a) -- see table above.
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
- **mpfr: FAIL, confirms known bug #3** (`.libs/*.o` not found at the
  `libmpfr.so` link step, identical shape to pcre2).
- **openjpeg: FAIL, new bug (#5 above).** See `dyndrv-openjpeg` in the
  table above -- `arToNode`/`ranlibToNode` never wire their own `.o`
  positional inputs as real `inputs.drvs`, so the first real static-lib
  link fails outright once its inputs are genuinely resolved dynamic
  derivations.
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
