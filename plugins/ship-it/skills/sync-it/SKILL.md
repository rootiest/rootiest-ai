---
name: sync-it
description: After a PR merges, waits for CI on the merge commit and fast-forwards local main, pulling in any automated post-merge commits.
version: 2.2.0
user-invocable: true
author: Rootiest
---

# /ship-it:sync-it

Phase 4b of `/ship-it`, after `/ship-it:merge-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## sync-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## sync-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

## Trigger Conditions
1. The user types `/ship-it:sync-it`, or asks to bring local `main` up to date after a merge.
2. `/ship-it` reaches Phase 4b: `/ship-it:merge-it` merged the PR, or the user says they merged
   it.

## Inputs
- **PR number and merge commit**: given by the caller. Run standalone, use the most recently merged PR whose head
  is the current branch; if that is ambiguous, ask.
- `<owner>/<repo>` and the platform come from `git remote get-url origin`.

## Steps
1. Get the merge commit from the PR, not from `origin/main` (later commits may already be there):
   - Gitea: `tea api "/repos/<owner>/<repo>/pulls/<n>" | jq -r .merge_commit_sha`
   - GitHub: `gh pr view <n> --json mergeCommit -q .mergeCommit.oid`
   If the PR is not merged, report that and stop.
2. Watch CI on that commit with `/ship-it:verify-it`, passing the merge commit SHA. Skip this
   when the caller already watched this merge commit and handed you the result. "No CI" is
   normal here. A failure is reported, and sync still continues: the merge already happened.
3. Pull any automated commits (e.g. generated files pushed by CI after the merge):
   ```bash
   git switch main && git pull --ff-only origin main
   ```
   Use the repo's default branch if it is not `main`. If the pull is not a fast-forward, stop and
   report; never merge or rebase local `main` on your own.

## Report
The merge commit, its CI result, and the commits pulled into local `main`.
