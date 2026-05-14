# Rootiest Skills Repository

A collection of reusable AI skills (structured prompt protocols) for **Claude Code** and **Gemini CLI**. Each skill defines a precise execution protocol that guides the AI through complex, multi-step tasks — replacing ad-hoc prompting with consistent, auditable workflows.

Skills are plain Markdown files. The included `install.sh` script handles discovery and installation in a single command.

---

## Table of Contents

- [Skills](#skills)
  - [systematic-enumeration](#systematic-enumeration)
  - [git-publish-workflow](#git-publish-workflow)
  - [readme-sync-audit](#readme-sync-audit)
- [Installation](#installation)
  - [Quick Install (curl)](#quick-install-curl)
  - [Flags & Options](#flags--options)
  - [Environment Variables](#environment-variables)
  - [Examples](#examples)
  - [Manual Install](#manual-install)
- [License](#license)

---

## Skills

### `systematic-enumeration`

**Purpose:** Eliminate counting and membership errors caused by the model's tendency toward holistic pattern recognition.

When invoked, the AI is required to work through three explicit phases:

1. **Set Definition** — enumerate every member of the finite set before any analysis begins.
2. **Atomic Element Testing** — test each item individually, producing a `[Item] → [Logic] → [Boolean]` record for every element. For character-level checks, the string is split into individual characters to bypass tokenization bias.
3. **Reduction & Summation** — aggregate results and self-verify that the number of items tested exactly matches the set size; if there is a mismatch, Phase 2 restarts.

**Use when:** counting characters in a string, verifying a property across a list of files or variables, or any membership test where a false negative carries real cost.

---

### `git-publish-workflow`

**Purpose:** Automate the full lifecycle from uncommitted local work to an open Pull Request, with built-in quality gates.

The workflow runs three phases:

1. **Scope Determination** — if staged changes exist, operate only on those; otherwise operate on all modified/untracked files.
2. **Safe-Commit Sequence** — generate a `kebab-case` branch name, compose a [Conventional Commits](https://www.conventionalcommits.org/) message, then run the project's primary test/lint/build command. If verification fails, the sequence stops — nothing is pushed.
3. **Remote Integration** — push the branch, open a PR against the default branch, and populate the description with a "Why/What" summary and a manual verification checklist (`- [ ]` items).

**Use when:** you say "Ship this," "Make a PR," or invoke `/git-publish-workflow`.

---

### `readme-sync-audit`

**Purpose:** Keep `README.md` accurate by programmatically aligning it with the current state of the codebase.

Three-phase execution:

1. **Delta Analysis** — locate the last commit that touched `README.md`, diff all code changes from that point to `HEAD`, and extract undocumented environment variables, CLI flags, or API changes.
2. **Pruning & Update Audit** — remove stale setup steps or "Coming Soon" notes, correct version numbers and file paths, and synthesize documentation for newly discovered features.
3. **Structural Integrity Check** — verify that Quick Start commands still work, all config keys are listed, and code snippets match the current API.

**Use when:** you say "Update the docs," "Sync the README," or invoke `/readme-sync-audit`.

---

## Installation

### Quick Install (curl)

The intended usage is a single `curl | bash` command. The installer fetches and runs `install.sh` directly — no clone required.

**Install all skills for both Claude Code and Gemini CLI:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --all
```

**Install all skills for Claude Code only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --all --claude
```

**Install all skills for Gemini CLI only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --all --gemini
```

**Install a single skill for both tools:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- systematic-enumeration
```

**Install specific skills for Claude Code only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --claude git-publish-workflow readme-sync-audit
```

**Install specific skills for Gemini CLI only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --gemini systematic-enumeration git-publish-workflow
```

> **Note:** Providing explicit skill names alongside `--all` causes the named skills to take precedence — only those skills are installed.

---

### Flags & Options

| Flag | Description |
|---|---|
| `-c`, `--claude` | Install into Claude Code (`~/.claude/skills/`) |
| `-g`, `--gemini` | Install into Gemini CLI (`~/.gemini/skills/`) |
| `-a`, `--all` | Install every skill available in the repository |
| `SKILL...` | Install one or more named skills (positional arguments) |
| `-h`, `--help` | Show the help page |

**Tool targeting:** if neither `--claude` nor `--gemini` is specified, the installer targets **both** tools by default.

**Skill selection precedence:** explicit skill names always override `--all`. Passing `--all skill-name` installs only `skill-name`, not every skill.

**Dependencies:** `curl` and `git` must be present on `PATH`. The installer checks for both and exits with a clear error if either is missing.

---

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_SKILLS_DIR` | `~/.claude/skills` | Override the Claude Code install directory |
| `GEMINI_SKILLS_DIR` | `~/.gemini/skills` | Override the Gemini CLI install directory |

Example — installing to a project-local skills directory:

```bash
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh \
  | CLAUDE_SKILLS_DIR=./.claude/skills bash -s -- --claude systematic-enumeration
```

---

### Examples

```bash
# Install everything, both tools (simplest possible invocation)
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --all

# Install one skill, Claude only
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --claude git-publish-workflow

# Install two skills, Gemini only
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh | bash -s -- --gemini systematic-enumeration readme-sync-audit

# Override install directory, Claude only
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh \
  | CLAUDE_SKILLS_DIR=~/my-skills bash -s -- --claude --all
```

---

### Manual Install

If you prefer to inspect the script before running it:

```bash
# Download
curl -sL https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main/install.sh -o install.sh

# Review
less install.sh

# Run
bash install.sh --all
```

Or clone the repository and run locally:

```bash
git clone https://git.rootiest.dev/rootiest/ai-skills.git
cd claude-skills
bash install.sh --all
```

---

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**.

See [LICENSE](LICENSE) for the full license text, or visit <https://www.gnu.org/licenses/gpl-3.0.html>.
