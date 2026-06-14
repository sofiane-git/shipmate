#!/usr/bin/env bash
# Validate .shipmate.json beyond JSON Schema.
# Usage: validate-config.sh [path]   (default ./.shipmate.json)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${1:-./.shipmate.json}"
read_version="$SCRIPT_DIR/read-version.sh"
[ -f "$config" ] || { echo "validate-config: not found: $config" >&2; exit 2; }
cfg_dir="$(cd "$(dirname "$config")" && pwd -P)"

errors=0
err() { echo "validate-config: $*" >&2; errors=1; }

primary="$(jq -r '.primaryContract' "$config")"

# primaryContract must name a contract whose tag != null
ptag="$(jq -r --arg n "$primary" '.contracts[] | select(.name==$n) | .tag // "null"' "$config")"
if [ -z "$ptag" ]; then
  err "primaryContract '$primary' names no contract"
elif [ "$ptag" = "null" ]; then
  err "primaryContract '$primary' must be a tagged contract (tag != null)"
fi

# collect rendered tags for uniqueness (portable: newline list, no associative arrays);
# validate regex groups + readability
seen_tags=""
count="$(jq '.contracts | length' "$config")"
for ((i = 0; i < count; i++)); do
  name="$(jq -r ".contracts[$i].name" "$config")"
  tag="$(jq -r ".contracts[$i].tag // \"null\"" "$config")"
  if [ "$tag" != "null" ]; then
    rendered="${tag//\{name\}/$name}"; rendered="${rendered//\{version\}/0.0.0}"
    if printf '%s\n' "$seen_tags" | grep -qxF "$rendered"; then
      err "two tagged contracts render the same tag '$rendered'"
    else
      seen_tags="$seen_tags"$'\n'"$rendered"
    fi
  fi

  lcount="$(jq ".contracts[$i].locations | length" "$config")"
  for ((j = 0; j < lcount; j++)); do
    file="$(jq -r ".contracts[$i].locations[$j].file" "$config")"

    # path containment: repo-relative only, no '..', no symlink escape outside repo root
    case "$file" in
      /*)   err "contract '$name': location '$file' must be repo-relative (no absolute path)"; continue ;;
      *..*) err "contract '$name': location '$file' must not contain '..'"; continue ;;
    esac
    if [ -e "$cfg_dir/$file" ]; then
      real="$(perl -MCwd=realpath -e 'print realpath($ARGV[0])' "$cfg_dir/$file" 2>/dev/null || true)"
      case "$real/" in
        "$cfg_dir/"*) : ;;
        *) err "contract '$name': location '$file' resolves outside the repo root" ;;
      esac
    fi

    re="$(jq -r ".contracts[$i].locations[$j].regex // empty" "$config")"
    if [ -n "$re" ]; then
      groups="$(RE="$re" perl -e '$n = () = $ENV{RE} =~ /\((?!\?)/g; print $n')"
      if [ "$groups" -ne 1 ]; then
        err "contract '$name' location '$file': regex must have exactly one capture group (found $groups)"
      fi
    fi
    # readability
    obj="$(jq -c ".contracts[$i].locations[$j]" "$config")"
    if   e="$(jq -er '.json'  <<<"$obj" 2>/dev/null)"; then t=json
    elif e="$(jq -er '.toml'  <<<"$obj" 2>/dev/null)"; then t=toml
    else e="$(jq -er '.regex' <<<"$obj")"; t=regex
    fi
    if ! "$read_version" "$cfg_dir/$file" "$t" "$e" >/dev/null 2>&1; then
      err "contract '$name': location '$file' is not currently readable"
    fi
  done
done

[ "$errors" -eq 0 ] || exit 1
echo "validate-config: OK"
