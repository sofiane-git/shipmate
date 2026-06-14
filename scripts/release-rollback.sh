#!/usr/bin/env bash
# Idempotent release cleanup ops.
#   release-rollback.sh tag <name>      # delete local tag if present
#   release-rollback.sh branch <name>   # delete local branch if present
#   release-rollback.sh restore <file>  # restore file from HEAD
set -euo pipefail

op="${1:?tag|branch|restore}"; arg="${2:?argument}"
case "$op" in
  tag)     git tag -d "$arg" >/dev/null 2>&1 || true ;;
  branch)  git branch -D "$arg" >/dev/null 2>&1 || true ;;
  restore) git checkout -- "$arg" ;;
  *) echo "release-rollback: unknown op: $op" >&2; exit 2 ;;
esac
echo "release-rollback: $op $arg done"
