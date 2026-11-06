---
name: ship-it
description: Ships pending work end to end - syncs docs and audits code, opens a PR, waits for CI, merges with approval, syncs main, prunes merged branches, and deploys.
version: 2.4.0
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

## Project instructions
Before Phase 1, look for the project's ship-it instructions once and use the first file that
exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

- The `## ship-it` section holds rules for the whole run (e.g. phases to skip). Follow it.
- Each other `## <sub-skill>` section belongs to that step. Hand it to the sub-skill when you
  invoke it, so it doesn't search again. Where a section conflicts with a sub-skill's defaults,
  the section wins.
- No file means every step uses its defaults.

`templates/ship-it.md` in this skill's directory is a starting point listing every section, and
`templates/example.md` is a filled-in example.

## Phases

| Phase | Sub-skill | Gate to continue |
|-------|-----------|------------------|
| 1. Docs sync & code audit | `/ship-it:doc-it` | No breaking code issues found. If any are, HALT and report; publish nothing. |
| 2. Publish | `/ship-it:push-it` | Branch pushed and PR opened (includes the Phase 1 docs changes). |
| 3. CI | `/ship-it:verify-it` on the PR head commit | Pass, or no CI registered. On failure or a repeated timeout, report and stop. |
| 4a. Merge | `/ship-it:merge-it` | The PR merged. It asks for approval unless the project's rules allow merging without it. If the user declines, report the PR link and STOP. |
| 4b. Post-merge sync | `/ship-it:sync-it` | Runs after 4a merged the PR, or when the user later says they merged it. |
| 5. Branch cleanup | `/ship-it:prune-it` | Runs right after Phase 4b, only if 4b ran. |
| 6. Deploy | `/ship-it:deploy-it` | Runs after Phase 5, whatever its result, only if 4b ran. It asks for approval unless the project's rules allow deploying without it. "Nothing to deploy" and a declined deploy both end the run successfully. |

## Phase notes
- **Phase 4a:** hand `merge-it` the PR number and the head commit Phase 3 already watched, so it
  doesn't watch CI again. When the user stops at 4a and later says the PR is merged (or asks you
  to merge it), continue from there.
- **Phase 4b:** hand `sync-it` the merge commit, and its CI result if `merge-it` watched it.
- **Phase 5:** dry-run, show the plan, then run it without asking for confirmation. Do not pass
  `--force` unless the user asked for it. This removes the merged PR's head branch, locally and on
  the remote, whether or not the merge already deleted it, along with any other merged or
  orphaned branches.
- **Phase 6:** a failed deploy is reported as the run's result; don't retry or roll back unless
  the project's `## deploy-it` section says to.
- **Fallback:** if a sub-skill is unavailable, do its job inline from its description. For Phase 5
  that means deleting only this PR's head branch: `git push origin --delete <branch>` (skip if the
  remote branch is already gone), then `git fetch --prune` and `git branch -D <branch>`.

## Final report
One summary covering every phase that ran: docs changes, the PR link, CI results (PR head and
merge commit), the merge and any approval rule applied, commits pulled into `main`, branches
deleted and kept, and the deploy result (or that there was nothing to deploy). Name the project
instructions file used, or say there was none.

If there was none and a step had to work out something project-specific (which checks to run,
where the docs live, an expected automated commit), offer to save what you learned to
`docs/ship-it.md`, starting from `templates/ship-it.md`, so the next run doesn't have to work
it out again. Only offer; don't write it unasked.
