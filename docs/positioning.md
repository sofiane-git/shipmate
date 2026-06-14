# shipmate vs release-please, changesets, semantic-release

shipmate is **not** a competitor to these — it fills a different niche.

| | release-please / semantic-release | changesets | **shipmate** |
|---|---|---|---|
| Driven by | Conventional Commits, in CI | changeset files + CI | LLM judgment in Claude Code |
| Changelog | machine-generated from commits | from changeset files | **curated** (the *why*) |
| Commit convention required | yes | partial | **no** |
| Runs | CI bot, async | CI, async | **local-first, one human checkpoint** |
| Multi independent versions | per-package (monorepo) | per-package | **per-contract** (incl. schema-style) |

## Use release-please / changesets when
- You want hands-off, fully automated releases in CI.
- Your team already uses Conventional Commits.
- You have a multi-package monorepo with independent package versions.

## Use shipmate when
- You release by hand and want a **high-quality changelog**, not a commit dump.
- You refuse to adopt a commit convention or a CI release bot.
- Your repo has **two version contracts** (e.g. a kit version + a rarely-moving schema version).

shipmate does not do registry publishing or monorepo multi-package releases in v0.
