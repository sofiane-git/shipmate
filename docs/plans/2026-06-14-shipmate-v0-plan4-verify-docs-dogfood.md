# shipmate v0 — Plan 4: verify + docs + dogfood Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. Depends on Plans 1–3 (all scripts + init + release).

**Goal:** Ship the `shipmate:verify` doctor, the beginner-first + SEO documentation set, and prove the whole system by dogfooding it on `explain-panel-skills` (the two-contract case) and on shipmate itself.

**Architecture:** `skills/verify/SKILL.md` is a thin read-only doctor (ajv schema validation + `version-sync-check.sh`). Docs are a first-class deliverable: README is SEO-load-bearing (keyword-rich H1 + opening), the rest is beginner-first with worked examples. Dogfood exercises the real end-to-end flow on a real repo, then bootstraps shipmate's own first release.

**Tech Stack:** SKILL.md via skill-creator, Markdown docs, ajv, the Plan-1/2/3 scripts.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/verify/SKILL.md` | Read-only drift doctor (schema + version-sync) |
| `README.md` | SEO-load-bearing landing page |
| `docs/quickstart.md` | install → init → first release, step by step |
| `docs/languages/js.md`, `docs/languages/python.md` | per-language setup |
| `docs/positioning.md` | honest vs release-please/changesets (long-tail SEO) |
| `CONTRIBUTING.md`, `SECURITY.md` | governance + security policy |

---

## Task 1: `skills/verify/SKILL.md`

**Files:**
- Create: `skills/verify/SKILL.md`

- [ ] **Step 1: Write `skills/verify/SKILL.md`** (author via skill-creator)

````markdown
---
name: verify
description: Check a shipmate-configured repo for version drift — validate .shipmate.json against its schema and confirm every contract's locations agree on the same version. Use to run shipmate verify, diagnose drift, or check release config health. Read-only.
---

# shipmate:verify — drift doctor (read-only)

This skill never writes. Scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`.

1. **Schema check** — validate `.shipmate.json`:
   `npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s ${CLAUDE_PLUGIN_ROOT}/schemas/shipmate-config.schema.json -d .shipmate.json`
2. **Beyond-schema check** — `validate-config.sh .shipmate.json` (primaryContract tagged,
   regex single-group, tag uniqueness, locations readable).
3. **Drift check** — `version-sync-check.sh .shipmate.json`.

Report each result in plain language. If drift is found, name the contract, the files, and
the differing versions, and suggest the fix (bump the lagging file, or run `shipmate:release`).
Define "drift" for the reader: the declared files no longer agree on one version.
````

- [ ] **Step 2: Lint frontmatter + smoke the checks against a fixture**

Run:
```bash
python3 - <<'PY'
import re, yaml
fm=yaml.safe_load(re.match(r'^---\n(.*?)\n---\n', open('skills/verify/SKILL.md').read(), re.S).group(1))
assert fm['name']=='verify' and len(fm['description'])>40
print("frontmatter OK")
PY
( cd examples/js-single-contract && cp expected.shipmate.json .shipmate.json &&
  bash ../../scripts/version-sync-check.sh .shipmate.json && rm .shipmate.json )
```
Expected: `frontmatter OK`, then `version-sync-check: all contracts consistent`

- [ ] **Step 3: Commit**

```bash
git add skills/verify/SKILL.md
git commit -m "feat: add shipmate:verify skill (read-only drift doctor)"
```

---

## Task 2: README (SEO-load-bearing)

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`** — keyword-rich H1 + opening, aligned with the GitHub description/topics.

```markdown
# shipmate — a Claude Code release plugin (curated changelog, SemVer, multi-version repos)

**shipmate** cuts software releases from inside Claude Code. It writes a *curated*
changelog (the why, not just the what), classifies the **SemVer** bump with judgment, and
handles repos that carry **more than one independent version** (multi-contract) — all
**local-first**, with **no Conventional Commits** and no CI bot required. Works on JS/TS
and Python repos.

> If you want fully-automated, commit-driven releases in CI, use
> [release-please](https://github.com/googleapis/release-please) or
> [changesets](https://github.com/changesets/changesets). shipmate is for maintainers who
> release by hand and want a high-quality changelog + a human checkpoint. See
> [docs/positioning.md](docs/positioning.md).

## What you get
- **`shipmate:init`** — onboard any repo: discover where versions live, write `.shipmate.json`.
- **`shipmate:release`** — bump, author the changelog, run guards, then tag + GitHub release after one checkpoint.
- **`shipmate:verify`** — catch version drift across your files.

## Install
(Standard Claude Code plugin install — see [docs/quickstart.md](docs/quickstart.md).)

## Quick start
See **[docs/quickstart.md](docs/quickstart.md)** — install → `init` → first `release`, step by step.

## How it compares
See **[docs/positioning.md](docs/positioning.md)** — an honest comparison with release-please, changesets, and semantic-release, including when *not* to use shipmate.

## License
MIT.
```

- [ ] **Step 2: Verify SEO/link integrity**

Run:
```bash
grep -q "^# shipmate — a Claude Code release plugin" README.md
for l in docs/positioning.md docs/quickstart.md; do grep -q "$l" README.md || echo "MISSING LINK $l"; done
```
Expected: H1 present; no `MISSING LINK` output

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add SEO-load-bearing README"
```

---

## Task 3: Quickstart (beginner-first)

**Files:**
- Create: `docs/quickstart.md`

- [ ] **Step 1: Write `docs/quickstart.md`** — every term defined, expected output shown.

```markdown
# Quickstart

This guide takes you from zero to your first shipmate release. No prior knowledge of
release tooling needed. New terms are defined the first time they appear.

## 1. Install the plugin
Install the `shipmate` plugin in Claude Code (marketplace install). Then open your repo.

## 2. Onboard the repo — `shipmate:init`
Run **init**. It scans your repo for places a version number lives (your `package.json`
or `pyproject.toml`, docs that say "currently 1.2.3", …) and proposes a **contract** — a
set of files that should always carry the *same* version. You confirm, and it writes a
small `.shipmate.json`.

Expected: a `.shipmate.json` file in your repo root, plus an offer to add a "drift guard"
(see below) and branch protection.

> **Drift** = two files that are supposed to share a version no longer match (you bumped
> one and forgot the other). The drift guard catches it before it ships.

## 3. Write what changed
In `CHANGELOG.md`, under `## [Unreleased]`, jot what changed — in plain words, the *why*.
shipmate turns this into the release notes; it does not invent them from commit messages.

## 4. Cut the release — `shipmate:release`
Run **release**. It:
1. checks your repo is in a safe state,
2. proposes a **SemVer** bump — `MAJOR.MINOR.PATCH`: breaking change → MAJOR, new feature
   → MINOR, fix → PATCH — and explains why,
3. bumps every file in the contract, finalizes the changelog,
4. (if your `main` is protected) opens a pull request and waits for you to merge,
5. shows a recap and asks **once** for go/no-go,
6. on go: creates the git **tag** and the GitHub release.

Expected at the checkpoint: a recap of the version, the changelog section, and the tag.
Nothing irreversible happens before you say go.

## 5. Check for drift anytime — `shipmate:verify`
Run **verify** to confirm all your version files still agree.
```

- [ ] **Step 2: Verify jargon-defined + commit**

Run: `for t in drift contract SemVer tag; do grep -qi "$t" docs/quickstart.md || echo "MISSING $t"; done`
Expected: no `MISSING` output
```bash
git add docs/quickstart.md
git commit -m "docs: add beginner-first quickstart"
```

---

## Task 4: Per-language guides + positioning

**Files:**
- Create: `docs/languages/js.md`
- Create: `docs/languages/python.md`
- Create: `docs/positioning.md`

- [ ] **Step 1: `docs/languages/js.md`**

```markdown
# shipmate on a JS/TS repo

Your version lives in `package.json` (`"version"`). A typical single-contract config:

```json
{ "remote": "origin", "protectedBranch": "main", "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [ { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
    "locations": [ { "file": "package.json", "json": ".version" } ] } ] }
```

Have a version repeated in docs (e.g. "currently `1.2.3`")? Add a `regex` location with one
capture group around the version. `shipmate:init` proposes these for you.
```

- [ ] **Step 2: `docs/languages/python.md`**

```markdown
# shipmate on a Python repo

Your version lives in `pyproject.toml` (`[project] version`). A single-contract config:

```json
{ "remote": "origin", "protectedBranch": "main", "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [ { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
    "locations": [ { "file": "pyproject.toml", "toml": "project.version" } ] } ] }
```

A TS app shipping together with its Python agent under one version? Put both
`package.json` and `pyproject.toml` as locations of the **same** contract.
```

- [ ] **Step 3: `docs/positioning.md`** (honest comparison, long-tail SEO)

```markdown
# shipmate vs release-please, changesets, semantic-release

shipmate is **not** a competitor to these — it fills a different niche.

| | release-please / semantic-release | changesets | **shipmate** |
|---|---|---|---|
| Driven by | Conventional Commits, in CI | changeset files + CI | LLM judgment in Claude Code |
| Changelog | machine-generated from commits | from changeset files | **curated** (the *why*) |
| Commit convention required | yes | partial | **no** |
| Runs | CI bot, async | CI, async | **local-first, one human checkpoint** |
| Multi independent versions | per-package (monorepo) | per-package | **per-contract** (incl. schema-style) |

## Use release-please / changesets when
- You want hands-off, fully automated releases in CI.
- Your team already uses Conventional Commits.
- You have a multi-package monorepo with independent package versions.

## Use shipmate when
- You release by hand and want a **high-quality changelog**, not a commit dump.
- You refuse to adopt a commit convention or a CI release bot.
- Your repo has **two version contracts** (e.g. a kit version + a rarely-moving schema version).

shipmate does not do registry publishing or monorepo multi-package releases in v0.
```

- [ ] **Step 4: Validate the embedded JSON configs parse + commit**

Run:
```bash
for f in docs/languages/js.md docs/languages/python.md; do
  python3 - "$f" <<'PY'
import sys,re,json
blocks=re.findall(r'```json\n(.*?)```', open(sys.argv[1]).read(), re.S)
for b in blocks: json.loads(b)
print(sys.argv[1], "json OK")
PY
done
```
Expected: both `json OK`
```bash
git add docs/languages docs/positioning.md
git commit -m "docs: add per-language guides + honest positioning page"
```

---

## Task 5: CONTRIBUTING + SECURITY

**Files:**
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`

- [ ] **Step 1: `CONTRIBUTING.md`**

```markdown
# Contributing

## Dev setup
```bash
./setup-dev.sh   # routes git hooks to hooks/ (pre-commit: shellcheck + ajv)
```

## Workflow
`main` is protected. Branch (`feat/…`, `fix/…`, `docs/…`, `ci/…`), open a PR, get CI green
(shellcheck + schema + bats), squash-merge. Tags are pushed after a release PR merges.

## Before a PR
```bash
shellcheck scripts/*.sh hooks/pre-commit setup-dev.sh
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json
bats tests
```

Run `/security-review` on your branch before requesting review (shipmate dogfoods the
secure-by-default review it ships).

## Adding a secret pattern to `scan-secrets.sh`
Every new pattern needs a matching bats case in `tests/scan-secrets.bats`.
```

- [ ] **Step 2: `SECURITY.md`**

```markdown
# Security Policy

## Reporting
Report vulnerabilities privately via GitHub Security Advisories on this repo.

## Trust boundaries
- shipmate skills propose; only the deterministic `scripts/*.sh` perform irreversible
  actions, each behind a guard that can hard-fail.
- shipmate edits only version literals + `CHANGELOG.md` (and, at init, scaffolded
  hooks/CI). It never edits source code.
- Release notes are scanned for secret-shaped strings before publish (`scan-secrets.sh`).
- shipmate never force-pushes or re-points a published tag.

## Supported versions
The latest minor line is supported.
```

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md SECURITY.md
git commit -m "docs: add CONTRIBUTING + SECURITY"
```

---

## Task 6: Dogfood on explain-panel-skills (the two-contract case)

This runs in the **`~/dev/explain-panel-skills`** repo (a separate repo with protected
`main`) — all changes there go through its own PR.

- [ ] **Step 1: Run `shipmate:init` on explain-panel-skills**

In a Claude Code session in `~/dev/explain-panel-skills`, run `shipmate:init`. Expected
proposed `.shipmate.json`:
- contract `kit` (tag `v{version}`, `bumpFrom: changelog`) with four locations:
  `package.json` (`.version`), `.claude-plugin/plugin.json` (`.version`),
  `.claude-plugin/marketplace.json` (`.plugins[0].version`),
  `docs/install.md` (regex `currently \`([0-9]+\.[0-9]+\.[0-9]+)\``).
- contract `schema` (`tag: null`, `bumpFrom: manual`) with one location:
  `schemas/pipeline-map.schema.json` (`.properties.schemaVersion.const`).
- `primaryContract: kit`.

- [ ] **Step 2: Validate the generated config**

Run (in explain-panel-skills):
```bash
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s ~/dev/shipmate/schemas/shipmate-config.schema.json -d .shipmate.json
bash ~/dev/shipmate/scripts/validate-config.sh .shipmate.json
bash ~/dev/shipmate/scripts/version-sync-check.sh .shipmate.json
```
Expected: `valid`, `validate-config: OK`, `version-sync-check: all contracts consistent` (all four kit locations read `1.2.0`).

- [ ] **Step 3: Replace the hand-rolled version-sync CI with shipmate's drift guard**

In explain-panel-skills' `.github/workflows/validate-schemas.yml`, replace the manual
`PV=$(jq …)` version-comparison block with the `version-sync-check.sh` call (vendored to
`.shipmate/`). Update `docs/releasing.md` to point at `shipmate:release`. Open a PR there.

- [ ] **Step 4: Dry-run a release to prove the two-contract flow**

In explain-panel-skills, run `shipmate:release --dry-run`. Expected: it diffs since
`v1.2.0` (kit's last tag), proposes a bump for `kit` only (schema is `manual`), shows the
curated changelog plan, and writes nothing (`git status` clean afterwards).

- [ ] **Step 5: Record the dogfood outcome**

Add a short note to shipmate's `CHANGELOG.md [Unreleased]` that the two-contract flow was
validated on explain-panel-skills. Commit in the shipmate repo:
```bash
git add CHANGELOG.md
git commit -m "docs: record explain-panel-skills dogfood (two-contract flow validated)"
```

---

## Task 7: Bootstrap shipmate's own first release

- [ ] **Step 1: Generate shipmate's own `.shipmate.json`**

Run `shipmate:init` in `~/dev/shipmate`. Expected contract `kit` over `package.json`
(`.version`), `.claude-plugin/plugin.json` (`.version`), `.claude-plugin/marketplace.json`
(`.plugins[0].version`). Commit via PR.

- [ ] **Step 2: Bootstrap the first tag manually (chicken/egg)**

The first release cannot be cut by an unreleased shipmate. Set all three manifests to
`0.1.0`, finalize `CHANGELOG.md` `[0.1.0]`, then:
```bash
git checkout -b release/v0.1.0
# (bump manifests + changelog already done)
git push -u origin release/v0.1.0
gh pr create --title "release: v0.1.0" --body "First shipmate release (bootstrap)."
# after CI green + merge:
git checkout main && git pull
git tag -a v0.1.0 -m "v0.1.0 — first release"
git push origin v0.1.0
gh release create v0.1.0 --title "v0.1.0" --notes "$(bash scripts/changelog-release.sh extract CHANGELOG.md 0.1.0)"
```

- [ ] **Step 3: Verify self-consistency**

Run:
```bash
bash scripts/version-sync-check.sh .shipmate.json
```
Expected: `all contracts consistent` (all manifests read `0.1.0`).

- [ ] **Step 4: From v0.1.1 on, shipmate releases shipmate**

Document in `CONTRIBUTING.md` that subsequent releases use `shipmate:release` itself.
```bash
git add CONTRIBUTING.md
git commit -m "docs: note shipmate self-releases from v0.1.1"
```

---

## Self-Review

**Spec coverage (verify/docs/dogfood portion):** verify two checks (§7.3, m4) → Task 1 ✓;
beginner-first docs + SEO requirement (§10) → Tasks 2–4 ✓; positioning page (§10) → Task 4
✓; CONTRIBUTING/SECURITY (§9) → Task 5 ✓; dogfood on explain-panel-skills incl. two-contract
`kit`+`schema` with `tag:null` (§12) → Task 6 ✓; shipmate self-dogfood + manual first-tag
bootstrap (§12) → Task 7 ✓.

**Placeholder scan:** docs are complete content; SKILL.md is prose with concrete commands.
No TBD/TODO.

**Type/name consistency:** verify calls `validate-config.sh` + `version-sync-check.sh`
(exact names from Plans 1–2). Dogfood config field names + the four explain-panel-skills
locations match its real files (`package.json`, `.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json` `.plugins[0].version`, `docs/install.md` regex,
`schemas/pipeline-map.schema.json` `.properties.schemaVersion.const`). `changelog-release.sh
extract` used in Task 7 matches Plan 3 Task 3.

**v0 complete after this plan:** three skills, all guard + mechanical scripts, schema,
templates, beginner-first + SEO docs, two fixtures, and a proven two-contract dogfood +
shipmate's own first release.
