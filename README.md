# overlay

Showcases Nix dynamic derivations (`builtins.outputOf`, `builder-rpc-v0`,
[NixOS/nix#15793][pr-15793]) against real nixpkgs C/C++ packages, using
two different libraries:

- [nixgg](https://github.com/tomberek/nixgg) — Go shim, already proven at scale.
- [dyn-drvs](https://github.com/tomberek/dyn-drvs) — Nix-language library (`dyndrv-*` outputs).

Full results, bugs found, and current status: [`benchmarks/RESULTS.md`](benchmarks/RESULTS.md).
Live benchmark dashboard: <https://nix-dyn-drv.github.io/overlay/benchmarks/dashboard/>

## The headline number

nixgg's mechanism rebuilds only 2 of openssl's 2213 translation units on
a one-line patch. dyn-drvs' mechanism builds clean on freetype and
giflib, but freetype's patch-rebuild is 17x *slower* than a plain
rebuild — per-TU acceleration only pays off when each unit costs more to
compile than the ~80ms registration overhead. A wider survey against
xxHash/re2/libb64/mpfr/tinycbor found three more distinct dyn-drvs bugs
beyond the four already documented; see `benchmarks/RESULTS.md`.

## Quickstart

```console
$ ./try-it-out/run-nix.sh build --impure --no-link --print-out-paths .#dyndrv-freetype
```

`run-nix.sh` fetches a pinned NixOS/nix build and runs it against a
local store, since the system daemon doesn't support `builder-rpc-v0`.
nixgg packages (`openssl`, `hello`, `mosh`, `zstd`) build with plain
`nix build`. CI uses `run-nix-ci.sh`, which points the same Nix at the
real `/nix/store` — safe there since each job gets its own VM.

[pr-15793]: https://github.com/NixOS/nix/pull/15793
