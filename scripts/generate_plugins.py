#!/usr/bin/env python3
"""Generate per-agent plugin/marketplace trees from the plugins/ SSoT.

A "plugin" is a directory under `plugins/<name>/` that may bundle any mix of:

  - plugin.json        (required marker + metadata: name, description, version, author)
  - skills/<name>/SKILL.md   (0+ skills)
  - hooks.json          (canonical, Claude-shaped: {"<EventName>": [<matcher-group>, ...]})
  - mcp.json            ({"mcpServers": {...}}, shared shape across targets)
  - rules/AGENTS.md     (agy-only; ignored by the Claude Code target)
  - commands/*.md       (Claude Code-only slash commands)
  - agents/*.md         (Claude Code-only subagents)

One or more source roots (each containing its own `plugins/` directory) are
layered together — a later source overlays/overrides an earlier one on a
per-plugin, per-file basis. This is how a private repo (PII/tokens/local-only
plugins) can extend or override the public plugin set without either repo
knowing about the other's internals.

Regenerates, under --out (default: repo root, i.e. today's committed paths):

  - .claude-plugin/marketplace.json      (Claude Code target)
  - dist/agy/**                          (Antigravity CLI target)

Run with --check to only validate the SSoT (plugin.json/SKILL.md frontmatter,
manifest.yaml) and skip writing any output — used as the pull-request gate.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = ROOT / "manifest.yaml"

REQUIRED_PLUGIN_FIELDS = ("name", "description")
REQUIRED_SKILL_FIELDS = ("name", "description")

# agy only documents these five hook events; everything else is Claude-only.
AGY_GROUPED_EVENTS = ("PreToolUse", "PostToolUse")
AGY_FLAT_EVENTS = ("PreInvocation", "PostInvocation", "Stop")


class ValidationError(Exception):
    pass


# ── Manifest / Frontmatter Loading ───────────────────────────────────────────


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as f:
        manifest = yaml.safe_load(f)
    for key in ("marketplace", "bundle", "targets"):
        if key not in manifest:
            raise ValidationError(f"manifest.yaml is missing required key '{key}'")
    return manifest


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ValidationError(f"{path}: invalid JSON ({e})")


def parse_skill_frontmatter(skill_md: Path) -> dict:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValidationError(f"{skill_md}: missing YAML frontmatter delimiter")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValidationError(f"{skill_md}: unterminated YAML frontmatter")
    data = yaml.safe_load(text[4:end]) or {}
    for field in REQUIRED_SKILL_FIELDS:
        if not data.get(field):
            raise ValidationError(f"{skill_md}: frontmatter missing required field '{field}'")
    return data


# ── Source Discovery & Layering ──────────────────────────────────────────────


def collect_layers(source_roots: list[Path]) -> "dict[str, list[Path]]":
    """Map plugin name -> ordered list of source dirs (base first, overlays after)."""
    layers: dict[str, list[Path]] = {}
    for root in source_roots:
        plugins_dir = root / "plugins"
        if not plugins_dir.is_dir():
            continue
        for plugin_dir in sorted(plugins_dir.iterdir()):
            if not plugin_dir.is_dir():
                continue
            layers.setdefault(plugin_dir.name, []).append(plugin_dir)
    if not layers:
        raise ValidationError(
            f"no plugins found under plugins/ in any source root: {[str(r) for r in source_roots]}"
        )
    return layers


def merge_layers(layers: "dict[str, list[Path]]", workdir: Path) -> Path:
    """Flatten each plugin's layers into a single merged directory (later wins)."""
    merged_root = workdir / "merged-plugins"
    merged_root.mkdir(parents=True, exist_ok=True)
    for name, dirs in layers.items():
        dest = merged_root / name
        dest.mkdir(parents=True, exist_ok=True)
        for d in dirs:
            shutil.copytree(d, dest, dirs_exist_ok=True)
    return merged_root


def discover_plugins(merged_root: Path) -> list[dict]:
    plugins = []
    for plugin_dir in sorted(merged_root.iterdir()):
        if not plugin_dir.is_dir():
            continue
        manifest_path = plugin_dir / "plugin.json"
        if not manifest_path.exists():
            raise ValidationError(f"{plugin_dir}: missing plugin.json")
        meta = load_json(manifest_path)
        if meta.get("name") != plugin_dir.name:
            raise ValidationError(
                f"{manifest_path}: name '{meta.get('name')}' does not match directory name '{plugin_dir.name}'"
            )
        for field in REQUIRED_PLUGIN_FIELDS:
            if not meta.get(field):
                raise ValidationError(f"{manifest_path}: missing required field '{field}'")

        skills = []
        skills_dir = plugin_dir / "skills"
        if skills_dir.is_dir():
            for skill_dir in sorted(skills_dir.iterdir()):
                if not skill_dir.is_dir():
                    continue
                skill_md = skill_dir / "SKILL.md"
                if not skill_md.exists():
                    raise ValidationError(f"{skill_dir}: missing SKILL.md")
                fm = parse_skill_frontmatter(skill_md)
                if fm["name"] != skill_dir.name:
                    raise ValidationError(
                        f"{skill_md}: frontmatter name '{fm['name']}' does not match directory name '{skill_dir.name}'"
                    )
                skills.append({"dir": skill_dir, "frontmatter": fm})

        hooks_path = plugin_dir / "hooks.json"
        hooks = load_json(hooks_path) if hooks_path.exists() else None

        mcp_path = plugin_dir / "mcp.json"
        mcp = load_json(mcp_path) if mcp_path.exists() else None

        plugins.append(
            {
                "dir": plugin_dir,
                "meta": meta,
                "skills": skills,
                "hooks": hooks,
                "mcp": mcp,
                "rules_dir": plugin_dir / "rules" if (plugin_dir / "rules").is_dir() else None,
                "commands_dir": plugin_dir / "commands" if (plugin_dir / "commands").is_dir() else None,
                "agents_dir": plugin_dir / "agents" if (plugin_dir / "agents").is_dir() else None,
            }
        )

    seen = set()
    for p in plugins:
        name = p["meta"]["name"]
        if name in seen:
            raise ValidationError(f"duplicate plugin name '{name}'")
        seen.add(name)
    return plugins


# ── Private Repo Cloning ─────────────────────────────────────────────────────

_ASKPASS_SCRIPT = """#!/bin/sh
case "$1" in
  *sername*) echo "x-access-token" ;;
  *) echo "$GIT_ASKPASS_TOKEN" ;;
esac
"""


def clone_private_repo(url: str, ref: str, token_env: str | None, workdir: Path) -> Path:
    clone_dir = workdir / "private-repo"
    env = os.environ.copy()
    env["GIT_TERMINAL_PROMPT"] = "0"

    if token_env:
        token = os.environ.get(token_env)
        if not token:
            raise ValidationError(f"--private-token-env={token_env} is not set in the environment")
        askpass_path = workdir / "git-askpass.sh"
        askpass_path.write_text(_ASKPASS_SCRIPT, encoding="utf-8")
        askpass_path.chmod(askpass_path.stat().st_mode | stat.S_IEXEC)
        env["GIT_ASKPASS"] = str(askpass_path)
        env["GIT_ASKPASS_TOKEN"] = token

    result = subprocess.run(
        ["git", "clone", "--quiet", "--depth", "1", "--branch", ref, url, str(clone_dir)],
        env=env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ValidationError(f"failed to clone private repo '{url}' (ref {ref}): {result.stderr.strip()}")
    return clone_dir


# ── Hook / MCP Translation ───────────────────────────────────────────────────


def translate_hooks_for_agy(hooks: dict, plugin_name: str) -> "dict | None":
    agy_events: dict = {}
    for event in AGY_GROUPED_EVENTS:
        if event in hooks:
            agy_events[event] = hooks[event]
    for event in AGY_FLAT_EVENTS:
        if event in hooks:
            flat = []
            for group in hooks[event]:
                flat.extend(group.get("hooks", []))
            agy_events[event] = flat
    if not agy_events:
        return None
    return {plugin_name: agy_events}


def translate_mcp_for_agy(mcp: dict) -> dict:
    servers = {}
    for name, cfg in mcp.get("mcpServers", {}).items():
        if "command" in cfg:
            out = {"command": cfg["command"]}
            if "args" in cfg:
                out["args"] = cfg["args"]
            if "env" in cfg:
                out["env"] = cfg["env"]
            servers[name] = out
        else:
            url = cfg.get("serverUrl") or cfg.get("url")
            if url:
                servers[name] = {"serverUrl": url}
    return {"mcpServers": servers}


# ── Claude Code Target ───────────────────────────────────────────────────────


def write_claude_plugin(plugin: dict, dest: Path) -> None:
    meta = plugin["meta"]
    dest.mkdir(parents=True, exist_ok=True)

    claude_plugin_dir = dest / ".claude-plugin"
    claude_plugin_dir.mkdir(exist_ok=True)
    manifest = {"name": meta["name"]}
    for field in ("description", "version", "author"):
        if meta.get(field):
            manifest[field] = meta[field]
    (claude_plugin_dir / "plugin.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    if plugin["skills"]:
        skills_out = dest / "skills"
        for s in plugin["skills"]:
            shutil.copytree(s["dir"], skills_out / s["frontmatter"]["name"])

    for optional_dir in ("commands_dir", "agents_dir"):
        src = plugin[optional_dir]
        if src is not None:
            shutil.copytree(src, dest / src.name)

    if plugin["hooks"] is not None:
        hooks_out = dest / "hooks"
        hooks_out.mkdir(exist_ok=True)
        (hooks_out / "hooks.json").write_text(
            json.dumps({"hooks": plugin["hooks"]}, indent=2) + "\n", encoding="utf-8"
        )

    if plugin["mcp"] is not None:
        (dest / ".mcp.json").write_text(json.dumps(plugin["mcp"], indent=2) + "\n", encoding="utf-8")


def gen_claude_code(manifest: dict, plugins: list[dict], out_dir: Path) -> None:
    # Generated output lives under dist/claude-code/ — never inside plugins/,
    # which is the SSoT and must stay untouched by generation.
    plugins_out = out_dir / "dist" / "claude-code"
    if plugins_out.exists():
        shutil.rmtree(plugins_out)
    plugins_out.mkdir(parents=True)

    marketplace_entries = []
    for p in plugins:
        name = p["meta"]["name"]
        write_claude_plugin(p, plugins_out / name)
        marketplace_entries.append({"name": name, "source": f"./dist/claude-code/{name}"})

    bundle_id = manifest["bundle"]["id"]
    bundle_dest = plugins_out / bundle_id
    (bundle_dest / ".claude-plugin").mkdir(parents=True)
    (bundle_dest / ".claude-plugin" / "plugin.json").write_text(
        json.dumps(
            {"name": bundle_id, "description": f"{manifest['marketplace']['description']} (all skills)"},
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    bundle_skills = bundle_dest / "skills"
    for p in plugins:
        for s in p["skills"]:
            shutil.copytree(s["dir"], bundle_skills / s["frontmatter"]["name"])
    marketplace_entries.append({"name": bundle_id, "source": f"./dist/claude-code/{bundle_id}"})

    marketplace = {
        "name": manifest["marketplace"]["name"],
        "owner": manifest["marketplace"]["owner"],
        "description": manifest["marketplace"]["description"],
        "plugins": marketplace_entries,
    }
    plugin_dir = out_dir / ".claude-plugin"
    plugin_dir.mkdir(exist_ok=True)
    (plugin_dir / "marketplace.json").write_text(json.dumps(marketplace, indent=2) + "\n", encoding="utf-8")


# ── Antigravity CLI (agy) Target ─────────────────────────────────────────────


def write_agy_plugin(plugin: dict, dest: Path) -> None:
    meta = plugin["meta"]
    name = meta["name"]
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "plugin.json").write_text(json.dumps({"name": name}, indent=2) + "\n", encoding="utf-8")

    if plugin["skills"]:
        skills_out = dest / "skills"
        for s in plugin["skills"]:
            shutil.copytree(s["dir"], skills_out / s["frontmatter"]["name"])

    if plugin["rules_dir"] is not None:
        shutil.copytree(plugin["rules_dir"], dest / "rules")

    if plugin["hooks"] is not None:
        translated = translate_hooks_for_agy(plugin["hooks"], name)
        if translated is not None:
            (dest / "hooks.json").write_text(json.dumps(translated, indent=2) + "\n", encoding="utf-8")

    if plugin["mcp"] is not None:
        (dest / "mcp_config.json").write_text(
            json.dumps(translate_mcp_for_agy(plugin["mcp"]), indent=2) + "\n", encoding="utf-8"
        )


def gen_agy(manifest: dict, plugins: list[dict], out_dir: Path) -> None:
    agy_dir = out_dir / "dist" / "agy"
    if agy_dir.exists():
        shutil.rmtree(agy_dir)
    agy_dir.mkdir(parents=True)

    for p in plugins:
        write_agy_plugin(p, agy_dir / p["meta"]["name"])

    bundle_id = manifest["bundle"]["id"]
    bundle_dest = agy_dir / bundle_id
    bundle_dest.mkdir(parents=True)
    (bundle_dest / "plugin.json").write_text(json.dumps({"name": bundle_id}, indent=2) + "\n", encoding="utf-8")
    bundle_skills = bundle_dest / "skills"
    for p in plugins:
        for s in p["skills"]:
            shutil.copytree(s["dir"], bundle_skills / s["frontmatter"]["name"])

    dist_readme = out_dir / "dist" / "README.md"
    dist_readme.write_text(
        "# Generated\n\n"
        "This directory is generated by `scripts/generate_plugins.py` from "
        "`manifest.yaml` and `plugins/`. Do not edit files here directly — "
        "edit the source plugin instead and regenerate.\n",
        encoding="utf-8",
    )


GENERATORS = {
    "claude-code": gen_claude_code,
    "agy": gen_agy,
}


# ── Local Install Helper ─────────────────────────────────────────────────────


def install_local(manifest: dict, out_dir: Path) -> None:
    home = Path.home()
    mp_name = f"{manifest['marketplace']['name']}-private"

    claude_src = out_dir / ".claude-plugin"
    if claude_src.exists():
        claude_dest = home / ".claude" / "plugins" / "marketplaces" / mp_name
        if claude_dest.exists():
            shutil.rmtree(claude_dest)
        claude_dest.mkdir(parents=True)
        shutil.copytree(claude_src, claude_dest / ".claude-plugin")
        shutil.copytree(out_dir / "dist" / "claude-code", claude_dest / "dist" / "claude-code")
        print(f"Installed Claude Code marketplace locally: {claude_dest}")
        print(f"  /plugin marketplace add {claude_dest}")

    agy_src = out_dir / "dist" / "agy"
    if agy_src.exists():
        install_agy_script = ROOT / "scripts" / "install_agy.py"
        result = subprocess.run(
            [sys.executable, str(install_agy_script), "--all", "--dist-dir", str(agy_src)],
            capture_output=True,
            text=True,
        )
        print(result.stdout, end="")
        if result.returncode != 0:
            print(result.stderr, end="", file=sys.stderr)


# ── CLI ───────────────────────────────────────────────────────────────────────


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate only, write nothing")
    parser.add_argument(
        "--source",
        action="append",
        default=None,
        help="a directory containing its own plugins/ folder; repeatable, layered in order (default: repo root)",
    )
    parser.add_argument("--private-repo", help="git URL of a private overlay repo to clone and layer on top")
    parser.add_argument("--private-ref", default="main", help="branch/tag to clone from --private-repo (default: main)")
    parser.add_argument(
        "--private-token-env",
        help="name of an environment variable holding a token for --private-repo (read at run time, never taken as a literal value)",
    )
    parser.add_argument(
        "--out",
        help="output directory (default: '.' for a pure public build, 'dist-private' when overlaying a private source)",
    )
    parser.add_argument(
        "--install-local",
        action="store_true",
        help="after generating, install the result into local Claude Code / agy config",
    )
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])

    try:
        manifest = load_manifest()
        for target in manifest["targets"]:
            if target not in GENERATORS:
                raise ValidationError(f"manifest.yaml: unknown target '{target}'")

        source_roots = [Path(s).expanduser().resolve() for s in (args.source or [str(ROOT)])]
        has_overlay = bool(args.private_repo) or len(source_roots) > 1

        with tempfile.TemporaryDirectory(prefix="rootiest-ai-build-") as tmp:
            workdir = Path(tmp)
            if args.private_repo:
                private_dir = clone_private_repo(args.private_repo, args.private_ref, args.private_token_env, workdir)
                source_roots.append(private_dir)

            layers = collect_layers(source_roots)
            merged_root = merge_layers(layers, workdir)
            plugins = discover_plugins(merged_root)

            if args.check:
                print(f"OK: {len(plugins)} plugin(s), {len(manifest['targets'])} target(s) validated")
                return 0

            out_dir = Path(args.out).expanduser().resolve() if args.out else (
                (ROOT / "dist-private") if has_overlay else ROOT
            )
            out_dir.mkdir(parents=True, exist_ok=True)

            for target in manifest["targets"]:
                GENERATORS[target](manifest, plugins, out_dir)

            print(f"Generated plugins for {len(plugins)} plugin(s) -> {out_dir}, targets: {', '.join(manifest['targets'])}")

            if args.install_local:
                install_local(manifest, out_dir)

        return 0
    except ValidationError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
