#!/usr/bin/env bash
# nixgg-vs-dyndrv-lua-bench.sh: direct head-to-head patch-rebuild
# wall-clock comparison between nixgg's own mkNixggBuild (`.#lua`) and
# dyn-drvs' accelerate.mkAcceleratedStdenv, both driving the IDENTICAL
# real, unmodified Lua 5.4.7 source tree via the IDENTICAL build
# command nixgg's own examples/lua/default.nix uses (`cd src && make
# linux CC=cc`).
#
# Neither side had a shared benchmark before this: dyn-drvs' own
# small-lib-patch-rebuild.sh only compares itself against plain
# stdenv.mkDerivation; nixgg's own tests/perf-regression.sh only
# asserts REBUILD SCOPE (which TUs rebuild), never wall-clock, and its
# README's one hand-measured number (48% RPC-vs-CLI win) is shim-
# internal overhead, not an end-to-end nixgg-vs-dyndrv number.
#
# Methodology, mirroring dyn-drvs' own real-package-patch-rebuild.sh:
#   1. warm each mechanism's own store with a cold `.#lua`-equivalent
#      build (excluded from the timed window -- both mechanisms need a
#      substantial one-time patched-Nix substitution too, see each
#      harness's own header comment for why that's pre-timing setup).
#   2. apply the SAME one-line comment-only edit to src/lmathlib.c
#      (nixgg's own tests/perf-regression.sh's exact fixture) via each
#      side's own edited-source derivation.
#   3. time the resulting rebuild, substituters OFF (so a cache hit
#      can't quietly satisfy a drv without it actually running) and
#      REMOTE BUILDERS OFF (`--builders ""`) -- confirmed necessary by
#      direct reproduction: with a remote builder still in play, one
#      run measured 27s for a rebuild that took ~19s local-only for
#      the SAME edit -- SSH round-trip latency to a remote machine is
#      not a property of either acceleration mechanism, and swamps the
#      real signal if left enabled.
#
# See ../RESULTS.md's own "Direct head-to-head" section for the last-
# measured numbers and their interpretation -- not duplicated here.
#
# Usage:
#   nixgg-vs-dyndrv-lua-bench.sh
#
# Env vars:
#   DYNDRV_ROOT   path to the dyn-drvs checkout (default: ~/dyn-drvs)
#   NIXGG_ROOT    path to the nixgg checkout (default: ~/nixgg)
#   BENCH_DIR     scratch dir for both alt stores (default: fresh mktemp -d)
#   KEEP=1        keep BENCH_DIR after the run, for inspection

set -uo pipefail

DYNDRV_ROOT="${DYNDRV_ROOT:-$HOME/dyn-drvs}"
NIXGG_ROOT="${NIXGG_ROOT:-$HOME/nixgg}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BENCH_DIR="${BENCH_DIR:-$(mktemp -d -t nixgg-vs-dyndrv-lua.XXXXXX)}"
mkdir -p "$BENCH_DIR"
if [[ -z "${KEEP:-}" ]]; then
  trap 'chmod -R u+w "$BENCH_DIR" 2>/dev/null; rm -rf "$BENCH_DIR" || true' EXIT
fi

echo "nixgg-vs-dyndrv lua patch-rebuild benchmark"
echo "dyndrv_root=$DYNDRV_ROOT nixgg_root=$NIXGG_ROOT bench_dir=$BENCH_DIR"
echo ""

# ---- dyn-drvs side: resolve its own patched Nix once (outside the timed window) ----
echo "==> resolving dyn-drvs' own patched Nix (one-time, cache-substitutable)"
DYNDRV_SYSTEM=$(nix config show --json | jq -r .system.value)
DYNDRV_NIX=$(nix build --no-link --print-out-paths \
  --argstr system "$DYNDRV_SYSTEM" \
  -f "$DYNDRV_ROOT/try-it-out/patched-nix.nix" '^out')
DYNDRV_NIX_BIN="$DYNDRV_NIX/bin/nix"
DYNDRV_STORE="$BENCH_DIR/dyndrv-store"
mkdir -p "$DYNDRV_STORE"
DYNDRV_EXTRA_FEATURES="nix-command ca-derivations dynamic-derivations recursive-nix"
DYNDRV_SYSTEM_FEATURES="builder-rpc-v0"

dyndrv_build() {
  local edit_arg=() substituter_arg=()
  if [[ -n "${1:-}" ]]; then
    edit_arg=(--argstr edit "$1")
  fi
  if [[ "${2:-}" = "no-substitute" ]]; then
    substituter_arg=(--option substituters "")
  fi
  "$DYNDRV_NIX_BIN" build \
    --builders "" \
    "${substituter_arg[@]}" \
    --extra-experimental-features "$DYNDRV_EXTRA_FEATURES" \
    --extra-system-features "$DYNDRV_SYSTEM_FEATURES" \
    --store "local?root=$DYNDRV_STORE" \
    --no-link --print-out-paths --impure \
    --arg flakeDir "$DYNDRV_ROOT" \
    --argstr variant accelerated \
    --argstr nixPackagePath "$DYNDRV_NIX" \
    "${edit_arg[@]}" \
    -f "$SCRIPT_DIR/lua-bench-edited.nix"
}

echo "==> dyn-drvs: warming the store (cold build, untimed)"
dyndrv_build "" >"$BENCH_DIR/dyndrv-warm.log" 2>&1 || {
  echo "  dyndrv warm build failed; see $BENCH_DIR/dyndrv-warm.log" >&2
  tail -20 "$BENCH_DIR/dyndrv-warm.log" >&2
  exit 1
}

echo "==> dyn-drvs: timing patch rebuild (src/lmathlib.c edited)"
DYNDRV_START=$(date +%s.%N)
dyndrv_build "src/lmathlib.c" "no-substitute" >"$BENCH_DIR/dyndrv-patch.log" 2>&1
DYNDRV_STATUS=$?
DYNDRV_END=$(date +%s.%N)
DYNDRV_ELAPSED=$(awk -v s="$DYNDRV_START" -v e="$DYNDRV_END" 'BEGIN { printf "%.2f", e - s }')
if [[ $DYNDRV_STATUS -ne 0 ]]; then
  echo "  dyndrv patch rebuild failed; see $BENCH_DIR/dyndrv-patch.log" >&2
  tail -20 "$BENCH_DIR/dyndrv-patch.log" >&2
  exit 1
fi
DYNDRV_TU_REBUILDS=$(grep -c "building '.*dyndrv-src_.*_o\.drv'" "$BENCH_DIR/dyndrv-patch.log" || true)

echo "  dyndrv elapsed: ${DYNDRV_ELAPSED}s, TU derivations rebuilt: $DYNDRV_TU_REBUILDS"
echo ""

# ---- nixgg side: resolve its own patched Nix once (outside the timed window) ----
echo "==> resolving nixgg's own patched Nix (one-time, cache-substitutable)"
NIXGG_NIX_DIR="$BENCH_DIR/nixgg-patched-nix"
nix build --no-eval-cache --no-link -o "$NIXGG_NIX_DIR" "$NIXGG_ROOT#patched-nix" \
  >"$BENCH_DIR/nixgg-nix-build.log" 2>&1 || {
    echo "  failed to build nixgg's own patched-nix; see $BENCH_DIR/nixgg-nix-build.log" >&2
    tail -20 "$BENCH_DIR/nixgg-nix-build.log" >&2
    exit 1
  }
NIXGG_NIX_BIN="$NIXGG_NIX_DIR/bin/nix"
NIXGG_NIX_INSTANTIATE_BIN="$NIXGG_NIX_DIR/bin/nix-instantiate"
NIXGG_STORE="$BENCH_DIR/nixgg-store"
mkdir -p "$NIXGG_STORE"
export NIX_CONFIG="
experimental-features = nix-command flakes ca-derivations dynamic-derivations configurable-impure-env
extra-system-features = builder-rpc-v0
store = local?root=$NIXGG_STORE
builders =
"

echo "==> nixgg: warming the store (cold build, untimed)"
"$NIXGG_NIX_BIN" build --no-eval-cache --no-link "$NIXGG_ROOT#lua" \
  >"$BENCH_DIR/nixgg-warm.log" 2>&1 || {
    echo "  nixgg warm build failed; see $BENCH_DIR/nixgg-warm.log" >&2
    tail -20 "$BENCH_DIR/nixgg-warm.log" >&2
    exit 1
  }

echo "==> nixgg: instantiating edited fixture (src/lmathlib.c edited)"
NIXGG_PKG_DRV=$("$NIXGG_NIX_INSTANTIATE_BIN" --impure \
  --arg flakeDir "$NIXGG_ROOT" \
  --argstr edit "src/lmathlib.c" \
  -A package "$NIXGG_ROOT/tests/perf-regression-fixture.nix" \
  2>"$BENCH_DIR/nixgg-instantiate.log") || {
    echo "  nixgg instantiate failed; see $BENCH_DIR/nixgg-instantiate.log" >&2
    tail -20 "$BENCH_DIR/nixgg-instantiate.log" >&2
    exit 1
  }

echo "==> nixgg: timing patch rebuild"
NIXGG_START=$(date +%s.%N)
"$NIXGG_NIX_BIN" build --no-eval-cache --no-link \
  --option substituters "" \
  "${NIXGG_PKG_DRV}^out" >"$BENCH_DIR/nixgg-patch.log" 2>&1
NIXGG_STATUS=$?
NIXGG_END=$(date +%s.%N)
NIXGG_ELAPSED=$(awk -v s="$NIXGG_START" -v e="$NIXGG_END" 'BEGIN { printf "%.2f", e - s }')
if [[ $NIXGG_STATUS -ne 0 ]]; then
  echo "  nixgg patch rebuild failed; see $BENCH_DIR/nixgg-patch.log" >&2
  tail -20 "$BENCH_DIR/nixgg-patch.log" >&2
  exit 1
fi
NIXGG_TU_REBUILDS=$(grep -oP "(?<=^building ')[^']*tu-[^']*(?=')" "$BENCH_DIR/nixgg-patch.log" | wc -l)

echo "  nixgg elapsed: ${NIXGG_ELAPSED}s, TU derivations rebuilt: $NIXGG_TU_REBUILDS"
echo ""

echo "=================================================================="
printf "%-10s %10s %10s\n" "mechanism" "elapsed" "TUs rebuilt"
printf "%-10s %10s %10s\n" "nixgg" "${NIXGG_ELAPSED}s" "$NIXGG_TU_REBUILDS"
printf "%-10s %10s %10s\n" "dyndrv" "${DYNDRV_ELAPSED}s" "$DYNDRV_TU_REBUILDS"
echo "=================================================================="
RATIO=$(awk -v a="$NIXGG_ELAPSED" -v b="$DYNDRV_ELAPSED" 'BEGIN { if (b > 0) printf "%.2f", a / b; else print "n/a" }')
echo "nixgg/dyndrv ratio: ${RATIO}x (>1 means dyndrv faster, <1 means nixgg faster)"
