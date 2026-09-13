#!/usr/bin/env bash
# Adapted from dyn-drvs. Fetches patched-nix.nix's pinned Nix build and
# re-execs into it against a local, non-daemon store -- the ambient
# nix-daemon can't serve builder-rpc-v0 and its experimental-features
# are fixed at startup.
#
# Usage:
#   try-it-out/run-nix.sh build --impure --no-link --print-out-paths .#dyndrv-freetype
#
# Env: NIX_REV (override the pinned commit), DYNDRV_STORE (default /tmp/dyndrv-store)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

DYNDRV_STORE="${DYNDRV_STORE:-/tmp/dyndrv-store}"

REV_ARG=""
if [[ -n "${NIX_REV:-}" ]]; then
  REV_ARG="--argstr rev $NIX_REV"
fi

SYSTEM=$(nix config show --json | jq -r .system.value)
# shellcheck disable=SC2086
PATCHED_NIX=$(nix build --no-link --print-out-paths $REV_ARG \
  --argstr system "$SYSTEM" \
  -f "$SCRIPT_DIR/patched-nix.nix" '^out')

mkdir -p "$DYNDRV_STORE"

# --builders '' avoids farming out to any remote-builder pool configured
# in the ambient nix.conf, which knows nothing about builder-rpc-v0.
exec "$PATCHED_NIX/bin/nix" \
  --extra-experimental-features "nix-command ca-derivations dynamic-derivations recursive-nix" \
  --extra-system-features "builder-rpc-v0" \
  --store "local?root=$DYNDRV_STORE" \
  --builders "" \
  "$@"
