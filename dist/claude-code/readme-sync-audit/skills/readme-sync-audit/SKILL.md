---
name: readme-sync-audit
description: Analyzes repository delta since the last documentation update and synchronizes the README.md with the current codebase state.
version: 1.2.0
user-invocable: true
author: Rootiest
---

# README Synchronization & Audit Skill

## **Objective**
To ensure the `README.md` serves as a "Single Source of Truth" by programmatically aligning documentation with the actual state of the codebase. This skill prioritizes accuracy and the removal of obsolete instructions.

## **Execution Protocol**

### **Phase 1: Delta Analysis**
1. **Time-Travel Check**: Locate the last commit where `README.md` was modified.
2. **Feature Diff**: Analyze all code changes (files added, functions modified, dependencies updated) from that commit to the present `HEAD`.
3. **Extraction**: Identify new environment variables, CLI flags, installation steps, or logic changes that are not yet documented.

### **Phase 2: The Pruning & Update Audit**
Perform a line-by-line comparison of the existing README against the current code:
*   **Prune**: Remove any setup steps, dependencies, or "Coming Soon" features that no longer exist or have been replaced.
*   **Correct**: Update version numbers, file paths, and command-line examples to match the current implementation.
*   **Synthesize**: Add concise documentation for new features identified in Phase 1.

### **Phase 3: Structural Integrity Check**
Ensure the updated README includes (or updates) these critical sections:
1. **Quick Start**: Are the commands (e.g., `cargo run`, `npm start`) still the primary entry points?
2. **Configuration**: Are all current `.env` or config keys listed?
3. **Usage Examples**: Do the provided code snippets actually compile/run with the current API?

## **Constraints & Rules**
*   **Minimalism**: Maintain the existing tone of the README. Do not add "fluff" or marketing language unless the original document uses it.
*   **No Hallucinations**: If a feature's purpose is unclear from the code diff, add a `TODO` comment or ask the user for clarification rather than guessing.
*   **Markdown Standards**: Use standard GFM (GitHub Flavored Markdown). Ensure all code blocks have the correct language identifier for syntax highlighting.

## **Trigger Scenarios**
* **Direct Command:** The user invokes `/readme-sync-audit` or `/update-docs`.
* **Natural Language:** User says "Update the docs" or "Sync the README with my recent changes."
* **Contextual Suggestion:** Trigger automatically if the model detects significant changes to public APIs, CLI arguments, or environment variables without a corresponding documentation update.
