---
name: ship-it
description: Runs a comprehensive pre-flight audit, syncs the README, and publishes the changes to a new PR.
version: 1.2.0
user-invocable: true
author: Rootiest
---

# /ship-it

## Instructions
Execute the following phases sequentially. Do not proceed to the next phase unless the current one completes successfully.

1. Phase 1: Documentation Sync & Code Audit
   - Act as the `/docs-sync-audit` skill.
   - Scan all file changes since the last README edit and update the README to ensure it accurately reflects the current state of the codebase.
   - Audit all code files for any syntax errors, regressions, or issues.
   - CRITICAL: If any code errors or breaking issues are discovered during the audit, HALT the workflow immediately and report them to the user. Do not proceed to publishing.

2. Phase 2: Git Publish Workflow
   - Act as the `/git-publish-workflow` skill.
   - Create a new, descriptively named git branch.
   - Stage and commit all pending changes (including the newly updated README from Phase 1).
   - Push the branch to the remote repository.
   - Generate a Pull Request (PR) from the new branch into 'main'.

3. Phase 3: CI Verification
   - Wait for CI on the PR head commit with ONE blocking watcher. Never poll with `sleep` or repeated status checks.
   - Run the watcher as a background command (Claude Code: Bash `run_in_background: true`); you are re-invoked when it exits. Without background support, run it in the foreground with a tool timeout longer than the watcher's.
   - Derive `<owner>/<repo>` and the platform from `git remote get-url origin`.
   - Gitea:
     ```bash
     tea-ci-watch "<owner>/<repo>" "$(git rev-parse HEAD)"
     ```
     | Exit | Meaning | Action |
     |------|---------|--------|
     | 0 | All checks passed | Continue |
     | 1 | A check failed (jobs printed) | Read the failing job's logs, report, stop |
     | 2 | API/usage error | Report the error, stop |
     | 3 | No CI registered | Report "no CI on this PR", continue |
     | 124 | Timed out | Re-run the watcher once; if it times out again, report and stop |
   - GitHub:
     ```bash
     gh pr checks <pr-number> --watch --fail-fast
     ```
     If it reports no checks yet, retry once with another background run, not a sleep loop.
   - Report the PR link and CI result, then STOP. The user merges.

4. Phase 4: Post-Merge Sync — ONLY when the user says the PR is merged, or explicitly asks you to merge it.
   - Get the merge commit from the PR, not from `origin/main`:
     - Gitea: `tea api "/repos/<owner>/<repo>/pulls/<n>" | jq -r .merge_commit_sha`
     - GitHub: `gh pr view <n> --json mergeCommit -q .mergeCommit.oid`
   - Watch it the same way as Phase 3. Exit 3 is normal here.
   - Pull any automated commits: `git switch main && git pull --ff-only origin main`
