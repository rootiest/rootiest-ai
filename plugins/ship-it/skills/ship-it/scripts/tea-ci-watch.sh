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
    Polls the Gitea combined commit status API (via 'tea api') and blocks until
    every check on the commit has finished. Designed for automated CI pipelines
    and agent workflows: run it once, in the background, and act on the exit
    code instead of sleep-polling.

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
    1                   One or more checks failed; failing jobs are printed
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

while ((SECONDS < TIMEOUT)); do
  # 'tea api' exits 0 even on HTTP errors, so a missing .state is the error signal
  if ! RESPONSE=$(tea api "/repos/${REPO}/commits/${SHA}/status" 2>&1) ||
    ! STATE=$(jq -er '.state' <<<"$RESPONSE" 2>/dev/null); then
    echo "ERROR: Status request failed for ${REPO}@${SHA:0:7}: ${RESPONSE}" >&2
    exit 2
  fi
  COUNT=$(jq -r '.total_count' <<<"$RESPONSE")

  case "$STATE" in
  success | warning)
    echo "SUCCESS: All ${COUNT} checks passed for ${SHA:0:7}." >&2
    exit 0
    ;;
  failure | error)
    echo "ERROR: One or more checks failed for ${SHA:0:7}:" >&2
    jq -r '.statuses[] | select(.status == "failure" or .status == "error")
      | "  \(.context): \(.description) (\(.target_url))"' <<<"$RESPONSE" >&2
    exit 1
    ;;
  esac

  # A commit with no workflows reports "pending" with zero checks forever
  if ((COUNT == 0 && SECONDS >= GRACE)); then
    echo "NO CI: No checks registered for ${SHA:0:7} after ${GRACE}s." >&2
    exit 3
  fi

  sleep "$INTERVAL"
done

echo "ERROR: Timeout reached (${TIMEOUT}s) waiting for CI on ${SHA:0:7}." >&2
exit 124
