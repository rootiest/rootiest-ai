---
name: ship-it
description: Runs a comprehensive pre-flight audit, syncs the README, and publishes the changes to a new PR.
version: 1.1.0
user-invocable: true
author: Rootiest
---

# /ship-it

Instructions:
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

3. Phase 3: Post-Publish Attribution Scrub
   - Only run this phase if a global, user, or project rule (e.g. `CLAUDE.md`, memory) explicitly
     forbids AI attribution footers/text (e.g. "no Co-Authored-By", "no Claude attribution") on
     commits or PRs. Skip this phase entirely if no such rule exists.
   - Run this check AFTER the commit and PR from Phase 2 already exist, not before — attribution
     lines can be injected by a hook outside the visible conversation, so text you composed
     yourself is not proof of what actually landed. Verify the real, persisted state:
     - Inspect the actual commit message(s) just created (`git log -1 --format=%B` for each
       commit pushed) for attribution lines (e.g. `Co-Authored-By: Claude...`, "Generated with
       Claude Code", or similar).
     - Inspect the actual PR description as stored on the remote (e.g. `gh pr view --json body`),
       not the text you intended to send.
   - If any attribution text is found in violation of the rule, remove it:
     - Commit message: amend it (`git commit --amend`) to strip the offending lines, then
       force-push the branch (`git push --force-with-lease`) since it was just created for this
       PR and nothing else depends on it yet.
     - PR description: edit it directly (`gh pr edit --body ...`) with the offending lines
       removed.
   - Report to the user whether attribution was found and stripped, or that none was found.
