# nixgg's splitStdenv already gets 2/2213 TUs rebuilt on a one-line
# openssl patch (see `openssl` below); dyn-drvs has never run openssl
# through `accelerate.mkAcceleratedStdenv`. Risk: openssl's `Configure`
# bakes `--openssldir`/`-DENGINESDIR=`/`-DMODULESDIR=` (derived from
# `$out`) into every `cc` invocation. Under `phases.split`, phase 1's
# `$out` is a placeholder, not the final path -- unclear if that stays
# stable across edits (cache-safe) or not.
#
# Checkpoints A-D are separate, buildable attrs; see benchmarks/RESULTS.md
# for outcomes. `patchedAccelerated` isn't validated until C and D run.

{
  pkgs,
  dyndrv,
  nixPackage ? pkgs.nix,
  dyndrvShim ? null,
}:

let
  acceleratedStdenv = dyndrv.accelerate.mkAcceleratedStdenv {
    stdenv = pkgs.stdenv;
    inherit nixPackage dyndrvShim;
  };

  # A: confirms the nixpkgs pin builds openssl at all.
  baseline = pkgs.openssl;

  # B: does the override evaluate and start phase 1? A failure here is
  # itself the result (a no-go).
  accelerated = baseline.override { stdenv = acceleratedStdenv; };

  # Same one-file patch nixgg uses for its own openssl test.
  patchedAccelerated = accelerated.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.writeText "openssl-dyndrv-checkpoint.diff" ''
        --- a/crypto/mem.c
        +++ b/crypto/mem.c
        @@ -1,5 +1,6 @@
         /*
          * Copyright 1995-2021 The OpenSSL Project Authors. All Rights Reserved.
        + * dyndrv openssl checkpoint marker
          *
          * Licensed under the Apache License 2.0 (the "License").  Unless you
          * comply with it, you may obtain a copy of the License at
      '')
    ];
  });
in
{
  inherit baseline accelerated patchedAccelerated;

  # C: dump one registered per-TU derivation's argv, check the literal
  # `-DOPENSSLDIR=` value. Needs a real sandboxed build:
  #   $DYNDRV_NIX build --store "local?root=$DYNDRV_STORE" \
  #     --no-link --print-out-paths .#dyndrv-openssl.accelerated
  #   $DYNDRV_NIX store build-trace <outer .drv> --store "local?root=$DYNDRV_STORE"
  # then `nix derivation show` on one compile-step `.drv`.

  # D: patch-rebuild count. `patchedAccelerated` above is the buildable
  # half; benchmarks/patch-rebuild.sh runs it and greps the build-trace
  # log for the rebuilt-derivation count.
}
