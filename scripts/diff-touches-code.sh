#!/usr/bin/env bash
# Read changed paths on stdin. Exit 0 if any path is "code"; exit 10 if the change set is
# code-less (only docs/changelog/config/lockfiles/manifests). Exit 2 on empty input.
set -euo pipefail

# Paths considered NON-code (a release touching only these skips security review under auto).
noncode_regex='(^|/)(CHANGELOG\.md|\.shipmate\.json|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|pyproject\.toml|poetry\.lock)$|\.md$|^docs/|^\.github/|^\.claude-plugin/'

any=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  any=1
  if ! [[ "$path" =~ $noncode_regex ]]; then
    exit 0   # found a code path
  fi
done

[ "$any" -eq 1 ] || { echo "diff-touches-code: no input" >&2; exit 2; }
exit 10        # everything was non-code
