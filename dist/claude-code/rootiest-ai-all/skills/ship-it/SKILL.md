---
name: ship-it
description: Ships pending work end to end - syncs docs and audits code, opens a PR, waits for CI, then after the merge syncs main and prunes merged branches.
version: 2.0.0
user-invocable: true
author: Rootiest
---

# /ship-it

## Instructions
Run the phases below in order. Each phase is a sub-skill of this plugin: invoke it and follow
its instructions. Do not repeat its steps here, and do not start the next phase unless the
current one passed its gate.

Sub-skills are named by skill, not plugin: `/ship-it:doc-it` is the `doc-it` skill. When installed
from the `rootiest-ai-all` bundle, the same skills sit under that prefix instead.

Pass along what earlier phases produced (PR number, branch, commit SHAs) so the sub-skills don't
have to rediscover it.

| Phase | Sub-skill | Gate to continue |
|-------|-----------|------------------|
| 1. Docs sync & code audit | `/ship-it:doc-it` | No breaking code issues found. If any are, HALT and report; publish nothing. |
| 2. Publish | `/ship-it:push-it` | Branch pushed and PR opened (includes the Phase 1 docs changes). |
| 3. CI | `/ship-it:verify-it` on the PR head commit | Pass, or no CI registered. On failure or a repeated timeout, report and stop. |
| — | Stop | Report the PR link and CI result, then STOP. The user merges. |
| 4. Post-merge sync | `/ship-it:sync-it` | Runs ONLY when the user says the PR is merged, or explicitly asks you to merge it (merge it, then continue). |
| 5. Branch cleanup | `/ship-it:prune-it` | Runs right after Phase 4, only if Phase 4 ran. |

## Phase notes
- **Phase 5:** dry-run, show the plan, then run it without asking for confirmation. Do not pass
  `--force` unless the user asked for it. This removes the merged PR's head branch, locally and on
  the remote, whether or not the merge already deleted it, along with any other merged or
  orphaned branches.
- **Fallback:** if a sub-skill is unavailable, do its job inline from its description. For Phase 5
  that means deleting only this PR's head branch: `git push origin --delete <branch>` (skip if the
  remote branch is already gone), then `git fetch --prune` and `git branch -D <branch>`.

## Final report
One summary covering every phase that ran: docs changes, the PR link, CI results (PR head and
merge commit), commits pulled into `main`, and branches deleted and kept.
