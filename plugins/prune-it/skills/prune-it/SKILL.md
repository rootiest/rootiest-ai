---
name: prune-it
description: Syncs the default branch and deletes local and remote branches that are already merged or whose remote branch is gone.
version: 1.0.0
user-invocable: true
author: Rootiest
---

# /prune-it

## Objective
Sweep up after merged work: fetch and prune the remote, fast-forward the default branch, and
delete every local and remote branch whose content is already in the default branch, plus local
branches whose remote branch was deleted. All of the logic lives in a bundled bash script, so the
result is the same whatever shell or config the user runs.

## Trigger Conditions
Activate this skill when one of the following is met:
1. The user types `/prune-it`.
2. The user asks to run `git-clean` (the Rootiest fish function this skill replaces), or to clean
   up, prune, tidy, or sweep up branches, e.g. "delete merged branches", "clean up stale
   branches", "get rid of old branches", "tidy up the repo after the merge".
3. `/ship-it` reaches its cleanup phase (Phase 5).
4. A PR you merged, or the user says was merged, leaves its head branch behind, locally or on
   the remote.

## Constraints
- **Not `git clean`**: "git-clean" here means branch cleanup. NEVER run the built-in `git clean`,
  which deletes untracked files in the working tree.
- **Use the script**: do not reimplement its checks with ad-hoc `git branch -d` loops. It detects
  merge-commit, fast-forward, rebase, and squash merges; plain `git branch --merged` misses the
  last two.
- **Always dry-run first**, and show the user the plan before deleting anything.
- **`--force` only on request**: pass it only when the user explicitly asks to delete branches
  that have unmerged commits. Otherwise report the kept branches and stop.
- **Never delete by hand** a branch the script kept. Each one was kept for a reason it prints
  (open PR, unmerged commits, another worktree, protected name).

## Prerequisites
- `git` and `bash`.
- Nothing else is required for local cleanup. To delete **remote** branches, the script must list
  open PRs, and it tries every way it knows until one works. It needs none of them in particular:
  1. The forge's CLI, scoped to the remote's host: `gh`, `tea`, or `glab`.
  2. `curl` with a token from the environment, sent only to the host the token belongs to:
     `GH_TOKEN`/`GITHUB_TOKEN`/`GITHUB_PERSONAL_ACCESS_TOKEN` (github.com),
     `GITEA_TOKEN`/`GITEA_ACCESS_TOKEN`/`FORGEJO_TOKEN` (the host in `GITEA_HOST`/`GITEA_URL`),
     `GITLAB_TOKEN`/`GITLAB_PRIVATE_TOKEN` (`GITLAB_HOST`, else gitlab.com).
  3. Anonymous `curl`, which works for public repositories.

  The forge is guessed from the host only to order the attempts, so self-hosted Gitea, Forgejo,
  GitLab, and GitHub Enterprise work without configuration. Responses are parsed with `jq`, or
  `python3` when `jq` is missing. If nothing works, the script skips remote deletion and still
  cleans local branches. Never print or echo a token yourself.
- The same checks back the `git-sweep` fish function in Rootiest's fish-config, so this skill
  and that function delete exactly the same branches.

## What It Deletes and Keeps

| Branch | Result |
|--------|--------|
| Local branch merged into `<remote>/<default>` (any merge strategy) | Deleted |
| Local branch whose remote branch is gone, content merged | Deleted |
| Local branch whose remote branch is gone, unmerged commits | Kept; deleted with `--force` |
| Remote branch merged into `<remote>/<default>`, no open PR | Deleted |
| Remote branch that is the head of an open PR, and local branches tracking it | Kept |
| Any branch with unmerged commits whose remote branch still exists | Kept |
| Default branch; `main`, `master`, `develop`, `dev`, `trunk`, `staging`, `production`, `gh-pages`, `release/*`; `--keep` names | Kept |
| Local branch checked out in another worktree | Kept |
| Local branch created but never committed to (no upstream) | Kept |

If the current branch is to be deleted, the script switches to the default branch first. If
tracked files have uncommitted changes, it keeps the branch and doesn't switch.

## Options

| User says | Flag |
|-----------|------|
| "keep X", "don't delete X" | `--keep X` (repeatable) |
| "local only", "don't touch the remote" | `--local-only` |
| "force", "delete unmerged gone branches too" | `--force` |
| A remote other than `origin` | `--remote NAME` |

## Execution Steps
The script is `scripts/prune-it.sh` in this skill's directory (the directory holding this
SKILL.md). Use its absolute path; it is not on `PATH`. Run it from inside the target repository.

1. Print the plan without changing anything (it does fetch and prune remote-tracking refs):
   ```bash
   bash "<skill-dir>/scripts/prune-it.sh" --dry-run [flags]
   ```
2. Show the user the `delete` and `keep` lines. If it printed `Nothing to delete.`, report that
   and stop.
3. Run the cleanup with the same flags. When `/ship-it` invoked this skill, or the user asked
   for the cleanup outright, continue without asking. Otherwise ask for confirmation first,
   since remote deletions affect everyone using the repository.
   ```bash
   bash "<skill-dir>/scripts/prune-it.sh" [flags]
   ```
   | Exit | Meaning | Action |
   |------|---------|--------|
   | 0 | Cleanup complete | Report |
   | 1 | A deletion failed (e.g. branch protection on the remote) | Report which, and the git error |
   | 2 | Not a repo, unknown option, or no default branch | Report the error, stop |
   If the fetch fails, the script warns, skips remote deletion, and still cleans local branches
   against the last fetched state. Say so in the report.
4. Report what was deleted (local and remote), what was kept and why, and the
   `Deleted branch <name> (was <sha>)` lines, so the user can restore a local branch with
   `git branch <name> <sha>`.
