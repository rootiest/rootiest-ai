---
name: mirror-it
description: Configures a Gitea repository to automatically push-mirror its contents to GitHub using the `tea` CLI and `jq`.
version: 1.1.0
user-invocable: true
author: Rootiest
---

# Gitea to GitHub Push Mirror

## Objective
Register a Gitea push mirror so a repository's commits are automatically forwarded to a
corresponding GitHub repository, via `tea api` against Gitea's `push_mirrors` endpoint.

## Trigger Conditions
Activate this skill ONLY when one of the following is met:
1. The user explicitly types the command `/mirror-it`.
2. The user makes a natural-language request to mirror the repository (e.g., "Mirror this
   repository to GitHub", "Mirror this example-config repo...").
3. You confidently infer the user intends to mirror the current repository, AND have
   verified that a GitHub repository does not already exist at the target address.

## Constraints & Relevance
- **Gitea only**: this skill is relevant ONLY for repositories hosted on a Gitea instance
  (e.g., `git.rootiest.dev`). Do NOT trigger it for repositories natively hosted on GitHub —
  GitHub does not support push-mirroring to itself.
- **Security**: never read, print, or otherwise expose the value of `$GITHUB_TOKEN` (whether it
  comes from the environment or a `.env` file — see Prerequisites). Pass the variable reference
  directly into shell commands so it is only ever expanded by the shell, never written out by you.
- **Shell environment**: the snippet below is POSIX-compatible (`var=$(command)`), since the
  command executes through whatever shell the tool invokes it with (bash/zsh/sh) — never assume
  Fish syntax is available. An exported variable (`set -gx` in Fish, `export` in bash/zsh) is
  inherited by every child process regardless of which shell that child happens to run, so
  variables from the user's interactive shell config are already present without any special
  handling.

## Prerequisites
- `tea` is installed and already authenticated against the target Gitea instance (`tea login list`).
- `jq` is installed.
- `$GITHUB_USER` and `$GITHUB_TOKEN` (a GitHub PAT with `repo` scope) are available before step 3
  below — either already exported in the environment, or defined in a `.env` file at the
  repository root (see step 1).
- Optionally, one of the following for the target-repo check/creation in step 4: the `gh` CLI
  (authenticated — `gh auth status`), a GitHub MCP server, or plain `$GITHUB_TOKEN` used directly
  against the GitHub REST API via `curl`. The first of these that's available is used; if none
  are, step 4 degrades to a warning instead of blocking the skill.

## Defaults & Overrides
Unless the user says otherwise, assume:
- **Target name (`$TARGET_REPO`)**: the exact name of the current Gitea repository.
- **Interval (`$INTERVAL`)**: `"8h"`.
- **Sync on commit (`$SYNC_ON_COMMIT`)**: `true`.

*Example override:* "Mirror this example-config repo, but don't sync on commit and use the
name 'exmpl_cfg'" → `$TARGET_REPO` becomes `exmpl_cfg`, `$SYNC_ON_COMMIT` becomes `false`.

## Execution Steps

1. If `$GITHUB_USER` or `$GITHUB_TOKEN` is not already set, and a `.env` file exists at the
   repository root, load it before doing anything else — without ever printing or `cat`-ing its
   contents:
   ```sh
   set -a; . ./.env; set +a
   ```
   Variables already present in the environment take priority: only fall back to `.env` for
   whichever of the two is still unset. If neither source provides both, stop and tell the user
   what's missing.
2. Identify the current Gitea repository's owner (`$OWNER`) and name (`$SOURCE_REPO`).
3. Determine `$TARGET_REPO`, `$INTERVAL`, and `$SYNC_ON_COMMIT` from the defaults above,
   applying any user overrides.
4. **Ensure the GitHub target repository exists.** GitHub, unlike Gitea, does not create a
   repository on first push — if `$GITHUB_USER/$TARGET_REPO` doesn't exist yet, the mirror will
   register successfully but every sync attempt will fail. Check for the repo and create it if
   missing, using whichever of these is available (in order of preference):

   - **`gh` CLI** (preferred if authenticated — `gh auth status`):
     ```sh
     if ! gh repo view "$GITHUB_USER/$TARGET_REPO" >/dev/null 2>&1; then
       gh repo create "$GITHUB_USER/$TARGET_REPO" --private --description "Push mirror of $OWNER/$SOURCE_REPO"
     fi
     ```
     Match visibility to the source repo where you can determine it (e.g. via `tea api
     "repos/$OWNER/$SOURCE_REPO"` → `.private`); otherwise default to `--private` and mention the
     choice when reporting the outcome.
   - **GitHub MCP server**, if one is connected: use its repo-lookup tool to check for
     `$GITHUB_USER/$TARGET_REPO`, and its repo-creation tool to create it (private by default) if
     absent.
   - **Plain REST API via `curl`**, using `$GITHUB_TOKEN` directly, if neither of the above is
     available:
     ```sh
     status=$(curl -s -o /dev/null -w '%{http_code}' \
       -H "Authorization: Bearer $GITHUB_TOKEN" \
       "https://api.github.com/repos/$GITHUB_USER/$TARGET_REPO")
     if [ "$status" = "404" ]; then
       curl -s -X POST \
         -H "Authorization: Bearer $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github+json" \
         https://api.github.com/user/repos \
         -d "$(jq -n --arg name "$TARGET_REPO" '{name: $name, private: true}')" \
         >/dev/null
     fi
     ```
   - **If none of these are available**, don't block on it — proceed to step 5, but warn the user
     clearly that they must create `$GITHUB_USER/$TARGET_REPO` on GitHub themselves before the
     mirror's first sync will succeed.

   If a repo already exists at the target address, leave it as-is and continue — do not treat this
   as an error.

5. Run the following snippet, substituting the values from steps 2–3. Credentials are passed as
   separate `remote_username`/`remote_password` fields — never embedded in the mirror URL — per
   Gitea's `CreatePushMirrorOption` schema.

```sh
# $OWNER / $SOURCE_REPO identify the local Gitea API endpoint.
# $TARGET_REPO is the destination repository name on GitHub.
# $INTERVAL and $SYNC_ON_COMMIT come from the Defaults & Overrides step above.

payload=$(jq -n \
  --arg addr "https://github.com/$GITHUB_USER/$TARGET_REPO.git" \
  --arg user "$GITHUB_USER" \
  --arg pass "$GITHUB_TOKEN" \
  --arg interval "$INTERVAL" \
  --argjson sync $SYNC_ON_COMMIT \
  '{remote_address: $addr, remote_username: $user, remote_password: $pass, interval: $interval, sync_on_commit: $sync}'
)

tea api --method POST --data "$payload" "repos/$OWNER/$SOURCE_REPO/push_mirrors"
```

6. Report the outcome to the user, without echoing the request body, `.env` contents, or token —
   including whether the GitHub repo already existed or was just created, and, if step 4 had no
   capability to check/create it, a reminder that they need to create it manually.
