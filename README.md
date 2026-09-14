# overlay

Showcases Nix dynamic derivations (`builtins.outputOf`, `builder-rpc-v0`,
[NixOS/nix#15793][pr-15793]) against real nixpkgs C/C++ packages, using
four independent libraries:

- [nixgg](https://github.com/tomberek/nixgg) — Go shim, already proven at scale.
- [dyn-drvs](https://github.com/tomberek/dyn-drvs) — Nix-language library (`dyndrv-*` outputs).
- [nix-ninja](https://github.com/pdtpartners/nix-ninja) — drop-in `ninja` replacement (`nixninja-*` outputs).
- [drowse](https://github.com/figsoda/drowse) — nested-eval, IFD-avoiding library (`drowse-*` outputs).

Full results, bugs found, and current status: [`benchmarks/RESULTS.md`](benchmarks/RESULTS.md).
Live benchmark dashboard: <https://nix-dyn-drv.github.io/overlay/benchmarks/dashboard/>

This repo also tracks `nixpkgs-unstable` daily
([`nixpkgs-update.yml`](.github/workflows/nixpkgs-update.yml)): a cron job
bumps the pin, rebuilds every proven package against it, and auto-merges
the bump only if nothing regressed — otherwise it opens a PR instead. The
goal is proving these mechanisms hold up against a real,
constantly-moving target, not just a pinned snapshot.

## The headline number

nixgg's mechanism rebuilds only 2 of openssl's 2213 translation units on
a one-line patch. dyn-drvs' mechanism builds clean on freetype, giflib,
tree, figlet, and nnn, but freetype's cold build is ~6.7x *slower* than
a plain rebuild (0.15x, measured directly in this repo) — per-TU
acceleration only pays off when each unit costs more to compile than the
~80ms registration overhead. A wider survey against eight more real
nixpkgs packages found five more distinct dyn-drvs bugs beyond the four
already documented — every failure traced back to either autotools'
dependency-tracking idiom or cmake's generated build systems, while
every clean pass used a plain, hand-written Makefile. Two more
independent libraries, nix-ninja and drowse, each demonstrate a
genuinely different angle on the same underlying feature: nix-ninja
turns a meson-generated `build.ninja`'s real build graph into per-TU
derivations (`nixninja-argp`, real `libargp.a` verified); drowse defers
a whole package's *evaluation* into a nested `nix-instantiate` instead
of splitting its *build* (`drowse-hello`, real runnable `hello` binary)
— the "avoid IFD" half of the story, not fine-grained caching. See
`benchmarks/RESULTS.md`.

## Quickstart

```console
$ ./try-it-out/run-nix.sh build --impure --no-link --print-out-paths .#dyndrv-freetype
```

`run-nix.sh` fetches a pinned NixOS/nix build and runs it against a
local store, since the system daemon doesn't support `builder-rpc-v0`.
Same script builds `nixninja-argp`/`drowse-hello`. nixgg packages
(`openssl`, `hello`, `mosh`, `zstd`) build with plain `nix build`. CI
uses `run-nix-ci.sh`, which points the same Nix at the real `/nix/store`
— safe there since each job gets its own VM.

[pr-15793]: https://github.com/NixOS/nix/pull/15793
