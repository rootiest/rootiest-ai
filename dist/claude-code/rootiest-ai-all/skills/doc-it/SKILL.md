---
name: doc-it
description: Syncs the project's documentation (docs/, wiki, or README) with the code changed since the last docs update, and audits the changed code for errors before it ships.
version: 2.1.0
user-invocable: true
author: Rootiest
---

# /ship-it:doc-it

Phase 1 of `/ship-it`. Also runs on its own.

## Project instructions
Projects can spell out how this step runs for them. Unless `/ship-it` already handed you this
step's section, look for the project's ship-it instructions and use the first file that exists:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Read only the `## doc-it` section. Where it conflicts with the defaults in this skill, the
section wins; anything it leaves out falls back to the defaults. No file, or no `## doc-it`
section, means use the defaults. Say in your report which file and section you used, or that
there were none.

## **Objective**
To ensure project documentation accurately reflects the current state of the codebase by identifying the "Single Source of Truth" (SSoT) (e.g., a `docs/` directory or wiki) and prioritizing updates there. The `README.md` is updated concurrently only for high-level changes or if it serves as the SSoT.

## **Execution Protocol**

### **Phase 0: SSoT Discovery**
1. **Locate Documentation Root**: Scan the repository structure for dedicated documentation directories (e.g., `docs/`, `wiki/`, `website/docs/`) or configuration files (e.g., `mkdocs.yml`, `docusaurus.config.js`).
2. **Establish SSoT**: If a dedicated documentation structure exists, designate it as the SSoT. If absent, fall back to `README.md` as the primary SSoT.

### **Phase 1: Delta Analysis**
1. **Time-Travel Check**: Locate the last commit where the SSoT files were modified.
2. **Feature Diff**: Analyze all code changes (files added, functions modified, dependencies updated) from that commit to the present `HEAD`.
3. **Extraction**: Identify new environment variables, CLI flags, installation steps, or logic changes that are not yet documented.

### **Phase 2: The Pruning & Update Audit**
Perform a targeted comparison of the SSoT against the current code:
* **Route Updates**: Direct detailed API, configuration, and architectural updates to their respective files within the SSoT (`docs/` or wiki).
* **Prune**: Remove any setup steps, dependencies, or "Coming Soon" features from the SSoT that no longer exist or have been replaced.
* **Correct**: Update version numbers, file paths, and command-line examples to match the current implementation.
* **Synthesize**: Add concise documentation for new features identified in Phase 1.
* **README Alignment**: If `docs/` is the SSoT, update the `README.md` *only* to reflect critical, high-level changes (e.g., Quick Start, Installation) or to ensure it properly links to the newly updated sections in the SSoT.

### **Phase 3: Structural Integrity Check**
Ensure the updated SSoT (and README, if applicable) includes or updates these critical sections:
1. **Quick Start**: Are the commands (e.g., `cargo run`, `npm start`) still the primary entry points?
2. **Configuration**: Are all current `.env` or config keys listed?
3. **Usage Examples**: Do the provided code snippets actually compile/run with the current API?

### **Phase 4: Code Audit**
1. Audit the code files changed in the Phase 1 delta, plus any uncommitted changes, for syntax errors, regressions, and other breaking issues.
2. **Halt on errors**: if anything breaking is found, stop and report it. When running under `/ship-it`, this stops the whole workflow before anything is published.

## **Constraints & Rules**
* **Hierarchy Enforcement**: Never duplicate deep technical documentation in the README if a `docs/` folder exists. Use the README as a high-level landing page that points to the SSoT.
* **Minimalism**: Maintain the existing tone of the documentation. Do not add "fluff" or marketing language unless the original document uses it.
* **No Hallucinations**: If a feature's purpose is unclear from the code diff, add a `TODO` comment or ask the user for clarification rather than guessing.
* **Markdown Standards**: Use standard GFM (GitHub Flavored Markdown) or MDX if applicable to the SSoT. Ensure all code blocks have the correct language identifier for syntax highlighting.

## **Trigger Scenarios**
* **Direct Command:** The user invokes `/ship-it:doc-it` or `/update-docs`.
* **Workflow:** `/ship-it` reaches Phase 1.
* **Natural Language:** User says "Update the docs", "Sync the wiki", or "Sync the README with my recent changes."
* **Contextual Suggestion:** Trigger automatically if the model detects significant changes to public APIs, CLI arguments, or environment variables without a corresponding documentation update.
