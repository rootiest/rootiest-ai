---
name: git-publish-workflow
description: Automates branching, conventional commits, testing, and PR creation for uncommitted or staged work.
version: 1.1.0
user-invocable: true
---

# Git Publish & PR Workflow

## **Objective**
To provide a hands-off, end-to-end automation for moving local changes into a formal Pull Request, ensuring code quality through automated and manual verification steps.

## **Execution Protocol**

### **Phase 1: Scope Determination**
Before execution, check the git index to determine the work boundary:
1. **Case A (Partial):** If staged changes exist, operate **ONLY** on staged changes.
2. **Case B (Full):** If no changes are staged, operate on **ALL** modified/untracked files.

### **Phase 2: The "Safe-Commit" Sequence**
1. **Branching**: Generate a `kebab-case` branch name (e.g., `feat-auth-logic` or `fix-header-css`).
2. **Naming**: Use **Conventional Commits** for the message (e.g., `feat(ui): add logout button`).
3. **Verification**: 
   * Identify the project type (e.g., Rust/Cargo, Python/Poetry, Node/NPM).
   * Run the primary `test`, `lint`, or `build` command.
   * **Abort Policy**: If verification fails, stop the sequence and report the error. Do not push.

### **Phase 3: Remote Integration**
1. **Push**: Upload the branch to `origin`.
2. **PR Creation**: Open a Pull Request targeting the default branch (usually `main` or `master`).
3. **Documentation**: Populate the PR description with:
   * **Summary**: A high-level overview of "Why" and "What."
   * **Manual Verification Checklist**: Provide a Markdown list (`- [ ]`) of 3-5 tactical steps for a human to verify the change in a live environment.

## **Constraints & Rules**
* **Atomic Commits**: If multiple distinct features are found in the scope, suggest splitting the work instead of one giant commit.
* **No Force Push**: Never use `--force` unless explicitly requested in the follow-up prompt.
* **Clean State**: Ensure the workflow ends with the user on the new branch, not the original branch.

## **Trigger Scenarios**
* User says: "Ship this."
* User says: "Make a PR for my current changes."
* Invoked via `/git-publish-workflow`.
