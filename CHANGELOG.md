# Changelog

All notable changes to this project will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.1] — 2026-06-14

### Fixed
- **`shipmate:release` no longer halts after the security review.** It previously told the
  model to invoke the `/security-review` slash command mid-flow, but that command is a
  turn-terminating built-in: it took over and the release state machine never resumed past
  PLAN (no LOCAL-WRITE, PR, CHECKPOINT, or PUBLISH). The review now runs by **dispatching a
  subagent** via the Agent/Task tool, which reports findings back and lets the flow
  continue. This was a release-blocking bug.

### Changed
- **`shipmate:release` hardening around the PR pause.** The full release state (version,
  changelog section, tag plan, security findings) is now written to the **PR body** as the
  durable source of truth, so a pause that lasts days and resumes in a brand-new session
  reconstructs everything from git + the PR — no reliance on conversation memory or a temp
  file. Resume re-derives all state and confirms the PR is merged before continuing. The
  pause step ends its turn cleanly instead of busy-polling `gh pr view`, gives the user a
  precise hand-off (PR URL, version/tag, the exact review-then-merge steps, how to resume),
  and **explicitly forbids the agent from merging the PR** (`gh pr merge`) — merging is the
  human's review gate. The CHECKPOINT recap re-reads findings from the durable source and
  states plainly that the next step is irreversible.
- **`shipmate:verify`** degrades gracefully when `ajv-cli` cannot be fetched (offline / no
  JS host): it reports an environment limitation instead of a false config error and still
  runs the pure-shell drift checks.

### Added
- **Glossary** (`docs/glossary.md`) — a beginner-first, plain-language reference for every
  technical term shipmate uses (tag, release, contract, SemVer, drift, bumpFrom, locators,
  …), each entry pairing the definition with why it matters here. Linked from the README and
  the quickstart.

## [0.1.0] — 2026-06-14

### Added
- **Foundation**: plugin scaffold, `.shipmate.json` schema, deterministic guard scripts
  (`read-version`, `version-sync-check`, `check-tag-unpushed`, `verify-remote`,
  `check-preconditions`, `scan-secrets`), bats tests, CI (shellcheck + schema + bats +
  frontmatter).
- **`shipmate:init`** skill + `discover-versions.sh`, `validate-config.sh`, scaffolding
  templates (3-layer branch protection + drift guard), js/python fixtures.
- **`shipmate:release`** skill (state machine) + WRITE scripts (`write-version`,
  `render-tag`, `changelog-release`, `diff-touches-code`, `release-rollback`).
- **`shipmate:verify`** skill (read-only drift doctor).
- **Docs**: SEO README, beginner-first quickstart, per-language guides, honest positioning
  page, CONTRIBUTING, SECURITY.
- shipmate's own `.shipmate.json` (self-dogfood).

### Security
- **Path containment enforced** (`validate-config.sh`): version locations must be
  repo-relative — absolute paths, `..`, and symlink escapes outside the repo root are
  rejected. Makes the "shipmate only writes what you declare" guarantee code-backed.
- **`scan-secrets.sh` coverage expanded** to Google API keys, GitLab tokens, Stripe live
  keys, and npm tokens (each with a test).

### Notes
- Two-contract flow validated against the real `explain-panel-skills` repo (kit over four
  locations + a `tag: null` schema contract).
- Pre-release audit: no critical/high vulnerabilities; CI now shellchecks templates and
  validates example fixtures; added CODE_OF_CONDUCT, issue/PR templates.
