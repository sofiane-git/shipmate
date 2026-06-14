#!/usr/bin/env bash
# Release preconditions: clean tree, not behind upstream, gh authed, remote reachable.
# Usage: check-preconditions.sh <remote>
# Set SHIPMATE_SKIP_GH_CHECK=1 to skip the `gh auth` probe (tests only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote="${1:?remote required}"

# 1) clean working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "check-preconditions: working tree is not clean" >&2
  exit 1
fi

# 2) remote reachable (reuse verify-remote)
"$SCRIPT_DIR/verify-remote.sh" "$remote" >/dev/null

# 3) not behind upstream (if an upstream is configured)
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  git fetch -q "$remote" || true
  behind="$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
  if [ "$behind" -gt 0 ]; then
    echo "check-preconditions: branch is $behind commit(s) behind $upstream" >&2
    exit 1
  fi
fi

# 4) gh authenticated
if [ "${SHIPMATE_SKIP_GH_CHECK:-0}" != "1" ]; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "check-preconditions: gh is not authenticated (run: gh auth login)" >&2
    exit 1
  fi
fi

echo "check-preconditions: OK"
