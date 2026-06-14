# Pull request

**What & why**
Briefly: what this changes and the reason.

**Checklist**
- [ ] `shellcheck scripts/*.sh templates/*.sh hooks/pre-commit setup-dev.sh` clean
- [ ] `bats tests` green
- [ ] schema + fixtures validate (`npm run validate:schema`)
- [ ] new `scan-secrets.sh` pattern (if any) has a matching bats case
- [ ] `CHANGELOG.md` `[Unreleased]` updated for user-visible changes
- [ ] ran `/security-review` on this branch
- [ ] frozen design docs (`docs/specs/`, `docs/plans/`) NOT edited for implementation changes
