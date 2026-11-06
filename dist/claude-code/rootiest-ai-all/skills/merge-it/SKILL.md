---
name: merge-it
description: Merges one PR or a set of PRs in the right order (stacks bottom-up), after checking CI and reviews, with user approval unless the project's rules allow merging without it. Waits for post-merge automated commits between merges.
version: 2.4.0
user-invocable: true
author: Rootiest
---

# /ship-it:merge-it

Phase 4a of `/ship-it`, before `/ship-it:sync-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## merge-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## merge-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

Things the section typically sets: merge method, when merging needs no approval, ordering rules
for independent PRs, and automated commits to wait for after a merge.

## Trigger Conditions
1. The user types `/ship-it:merge-it`, or asks to merge a PR or a stack of PRs.
2. `/ship-it` reaches Phase 4a.

## Inputs
- **PRs**: the numbers the caller or user gave. Without any, use the open PR whose head is the
  current branch, plus the open PRs stacked on it. If that is ambiguous, ask.
- `<owner>/<repo>` and the platform come from `git remote get-url origin`.

## Step 1: Order the PRs
- **Stacks:** a PR whose base branch is another open PR's head is stacked on it. Merge parents
  before children, bottom-up.
- **Independent PRs:** follow the project's ordering rule; otherwise merge in ascending PR number.
- Merge one at a time. Never merge a child before its parent.

## Step 2: Check each PR before merging
Re-check each PR right before its turn, since earlier merges change things.

| Check | Gitea | GitHub |
|-------|-------|--------|
| Open and mergeable | `tea api "/repos/<owner>/<repo>/pulls/<n>"`: `.state == "open"`, `.mergeable == true` | `gh pr view <n> --json state,mergeable`: `OPEN`, `MERGEABLE` |
| No changes requested | `tea api "/repos/<owner>/<repo>/pulls/<n>/reviews"`: no latest review per reviewer with `state == "REQUEST_CHANGES"` | `gh pr view <n> --json reviewDecision`: not `CHANGES_REQUESTED` |
| CI green | `/ship-it:verify-it` on the PR head commit | same |

Skip the CI watch when the caller already watched this exact head commit and it passed. "No CI"
is not a failure. If any check fails, stop before merging this PR; PRs already merged stay
merged. Report which PR stopped and why.

## Step 3: Approval
The default is to ask before merging. Show the PRs in merge order with title, base, and merge
method, and wait for the user's answer.

Do not ask when either is true:
- The user already asked for these exact PRs to be merged in this conversation ("merge it",
  "merge #12 and #13"). That request is the approval.
- The project's `## merge-it` section says this PR can merge without approval, and the PR meets
  its condition. Check the condition against the facts, e.g. the PR's changed files
  (`git diff --name-only <base>...<head>`), labels, or author. When it applies, say which rule
  matched. If it is unclear whether it applies, ask.

Approval can differ per PR: merge those that are approved, and stop at the first one that isn't,
since everything stacked above it has to wait anyway.

## Step 4: Merge
Use the project's merge method, else the repository default (merge commit).
- Gitea: `tea pr merge <n> --style <merge|squash|rebase|rebase-merge>`
- GitHub: `gh pr merge <n> --<merge|squash|rebase>`

Do not delete the head branch here; `/ship-it:prune-it` does that. Then confirm the merge and
get the merge commit:
- Gitea: `tea api "/repos/<owner>/<repo>/pulls/<n>" | jq -r '.merged, .merge_commit_sha'`
- GitHub: `gh pr view <n> --json state,mergeCommit -q '.state, .mergeCommit.oid'`

## Step 5: Before the next PR
Skip this step after the last PR.

1. **Wait for post-merge work.** Watch the merge commit with `/ship-it:verify-it`. Then
   `git fetch origin` and look for commits on the base branch after the merge commit
   (`git log --oneline <merge-sha>..origin/<base>`). If the project lists automated commits to
   expect and they haven't landed yet, re-run the watch once on the newest base-branch commit,
   then look again. Don't continue while one is still expected.
2. **Retarget stacked children.** A child whose base was the merged PR's head moves to the
   parent's base:
   - Gitea: `tea api -X PATCH "/repos/<owner>/<repo>/pulls/<child>" -f base=<new-base>`
   - GitHub: `gh pr edit <child> --base <new-base>`
3. **Squash or rebase merges** leave the child carrying the parent's original commits, which
   then conflict. Rebase the child onto the new base, dropping the parent's commits:
   ```bash
   git fetch origin
   git rebase --onto origin/<new-base> <old-parent-head-sha> <child-branch>
   git push --force-with-lease origin <child-branch>
   ```
   This force-pushes, so ask first unless the user or the project's section already allows it.
   Plain merge commits need no rebase.
4. Go back to Step 2 for the next PR.

## Report
For each PR in order: merged (with merge commit and method) or stopped (and why), plus which
approval rule applied, if any. Hand the last merge commit, and its CI result if you watched it, to
`/ship-it:sync-it`.
