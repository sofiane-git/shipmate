#!/usr/bin/env bash
# Render a tag template. Usage: render-tag.sh <template> <name> <version>
set -euo pipefail
tmpl="${1:?template (use empty string only for tag:null, which has no tag)}"
name="${2:?name}"; version="${3:?version}"
[ -n "$tmpl" ] || { echo "render-tag: empty template" >&2; exit 1; }
out="${tmpl//\{name\}/$name}"
out="${out//\{version\}/$version}"
echo "$out"
