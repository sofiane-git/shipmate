# shipmate — a Claude Code release plugin (curated changelog, SemVer, multi-version repos)

**shipmate** cuts software releases from inside Claude Code. It writes a *curated*
changelog (the why, not just the what), classifies the **SemVer** bump with judgment, and
handles repos that carry **more than one independent version** (multi-contract) — all
**local-first**, with **no Conventional Commits** and no CI bot required. Works on JS/TS
and Python repos.

> If you want fully-automated, commit-driven releases in CI, use
> [release-please](https://github.com/googleapis/release-please) or
> [changesets](https://github.com/changesets/changesets). shipmate is for maintainers who
> release by hand and want a high-quality changelog + a human checkpoint. See
> [docs/positioning.md](docs/positioning.md).

## What you get
- **`shipmate:init`** — onboard any repo: discover where versions live, write `.shipmate.json`.
- **`shipmate:release`** — bump, author the changelog, run guards, then tag + GitHub release after one checkpoint.
- **`shipmate:verify`** — catch version drift across your files.

## Install
(Standard Claude Code plugin install — see [docs/quickstart.md](docs/quickstart.md).)

## Quick start
See **[docs/quickstart.md](docs/quickstart.md)** — install → `init` → first `release`, step by step.

## How it compares
See **[docs/positioning.md](docs/positioning.md)** — an honest comparison with release-please, changesets, and semantic-release, including when *not* to use shipmate.

## License
MIT.
