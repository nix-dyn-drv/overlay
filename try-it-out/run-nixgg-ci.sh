#!/usr/bin/env bash
# CI-only runner for nixgg-mechanism packages (openssl, hello, mosh,
# zstd), analogous to run-nix-ci.sh but using nixgg's own pinned
# patched-nix + feature set (ca-derivations dynamic-derivations,
# builder-rpc-v0) against the real /nix/store via sudo.
#
# Usage: try-it-out/run-nixgg-ci.sh build --impure --no-link --print-out-paths .#openssl

set -euo pipefail

PATCHED_NIX=$(nix build github:tomberek/nixgg#patched-nix --no-link --print-out-paths)

exec sudo "$PATCHED_NIX/bin/nix" \
  --extra-experimental-features "ca-derivations dynamic-derivations" \
  --extra-system-features "builder-rpc-v0" \
  --store "local" \
  --builders "" \
  "$@"
