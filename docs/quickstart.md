# Quickstart

This guide takes you from zero to your first shipmate release. No prior knowledge of
release tooling needed. New terms are defined the first time they appear — and every
technical term shipmate uses (tag, release, contract, SemVer, drift, …) has a full
plain-language entry in the [Glossary](./glossary.md).

## 1. Install the plugin
Install the `shipmate` plugin in Claude Code (marketplace install). Then open your repo.

## 2. Onboard the repo — `shipmate:init`
Run **init**. It scans your repo for places a version number lives (your `package.json`
or `pyproject.toml`, docs that say "currently 1.2.3", …) and proposes a **contract** — a
set of files that should always carry the *same* version. You confirm, and it writes a
small `.shipmate.json`.

Expected: a `.shipmate.json` file in your repo root, plus an offer to add a "drift guard"
(see below) and branch protection.

> **Drift** = two files that are supposed to share a version no longer match (you bumped
> one and forgot the other). The drift guard catches it before it ships.

## 3. Write what changed
In `CHANGELOG.md`, under `## [Unreleased]`, jot what changed — in plain words, the *why*.
shipmate turns this into the release notes; it does not invent them from commit messages.

## 4. Cut the release — `shipmate:release`
Run **release**. It:
1. checks your repo is in a safe state,
2. proposes a **SemVer** bump — `MAJOR.MINOR.PATCH`: breaking change → MAJOR, new feature
   → MINOR, fix → PATCH — and explains why,
3. bumps every file in the contract, finalizes the changelog,
4. (if your `main` is protected) opens a pull request and waits for you to merge,
5. shows a recap and asks **once** for go/no-go,
6. on go: creates the git **tag** and the GitHub release.

Expected at the checkpoint: a recap of the version, the changelog section, and the tag.
Nothing irreversible happens before you say go.

## 5. Check for drift anytime — `shipmate:verify`
Run **verify** to confirm all your version files still agree.
