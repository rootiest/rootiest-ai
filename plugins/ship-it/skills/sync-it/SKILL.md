---
name: sync-it
description: After a PR merges, waits for CI on the merge commit and fast-forwards local main, pulling in any automated post-merge commits.
version: 2.0.0
user-invocable: true
author: Rootiest
---

# /ship-it:sync-it

Phase 4 of `/ship-it`. Also runs on its own.

## Trigger Conditions
1. The user types `/ship-it:sync-it`, or asks to bring local `main` up to date after a merge.
2. `/ship-it` reaches Phase 4: the user says the PR is merged, or asked you to merge it and the
   merge succeeded.

## Inputs
- **PR number**: given by the caller. Run standalone, use the most recently merged PR whose head
  is the current branch; if that is ambiguous, ask.
- `<owner>/<repo>` and the platform come from `git remote get-url origin`.

## Steps
1. Get the merge commit from the PR, not from `origin/main` (later commits may already be there):
   - Gitea: `tea api "/repos/<owner>/<repo>/pulls/<n>" | jq -r .merge_commit_sha`
   - GitHub: `gh pr view <n> --json mergeCommit -q .mergeCommit.oid`
   If the PR is not merged, report that and stop.
2. Watch CI on that commit with `/ship-it:verify-it`, passing the merge commit SHA. "No CI" is
   normal here. A failure is reported, and sync still continues: the merge already happened.
3. Pull any automated commits (e.g. generated files pushed by CI after the merge):
   ```bash
   git switch main && git pull --ff-only origin main
   ```
   Use the repo's default branch if it is not `main`. If the pull is not a fast-forward, stop and
   report; never merge or rebase local `main` on your own.

## Report
The merge commit, its CI result, and the commits pulled into local `main`.
