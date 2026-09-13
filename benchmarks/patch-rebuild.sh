#!/usr/bin/env bash
# Times a cold build of a plain vs. accelerated flake attr and reports:
#   1. rebuild wall-clock, plain vs. accelerated
#   2. dynamic per-TU derivations rebuilt (accelerated only; plain always
#      rebuilds 1/1)
#
# Each package must expose plain and accelerated variants as separate flake
# outputs (e.g. dyndrv-openssl-baseline / dyndrv-openssl) since the override
# wiring in nix/packages/*.nix is per-package, not parameterized by a shared
# variant argument.
#
# Usage:
#   benchmarks/patch-rebuild.sh <plain-attr> <accelerated-attr> <patch-file>
#
# Example:
#   benchmarks/patch-rebuild.sh packages.x86_64-linux.dyndrv-openssl-baseline \
#     packages.x86_64-linux.dyndrv-openssl \
#     benchmarks/patches/openssl-one-file.diff
#
# Env vars:
#   RUN_NIX           which run-nix wrapper to drive builds with (default:
#                     try-it-out/run-nix.sh, the redirected-store variant;
#                     CI uses try-it-out/run-nix-ci.sh, the real-store one)
#   DYNDRV_BENCH_DIR  scratch dir for local stores when using the
#                     redirected-store run-nix.sh (default: a fresh
#                     mktemp -d, removed on exit unless KEEP=1). Has no
#                     effect with run-nix-ci.sh, which always targets the
#                     real /nix/store.
#   KEEP=1            keep DYNDRV_BENCH_DIR after the run, for inspection

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <plain-attr> <accelerated-attr> [patch-file]" >&2
  exit 1
fi

PLAIN_ATTR="$1"
ACCELERATED_ATTR="$2"
PATCH_FILE="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RUN_NIX="${RUN_NIX:-$REPO_ROOT/try-it-out/run-nix.sh}"

WORKDIR="${DYNDRV_BENCH_DIR:-$(mktemp -d -t dyndrv-patch-rebuild.XXXXXX)}"
mkdir -p "$WORKDIR"
if [[ -z "${KEEP:-}" ]]; then
  trap 'chmod -R u+w "$WORKDIR" 2>/dev/null; rm -rf "$WORKDIR" || true' EXIT
fi

echo "dyndrv patch-rebuild benchmark"
echo "  plain:       .#$PLAIN_ATTR"
echo "  accelerated: .#$ACCELERATED_ATTR"
[[ -n "$PATCH_FILE" ]] && echo "  patch:       $PATCH_FILE"
echo "workdir=$WORKDIR"
echo ""

time_build() {
  local attr="$1" store="$2"
  local start end
  start=$(date +%s.%N)
  DYNDRV_STORE="$store" "$RUN_NIX" build --impure --no-link --print-out-paths \
    ".#$attr" >"$WORKDIR/last-build.log" 2>&1
  end=$(date +%s.%N)
  awk -v s="$start" -v e="$end" 'BEGIN { printf "%.2f", e - s }'
}

count_dyndrv_builds() {
  grep -c "building '.*dyndrv-.*\.drv'" "$WORKDIR/last-build.log" || true
}

echo "=== Plain ==="
echo "-- cold build --"
plain_cold=$(time_build "$PLAIN_ATTR" "$WORKDIR/store-plain")
echo "  ${plain_cold}s"

echo "=== Accelerated ==="
echo "-- cold build --"
acc_cold=$(time_build "$ACCELERATED_ATTR" "$WORKDIR/store-accelerated")
echo "  ${acc_cold}s"

if [[ -n "$PATCH_FILE" ]]; then
  echo ""
  echo "NOTE: nix/packages/*.nix has no eval-time 'patch' argument, so applying"
  echo "\"$PATCH_FILE\" needs a package-specific patched variant (see"
  echo "nix/packages/openssl.nix's patchedAccelerated: .#dyndrv-openssl-patched)."
fi

echo ""
echo "=== Metric 1: cold-build wall-clock ==="
echo "  plain:       ${plain_cold}s"
echo "  accelerated: ${acc_cold}s"
speedup=$(awk -v p="$plain_cold" -v a="$acc_cold" 'BEGIN { if (a > 0) printf "%.2f", p / a; else print "n/a" }')
echo "  ratio: ${speedup}x"
echo ""
echo "=== Metric 2: dynamic per-TU derivations built (accelerated) ==="
echo "  $(count_dyndrv_builds)"
