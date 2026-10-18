#!/usr/bin/env bash
set -euo pipefail

# Run all STAGE scripts in dependency order.
# Usage: bash pipeline/run_STAGE.sh
# Requires run_UPSTREAM_STAGE.sh to have been run first.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
init_log_dir "run_STAGE"
mkdir -p output/STAGE

echo "=== Layer 0: scripts with no upstream dependencies ==="
run_r src/STAGE/SCRIPT_A.R
run_r src/STAGE/SCRIPT_B.R

echo "=== Layer 1: <what these depend on> ==="
run_r src/STAGE/SCRIPT_C.R   # needs output/STAGE/SCRIPT_A.rds

# --- Patterns to use as needed (delete the rest) ---

# Parameterized runs (one call per combination):
# for group in all highest likely; do
#   run_r src/analysis/analysis-groupwise.R --group "$group"
# done

# Console output is a deliverable:
# run_r_console src/manuscript/manu-table-1.R output/manuscript/manu-table-1-console.txt

# Slow step:
# echo "NOTE: <script> runs <what> and can take a long time."
# run_r src/manuscript/SLOW_SCRIPT.R

# Render every report in a folder:
# for qmd in src/reports/*.qmd; do
#   [[ "$(basename "$qmd")" == *template* ]] && continue
#   render_qmd "$qmd" output/reports
# done

# Render one doc per parameter value:
# render_qmd src/reports/results.qmd "output/reports/results_${group}.pdf" -P group:"$group"

echo "=== STAGE complete ==="
