# shipmate v0 — Plan 2: `init` skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Depends on Plan 1 (schema + `read-version.sh` must exist).

**Goal:** Build the `shipmate:init` skill that onboards any JS/TS or Python repo — discovers version locations, proposes a contract map, validates it, writes `.shipmate.json`, and offers the drift-guard + branch-protection scaffolding.

**Architecture:** Two new deterministic scripts (`discover-versions.sh`, `validate-config.sh`) do the testable mechanical work; `skills/init/SKILL.md` is the LLM-driven workflow that calls them and runs the human dialogue. Templates back the optional scaffolding. Skills are verified by skill-creator evals against the `examples/` fixture repos (created here), not by unit tests.

**Tech Stack:** Bash + jq + perl (scripts), SKILL.md authored via skill-creator, bats (script tests), ajv (config validation).

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/discover-versions.sh` | Scan a repo → candidate version locations as JSON |
| `scripts/validate-config.sh` | Validate `.shipmate.json` beyond schema (primaryContract tagged, regex single-group, tag uniqueness, locations readable) |
| `skills/init/SKILL.md` | The onboarding workflow (discover → propose → confirm → validate → write → scaffold) |
| `templates/changelog-skeleton.md` | Keep-a-Changelog starter |
| `templates/protect-main.sh` | Branch-protection layer 1 (local hook) |
| `templates/github-branch-protection.sh` | Layer 2 (`gh api`) |
| `templates/ci-version-sync.yml` | Drift guard as CI step |
| `templates/pre-push-version-sync.sh` | Drift guard as pre-push hook |
| `templates/branch-protection-notes.md` | Plain-language explainer |
| `examples/js-single-contract/` | Fixture repo (also Plan 4 demo) |
| `examples/python-single-contract/` | Fixture repo (also Plan 4 demo) |
| `tests/discover-versions.bats`, `tests/validate-config.bats` | Script tests |

---

## Task 1: `discover-versions.sh`

**Files:**
- Create: `scripts/discover-versions.sh`
- Test: `tests/discover-versions.bats`

- [ ] **Step 1: Write the failing bats test**

`tests/discover-versions.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/discover-versions.sh"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

@test "finds package.json version" {
  echo '{"version":"1.2.3"}' > "$TMP/package.json"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="package.json" and .version=="1.2.3")'
}

@test "finds pyproject.toml version" {
  printf '[project]\nversion = "4.5.6"\n' > "$TMP/pyproject.toml"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="pyproject.toml" and .version=="4.5.6")'
}

@test "finds claude plugin manifests" {
  mkdir -p "$TMP/.claude-plugin"
  echo '{"version":"0.1.0"}' > "$TMP/.claude-plugin/plugin.json"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file==".claude-plugin/plugin.json")'
}

@test "finds prose currently-version markers" {
  mkdir -p "$TMP/docs"
  printf 'pinned (currently `7.8.9` here)\n' > "$TMP/docs/install.md"
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[] | select(.file=="docs/install.md" and .version=="7.8.9")'
}

@test "emits empty array when nothing found" {
  run "$SCRIPT" "$TMP"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq 'length')" -eq 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/discover-versions.bats`
Expected: FAIL (script missing)

- [ ] **Step 3: Write `scripts/discover-versions.sh`**

```bash
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/discover-versions.sh && bats tests/discover-versions.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

Run: `shellcheck scripts/discover-versions.sh`
```bash
git add scripts/discover-versions.sh tests/discover-versions.bats
git commit -m "feat: add discover-versions.sh (init discovery)"
```

---

## Task 2: `validate-config.sh`

**Files:**
- Create: `scripts/validate-config.sh`
- Test: `tests/validate-config.bats`

Validates a `.shipmate.json` beyond the JSON Schema: (a) `primaryContract` names a contract whose `tag` ≠ null; (b) each `regex` location has exactly one capture group; (c) tagged contracts render distinct tags; (d) every location is currently readable.

- [ ] **Step 1: Write the failing bats test**

`tests/validate-config.bats`:
```bash
#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/validate-config.sh"
  TMP="$(mktemp -d)"; cd "$TMP"
  echo '{"version":"1.0.0"}' > package.json
}
teardown() { rm -rf "$TMP"; }
cfg() { cat > "$TMP/.shipmate.json"; }

@test "passes a valid single-contract config" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -eq 0 ]
}

@test "fails when primaryContract is untagged" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"schema",
  "contracts":[{"name":"schema","tag":null,"bumpFrom":"manual",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"primaryContract"* ]]
}

@test "fails when primaryContract names no contract" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"ghost",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"package.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
}

@test "fails when a regex location has != 1 capture group" {
  printf 'v 1.0.0 here\n' > install.md
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"install.md","regex":"v ([0-9]+)\\.([0-9]+)\\.[0-9]+"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"capture group"* ]]
}

@test "fails when two tagged contracts render the same tag" {
  echo '{"version":"1.0.0"}' > a.json
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[
    {"name":"kit","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"package.json","json":".version"}]},
    {"name":"two","tag":"v{version}","bumpFrom":"changelog","locations":[{"file":"a.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"tag"* ]]
}

@test "fails when a location is unreadable" {
  cfg <<'JSON'
{ "remote":"origin","protectedBranch":"main","primaryContract":"kit",
  "contracts":[{"name":"kit","tag":"v{version}","bumpFrom":"changelog",
    "locations":[{"file":"missing.json","json":".version"}]}]}
JSON
  run "$SCRIPT" "$TMP/.shipmate.json"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/validate-config.bats`
Expected: FAIL (script missing)

- [ ] **Step 3: Write `scripts/validate-config.sh`**

```bash
#!/usr/bin/env bash
# Validate .shipmate.json beyond JSON Schema.
# Usage: validate-config.sh [path]   (default ./.shipmate.json)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${1:-./.shipmate.json}"
read_version="$SCRIPT_DIR/read-version.sh"
[ -f "$config" ] || { echo "validate-config: not found: $config" >&2; exit 2; }
cfg_dir="$(cd "$(dirname "$config")" && pwd)"

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

# collect rendered tags for uniqueness (portable: newline list, no associative arrays —
# macOS ships bash 3.2 which lacks `declare -A`); validate regex groups + readability
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/validate-config.sh && bats tests/validate-config.bats`
Expected: all PASS

- [ ] **Step 5: shellcheck + commit**

Run: `shellcheck scripts/validate-config.sh`
```bash
git add scripts/validate-config.sh tests/validate-config.bats
git commit -m "feat: add validate-config.sh (beyond-schema invariants)"
```

---

## Task 3: Scaffolding templates

**Files:**
- Create: `templates/changelog-skeleton.md`
- Create: `templates/protect-main.sh`
- Create: `templates/github-branch-protection.sh`
- Create: `templates/ci-version-sync.yml`
- Create: `templates/pre-push-version-sync.sh`
- Create: `templates/branch-protection-notes.md`

- [ ] **Step 1: `templates/changelog-skeleton.md`**

```markdown
# Changelog

All notable changes to this project will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

## [Unreleased]
```

- [ ] **Step 2: `templates/protect-main.sh`** (layer 1 — local hook; `{{BRANCH}}` substituted by `init`)

```bash
#!/usr/bin/env bash
# shipmate-scaffolded local guard: deny direct commit/push on the protected branch.
# Convenience only (bypassable with --no-verify); the real barrier is GitHub branch protection.
set -euo pipefail
protected="{{BRANCH}}"
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ "$branch" = "$protected" ]; then
  echo "Blocked: commit on '$protected' directly. Branch + PR required." >&2
  exit 1
fi
```

- [ ] **Step 3: `templates/github-branch-protection.sh`** (layer 2 — `gh api`; `{{OWNER}}`, `{{REPO}}`, `{{BRANCH}}` substituted)

```bash
#!/usr/bin/env bash
# Configure GitHub branch protection (the real barrier) + required CI check.
set -euo pipefail
gh api -X PUT "repos/{{OWNER}}/{{REPO}}/branches/{{BRANCH}}/protection" \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=CI' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews=null' \
  -F 'restrictions=null'
echo "Branch protection enabled on {{BRANCH}}."
```

- [ ] **Step 4: `templates/ci-version-sync.yml`** (layer 3 / drift guard as CI)

```yaml
# Paste into .github/workflows/ — fails a PR if version locations drift.
name: version-sync
on: [pull_request]
permissions:
  contents: read
jobs:
  version-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: check version sync
        run: bash .shipmate/version-sync-check.sh .shipmate.json
```

- [ ] **Step 5: `templates/pre-push-version-sync.sh`** (drift guard as pre-push hook)

```bash
#!/usr/bin/env bash
# shipmate-scaffolded pre-push hook: block a push if version locations drift.
set -euo pipefail
bash "$(git rev-parse --show-toplevel)/.shipmate/version-sync-check.sh" \
  "$(git rev-parse --show-toplevel)/.shipmate.json"
```

- [ ] **Step 6: `templates/branch-protection-notes.md`** (plain-language explainer)

```markdown
# How shipmate protects your main branch

Three layers, weakest to strongest:

1. **Local hook** — stops *you* from committing to `main` by accident. Bypassable
   (`git commit --no-verify`), so it is convenience, not security.
2. **GitHub branch protection** — the real wall. GitHub refuses any direct push to
   `main` server-side, even if your local hook is off. This is what actually enforces.
3. **Required status checks (CI)** — your CI must pass before a pull request can merge.
   A CI run cannot *block a push* (the push already happened); it gates the *merge*.

shipmate sets up whichever layers you opt into. Tags are intentionally exempt from
protection so releases can be tagged after merge.
```

- [ ] **Step 7: Validate templates**

Run:
```bash
shellcheck templates/protect-main.sh templates/github-branch-protection.sh templates/pre-push-version-sync.sh
python3 -c "import yaml; yaml.safe_load(open('templates/ci-version-sync.yml')); print('yaml OK')"
```
Expected: shellcheck clean (note: `{{...}}` placeholders are inside strings, not code — shellcheck passes), `yaml OK`

- [ ] **Step 8: Commit**

```bash
git add templates/
git commit -m "feat: add init scaffolding templates (branch protection + drift guard)"
```

---

## Task 4: Example fixture repos

**Files:**
- Create: `examples/js-single-contract/package.json`
- Create: `examples/js-single-contract/CHANGELOG.md`
- Create: `examples/js-single-contract/expected.shipmate.json`
- Create: `examples/python-single-contract/pyproject.toml`
- Create: `examples/python-single-contract/CHANGELOG.md`
- Create: `examples/python-single-contract/expected.shipmate.json`

These are eval fixtures (init: repo in → `expected.shipmate.json` out) and Plan 4 demos.

- [ ] **Step 1: JS fixture**

`examples/js-single-contract/package.json`:
```json
{ "name": "demo-js", "version": "0.3.0" }
```
`examples/js-single-contract/CHANGELOG.md`:
```markdown
# Changelog

## [Unreleased]

### Fixed
- Handle empty input in the parser.
```
`examples/js-single-contract/expected.shipmate.json`:
```json
{
  "remote": "origin",
  "protectedBranch": "main",
  "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [
    { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
      "locations": [ { "file": "package.json", "json": ".version" } ] }
  ]
}
```

- [ ] **Step 2: Python fixture**

`examples/python-single-contract/pyproject.toml`:
```toml
[project]
name = "demo-py"
version = "0.3.0"
```
`examples/python-single-contract/CHANGELOG.md`:
```markdown
# Changelog

## [Unreleased]

### Added
- New `--verbose` flag.
```
`examples/python-single-contract/expected.shipmate.json`:
```json
{
  "remote": "origin",
  "protectedBranch": "main",
  "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [
    { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
      "locations": [ { "file": "pyproject.toml", "toml": "project.version" } ] }
  ]
}
```

- [ ] **Step 3: Verify discovery matches the expected contract location**

Run:
```bash
scripts/discover-versions.sh examples/js-single-contract | jq -e '.[] | select(.file=="package.json" and .version=="0.3.0")'
scripts/discover-versions.sh examples/python-single-contract | jq -e '.[] | select(.file=="pyproject.toml" and .version=="0.3.0")'
```
Expected: both jq selects exit 0 (match found)

- [ ] **Step 4: Validate each expected config against the schema**

Run:
```bash
for f in examples/*/expected.shipmate.json; do
  npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d "$f"
done
```
Expected: both `valid`

- [ ] **Step 5: Commit**

```bash
git add examples/js-single-contract examples/python-single-contract
git commit -m "test: add js + python init fixtures with expected configs"
```

---

## Task 5: `skills/init/SKILL.md`

**Files:**
- Create: `skills/init/SKILL.md`

Author this through **skill-creator** (frontmatter + structure below). It is the LLM workflow; it calls the Plan-1/Plan-2 scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...`.

- [ ] **Step 1: Write `skills/init/SKILL.md`**

````markdown
---
name: init
description: Onboard a repo to shipmate — discover version locations, propose and confirm a contract map, write .shipmate.json, and optionally scaffold drift-guard and branch protection. Use when setting up shipmate on a new repository, running shipmate init, or preparing a repo for shipmate releases.
---

# shipmate:init — onboard a repository

You are onboarding the current repo to shipmate. Follow these phases in order. Never
overwrite without showing a diff. Locate scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`.

## Phase 1 — Discover
Run `discover-versions.sh` on the repo root. Present the candidate locations (file +
current version) as a table. If none found, ask the user where versions live.

## Phase 2 — Propose a contract map
Group the candidates into named contracts. Default: one contract `kit` over all
locations that share the same current version. If two groups carry *different* current
versions, propose them as separate contracts and ask which is the `primaryContract`
(must be a tagged one). Explain "contract" in plain language (a set of files that
version together).

## Phase 3 — Confirm
Show the proposed `.shipmate.json` and ask the user to confirm or correct: contract
names, which locations belong where, tag templates, `primaryContract`, `securityReview`.

## Phase 4 — Validate (before writing)
Write the proposed config to a temp file and run `validate-config.sh` on it. If it fails,
show the error in plain language and loop back to Phase 3. Do not write until it passes.

## Phase 5 — Write
Show the final `.shipmate.json` (dry-run preview) and, on approval, write it to the repo
root. If a `.shipmate.json` already exists, diff against it and merge — never blind
overwrite (idempotent re-run).

## Phase 6 — Offer the drift guard (opt-in)
Offer to wire `version-sync-check.sh` as: a pre-push hook (template
`pre-push-version-sync.sh`), and/or a CI step (template `ci-version-sync.yml`). Copy
`version-sync-check.sh` + `read-version.sh` into the repo's `.shipmate/` dir so the
hook/CI can call them. Explain drift with a concrete example.

## Phase 7 — Offer branch protection (three layers, opt-in)
For `protectedBranch`, offer each layer separately (templates `protect-main.sh`,
`github-branch-protection.sh`, and the CI required-check). State plainly that layer 2
(GitHub branch protection) is the real barrier. Also scaffold `CHANGELOG.md` from
`changelog-skeleton.md` if absent.

## Hard rules
- shipmate never edits source code. You only write `.shipmate.json`, scaffolded
  hooks/CI/templates, and (if absent) a CHANGELOG skeleton.
- Always preview before writing; always confirm before scaffolding.
````

- [ ] **Step 2: Lint the frontmatter**

Run:
```bash
python3 - <<'PY'
import re, sys
t = open('skills/init/SKILL.md').read()
m = re.match(r'^---\n(.*?)\n---\n', t, re.S)
assert m, "missing frontmatter"
import yaml; fm = yaml.safe_load(m.group(1))
assert fm.get('name') == 'init', fm
assert 'description' in fm and len(fm['description']) > 40
print("frontmatter OK")
PY
```
Expected: `frontmatter OK`

- [ ] **Step 3: Eval via skill-creator (acceptance test)**

Using skill-creator's eval flow, run an eval where the input is "run shipmate init" inside
each `examples/*` fixture and the expected output is a `.shipmate.json` byte-equal (after
`jq -S`) to that fixture's `expected.shipmate.json`. Record the eval under
`skills/init/evals/`.

Acceptance criteria (definition of done):
- On `examples/js-single-contract`, init produces a config `jq -S`-equal to its `expected.shipmate.json`.
- On `examples/python-single-contract`, same.
- On a repo with two differently-versioned groups, init proposes two contracts and asks for `primaryContract`.
- init refuses to write a config that fails `validate-config.sh`.

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md skills/init/evals
git commit -m "feat: add shipmate:init skill + evals"
```

---

## Task 6: Wire new scripts into CI + open the Plan-2 PR

**Files:**
- Modify: `.github/workflows/ci.yml` (shellcheck/bats already glob `scripts/*.sh` and `tests` — confirm new files are covered)

- [ ] **Step 1: Confirm CI globs cover the new scripts/tests**

Run:
```bash
shellcheck scripts/*.sh
bats tests
```
Expected: all clean / PASS (new scripts + tests included by the existing globs)

- [ ] **Step 2: Commit any CI tweak (only if a glob needed widening)**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: ensure init scripts + tests are covered" || echo "no change needed"
```

- [ ] **Step 3: Open the Plan-2 PR**

```bash
git checkout -b feat/init
git push -u origin feat/init
gh pr create --title "init skill: discovery, validation, scaffolding" \
  --body "Plan 2 of 4. Adds discover-versions.sh, validate-config.sh, scaffolding templates, js/python fixtures, and the shipmate:init skill with evals."
```

---

## Self-Review

**Spec coverage (init portion):** §7.1 phases 1–7 → Task 5 ✓; discovery (§7.1.1) → Task 1 ✓; beyond-schema validation incl. primaryContract-tagged + regex-single-group + tag uniqueness (§6, m2/M5/M6) → Task 2 ✓; templates for drift guard + 3-layer branch protection (§7.1.5–6, §8.1) → Task 3 ✓; `${CLAUDE_PLUGIN_ROOT}` resolution (m3) → Task 5 ✓; fixtures for evals (§11) → Task 4 ✓.

**Placeholder scan:** scripts are complete; `{{OWNER}}`/`{{REPO}}`/`{{BRANCH}}` in templates are intentional substitution tokens (documented as substituted by init), not plan placeholders.

**Type/name consistency:** `discover-versions.sh` output shape `{file,type,expr,version}` matches its bats asserts and the init proposal. `validate-config.sh` reads the same config field names as Plan 1's schema + version-sync-check. Scripts called from SKILL.md by the exact filenames created here.

**Carried to Plan 3:** `write-version.sh` (the WRITE counterpart of `read-version.sh`) and tag rendering are defined in Plan 3, where `release` needs them.
