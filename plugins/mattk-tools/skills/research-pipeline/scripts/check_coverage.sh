#!/usr/bin/env bash
set -euo pipefail

# Check a project's pipeline/: syntax-check every script, then list src/ files
# that no pipeline script mentions by name.
# Usage: bash check_coverage.sh <project-root>

ROOT="${1:-.}"
cd "$ROOT"

if [[ ! -d pipeline ]]; then
  echo "No pipeline/ directory in $(pwd)"
  exit 1
fi

status=0

echo "=== Syntax check (bash -n) ==="
for f in pipeline/*.sh; do
  if bash -n "$f"; then
    echo "  ok      $f"
  else
    echo "  ERROR   $f"
    status=1
  fi
done

if command -v shellcheck > /dev/null 2>&1; then
  echo "=== shellcheck ==="
  # SC1091: can't follow sourced _common.sh; SC2034: vars used by sourced helpers
  shellcheck -x -e SC1091,SC2034 pipeline/*.sh && echo "  ok" || status=1
else
  echo "(shellcheck not installed; skipping lint)"
fi

echo "=== src/ files not mentioned in pipeline/ ==="
missing=0
while IFS= read -r f; do
  base="$(basename "$f")"
  stem="${base%.*}"
  if ! grep -qF -e "$f" -e "$base" pipeline/*.sh; then
    # Name may be built from a variable (e.g. "${name}.R"): look for the bare
    # stem, not followed by an extension (so foo.R doesn't vouch for foo.qmd).
    stem_re="$(printf '%s' "$stem" | sed 's/[.[\*^$]/\\&/g')"
    if grep -qE "(^|[^A-Za-z0-9_.-])${stem_re}([^A-Za-z0-9_.-]|\\.?\\\$|$)" pipeline/*.sh; then
      echo "  maybe   $f   (stem '$stem' appears; confirm by hand)"
    else
      echo "  MISSING $f"
    fi
    missing=$((missing + 1))
  fi
done < <(find src -type f \( -name '*.R' -o -name '*.qmd' \) \
           -not -path '*/archive/*' -not -path '*/misc/*' \
           -not -name '*template*' | sort)

if [[ $missing -eq 0 ]]; then
  echo "  none: every src/ script is referenced"
else
  echo "  $missing file(s) above: add them to a stage, or confirm they're intentionally"
  echo "  excluded (or covered by a glob loop like src/reports/*.qmd)."
fi

exit $status
