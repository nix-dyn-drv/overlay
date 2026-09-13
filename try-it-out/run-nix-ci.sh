#!/usr/bin/env bash
# CI-only sibling of run-nix.sh: same pinned patched-Nix, but drives it
# directly against the REAL /nix/store (via sudo) instead of a redirected
# /tmp/dyndrv-store. Safe here because a GHA job owns its VM exclusively
# -- nothing else touches this store concurrently. run-nix.sh itself
# keeps redirecting to /tmp for local dev, where the store is shared with
# other users/processes on the machine and writing into it directly as a
# non-owning user isn't safe.
#
# Net effect: outputs land at real /nix/store paths, substitutable by
# and from Cachix exactly like an ordinary `nix build` would produce --
# no separate alt-store namespace to bridge.
#
# `sudo` resets $HOME to root's own -- harmless here (root just gets its
# own fresh ~/.cache/nix instead of reusing the caller's), and GHA's
# default runner user has passwordless sudo, which this relies on.
#
# Usage: try-it-out/run-nix-ci.sh build --impure --no-link --print-out-paths .#dyndrv-freetype

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REV_ARG=""
if [[ -n "${NIX_REV:-}" ]]; then
  REV_ARG="--argstr rev $NIX_REV"
fi

SYSTEM=$(nix config show --json | jq -r .system.value)
# shellcheck disable=SC2086
PATCHED_NIX=$(nix build --no-link --print-out-paths $REV_ARG \
  --argstr system "$SYSTEM" \
  -f "$SCRIPT_DIR/patched-nix.nix" '^out')

exec sudo "$PATCHED_NIX/bin/nix" \
  --extra-experimental-features "nix-command ca-derivations dynamic-derivations recursive-nix" \
  --extra-system-features "builder-rpc-v0" \
  --store "local" \
  --builders "" \
  "$@"
