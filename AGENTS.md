# Agent instructions for this repository

Do not run broad staging commands such as `git add .`, `git add -A`, or `git add --` unless explicitly asked.

Do not add generated outputs, virtual environments, raw data, cache folders, or local analysis artifacts to Git.

Before staging files, always show:
- `git status --short`
- the exact files proposed for staging
- any files larger than 20 MB

Generated or local-only paths include:
- `outputs/`
- `results/`
- `cache/`
- `tmp/`
- `temp/`
- `.venv/`
- `.venv_*/`
- `.mplconfig/`
- `*.mat`, except explicitly curated files in `resources/templates/`

Generated or local-only paths include:

- scratch/
- outputs/
- results/
- cache/
- tmp/
- temp/
- .venv/
- .venv_*/
- .mplconfig/
- *.mat, except explicitly curated files in resources/templates/
Exploratory agent work should write temporary figures, logs, CSVs, scripts, and intermediate analysis files under a task-specific folder in `scratch/`, for example:

`scratch/taskName_YYYYMMDD/`

At the end of the task, report all created files and recommend which, if any, should be promoted to tracked locations such as `scripts/`, `docs/`, `figures/`, `resources/`, or `NCMposter/`.

Do not promote, stage, move, or delete files unless explicitly asked.

Prefer selective staging:
`git add path/to/file1 path/to/file2`

Never run cleanup/destructive commands such as `git clean`, `git reset --hard`, `git rm`, `git gc`, or history rewrite commands unless explicitly asked.

cat >> AGENTS.md <<'EOF'

## Standard maintenance commands requested by the user

When the user asks to "cleanup", do not interpret this as permission to delete files immediately.

Cleanup means:
1. Inspect `git status --short`.
2. Identify generated, temporary, duplicate, cache, local-data, or intermediate files.
3. Check for large files with:
   `find . -path './.git' -prune -o -type f -size +20M -print`
4. Report which files appear safe to delete, move, ignore, or keep.
5. Ask before deleting, moving, or running destructive commands.
6. Never run `git clean`, `rm`, `git reset --hard`, or `git rm` unless explicitly instructed.

When the user asks to "document", this means:
1. Update relevant Markdown documentation, development logs, handoff notes, or README sections.
2. Prefer concise, factual notes over broad claims.
3. Include what changed, why it changed, and how to run or reproduce the relevant step.
4. If new generated files were created, document where they are and whether they are temporary or curated.
5. Do not invent conclusions beyond what the code/results support.

When the user asks to "commit", this means:
1. Run `git status --short`.
2. Show the exact files proposed for staging.
3. Check for proposed files larger than 20 MB.
4. Stage only named files with selective `git add path/to/file`.
5. Do not use `git add .`, `git add -A`, or `git add --`.
6. Use a concise commit message describing the actual change.
7. Do not commit generated scratch files, virtual environments, raw data, cache files, or local-only outputs.

When the user asks to "push", this means:
1. Confirm the working tree state with `git status --short`.
2. Confirm the recent commit with `git log --oneline -3`.
3. Run `git push`.
4. Report whether the push succeeded.

When the user asks to "cleanup, document, commit, and push", perform the sequence in this order:
1. Inspect repository status and generated files.
2. Propose cleanup actions; do not delete without explicit permission.
3. Update documentation if needed.
4. Propose the exact files to stage.
5. Commit only curated source/docs/config files.
6. Push only after the commit succeeds.

If any step reveals unexpected large files, generated outputs outside ignored folders, or untracked environments, stop and report before continuing.
EOF
