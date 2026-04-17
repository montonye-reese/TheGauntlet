#!/bin/bash
# v10_run.sh
# Runs the v10 experiment sequence for each of 9 models sequentially,
# using the questions file specified as the first argument.
# Each model's output goes into its own subdirectory named after the
# model + coordinate (derived from the qs filename).
#
# Usage:
#   ./v10_run.sh v10_qs_present-warm.md                          # default localhost
#   ./v10_run.sh v10_qs_present-warm.md http://192.168.1.100:11434  # custom host

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <qs_file> [host]"
    echo "Example: $0 v10_qs_present-warm.md"
    exit 1
fi

QS_FILE="$1"
HOST="${2:-http://localhost:11434}"

if [ ! -f "${QS_FILE}" ]; then
    echo "  ✗ Questions file not found: ${QS_FILE}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Derive coordinate from qs filename: v10_qs_present-warm.md → v9a_present-warm
QS_BASENAME=$(basename "${QS_FILE}" .md)
COORDINATE="${QS_BASENAME/_qs_/_}"

LOG_FILE="${SCRIPT_DIR}/v10_run_all_${COORDINATE}_${TIMESTAMP}.log"

# Model name : output directory base (relative to script location)
# Dots stripped, colons → dashes. Coordinate suffix added at run time.
declare -A MODEL_DIRS
MODEL_DIRS["qwen3.5:27b"]="qwen35-27b"
MODEL_DIRS["qwen3.5:35b"]="qwen35-35b"
MODEL_DIRS["qwen3.5:122b"]="qwen35-122b"
MODEL_DIRS["nemotron-3-nano:30b"]="nemotron-3-nano-30b"
MODEL_DIRS["nemotron-cascade-2:30b"]="nemotron-cascade-2-30b"
MODEL_DIRS["nemotron-3-super:120b"]="nemotron-3-super-120b"
MODEL_DIRS["gemma4:31b"]="gemma4-31b"
MODEL_DIRS["gemma3:27b"]="gemma3-27b"
MODEL_DIRS["deepseek-r1:70b"]="deepseek-r1-70b"

# Run order
MODELS=(
    "qwen3.5:27b"
    "qwen3.5:35b"
    "qwen3.5:122b"
    "nemotron-3-nano:30b"
    "nemotron-cascade-2:30b"
    "nemotron-3-super:120b"
    "gemma4:31b"
    "gemma3:27b"
    "deepseek-r1:70b"
)

echo "========================================================"
echo "  8 DEGREES — v10 ALL MODELS RUNNER"
echo "  $(date)"
echo "  QS file:    ${QS_FILE}"
echo "  Coordinate: ${COORDINATE}"
echo "  Models:     ${#MODELS[@]}"
echo "  Host:       ${HOST}"
echo "  Log:        ${LOG_FILE}"
echo "========================================================"

PASS=0
FAIL=0
SKIP=0
FAILED_MODELS=()

for MODEL in "${MODELS[@]}"; do
    # Output dir = model-safe-name + coordinate suffix
    OUTPUT_DIR="${SCRIPT_DIR}/${MODEL_DIRS[$MODEL]}-${COORDINATE}"

    # Skip if output file already exists and has content (model already completed)
    EXISTING_OUTPUT=$(find "${OUTPUT_DIR}" -name "*.md" -size +1k 2>/dev/null | head -1)
    if [ -n "${EXISTING_OUTPUT}" ]; then
        echo ""
        echo "  ⏭ ${MODEL} — already completed, skipping (${EXISTING_OUTPUT})"
        SKIP=$((SKIP + 1))
        PASS=$((PASS + 1))
        continue
    fi

    # Create output dir if it doesn't exist
    mkdir -p "${OUTPUT_DIR}"

    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "  Model:  ${MODEL}"
    echo "  Output: ${OUTPUT_DIR}"
    echo "  $(date)"
    echo "────────────────────────────────────────────────────────"

    if python3 "${SCRIPT_DIR}/v10_run.py" \
        --qs "${QS_FILE}" \
        --model "${MODEL}" \
        --host "${HOST}" \
        --output-dir "${OUTPUT_DIR}" \
        2>&1 | tee -a "${LOG_FILE}"; then
        echo "  ✓ ${MODEL} complete"
        PASS=$((PASS + 1))
    else
        echo "  ✗ ${MODEL} FAILED"
        FAIL=$((FAIL + 1))
        FAILED_MODELS+=("${MODEL}")
    fi
done

echo ""
echo "========================================================"
echo "  ALL MODELS COMPLETE"
echo "  Passed: ${PASS} / ${#MODELS[@]}  (${SKIP} skipped)"
if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo "  Failed: ${FAIL}"
    for M in "${FAILED_MODELS[@]}"; do
        echo "    - ${M}"
    done
fi
echo "  Log: ${LOG_FILE}"
echo "========================================================"
