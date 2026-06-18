---
name: ship-it
description: Runs a comprehensive pre-flight audit, syncs the README, and publishes the changes to a new PR.
version: 1.0.0
user-invocable: true
---

# /ship-it

Instructions:
Execute the following two phases sequentially. Do not proceed to Phase 2 unless Phase 1 completes successfully.

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
