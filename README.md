# overlay: is Nix's dynamic-derivations feature viable yet?

Nix gained a real feature for splitting one derivation's build into many
independently-cacheable pieces, resolved at *build* time instead of eval
time: `builtins.outputOf` plus the `builder-rpc-v0`/`nix store
submit-output` protocol ([NixOS/nix#15793][pr-15793], merged 2026-07-21,
not yet in a stable release). In principle this lets a C/C++ package's
few thousand translation units become a few thousand separately-cached
Nix derivations — patch one file, only that file (and whatever links
against it) rebuilds, at any scale, without import-from-derivation's
eval-time cost.

That's the promise. This repo exists to find out whether it holds up
against **real, unmodified nixpkgs packages** — not toy examples — and
to report the answer honestly, wins and losses both.

## What we're testing

Four independent libraries have each built their own layer on top of
this primitive, without coordinating with each other. Testing all four
against the same real packages tells us whether the *underlying Nix
feature* is viable, not just whether one library's design happens to
work:

- [nixgg](https://github.com/tomberek/nixgg) — Go-based shim, splits a package's build into per-translation-unit derivations. `openssl`/`hello`/`mosh`/`zstd` outputs.
- [dyn-drvs](https://github.com/tomberek/dyn-drvs) — the same idea in pure Nix (`accelerate.mkAcceleratedStdenv`). `dyndrv-*` outputs.
- [nix-ninja](https://github.com/pdtpartners/nix-ninja) — a drop-in `ninja` replacement that turns any meson/cmake project's real build graph into dynamic derivations. `nixninja-*` outputs.
- [drowse](https://github.com/figsoda/drowse) — a different angle: defers a whole package's *evaluation* into a nested Nix instance, avoiding IFD rather than splitting a build. `drowse-*` outputs.

Every package here is real, unmodified (or minimally patched) nixpkgs —
openssl, freetype, zstd, mosh, giflib, tree, and more. Full per-package
results, exact error text, and root causes:
[`benchmarks/RESULTS.md`](benchmarks/RESULTS.md). Live benchmark trend:
<https://nix-dyn-drv.github.io/overlay/benchmarks/dashboard/>.

## What we found

**It works, dramatically, on the right shape of package.** nixgg's
mechanism rebuilds only 2 of openssl's 2213 translation units on a
one-line patch — that's the headline case for why this feature exists.

**It's not free, and not universal yet.** dyn-drvs' per-TU splitting
costs ~80ms of registration overhead per derivation; on a package with
many small, fast-compiling files (freetype), that overhead outweighs the
savings — measured directly here at ~6.7x *slower* than a plain build,
not faster. And surveying more real packages surfaced a series of
distinct bugs in dyn-drvs, mostly concentrated in one pattern: **every
package that failed used either cmake's generated build system or
autotools' automake dependency-file idiom; every package that passed
cleanly used a plain, hand-written Makefile.** That's a real, current
limit on viability, not a fluke of any one package — see
`benchmarks/RESULTS.md` for the full list.

**Two more independent mechanisms confirm the underlying feature is
sound**, even where one library's implementation has gaps. nix-ninja (a
separate implementation, written in Rust) also builds a real package
cleanly via the same primitive. drowse proves out the other half of the
story — using dynamic derivations to avoid IFD during evaluation, not
just to split a build.

**This repo tracks a moving target, not a snapshot.** A daily job
([`nixpkgs-update.yml`](.github/workflows/nixpkgs-update.yml)) bumps
`nixpkgs-unstable` and rebuilds every proven package against it,
auto-merging if nothing regressed. Viability has to hold up against
nixpkgs as it actually changes, not just the revision this repo happened
to start from.

Every bug found in dyn-drvs during this work has been reported upstream
with a minimal repro and root cause — several are already fixed as of
this writing, and this repo re-tests against each fix. That feedback
loop is as much the point of this repo as the benchmark numbers: proving
viability means finding the real gaps, not just citing the best-case
demo.

## Quickstart

```console
$ ./try-it-out/run-nix.sh build --impure --no-link --print-out-paths .#dyndrv-freetype
```

`run-nix.sh` fetches a pinned NixOS/nix build and runs it against a
local store, since the system daemon doesn't support `builder-rpc-v0`
yet. Same script builds `nixninja-argp`/`drowse-hello`. nixgg packages
(`openssl`, `hello`, `mosh`, `zstd`) build with plain `nix build`. CI
uses `run-nix-ci.sh`, which points the same Nix at the real `/nix/store`
— safe there since each job gets its own VM.

[pr-15793]: https://github.com/NixOS/nix/pull/15793

