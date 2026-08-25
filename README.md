# Rootiest AI Repository

A shareable extension library for **Claude Code** and **Antigravity CLI**
(`agy`). The unit of distribution is a **plugin** — a bundle that can carry
any mix of skills (structured prompt protocols), MCP servers, lifecycle
hooks, and tool-specific extras (slash commands, subagents, rules) — built
from one source tree and published as a native marketplace for both tools.

---

## Table of Contents

- [Plugins](#plugins)
  - [systematic-enumeration](#systematic-enumeration)
  - [git-publish-workflow](#git-publish-workflow)
  - [readme-sync-audit](#readme-sync-audit)
  - [docs-sync-audit](#docs-sync-audit)
  - [date-time](#date-time)
  - [technical-devlog-scribe](#technical-devlog-scribe)
  - [ship-it](#ship-it)
  - [core-essentials](#core-essentials)
  - [github-mcp](#github-mcp)
  - [gitea-mcp](#gitea-mcp)
  - [caveman](#caveman)
  - [ponytail](#ponytail)
- [Installation](#installation)
  - [Claude Code](#claude-code)
  - [Antigravity CLI (agy)](#antigravity-cli-agy)
- [Repository Structure](#repository-structure)
  - [Anatomy of a Plugin](#anatomy-of-a-plugin)
  - [Restricting a Plugin (or a Skill) to Specific Targets](#restricting-a-plugin-or-a-skill-to-specific-targets)
  - [How Generation Works](#how-generation-works)
- [Private Overlay Builds](#private-overlay-builds)
- [License](#license)

---

## Plugins

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

### `core-essentials`

**Purpose:** Cross-tool utilities that don't belong to a single workflow.

Currently bundles `delegate-agy`, which hands a subtask off to the
Antigravity CLI (`agy`) in headless mode — useful for a second opinion,
external grounded research, or a large multi-file audit (>500 lines) that
would otherwise bloat the current context. Only makes sense run *from*
Claude Code, so its `SKILL.md` declares `targets: [claude-code]` — this
plugin has no agy output at all.

---

### `github-mcp`

**Purpose:** Connect Claude Code/agy to GitHub via the official
`@modelcontextprotocol/server-github`, authenticated with a
`GITHUB_PERSONAL_ACCESS_TOKEN` you set locally — never stored in the repo.

---

### `gitea-mcp`

**Purpose:** Connect Claude Code/agy to a Gitea instance via the official
`gitea-mcp` server, authenticated with `GITEA_HOST`/`GITEA_ACCESS_TOKEN`
you set locally.

Split from `github-mcp` into its own plugin so you can install either,
both, or neither independently.

---

### `caveman`

**Purpose:** Ultra-compressed communication mode — cuts output tokens while
keeping full technical accuracy.

This is a third-party plugin from
[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman), not
maintained in this repo. Our marketplace entry points straight at that
repo's own `.claude-plugin/plugin.json` (via `source: {"source": "github",
"repo": "JuliusBrussee/caveman"}`), so installing it through us always
fetches the current upstream version — nothing is vendored or copied.
Claude Code-only; see [Antigravity CLI (agy)](#antigravity-cli-agy) below
for why.

---

### `ponytail`

**Purpose:** Lazy senior dev mode — forces the simplest, shortest solution
that actually works (YAGNI, stdlib first, no unrequested abstractions).

Also third-party, from
[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail),
installed the same external-source way as `caveman` above. Claude Code-only.

---

## Installation

This repository is a native plugin marketplace for both tools — there is no
install script. Each plugin can be installed individually, or as one bundle
(`rootiest-ai-all`).

### Claude Code

```
/plugin marketplace add https://git.rootiest.dev/rootiest/rootiest-ai.git
/plugin install git-publish-workflow@rootiest-ai
```

Install everything at once:

```
/plugin install rootiest-ai-all@rootiest-ai
```

Run `/plugin marketplace update` to pick up newly published plugins.

### Antigravity CLI (`agy`)

Third-party plugins pulled in via `external` (see below) aren't offered
here at all — agy has no marketplace-style external-source mechanism, and
their hooks/MCP servers are built assuming Claude Code's plugin runtime
(e.g. resolving `${CLAUDE_PLUGIN_ROOT}`), so there'd be nothing correct to
translate even if we vendored them.

agy documents a `plugins.json` "entries" mechanism for pointing it at an
external directory of plugins, but empirically it doesn't reliably load
one as a bundle — hooks and MCP servers inside a `plugins/<name>/` folder
are never picked up that way, only a stray skill occasionally surfaces via
agy's generic skill-walk. What does reliably work is placing things
directly where agy actually looks: `~/.gemini/config/skills/<name>/`,
`~/.gemini/config/mcp_config.json`, `~/.gemini/config/hooks.json`.
`scripts/install_agy.py` does exactly that from a generated `dist/agy`:

```bash
git clone https://git.rootiest.dev/rootiest/rootiest-ai.git ~/rootiest-ai
cd ~/rootiest-ai
python3 scripts/generate_plugins.py          # produces dist/agy/**
python3 scripts/install_agy.py --all         # symlinks skills, merges MCP/hooks into ~/.gemini/config
```

It symlinks each skill (so `git pull` + re-running the script — or just
`git pull` alone, since skills are live symlinks — keeps them current) and
merges each plugin's `mcpServers`/hooks into the shared global config
files without touching unrelated entries already there. Install specific
plugins by name instead of `--all`, add `--project` to target a project's
`.agents/` instead of the global config, or `--uninstall` to cleanly
remove exactly what was added.

---

## Repository Structure

### Anatomy of a Plugin

Every plugin lives under `plugins/<name>/` and is the single source of
truth for that name — nothing under `plugins/` is ever written by the
generator. A plugin can bundle any subset of:

```
plugins/<name>/
├── plugin.json          # required: name, description, version, author
├── skills/<skill>/SKILL.md   # 0+ skills (YAML frontmatter: name, description, version, author)
├── hooks.json            # optional: lifecycle hooks, Claude-shaped event → matcher groups
├── mcp.json              # optional: {"mcpServers": {...}}
├── rules/AGENTS.md        # optional: agy-only, always-on project rules
├── commands/*.md          # optional: Claude Code-only slash commands
└── agents/*.md            # optional: Claude Code-only subagents
```

`hooks.json` and `mcp.json` are translated per target rather than copied
verbatim where the two tools' schemas diverge:

- MCP: the shared `mcpServers` shape passes straight through to Claude's
  `.mcp.json`; a `url`/`serverUrl` remote entry becomes agy's
  `serverUrl` field in `mcp_config.json`.
- Hooks: Claude Code has far more event types than agy documents. Events
  agy doesn't support (`SessionStart`, `TaskCreated`, etc.) simply stay
  Claude-only — the agy output only carries `PreToolUse`/`PostToolUse`
  (kept grouped with their `matcher`) and `PreInvocation`/`PostInvocation`/
  `Stop` (flattened to agy's handler-list shape, since agy doesn't group
  those by matcher).
- `rules/` has no Claude Code plugin equivalent and is skipped for that
  target; `commands/`/`agents/` have no agy equivalent and are skipped for
  that target.

A plugin can instead declare `external` in its `plugin.json` — a
target-keyed map of Claude Code marketplace `source` objects — to point at
a third-party plugin we don't own or vendor, instead of carrying any of
the local content above:

```json
{
  "name": "caveman",
  "description": "...",
  "targets": ["claude-code"],
  "external": {
    "claude-code": { "source": "github", "repo": "owner/repo" }
  }
}
```

The generator emits that `source` object verbatim into
`.claude-plugin/marketplace.json` instead of a local `./dist/...` path, so
`/plugin install` fetches the plugin's real content straight from upstream
at install time — it's never copied into this repo and never goes stale.
A plugin with `external` must not also carry local skills/hooks/mcp/rules/
commands/agents, and today only the `claude-code` target supports it (see
[caveman](#caveman) and [ponytail](#ponytail) above).

### Restricting a Plugin (or a Skill) to Specific Targets

Some content only makes sense for one tool — `delegate-agy` (Claude Code
shelling out to `agy`) has no reason to exist *inside* agy, for instance.
Declare a `targets` list wherever it's needed:

- In `plugin.json`, `"targets": ["claude-code"]` restricts the **whole
  plugin** — including any hooks/mcp/rules/commands/agents it bundles —
  to just the listed targets.
- In a skill's own `SKILL.md` frontmatter, `targets: [claude-code]`
  restricts **just that skill**, independent of its sibling skills in the
  same plugin. A skill's targets are narrowed to, never wider than, its
  plugin's own targets.

Omitting `targets` (the default everywhere) means "every target in
`manifest.yaml`" — today's behavior for every existing plugin. A plugin
left with no content at all for a given target (every skill excluded, and
nothing of its own) is skipped entirely for that target — no empty output
directory, no marketplace entry.

### How Generation Works

`scripts/generate_plugins.py` reads `manifest.yaml` (marketplace metadata,
bundle id, target list) and every `plugins/<name>/`, then regenerates:

| Path | Generated for |
|---|---|
| `.claude-plugin/marketplace.json` | Claude Code plugin marketplace |
| `dist/claude-code/**` | Claude Code plugin directories (linked from the marketplace) |
| `dist/agy/**` | Antigravity CLI (`agy`) plugin directories — an intermediate; run `scripts/install_agy.py` to actually get them into agy |

CI (`.github/workflows/plugins.yml`) runs the generator on every push to
`main` that touches `plugins/`, `manifest.yaml`, or the generator itself,
and commits the regenerated output; it can also be re-run on demand from
the Actions tab (`workflow_dispatch`). Pull requests run the same generator
in `--check` mode to catch missing/invalid `plugin.json`/`SKILL.md`
frontmatter before merge.

Don't hand-edit anything under `.claude-plugin/` or `dist/` — edit the
source plugin or `manifest.yaml` and let the generator regenerate them.

---

## Private Overlay Builds

The generator supports layering an additional, non-public source of
plugins on top of this repo — for keeping PII, tokens, API keys, or
personal-only plugins out of a public repo's git history entirely, while
still reusing the same plugin format and generator.

```bash
# Layer a second, already-cloned repo on top of this one
python3 scripts/generate_plugins.py --source . --source ~/rootiest-ai-private

# Or have the generator clone it (token read from an env var, never a CLI argument)
export PRIVATE_TOKEN=...
python3 scripts/generate_plugins.py \
  --private-repo https://git.example.com/you/rootiest-ai-private.git \
  --private-ref main \
  --private-token-env PRIVATE_TOKEN
```

A later `--source` overlays the earlier ones per plugin: a plugin name that
only exists in the private source is added; a plugin name that exists in
both is merged file-by-file, with the private copy winning on conflicts
(e.g. supplying a real `mcp.json` where the public plugin ships a
placeholder).

Output never lands in this repo's tracked paths for an overlaid build —
`--out` defaults to `dist-private/` (gitignored) whenever more than one
source is in play. Add `--install-local` to also drop the result straight
into `~/.claude/plugins/marketplaces/<name>-private/` and print the
`~/.gemini/config/plugins.json` entry for agy, so a personal build is
usable immediately without committing anything anywhere.

---

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**.

See [LICENSE](LICENSE) for the full license text, or visit <https://www.gnu.org/licenses/gpl-3.0.html>.
