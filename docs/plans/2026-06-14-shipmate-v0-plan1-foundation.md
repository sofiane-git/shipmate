# shipmate v0 — Plan 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the tested, CI-green deterministic foundation of shipmate — the plugin scaffold, the `.shipmate.json` JSON Schema, and the five guard scripts that `release` will later orchestrate — with bats unit tests and a green CI, before any skill exists.

**Architecture:** Plain Bash scripts (`set -euo pipefail`), each one job, each unit-tested with `bats`. A shared `read-version.sh` reads a version literal from a JSON (`jq`), TOML (awk), or prose (`perl` regex) location; the guard scripts build on it. No Node runtime dependency beyond `jq`/`ajv` for schema validation and `bats` for tests. This is Plan 1 of 4 (Foundation → init → release → verify+docs+dogfood); see `docs/specs/2026-06-14-shipmate-design.md`.

**Tech Stack:** Bash, jq, perl, awk (guard scripts); ajv-cli (schema validation); bats-core (tests); GitHub Actions + shellcheck (CI).

---

## File Structure

| File | Responsibility |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest (name `shipmate`, version) |
| `.claude-plugin/marketplace.json` | Marketplace entry |
| `package.json` | Metadata + `validate:schema` script (ajv) |
| `LICENSE` | MIT |
| `.gitignore` | Node/OS noise |
| `CHANGELOG.md` | Keep-a-Changelog skeleton (`[Unreleased]`) |
| `schemas/shipmate-config.schema.json` | Validates `.shipmate.json` (draft 2020-12) |
| `examples/config-valid.json` | A valid config fixture (schema + script tests) |
| `scripts/read-version.sh` | Read a version literal from a json/toml/regex location |
| `scripts/version-sync-check.sh` | Assert all locations of each contract agree |
| `scripts/check-tag-unpushed.sh` | Fail if a tag already exists on the remote |
| `scripts/verify-remote.sh` | Assert the configured remote exists and is reachable |
| `scripts/check-preconditions.sh` | Clean tree + up-to-date + gh auth + remote reachable |
| `scripts/scan-secrets.sh` | Fail if text contains secret-shaped strings |
| `hooks/pre-commit` | Native bash dev hook (shellcheck + ajv + frontmatter) |
| `setup-dev.sh` | Wire `core.hooksPath hooks` |
| `tests/*.bats` | One bats file per script |
| `.github/workflows/ci.yml` | shellcheck + schema validate + bats |

**Implementation notes locked here (deviations from spec prose, intentional):**
- `locations[].json` holds a **`jq` filter** (e.g. `.version`, `.plugins[0].version`), not a `$.`-JSONPath string. Reconciled in the schema + example below; the spec's `$.version` was illustrative.
- `locations[].toml` holds a `table.key` dotted path (one level deep, e.g. `project.version`).
- `locations[].regex` is a Perl regex with **exactly one capture group**; group 1 is the version.

---

## Task 1: Repo scaffold (manifests, license, changelog)

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `package.json`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Create the plugin manifest**

`.claude-plugin/plugin.json`:
```json
{
  "name": "shipmate",
  "description": "Cut software releases from Claude Code: curated changelog, nuanced SemVer, multi-version (multi-contract) repos. Local-first, no Conventional Commits required.",
  "version": "0.0.0",
  "author": { "name": "Sofiane Conan" },
  "homepage": "https://github.com/sofiane-git/shipmate",
  "repository": "https://github.com/sofiane-git/shipmate",
  "license": "MIT",
  "keywords": ["claude-code", "release-automation", "changelog", "semver", "versioning"]
}
```

- [ ] **Step 2: Create the marketplace entry**

`.claude-plugin/marketplace.json`:
```json
{
  "name": "shipmate",
  "description": "Marketplace for the shipmate release plugin.",
  "owner": { "name": "Sofiane Conan" },
  "plugins": [
    {
      "name": "shipmate",
      "source": "./",
      "description": "Cut software releases from Claude Code: curated changelog, nuanced SemVer, multi-version repos. Local-first, no Conventional Commits required.",
      "version": "0.0.0",
      "author": { "name": "Sofiane Conan" },
      "homepage": "https://github.com/sofiane-git/shipmate",
      "license": "MIT",
      "keywords": ["claude-code", "release-automation", "changelog", "semver"],
      "category": "developer-tools"
    }
  ]
}
```

- [ ] **Step 3: Create `package.json`**

```json
{
  "name": "shipmate",
  "version": "0.0.0",
  "description": "Cut software releases from Claude Code: curated changelog, nuanced SemVer, multi-version repos. Local-first, no Conventional Commits required.",
  "license": "MIT",
  "repository": { "type": "git", "url": "https://github.com/sofiane-git/shipmate.git" },
  "scripts": {
    "validate:schema": "npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json",
    "test": "bats tests"
  },
  "keywords": ["claude-code", "claude-plugin", "release-automation", "changelog", "semver", "versioning"],
  "engines": { "node": ">=18" }
}
```

- [ ] **Step 4: Create `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 Sofiane Conan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Create `.gitignore`**

```
node_modules/
*.log
.DS_Store
```

- [ ] **Step 6: Create `CHANGELOG.md` skeleton**

```markdown
# Changelog

All notable changes to this project will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Foundation: plugin scaffold, `.shipmate.json` schema, deterministic guard scripts, bats tests, CI.
```

- [ ] **Step 7: Verify the JSON files parse**

Run: `jq empty .claude-plugin/plugin.json .claude-plugin/marketplace.json package.json && echo OK`
Expected: `OK`

- [ ] **Step 8: Commit**

```bash
git add .claude-plugin package.json LICENSE .gitignore CHANGELOG.md
git commit -m "chore: scaffold shipmate plugin (manifests, license, changelog)"
```

---

## Task 2: Config JSON Schema + valid fixture

**Files:**
- Create: `schemas/shipmate-config.schema.json`
- Create: `examples/config-valid.json`

- [ ] **Step 1: Write the valid config fixture**

`examples/config-valid.json`:
```json
{
  "$schema": "https://raw.githubusercontent.com/sofiane-git/shipmate/main/schemas/shipmate-config.schema.json",
  "remote": "origin",
  "protectedBranch": "main",
  "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [
    {
      "name": "kit",
      "tag": "v{version}",
      "bumpFrom": "changelog",
      "locations": [
        { "file": "package.json", "json": ".version" }
      ]
    },
    {
      "name": "schema",
      "tag": null,
      "bumpFrom": "manual",
      "locations": [
        { "file": "schemas/x.schema.json", "json": ".properties.schemaVersion.const" }
      ]
    }
  ]
}
```

- [ ] **Step 2: Write the schema**

`schemas/shipmate-config.schema.json`:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://raw.githubusercontent.com/sofiane-git/shipmate/main/schemas/shipmate-config.schema.json",
  "title": "shipmate config",
  "type": "object",
  "required": ["remote", "protectedBranch", "primaryContract", "contracts"],
  "additionalProperties": false,
  "properties": {
    "$schema": { "type": "string" },
    "remote": { "type": "string", "minLength": 1 },
    "protectedBranch": { "type": "string", "minLength": 1 },
    "primaryContract": { "type": "string", "minLength": 1 },
    "securityReview": { "enum": ["auto", "always", "off"], "default": "auto" },
    "contracts": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["name", "tag", "bumpFrom", "locations"],
        "additionalProperties": false,
        "properties": {
          "name": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
          "tag": { "type": ["string", "null"] },
          "bumpFrom": { "enum": ["changelog", "manual"] },
          "locations": {
            "type": "array",
            "minItems": 1,
            "items": {
              "type": "object",
              "required": ["file"],
              "additionalProperties": false,
              "properties": {
                "file": { "type": "string", "minLength": 1 },
                "json": { "type": "string", "minLength": 1 },
                "toml": { "type": "string", "minLength": 1 },
                "regex": { "type": "string", "minLength": 1 }
              },
              "oneOf": [
                { "required": ["json"] },
                { "required": ["toml"] },
                { "required": ["regex"] }
              ]
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 3: Validate the fixture against the schema (must PASS)**

Run: `npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json`
Expected: `examples/config-valid.json valid`

- [ ] **Step 4: Negative check — a malformed config must FAIL**

Run:
```bash
echo '{"remote":"origin"}' > /tmp/bad.json
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d /tmp/bad.json; echo "exit=$?"
```
Expected: invalid (missing `protectedBranch`/`primaryContract`/`contracts`), `exit=1`

- [ ] **Step 5: Commit**

```bash
git add schemas/shipmate-config.schema.json examples/config-valid.json
git commit -m "feat: add .shipmate.json schema + valid fixture"
```

---

## Task 3: `read-version.sh` (json/toml/regex reader)

**Files:**
- Create: `scripts/read-version.sh`
- Test: `tests/read-version.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/read-version.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/read-version.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "reads json version via jq filter" {
  echo '{"version":"1.2.3"}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP/package.json" json ".version"
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "reads nested json via jq filter" {
  echo '{"plugins":[{"version":"2.0.0"}]}' > "$TMP/m.json"
  run "$SCRIPT" "$TMP/m.json" json ".plugins[0].version"
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "reads toml table.key" {
  printf '[project]\nname = "x"\nversion = "3.4.5"\n' > "$TMP/pyproject.toml"
  run "$SCRIPT" "$TMP/pyproject.toml" toml "project.version"
  [ "$status" -eq 0 ]
  [ "$output" = "3.4.5" ]
}

@test "reads regex capture group 1" {
  printf 'pinned to (currently `9.9.9` here)\n' > "$TMP/install.md"
  run "$SCRIPT" "$TMP/install.md" regex 'currently `([0-9]+\.[0-9]+\.[0-9]+)`'
  [ "$status" -eq 0 ]
  [ "$output" = "9.9.9" ]
}

@test "exits non-zero when json path missing" {
  echo '{}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP/package.json" json ".version"
  [ "$status" -ne 0 ]
}

@test "exits non-zero on unknown type" {
  run "$SCRIPT" "$TMP/whatever" yaml ".x"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/read-version.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/read-version.sh`**

```bash
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
```

- [ ] **Step 4: Make executable and run the test to verify it passes**

Run: `chmod +x scripts/read-version.sh && bats tests/read-version.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck the script**

Run: `shellcheck scripts/read-version.sh`
Expected: no output (clean)

- [ ] **Step 6: Commit**

```bash
git add scripts/read-version.sh tests/read-version.bats
git commit -m "feat: add read-version.sh (json/toml/regex location reader)"
```

---

## Task 4: `version-sync-check.sh`

**Files:**
- Create: `scripts/version-sync-check.sh`
- Test: `tests/version-sync-check.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/version-sync-check.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/version-sync-check.sh"
  TMP="$(mktemp -d)"
  cd "$TMP"
}
teardown() { rm -rf "$TMP"; }

write_config() { cat > "$TMP/.shipmate.json"; }

@test "passes when both locations of a contract agree" {
  echo '{"version":"1.0.0"}' > package.json
  printf '[project]\nversion = "1.0.0"\n' > pyproject.toml
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[
    {"file":"package.json","json":".version"},
    {"file":"pyproject.toml","toml":"project.version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}

@test "fails when locations disagree (drift)" {
  echo '{"version":"1.0.0"}' > package.json
  printf '[project]\nversion = "1.0.1"\n' > pyproject.toml
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[
    {"file":"package.json","json":".version"},
    {"file":"pyproject.toml","toml":"project.version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"kit"* ]]
  [[ "$output" == *"1.0.0"* ]]
  [[ "$output" == *"1.0.1"* ]]
}

@test "checks each contract independently" {
  echo '{"version":"1.0.0"}' > package.json
  echo '{"const":"2.0"}' > schema.json
  write_config <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[
    {"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"package.json","json":".version"}]},
    {"name":"schema","tag":null,"bumpFrom":"manual","locations":[{"file":"schema.json","json":".const"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/version-sync-check.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/version-sync-check.sh`**

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/version-sync-check.sh && bats tests/version-sync-check.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/version-sync-check.sh`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add scripts/version-sync-check.sh tests/version-sync-check.bats
git commit -m "feat: add version-sync-check.sh (drift guard)"
```

---

## Task 5: `check-tag-unpushed.sh`

**Files:**
- Create: `scripts/check-tag-unpushed.sh`
- Test: `tests/check-tag-unpushed.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/check-tag-unpushed.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-tag-unpushed.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
  git push -q origin HEAD:main
}
teardown() { rm -rf "$TMP"; }

@test "passes when the tag is not on the remote" {
  run "$SCRIPT" origin v1.0.0
  [ "$status" -eq 0 ]
}

@test "fails when the tag already exists on the remote" {
  git tag v1.0.0
  git push -q origin v1.0.0
  run "$SCRIPT" origin v1.0.0
  [ "$status" -ne 0 ]
  [[ "$output" == *"v1.0.0"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/check-tag-unpushed.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/check-tag-unpushed.sh`**

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/check-tag-unpushed.sh && bats tests/check-tag-unpushed.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/check-tag-unpushed.sh`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add scripts/check-tag-unpushed.sh tests/check-tag-unpushed.bats
git commit -m "feat: add check-tag-unpushed.sh (no re-pointing published tags)"
```

---

## Task 6: `verify-remote.sh`

**Files:**
- Create: `scripts/verify-remote.sh`
- Test: `tests/verify-remote.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/verify-remote.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/verify-remote.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
}
teardown() { rm -rf "$TMP"; }

@test "passes when the remote exists and is reachable" {
  run "$SCRIPT" origin
  [ "$status" -eq 0 ]
}

@test "fails when the remote does not exist" {
  run "$SCRIPT" nope
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/verify-remote.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/verify-remote.sh`**

```bash
#!/usr/bin/env bash
# Assert the configured remote exists and is reachable.
# Usage: verify-remote.sh <remote>
set -euo pipefail

remote="${1:?remote required}"

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  echo "verify-remote: no such remote '$remote'" >&2
  exit 1
fi
if ! git ls-remote --exit-code "$remote" >/dev/null 2>&1; then
  echo "verify-remote: remote '$remote' is not reachable" >&2
  exit 1
fi
echo "verify-remote: '$remote' exists and is reachable"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/verify-remote.sh && bats tests/verify-remote.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/verify-remote.sh`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add scripts/verify-remote.sh tests/verify-remote.bats
git commit -m "feat: add verify-remote.sh"
```

---

## Task 7: `check-preconditions.sh`

**Files:**
- Create: `scripts/check-preconditions.sh`
- Test: `tests/check-preconditions.bats`

This script checks: (1) clean working tree, (2) not behind upstream, (3) remote reachable. The `gh auth` check is delegated to a `SHIPMATE_SKIP_GH_CHECK` env guard so it is testable offline (real `release` does not set it).

- [ ] **Step 1: Write the failing bats test**

`tests/check-preconditions.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-preconditions.sh"
  TMP="$(mktemp -d)"
  REMOTE="$TMP/remote.git"
  WORK="$TMP/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  cd "$WORK"
  git config user.email t@t.t; git config user.name t
  git commit -q --allow-empty -m init
  git remote add origin "$REMOTE"
  git push -q -u origin HEAD:main
  export SHIPMATE_SKIP_GH_CHECK=1
}
teardown() { rm -rf "$TMP"; }

@test "passes on a clean, up-to-date tree" {
  run "$SCRIPT" origin
  [ "$status" -eq 0 ]
}

@test "fails on a dirty working tree" {
  echo dirty > file.txt
  run "$SCRIPT" origin
  [ "$status" -ne 0 ]
  [[ "$output" == *"working tree"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/check-preconditions.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/check-preconditions.sh`**

```bash
#!/usr/bin/env bash
# Release preconditions: clean tree, not behind upstream, gh authed, remote reachable.
# Usage: check-preconditions.sh <remote>
# Set SHIPMATE_SKIP_GH_CHECK=1 to skip the `gh auth` probe (tests only).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
remote="${1:?remote required}"

# 1) clean working tree
if [ -n "$(git status --porcelain)" ]; then
  echo "check-preconditions: working tree is not clean" >&2
  exit 1
fi

# 2) remote reachable (reuse verify-remote)
"$SCRIPT_DIR/verify-remote.sh" "$remote" >/dev/null

# 3) not behind upstream (if an upstream is configured)
if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  git fetch -q "$remote" || true
  behind="$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
  if [ "$behind" -gt 0 ]; then
    echo "check-preconditions: branch is $behind commit(s) behind $upstream" >&2
    exit 1
  fi
fi

# 4) gh authenticated
if [ "${SHIPMATE_SKIP_GH_CHECK:-0}" != "1" ]; then
  if ! gh auth status >/dev/null 2>&1; then
    echo "check-preconditions: gh is not authenticated (run: gh auth login)" >&2
    exit 1
  fi
fi

echo "check-preconditions: OK"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/check-preconditions.sh && bats tests/check-preconditions.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/check-preconditions.sh`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add scripts/check-preconditions.sh tests/check-preconditions.bats
git commit -m "feat: add check-preconditions.sh"
```

---

## Task 8: `scan-secrets.sh`

**Files:**
- Create: `scripts/scan-secrets.sh`
- Test: `tests/scan-secrets.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/scan-secrets.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/scan-secrets.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "passes on clean release notes" {
  printf '## [1.2.0]\n- Fixed a bug in the parser.\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -eq 0 ]
}

@test "fails on a GitHub token" {
  printf 'token: ghp_0123456789abcdef0123456789abcdef0123\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on a private key header" {
  printf -- '-----BEGIN RSA PRIVATE KEY-----\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "fails on an AWS access key id" {
  printf 'AKIAIOSFODNN7EXAMPLE\n' > "$TMP/notes.md"
  run "$SCRIPT" "$TMP/notes.md"
  [ "$status" -ne 0 ]
}

@test "reads from stdin when no file given" {
  run bash -c "printf 'ghp_0123456789abcdef0123456789abcdef0123\n' | '$SCRIPT'"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/scan-secrets.bats`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write `scripts/scan-secrets.sh`**

```bash
#!/usr/bin/env bash
# Fail if the given text (file arg or stdin) contains secret-shaped strings.
# Usage: scan-secrets.sh [file]   (reads stdin if no file)
# Pattern set is intentionally narrow + tested; extend with a test for each addition.
set -euo pipefail

if [ "${1:-}" != "" ]; then
  content="$(cat "$1")"
else
  content="$(cat)"
fi

# Each pattern is an ERE. Keep one per line; every addition needs a bats case.
patterns=(
  'ghp_[A-Za-z0-9]{36}'                 # GitHub personal access token
  'gho_[A-Za-z0-9]{36}'                 # GitHub OAuth token
  'github_pat_[A-Za-z0-9_]{22,}'        # GitHub fine-grained PAT
  'AKIA[0-9A-Z]{16}'                    # AWS access key id
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'  # PEM private key
  'xox[baprs]-[A-Za-z0-9-]{10,}'        # Slack token
)

hit=0
for p in "${patterns[@]}"; do
  if grep -Eq "$p" <<<"$content"; then
    echo "scan-secrets: matched secret-shaped pattern: /$p/" >&2
    hit=1
  fi
done

if [ "$hit" -ne 0 ]; then
  echo "scan-secrets: refusing to publish — secret-shaped strings found" >&2
  exit 1
fi
echo "scan-secrets: clean"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/scan-secrets.sh && bats tests/scan-secrets.bats`
Expected: all tests PASS

- [ ] **Step 5: shellcheck**

Run: `shellcheck scripts/scan-secrets.sh`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add scripts/scan-secrets.sh tests/scan-secrets.bats
git commit -m "feat: add scan-secrets.sh (pre-publish secret guard)"
```

---

## Task 9: Dev pre-commit hook + setup script

**Files:**
- Create: `hooks/pre-commit`
- Create: `setup-dev.sh`

- [ ] **Step 1: Write the pre-commit hook**

`hooks/pre-commit`:
```bash
#!/usr/bin/env bash
# shipmate dev pre-commit hook — fast local subset of CI. No husky, no node_modules.
# Enable with: ./setup-dev.sh
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

# shellcheck on all scripts + hooks
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh hooks/pre-commit setup-dev.sh
else
  echo "pre-commit: shellcheck not installed — skipping (CI still enforces it)" >&2
fi

# schema validation
npx -y ajv-cli@5.0.0 validate --spec=draft2020 \
  -s schemas/shipmate-config.schema.json -d examples/config-valid.json

echo "pre-commit: OK"
```

- [ ] **Step 2: Write the setup script**

`setup-dev.sh`:
```bash
#!/usr/bin/env bash
# One-time dev setup: route git hooks to the committed hooks/ dir.
set -euo pipefail
git config core.hooksPath hooks
chmod +x hooks/pre-commit
echo "setup-dev: core.hooksPath -> hooks/"
```

- [ ] **Step 3: Make executable and smoke-test the hook**

Run:
```bash
chmod +x hooks/pre-commit setup-dev.sh
./hooks/pre-commit
```
Expected: ends with `pre-commit: OK`

- [ ] **Step 4: shellcheck both**

Run: `shellcheck hooks/pre-commit setup-dev.sh`
Expected: clean

- [ ] **Step 5: Commit**

```bash
git add hooks/pre-commit setup-dev.sh
git commit -m "chore: add native bash pre-commit hook + dev setup (no husky)"
```

---

## Task 10: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the workflow**

`.github/workflows/ci.yml`:
```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: shellcheck
        run: shellcheck scripts/*.sh hooks/pre-commit setup-dev.sh

  schema:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: validate schema + fixture
        run: npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json

  bats:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: install bats
        run: npm install -g bats@1.11.0
      - name: run tests
        run: bats tests
```

- [ ] **Step 2: Validate the workflow YAML locally**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml')); print('yaml OK')"`
Expected: `yaml OK`

- [ ] **Step 3: Run the full local test suite (mirror CI)**

Run:
```bash
shellcheck scripts/*.sh hooks/pre-commit setup-dev.sh
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json
bats tests
```
Expected: shellcheck clean, schema valid, all bats PASS

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: shellcheck + schema validation + bats"
```

- [ ] **Step 5: Open the foundation PR (first real shipmate PR)**

```bash
git checkout -b feat/foundation
git push -u origin feat/foundation
gh pr create --title "Foundation: schema + guard scripts + CI" \
  --body "Plan 1 of 4. Adds the plugin scaffold, .shipmate.json schema, five deterministic guard scripts (read-version, version-sync-check, check-tag-unpushed, verify-remote, check-preconditions, scan-secrets), bats tests, and CI."
```
Then, after CI is green, enable branch protection on `main` (the user's "at first PR" governance step) and squash-merge.

---

## Self-Review

**Spec coverage (Plan 1 portion of `docs/specs/2026-06-14-shipmate-design.md`):**
- §6 schema → Task 2 ✓ (note: `json` = jq filter, reconciled in fixture + schema)
- §7.2 PRE-FLIGHT guards: preconditions/tag-unpushed/remote/version-sync → Tasks 4–7 ✓; pre-PUBLISH secret-scan → Task 8 ✓
- §9 layout (scripts/, schemas/, hooks/, .github/, manifests) → Tasks 1, 9, 10 ✓
- §11 testing (bats, shellcheck, schema CI, pre-commit no-husky) → Tasks 3–10 ✓
- Deferred to later plans (correctly out of Plan 1): `discover-versions.sh`, the three SKILL.md, templates/, examples fixtures, docs/, dogfood. Tracked in Plans 2–4.

**Placeholder scan:** none — every script and test is complete code.

**Type/name consistency:** `read-version.sh <file> <type> <expr>` is called identically in Task 4's `read_loc`. Script names match the §9 layout and the CI/hook globs (`scripts/*.sh`). Config field names (`remote`, `protectedBranch`, `primaryContract`, `contracts[].name/tag/bumpFrom/locations[].file/json/toml/regex`) are identical across schema (Task 2), version-sync-check (Task 4), and fixture.

**Note carried to Plan 2:** the schema does not enforce "primaryContract is a tagged contract" or "regex has exactly one capture group" (not expressible in JSON Schema) — these are validated by `init` (Plan 2).
