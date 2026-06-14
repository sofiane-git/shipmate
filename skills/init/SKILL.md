---
name: init
description: Onboard a repo to shipmate — discover version locations, propose and confirm a contract map, write .shipmate.json, and optionally scaffold drift-guard and branch protection. Use when setting up shipmate on a new repository, running shipmate init, or preparing a repo for shipmate releases.
---

# shipmate:init — onboard a repository

You are onboarding the current repo to shipmate. Follow these phases in order. Never
overwrite without showing a diff. Locate scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`.

## Phase 1 — Discover
Run `discover-versions.sh` on the repo root. Present the candidate locations (file +
current version) as a table. If none found, ask the user where versions live.

## Phase 2 — Propose a contract map
Group the candidates into named contracts. Default: one contract `kit` over all
locations that share the same current version. If two groups carry *different* current
versions, propose them as separate contracts and ask which is the `primaryContract`
(must be a tagged one). Explain "contract" in plain language (a set of files that
version together).

## Phase 3 — Confirm
Show the proposed `.shipmate.json` and ask the user to confirm or correct: contract
names, which locations belong where, tag templates, `primaryContract`, `securityReview`.

## Phase 4 — Validate (before writing)
Write the proposed config to a temp file and run `validate-config.sh` on it. If it fails,
show the error in plain language and loop back to Phase 3. Do not write until it passes.

## Phase 5 — Write
Show the final `.shipmate.json` (dry-run preview) and, on approval, write it to the repo
root. If a `.shipmate.json` already exists, diff against it and merge — never blind
overwrite (idempotent re-run).

## Phase 6 — Offer the drift guard (opt-in)
Offer to wire `version-sync-check.sh` as: a pre-push hook (template
`pre-push-version-sync.sh`), and/or a CI step (template `ci-version-sync.yml`). Copy
`version-sync-check.sh` + `read-version.sh` into the repo's `.shipmate/` dir so the
hook/CI can call them. Explain drift with a concrete example.

## Phase 7 — Offer branch protection (three layers, opt-in)
For `protectedBranch`, offer each layer separately (templates `protect-main.sh`,
`github-branch-protection.sh`, and the CI required-check). State plainly that layer 2
(GitHub branch protection) is the real barrier. Also scaffold `CHANGELOG.md` from
`changelog-skeleton.md` if absent.

## Hard rules
- shipmate writes only what the config declares: `.shipmate.json`, scaffolded
  hooks/CI/templates, and (if absent) a CHANGELOG skeleton. It does not discover or edit
  source code on its own. Version locations are validated repo-relative (no absolute paths,
  no `..`, no symlink escape).
- Always preview before writing; always confirm before scaffolding.
