# shipmate v0 — Plan 3: `release` skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Depends on Plans 1–2 (read-version, version-sync-check, validate-config, the config).

**Goal:** Build the `shipmate:release` skill — the state machine that bumps versions, authors the curated changelog, runs the pre-flight + pre-publish guards, and (after one human checkpoint) tags and publishes — plus the deterministic WRITE-side scripts it orchestrates.

**Architecture:** New scripts do the mechanical writes (`write-version.sh`, `render-tag.sh`, `changelog-release.sh`, `diff-touches-code.sh`, `release-rollback.sh`), each unit-tested with bats. `skills/release/SKILL.md` is the LLM state machine (PRE-FLIGHT → PLAN → LOCAL-WRITE → PR/`--no-pr` → CHECKPOINT → PUBLISH) that calls them and runs the human dialogue + SemVer judgment + changelog authoring + `/security-review`.

**Tech Stack:** Bash + jq + perl + awk (scripts), SKILL.md via skill-creator, bats.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/write-version.sh` | Write a new version into a json/toml/regex location (WRITE counterpart of read-version) |
| `scripts/render-tag.sh` | Render a tag template (`{name}`/`{version}`) |
| `scripts/changelog-release.sh` | Restructure `[Unreleased]`→`[X.Y.Z]` + extract a version's notes |
| `scripts/diff-touches-code.sh` | Decide whether a change set touches code (security-review `auto`) |
| `scripts/release-rollback.sh` | Undo local tag / branch / changelog on abort |
| `skills/release/SKILL.md` | The release state machine |
| `tests/*.bats` | One per new script |

---

## Task 1: `write-version.sh`

**Files:**
- Create: `scripts/write-version.sh`
- Test: `tests/write-version.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/write-version.bats`:
```bash
#!/usr/bin/env bats

setup() {
  W="$BATS_TEST_DIRNAME/../scripts/write-version.sh"
  R="$BATS_TEST_DIRNAME/../scripts/read-version.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "writes json version" {
  echo '{"version":"1.0.0"}' > "$TMP/package.json"
  "$W" "$TMP/package.json" json ".version" "2.0.0"
  [ "$("$R" "$TMP/package.json" json ".version")" = "2.0.0" ]
}

@test "writes nested json version" {
  echo '{"plugins":[{"version":"1.0.0"}]}' > "$TMP/m.json"
  "$W" "$TMP/m.json" json ".plugins[0].version" "3.1.0"
  [ "$("$R" "$TMP/m.json" json ".plugins[0].version")" = "3.1.0" ]
}

@test "writes toml version, leaving other keys intact" {
  printf '[project]\nname = "x"\nversion = "1.0.0"\n' > "$TMP/pyproject.toml"
  "$W" "$TMP/pyproject.toml" toml "project.version" "2.2.2"
  [ "$("$R" "$TMP/pyproject.toml" toml "project.version")" = "2.2.2" ]
  grep -q 'name = "x"' "$TMP/pyproject.toml"
}

@test "writes regex capture group 1, leaving surrounding text intact" {
  printf 'pinned (currently `1.0.0` here)\n' > "$TMP/install.md"
  "$W" "$TMP/install.md" regex 'currently `([0-9]+\.[0-9]+\.[0-9]+)`' "9.9.9"
  grep -q 'currently `9.9.9` here' "$TMP/install.md"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/write-version.bats`
Expected: FAIL (missing script)

- [ ] **Step 3: Write `scripts/write-version.sh`**

```bash
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x scripts/write-version.sh && bats tests/write-version.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/write-version.sh
git add scripts/write-version.sh tests/write-version.bats
git commit -m "feat: add write-version.sh (location WRITE side)"
```

---

## Task 2: `render-tag.sh`

**Files:**
- Create: `scripts/render-tag.sh`
- Test: `tests/render-tag.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/render-tag.bats`:
```bash
#!/usr/bin/env bats
setup() { S="$BATS_TEST_DIRNAME/../scripts/render-tag.sh"; }

@test "renders version-only template" {
  run "$S" "v{version}" kit 1.2.3
  [ "$status" -eq 0 ]; [ "$output" = "v1.2.3" ]
}
@test "renders name+version template" {
  run "$S" "{name}-v{version}" schema 2.0.0
  [ "$status" -eq 0 ]; [ "$output" = "schema-v2.0.0" ]
}
@test "errors on null/empty template" {
  run "$S" "" kit 1.0.0
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/render-tag.bats`
Expected: FAIL

- [ ] **Step 3: Write `scripts/render-tag.sh`**

```bash
#!/usr/bin/env bash
# Render a tag template. Usage: render-tag.sh <template> <name> <version>
set -euo pipefail
tmpl="${1:?template (use empty string only for tag:null, which has no tag)}"
name="${2:?name}"; version="${3:?version}"
[ -n "$tmpl" ] || { echo "render-tag: empty template" >&2; exit 1; }
out="${tmpl//\{name\}/$name}"
out="${out//\{version\}/$version}"
echo "$out"
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x scripts/render-tag.sh && bats tests/render-tag.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/render-tag.sh
git add scripts/render-tag.sh tests/render-tag.bats
git commit -m "feat: add render-tag.sh"
```

---

## Task 3: `changelog-release.sh`

**Files:**
- Create: `scripts/changelog-release.sh`
- Test: `tests/changelog-release.bats`

Two subcommands: `restructure <file> <version> <date>` (rename `[Unreleased]`→`[version] — date`, insert fresh `[Unreleased]` above) and `extract <file> <version>` (print just that version's section body, for release notes).

- [ ] **Step 1: Write the failing bats test**

`tests/changelog-release.bats`:
```bash
#!/usr/bin/env bats
setup() {
  S="$BATS_TEST_DIRNAME/../scripts/changelog-release.sh"
  TMP="$(mktemp -d)"
  cat > "$TMP/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Fixed
- A bug.
MD
}
teardown() { rm -rf "$TMP"; }

@test "restructure renames Unreleased and inserts a fresh one" {
  "$S" restructure "$TMP/CHANGELOG.md" 1.2.0 2026-06-14
  grep -q "## \[1.2.0\] — 2026-06-14" "$TMP/CHANGELOG.md"
  # exactly one fresh empty Unreleased remains above the version
  run grep -n "## \[Unreleased\]" "$TMP/CHANGELOG.md"
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  # the fixed entry now lives under the version heading
  awk '/## \[1.2.0\]/{f=1} f&&/A bug/{found=1} END{exit !found}' "$TMP/CHANGELOG.md"
}

@test "extract prints a version's section body only" {
  "$S" restructure "$TMP/CHANGELOG.md" 1.2.0 2026-06-14
  run "$S" extract "$TMP/CHANGELOG.md" 1.2.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"A bug"* ]]
  [[ "$output" != *"Unreleased"* ]]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/changelog-release.bats`
Expected: FAIL

- [ ] **Step 3: Write `scripts/changelog-release.sh`**

```bash
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x scripts/changelog-release.sh && bats tests/changelog-release.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/changelog-release.sh
git add scripts/changelog-release.sh tests/changelog-release.bats
git commit -m "feat: add changelog-release.sh (restructure + extract)"
```

---

## Task 4: `diff-touches-code.sh`

**Files:**
- Create: `scripts/diff-touches-code.sh`
- Test: `tests/diff-touches-code.bats`

Decides whether a change set touches code (drives `securityReview: auto`). Input: a newline list of changed paths on stdin. Exit 0 = touches code; exit 10 = code-less (docs/changelog/config/version files only).

- [ ] **Step 1: Write the failing bats test**

`tests/diff-touches-code.bats`:
```bash
#!/usr/bin/env bats
setup() { S="$BATS_TEST_DIRNAME/../scripts/diff-touches-code.sh"; }

@test "code-less when only docs + changelog + config change" {
  run bash -c "printf 'CHANGELOG.md\ndocs/install.md\n.shipmate.json\npackage.json\n' | '$S'"
  [ "$status" -eq 10 ]
}
@test "touches code when a source file changes" {
  run bash -c "printf 'CHANGELOG.md\nsrc/index.ts\n' | '$S'"
  [ "$status" -eq 0 ]
}
@test "touches code for a python source change" {
  run bash -c "printf 'app/main.py\n' | '$S'"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/diff-touches-code.bats`
Expected: FAIL

- [ ] **Step 3: Write `scripts/diff-touches-code.sh`**

```bash
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x scripts/diff-touches-code.sh && bats tests/diff-touches-code.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/diff-touches-code.sh
git add scripts/diff-touches-code.sh tests/diff-touches-code.bats
git commit -m "feat: add diff-touches-code.sh (security-review auto gate)"
```

---

## Task 5: `release-rollback.sh`

**Files:**
- Create: `scripts/release-rollback.sh`
- Test: `tests/release-rollback.bats`

Discrete, idempotent cleanup ops the skill calls on abort: delete a local tag, delete a local branch, restore a file from HEAD.

- [ ] **Step 1: Write the failing bats test**

`tests/release-rollback.bats`:
```bash
#!/usr/bin/env bats
setup() {
  S="$BATS_TEST_DIRNAME/../scripts/release-rollback.sh"
  TMP="$(mktemp -d)"; cd "$TMP"
  git init -q; git config user.email t@t.t; git config user.name t
  echo base > f.txt; git add f.txt; git commit -qm init
}
teardown() { rm -rf "$TMP"; }

@test "deletes a local tag" {
  git tag v1.0.0
  "$S" tag v1.0.0
  run git tag -l v1.0.0
  [ -z "$output" ]
}
@test "deleting a missing tag is a no-op (idempotent)" {
  run "$S" tag v9.9.9
  [ "$status" -eq 0 ]
}
@test "deletes a local branch" {
  git branch release/x
  "$S" branch release/x
  run git branch --list release/x
  [ -z "$output" ]
}
@test "restores a file from HEAD" {
  echo changed > f.txt
  "$S" restore f.txt
  [ "$(cat f.txt)" = "base" ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats tests/release-rollback.bats`
Expected: FAIL

- [ ] **Step 3: Write `scripts/release-rollback.sh`**

```bash
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `chmod +x scripts/release-rollback.sh && bats tests/release-rollback.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/release-rollback.sh
git add scripts/release-rollback.sh tests/release-rollback.bats
git commit -m "feat: add release-rollback.sh (abort cleanup)"
```

---

## Task 6: `skills/release/SKILL.md`

**Files:**
- Create: `skills/release/SKILL.md`

Author via **skill-creator**. This is the state machine; it calls Plan-1/2/3 scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...` and does the judgment work (SemVer classification, changelog authoring, `/security-review`).

- [ ] **Step 1: Write `skills/release/SKILL.md`**

````markdown
---
name: release
description: Cut a release for a shipmate-configured repo — classify the SemVer bump, author the curated changelog, run guards, and after one human checkpoint tag and publish. Use when releasing, cutting a version, shipping a release, or running shipmate release. Supports --no-pr, --dry-run, --bump, and security-review flags.
---

# shipmate:release — cut a release (state machine)

Requires `.shipmate.json` (run `shipmate:init` first). Run states in order. Scripts are at
`${CLAUDE_PLUGIN_ROOT}/scripts/`. Never perform an irreversible action (tag/push-tag/
release) before the CHECKPOINT go.

## State 1 — PRE-FLIGHT (all guards must pass; nothing written yet)
Run, in order, aborting on the first failure:
1. `check-preconditions.sh <remote>` — clean tree, up to date, gh auth, remote reachable.
2. For each tagged contract: `render-tag.sh` then `check-tag-unpushed.sh <remote> <tag>`.
3. `verify-remote.sh <remote>`.
4. `version-sync-check.sh .shipmate.json`.

## State 2 — PLAN (no writes)
- Determine the diff since the **primaryContract**'s last tag. **If no tag exists yet (a
  repo's first-ever release), fall back to the diff from the repository's initial commit**
  (`git rev-list --max-parents=0 HEAD`). The curated `[Unreleased]` drives the notes either
  way. (Distinct from shipmate's own chicken/egg — consuming repos always have shipmate
  available; they just lack a prior tag on first release.)
- Classify the SemVer bump **per contract** using documented nuance (e.g. tightening an
  already-documented contract = PATCH, not MAJOR). Skip `bumpFrom: "manual"` contracts
  unless `--bump <name>` was passed. Present the proposed version(s) + reasoning.
- Author/finalize the curated `CHANGELOG.md [Unreleased]` content (the *why*, not just the
  *what*). For non-primary contracts in a multi-contract repo, prefix entries with the
  contract name and link any migrator.
- **Security review** per `securityReview` policy: if `always`, or if `auto` and
  `diff-touches-code.sh` returns 0 (code touched), invoke `/security-review` on the diff;
  surface findings at CHECKPOINT. `--security-review`/`--no-security-review` override.
- If `--dry-run`: print the full plan (bumps, changelog, tag plan, review findings) and STOP.

## State 3 — LOCAL-WRITE (reversible)
- `write-version.sh` each location of each bumping contract to the decided version.
- `changelog-release.sh restructure CHANGELOG.md <version> <today>`.
- Commit locally on a `release/<version>` branch.

## State 4 — fork on mode
- **`--no-pr`** (no protected branch): skip to CHECKPOINT.
- **PR mode** (default when `protectedBranch` set): `gh pr create`. PAUSE. Tell the user
  the PR is open and CI is running; wait for them to merge. Detect the merge, then resume.
  (The merge is reversible by revert; the tag/release are not.)

## State 5 — CHECKPOINT (single gate)
- Run the pre-PUBLISH guard: `changelog-release.sh extract CHANGELOG.md <version>` →
  pipe to `scan-secrets.sh`. Abort on a hit.
- Show a full recap: bumps, the extracted changelog section, tag plan, remote, branch,
  and (PR mode) that the PR is already merged. Require ONE explicit go/no-go.
- On no-go: use `release-rollback.sh` to clean up (tag/branch/restore) and stop.

## State 6 — PUBLISH (irreversible, ordered last)
- For each tagged contract: create the annotated tag on the merged commit, push it.
- `gh release create <primary tag> --notes "<extracted changelog section, verbatim>"`.

## Hard rules
- Never `-f`/force-push a tag. Never re-point a published tag (PRE-FLIGHT guards this).
- shipmate edits only version locations + `CHANGELOG.md`; never source code.
- In PR mode, never commit or tag directly on `protectedBranch`.
````

- [ ] **Step 2: Lint frontmatter**

Run:
```bash
python3 - <<'PY'
import re, yaml
t=open('skills/release/SKILL.md').read()
fm=yaml.safe_load(re.match(r'^---\n(.*?)\n---\n', t, re.S).group(1))
assert fm['name']=='release' and len(fm['description'])>40
print("frontmatter OK")
PY
```
Expected: `frontmatter OK`

- [ ] **Step 3: Eval via skill-creator (acceptance)**

Build an eval on a throwaway git repo seeded from `examples/js-single-contract` (with a
remote) that runs `shipmate:release --no-pr --no-security-review` after adding a `[Unreleased]`
entry. Record under `skills/release/evals/`.

Acceptance criteria (definition of done):
- Picks the correct SemVer bump from the `[Unreleased]` sections (Added→MINOR, Fixed→PATCH).
- `package.json` and all contract locations are bumped to the new version (verified via `read-version.sh`).
- `CHANGELOG.md` has `[X.Y.Z] — <date>` with the old `[Unreleased]` content, plus a fresh empty `[Unreleased]`.
- A tag `v<version>` is created; `gh release` notes equal `changelog-release.sh extract` output.
- With a secret in the notes, PUBLISH is blocked by `scan-secrets.sh`.
- `--dry-run` writes nothing (git status clean afterwards).

- [ ] **Step 4: Commit**

```bash
git add skills/release/SKILL.md skills/release/evals
git commit -m "feat: add shipmate:release skill (state machine) + evals"
```

---

## Task 7: Full suite + Plan-3 PR

- [ ] **Step 1: Run the whole local suite**

Run:
```bash
shellcheck scripts/*.sh
bats tests
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json
```
Expected: clean / all PASS / valid

- [ ] **Step 2: Open the Plan-3 PR**

```bash
git checkout -b feat/release
git push -u origin feat/release
gh pr create --title "release skill: state machine + WRITE scripts" \
  --body "Plan 3 of 4. Adds write-version, render-tag, changelog-release, diff-touches-code, release-rollback (all bats-tested), and the shipmate:release state-machine skill with evals."
```

---

## Self-Review

**Spec coverage (release portion):** §7.2 state machine (PRE-FLIGHT/PLAN/LOCAL-WRITE/PR/--no-pr/CHECKPOINT/PUBLISH) → Task 6 ✓; pre-PUBLISH secret-scan ordering (audit fix A) → Task 6 State 5 ✓; SemVer nuance + manual-skip (M1) → Task 6 State 2 ✓; multi-contract changelog (§7.4) → Task 6 State 2 ✓; security-review secure-by-default `auto` (§7.2) → Task 4 + Task 6 ✓; reversibility ladder + rollback (M4) → Task 5 + Task 6 ✓; tag rendering {name}/{version} (M6) → Task 2 ✓; WRITE side of locations → Task 1 ✓.

**Placeholder scan:** all scripts complete; SKILL.md is prose (authored via skill-creator) with concrete script calls and acceptance criteria — no code placeholders.

**Type/name consistency:** `write-version.sh <file> <type> <expr> <new>` mirrors `read-version.sh` arg order. `render-tag.sh <template> <name> <version>` used identically in SKILL.md State 1/6. `changelog-release.sh restructure|extract` subcommands match the SKILL.md calls and bats. `diff-touches-code.sh` exit codes (0 code / 10 code-less) match SKILL.md State 2 logic. Config fields unchanged from Plans 1–2.

**Carried to Plan 4:** `verify` skill, docs, README/SEO, positioning, and the explain-panel-skills dogfood (which exercises the two-contract `kit`+`schema` path end-to-end).
