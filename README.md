# Rootiest Skills Repository

A collection of reusable AI skills (structured prompt protocols) for **Claude Code** and **Antigravity CLI**. Each skill defines a precise execution protocol that guides the AI through complex, multi-step tasks — replacing ad-hoc prompting with consistent, auditable workflows.

Skills are plain Markdown files. The included `install.sh` script handles discovery and installation in a single command.

---

## Table of Contents

- [Skills](#skills)
  - [systematic-enumeration](#systematic-enumeration)
  - [git-publish-workflow](#git-publish-workflow)
  - [readme-sync-audit](#readme-sync-audit)
  - [docs-sync-audit](#docs-sync-audit)
  - [date-time](#date-time)
  - [technical-devlog-scribe](#technical-devlog-scribe)
  - [ship-it](#ship-it)
- [Installation](#installation)
  - [Claude Code Plugin Marketplace](#claude-code-plugin-marketplace)
  - [Quick Install (curl)](#quick-install-curl)
  - [Flags & Options](#flags--options)
  - [Environment Variables](#environment-variables)
  - [Examples](#examples)
  - [Manual Install](#manual-install)
- [Repository Structure](#repository-structure)
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

### `docs-sync-audit`

**Purpose:** Keep documentation accurate by aligning the project's Single Source of Truth (SSoT) with the current state of the codebase.

Unlike `readme-sync-audit`, this skill first discovers the documentation root. If a dedicated `docs/`, `wiki/`, or site config (e.g. `mkdocs.yml`) exists, it is treated as the SSoT and receives the detailed updates; the `README.md` is then kept as a high-level landing page that links into it. If no docs directory exists, it falls back to `README.md` as the SSoT.

Three-phase execution:

1. **Delta Analysis** — locate the last commit that touched the SSoT, diff all code changes to `HEAD`, and extract undocumented environment variables, CLI flags, or API changes.
2. **Pruning & Update Audit** — route detailed changes to the correct files, remove stale steps, correct versions and paths, and synthesize docs for new features.
3. **Structural Integrity Check** — verify Quick Start commands, configuration keys, and usage examples still match the implementation.

**Use when:** you say "Update the docs," "Sync the wiki," or invoke `/docs-sync-audit`.

---

### `date-time`

**Purpose:** Retrieve the exact, real-time current date and time when a task depends on the present moment.

The skill runs the system `date` command rather than guessing, then uses the result for time-sensitive reasoning.

**Use when:** the request asks for the current date/time, uses relative expressions ("today", "next week", "recently"), or needs an age, duration, countdown, or check of whether an event has already occurred.

---

### `technical-devlog-scribe`

**Purpose:** Produce a dense, objective technical summary of a development session as a durable historical record optimized for future context loading.

The skill writes a structured Markdown file to `AGENTS/devlogs/<kebab-case-short-description>.md`, with YAML frontmatter (date, title, tags, status) followed by the session summary. It relies strictly on what happened in the session — no hallucinated external constraints — and avoids conversational filler.

**Use when:** you say "session wrap-up," "write a devlog," "done for the day," or want an auditable record of what changed and why.

---

### `ship-it`

**Purpose:** Run a comprehensive pre-flight audit and publish changes to a new PR in a single command.

Two sequential phases — Phase 2 is blocked until Phase 1 succeeds:

1. **Documentation Sync & Code Audit** — acts as `/docs-sync-audit`: scans all file changes since the last documentation edit, updates the docs/README to match the current codebase, and audits code files for syntax errors or regressions. **Halts the entire workflow** if any breaking issue is found.
2. **Git Publish Workflow** — acts as `/git-publish-workflow`: creates a descriptively named branch, commits all pending changes (including the README updates from Phase 1), pushes to the remote, and opens a Pull Request against `main`.

**Use when:** you say "Ship this," "Publish my changes," or invoke `/ship-it`.

---

## Installation

### Claude Code Plugin Marketplace

This repository is a Claude Code plugin marketplace. Each skill is installable
individually, or install everything as one bundle. This is the preferred
install path for Claude Code — `install.sh` remains available as a
cross-tool fallback (and is the only supported path for Antigravity CLI today).

```
/plugin marketplace add https://git.rootiest.dev/rootiest/rootiest-ai.git
/plugin install git-publish-workflow@rootiest-skills
```

Install every skill at once with the `rootiest-skills-all` bundle:

```
/plugin install rootiest-skills-all@rootiest-skills
```

Run `/plugin marketplace update` to pick up newly published skills.

### Quick Install (curl)

The intended usage is a single `curl | bash` command. The installer fetches and runs `install.sh` directly — no clone required.

> [!TIP]
> The short-url `https://url.rootiest.dev/skills` can be substituted for the full URL in the examples below.  
> e.g. `curl -sL https://url.rootiest.dev/skills | bash -s -- --all`

**Install all skills for both Claude Code and Antigravity CLI:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --all
```

**Install all skills for Claude Code only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --all --claude
```

**Install all skills for Antigravity CLI only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --all --antigravity
```

**Install a single skill for both tools:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- systematic-enumeration
```

**Install specific skills for Claude Code only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --claude git-publish-workflow readme-sync-audit
```

**Install specific skills for Antigravity CLI only:**

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --antigravity systematic-enumeration git-publish-workflow
```

> **Note:** Providing explicit skill names alongside `--all` causes the named skills to take precedence — only those skills are installed.

---

### Flags & Options

| Flag | Description |
|---|---|
| `-c`, `--claude` | Install into Claude Code (`~/.claude/skills/`) |
| `-g`, `--antigravity` | Install into Antigravity CLI (`~/.gemini/antigravity-cli/skills/`) |
| `-a`, `--all` | Install every skill available in the repository |
| `SKILL...` | Install one or more named skills (positional arguments) |
| `-l`, `--list` | List all available skills with descriptions and exit |
| `-h`, `--help` | Show the help page |

**Tool targeting:** if neither `--claude` nor `--antigravity` is specified, the installer targets **both** tools by default.

**Skill selection precedence:** explicit skill names always override `--all`. Passing `--all skill-name` installs only `skill-name`, not every skill.

**Dependencies:** `curl` and `git` must be present on `PATH`. The installer checks for both and exits with a clear error if either is missing.

---

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_SKILLS_DIR` | `~/.claude/skills` | Override the Claude Code install directory |
| `ANTIGRAVITY_SKILLS_DIR` | `~/.gemini/antigravity-cli/skills` | Override the Antigravity CLI install directory. Falls back to `GEMINI_SKILLS_DIR` if set (legacy support). |

Example — installing to a project-local skills directory:

```bash
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh \
  | CLAUDE_SKILLS_DIR=./.claude/skills bash -s -- --claude systematic-enumeration
```

---

### Examples

```bash
# Install everything, both tools (simplest possible invocation)
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --all

# Install one skill, Claude only
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --claude git-publish-workflow

# Install two skills, Antigravity only
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh | bash -s -- --antigravity systematic-enumeration readme-sync-audit

# Override install directory, Claude only
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh \
  | CLAUDE_SKILLS_DIR=~/my-skills bash -s -- --claude --all
```

---

### Manual Install

If you prefer to inspect the script before running it:

```bash
# Download
curl -sL https://git.rootiest.dev/rootiest/rootiest-ai/raw/branch/main/install.sh -o install.sh

# Review
less install.sh

# Run
bash install.sh --all
```

Or clone the repository and run locally:

```bash
git clone https://git.rootiest.dev/rootiest/rootiest-ai.git
cd rootiest-ai
bash install.sh --all
```

---

## Repository Structure

Skill content lives entirely in `skills/<name>/SKILL.md` — that's the single
source of truth for a skill's metadata (YAML frontmatter: `name`,
`description`, `version`, `author`, `user-invocable`) and instructions.
`manifest.yaml` holds only marketplace-level metadata (owner, marketplace
name, which agent targets to generate for) — it does not list skills
individually; adding a new `skills/<name>/` folder is picked up automatically.

CI (`.gitea/workflows/plugins.yml`) runs `scripts/generate_plugins.py` on
every push to `main` that touches `skills/`, `manifest.yaml`, or the
generator itself, and commits the regenerated output:

| Path | Generated for |
|---|---|
| `.claude-plugin/marketplace.json` | Claude Code plugin marketplace |
| `dist/agy/**` | Antigravity CLI (`agy`) plugins |
| `descriptions.json` | `install.sh` skill listing |

Don't hand-edit any of the paths above — edit the source skill or
`manifest.yaml` and let CI regenerate them. Pull requests run the same
generator in `--check` mode to catch missing/invalid frontmatter before merge.

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**.

See [LICENSE](LICENSE) for the full license text, or visit <https://www.gnu.org/licenses/gpl-3.0.html>.
