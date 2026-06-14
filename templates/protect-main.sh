#!/usr/bin/env bash
# shipmate-scaffolded local guard: deny direct commit/push on the protected branch.
# Convenience only (bypassable with --no-verify); the real barrier is GitHub branch protection.
set -euo pipefail
protected="{{BRANCH}}"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ "$branch" = "$protected" ]; then
  echo "Blocked: commit on '$protected' directly. Branch + PR required." >&2
  exit 1
fi
