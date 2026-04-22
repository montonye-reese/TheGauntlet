#!/usr/bin/env bash
# 8 Degrees — v18 Orchestration Script
#
# v18 expanded-hull trial: 3 chassis variants × 8 models = 24 runs.
#   - v18a: Chassis A (v17 baseline language) — "How would X respond..."
#   - v18b: Chassis B (receive-mode) — "Read X on the framework..."
#   - v18c: Chassis A/B alternation by position
#
# Tests:
#   - Does Postrel (G4) eliminate super's v17 "no human override" refrain?
#   - Does Calf 269 (G10) preserve F1 non-human scope through P14?
#   - Does Chassis B reduce the 7-section scaffolding? (H1)
#   - Does chassis rotation disrupt perseveration attractors? (H1 via v18c)
#
# Behavior:
#   - Skips runs that already have a final-snapshot file.
#   - Continues past failures (does not `set -e`).
#   - Logs start/end timestamps and duration per combo.
#
# Usage:
#   ./run_v18.sh                        # all variants × all models
#   ./run_v18.sh a                      # v18a only × all models (one Spark)
#   ./run_v18.sh b                      # v18b only × all models (another Spark)
#   ./run_v18.sh c                      # v18c only × all models (third Spark)
#   ./run_v18.sh "" super               # all variants × super only
#   ./run_v18.sh a super                # v18a × super only (single run)
#
# Output: .md logs and framework snapshots land in
#         v18{a,b,c}_cold/<model-dir>/ (per-model subdirectory, v12-style:
#         dots stripped, colons → dashes; e.g. qwen3.5:122b → qwen35-122b).
#
# Change log:
#   2026-04-22 — switched output from flat v18{a,b,c}_cold/ to per-model
#                subdirectories to match v12 convention. Previous flat-
#                output version preserved as run_v18.sh.bak for reference.
#                Skip check looks only at the nested location; finish
#                migrating any flat-layout files before re-running, or
#                completed models will be re-run.

set -uo pipefail  # continue on error; no -e

V18_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$V18_DIR"

VARIANT_FILTER="${1:-}"  # "a" | "b" | "c" | "" for all
MODEL_FILTER="${2:-}"    # substring match on model name, "" for all

VARIANTS=(a b c)

# Models ordered large-to-small so big runs start first (most informative if we stop early).
# Nemotrons grouped, Qwens grouped, Gemmas grouped for family-level comparison.
MODELS=(
    nemotron-3-super:120b
    qwen3.5:122b
    gemma4:31b
    nemotron-cascade-2:30b
    nemotron-3-nano:30b
    qwen3.6:35b
    qwen3.5:27b
)

# Per-model output directory names (v12 convention: dots stripped, colons → dashes).
declare -A MODEL_DIRS
MODEL_DIRS["nemotron-3-super:120b"]="nemotron-3-super-120b"
MODEL_DIRS["qwen3.5:122b"]="qwen35-122b"
MODEL_DIRS["gemma4:31b"]="gemma4-31b"
MODEL_DIRS["nemotron-cascade-2:30b"]="nemotron-cascade-2-30b"
MODEL_DIRS["nemotron-3-nano:30b"]="nemotron-3-nano-30b"
MODEL_DIRS["qwen3.6:35b"]="qwen36-35b"
MODEL_DIRS["qwen3.5:27b"]="qwen35-27b"

TOTAL=0
SKIPPED=0
COMPLETED=0
FAILED=0

GLOBAL_START=$(date +%s)

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  v18 orchestration start — $(date +%Y-%m-%d\ %H:%M:%S)"
echo "  Variant filter: ${VARIANT_FILTER:-<all>}"
echo "  Model filter:   ${MODEL_FILTER:-<all>}"
echo "════════════════════════════════════════════════════════════"

for VARIANT in "${VARIANTS[@]}"; do
    if [[ -n "$VARIANT_FILTER" && "$VARIANT" != "$VARIANT_FILTER" ]]; then
        continue
    fi

    QS_FILE="v18${VARIANT}_cold/v18${VARIANT}_qs_cold.md"
    OUT_DIR="v18${VARIANT}_cold"

    if [[ ! -f "$QS_FILE" ]]; then
        echo "[$(date +%H:%M:%S)] ERROR: QS file missing: $QS_FILE — skipping variant $VARIANT" >&2
        continue
    fi

    for MODEL in "${MODELS[@]}"; do
        if [[ -n "$MODEL_FILTER" && "$MODEL" != *"$MODEL_FILTER"* ]]; then
            continue
        fi

        TOTAL=$((TOTAL + 1))
        MODEL_SAFE="${MODEL//:/_}"
        MODEL_DIR="${OUT_DIR}/${MODEL_DIRS[$MODEL]}"
        FINAL_FILE="${MODEL_DIR}/framework_${MODEL_SAFE}_v18${VARIANT}_cold_final.md"

        if [[ -f "$FINAL_FILE" ]]; then
            echo "[$(date +%H:%M:%S)] SKIP  v18${VARIANT} × $MODEL  (final snapshot exists)"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        mkdir -p "$MODEL_DIR"

        echo ""
        echo "────────────────────────────────────────────────────────────"
        echo "  [$(date +%H:%M:%S)] START v18${VARIANT} × $MODEL"
        echo "  QS:     $QS_FILE"
        echo "  Output: $MODEL_DIR/"
        echo "────────────────────────────────────────────────────────────"

        RUN_START=$(date +%s)
        RUN_OK=0

        if python3 v18_run.py \
            --qs "$QS_FILE" \
            --model "$MODEL" \
            --output-dir "$MODEL_DIR"; then
            RUN_OK=1
        else
            # Retry once with flipped b↔B in param-size tag
            # (ollama cp sometimes changes case, e.g. qwen3.6:35b → qwen3.6:35B).
            MODEL_ALT=""
            if [[ "$MODEL" == *b ]]; then
                MODEL_ALT="${MODEL%b}B"
            elif [[ "$MODEL" == *B ]]; then
                MODEL_ALT="${MODEL%B}b"
            fi
            if [[ -n "$MODEL_ALT" ]]; then
                echo "[$(date +%H:%M:%S)] RETRY v18${VARIANT} × $MODEL → $MODEL_ALT (case flip)"
                if python3 v18_run.py \
                    --qs "$QS_FILE" \
                    --model "$MODEL_ALT" \
                    --output-dir "$MODEL_DIR"; then
                    RUN_OK=1
                fi
            fi
        fi

        RUN_END=$(date +%s)
        ELAPSED=$((RUN_END - RUN_START))
        MINS=$((ELAPSED / 60))
        SECS=$((ELAPSED % 60))
        if (( RUN_OK )); then
            echo "[$(date +%H:%M:%S)] DONE  v18${VARIANT} × $MODEL  (${MINS}m ${SECS}s)"
            COMPLETED=$((COMPLETED + 1))
        else
            echo "[$(date +%H:%M:%S)] FAIL  v18${VARIANT} × $MODEL  (${MINS}m ${SECS}s — continuing)"
            FAILED=$((FAILED + 1))
        fi
    done
done

GLOBAL_END=$(date +%s)
TOTAL_ELAPSED=$((GLOBAL_END - GLOBAL_START))
TOTAL_HOURS=$((TOTAL_ELAPSED / 3600))
TOTAL_MINS=$(( (TOTAL_ELAPSED % 3600) / 60 ))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  v18 ORCHESTRATION COMPLETE — $(date +%Y-%m-%d\ %H:%M:%S)"
echo "  Wall time: ${TOTAL_HOURS}h ${TOTAL_MINS}m"
echo "  Total:     $TOTAL"
echo "  Completed: $COMPLETED"
echo "  Skipped:   $SKIPPED  (already done)"
echo "  Failed:    $FAILED"
echo "════════════════════════════════════════════════════════════"

# Non-zero exit if any run failed
if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
