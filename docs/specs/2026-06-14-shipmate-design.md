# shipmate — design spec

- **Date:** 2026-06-14
- **Status:** approved (brainstorming), pending implementation plan
- **Author:** Sofiane Conan

## 1. Summary

shipmate is a **Claude Code plugin** that cuts releases across many repositories. It
is the **judgment layer** of a release: it authors a curated changelog, classifies the
SemVer bump with domain nuance, and reasons about repositories that carry more than one
independent version. It then performs the mechanical work (bump version literals, tag,
GitHub release) itself, **local-first**, behind a single human checkpoint (§4).

It is distributed as a plugin (like a normal Claude Code marketplace plugin) and is
installed once, then used on any consuming repo via three skills — `init`, `release`, and
`verify` (a read-only drift doctor).

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
- **shipmate is not a GitHub Action.** It runs in a Claude Code session and drives the
  release locally. In PR mode it *does* wait on the consuming repo's own CI before the
  release is merged — that wait is the consuming repo's CI, not shipmate-as-CI. (See §4
  for the "local-first" framing.)
- **No monorepo / multi-package matrix in v0.** Single-package repos plus the
  multi-*contract* case only. Monorepo support is a documented extension point (§13).
- **No `npm publish` (or other registry publish) in v0.** A future opt-in per-contract
  publish step is a documented extension (§13), not part of v0.
- **No dependency on release-please.** shipmate is standalone. (Rationale in §4.)
- **shipmate never edits source code.** It writes only: version literals (in the declared
  contract locations), `CHANGELOG.md`, and — at `init` only — generated config/hooks. It
  does not touch application or library source. This is a hard boundary.

## 4. Why standalone (no release-please)

Once shipmate owns the changelog and owns the SemVer decision, release-please's two real
strengths — version inference from commits, and changelog generation — are removed.
What remains for it to do is bump version literals, open a PR, tag, and create a GitHub
release: `jq` writes plus `git tag` plus `gh release create`. Delegating that trivial
mechanic to release-please would import three structural frictions for no benefit:

1. **Extra async boundary** — release-please runs *its own* logic in CI, outside the
   session, adding a second asynchronous actor on top of the repo's own CI.
2. **Multi-contract mismatch** — release-please models a version *per package/path*; a
   second contract that is not a package does not fit its manifest.
3. **Dual source of truth** — `.shipmate.json` plus release-please config/manifest can
   diverge.

Doing the mechanic in-house removes all three. This is not "reinventing release-please's
value": the in-house part is `git tag` + `gh release` + literal bumping, which no one
treats as a moat. A well-tested standalone skill (shellcheck + bats + skill evals) is
its own form of "pro."

**"Local-first," not "fully synchronous."** shipmate does all reasoning and all file
edits locally, behind one checkpoint. It then offers two release modes:

- **`--no-pr` (direct):** for repos without a protected default branch — commit, tag, and
  release run start to finish in the session, fully synchronous.
- **PR mode (default for protected branches):** shipmate opens a release PR and **pauses**
  while the consuming repo's own CI runs and a human merges; it then resumes to tag and
  publish. The wait is bounded and human-gated. This is "local-first with a merge pause,"
  not "zero async" — the earlier framing was too strong and is corrected here.

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

The plugin is named **`shipmate`**; its skills are invoked as **`shipmate:init`**,
**`shipmate:release`**, **`shipmate:verify`**. (m5)

## 6. `.shipmate.json` — single source of truth

Lives in the consuming repo. Declares a list of **named contracts**. One contract = a
simple single-version repo; N contracts = the multi-version case. Everything else
(release-please-style config, what `release` protects) is derived from this file. It is
**generated/updated by `init`**, never hand-edited as a second source.

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

- **`$schema`** — points to a **stable** URL (the `main` branch raw schema) or a
  repo-relative path, **not** a versioned release asset. Avoids the chicken/egg of the
  very first config existing before any shipmate release. (m1)
- **`primaryContract`** — names the contract whose tag defines "the last release" for the
  diff in `release` (§7.2). Removes ambiguity when several contracts (or `tag: null`
  contracts) exist. Must reference a **tagged** contract (`tag` ≠ null) — there is no
  "last tag" to diff from otherwise; `init` validates this. (m2)
- **`locations[].json` / `.toml` / `.regex`** — how to read/write the literal.
  - `json` = JSONPath, `toml` = dotted key.
  - `regex` must contain **exactly one capture group**, and that group's span is the
    version that gets replaced on write (same expression reads and writes). `init`
    validates the single-group rule before accepting a regex location. (M5)
- **`tag`** — template with placeholders `{version}` and `{name}` (e.g. `v{version}`,
  `schema-v{version}`). May be `null` for a versioned-but-untagged contract. When more
  than one contract is tagged, `init` validates that their rendered tag templates are
  **distinct** (no collision). (M6)
- **`bumpFrom: "changelog"`** — version decided from the curated changelog +
  diff (LLM judgment). **`"manual"`** — never auto-bumped by `release`; only moves when
  explicitly requested via `release --bump <name>` (§7.2). (M1)
- **`securityReview`** — pre-publish review policy: `"auto"` (default — run
  `/security-review` when the release diff touches code, skip code-less releases),
  `"always"`, or `"off"`. Overridable per-invocation by `--security-review` /
  `--no-security-review` (§7.2).

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
5. **Offer to wire the drift guard** (`version-sync-check.sh`) into the consuming repo, as
   an explicit opt-in — both levels offered, user picks:
   - a **pre-push git hook** (local, instant feedback before a push leaves the machine),
   - and/or a **CI snippet** (a ready-to-paste GitHub Actions step that fails a PR if any
     contract's locations disagree — server-side, blocks the merge).
   This is the generalized form of the hand-rolled version comparison many repos already
   carry in CI. It is a first-class, documented `init` step, not an afterthought.
6. **Offer branch-protection (three layers, each opt-in)** for `protectedBranch` —
   defense in depth, mirroring the explain-panel-skills setup (§8.1):
   - a **local `protect-main` hook** (denies direct commit/push — convenience, bypassable),
   - **GitHub branch protection** via `gh api` (server-side gate — the real barrier),
   - **required status checks** (CI gates the PR merge; it does not block a push).
   See §8.1 for which layer actually enforces. Also scaffold an OSS-standard
   `CHANGELOG.md` skeleton if absent.
7. **Idempotent re-run:** never blind-overwrite. Diff against existing `.shipmate.json`
   and merge, surfacing changes for confirmation.

`init` supersedes any pre-existing manual release runbook and version-sync CI in the
consuming repo. Skills locate their helper scripts via `${CLAUDE_PLUGIN_ROOT}` (the
plugin install root), never a hardcoded path. (m3)

### 7.2 `release` — cut a release (state machine)

`release` is a state machine, not a loop. States run in order; any guard failure in
PRE-FLIGHT aborts before a single irreversible action. A `--dry-run` flag (I5) runs every
state up to — but not including — `PUBLISH`, printing the full plan and writing nothing.

```
                 ┌─────────────┐
                 │  PRE-FLIGHT │  all guards run here, before anything irreversible (M2,M3)
                 └──────┬──────┘
                        │ all pass
                 ┌──────▼──────┐
                 │   PLAN      │  diff since primaryContract's last tag (m2);
                 │             │  classify SemVer per contract (skip bumpFrom:manual
                 │             │  unless --bump <name>, M1); author curated CHANGELOG;
                 │             │  security review per policy (auto: run /security-review
                 │             │  when diff touches code), findings surfaced at CHECKPOINT
                 └──────┬──────┘
                        │ user sees plan  ── --dry-run stops here ──►
                 ┌──────▼──────┐
                 │ LOCAL-WRITE │  bump contract locations; restructure CHANGELOG
                 │             │  ([Unreleased] → [X.Y.Z] — date, fresh [Unreleased],
                 │             │  compare links); local commit. All reversible.
                 └──────┬──────┘
            ┌───────────┴───────────┐
       --no-pr (C2)            PR mode (default for protectedBranch)
            │                       │
     ┌──────▼──────┐         ┌──────▼──────┐
     │  (no PR)    │         │   PR-WAIT   │  gh pr create; PAUSE while the consuming
     │             │         │             │  repo's CI runs and a HUMAN merges (C1).
     │             │         │             │  shipmate detects the merge, then resumes.
     └──────┬──────┘         └──────┬──────┘
            └───────────┬───────────┘
                 ┌──────▼──────┐
                 │  CHECKPOINT │  pre-PUBLISH secret-scan on the authored notes; then a
                 │             │  single gate: full recap (bumps, changelog section,
                 │             │  tag plan, remote, branch). One explicit go/no-go
                 │             │  BEFORE the first irreversible action.
                 └──────┬──────┘
                        │ go
                 ┌──────▼──────┐
                 │   PUBLISH   │  tag (annotated) per tagged contract; push tag(s);
                 │             │  gh release create with notes extracted VERBATIM from
                 │             │  the curated CHANGELOG section.
                 └─────────────┘
```

**PRE-FLIGHT guards** (deterministic scripts, always on, cannot be reasoned past — M2).
These depend on nothing the run authors, so they execute first:

- **Preconditions** (`check-preconditions.sh`, M3): working tree clean, branch up to date
  with its base, `gh` authenticated, remote reachable. Abort on any failure.
- **Tag not already published** (`check-tag-unpushed.sh`): if a contract's rendered tag
  already exists on the remote, stop. Never `-f`. (No re-pointing a published tag.)
- **Remote verified** (`verify-remote.sh`): remote URL and target branch match
  `.shipmate.json` before any push.
- **Version-sync** (`version-sync-check.sh`): all locations of each contract currently
  agree, before any bump.

**Pre-PUBLISH guard** — runs after the notes are authored, before the first irreversible
action (still satisfies M2: nothing irreversible has happened yet):

- **Secret scan** (`scan-secrets.sh`): the curated CHANGELOG section that will become the
  release notes is scanned for secret-shaped strings. It cannot run in PRE-FLIGHT because
  the section does not exist until PLAN authors it; it runs at CHECKPOINT, gating PUBLISH.

**Security review — secure by default** (`securityReview` policy, §6): at PLAN, shipmate
**reuses the existing `/security-review` skill** on the diff since the last tag — it does
not reimplement scanning. The default policy is **`auto`**: the review runs whenever the
release diff **touches code**, and is **skipped silently for code-less releases**
(docs / changelog / version-bump only) so trivial releases pay nothing — which avoids
training the maintainer to disable it reflexively. Policy is `auto` | `always` | `off` in
`.shipmate.json`, overridable per run with `--security-review` / `--no-security-review`.
Findings are **advisory**, surfaced to the human at CHECKPOINT before the go/no-go; they
do not hard-block. This complements the deterministic `scan-secrets.sh` (narrow) with a
broader LLM review at the natural pre-publish moment. Scope boundary: shipmate stays a
release tool — it does not become a code-review product, and it does **not** generate
security-review tooling for consuming repos (their choice).

**Branch discipline** (M2/Q1): in PR mode `release` never commits or tags directly on
`protectedBranch`; it works on a `release/*` branch, and only the **tag** is pushed
directly after merge (tags are exempt from branch protection — see §8.1).

**Reversibility ladder.** In PR mode the human merges the release PR *before* CHECKPOINT,
so the version bump reaches `protectedBranch` before the go/no-go. That is deliberate: a
merge is **revertible** (`git revert` / revert the PR), whereas the git tag and GitHub
release are **policy-immutable**. CHECKPOINT therefore gates only the immutable artifacts;
its recap states plainly that the PR is already merged and it is confirming **tag +
release** on the merged commit. A no-go here cleans up the (un-pushed) tag and, if the
maintainer wants, guides a revert of the merge.

**Rollback / abort** (M4): `release` journals each completed step. On a guard failure, a
no-go at CHECKPOINT, or an error mid-flight, it offers a cleanup matched to how far it got
— delete the local tag, reset/delete the `release/*` branch, restore `CHANGELOG.md`, or
guide a revert of a merged PR. The git tag and GitHub release (the only policy-immutable
artifacts) are ordered last precisely so a failure cannot leave a half-published release.

### 7.3 `verify` — drift doctor

Read-only. Validates `.shipmate.json` against its schema and confirms every location of
each contract agrees on the same version. Catches drift between the single source of
truth and the actual files.

`verify` runs **two checks** (m4): (1) **schema validation** of `.shipmate.json` against
`shipmate-config.schema.json` — skill-only; (2) **version-sync** across each contract's
locations — the half implemented by `version-sync-check.sh` and **reused** by the
pre-push hook / CI step.

**Manual vs automatic — important distinction.** The `verify` *skill* never auto-runs; a
skill is always manually invoked (the interactive doctor). The *automatic* equivalent is
the deterministic `version-sync-check.sh` script, which `init` can wire into the consuming
repo as an **opt-in pre-push hook and/or a CI step**. So: skill = on-demand inspection;
script = unattended guard. They share the version-sync check.

### 7.4 Changelog model with multiple contracts (C3)

The repo keeps **one** `CHANGELOG.md`, owned by shipmate:

- **Single tagged contract (the common case):** standard Keep-a-Changelog timeline; the
  primary contract's version is the section heading.
- **Multiple contracts:** the timeline is driven by the **primary (tagged) contract**.
  Entries that belong to a non-primary contract are **prefixed with the contract name**
  (e.g. `**[schema]** …`). When a non-primary contract bumps (e.g. a `schemaVersion`
  change shipping a migrator), it is recorded as a sub-note under the primary version
  section, **linking to its migrator** (e.g. `migrate/…`). The primary timeline stays the
  spine; secondary contracts annotate it rather than forking the file.

## 8. Security model

- **No force-push of tags, ever.**
- **Secret scan** before any GitHub release notes are published (maintained, *tested*
  pattern set).
- **`init` dry-run**: print generated `.shipmate.json` before writing.
- **Least privilege**: any scaffolded workflow uses a minimal `permissions:` block; docs
  describe the minimal token scope.
- **Path safety** in discovery: resolve symlinks, reject locations resolving outside the
  repo root.
- **Preconditions** before any release work (clean tree, up to date, `gh` auth, remote
  reachable) — `check-preconditions.sh`.
- **Pre-publish security review — secure by default** — `securityReview: auto` runs the
  `/security-review` skill on the release diff whenever it touches code (skips code-less
  releases); `always`/`off` + `--security-review`/`--no-security-review` override.
  Advisory, surfaced at CHECKPOINT (§7.2).
- Trust boundary: SKILL prose can propose; only the deterministic scripts perform
  irreversible actions, and each has a guard that can hard-fail.

### 8.1 Branch-protection model (Q1, I2)

For a repo with a `protectedBranch`, `init` offers **three independent, opt-in layers** —
the same defense-in-depth shipmate's own reference consumer uses:

1. **Local `protect-main` hook** — denies `git commit` / `git push` issued directly on the
   protected branch (tag-only pushes excepted — see below). First, fastest gate. A hook is
   bypassable (`--no-verify`); it is a convenience guard, not the real barrier.
2. **GitHub branch protection** via `gh api` — the **real barrier**: server-side rejection
   of direct pushes, enforced even if the local hook is bypassed. This layer also declares
   which CI checks are **required** before a PR can merge.
3. **Required status checks (CI)** — the consuming repo's CI jobs, *referenced by* layer 2
   as required-to-merge. A CI run cannot **prevent** a direct push (the push already
   happened by the time it runs); its role is to gate the **PR merge**, not to block the
   push. Optionally a workflow can also flag an after-the-fact direct-to-protected commit
   as a failure (a signal, not a barrier).

Layer 2 is the one that actually enforces; layers 1 and 3 are convenience and merge-gating
respectively. `init` sets up all three but is explicit about which is the true barrier.

`release` honors this: in PR mode it never commits or tags on the protected branch, works
on a `release/*` branch, and pushes **only the tag** directly after merge — tags are not
branch-protected, which is intentional and matches established release practice. In
`--no-pr` mode (unprotected repos) none of this applies and the flow is fully local.

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
│   ├── check-preconditions.sh    # clean tree, up-to-date, gh auth, remote reachable
│   ├── verify-remote.sh
│   ├── scan-secrets.sh
│   ├── check-tag-unpushed.sh
│   └── version-sync-check.sh     # reused by verify skill + pre-push hook + CI
├── templates/
│   ├── changelog-skeleton.md
│   ├── protect-main.sh              # layer 1: local hook
│   ├── github-branch-protection.sh # layer 2: gh api configuration
│   ├── ci-version-sync.yml          # opt-in CI step (drift guard)
│   ├── pre-push-version-sync.sh     # opt-in pre-push hook (drift guard)
│   └── branch-protection-notes.md
├── schemas/
│   └── shipmate-config.schema.json
├── examples/
│   ├── js-single-contract/       # fixture + demo
│   └── python-single-contract/   # fixture + demo
├── hooks/
│   └── pre-commit                 # native bash dev hook (shellcheck/ajv/frontmatter); core.hooksPath, no husky
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

## 10. Documentation — beginner-first (v0 deliverable)

Docs are a first-class deliverable, not an afterthought, and they target the
**non-initiated developer** — someone who has never heard of SemVer contracts, drift, or
release tooling. This mirrors the beginner walkthrough style already used in
`explain-panel-skills`.

Requirements:

- **No bare jargon.** Every term a consuming dev meets — *drift*, *contract*, *SemVer
  bump*, *tag*, *checkpoint* — is defined in plain language at first use.
- **`docs/quickstart.md`** — install → `init` → first `release`, step by step, with
  expected output shown at each step.
- **Commented walkthrough** — "here is every question `init` asks you, and *why* it asks
  it, and what to answer," modeled on the existing repo's walkthrough.
- **Every dev-facing feature documented with a concrete failure example** — for the
  version-sync guard: "here is exactly what breaks if two files drift, and how the guard
  catches it." Show the broken state, not just the happy path.
- **`docs/languages/{js,python}.md`** — copy-pasteable setup per language.
- **`docs/positioning.md`** — honest comparison vs release-please / changesets, so a
  reader can tell when *not* to use shipmate.

## 11. Testing strategy

- **`bats`** unit tests for every `scripts/*.sh` guard (deterministic → unit-testable).
- **skill-creator as the build-time authoring + eval method.** The three `SKILL.md`
  (`init`/`release`/`verify`) are authored through **skill-creator** to get correct
  frontmatter, best-practice structure, and — critically — **trigger-description tuning**
  so the three skills fire on the right phrases without overlapping. It also drives
  **skill evals** using the `examples/` repos as fixtures: a fixture repo in → expected
  `.shipmate.json` / expected bump decision out. skill-creator is a build/test tool only —
  **not** a runtime dependency or a shipmate feature; detailed usage belongs in the
  implementation plan (writing-plans).
- **CI (`ci.yml`)**: `shellcheck` all scripts, validate `shipmate-config.schema.json`,
  lint SKILL.md frontmatter, run bats + fixtures. Pin any action by commit SHA. **CI is
  the barrier** (required status checks); the pre-commit hook below is convenience only.
- **Dev pre-commit hook — native bash, no husky.** A committed `hooks/pre-commit` runs a
  fast subset of CI locally (`shellcheck`, `ajv` schema validation, frontmatter lint),
  wired via `git config core.hooksPath hooks` in a one-line setup script. **No husky / no
  `lint-staged` / no `node_modules`**: shipmate is a bash + markdown + JSON repo, husky is
  a JS-app tool and would contradict the lightweight, dependency-light ethos — and shipmate
  already scaffolds plain bash hooks for consumers, so its own repo dogfoods the same
  mechanism. The hook is opt-in for contributors and documented in `CONTRIBUTING.md`; it
  speeds feedback but never replaces CI.
- `examples/` double as fixtures and as documentation/demos.
- **Acceptance criteria** (I6): per-skill, testable "definition of done" lives in the
  **implementation plan** (writing-plans step), not this spec — keeping the spec at the
  design level and the verifiable criteria with the execution.

## 12. Dogfood plan

`explain-panel-skills` becomes shipmate's first consumer:

- Run `init` there → generates `.shipmate.json` with two contracts (`kit` over the four
  version locations; `schema` over `schemaVersion`, `tag: null`).
- Its manual release runbook and version-sync CI check are **replaced** by shipmate.
- Its curated `CHANGELOG.md` quality is preserved (shipmate owns the changelog).
- The existing `protect-main` hook is kept (shipmate can also scaffold it).

shipmate also **dogfoods itself** (shipmate releases shipmate); bootstrap the first tag
manually (chicken/egg).

**Repo bootstrap (shipmate's own governance).** Protecting shipmate's `main` is a GitHub
**settings** step, not a CI-file edit: enable branch protection on `main` and mark the
`ci.yml` jobs as **required status checks**. The CI workflow runs the test jobs (§11);
branch protection references them as required-to-merge. This bootstrap belongs in the
implementation plan, performed once when the GitHub remote is created.

shipmate's own PRs run `/security-review` before merge (documented in `CONTRIBUTING.md`) —
dogfooding the secure-by-default review it exposes via `release` (`securityReview: auto`).

## 13. Extension points (not built in v0)

- **Monorepo / multi-package.** If a future repo needs per-package independent versioning
  across many `package.json`s, re-evaluate adapting `release-please` (manifest mode) as a
  pluggable mechanical backend behind the same `.shipmate.json` front end. The judgment
  layer stays; only the bump/tag engine would change.
- **Additional languages** (Rust `Cargo.toml`, etc.) behind the same generic discovery.
- **Registry publish** (npm, PyPI) as an opt-in per-contract step.

## 14. v0 scope

In: standalone plugin (`shipmate:init` / `:release` / `:verify`); `.shipmate.json` with N
contracts (`primaryContract`, `{name}`/`{version}` tag templates, single-capture regex
locations); JS/TS + Python discovery; curated changelog ownership incl. multi-contract
model; `release` state machine with PR mode + `--no-pr` + `--dry-run` + `--bump <name>` +
secure-by-default security review (`securityReview: auto`, reuses `/security-review`,
advisory, code-aware skip);
PRE-FLIGHT guards (preconditions, tag-unpushed, remote, version-sync) + pre-PUBLISH
secret-scan; journalled rollback; three-layer branch protection; drift guard wired as opt-in pre-push
hook and/or CI snippet; **beginner-first docs (quickstart + commented walkthrough)**;
bats + eval + CI; two example fixtures; dogfood on explain-panel-skills.

Out: monorepo, non-JS/Python languages, registry publish, shipmate-as-GitHub-Action,
Conventional Commits.

### Supported repo shapes (v0)

| Shape | Modeled as | v0 |
|---|---|---|
| **TS only** (one `package.json`) | one contract, one location | ✅ |
| **TS + Python agent, released together** (single shared version) | one contract, locations in **both** `package.json` and `pyproject.toml` | ✅ |
| **One repo, two independent contracts** (e.g. kit + schema) | N contracts, one tagged + one `tag: null` | ✅ |
| **TS + Python versioned independently** (separate cadences) | per-package monorepo | ❌ → §13 extension |

A "TS app + its Python agent" is covered as long as they ship under one version. Separate
release cadences for the two languages need the monorepo extension point.
