#!/usr/bin/env bash
# Read a version literal from a file location.
# Usage: read-version.sh <file> <json|toml|regex> <expr>
#   json  : expr is a jq filter (e.g. .version, .plugins[0].version)
#   toml  : expr is a one-level dotted path (e.g. project.version)
#   regex : expr is a Perl regex with exactly one capture group (group 1 = version)
# Prints the version to stdout; exits non-zero if not found or type unknown.
set -euo pipefail

file="${1:?file required}"
type="${2:?type required}"
expr="${3:?expr required}"

[ -f "$file" ] || { echo "read-version: file not found: $file" >&2; exit 2; }

case "$type" in
  json)
    jq -er "$expr" "$file"
    ;;
  toml)
    awk -v path="$expr" '
      BEGIN { n = split(path, p, "."); table = p[1]; key = p[2]; cur = "" }
      /^[ \t]*\[/ { line = $0; gsub(/[][ \t]/, "", line); cur = line; next }
      {
        line = $0; sub(/[ \t]*#.*/, "", line)
        if (cur == table && line ~ "^[ \t]*" key "[ \t]*=") {
          sub(/^[^=]*=[ \t]*/, "", line)
          gsub(/^["'\'']|["'\'']$/, "", line)
          gsub(/[ \t]+$/, "", line)
          print line; found = 1; exit
        }
      }
      END { if (!found) exit 1 }
    ' "$file"
    ;;
  regex)
    RE="$expr" perl -ne 'if (/$ENV{RE}/) { print $1; $ok = 1; last } END { exit($ok ? 0 : 1) }' "$file"
    ;;
  *)
    echo "read-version: unknown type: $type" >&2
    exit 2
    ;;
esac
