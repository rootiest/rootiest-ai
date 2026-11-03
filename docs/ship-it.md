# Shipping this project

Instructions for `/ship-it` and its steps. Each `##` section is read by the step of the same
name; anything left out uses that step's defaults.

## doc-it
- `README.md` is the documentation root. `docs/` holds only this file.
- Never edit `dist/` or `.claude-plugin/`; CI generates them.

## push-it
- Before pushing, run `python3 scripts/generate_plugins.py --check`.
- Change only `plugins/`, `scripts/`, `manifest.yaml`, `README.md` and `docs/`. Do not commit
  regenerated `dist/` or `.claude-plugin/` output.

## verify-it
- One workflow on PRs: `Generate plugin manifests` runs the `--check` validation. It takes about
  a minute.

## sync-it
- After a merge that touches `plugins/`, `scripts/` or `manifest.yaml`, CI pushes a
  `chore(plugins): regenerate plugin manifests` commit to `main`. Wait for the merge commit's CI
  to finish before pulling, so local `main` picks that commit up.
