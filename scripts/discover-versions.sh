#!/usr/bin/env bash
# Scan a repo for candidate version locations. Prints a JSON array:
#   [{ "file": "...", "type": "json|toml|regex", "expr": "...", "version": "..." }]
# Usage: discover-versions.sh [repo-root]   (default .)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${1:-.}"
read_version="$SCRIPT_DIR/read-version.sh"

# candidate (relative-file, type, expr) tuples for structured files
candidates=(
  "package.json|json|.version"
  "pyproject.toml|toml|project.version"
  ".claude-plugin/plugin.json|json|.version"
  ".claude-plugin/marketplace.json|json|.plugins[0].version"
)

emit() { # file type expr version
  jq -nc --arg f "$1" --arg t "$2" --arg e "$3" --arg v "$4" \
    '{file:$f, type:$t, expr:$e, version:$v}'
}

results=()
for c in "${candidates[@]}"; do
  IFS='|' read -r file type expr <<<"$c"
  if [ -f "$root/$file" ]; then
    if ver="$("$read_version" "$root/$file" "$type" "$expr" 2>/dev/null)"; then
      results+=("$(emit "$file" "$type" "$expr" "$ver")")
    fi
  fi
done

# prose markers: `currently `X.Y.Z`` in any tracked .md under the root
# shellcheck disable=SC2016  # backticks are literal here (a Perl regex, not a shell expansion)
prose_re='currently `([0-9]+\.[0-9]+\.[0-9]+)`'
while IFS= read -r md; do
  rel="${md#"$root"/}"
  if ver="$("$read_version" "$md" regex "$prose_re" 2>/dev/null)"; then
    results+=("$(emit "$rel" "regex" "$prose_re" "$ver")")
  fi
done < <(find "$root" -name '*.md' -not -path '*/node_modules/*' 2>/dev/null)

if [ "${#results[@]}" -eq 0 ]; then
  echo "[]"
else
  printf '%s\n' "${results[@]}" | jq -s '.'
fi
