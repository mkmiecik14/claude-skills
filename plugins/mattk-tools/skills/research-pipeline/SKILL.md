---
name: research-pipeline
description: Build, extend, or audit a reproducible analysis pipeline of nested bash scripts in a project's pipeline/ directory, so that one command (bash pipeline/run_pipeline.sh) recreates every output from raw data. Use when the user wants to set up a pipeline for an R/Quarto research project, add a new script or stage to an existing pipeline/, reorder scripts by dependency, check that every analysis is covered by the pipeline, or make a project reproducible end to end.
---

# Research pipeline

Goal: running `bash pipeline/run_pipeline.sh` from a clean checkout plus the raw
`data/` recreates every processed dataset, analysis result, report, and
manuscript output. Every script that produces something used downstream is
called, in dependency order, by some script under `pipeline/`.

## Layout

```
pipeline/
  _common.sh            # shared helpers, sourced by every run_*.sh (not run directly)
  run_pipeline.sh       # top-level orchestrator: calls the stage scripts in order
  run_preprocessing.sh  # stage: src/prepro/*.R      -> output/prepro/
  run_analyses.sh       # stage: src/analysis/*.R    -> output/analysis/
  run_reports.sh        # stage: src/reports/*.qmd   -> output/reports/
  run_manuscript.sh     # stage: src/manuscript/*    -> output/manuscript/
  run_script.sh         # run any single .R / .qmd with the same logging
```

Stage names follow the project's `src/` folders (e.g. noh-survey uses `src/manu/`
and `run_manu.sh`). Add stages only for folders that exist; don't invent empty ones.

## Conventions

- `#!/usr/bin/env bash` and `set -euo pipefail` in every script.
- A header comment on every script: what it does, the usage line
  (`bash pipeline/<name>.sh`), and which stage must have run first (`Requires ...`).
- Scripts `cd` to the project root via `_common.sh`, so they work from any
  directory. All paths inside are relative to the project root.
- **Logging**: `run_pipeline.sh` exports `PIPELINE_LOG_DIR=logs/run_pipeline_<timestamp>`.
  Each stage creates `${PIPELINE_LOG_DIR:-logs}/run_<stage>_<timestamp>/`, so
  stages nest under the pipeline run, or go under `logs/` when run on their own.
  Each R script / Quarto doc logs to its own `<name>_<HH-MM-SS>.txt`.
- On failure, `run_r` / `render_qmd` print the failing script, its log path, and
  the last 20 lines of the log, then stop the whole pipeline.
- Inside a stage, group calls under `echo "=== Layer N: <why> ==="` headers by
  dependency depth. Put a trailing comment on any call whose dependency isn't obvious
  (`# needs output/prepro/redcap-joined.rds`). Cross-stage dependencies get their own
  labeled block (e.g. a prepro script that needs PCA results goes in the analyses
  stage after PCA).
- Each stage `mkdir -p`s the output directories it writes to.
- Quarto renders into the source folder, so `render_qmd` moves the result into
  `output/`. Use a `for qmd in src/reports/*.qmd` loop (skipping templates) when
  every report in a folder gets rendered the same way.
- Slow steps get an `echo "NOTE: ... can take a long time"` before them.
- Keep calls explicit, one line per script. Don't auto-discover R scripts with
  globs: the order is the dependency graph, and it should be readable.

## Templates

Copy these from this skill's `templates/` directory and fill them in:

| Template | Becomes |
|---|---|
| `_common.sh` | `pipeline/_common.sh` (copy as is) |
| `run_pipeline.sh` | `pipeline/run_pipeline.sh` |
| `run_stage.sh` | one `pipeline/run_<stage>.sh` per stage |
| `run_script.sh` | `pipeline/run_script.sh` (copy as is) |

`_common.sh` provides:
- `init_log_dir <stage-name>`: creates and sets `LOG_DIR`
- `run_r <script.R> [args...]`: runs an R script, stdout+stderr to its log (args are added to the log name, for parameterized runs like noh-survey's group loop)
- `run_r_console <script.R> <stdout-file>`: stdout saved as a deliverable (e.g. `output/manuscript/<name>-console.txt`), stderr to the log
- `render_qmd <doc.qmd> <dest-dir-or-file> [quarto args...]`: renders and moves the output; pass a file path as dest to rename it (e.g. one PDF per `-P group:...`)
- `find_quarto`: falls back to the Quarto bundled with RStudio/Positron

## Workflow

### 1. Survey the project
- List `src/` (and `fns/`, `config/`) and any existing `pipeline/`. If `pipeline/`
  exists, read every script before changing anything, and keep its style where
  it differs from these conventions (ask before migrating an established pipeline).
- Read the project's CLAUDE.md / README for stated run order.

### 2. Work out the dependency order
For every `.R` / `.qmd` in `src/`, find what it **reads** and **writes**:

```bash
grep -nE 'readRDS|read_rds|read_csv|read_excel|read\.csv|load\(|fread|readMat|source\(' <file>
grep -nE 'saveRDS|write_rds|write_csv|ggsave|save\(|writexl|write\.csv|pdf\(|png\(|tiff\(' <file>
```

Match each read to the script that writes that file. A read with no producer must
be raw input in `data/`; if it isn't, flag it (it's either a missing pipeline step
or an output that was made by hand). Assign layers: Layer 0 reads only `data/`;
Layer N reads outputs from layers < N. Show the user the resulting order for any
non-obvious cases before writing scripts.

Skip `archive/`, `misc/`, templates (`*template*`), and scratch scripts unless the
user says otherwise, and list what you skipped.

### 3. Write the scripts
Copy the templates, fill in stages and layers, `chmod +x pipeline/*.sh`.

### 4. Check coverage and syntax
```bash
bash <this-skill-dir>/scripts/check_coverage.sh <project-root>
```
This runs `bash -n` and `shellcheck` (if installed) on every pipeline script, then
lists `src/` files no pipeline script mentions by name. Files rendered by a glob
loop show up as unmentioned, so check those by hand. Every remaining file is either
added to the pipeline or confirmed as intentionally excluded.

### 5. Reproducibility audit
Grep `src/` and report (don't silently fix) any of these:
- `setwd(` or absolute paths (`/Users/`, `C:/`, `~/`): break on other machines
- randomness (`sample(`, `rnorm(`, `boot`, `simr`, `set.seed` missing) without a `set.seed()`
- interactive-only code: `View(`, `file.choose(`, `readline(`, `browser(`
- outputs written outside `output/` (except Quarto's render-then-move)
- `rm(list = ls())`: hides missing dependencies when scripts are run in one session

### 6. Run it
The full pipeline can take a long time and overwrites `output/`, so ask before
running it. Offer to run a single stage or `run_script.sh` on one file first. To
check from-scratch reproducibility, move `output/` aside (`mv output output.bak`),
don't delete it, then run `run_pipeline.sh` and compare.

### 7. Document it
Add or update a "Run the pipeline" section in the project's CLAUDE.md / README:
the one command, what each stage does, and how to run one script.

## Adding a script to an existing pipeline
1. Find what the new script reads (step 2) and so which stage and layer it belongs in.
2. Add one `run_r` line there, with a dependency comment if it isn't obvious.
3. If its outputs feed later scripts, check those are still in a later layer.
4. Run `scripts/check_coverage.sh`.
