#!/usr/bin/env bash
# _common.sh
# Shared helpers sourced by every pipeline/run_*.sh script. Not run directly.

# Always operate from the project root, wherever the caller started.
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# init_log_dir <stage-name>
# Creates logs/<stage>_<timestamp>/ (nested under $PIPELINE_LOG_DIR when called
# from run_pipeline.sh) and sets LOG_DIR.
init_log_dir() {
  local parent="${PIPELINE_LOG_DIR:-logs}"
  LOG_DIR="${parent}/$1_$(date +%Y-%m-%d_%H-%M-%S)"
  mkdir -p "$LOG_DIR"
  echo "Logging to: ${LOG_DIR}"
}

# _log_path <name> [args...]
# Per-file log path; script args are appended so parameterized runs don't collide.
_log_path() {
  local name="$1"; shift
  if [[ $# -gt 0 ]]; then
    name="${name}_$(printf '%s_' "$@" | tr -c 'A-Za-z0-9_-' '-')"
    name="${name%_}"
  fi
  echo "${LOG_DIR}/${name}_$(date +%H-%M-%S).txt"
}

# _fail <file> <log>
_fail() {
  echo "FAILED: $1" >&2
  echo "  log: $2" >&2
  echo "----- last 20 lines -----" >&2
  tail -n 20 "$2" >&2
  exit 1
}

# run_r <path/to/script.R> [args...]
# stdout and stderr go to the script's log file.
run_r() {
  local script="$1"; shift
  local log; log="$(_log_path "$(basename "$script" .R)" "$@")"
  local start=$SECONDS
  echo "  -> ${script} $*"
  Rscript "$script" "$@" > "$log" 2>&1 || _fail "$script" "$log"
  echo "     done ($((SECONDS - start))s)"
}

# run_r_console <path/to/script.R> <stdout-file>
# For scripts whose printed output is a deliverable: stdout is saved to
# <stdout-file>, stderr (messages, warnings) to the log.
run_r_console() {
  local script="$1" out="$2"
  local log; log="$(_log_path "$(basename "$script" .R)")"
  local start=$SECONDS
  echo "  -> ${script} (console: ${out})"
  mkdir -p "$(dirname "$out")"
  Rscript "$script" > "$out" 2> "$log" || _fail "$script" "$log"
  echo "     done ($((SECONDS - start))s)"
}

# find_quarto: sets QUARTO, falling back to the copy bundled with RStudio/Positron.
find_quarto() {
  if command -v quarto > /dev/null 2>&1; then
    QUARTO="quarto"
  elif [[ -x "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto" ]]; then
    QUARTO="/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"
  elif [[ -x "/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto" ]]; then
    QUARTO="/Applications/Positron.app/Contents/Resources/app/quarto/bin/quarto"
  else
    echo "Error: quarto not found. Install quarto or add it to PATH." >&2
    exit 1
  fi
}

# render_qmd <path/to/doc.qmd> <dest-dir | dest-file> [quarto args...]
# Renders in place, then moves the output (pdf/html/docx) to dest. Pass a file
# path as dest to rename, e.g. one PDF per -P parameter value.
render_qmd() {
  local qmd="$1" dest="$2"; shift 2
  [[ -n "${QUARTO:-}" ]] || find_quarto
  local log; log="$(_log_path "$(basename "$qmd" .qmd)" "$@")"
  local start=$SECONDS
  echo "  -> ${qmd} $*"
  "$QUARTO" render "$qmd" "$@" > "$log" 2>&1 || _fail "$qmd" "$log"

  local ext out=""
  for ext in pdf html docx; do
    if [[ -f "${qmd%.qmd}.${ext}" ]]; then out="${qmd%.qmd}.${ext}"; break; fi
  done
  if [[ -z "$out" ]]; then
    echo "FAILED: ${qmd} rendered but no pdf/html/docx found next to it" >&2
    exit 1
  fi
  if [[ "$dest" == *.* ]]; then
    mkdir -p "$(dirname "$dest")"
  else
    mkdir -p "$dest"
  fi
  mv "$out" "$dest"
  echo "     done ($((SECONDS - start))s) -> ${dest}"
}
