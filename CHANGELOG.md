# Changelog

All notable changes to this project will be documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
