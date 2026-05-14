#!/usr/bin/env bash
# install.sh — AI Skill Installer
# Install skills from rootiest/ai-skills into Claude Code and/or Gemini CLI
#
# Usage: bash <(curl -sL <url>) [OPTIONS] [SKILL...]

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
readonly BASE_URL="https://git.rootiest.dev/rootiest/ai-skills/raw/branch/main"
readonly REPO_URL="https://git.rootiest.dev/rootiest/ai-skills.git"
readonly API_URL="https://git.rootiest.dev/api/v1/repos/rootiest/ai-skills/contents/skills"

# Overridable via environment
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"
GEMINI_SKILLS_DIR="${GEMINI_SKILLS_DIR:-${HOME}/.gemini/skills}"

# ── ANSI Colors (only when writing to a terminal) ─────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  BOLD_CYAN=$'\033[1;36m'
  BOLD_GREEN=$'\033[1;32m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  RED=$'\033[0;31m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  BOLD='' BOLD_CYAN='' BOLD_GREEN='' GREEN='' YELLOW='' RED='' DIM='' RESET=''
fi

# ── State ─────────────────────────────────────────────────────────────────────
INSTALL_CLAUDE=false
INSTALL_GEMINI=false
INSTALL_ALL=false
declare -a SKILLS=()
TMP_DIR=""

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# ── Output Helpers ────────────────────────────────────────────────────────────
info()    { printf "  ${BOLD_CYAN}→${RESET}  %b\n" "$*"; }
ok()      { printf "  ${BOLD_GREEN}✓${RESET}  %b\n" "$*"; }
warn()    { printf "  ${YELLOW}⚠${RESET}  %b\n" "$*" >&2; }
die()     { printf "  ${RED}✗  ERROR:${RESET} %b\n" "$*" >&2; exit 1; }
sep()     { printf "${BOLD_CYAN}%s${RESET}\n" "──────────────────────────────────────────"; }

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
  printf "\n"
  printf "${BOLD_CYAN}  AI Skill Installer${RESET}\n"
  printf "${DIM}  Install skills from rootiest/ai-skills into Claude Code and Gemini CLI${RESET}\n"
  printf "\n"
  printf "${BOLD}  USAGE${RESET}\n"
  printf "    install.sh [OPTIONS] [SKILL...]\n"
  printf "    bash <(curl -sL <url>/install.sh) [OPTIONS] [SKILL...]\n"
  printf "\n"
  printf "${BOLD}  TOOL TARGETS${RESET}\n"
  printf "    ${GREEN}-c, --claude${RESET}    Install into Claude Code  (\$CLAUDE_SKILLS_DIR)\n"
  printf "    ${GREEN}-g, --gemini${RESET}    Install into Gemini CLI   (\$GEMINI_SKILLS_DIR)\n"
  printf "    ${DIM}                (default: install for both tools)${RESET}\n"
  printf "\n"
  printf "${BOLD}  SKILL SELECTION${RESET}\n"
  printf "    ${GREEN}-a, --all${RESET}       Install every skill in the repository\n"
  printf "    ${GREEN}SKILL...${RESET}        One or more skill names (folder names under skills/)\n"
  printf "    ${DIM}                Specific names always override --all${RESET}\n"
  printf "\n"
  printf "${BOLD}  OTHER${RESET}\n"
  printf "    ${GREEN}-h, --help${RESET}      Show this help page\n"
  printf "\n"
  printf "${BOLD}  EXAMPLES${RESET}\n"
  printf "    ${DIM}# Install all skills for both tools${RESET}\n"
  printf "    install.sh --all\n"
  printf "\n"
  printf "    ${DIM}# Install one skill, Claude Code only${RESET}\n"
  printf "    install.sh --claude my-skill\n"
  printf "\n"
  printf "    ${DIM}# Install two skills, Gemini CLI only${RESET}\n"
  printf "    install.sh --gemini skill-one skill-two\n"
  printf "\n"
  printf "    ${DIM}# Named skills override --all (only those listed are installed)${RESET}\n"
  printf "    install.sh --all --claude skill-name\n"
  printf "\n"
  printf "${BOLD}  ENVIRONMENT${RESET}\n"
  printf "    ${GREEN}CLAUDE_SKILLS_DIR${RESET}   Claude skills directory  (default: ~/.claude/skills)\n"
  printf "    ${GREEN}GEMINI_SKILLS_DIR${RESET}   Gemini skills directory  (default: ~/.gemini/skills)\n"
  printf "\n"
  printf "${BOLD}  REPOSITORY${RESET}\n"
  printf "    ${DIM}%s${RESET}\n" "$REPO_URL"
  printf "\n"
}

# ── Dependency Check ──────────────────────────────────────────────────────────
check_deps() {
  local -a missing=()
  command -v curl &>/dev/null || missing+=(curl)
  command -v git  &>/dev/null || missing+=(git)
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}"
  fi
}

# ── Validate Skill Name ───────────────────────────────────────────────────────
validate_skill_name() {
  local name="$1"
  if [[ -z "$name" ]];         then die "Skill name cannot be empty."; fi
  if [[ "$name" == *".."* ]];  then die "Invalid skill name (path traversal): '${name}'"; fi
  if [[ "$name" == *"/"* ]];   then die "Invalid skill name (contains slash): '${name}'"; fi
}

# ── Parse Directory Names from Gitea API JSON ─────────────────────────────────
# Supports jq, python3, or no-dep grep/awk fallback
parse_dir_names() {
  local json="$1"

  if command -v jq &>/dev/null; then
    printf '%s' "$json" | jq -r '.[] | select(.type == "dir") | .name'
    return
  fi

  if command -v python3 &>/dev/null; then
    printf '%s' "$json" | python3 -c \
      "import sys,json; [print(e['name']) for e in json.load(sys.stdin) if e.get('type')=='dir']"
    return
  fi

  # Awk fallback: track name/type fields within each JSON object token stream.
  # Reliable for single-line (minified) Gitea API responses.
  printf '%s' "$json" | tr ',' '\n' | awk -F'"' '
    /^[[:space:]]*"name"/  { name = $4 }
    /^[[:space:]]*"type".*"dir"/ { if (name != "") print name; name = "" }
  '
}

# ── Discover Available Skills ─────────────────────────────────────────────────
discover_skills() {
  info "Discovering available skills from repository..."

  # Attempt 1: Gitea contents API
  local api_response
  api_response=$(curl -sf --max-time 15 "$API_URL" 2>/dev/null) || api_response=""

  if [[ -n "$api_response" ]]; then
    mapfile -t SKILLS < <(parse_dir_names "$api_response" 2>/dev/null | grep -v '^$' || true)
  fi

  # Attempt 2: Sparse/no-checkout git clone — no JSON parsing required
  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    warn "API unavailable or returned no results — falling back to git ls-tree..."
    TMP_DIR=$(mktemp -d)
    if ! git clone \
        --quiet \
        --depth=1 \
        --filter=blob:none \
        --no-checkout \
        "$REPO_URL" \
        "${TMP_DIR}/repo" 2>/dev/null; then
      die "Cannot reach repository.\n  URL: ${REPO_URL}\n  Check your network connection."
    fi
    mapfile -t SKILLS < <(
      git -C "${TMP_DIR}/repo" ls-tree --name-only HEAD "skills/" 2>/dev/null \
        | grep -v '^\.' \
        | grep -v '^$' \
        || true
    )
  fi

  if [[ ${#SKILLS[@]} -eq 0 ]]; then
    die "No skills found in repository. Verify the skills/ directory exists:\n  ${REPO_URL}"
  fi

  ok "Found ${#SKILLS[@]} skill(s): ${DIM}${SKILLS[*]}${RESET}"
}

# ── Fetch a Single Skill's SKILL.md ──────────────────────────────────────────
fetch_skill() {
  local skill_name="$1"
  local url="${BASE_URL}/skills/${skill_name}/SKILL.md"
  if ! curl -sf --max-time 30 "$url" 2>/dev/null; then
    warn "Download failed: ${url}"
    return 1
  fi
}

# ── Install to Claude Code ────────────────────────────────────────────────────
install_to_claude() {
  local skill_name="$1"
  local dest="${CLAUDE_SKILLS_DIR}/${skill_name}/SKILL.md"

  info "[Claude] Downloading ${BOLD}${skill_name}${RESET}..."

  local content
  if ! content=$(fetch_skill "$skill_name"); then
    warn "[Claude] Skipping '${skill_name}' — download failed."
    return 1
  fi

  mkdir -p "${CLAUDE_SKILLS_DIR}/${skill_name}"
  printf '%s\n' "$content" > "$dest"
  ok "[Claude] ${BOLD}${skill_name}${RESET} → ${DIM}${dest}${RESET}"
}

# ── Install to Gemini CLI ─────────────────────────────────────────────────────
install_to_gemini() {
  local skill_name="$1"
  local dest="${GEMINI_SKILLS_DIR}/${skill_name}/SKILL.md"

  info "[Gemini] Downloading ${BOLD}${skill_name}${RESET}..."

  local content
  if ! content=$(fetch_skill "$skill_name"); then
    warn "[Gemini] Skipping '${skill_name}' — download failed."
    return 1
  fi

  mkdir -p "${GEMINI_SKILLS_DIR}/${skill_name}"
  printf '%s\n' "$content" > "$dest"
  ok "[Gemini] ${BOLD}${skill_name}${RESET} → ${DIM}${dest}${RESET}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  if [[ $# -eq 0 ]]; then show_help; exit 0; fi

  local -a positional=()

  # ── Parse Arguments ────────────────────────────────────────────────────────
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)   show_help; exit 0 ;;
      -c|--claude) INSTALL_CLAUDE=true ;;
      -g|--gemini) INSTALL_GEMINI=true ;;
      -a|--all)    INSTALL_ALL=true ;;
      -*)          die "Unknown option: '${1}'. Run with -h for help." ;;
      *)           positional+=("$1") ;;
    esac
    shift
  done

  # Default: install for both tools when neither is specified
  if ! $INSTALL_CLAUDE && ! $INSTALL_GEMINI; then
    INSTALL_CLAUDE=true
    INSTALL_GEMINI=true
  fi

  check_deps

  # ── Skill Resolution ───────────────────────────────────────────────────────
  # Named positional arguments always take precedence over --all
  if [[ ${#positional[@]} -gt 0 ]]; then
    SKILLS=("${positional[@]}")
    for skill in "${SKILLS[@]}"; do
      validate_skill_name "$skill"
    done
  elif $INSTALL_ALL; then
    discover_skills
  else
    warn "No skills specified. Provide skill name(s) or use --all."
    printf "\n"
    show_help
    exit 1
  fi

  # ── Target Label for Display ──────────────────────────────────────────────
  local target_label
  if $INSTALL_CLAUDE && $INSTALL_GEMINI; then
    target_label="Claude Code + Gemini CLI"
  elif $INSTALL_CLAUDE; then
    target_label="Claude Code"
  else
    target_label="Gemini CLI"
  fi

  # ── Header ────────────────────────────────────────────────────────────────
  printf "\n"
  sep
  printf "  ${BOLD}%d skill(s)${RESET} → %s\n" "${#SKILLS[@]}" "$target_label"
  sep
  printf "\n"

  # ── Install Loop ──────────────────────────────────────────────────────────
  local errors=0
  for skill in "${SKILLS[@]}"; do
    printf "  ${BOLD}%s${RESET}\n" "$skill"
    if $INSTALL_CLAUDE; then
      install_to_claude "$skill" || errors=$((errors + 1))
    fi
    if $INSTALL_GEMINI; then
      install_to_gemini "$skill" || errors=$((errors + 1))
    fi
    printf "\n"
  done

  # ── Summary ───────────────────────────────────────────────────────────────
  sep
  if [[ $errors -eq 0 ]]; then
    printf "  ${BOLD_GREEN}✓ All skills installed successfully.${RESET}\n"
  else
    printf "  ${YELLOW}⚠ %d installation(s) failed.${RESET} Review warnings above.\n" "$errors"
  fi
  sep
  printf "\n"

  if [[ $errors -gt 0 ]]; then exit 1; fi
  return 0
}

main "$@"
