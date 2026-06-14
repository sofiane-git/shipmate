#!/usr/bin/env bash
# Assert the configured remote exists and is reachable.
# Usage: verify-remote.sh <remote>
set -euo pipefail

remote="${1:?remote required}"

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  echo "verify-remote: no such remote '$remote'" >&2
  exit 1
fi
if ! git ls-remote "$remote" >/dev/null 2>&1; then
  echo "verify-remote: remote '$remote' is not reachable" >&2
  exit 1
fi
echo "verify-remote: '$remote' exists and is reachable"
