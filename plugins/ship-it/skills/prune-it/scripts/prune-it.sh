#!/usr/bin/env bash
#
# Copyright (c) 2026 Christopher Robert Laprade (Rootiest)
# Licensed under the MIT License.
#

set -euo pipefail

show_help() {
  cat <<'EOF'
NAME
    prune-it - Sync the default branch and delete merged or orphaned branches

SYNOPSIS
    prune-it [OPTIONS]

DESCRIPTION
    Fetches and prunes the remote, fast-forwards the local default branch, and
    deletes branches whose content is already in the default branch:

      - Local branches merged into <remote>/<default> by any strategy
        (merge commit, fast-forward, rebase, or squash).
      - Local branches whose upstream was deleted ("gone"). Gone branches with
        unmerged commits are kept and reported unless --force is given.
      - Remote branches merged into <remote>/<default>, unless they are the
        head of an open pull request (a local branch tracking one is kept
        too). Open PRs are listed with whatever works: gh, tea or glab,
        else curl with a token from the environment bound to the remote's
        host, else anonymous curl for a public repository (GitHub, Gitea/
        Forgejo, GitLab, self-hosted included). If none works, remote
        deletion is skipped entirely.

    Never touched: the default branch, protected names (main, master,
    develop, dev, trunk, staging, production, gh-pages, release/*), --keep
    branches, branches checked out in another worktree, local branches
    created but never committed to, and any branch with unmerged commits
    whose upstream still exists. Unmerged remote branches are never deleted,
    even with --force.

    If the current branch is to be deleted, the script switches to the
    default branch first, or keeps the branch if tracked files have
    uncommitted changes.

OPTIONS
    -n, --dry-run       Print the plan; fetch, but change nothing else
    -f, --force         Also delete local gone branches with unmerged commits
    -l, --local-only    Do not delete remote branches
    -r, --remote NAME   Remote to sync and prune (default: origin)
    -k, --keep BRANCH   Never delete BRANCH (local or remote); repeatable
    -h, --help          Display this help documentation and exit

RETURNS
    0                   Cleanup complete (or plan printed with --dry-run)
    1                   One or more deletions failed
    2                   Usage error, not a git repository, or no default branch

    If the fetch fails, cleanup continues offline against the last fetched
    state and skips remote deletion.

EXAMPLES
    prune-it --dry-run
    prune-it
    prune-it --force --keep wip/experiment
EOF
}

remote=origin
dry_run=0
force=0
do_remote=1
keep=()

while [ $# -gt 0 ]; do
  case $1 in
    -n | --dry-run) dry_run=1 ;;
    -f | --force) force=1 ;;
    -l | --local-only) do_remote=0 ;;
    -r | --remote)
      [ $# -ge 2 ] || { echo "prune-it: $1 needs a value" >&2; exit 2; }
      remote=$2
      shift
      ;;
    -k | --keep)
      [ $# -ge 2 ] || { echo "prune-it: $1 needs a value" >&2; exit 2; }
      keep+=("$2")
      shift
      ;;
    -h | --help) show_help; exit 0 ;;
    *) echo "prune-it: unknown option '$1' (see --help)" >&2; exit 2 ;;
  esac
  shift
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "prune-it: not inside a git work tree" >&2
  exit 2
}

has_remote=0
if git remote get-url "$remote" >/dev/null 2>&1; then
  has_remote=1
  echo "Fetching and pruning '$remote'..."
  # Offline is still safe for local branches: anything merged into a stale
  # <remote>/<default> is merged into the current one too.
  if ! git fetch --prune --quiet "$remote"; then
    echo "prune-it: fetch from '$remote' failed; using the last fetched state, local branches only" >&2
    do_remote=0
  fi
else
  echo "No remote '$remote'; cleaning local branches only."
  do_remote=0
fi
git worktree prune

# ── Default branch & comparison base ─────────────────────────────────────────

default=
if [ $has_remote = 1 ] && ref=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null); then
  default=${ref#"$remote"/}
else
  for b in main master; do
    if git show-ref --verify --quiet "refs/remotes/$remote/$b" ||
      git show-ref --verify --quiet "refs/heads/$b"; then
      default=$b
      break
    fi
  done
fi
[ -n "$default" ] || { echo "prune-it: cannot determine the default branch" >&2; exit 2; }

if [ $has_remote = 1 ] && git show-ref --verify --quiet "refs/remotes/$remote/$default"; then
  base=refs/remotes/$remote/$default
else
  base=refs/heads/$default
fi
echo "Default branch: $default (comparing against ${base#refs/remotes/})"

current=$(git branch --show-current)
toplevel=$(git rev-parse --show-toplevel)

# ── Helpers ──────────────────────────────────────────────────────────────────

is_protected() {
  case $1 in
    "$default" | main | master | develop | dev | trunk | staging | production | gh-pages | release/*) return 0 ;;
  esac
  local k
  for k in "${keep[@]+"${keep[@]}"}"; do
    [ "$1" = "$k" ] && return 0
  done
  return 1
}

# Succeeds when every change on $1 is already in $base. Covers merge commits
# and fast-forwards (ancestry), rebase merges (every commit has a
# patch-equivalent on base), and squash merges (the branch's whole diff
# matches one commit on base). Anything else fails, so the branch is kept.
merged_reason=
content_merged() {
  local ref=$1 out mb tree probe
  if git merge-base --is-ancestor "$ref" "$base"; then
    merged_reason=merged
    return 0
  fi
  out=$(git cherry "$base" "$ref") || return 1
  if ! grep -q '^+' <<<"$out"; then
    merged_reason=rebase-merged
    return 0
  fi
  mb=$(git merge-base "$base" "$ref") || return 1
  tree=$(git rev-parse "$ref^{tree}") || return 1
  probe=$(GIT_AUTHOR_NAME=prune-it GIT_AUTHOR_EMAIL=prune-it@localhost \
    GIT_COMMITTER_NAME=prune-it GIT_COMMITTER_EMAIL=prune-it@localhost \
    git commit-tree "$tree" -p "$mb" -m prune-it-probe) || return 1
  out=$(git cherry "$base" "$probe") || return 1
  if [[ $out == -* ]]; then
    merged_reason=squash-merged
    return 0
  fi
  return 1
}

# A local branch that was created and never moved: every reflog entry is the
# creation entry. Its tip is usually an ancestor of base, but it is new work,
# not merged work. Only checked for branches with no upstream, so a branch
# checked out from someone else's remote branch is still cleaned up.
is_fresh() {
  local entries
  entries=$(git reflog show --format=%gs "refs/heads/$1" -- 2>/dev/null) || return 1
  [ -n "$entries" ] || return 1
  ! grep -qv '^branch: Created from' <<<"$entries"
}

# Bare, lowercased host of a remote URL, web URL, or host value: scheme,
# user, port and path dropped. Fails for a local path remote.
url_host() {
  local h=$1
  case $h in /* | .* | ~* | file://*) return 1 ;; esac
  h=${h#*://}
  h=${h%%/*}
  h=${h##*@}
  h=${h%%:*}
  [ -n "$h" ] || return 1
  printf '%s\n' "$h" | tr '[:upper:]' '[:lower:]'
}

# First API token in the environment that belongs to <host> on <forge>. A
# token is only handed out for the host it is bound to, so a repository on
# someone else's server never receives it:
#   github  GH_TOKEN, GITHUB_TOKEN, GITHUB_PERSONAL_ACCESS_TOKEN -> github.com;
#           GH_ENTERPRISE_TOKEN, GITHUB_ENTERPRISE_TOKEN -> $GH_HOST
#   gitea   GITEA_TOKEN, GITEA_ACCESS_TOKEN, FORGEJO_TOKEN -> the host in
#           $GITEA_HOST, $GITEA_URL, $GITEA_SERVER_URL or $FORGEJO_HOST only
#   gitlab  GITLAB_TOKEN, GITLAB_PRIVATE_TOKEN, GITLAB_ACCESS_TOKEN -> the host
#           in $GITLAB_HOST, $GITLAB_URI or $GITLAB_URL, else gitlab.com
forge_token() {
  local forge=$1 host=$2 tokens=() bounds=() b v t match=0
  case $forge in
    github)
      if [ "$host" = github.com ]; then
        tokens=(GH_TOKEN GITHUB_TOKEN GITHUB_PERSONAL_ACCESS_TOKEN)
        bounds=(github.com)
      else
        tokens=(GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN)
        bounds=("${GH_HOST:-}")
      fi
      ;;
    gitea)
      tokens=(GITEA_TOKEN GITEA_ACCESS_TOKEN FORGEJO_TOKEN)
      bounds=("${GITEA_HOST:-}" "${GITEA_URL:-}" "${GITEA_SERVER_URL:-}" "${FORGEJO_HOST:-}")
      ;;
    gitlab)
      tokens=(GITLAB_TOKEN GITLAB_PRIVATE_TOKEN GITLAB_ACCESS_TOKEN)
      bounds=("${GITLAB_HOST:-}" "${GITLAB_URI:-}" "${GITLAB_URL:-}")
      [ -n "${GITLAB_HOST:-}${GITLAB_URI:-}${GITLAB_URL:-}" ] || bounds=(gitlab.com)
      ;;
    *) return 1 ;;
  esac
  for b in "${bounds[@]}"; do
    [ -n "$b" ] || continue
    if [ "$(url_host "$b")" = "$host" ]; then match=1; break; fi
  done
  [ $match = 1 ] || return 1
  for t in "${tokens[@]}"; do
    v=${!t:-}
    if [ -n "$v" ]; then printf '%s\n' "$v"; return 0; fi
  done
  return 1
}

# Print the head branch names on one page of open PRs (MRs). <method> is cli
# (gh/tea/glab scoped to <host>), token (curl with forge_token) or anon (curl,
# public repos). Fails if the method is unavailable or the response is not a
# JSON array, which is also what the wrong forge's API returns, so a wrong
# guess just fails over. Redirects are never followed, and the token goes to
# curl on stdin, never on its command line.
pr_page() {
  local method=$1 forge=$2 host=$3 path=$4 page=$5 q api auth body tok login
  local filter='.[].head | .ref, (.label // "" | sub("^[^:]*:"; ""))'
  case $forge in
    github)
      q="repos/$path/pulls?state=open&per_page=100&page=$page"
      api=https://api.github.com
      [ "$host" = github.com ] || api=https://$host/api/v3
      auth='Authorization: Bearer'
      ;;
    gitea)
      q="repos/$path/pulls?state=open&limit=50&page=$page"
      api=https://$host/api/v1
      auth='Authorization: token'
      ;;
    gitlab)
      q="projects/${path//\//%2F}/merge_requests?state=opened&per_page=100&page=$page"
      api=https://$host/api/v4
      auth='PRIVATE-TOKEN:'
      filter='.[].source_branch'
      ;;
    *) return 1 ;;
  esac

  case $method in
    cli)
      case $forge in
        github)
          # gh filters with its built-in jq, so no parser is needed.
          command -v gh >/dev/null || return 1
          gh api --hostname "$host" "$q" \
            -q "if type == \"array\" then $filter else error(\"not a list\") end" \
            </dev/null 2>/dev/null || return 1
          return 0
          ;;
        gitea)
          command -v tea >/dev/null || return 1
          # Use the login for this host, not tea's default login.
          login=$(tea login list -o tsv </dev/null 2>/dev/null |
            while IFS=$'\t' read -r name url _; do
              if [ "$(url_host "$url" 2>/dev/null)" = "$host" ]; then printf '%s\n' "$name"; break; fi
            done)
          [ -n "$login" ] || return 1
          body=$(tea api --login "$login" "/$q" </dev/null 2>/dev/null) || return 1
          ;;
        gitlab)
          command -v glab >/dev/null || return 1
          body=$(glab api --hostname "$host" "$q" </dev/null 2>/dev/null) || return 1
          ;;
      esac
      ;;
    token | anon)
      command -v curl >/dev/null || return 1
      local header=
      if [ "$method" = token ]; then
        tok=$(forge_token "$forge" "$host") || return 1
        header="$auth $tok"
      fi
      # -H @- reads the header from stdin; an empty stdin adds none.
      body=$(printf '%s' "$header" | curl -fsS --connect-timeout 5 --max-time 20 \
        -H 'Accept: application/json' -H @- "$api/$q" 2>/dev/null) || return 1
      ;;
    *) return 1 ;;
  esac

  # jq accepts empty input and prints nothing, which would read as "no open
  # PRs". An empty body (e.g. a redirect from the wrong forge) is a failure.
  [[ $body == *[![:space:]]* ]] || return 1
  if command -v jq >/dev/null; then
    jq -r "if type == \"array\" then $filter else error(\"not a list\") end" <<<"$body" 2>/dev/null || return 1
  elif command -v python3 >/dev/null; then
    python3 -c '
import json, sys
data = json.load(sys.stdin)
if not isinstance(data, list):
    sys.exit(1)
for pr in data:
    if sys.argv[1] == "gitlab":
        print(pr.get("source_branch") or "")
    else:
        head = pr.get("head") or {}
        print(head.get("ref") or "")
        print((head.get("label") or "").split(":")[-1])
' "$forge" <<<"$body" 2>/dev/null || return 1
  else
    return 1
  fi
}

# Print the head branch of every open PR on the remote, trying every method
# until one works: the forge guessed from the host only orders the attempts
# (a wrong guess costs one failed request), then per forge its CLI, a token
# bound to the host, and anonymous access. Pages until an empty page; 20
# pages without one is a failure, so an API that ignores paging cannot loop
# or truncate silently. Fails if nothing works, so the caller can refuse to
# delete blind.
open_pr_heads() {
  local url host path real forges forge method page names heads complete
  url=$(git remote get-url "$remote") || return 1
  host=$(url_host "$url") || return 1
  case $url in
    *://*) path=${url#*://*/} ;;
    *) path=${url#*:} ;;
  esac
  path=${path%/}
  path=${path%.git}
  path=${path#/}
  [ -n "$path" ] || return 1

  # ssh remotes may name a Host alias; ask ssh for the real host name.
  case $url in
    http://* | https://*) ;;
    *)
      if command -v ssh >/dev/null; then
        real=$(ssh -G "$host" 2>/dev/null | sed -n 's/^hostname //p' | head -n1)
        [ -n "$real" ] && host=$(printf '%s\n' "$real" | tr '[:upper:]' '[:lower:]')
      fi
      ;;
  esac

  case $host in
    github.com) forges=(github) ;;
    gitlab.com) forges=(gitlab) ;;
    *github*) forges=(github gitea gitlab) ;;
    *gitlab*) forges=(gitlab gitea github) ;;
    *) forges=(gitea gitlab github) ;;
  esac

  for forge in "${forges[@]}"; do
    for method in cli token anon; do
      heads=
      complete=0
      for page in $(seq 20); do
        names=$(pr_page "$method" "$forge" "$host" "$path" "$page") || break
        if [ -z "$names" ]; then
          complete=1
          break
        fi
        heads+="$names"$'\n'
      done
      if [ $complete = 1 ]; then
        printf '%s' "$heads"
        return 0
      fi
    done
  done
  return 1
}

# ── Plan: remote branches ────────────────────────────────────────────────────

remote_del=()
open_heads=()
if [ $do_remote = 1 ]; then
  candidates=()
  reasons=()
  while IFS= read -r ref; do
    name=${ref#"refs/remotes/$remote/"}
    [ "$name" = HEAD ] && continue
    is_protected "$name" && continue
    if content_merged "$ref"; then
      candidates+=("$name")
      reasons+=("$merged_reason")
    fi
  done < <(git for-each-ref --format='%(refname)' "refs/remotes/$remote/")

  if [ ${#candidates[@]} -gt 0 ]; then
    if heads=$(open_pr_heads); then
      for i in "${!candidates[@]}"; do
        name=${candidates[$i]}
        if grep -qxF -- "$name" <<<"$heads"; then
          open_heads+=("refs/remotes/$remote/$name")
          echo "  keep    $remote/$name  (head of an open PR)"
        else
          remote_del+=("$name")
          echo "  delete  $remote/$name  (${reasons[$i]})"
        fi
      done
    else
      echo "  Could not list open PRs on '$remote'; skipping remote deletion of:"
      printf '            %s\n' "${candidates[@]/#/$remote/}"
    fi
  fi
fi

# ── Plan: local branches ─────────────────────────────────────────────────────

local_del=()
local_kept_unmerged=()
while IFS=$'\x1f' read -r ref upstream track wtpath; do
  name=${ref#refs/heads/}
  is_protected "$name" && continue
  if [ -n "$upstream" ] && printf '%s\n' "${open_heads[@]+"${open_heads[@]}"}" | grep -qxF -- "$upstream"; then
    echo "  keep    $name  (tracks the head of an open PR)"
    continue
  fi
  if [ -n "$wtpath" ] && [ "$wtpath" != "$toplevel" ]; then
    echo "  keep    $name  (checked out in worktree $wtpath)"
    continue
  fi
  [ -z "$upstream" ] && is_fresh "$name" && continue
  gone=0
  [ "$track" = "[gone]" ] && gone=1
  if content_merged "$ref"; then
    local_del+=("$name")
    [ $gone = 1 ] && merged_reason="$merged_reason, upstream gone"
    echo "  delete  $name  ($merged_reason)"
  elif [ $gone = 1 ]; then
    if [ $force = 1 ]; then
      local_del+=("$name")
      echo "  delete  $name  (upstream gone, UNMERGED commits, --force)"
    else
      local_kept_unmerged+=("$name")
      echo "  keep    $name  (upstream gone but has unmerged commits; use --force)"
    fi
  fi
done < <(git for-each-ref --format='%(refname)%1f%(upstream)%1f%(upstream:track)%1f%(worktreepath)' refs/heads/)

if [ ${#remote_del[@]} -eq 0 ] && [ ${#local_del[@]} -eq 0 ]; then
  echo "Nothing to delete."
fi

if [ $dry_run = 1 ]; then
  echo "Dry run: no changes made."
  exit 0
fi

# ── Execute ──────────────────────────────────────────────────────────────────

# Leave the current branch first if it is going away.
for i in "${!local_del[@]}"; do
  [ "${local_del[$i]}" = "$current" ] || continue
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Keeping current branch '$current': tracked files have uncommitted changes."
    unset 'local_del[i]'
  elif git show-ref --verify --quiet "refs/heads/$default"; then
    git switch --quiet "$default"
    current=$default
  else
    git switch --quiet --track -c "$default" "$base"
    current=$default
  fi
done

# Fast-forward the local default branch. A local fetch with no '+' refuses
# non-fast-forward updates and branches checked out in another worktree.
if [ "$base" != "refs/heads/$default" ] && git show-ref --verify --quiet "refs/heads/$default"; then
  echo "Fast-forwarding '$default'..."
  if [ "$current" = "$default" ]; then
    git merge --ff-only --quiet "$base" || echo "  Could not fast-forward '$default'; left as is."
  else
    git fetch --quiet . "$base:refs/heads/$default" 2>/dev/null ||
      echo "  Could not fast-forward '$default'; left as is."
  fi
fi

failed=0

if [ ${#remote_del[@]} -gt 0 ]; then
  echo "Deleting merged branches on '$remote':"
  printf '  %s\n' "${remote_del[@]}"
  git push --quiet "$remote" --delete "${remote_del[@]}" || failed=1
fi

if [ ${#local_del[@]} -gt 0 ]; then
  echo "Deleting local branches:"
  for name in "${local_del[@]}"; do
    git branch -D "$name" || failed=1
  done
  echo "Restore a deleted local branch with: git branch <name> <sha>"
fi

if [ ${#local_kept_unmerged[@]} -gt 0 ]; then
  echo "Kept ${#local_kept_unmerged[@]} gone branch(es) with unmerged commits; rerun with --force to delete them."
fi

exit $failed
