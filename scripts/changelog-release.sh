#!/usr/bin/env bash
# Changelog release operations.
#   changelog-release.sh restructure <file> <version> <date>
#   changelog-release.sh extract     <file> <version>
set -euo pipefail

cmd="${1:?restructure|extract}"; file="${2:?file}"
[ -f "$file" ] || { echo "changelog-release: not found: $file" >&2; exit 2; }

case "$cmd" in
  restructure)
    version="${3:?version}"; date="${4:?date}"
    tmp="$(mktemp)"
    awk -v ver="$version" -v date="$date" '
      !done && /^## \[Unreleased\]/ {
        print "## [Unreleased]"
        print ""
        print "## [" ver "] — " date
        done=1
        next
      }
      { print }
    ' "$file" > "$tmp"
    grep -q "^## \[$version\] — $date" "$tmp" || { echo "changelog-release: no [Unreleased] heading found" >&2; rm -f "$tmp"; exit 1; }
    mv "$tmp" "$file"
    ;;
  extract)
    version="${3:?version}"
    # print the section body, trimming leading/trailing blank lines (portable, no BSD-sed)
    awk -v ver="$version" '
      $0 ~ "^## \\[" ver "\\]" { grab=1; next }
      grab && /^## \[/ { stop=1 }
      grab && !stop { buf[n++]=$0 }
      END {
        s=0;   while (s<n   && buf[s] ~ /^[ \t]*$/) s++
        e=n-1; while (e>=s  && buf[e] ~ /^[ \t]*$/) e--
        for (i=s; i<=e; i++) print buf[i]
      }
    ' "$file"
    ;;
  *)
    echo "changelog-release: unknown subcommand: $cmd" >&2; exit 2 ;;
esac
