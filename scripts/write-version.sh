#!/usr/bin/env bash
# Write a new version into a location (in place).
# Usage: write-version.sh <file> <json|toml|regex> <expr> <new-version>
set -euo pipefail

file="${1:?file}"; type="${2:?type}"; expr="${3:?expr}"; new="${4:?new version}"
[ -f "$file" ] || { echo "write-version: file not found: $file" >&2; exit 2; }

case "$type" in
  json)
    tmp="$(mktemp)"
    jq --arg v "$new" "$expr = \$v" "$file" > "$tmp"
    mv "$tmp" "$file"
    ;;
  toml)
    table="${expr%%.*}"; key="${expr#*.}"
    tmp="$(mktemp)"
    awk -v table="$table" -v key="$key" -v val="$new" '
      /^[ \t]*\[/ { line=$0; gsub(/[][ \t]/,"",line); cur=line; print; next }
      {
        if (cur==table && $0 ~ "^[ \t]*" key "[ \t]*=") {
          match($0, /^[ \t]*[^=]*=[ \t]*/)
          print substr($0,1,RLENGTH) "\"" val "\""
          next
        }
        print
      }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    ;;
  regex)
    RE="$expr" NEW="$new" perl -i -pe 'if (/$ENV{RE}/) { substr($_, $-[1], $+[1]-$-[1], $ENV{NEW}); }' "$file"
    ;;
  *)
    echo "write-version: unknown type: $type" >&2; exit 2 ;;
esac
