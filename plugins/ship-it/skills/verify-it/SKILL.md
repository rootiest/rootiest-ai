---
name: verify-it
description: Waits for CI on a commit (a PR head, or a merge commit after merging) with one blocking watcher and reports pass, fail, or no CI.
version: 2.2.0
user-invocable: true
author: Rootiest
---

# /ship-it:verify-it

Phase 3 of `/ship-it`, and the CI watch inside `/ship-it:sync-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## verify-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## verify-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

## Trigger Conditions
1. The user types `/ship-it:verify-it`, or asks to wait for / watch / check CI on a PR or commit.
2. `/ship-it` reaches Phase 3.
3. `/ship-it:sync-it` needs the merge commit watched.

## Inputs
- **Commit**: the SHA to watch. When the caller passes one, use it. Run standalone, default to the
  head of the current branch's open PR, else `git rev-parse HEAD`.
- **PR number** (GitHub only): the PR for the current branch when not given.
- `<owner>/<repo>` and the platform come from `git remote get-url origin`.

## Rules
- Wait with ONE blocking watcher. Never poll with `sleep` or repeated status checks.
- Run the watcher as a background command (Claude Code: Bash `run_in_background: true`); you are
  re-invoked when it exits. Without background support, run it in the foreground with a tool
  timeout longer than the watcher's.

## Gitea
Run the bundled watcher, `scripts/tea-ci-watch.sh` in this skill's directory (the directory
holding this SKILL.md). Use its absolute path; it is not on `PATH`. Requires `tea` (logged in)
and `jq`.
```bash
bash "<skill-dir>/scripts/tea-ci-watch.sh" "<owner>/<repo>" "<commit-sha>"
```

| Exit | Meaning | Action |
|------|---------|--------|
| 0 | All checks passed | Report pass |
| 1 | A check failed (jobs printed) | Read the failing job's logs, report, stop |
| 2 | API/usage error | Report the error, stop |
| 3 | No CI registered | Report "no CI on this commit". Not a failure. |
| 124 | Timed out | Re-run the watcher once; if it times out again, report and stop |

## GitHub
For a PR head:
```bash
gh pr checks <pr-number> --watch --fail-fast
```
If it reports no checks yet, retry once with another background run, not a sleep loop.

For a merge commit (no PR to watch), find its runs and watch them:
```bash
gh run list --commit <commit-sha> --json databaseId -q '.[].databaseId'
gh run watch <run-id> --exit-status
```
No runs means no CI on that commit; report it, not a failure.

## Report
The commit watched, the result (pass / fail with the failing job / no CI / timed out), and the
PR link when there is one.
