#!/usr/bin/env bash
# 8 Degrees — v15 Warm Orchestration Script
#
# Separate from run_v15.sh (which covered the completed v15_cold arms) so
# the historical record of what-ran-when stays untouched per the versioning
# convention. This script runs the v15_warm set with the post-audit language:
#
#   1. super × v15_warm                (warm control, no label)
#   2. super × v15_warm_label-vegan    (warm fortress test, vegan)
#   3. nano  × v15_warm                (warm control, no label)
#   4. nano  × v15_warm_label-vegan    (warm fortress test, vegan)
#
# Uses v15_run.py (identical to cold runs — v15 register is a qs-file property,
# not a runner one).
#
# Sequential because only one model fits in Spark unified memory at a time.
# Fail-fast: if any run errors, the chain stops.
#
# Usage:
#   ./run_v15_warm.sh                # run all four
#   ./run_v15_warm.sh super-only     # runs #1 and #2 only
#   ./run_v15_warm.sh nano-only      # runs #3 and #4 only
#
# Output: .md logs land in each coordinate's directory via --output-dir.

set -euo pipefail

V15_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$V15_DIR"

MODE="${1:-all}"

case "$MODE" in
    all|super-only|nano-only) ;;
    *)
        echo "Usage: $0 [all|super-only|nano-only]" >&2
        exit 2
        ;;
esac

run_one() {
    local label="$1"
    local model="$2"
    local coord_dir="$3"
    local qs_file="$4"

    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  [$(date +%H:%M:%S)] Starting: $label"
    echo "  Model:   $model"
    echo "  QS:      $qs_file"
    echo "  Output:  $coord_dir/"
    echo "════════════════════════════════════════════════════════════"

    python3 v15_run.py \
        --qs "$qs_file" \
        --model "$model" \
        --output-dir "$coord_dir"

    echo ""
    echo "  [$(date +%H:%M:%S)] Completed: $label"
}

START_TS=$(date +%s)

if [[ "$MODE" == "all" || "$MODE" == "super-only" ]]; then
    run_one "super × v15_warm"               "nemotron-3-super:120b" "v15_warm"              "v15_warm/v15_qs_warm.md"
    run_one "super × v15_warm_label-vegan"   "nemotron-3-super:120b" "v15_warm_label-vegan"  "v15_warm_label-vegan/v15_qs_warm_label-vegan.md"
fi

if [[ "$MODE" == "all" || "$MODE" == "nano-only" ]]; then
    run_one "nano × v15_warm"                "nemotron-3-nano:30b"   "v15_warm"              "v15_warm/v15_qs_warm.md"
    run_one "nano × v15_warm_label-vegan"    "nemotron-3-nano:30b"   "v15_warm_label-vegan"  "v15_warm_label-vegan/v15_qs_warm_label-vegan.md"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
HOURS=$((ELAPSED / 3600))
MINUTES=$(( (ELAPSED % 3600) / 60 ))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  v15_warm ORCHESTRATION COMPLETE"
echo "  Mode:    $MODE"
echo "  Elapsed: ${HOURS}h ${MINUTES}m"
echo "════════════════════════════════════════════════════════════"
