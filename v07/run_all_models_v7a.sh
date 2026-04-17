#!/bin/bash
# run_all_models_v7a.sh
# Runs the full v7a experiment sequence for each of 9 models sequentially.
# Each model's output goes into its own subdirectory.
#
# Usage:
#   ./run_all_models_v7a.sh
#   ./run_all_models_v7a.sh --host http://localhost:11434

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${SCRIPT_DIR}/run_all_v7a_${TIMESTAMP}.log"
HOST="${1:---host http://localhost:11434}"

# Model name : output directory (relative to script location)
declare -A MODEL_DIRS
MODEL_DIRS["qwen3.5:27b"]="qwen35-27b"
MODEL_DIRS["qwen3.5:35B"]="qwen35-35b"
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
    "qwen3.5:35B"
    "qwen3.5:122b"
    "nemotron-3-nano:30b"
    "nemotron-cascade-2:30b"
    "nemotron-3-super:120b"
    "gemma4:31b"
    "gemma3:27b"
    "deepseek-r1:70b"
)

echo "========================================================"
echo "  8 STEPS TO ALIGNMENT — v7a ALL MODELS RUNNER"
echo "  $(date)"
echo "  Models: ${#MODELS[@]}"
echo "  Log: ${LOG_FILE}"
echo "========================================================"

PASS=0
FAIL=0
FAILED_MODELS=()

for MODEL in "${MODELS[@]}"; do
    OUTPUT_DIR="${SCRIPT_DIR}/${MODEL_DIRS[$MODEL]}"

    # Create output dir if it doesn't exist
    mkdir -p "${OUTPUT_DIR}"

    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "  Model:  ${MODEL}"
    echo "  Output: ${OUTPUT_DIR}"
    echo "  $(date)"
    echo "────────────────────────────────────────────────────────"

    if python3 "${SCRIPT_DIR}/run_v7a.py" \
        --model "${MODEL}" \
        --host "http://localhost:11434" \
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
echo "  Passed: ${PASS} / ${#MODELS[@]}"
if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo "  Failed: ${FAIL}"
    for M in "${FAILED_MODELS[@]}"; do
        echo "    - ${M}"
    done
fi
echo "  Log: ${LOG_FILE}"
echo "========================================================"
