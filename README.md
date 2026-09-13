# overlay: Nix dynamic derivations at nixpkgs scale

Nix's dynamic derivations (`builtins.outputOf`, `builder-rpc-v0` --
[NixOS/nix#15793][pr-15793], not yet stable) applied to real nixpkgs
C/C++ packages, via two independent mechanisms:
[nixgg](https://github.com/tomberek/nixgg)'s `splitStdenv` (Go shim,
proven at scale) and [dyn-drvs](https://github.com/tomberek/dyn-drvs)'
`accelerate.mkAcceleratedStdenv` (Nix-language library, `dyndrv-*`
outputs -- only `freetype` is dyn-drvs' own proof point; zstd/mosh/
openssl coverage is new here). Both are real flake inputs, unmodified.

## Numbers

Per-TU acceleration only pays off when per-unit compile cost clears the
~80ms/derivation registration tax:

| Package | Mechanism | One-line patch rebuild | Result |
|---|---|---|---|
| openssl (~2200 TUs) | nixgg `splitStdenv` | **2 / 2213 TUs** | win |
| freetype (~45 TUs) | dyn-drvs `mkAcceleratedStdenv` | 2 / 45 TUs, but 17x *slower* wall-clock | loss |

Full table, real bugs found, and current status of zstd/mosh/openssl:
[`benchmarks/RESULTS.md`](benchmarks/RESULTS.md).

## Quickstart

```console
$ ./try-it-out/run-nix.sh build --impure --no-link --print-out-paths .#dyndrv-freetype
```

`run-nix.sh` fetches a pinned NixOS/nix build and runs it against a
local, non-daemon store (the ambient daemon can't serve
`builder-rpc-v0`). nixgg-mechanism packages (`openssl`, `hello`, `mosh`,
`zstd`) need no wrapper -- plain `nix build` works. CI uses
`run-nix-ci.sh` instead, driving the same fetched Nix directly against
the real `/nix/store` (safe there -- each job owns its VM exclusively).

[pr-15793]: https://github.com/NixOS/nix/pull/15793
