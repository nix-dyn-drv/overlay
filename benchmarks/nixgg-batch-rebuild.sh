#!/usr/bin/env bash
# Times nixgg's unbatched-vs-batched lua variants and reports:
#   1. build-phase wall-clock, unbatched vs batched (first per-TU/archive
#      "building" line to the final output line -- excludes the one-time
#      nixpkgs/toolchain substitution into a fresh store, which is
#      identical for both variants and otherwise swamps the real signal)
#   2. per-TU derivations built (accelerated only)
#
# Usage:
#   benchmarks/nixgg-batch-rebuild.sh <unbatched-attr> <batched-attr>
#
# Example:
#   benchmarks/nixgg-batch-rebuild.sh nixgg-lua nixgg-lua-batch
#
# Env vars:
#   RUN_NIXGG          which run-nixgg wrapper to drive builds with
#                       (default: try-it-out/run-nixgg.sh)
#   NIXGG_BENCH_DIR    scratch dir for local stores (default: a fresh
#                       mktemp -d, removed on exit unless KEEP=1)
#   KEEP=1             keep NIXGG_BENCH_DIR after the run, for inspection

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <unbatched-attr> <batched-attr>" >&2
  exit 1
fi

UNBATCHED_ATTR="$1"
BATCHED_ATTR="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RUN_NIXGG="${RUN_NIXGG:-$REPO_ROOT/try-it-out/run-nixgg.sh}"

WORKDIR="${NIXGG_BENCH_DIR:-$(mktemp -d -t nixgg-batch-rebuild.XXXXXX)}"
mkdir -p "$WORKDIR"
if [[ -z "${KEEP:-}" ]]; then
  trap 'chmod -R u+w "$WORKDIR" 2>/dev/null; rm -rf "$WORKDIR" || true' EXIT
fi

echo "nixgg batch-rebuild benchmark"
echo "  unbatched: .#$UNBATCHED_ATTR"
echo "  batched:   .#$BATCHED_ATTR"
echo "workdir=$WORKDIR"
echo ""

# Timestamps every log line so the build-phase window can be sliced out
# of the substitution noise after the fact.
run_timestamped() {
  local attr="$1" store="$2" log="$3"
  NIXGG_STORE="$store" "$RUN_NIXGG" build --impure --no-link --print-out-paths -Lv \
    ".#$attr" 2>&1 | while IFS= read -r line; do printf '%s %s\n' "$(date +%s.%N)" "$line"; done >"$log"
}

# From the first per-TU/archive "building" line to the last log line.
build_phase_seconds() {
  local log="$1"
  awk '
    /building .*(tu-|ar-|batch-).*\.drv/ && !start { start=$1 }
    { last=$1 }
    END { if (start) printf "%.2f", last - start; else print "n/a" }
  ' "$log"
}

count_tu_builds() {
  grep -cE "building '.*(tu-|ar-|batch-).*\.drv'" "$1" || true
}

echo "=== Unbatched ==="
run_timestamped "$UNBATCHED_ATTR" "$WORKDIR/store-unbatched" "$WORKDIR/unbatched.log"
unbatched_phase=$(build_phase_seconds "$WORKDIR/unbatched.log")
unbatched_tus=$(count_tu_builds "$WORKDIR/unbatched.log")
echo "  build phase: ${unbatched_phase}s, ${unbatched_tus} per-TU/archive derivations"

echo "=== Batched ==="
run_timestamped "$BATCHED_ATTR" "$WORKDIR/store-batched" "$WORKDIR/batched.log"
batched_phase=$(build_phase_seconds "$WORKDIR/batched.log")
batched_tus=$(count_tu_builds "$WORKDIR/batched.log")
echo "  build phase: ${batched_phase}s, ${batched_tus} per-TU/archive derivations"

echo ""
echo "=== Metric 1: build-phase wall-clock (excludes one-time substitution) ==="
echo "  unbatched: ${unbatched_phase}s"
echo "  batched:   ${batched_phase}s"
speedup=$(awk -v u="$unbatched_phase" -v b="$batched_phase" 'BEGIN { if (b > 0) printf "%.2f", u / b; else print "n/a" }')
echo "  ratio: ${speedup}x"
echo ""
echo "=== Metric 2: per-TU/archive derivations submitted ==="
echo "  unbatched: ${unbatched_tus}"
echo "  batched:   ${batched_tus}"
