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
  - [date-time](#date-time)
  - [technical-devlog-scribe](#technical-devlog-scribe)
  - [ship-it](#ship-it)
  - [core-essentials](#core-essentials)
  - [github-mcp](#github-mcp)
  - [gitea-mcp](#gitea-mcp)
  - [caveman](#caveman)
  - [ponytail](#ponytail)
  - [mattpocock-skills](#mattpocock-skills)
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

**Purpose:** Eliminate counting and membership errors caused by the model's
tendency toward holistic pattern recognition.

When invoked, the AI is required to work through three explicit phases:

1. **Set Definition** — enumerate every member of the finite set before any
   analysis begins.
2. **Atomic Element Testing** — test each item individually, producing a
   `[Item] → [Logic] → [Boolean]` record for every element. For
   character-level checks, the string is split into individual characters to
   bypass tokenization bias.
3. **Reduction & Summation** — aggregate results and self-verify that the number
   of items tested exactly matches the set size; if there is a mismatch, Phase 2
   restarts.

**Use when:** counting characters in a string, verifying a property across a
list of files or variables, or any membership test where a false negative
carries real cost.

---

### `date-time`

**Purpose:** Retrieve the exact, real-time current date and time when a task
depends on the present moment.

The skill runs the system `date` command rather than guessing, then uses the
result for time-sensitive reasoning.

**Use when:** the request asks for the current date/time, uses relative
expressions ("today", "next week", "recently"), or needs an age, duration,
countdown, or check of whether an event has already occurred.

---

### `technical-devlog-scribe`

**Purpose:** Produce a dense, objective technical summary of a development
session as a durable historical record optimized for future context loading.

The skill writes a structured Markdown file to
`AGENTS/devlogs/<kebab-case-short-description>.md`, with YAML frontmatter (date,
title, tags, status) followed by the session summary. It relies strictly on
what happened in the session — no hallucinated external constraints — and
avoids conversational filler.

**Use when:** you say "session wrap-up," "write a devlog," "done for the day,"
or want an auditable record of what changed and why.

---

### `ship-it`

**Purpose:** Ship pending work end to end in one command: docs sync and code
audit, PR, CI, merge, syncing `main`, cleaning up branches, and deploying.

`/ship-it` runs each step as its own sub-skill, in order, and stops when a step
fails its gate. Every sub-skill can also be run on its own:

| Phase | Sub-skill | What it does |
|-------|-----------|--------------|
| 1 | `/ship-it:doc-it` | Syncs the docs with the code, then audits the changed code. **Halts the whole workflow** on any breaking issue. |
| 2 | `/ship-it:push-it` | Branches, commits, tests, pushes, and opens the PR. |
| 3 | `/ship-it:verify-it` | Waits for CI on the PR head. |
| 4a | `/ship-it:merge-it` | Merges the PR once you approve, or without asking when the project's rules allow it. Decline and it stops with the PR link. |
| 4b | `/ship-it:sync-it` | After the merge (or once you say you merged it yourself): watches CI on the merge commit and fast-forwards local `main`. |
| 5 | `/ship-it:prune-it` | Right after Phase 4b: deletes the merged branch and any other merged or orphaned branches. |
| 6 | `/ship-it:deploy-it` | Deploys `main` with the project's deploy steps, once you approve or when the project's rules allow it. A project with nothing to deploy just reports that. |

**Use when:** you say "Ship this," "Publish my changes," or invoke `/ship-it`.

#### Project instructions

A project can tell each step how it ships, so the agent doesn't have to work
it out each run. Steps look for the first of these files:

1. `AGENTS_ship-it.md` in the repo root
2. `AGENTS/AGENTS_ship-it.md`
3. `docs/ship-it.md`

Each `##` section is read by the step of the same name (`## push-it`,
`## verify-it`, …), and `## ship-it` holds rules for the whole run. A section
overrides that step's defaults; anything left out keeps them. Commit
`docs/ship-it.md` to share the rules, or use `AGENTS_ship-it.md` to keep them
local; when both exist, `AGENTS_ship-it.md` is used.

You don't have to write it from scratch: after a run that had to work something
out, `/ship-it` offers to save what it learned, and you can ask an agent to
write one for a project. To write or review one yourself, start from
[the template](plugins/ship-it/skills/ship-it/templates/ship-it.md), which
lists every section with what goes in it, or see
[a filled-in example](plugins/ship-it/skills/ship-it/templates/example.md) for
a small web app with staging and production deploys.

#### `doc-it`

Keeps the project's documentation accurate. It first finds the docs root: a
dedicated `docs/`, `wiki/`, or site config (e.g. `mkdocs.yml`) becomes the
Single Source of Truth (SSoT) and gets the detailed updates, with `README.md`
kept as a landing page that links into it. Without one, `README.md` is the
SSoT.

1. **Delta Analysis** — find the last commit that touched the SSoT, diff all
   code changes to `HEAD`, and extract undocumented environment variables, CLI
   flags, or API changes.
2. **Pruning & Update Audit** — route detailed changes to the right files,
   remove stale steps, correct versions and paths, and document new features.
3. **Structural Integrity Check** — verify Quick Start commands, configuration
   keys, and usage examples still match the implementation.
4. **Code Audit** — check the changed code for syntax errors and regressions,
   and stop if anything is breaking.

#### `push-it`

Takes uncommitted local work to an open Pull Request:

1. **Scope** — if staged changes exist, use only those; otherwise all
   modified/untracked files. On `main` the PR targets `main`; on a feature
   branch it stacks a new PR on top of that branch.
2. **Safe-Commit** — create a `kebab-case` branch, write a
   [Conventional Commits](https://www.conventionalcommits.org/) message, and
   run the project's test/lint/build command. If that fails, nothing is pushed.
3. **Remote** — push and open the PR with a "Why/What" summary and a manual
   verification checklist.

#### `verify-it`

Waits on a commit with a single background watcher instead of sleep-polling.
On GitHub it uses `gh pr checks --watch --fail-fast` for a PR head, or
`gh run watch` for a merge commit. On Gitea it runs the bundled
`scripts/tea-ci-watch.sh` (requires `tea` and `jq`), which waits until every
Actions run for the commit — including runs still queued, which Gitea does
not yet report as commit statuses — has completed and the combined commit
status is no longer pending. It fails fast on the first failed or cancelled
check; a commit with no CI is reported, not treated as a failure.

#### `merge-it`

Merges one PR or several, one at a time. Stacked PRs (a PR based on another
open PR's branch) merge bottom-up; independent ones by PR number. Before each
merge it checks the PR is open and mergeable, has no requested changes, and
has green CI (via `verify-it`).

It asks before merging unless you already asked it to merge those PRs, or
the project's `## merge-it` section allows it for this PR, e.g. "merge
without approval if the PR only touches docs." It says which rule matched.

Between merges it waits for the merge commit's CI and any automated commits
the project expects, then retargets stacked children to the new base. After a
squash or rebase merge, the child also has to be rebased and force-pushed
(`--force-with-lease`), which it asks about first unless the project allows it.
It uses the project's merge method, else a merge commit, and leaves branch
deletion to `prune-it`.

#### `sync-it`

Gets the merge commit from the PR (not from `origin/main`), watches its CI with
`verify-it`, then runs `git pull --ff-only` on `main` to pick up any automated
post-merge commits. It never merges or rebases local `main` itself.

#### `prune-it`

**Purpose:** Sweep up after merged work. A bundled bash script does the
work, so it behaves the same in any shell and without the fish config; it
makes the same decisions as the fish config's `git-sweep` function (the
successor to `git-clean`).

It fetches and prunes the remote, fast-forwards the local default branch,
then deletes:

- **Local branches** merged into `origin/<default>`, or whose remote branch
  is gone and whose content is merged.
- **Remote branches** merged into `origin/<default>`, unless they are the
  head of an open PR.

Open PRs are listed with whatever works: `gh`, `tea` or `glab`, else
`curl` with a token from the environment (sent only to the host it belongs
to), else anonymous `curl` for a public repository. GitHub, Gitea/Forgejo
and GitLab are supported, self-hosted included. If nothing works, no remote
branch is deleted; local cleanup never needs any of it.

"Merged" covers merge commits, fast-forwards, rebase merges, and squash
merges; `git branch --merged` alone misses the last two. A branch with
unmerged commits is kept (gone local branches are deleted with `--force`;
unmerged remote branches never are). Also kept: protected names (`main`,
`master`, `develop`, `release/*`, …), `--keep` names, branches checked out
in another worktree, and new branches with no commits yet. It switches off
the current branch before deleting it, and keeps the branch instead if
tracked files have uncommitted changes. The skill always dry-runs and shows
the plan before deleting anything.

**Use when:** you invoke `/ship-it:prune-it` or `git-clean`, or ask to clean
up, prune, or tidy branches. `/ship-it` runs it after a merge.

#### `deploy-it`

Deploys what is on the default branch, after checking local `main` matches
the remote and has no uncommitted changes. The project's `## deploy-it`
section is the source of truth: commands, environments, verification,
rollback, and when no approval is needed (e.g. "staging without asking,
production needs approval").

Without a section it works out the plan from the repo: a CI workflow that
deploys on merge, a `deploy` target or script, or container and hosting
config. A plan it worked out is always shown and approved before anything
runs, and afterwards it offers to save it to `docs/ship-it.md`. When the
deploy happens in CI, it watches that run instead of deploying by hand. If
nothing turns up, it reports "no deploy configured" and `/ship-it` still
succeeds.

After deploying it verifies (health-check URL, service status, or the CI job)
and reports. On failure it stops; it rolls back only if the project says how,
and asks first unless told to roll back automatically.

**Use when:** you invoke `/ship-it:deploy-it` or ask to deploy, release, or
roll out the project. `/ship-it` runs it last, after branch cleanup.

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

### `mattpocock-skills`

**Purpose:** Matt Pocock's agent skills for real engineering — grilling,
spec/ticket flows, TDD, code review, domain modelling and more.

Also third-party, from
[mattpocock/skills](https://github.com/mattpocock/skills), installed the
same external-source way as `caveman`/`ponytail` above. Claude Code-only.

---

## Installation

This repository is a native plugin marketplace for both tools — there is no
install script. Each plugin can be installed individually, or as one bundle
(`rootiest-ai-all`).

### Claude Code

From inside a Claude Code session:

```
/plugin marketplace add rootiest/rootiest-ai
/plugin install ship-it@rootiest-ai
```

Or from a regular shell, before starting a session:

```bash
claude plugin marketplace add rootiest/rootiest-ai
```

The `owner/repo` shorthand resolves against GitHub, so it works because
this repo is mirrored to
[github.com/rootiest/rootiest-ai](https://github.com/rootiest/rootiest-ai)
on every push to our canonical Gitea remote. If you're pointing at a fork
or a private mirror instead, use the full clone URL:
`/plugin marketplace add https://git.rootiest.dev/rootiest/rootiest-ai.git`.

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
├── skills/<skill>/scripts/   # optional: helper scripts, shipped with the skill
├── hooks.json            # optional: lifecycle hooks, Claude-shaped event → matcher groups
├── mcp.json              # optional: {"mcpServers": {...}}
├── rules/AGENTS.md        # optional: agy-only, always-on project rules
├── commands/*.md          # optional: Claude Code-only slash commands
└── agents/*.md            # optional: Claude Code-only subagents
```

Anything else at the plugin root fails validation, since the generator would
not ship it. Each skill directory is copied whole, so a skill reaches its
helper scripts by a path relative to its own `SKILL.md`.

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
