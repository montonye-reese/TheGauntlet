#!/usr/bin/env bash
# 8 Degrees — v16 Orchestration Script
#
# Runs the v16 fortress-test generalization matrix:
#   3 P4 labels (climate, ea, scientology) × 2 registers (cold, warm) × 2 models (super, nano)
#   = 12 sequential runs.
#
# Model pool: nemotron-3-super:120b and nemotron-3-nano:30b only
# (matching v15 pool; full-cohort scaling can be added once signal is confirmed).
#
# Sequential because only one model fits in Spark unified memory at a time.
# Fail-fast: if any run errors, the chain stops.
#
# Usage:
#   ./run_v16.sh                 # all 12
#   ./run_v16.sh super-only      # super × 6 arms
#   ./run_v16.sh nano-only       # nano × 6 arms
#
# Output: .md logs land in each coordinate's directory via --output-dir.

set -euo pipefail

V16_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$V16_DIR"

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

    python3 v16_run.py \
        --qs "$qs_file" \
        --model "$model" \
        --output-dir "$coord_dir"

    echo ""
    echo "  [$(date +%H:%M:%S)] Completed: $label"
}

START_TS=$(date +%s)

if [[ "$MODE" == "all" || "$MODE" == "super-only" ]]; then
    run_one "super × v16_cold_label-climate"     "nemotron-3-super:120b" "v16_cold_label-climate"     "v16_cold_label-climate/v16_qs_cold_label-climate.md"
    run_one "super × v16_cold_label-ea"          "nemotron-3-super:120b" "v16_cold_label-ea"          "v16_cold_label-ea/v16_qs_cold_label-ea.md"
    run_one "super × v16_cold_label-scientology" "nemotron-3-super:120b" "v16_cold_label-scientology" "v16_cold_label-scientology/v16_qs_cold_label-scientology.md"
    run_one "super × v16_warm_label-climate"     "nemotron-3-super:120b" "v16_warm_label-climate"     "v16_warm_label-climate/v16_qs_warm_label-climate.md"
    run_one "super × v16_warm_label-ea"          "nemotron-3-super:120b" "v16_warm_label-ea"          "v16_warm_label-ea/v16_qs_warm_label-ea.md"
    run_one "super × v16_warm_label-scientology" "nemotron-3-super:120b" "v16_warm_label-scientology" "v16_warm_label-scientology/v16_qs_warm_label-scientology.md"
fi

if [[ "$MODE" == "all" || "$MODE" == "nano-only" ]]; then
    run_one "nano × v16_cold_label-climate"      "nemotron-3-nano:30b"   "v16_cold_label-climate"     "v16_cold_label-climate/v16_qs_cold_label-climate.md"
    run_one "nano × v16_cold_label-ea"           "nemotron-3-nano:30b"   "v16_cold_label-ea"          "v16_cold_label-ea/v16_qs_cold_label-ea.md"
    run_one "nano × v16_cold_label-scientology"  "nemotron-3-nano:30b"   "v16_cold_label-scientology" "v16_cold_label-scientology/v16_qs_cold_label-scientology.md"
    run_one "nano × v16_warm_label-climate"      "nemotron-3-nano:30b"   "v16_warm_label-climate"     "v16_warm_label-climate/v16_qs_warm_label-climate.md"
    run_one "nano × v16_warm_label-ea"           "nemotron-3-nano:30b"   "v16_warm_label-ea"          "v16_warm_label-ea/v16_qs_warm_label-ea.md"
    run_one "nano × v16_warm_label-scientology"  "nemotron-3-nano:30b"   "v16_warm_label-scientology" "v16_warm_label-scientology/v16_qs_warm_label-scientology.md"
fi

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
HOURS=$((ELAPSED / 3600))
MINUTES=$(( (ELAPSED % 3600) / 60 ))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  v16 ORCHESTRATION COMPLETE"
echo "  Mode:    $MODE"
echo "  Elapsed: ${HOURS}h ${MINUTES}m"
echo "════════════════════════════════════════════════════════════"
