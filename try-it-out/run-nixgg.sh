#!/usr/bin/env bash
# Local (non-daemon-store) runner for nixgg-mechanism packages, analogous
# to run-nix.sh (dyn-drvs' mechanism) but pointed at nixgg's own
# patched-nix + feature set. Unlike run-nix.sh's --builders "" trick,
# nixgg's patched Nix grants builder-rpc-v0 directly via
# --extra-system-features, matching run-nixgg-ci.sh's flags exactly --
# the only difference here is a local --store instead of the real
# /nix/store + sudo (CI has its own disposable VM; a local dev machine
# doesn't).
#
# Usage:
#   try-it-out/run-nixgg.sh build --impure --no-link --print-out-paths .#lua-batch
#
# Env: NIXGG_STORE (default /tmp/nixgg-store)

set -euo pipefail

NIXGG_STORE="${NIXGG_STORE:-/tmp/nixgg-store}"

PATCHED_NIX=$(nix build github:tomberek/nixgg#patched-nix --no-link --print-out-paths)

mkdir -p "$NIXGG_STORE"

exec "$PATCHED_NIX/bin/nix" \
  --extra-experimental-features "nix-command ca-derivations dynamic-derivations" \
  --extra-system-features "builder-rpc-v0" \
  --store "local?root=$NIXGG_STORE" \
  --builders "" \
  "$@"
