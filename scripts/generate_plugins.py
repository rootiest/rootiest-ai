#!/usr/bin/env python3
"""Generate per-agent plugin manifests from the skills/ SSoT.

Reads manifest.yaml (marketplace/org metadata + target list) and every
skills/<name>/SKILL.md (per-skill frontmatter), then regenerates:

  - descriptions.json                    (from SKILL.md frontmatter)
  - .claude-plugin/marketplace.json      (Claude Code target)
  - dist/agy/**                          (Antigravity CLI target)

Run with --check to only validate the SSoT (frontmatter, manifest.yaml) and
skip writing any output — used as the pull-request gate.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"
MANIFEST_PATH = ROOT / "manifest.yaml"

REQUIRED_FRONTMATTER_FIELDS = ("name", "description", "version", "author")


class ValidationError(Exception):
    pass


def load_manifest() -> dict:
    with MANIFEST_PATH.open("r", encoding="utf-8") as f:
        manifest = yaml.safe_load(f)
    for key in ("marketplace", "bundle", "targets"):
        if key not in manifest:
            raise ValidationError(f"manifest.yaml is missing required key '{key}'")
    return manifest


def parse_frontmatter(skill_md: Path) -> dict:
    text = skill_md.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValidationError(f"{skill_md}: missing YAML frontmatter delimiter")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValidationError(f"{skill_md}: unterminated YAML frontmatter")
    raw = text[4:end]
    data = yaml.safe_load(raw) or {}
    for field in REQUIRED_FRONTMATTER_FIELDS:
        if not data.get(field):
            raise ValidationError(f"{skill_md}: frontmatter missing required field '{field}'")
    return data


def discover_skills() -> list[dict]:
    skills = []
    seen_names = set()
    for skill_dir in sorted(SKILLS_DIR.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.exists():
            raise ValidationError(f"{skill_dir}: missing SKILL.md")
        frontmatter = parse_frontmatter(skill_md)
        name = frontmatter["name"]
        if name != skill_dir.name:
            raise ValidationError(
                f"{skill_md}: frontmatter name '{name}' does not match directory name '{skill_dir.name}'"
            )
        if name in seen_names:
            raise ValidationError(f"duplicate skill name '{name}'")
        seen_names.add(name)
        skills.append({"dir": skill_dir, "frontmatter": frontmatter})
    if not skills:
        raise ValidationError("no skills found under skills/")
    return skills


def gen_descriptions_json(skills: list[dict]) -> None:
    descriptions = {s["frontmatter"]["name"]: s["frontmatter"]["description"] for s in skills}
    out = ROOT / "descriptions.json"
    out.write_text(json.dumps(descriptions, indent=2) + "\n", encoding="utf-8")


def gen_claude_code(manifest: dict, skills: list[dict]) -> None:
    plugin_dir = ROOT / ".claude-plugin"
    plugin_dir.mkdir(exist_ok=True)

    plugins = []
    for s in skills:
        fm = s["frontmatter"]
        plugins.append(
            {
                "name": fm["name"],
                "description": fm["description"],
                "source": "./",
                "skills": [f"./skills/{fm['name']}"],
            }
        )

    plugins.append(
        {
            "name": manifest["bundle"]["id"],
            "description": f"{manifest['marketplace']['description']} (all skills)",
            "source": "./",
            "skills": ["./skills/"],
        }
    )

    marketplace = {
        "name": manifest["marketplace"]["name"],
        "owner": manifest["marketplace"]["owner"],
        "description": manifest["marketplace"]["description"],
        "plugins": plugins,
    }

    out = plugin_dir / "marketplace.json"
    out.write_text(json.dumps(marketplace, indent=2) + "\n", encoding="utf-8")


def gen_agy(manifest: dict, skills: list[dict]) -> None:
    agy_dir = ROOT / "dist" / "agy"
    if agy_dir.exists():
        shutil.rmtree(agy_dir)
    agy_dir.mkdir(parents=True)

    def write_plugin(plugin_name: str, description: str, members: list[dict]) -> None:
        plugin_root = agy_dir / plugin_name
        skills_out = plugin_root / "skills"
        skills_out.mkdir(parents=True)
        for s in members:
            dest = skills_out / s["frontmatter"]["name"]
            shutil.copytree(s["dir"], dest)
        plugin_json = {"name": plugin_name, "description": description}
        (plugin_root / "plugin.json").write_text(
            json.dumps(plugin_json, indent=2) + "\n", encoding="utf-8"
        )

    for s in skills:
        fm = s["frontmatter"]
        write_plugin(fm["name"], fm["description"], [s])

    write_plugin(
        manifest["bundle"]["id"],
        f"{manifest['marketplace']['description']} (all skills)",
        skills,
    )

    dist_readme = ROOT / "dist" / "README.md"
    dist_readme.write_text(
        "# Generated\n\n"
        "This directory is generated by `scripts/generate_plugins.py` from "
        "`manifest.yaml` and `skills/`. Do not edit files here directly — "
        "edit the source skill instead and regenerate.\n",
        encoding="utf-8",
    )


GENERATORS = {
    "claude-code": gen_claude_code,
    "agy": gen_agy,
}


def main() -> int:
    check_only = "--check" in sys.argv[1:]
    try:
        manifest = load_manifest()
        skills = discover_skills()
        for target in manifest["targets"]:
            if target not in GENERATORS:
                raise ValidationError(f"manifest.yaml: unknown target '{target}'")
        if check_only:
            print(f"OK: {len(skills)} skill(s), {len(manifest['targets'])} target(s) validated")
            return 0
        gen_descriptions_json(skills)
        for target in manifest["targets"]:
            GENERATORS[target](manifest, skills)
        print(f"Generated plugins for {len(skills)} skill(s), targets: {', '.join(manifest['targets'])}")
        return 0
    except ValidationError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
