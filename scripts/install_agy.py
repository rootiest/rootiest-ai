#!/usr/bin/env python3
"""Install generated agy plugins into agy's real, working config locations.

agy documents a `plugins.json` "entries" indirection for discovering plugin
bundles from an arbitrary directory, but empirically (tested against a live
agy session) it does not reliably surface a `plugins/<name>/plugin.json`
bundle as a plugin — hooks and MCP servers inside it are never loaded, and
only a stray skill occasionally surfaces via agy's generic skill-walk. The
mechanism that IS confirmed working is placing things directly where agy
actually looks:

  - skills:        <root>/skills/<skill>/            (symlinked from dist/agy)
  - MCP servers:    <root>/mcp_config.json            (merged in, "mcpServers" key)
  - lifecycle hooks: <root>/hooks.json                (merged in, one top-level key per plugin)

where <root> is `~/.gemini/config` (global, default) or `.agents` at the
project's git root (--project).

Run `scripts/generate_plugins.py` first to produce `dist/agy/**`; this
script only consumes that output, it doesn't generate anything itself.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class InstallError(Exception):
    pass


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def resolve_target_root(project: bool) -> Path:
    if not project:
        return Path.home() / ".gemini" / "config"
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    project_root = Path(result.stdout.strip()) if result.returncode == 0 else Path.cwd()
    return project_root / ".agents"


def discover_plugin_names(dist_agy: Path, bundle_id: "str | None") -> list[str]:
    if not dist_agy.is_dir():
        raise InstallError(
            f"{dist_agy} does not exist. Run `python3 scripts/generate_plugins.py` first."
        )
    names = [p.name for p in sorted(dist_agy.iterdir()) if p.is_dir()]
    if bundle_id and bundle_id in names:
        names.remove(bundle_id)  # would just re-symlink every skill a second time
    return names


def install_plugin(name: str, dist_agy: Path, target_root: Path) -> None:
    plugin_dir = dist_agy / name
    if not plugin_dir.is_dir():
        raise InstallError(f"no such generated plugin: {name} (looked in {plugin_dir})")

    skills_dir = plugin_dir / "skills"
    if skills_dir.is_dir():
        target_skills = target_root / "skills"
        target_skills.mkdir(parents=True, exist_ok=True)
        for skill_dir in sorted(skills_dir.iterdir()):
            if not skill_dir.is_dir():
                continue
            link = target_skills / skill_dir.name
            if link.is_symlink() or link.exists():
                if link.is_symlink():
                    link.unlink()
                else:
                    raise InstallError(
                        f"{link} already exists and is not a symlink managed by this script "
                        "— remove it manually if you want to replace it"
                    )
            link.symlink_to(skill_dir.resolve())
            print(f"  skill:  {skill_dir.name} -> {link}")

    mcp_path = plugin_dir / "mcp_config.json"
    if mcp_path.exists():
        source = load_json(mcp_path)
        target_path = target_root / "mcp_config.json"
        target = load_json(target_path)
        target.setdefault("mcpServers", {})
        for server_name, cfg in source.get("mcpServers", {}).items():
            target["mcpServers"][server_name] = cfg
            print(f"  mcp:    {server_name} -> {target_path}")
        write_json(target_path, target)

    hooks_path = plugin_dir / "hooks.json"
    if hooks_path.exists():
        source = load_json(hooks_path)
        target_path = target_root / "hooks.json"
        target = load_json(target_path)
        for hook_name, spec in source.items():
            target[hook_name] = spec
            print(f"  hook:   {hook_name} -> {target_path}")
        write_json(target_path, target)

    if not any((skills_dir.is_dir(), mcp_path.exists(), hooks_path.exists())):
        print(f"  (nothing to install for '{name}')")


def uninstall_plugin(name: str, dist_agy: Path, target_root: Path) -> None:
    plugin_dir = dist_agy / name
    if not plugin_dir.is_dir():
        raise InstallError(f"no such generated plugin: {name} (looked in {plugin_dir})")

    skills_dir = plugin_dir / "skills"
    if skills_dir.is_dir():
        for skill_dir in sorted(skills_dir.iterdir()):
            link = target_root / "skills" / skill_dir.name
            if link.is_symlink() and link.resolve() == skill_dir.resolve():
                link.unlink()
                print(f"  removed skill symlink: {link}")

    mcp_path = plugin_dir / "mcp_config.json"
    if mcp_path.exists():
        source = load_json(mcp_path)
        target_path = target_root / "mcp_config.json"
        target = load_json(target_path)
        for server_name in source.get("mcpServers", {}):
            if target.get("mcpServers", {}).pop(server_name, None) is not None:
                print(f"  removed mcp server: {server_name}")
        if target_path.exists():
            write_json(target_path, target)

    hooks_path = plugin_dir / "hooks.json"
    if hooks_path.exists():
        source = load_json(hooks_path)
        target_path = target_root / "hooks.json"
        target = load_json(target_path)
        for hook_name in source:
            if target.pop(hook_name, None) is not None:
                print(f"  removed hook group: {hook_name}")
        if target_path.exists():
            write_json(target_path, target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("plugins", nargs="*", help="plugin name(s) to install/uninstall")
    parser.add_argument("--all", action="store_true", help="install/uninstall every generated plugin")
    parser.add_argument("--uninstall", action="store_true", help="remove instead of install")
    parser.add_argument("--project", action="store_true", help="target .agents/ at the project's git root instead of ~/.gemini/config")
    parser.add_argument("--dist-dir", help="path to a generated dist/agy directory (default: <repo>/dist/agy)")
    args = parser.parse_args(sys.argv[1:])

    try:
        dist_agy = Path(args.dist_dir).expanduser().resolve() if args.dist_dir else ROOT / "dist" / "agy"
        target_root = resolve_target_root(args.project)

        bundle_id = None
        manifest_path = ROOT / "manifest.yaml"
        if manifest_path.exists():
            import yaml

            bundle_id = yaml.safe_load(manifest_path.read_text(encoding="utf-8")).get("bundle", {}).get("id")

        if args.all:
            names = discover_plugin_names(dist_agy, bundle_id)
        elif args.plugins:
            names = args.plugins
        else:
            parser.error("specify plugin name(s) or --all")

        action = uninstall_plugin if args.uninstall else install_plugin
        verb = "Uninstalling" if args.uninstall else "Installing"
        print(f"{verb} {len(names)} plugin(s) -> {target_root}")
        for name in names:
            print(f"{name}:")
            action(name, dist_agy, target_root)

        return 0
    except InstallError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
