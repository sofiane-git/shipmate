# shipmate — design spec

- **Date:** 2026-06-14
- **Status:** approved (brainstorming), pending implementation plan
- **Author:** Sofiane Conan

## 1. Summary

shipmate is a **Claude Code plugin** that cuts releases across many repositories. It
is the **judgment layer** of a release: it authors a curated changelog, classifies the
SemVer bump with domain nuance, and reasons about repositories that carry more than one
independent version. It then performs the mechanical work (bump version literals, tag,
GitHub release) itself, locally and synchronously, behind a single human checkpoint.

It is distributed as a plugin (like a normal Claude Code marketplace plugin) and is
installed once, then used on any consuming repo via two skills plus a doctor command.

## 2. Why this exists / positioning

The release-tooling space is mature: `release-please`, `changesets`, and
`semantic-release` all automate versioning from **Conventional Commits** in CI. They are
excellent at *mechanical* release work and at machine-generated changelogs.

They are structurally weak at *judgment*:

- **Curated changelogs.** Commit-subject-derived changelogs are flat. They cannot
  explain the *why* of a change, the security context, or the user-facing nuance.
- **Nuanced SemVer.** "Tightening a schema to match an already-documented contract ships
  as a PATCH, not a MAJOR" is a judgment call a commit-convention parser cannot encode.
- **Multiple independent version contracts** in one repo (e.g. a kit version that bumps
  often, and a schema version that bumps rarely and ships a migrator).

shipmate occupies exactly that judgment niche, leveraging the LLM already present in a
Claude Code session. It does **not** compete with release-please on Conventional-Commits
automation, and it imposes **no commit convention** on the repo.

**Honest scope note.** This is a defensible *personal/niche* tool. We are not claiming a
large unmet OSS market. OSS viability is to be re-evaluated after dogfooding on a real
repo and after a separate search for higher-value gaps.

## 3. Non-goals (YAGNI)

- **No Conventional Commits requirement.** shipmate reads the working changelog and the
  diff; it does not parse commit subjects to infer versions.
- **No CI-driven automation.** shipmate runs in a Claude Code session, synchronously,
  with a human checkpoint. It is not a GitHub Action.
- **No monorepo / multi-package matrix in v0.** Single-package repos plus the
  multi-*contract* case only. Monorepo support is a documented extension point (§12).
- **No `npm publish` (or other registry publish) unless a repo opts in.**
- **No dependency on release-please.** shipmate is standalone. (Rationale in §4.)

## 4. Why standalone (no release-please)

Once shipmate owns the changelog and owns the SemVer decision, release-please's two real
strengths — version inference from commits, and changelog generation — are removed.
What remains for it to do is bump version literals, open a PR, tag, and create a GitHub
release: `jq` writes plus `git tag` plus `gh release create`. Delegating that trivial
mechanic to release-please would import three structural frictions for no benefit:

1. **Async boundary** — release-please runs in CI, outside the session, breaking the
   local/remote checkpoint model.
2. **Multi-contract mismatch** — release-please models a version *per package/path*; a
   second contract that is not a package does not fit its manifest.
3. **Dual source of truth** — `.shipmate.json` plus release-please config/manifest can
   diverge.

Doing the mechanic in-house removes all three. This is not "reinventing release-please's
value": the in-house part is `git tag` + `gh release` + literal bumping, which no one
treats as a moat. A well-tested standalone skill (shellcheck + bats + skill evals) is
its own form of "pro."

## 5. Architecture overview

```
consuming repo                      shipmate plugin (installed once)
──────────────                      ────────────────────────────────
.shipmate.json   ◄── written by ──  skills/init     (onboard a repo)
CHANGELOG.md     ◄── curated by ──  skills/release  (cut a release)
version files    ◄── bumped by  ──  skills/verify   (drift doctor)
git tag, release ◄── created by ──  scripts/*.sh    (deterministic guards)
```

- **SKILL.md files** do the reasoning (discovery proposals, changelog authoring, SemVer
  classification). Flexible, LLM-driven.
- **`scripts/*.sh`** do the deterministic guards and mechanical operations. A script
  failure **stops** the release regardless of model state. This is the robustness
  boundary (approach "B": skill reasons, scripts block).

## 6. `.shipmate.json` — single source of truth

Lives in the consuming repo. Declares a list of **named contracts**. One contract = a
simple single-version repo; N contracts = the multi-version case. Everything else
(release-please-style config, what `release` protects) is derived from this file. It is
**generated/updated by `init`**, never hand-edited as a second source.

```json
{
  "$schema": "https://github.com/sofiane-git/shipmate/releases/download/vX.Y.Z/shipmate-config.schema.json",
  "remote": "origin",
  "protectedBranch": "main",
  "contracts": [
    {
      "name": "kit",
      "tag": "v{version}",
      "bumpFrom": "changelog",
      "locations": [
        { "file": "package.json", "json": "$.version" },
        { "file": "pyproject.toml", "toml": "project.version" },
        { "file": "docs/install.md", "regex": "currently `([0-9]+\\.[0-9]+\\.[0-9]+)`" }
      ]
    },
    {
      "name": "schema",
      "tag": null,
      "bumpFrom": "manual",
      "locations": [
        { "file": "schemas/x.schema.json", "json": "$.properties.schemaVersion.const" }
      ]
    }
  ]
}
```

- **`locations[].json` / `.toml` / `.regex`** — how to read/write the literal in a
  structured or prose file. (`json` = JSONPath, `toml` = dotted key, `regex` = capture
  group 1 is the version.)
- **`tag: null`** — a versioned contract that gets no git tag (e.g. a schema version
  surfaced only in files and pinned URLs).
- **`bumpFrom: "changelog"`** — version decided from the curated changelog +
  diff (LLM judgment). **`"manual"`** — only bumps when explicitly asked (rare contracts).

`shipmate-config.schema.json` validates this file; `verify` checks all locations of a
contract currently agree on the same version.

## 7. Skills

### 7.1 `init` — onboard a repo

1. **Discover** candidate version locations across the repo (package.json,
   pyproject.toml, plugin manifests, prose "currently X.Y.Z", etc.) — JS/TS and Python in
   v0. Multi-language generic, but only those two are validated.
2. **Propose** the discovered contract map and **ask the user to confirm/correct** it.
3. **Verify** every proposed location of a contract currently holds the *same* version
   (catches a bad regex or a stale file before writing anything).
4. **Write** `.shipmate.json` (after a dry-run preview of the file).
5. **Optionally scaffold** branch-protection helpers (a `protect-main`-style hook) and an
   OSS-standard `CHANGELOG.md` skeleton if absent.
6. **Idempotent re-run:** never blind-overwrite. Diff against existing `.shipmate.json`
   and merge, surfacing changes for confirmation.

`init` supersedes any pre-existing manual release runbook and version-sync CI in the
consuming repo.

### 7.2 `release` — cut a release

1. **Read** the diff since the last tag and the current `[Unreleased]` changelog section.
2. **Classify** the SemVer bump per contract, using domain nuance (documented policy,
   e.g. "documented-contract tightening = PATCH"). Present the proposed bump + reasoning.
3. **Author / finalize** the curated `CHANGELOG.md` entry: restructure `[Unreleased]`
   into `[X.Y.Z] — YYYY-MM-DD`, insert a fresh empty `[Unreleased]`, update compare links.
4. **Bump** every contract's locations to the decided version(s) (structured + prose).
5. **Local commit** + create the release branch / PR (`gh pr create`); let the repo's CI
   run. All work so far is **local and reversible.**
6. **CHECKPOINT (single gate):** show a full recap (bumps, changelog section, tag plan,
   remote, branch). Require one explicit go/no-go **before the first remote/irreversible
   action.**
7. After go: tag the merge commit (annotated), push the tag, create the GitHub release
   with notes **extracted verbatim from the curated CHANGELOG section**.

Hard guards (scripts, always on, cannot be reasoned past):

- **Refuse to re-point a published tag.** If `vX.Y.Z` already exists on the remote, stop.
  Never `-f`.
- **Verify the remote** URL and target branch before any push.
- **Scan the release notes** for secret-shaped strings before publishing.
- **Version-sync check** across all locations of each contract before tagging.

### 7.3 `verify` — drift doctor

Read-only. Validates `.shipmate.json` against its schema and confirms every location of
each contract agrees on the same version. Catches drift between the single source of
truth and the actual files. Small, high ROI; usable in the consuming repo's CI.

## 8. Security model

- **No force-push of tags, ever.**
- **Secret scan** before any GitHub release notes are published (maintained, *tested*
  pattern set).
- **`init` dry-run**: print generated `.shipmate.json` before writing.
- **Least privilege**: any scaffolded workflow uses a minimal `permissions:` block; docs
  describe the minimal token scope.
- **Path safety** in discovery: resolve symlinks, reject locations resolving outside the
  repo root.
- Trust boundary: SKILL prose can propose; only the deterministic scripts perform
  irreversible actions, and each has a guard that can hard-fail.

## 9. Repo layout

```
shipmate/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── init/SKILL.md
│   ├── release/SKILL.md
│   └── verify/SKILL.md
├── scripts/
│   ├── discover-versions.sh
│   ├── verify-remote.sh
│   ├── scan-secrets.sh
│   ├── check-tag-unpushed.sh
│   └── version-sync-check.sh
├── templates/
│   ├── changelog-skeleton.md
│   ├── protect-main.sh
│   └── branch-protection-notes.md
├── schemas/
│   └── shipmate-config.schema.json
├── examples/
│   ├── js-single-contract/       # fixture + demo
│   └── python-single-contract/   # fixture + demo
├── .github/workflows/ci.yml
├── docs/
│   ├── specs/2026-06-14-shipmate-design.md
│   ├── quickstart.md
│   ├── languages/{js.md,python.md}
│   └── positioning.md            # honest "shipmate vs release-please/changesets"
├── CHANGELOG.md
├── CONTRIBUTING.md
├── SECURITY.md
├── LICENSE                       # MIT
└── README.md
```

## 10. Testing strategy

- **`bats`** unit tests for every `scripts/*.sh` guard (deterministic → unit-testable).
- **Skill evals** (via skill-creator) using the `examples/` repos as fixtures: a fixture
  repo in → expected `.shipmate.json` / expected bump decision out.
- **CI (`ci.yml`)**: `shellcheck` all scripts, validate `shipmate-config.schema.json`,
  lint SKILL.md frontmatter, run bats + fixtures. Pin any action by commit SHA.
- `examples/` double as fixtures and as documentation/demos.

## 11. Dogfood plan

`explain-panel-skills` becomes shipmate's first consumer:

- Run `init` there → generates `.shipmate.json` with two contracts (`kit` over the four
  version locations; `schema` over `schemaVersion`, `tag: null`).
- Its manual release runbook and version-sync CI check are **replaced** by shipmate.
- Its curated `CHANGELOG.md` quality is preserved (shipmate owns the changelog).
- The existing `protect-main` hook is kept (shipmate can also scaffold it).

shipmate also **dogfoods itself** (shipmate releases shipmate); bootstrap the first tag
manually (chicken/egg).

## 12. Extension points (not built in v0)

- **Monorepo / multi-package.** If a future repo needs per-package independent versioning
  across many `package.json`s, re-evaluate adapting `release-please` (manifest mode) as a
  pluggable mechanical backend behind the same `.shipmate.json` front end. The judgment
  layer stays; only the bump/tag engine would change.
- **Additional languages** (Rust `Cargo.toml`, etc.) behind the same generic discovery.
- **Registry publish** (npm, PyPI) as an opt-in per-contract step.

## 13. v0 scope

In: standalone plugin; `init` + `release` + `verify`; `.shipmate.json` with N contracts;
JS/TS + Python discovery; curated changelog ownership; local/synchronous flow with one
checkpoint; deterministic guard scripts; security guards; bats + eval + CI; two example
fixtures; dogfood on explain-panel-skills.

Out: monorepo, non-JS/Python languages, registry publish, any CI-driven automation,
Conventional Commits.
