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
| zstd | cold build | -- | -- | Pending first measurement (gen_html self-exec fix via `extraPhase1Attrs`). |

## dyn-drvs mechanism (`accelerate.mkAcceleratedStdenv`)

| Package | Scenario | TUs rebuilt | Wall-clock (plain vs accelerated) | Speedup | Notes |
|---|---|---|---|---|---|
| freetype (~45 TUs) | one-file patch | 2/45 | 4.43s vs 78.86s | **0.06x (17x slower)** | `dyndrv-freetype` builds real `libfreetype.so`, 93 dynamic derivations registered. Per-TU compile cost too small to amortize the ~80ms/derivation registration tax (known loss, dyn-drvs BASELINE.md). |
| freetype | version bump (3 files) | 6/45 | 18.24s vs 52.01s | **0.35x** | Same cause, smaller magnitude (dyn-drvs number, not re-measured here). |
| zstd | cold build | **BLOCKED** | -- | -- | `discoverTree` mode (used unconditionally by the `cc`/`c++` shim) runs `cc <args> -M -MG` to find extra paths to stage; on a link invocation `.o`/`-o <exe>` args make gcc treat it as unused linker input and print nothing, so `.o` inputs are never staged or resolved. Link derivations end up with empty `inputs.drvs` (confirmed via `nix derivation show`). Root-caused; two other bugs also fixed here (gen_html self-exec, a CMake compiler-flag-probe false positive). Details in `nix/packages/zstd.nix`. |
| mosh | cold build | **BLOCKED** | -- | -- | `dyndrv.phases.split`'s `sandboxedPhases` is a static list that omits `autoreconfHook`'s dynamically `appendToVar`'d `autoreconfPhase` (`configurePhase` logs "no configure script, doing nothing"). `mkAcceleratedStdenv` doesn't expose a `sandboxedPhases` override, so there's no package-level workaround; needs a dyn-drvs change. Details in `nix/packages/mosh.nix`. |
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
   files are never staged or resolved (empty `inputs.drvs`).
4. **`finalAttrs.finalPackage` self-reference missing** (openssl) --
   `mkAcceleratedStdenv`'s custom `mkDerivation` supports the
   `finalAttrs: {...}` call convention but doesn't provide the
   `finalPackage` attribute nixpkgs' `makeOverridable` injects, which
   real packages (openssl, likely others) read.

Every tier attempted beyond freetype found a distinct, previously-unknown
gap -- `mkAcceleratedStdenv` generalizes less readily than its README
implies.

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
