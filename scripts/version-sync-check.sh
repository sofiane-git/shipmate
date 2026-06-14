#!/usr/bin/env bash
# Assert that every location of each contract currently holds the same version.
# Usage: version-sync-check.sh [path-to-.shipmate.json]   (default ./.shipmate.json)
# Exit 0 if all contracts are internally consistent; exit 1 + report on drift.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${1:-./.shipmate.json}"
[ -f "$config" ] || { echo "version-sync-check: config not found: $config" >&2; exit 2; }

read_loc() {
  # args: file, then the location object as compact json
  local file="$1" obj="$2" type expr
  if   expr="$(jq -er '.json'  <<<"$obj" 2>/dev/null)"; then type=json
  elif expr="$(jq -er '.toml'  <<<"$obj" 2>/dev/null)"; then type=toml
  elif expr="$(jq -er '.regex' <<<"$obj" 2>/dev/null)"; then type=regex
  else echo "version-sync-check: location has no json/toml/regex: $obj" >&2; return 2
  fi
  "$SCRIPT_DIR/read-version.sh" "$file" "$type" "$expr"
}

drift=0
contract_count="$(jq '.contracts | length' "$config")"
for ((i = 0; i < contract_count; i++)); do
  name="$(jq -r ".contracts[$i].name" "$config")"
  loc_count="$(jq ".contracts[$i].locations | length" "$config")"
  first=""
  for ((j = 0; j < loc_count; j++)); do
    file="$(jq -r ".contracts[$i].locations[$j].file" "$config")"
    obj="$(jq -c ".contracts[$i].locations[$j]" "$config")"
    ver="$(read_loc "$file" "$obj")"
    if [ -z "$first" ]; then
      first="$ver"
    elif [ "$ver" != "$first" ]; then
      echo "DRIFT in contract '$name': $file has '$ver', expected '$first'" >&2
      drift=1
    fi
  done
done

if [ "$drift" -ne 0 ]; then
  echo "version-sync-check: contracts have drifted" >&2
  exit 1
fi
echo "version-sync-check: all contracts consistent"
