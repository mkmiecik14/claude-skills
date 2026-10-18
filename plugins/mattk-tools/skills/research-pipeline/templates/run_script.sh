#!/usr/bin/env bash
set -euo pipefail

# Run a single R script or render a single Quarto doc with pipeline logging.
# Usage (paths relative to the project root):
#   bash pipeline/run_script.sh src/analysis/<script>.R [args...]
#   bash pipeline/run_script.sh src/reports/<doc>.qmd [dest-dir] [quarto args...]
# The upstream outputs the script reads must already exist.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if [[ $# -lt 1 || ! -f "$1" ]]; then
  echo "Usage: bash pipeline/run_script.sh <path/to/script.R|doc.qmd> [args...]"
  [[ $# -ge 1 ]] && echo "Error: file not found: $1"
  exit 1
fi

target="$1"; shift
init_log_dir "run_script"

case "$target" in
  *.R)
    run_r "$target" "$@"
    ;;
  *.qmd)
    dest="${1:-output/reports}"
    [[ $# -gt 0 ]] && shift
    render_qmd "$target" "$dest" "$@"
    ;;
  *)
    echo "Error: expected a .R or .qmd file: ${target}"
    exit 1
    ;;
esac
