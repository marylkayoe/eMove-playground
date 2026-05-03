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

Prefer selective staging:
`git add path/to/file1 path/to/file2`

Never run cleanup/destructive commands such as `git clean`, `git reset --hard`, `git rm`, `git gc`, or history rewrite commands unless explicitly asked.
