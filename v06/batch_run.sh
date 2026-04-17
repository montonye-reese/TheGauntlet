#!/bin/bash
# 8 Degrees — v6 Batch Runner
# Runs all models sequentially, outputs to v6/<modelname>/
#
# Usage:
#   cd ~/bench/research/8deg/v6
#   bash batch_run.sh
#
# To run a subset, comment out models you don't want.
# To resume a crashed run, use:
#   python3 run_deg8_v6.py --model <model> --resume v6/<modelname>/<output_file>.md --output-dir <modelname>/

SCRIPT="run_deg8_v6.py"
HOST="http://localhost:11434"

# ─────────────────────────────────────────────────────────────────────
# MODEL LIST — comment out any you don't want to run
# ─────────────────────────────────────────────────────────────────────
MODELS=(
    "gemma3:27b"
    "gemma4:31b"
    "nemotron-3-nano:30b"
    "nemotron-3-super:120b"
    "nemotron-cascade-2:30b"
    "qwen3.5:122b"
    "qwen3.5:27b"
    "qwen3.5:35b"
)

# ─────────────────────────────────────────────────────────────────────
# FOLDER MAPPING — model name to folder name
# ─────────────────────────────────────────────────────────────────────
declare -A FOLDERS
FOLDERS=(
    ["gemma3:27b"]="gemma3-27b"
    ["gemma4:31b"]="gemma4-31b"
    ["nemotron-3-nano:30b"]="nemotron-3-nano-30b"
    ["nemotron-3-super:120b"]="nemotron-3-super-120b"
    ["nemotron-cascade-2:30b"]="nemotron-cascade-2-30b"
    ["qwen3.5:122b"]="qwen35-122b"
    ["qwen3.5:27b"]="qwen35-27b"
    ["qwen3.5:35b"]="qwen35-35b"
)

# ─────────────────────────────────────────────────────────────────────
# RUN
# ─────────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  8 DEGREES — v6 BATCH RUNNER"
echo "  Models: ${#MODELS[@]}"
echo "  Host:   $HOST"
echo "============================================================"
echo ""

TOTAL=${#MODELS[@]}
CURRENT=0
FAILED=()

for MODEL in "${MODELS[@]}"; do
    CURRENT=$((CURRENT + 1))
    FOLDER="${FOLDERS[$MODEL]}"
    
    echo "────────────────────────────────────────────────────────────"
    echo "  [$CURRENT/$TOTAL] $MODEL → $FOLDER/"
    echo "────────────────────────────────────────────────────────────"
    
    # Ensure folder exists
    mkdir -p "$FOLDER"
    
    # Copy script into folder for provenance
    cp "$SCRIPT" "$FOLDER/$SCRIPT"
    
    # Run
    python3 "$SCRIPT" \
        --model "$MODEL" \
        --host "$HOST" \
        --output-dir "$FOLDER/" \
        2>&1 | tee "$FOLDER/v6-${FOLDER}.log"
    
    EXIT_CODE=${PIPESTATUS[0]}
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "  ⚠ $MODEL FAILED (exit code $EXIT_CODE)"
        echo "  Check $FOLDER/v6-${FOLDER}.log"
        FAILED+=("$MODEL")
    else
        echo ""
        echo "  ✓ $MODEL complete"
    fi
    
    echo ""
done

# ─────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  BATCH COMPLETE"
echo "  Total:  $TOTAL"
echo "  Failed: ${#FAILED[@]}"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "  Failed models:"
    for F in "${FAILED[@]}"; do
        echo "    - $F"
    done
fi
echo "============================================================"
