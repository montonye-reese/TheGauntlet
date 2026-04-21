#!/usr/bin/env bash
# 8 Degrees — v15 Orchestration Script
#
# Runs the four v15 configurations sequentially:
#   1. nemotron-3-super:120b × v15_cold                (voice-centering baseline)
#   2. nemotron-3-super:120b × v15_cold_label-vegan    (voice-centering + fortress test)
#   3. nemotron-3-nano:30b   × v15_cold                (nano baseline)
#   4. nemotron-3-nano:30b   × v15_cold_label-vegan    (nano fortress test)
#
# Sequential because only one model fits in Spark unified memory at a time.
# Fail-fast: if any run errors, the chain stops (so we don't burn 3 hours
# after the first run broke).
#
# Usage:
#   ./run_v15.sh                 # run all four
#   ./run_v15.sh super-only      # runs #1 and #2 only
#   ./run_v15.sh nano-only       # runs #3 and #4 only
#
# Output: .md logs land in each coordinate's directory via --output-dir.

set -euo pipefail

V13_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$V13_DIR"

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
    run_one "super × cold"               "nemotron-3-super:120b" "v15_cold"             "v15_cold/v15_qs_cold.md"
    run_one "super × cold_label-vegan"   "nemotron-3-super:120b" "v15_cold_label-vegan" "v15_cold_label-vegan/v15_qs_cold_label-vegan.md"
fi

if [[ "$MODE" == "all" || "$MODE" == "nano-only" ]]; then
    run_one "nano × cold"                "nemotron-3-nano:30b"   "v15_cold"             "v15_cold/v15_qs_cold.md"
    run_one "nano × cold_label-vegan"    "nemotron-3-nano:30b"   "v15_cold_label-vegan" "v15_cold_label-vegan/v15_qs_cold_label-vegan.md"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
HOURS=$((ELAPSED / 3600))
MINUTES=$(( (ELAPSED % 3600) / 60 ))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  v15 ORCHESTRATION COMPLETE"
echo "  Mode:    $MODE"
echo "  Elapsed: ${HOURS}h ${MINUTES}m"
echo "════════════════════════════════════════════════════════════"
