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
- Determine the diff since the **primaryContract**'s last tag. **If no tag exists yet (a
  repo's first-ever release), fall back to the diff from the repository's initial commit**
  (`git rev-list --max-parents=0 HEAD`) — i.e. the whole history. The curated
  `[Unreleased]` section drives the notes either way. This is NOT the shipmate chicken/egg
  (§7 of the design): any consuming repo's first release works because shipmate is already
  installed; it just has no prior tag to diff from.
- Classify the SemVer bump **per contract** using documented nuance (e.g. tightening an
  already-documented contract = PATCH, not MAJOR). Skip `bumpFrom: "manual"` contracts
  unless `--bump <name>` was passed. Present the proposed version(s) + reasoning.
- Author/finalize the curated `CHANGELOG.md [Unreleased]` content (the *why*, not just the
  *what*). For non-primary contracts in a multi-contract repo, prefix entries with the
  contract name and link any migrator.
- **Security review** per `securityReview` policy: if `always`, or if `auto` and
  `diff-touches-code.sh` returns 0 (code touched), run a security review of the release
  diff by **dispatching a subagent via the Agent/Task tool** (prefer a security-focused
  type such as `security-auditor`, else `general-purpose`); pass it the diff and ask for a
  findings-only report. Do NOT invoke the `/security-review` slash command here — it is a
  turn-terminating built-in and control would not return to this state machine. **Persist the
  subagent's findings to a scratch file `${TMPDIR:-/tmp}/shipmate-security-<version>.md`** so
  they survive the State 4 PR pause + any context compaction; CHECKPOINT re-reads this file.
  `--security-review`/`--no-security-review` override.
- If `--dry-run`: print the full plan (bumps, changelog, tag plan, review findings) and STOP.

## State 3 — LOCAL-WRITE (reversible)
- `write-version.sh` each location of each bumping contract to the decided version.
- `changelog-release.sh restructure CHANGELOG.md <version> <today>`.
- Commit locally on a `release/<version>` branch.

## State 4 — fork on mode
- **`--no-pr`** (no protected branch): skip to CHECKPOINT.
- **PR mode** (default when `protectedBranch` set): `gh pr create`. **Write the full release
  state into durable storage, never rely on this conversation surviving** — the pause may
  last days and resume in a brand-new session with no memory of this one:
  - Put into the **PR body** (the durable source of truth): the version(s), a copy of the
    `[<version>]` changelog section, the tag plan, and the security-review findings (or
    "none / skipped" + reason). Everything State 5 needs must be reconstructable from the PR
    body + git alone.
  - `${TMPDIR:-/tmp}/shipmate-security-<version>.md` is only a same-session cache, not the
    source — assume it is gone after a reboot.
- Then **end your turn** (do NOT busy-poll `gh pr view` — that blocks the turn). **The human
  merges the PR, never you**: do NOT run `gh pr merge` / squash / rebase under any
  circumstance. Merging is the human's review gate.
- **Be hyper-precise with the user when you pause.** Your message must state, explicitly:
  1. the exact PR URL,
  2. the version about to be released and the tag that will be created,
  3. that **they** must, in order: wait for CI to go green, review the diff and the security
     findings in the PR body, then **merge the PR themselves**,
  4. that nothing irreversible (tag/release) has happened yet and won't until after they
     come back,
  5. the **exact** way to resume: re-run `shipmate:release` (any session, even days later) —
     and that they should NOT delete the `release/<version>` branch or the PR meanwhile.
- **Resume (State 4-RESUME), re-derive everything from durable state — do not assume any
  conversation context:** read the version from `package.json`/the branch, the changelog
  section from `CHANGELOG.md`, and the security findings + tag plan from the PR body
  (`gh pr view <pr> --json state,mergedAt,body`). Confirm `mergedAt` is set (PR merged)
  before continuing; if not merged, tell the user precisely what is still pending and end the
  turn again. (The merge is reversible by revert; the tag/release are not.)

## State 5 — CHECKPOINT (single gate)
- Run the pre-PUBLISH guard: `changelog-release.sh extract CHANGELOG.md <version>` →
  pipe to `scan-secrets.sh`. Abort on a hit.
- Re-derive the security findings from the **durable** source: in PR mode read them back
  from the PR body (`gh pr view <pr> --json body`); the `${TMPDIR:-/tmp}/shipmate-security-
  <version>.md` cache is only a same-session fast-path. In `--no-pr` mode use the cache, or
  re-run the review if it is gone. Never silently drop findings because a temp file vanished.
- Show a full recap: bumps, the extracted changelog section, **the security-review findings
  (or "none / skipped" with the reason)**, tag plan, remote, branch, and (PR mode) that the
  PR is already merged. State plainly that the next step is irreversible (tag + release).
  Require ONE explicit go/no-go.
- On no-go: use `release-rollback.sh` to clean up (tag/branch/restore) and stop.

## State 6 — PUBLISH (irreversible, ordered last)
- For each tagged contract: create the annotated tag on the merged commit, push it.
- `gh release create <primary tag> --notes "<extracted changelog section, verbatim>"`.

## Hard rules
- Never `-f`/force-push a tag. Never re-point a published tag (PRE-FLIGHT guards this).
- shipmate edits only version locations + `CHANGELOG.md`; never source code.
- **Never merge the PR yourself** (`gh pr merge` and equivalents are forbidden). Merging is
  the human's review gate; you only open the PR and resume after they have merged it.
- In PR mode, never commit or tag directly on `protectedBranch`.
