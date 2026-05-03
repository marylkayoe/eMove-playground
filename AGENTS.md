cat > AGENTS.md <<'EOF'
# Agent instructions for this repository

This is a MATLAB-first repository. Use MATLAB for analysis, plotting, and tests unless explicitly told otherwise.

Python may be used only as optional helper tooling for presentation/export polish when explicitly approved. Do not install Python packages, create virtual environments, or add Python plotting scripts unless the user explicitly asks.

If Python is necessary, use only the ignored local environment `.venv_fig/`. Do not install packages globally.

## Generated files and scratch workflow

Use `scratch/` for exploratory or intermediate generated files.

Exploratory agent work should write temporary figures, logs, CSVs, scripts, and intermediate analysis files under a task-specific folder, for example:

`scratch/taskName_YYYYMMDD/`

Do not write exploratory outputs directly into:

- `scripts/`
- `docs/`
- `figures/`
- `NCMposter/`
- `resources/`
- `outputs/`

unless explicitly asked.

At the end of exploratory work, report:

1. all files created,
2. which files are worth keeping,
3. which files are intermediate and safe to delete,
4. which files, if any, should be promoted to tracked folders.

Do not promote, stage, move, or delete files unless explicitly asked.

Generated or local-only paths include:

- `scratch/`
- `outputs/`
- `results/`
- `cache/`
- `tmp/`
- `temp/`
- `.venv/`
- `.venv_*/`
- `.venv_fig/`
- `venv/`
- `env/`
- `.mplconfig/`
- `*.mat`, except explicitly curated files in `resources/templates/`

Do not add generated outputs, virtual environments, raw data, cache folders, or local analysis artifacts to Git.

## MATLAB figure layout policy

Use MATLAB figure layout tools before manual positioning.

For multi-panel figures:

- use `tiledlayout` and `nexttile`,
- avoid manual `axes('Position', ...)` unless explicitly requested,
- set `TileSpacing` and `Padding` explicitly,
- use shared labels with `xlabel(tiledLayoutHandle, ...)` and `ylabel(tiledLayoutHandle, ...)` when appropriate.

For dense traces:

- do not place text labels directly on top of traces,
- prefer legends outside the axes,
- use small multiples instead of overplotting too many traces,
- use annotations only after checking axis limits and data ranges,
- if labels would collide, omit direct labels and provide a legend or separate key.

For categorical/group plots:

- prefer table-driven plotting,
- use consistent group order,
- avoid manually tuned x/y offsets unless documented.

For export:

- first render to `scratch/<taskName>_YYYYMMDD/`,
- inspect whether labels, legends, and traces overlap,
- revise layout before proposing promotion to tracked folders.

Do not claim a figure is final unless:

- axis labels are readable,
- legends do not cover data,
- panel labels do not collide with axes content,
- text labels do not overlap traces,
- exported PDF/PNG has been generated successfully.

## MATLAB coding style

This is a MATLAB-first repository. Use MATLAB for analysis, plotting, and tests unless explicitly told otherwise.

Prefer readable, explicit MATLAB over compact or clever code.

Use camelCase for variable and function names.

Use `index` rather than `idx` in variable names.

Do not use `ifelse`; MATLAB does not support it.

Prefer `inputParser` for public-facing function options unless there is a clear reason to use another pattern.

For functions intended for reuse:
- include a short help block,
- describe inputs and outputs,
- document important assumptions,
- keep side effects explicit.

For scripts:
- start with a short purpose statement,
- define configuration near the top,
- avoid hard-coded absolute paths unless explicitly needed,
- write exploratory outputs only under `scratch/`.

For helper functions used only within one file:
- define them as local functions at the end of the file,
- prefix local helper names with `LF_`.

Do not optimize prematurely. Prioritize:
1. correctness,
2. readability,
3. design clarity,
4. speed only when needed.
5. do not create local helpers for single-use code unless it improves readability.

When modifying existing MATLAB code:
- preserve existing behavior unless explicitly asked to change it,
- make small, reviewable edits,
- avoid broad rewrites,
- explain any change in data structure or output fields.

When adding new analysis code:
- prefer table/struct outputs with clear field names,
- avoid hidden global state,
- check input dimensions explicitly,
- fail with informative error messages.

## Git safety

Never run broad staging commands such as:

- `git add .`
- `git add -A`
- `git add --`

unless explicitly asked.

Prefer selective staging:

`git add path/to/file1 path/to/file2`

Before staging files, always show:

- `git status --short`,
- the exact files proposed for staging,
- any files larger than 20 MB.

Never run cleanup/destructive commands such as:

- `git clean`
- `git reset --hard`
- `git rm`
- `git gc`
- history rewrite commands

unless explicitly asked.

## Standard maintenance commands requested by the user

When the user asks to “cleanup”, do not interpret this as permission to delete files immediately.

Cleanup means:

1. Inspect `git status --short`.
2. Identify generated, temporary, duplicate, cache, local-data, or intermediate files.
3. Check for large files with:

   `find . -path './.git' -prune -o -type f -size +20M -print`

4. Report which files appear safe to delete, move, ignore, or keep.
5. Ask before deleting, moving, or running destructive commands.
6. Never run `git clean`, `rm`, `git reset --hard`, or `git rm` unless explicitly instructed.

When the user asks to “document”, this means:

1. Update relevant Markdown documentation, development logs, handoff notes, or README sections.
2. Prefer concise, factual notes over broad claims.
3. Include what changed, why it changed, and how to run or reproduce the relevant step.
4. If new generated files were created, document where they are and whether they are temporary or curated.
5. Do not invent conclusions beyond what the code/results support.

When the user asks to “commit”, this means:

1. Run `git status --short`.
2. Show the exact files proposed for staging.
3. Check for proposed files larger than 20 MB.
4. Stage only named files with selective `git add path/to/file`.
5. Do not use `git add .`, `git add -A`, or `git add --`.
6. Use a concise commit message describing the actual change.
7. Do not commit generated scratch files, virtual environments, raw data, cache files, or local-only outputs.

When the user asks to “push”, this means:

1. Confirm the working tree state with `git status --short`.
2. Confirm the recent commit with `git log --oneline -3`.
3. Run `git push`.
4. Report whether the push succeeded.

When the user asks to “cleanup, document, commit, and push”, perform the sequence in this order:

1. Inspect repository status and generated files.
2. Propose cleanup actions; do not delete without explicit permission.
3. Update documentation if needed.
4. Propose the exact files to stage.
5. Commit only curated source/docs/config files.
6. Push only after the commit succeeds.

If any step reveals unexpected large files, generated outputs outside ignored folders, or untracked environments, stop and report before continuing.
EOF