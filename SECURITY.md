# Security Policy

## Reporting
Report vulnerabilities privately via GitHub Security Advisories on this repo.

## Trust boundaries
- shipmate skills propose; only the deterministic `scripts/*.sh` perform irreversible
  actions, each behind a guard that can hard-fail.
- shipmate writes only: the version literals in the locations you **declare** in
  `.shipmate.json` (each validated to be repo-relative — no absolute paths, no `..`, no
  symlink escape — by `validate-config.sh`), `CHANGELOG.md`, and — at init — scaffolded
  hooks/CI. It does not discover or edit source code on its own; what it touches is exactly
  what your config declares.
- Release notes are scanned for secret-shaped strings before publish (`scan-secrets.sh`).
- shipmate never force-pushes or re-points a published tag.

## Supported versions
The latest minor line is supported.
