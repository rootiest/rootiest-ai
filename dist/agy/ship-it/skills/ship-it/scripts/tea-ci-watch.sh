#!/usr/bin/env bash
#
# Copyright (c) 2026 Christopher Robert Laprade (Rootiest)
# Licensed under the MIT License.
#

set -euo pipefail

show_help() {
  cat <<'EOF'
NAME
    tea-ci-watch - Block execution until Gitea Actions/commit checks complete

SYNOPSIS
    tea-ci-watch [OPTIONS] <owner/repo> <commit-sha> [timeout_seconds]

DESCRIPTION
    Polls Gitea (via 'tea api') and blocks until every check on the commit has
    finished. Designed for automated CI pipelines and agent workflows: run it
    once, in the background, and act on the exit code instead of sleep-polling.

    Two sources are combined. Gitea posts an Actions job's commit status only
    once a runner picks the job up, so queued workflows are invisible to the
    combined status; the Actions runs API lists them from the moment they are
    triggered. The commit is done only when every Actions run for it has
    completed AND the combined status (which also covers external CI) is no
    longer pending. The first failure in either source fails fast.

    The combined status reports the latest state of each check, so earlier
    'pending' entries for re-run jobs do not affect the result. Skipped jobs
    count as passing.

ARGUMENTS
    <owner/repo>        Target repository path (e.g. rootiest/ship-it)
    <commit-sha>        Commit SHA to observe
    [timeout_seconds]   Maximum wait duration in seconds (default: 1200)

OPTIONS
    -h, --help          Display this help documentation and exit

ENVIRONMENT VARIABLES
    TEA_CI_WATCH_GRACE  Seconds to wait for any check to register before
                        concluding the commit has no CI (default: 60)

AUTHENTICATION
    Uses the default 'tea' login. Run 'tea login add' if none is configured.

RETURNS
    0                   All checks passed (success, warning, or skipped)
    1                   One or more checks failed or were cancelled; failing
                        checks are printed
    2                   Usage, dependency, or API error (bad repo, auth, network)
    3                   No checks registered within the grace period
    124                 Timeout reached with checks still pending

EXAMPLES
    tea-ci-watch rootiest/rootiest-ai a1b2c3d4e5f6
    tea-ci-watch rootiest/rootiest-ai "$(git rev-parse HEAD)" 300
EOF
}

# Parse help flag before positional parameters
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
  show_help
  exit 0
fi

# Validate positional inputs
if [ "$#" -lt 2 ]; then
  echo "Error: Missing required arguments." >&2
  echo "Run 'tea-ci-watch --help' for usage." >&2
  exit 2
fi

# Ensure required runtime dependencies exist in PATH
for bin in jq tea; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: Required binary '$bin' is not installed or not in PATH." >&2
    exit 2
  fi
done

REPO="$1"
SHA="$2"
TIMEOUT="${3:-1200}"
GRACE="${TEA_CI_WATCH_GRACE:-60}"
INTERVAL=5

echo "Waiting for CI completion on ${REPO}@${SHA:0:7}..." >&2

# Fetch a Gitea API path as JSON. 'tea api' exits 0 even on HTTP errors, so the
# caller-supplied jq probe (which must succeed on a valid body) is the error signal.
fetch() {
  local path="$1" probe="$2" body
  if ! body=$(tea api "$path" 2>&1) || ! jq -e "$probe" <<<"$body" >/dev/null 2>&1; then
    echo "ERROR: Request ${path} failed for ${REPO}@${SHA:0:7}: ${body}" >&2
    exit 2
  fi
  printf '%s' "$body"
}

while ((SECONDS < TIMEOUT)); do
  STATUS=$(fetch "/repos/${REPO}/commits/${SHA}/status" '.state | strings') || exit 2
  RUNS=$(fetch "/repos/${REPO}/actions/runs?head_sha=${SHA}&limit=50" '.workflow_runs | arrays') || exit 2

  STATE=$(jq -r '.state' <<<"$STATUS")
  COUNT=$(jq -r '.total_count' <<<"$STATUS")
  RUN_COUNT=$(jq -r '.workflow_runs | length' <<<"$RUNS")
  RUNS_PENDING=$(jq -r '[.workflow_runs[] | select(.status != "completed")] | length' <<<"$RUNS")
  RUNS_FAILED=$(jq -r '[.workflow_runs[] | select(.status == "completed"
      and (.conclusion == "failure" or .conclusion == "cancelled"))] | length' <<<"$RUNS")

  if [[ "$STATE" == failure || "$STATE" == error ]] || ((RUNS_FAILED > 0)); then
    echo "ERROR: One or more checks failed for ${SHA:0:7}:" >&2
    jq -r '.statuses[] | select(.status == "failure" or .status == "error")
      | "  \(.context): \(.description) (\(.target_url))"' <<<"$STATUS" >&2
    jq -r '.workflow_runs[] | select(.status == "completed"
        and (.conclusion == "failure" or .conclusion == "cancelled"))
      | "  \(.path) [\(.event)]: \(.conclusion) (\(.html_url))"' <<<"$RUNS" >&2
    exit 1
  fi

  # Done only when no run is queued/running and every posted status is terminal.
  # Zero statuses with completed runs means every job was skipped (no status posted).
  if ((RUNS_PENDING == 0)) && { [[ "$STATE" == success || "$STATE" == warning ]] ||
    ((COUNT == 0 && RUN_COUNT > 0)); }; then
    echo "SUCCESS: All ${RUN_COUNT} workflow runs and ${COUNT} checks passed for ${SHA:0:7}." >&2
    exit 0
  fi

  # A commit with no workflows reports "pending" with zero checks forever
  if ((COUNT == 0 && RUN_COUNT == 0 && SECONDS >= GRACE)); then
    echo "NO CI: No checks registered for ${SHA:0:7} after ${GRACE}s." >&2
    exit 3
  fi

  sleep "$INTERVAL"
done

echo "ERROR: Timeout reached (${TIMEOUT}s) waiting for CI on ${SHA:0:7}." >&2
exit 124
