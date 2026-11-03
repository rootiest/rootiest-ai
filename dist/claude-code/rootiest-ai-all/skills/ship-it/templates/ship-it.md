# Shipping this project

Instructions for `/ship-it` and its steps. Each `##` section is read by the step of the same
name; anything left out uses that step's defaults. Delete sections you don't need.

Save as `docs/ship-it.md` to share with everyone working on the project, or as
`AGENTS_ship-it.md` (repo root or `AGENTS/`) to keep it local. If both exist, the
`AGENTS_ship-it.md` file is used and `docs/ship-it.md` is ignored.

## ship-it
Rules for the whole run.
- Phases to skip, e.g. "No docs to sync; skip doc-it."

## doc-it
- Documentation root, if not `docs/` or the README.
- Files to keep in sync, and generated files or sections to leave alone.
- What counts as a breaking issue in the code audit, beyond syntax errors.

## push-it
- Branch naming, e.g. `feat/<topic>`, `fix/<topic>`.
- Commit scopes in use.
- Checks to run before pushing, e.g. `just test`, `npm run lint`.
- PR target branch, if not `main`.

## verify-it
- Checks that matter, and known-flaky jobs to re-run once before reporting a failure.
- How long CI normally takes.
- "This project has no CI" if that is expected.

## merge-it
- Merge method: merge commit, squash, or rebase.
- When to merge without asking, e.g. "If the PR only changes `docs/` or `*.md`, merge without
  approval." or "Merge without approval unless the PR touches `src/core/`." Anything not covered
  here asks first.
- Whether stacked branches may be force-pushed after a squash/rebase merge without asking.
- Order for independent PRs, if not by PR number.

## sync-it
- Automated commits to expect after a merge, e.g. "CI pushes regenerated `dist/`."
- Steps to run after pulling, e.g. submodule update, regenerate lockfiles.

## prune-it
- Branches to keep beyond the defaults (`--keep` names).
