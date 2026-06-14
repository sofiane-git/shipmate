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
