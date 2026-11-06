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

## merge-it
- Merge method: merge commit.
- Between merges, wait for the `chore(plugins): regenerate plugin manifests` commit (see
  `sync-it`) before merging the next PR.

## sync-it
- After a merge that touches `plugins/`, `scripts/` or `manifest.yaml`, CI pushes a
  `chore(plugins): regenerate plugin manifests` commit to `main`. Wait for the merge commit's CI
  to finish before pulling, so local `main` picks that commit up.

## deploy-it
Deploying means refreshing the local install of the marketplace, after `sync-it` has pulled the
regenerate commit into `main`. It only changes this machine.

1. Check where `rootiest-ai` comes from: `claude plugin marketplace list`.
   - **A local folder** (`~/.claude/plugins/marketplaces/rootiest-ai-private`): it is a private
     overlay build, which a plain update would only re-read unchanged. Run `scripts/deploy.sh` in
     the overlay repo, as its own `## deploy-it` describes; it pulls this repo's `main` and
     rebuilds on top of it. Stop here.
   - **This repo** (GitHub or Gitea): continue.
2. `claude plugin marketplace update rootiest-ai`
3. Verify: `claude plugin list` shows each installed `@rootiest-ai` plugin at the version in its
   `plugins/<plugin>/plugin.json`. Update any that lag with
   `claude plugin update <plugin>@rootiest-ai`. List installed plugins that the marketplace no
   longer has and ask before uninstalling them.

The GitHub copies of this repo are Gitea push mirrors that sync on every commit: nothing to deploy
for them, and never push to them directly (the next sync overwrites it).
