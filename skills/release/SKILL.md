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
- Determine the diff since the **primaryContract**'s last tag.
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
