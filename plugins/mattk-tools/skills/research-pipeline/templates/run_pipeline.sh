#!/usr/bin/env bash
set -euo pipefail

# Run the full <PROJECT> pipeline: recreates every output from raw data.
# Usage: bash pipeline/run_pipeline.sh

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

PIPELINE_LOG_DIR="logs/run_pipeline_$(date +%Y-%m-%d_%H-%M-%S)"
export PIPELINE_LOG_DIR
mkdir -p "$PIPELINE_LOG_DIR"

# Mirror everything printed to the terminal into one pipeline log.
exec > >(tee -a "${PIPELINE_LOG_DIR}/pipeline.txt") 2>&1
echo "Pipeline logging to: ${PIPELINE_LOG_DIR}"
echo "Started: $(date)"
START=$SECONDS

# Record what produced this run so the results can be traced and reproduced.
{
  echo "date: $(date)"
  echo "git commit: $(git rev-parse HEAD 2>/dev/null || echo 'not a git repo')"
  echo "uncommitted changes:"
  git status --porcelain 2>/dev/null || true
  echo
  quarto --version 2>/dev/null | sed 's/^/quarto: /' || true
  echo
  Rscript -e 'sessionInfo()'
} > "${PIPELINE_LOG_DIR}/environment.txt" 2>&1 || true

# Stages, in dependency order. Add/remove to match the project's src/ folders.
bash pipeline/run_preprocessing.sh
bash pipeline/run_analyses.sh
bash pipeline/run_reports.sh
bash pipeline/run_manuscript.sh

echo "=== Pipeline complete in $(( (SECONDS - START) / 60 ))m $(( (SECONDS - START) % 60 ))s ==="
echo "Finished: $(date)"
