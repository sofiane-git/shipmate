#!/usr/bin/env bash
# Fail if a tag already exists on the remote (never re-point a published tag).
# Usage: check-tag-unpushed.sh <remote> <tag>
set -euo pipefail

remote="${1:?remote required}"
tag="${2:?tag required}"

if git ls-remote --tags --exit-code "$remote" "refs/tags/$tag" >/dev/null 2>&1; then
  echo "check-tag-unpushed: tag '$tag' already exists on '$remote' — refusing to re-point a published tag" >&2
  exit 1
fi
echo "check-tag-unpushed: '$tag' not yet on '$remote'"
