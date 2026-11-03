---
name: push-it
description: Branches, commits (Conventional Commits), tests, pushes, and opens a PR for uncommitted or staged work. Handles both independent and stacked PRs.
version: 2.3.0
user-invocable: true
author: Rootiest
---

# /ship-it:push-it

Phase 2 of `/ship-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## push-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## push-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

## **Objective**
To provide a hands-off, end-to-end automation for moving local changes into a formal Pull Request, ensuring code quality through automated and manual verification steps, while intelligently routing Stacked PRs.

## **Execution Protocol**

### **Phase 1: Scope & Base Determination**
Before execution, check the local git state:
1. **Scope Check**: Determine the work boundary:
   * **Case A (Partial):** If staged changes exist, operate **ONLY** on staged changes.
   * **Case B (Full):** If no changes are staged, operate on **ALL** modified/untracked files.
2. **Base Branch Detection**: Identify the currently checked-out branch.
   * **Independent PR**: If the current branch is `main` (or `master`), the new branch will be based on `main`. The PR target will be `main`.
   * **Stacked PR**: If the current branch is a feature branch (e.g., `feat-a`), assume the new changes are dependent. The new branch will be created from the current branch. The PR target will be the current feature branch (NOT `main`).
   * *Safety Check*: If creating a Stacked PR, output a brief terminal message stating: "Detected active feature branch. Stacking new PR on top of `[current-branch-name]`."

### **Phase 2: The "Safe-Commit" Sequence**
1. **Branching**: Generate a `kebab-case` branch name (e.g., `feat-auth-logic` or `fix-header-css`) based off the branch determined in Phase 1.
2. **Naming**: Use **Conventional Commits** for the message (e.g., `feat(ui): add logout button`).
3. **Verification**: 
   * Identify the project type (e.g., Rust/Cargo, Python/Poetry, Node/NPM).
   * Run the primary `test`, `lint`, or `build` command.
   * **Abort Policy**: If verification fails, stop the sequence and report the error. Do not push.

### **Phase 3: Remote Integration**
1. **Push**: Upload the new branch to `origin`.
2. **PR Creation**: Open a Pull Request targeting the base branch determined in Phase 1 (either `main` or the parent feature branch).
3. **Documentation**: Populate the PR description with:
   * **Summary**: A high-level overview of "Why" and "What."
   * **Manual Verification Checklist**: Provide a Markdown list (`- [ ]`) of 3-5 tactical steps for a human to verify the change in a live environment.

## **Constraints & Rules**
* **Atomic Commits**: If multiple distinct features are found in the scope, suggest splitting the work instead of one giant commit.
* **No Force Push**: Never use `--force` unless explicitly requested in the follow-up prompt.
* **Clean State**: Ensure the workflow ends with the user on the new branch, not the original branch.

## **Trigger Scenarios**
* User says: "Make a PR for my current changes" or "push this up".
* Invoked via `/ship-it:push-it`.
* `/ship-it` reaches Phase 2. ("Ship this" means the full `/ship-it` workflow, not this step alone.)
