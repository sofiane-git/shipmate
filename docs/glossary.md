# Glossary

A plain-language reference for every technical term shipmate uses. No prior release
experience assumed — each entry says what the term means **and** why it matters here.
If you hit a word you don't know in the [Quickstart](./quickstart.md) or anywhere else,
look it up here.

Terms are grouped by topic. Use your browser's find (Ctrl/Cmd-F) to jump to one.

---

## Versioning basics

### Version
A label that identifies one specific state of your software, written as numbers like
`1.4.2`. Every time you ship changes, you give them a new version so people can tell
releases apart and know which one they have.

### SemVer (Semantic Versioning)
The rulebook shipmate follows for choosing the next version number. A version has three
parts — `MAJOR.MINOR.PATCH` (e.g. `2.5.1`) — and *which* part you increase carries
meaning:
- **MAJOR** (`2.x.x` → `3.0.0`) — you broke something. Code that used the old version may
  stop working. Also called a **breaking change**.
- **MINOR** (`2.5.x` → `2.6.0`) — you added a feature, but old usage still works.
- **PATCH** (`2.5.1` → `2.5.2`) — you fixed a bug; no new features, nothing breaks.

shipmate reads your changes and proposes which part to raise — that judgment is the whole
point of the tool. Official spec: <https://semver.org>.

### Bump
The act of raising a version number. "Bumping the MINOR" means going from `1.4.2` to
`1.5.0`. shipmate classifies the bump (MAJOR/MINOR/PATCH) for you and explains why.

### Breaking change
A change that forces the people using your software to adjust their own code or setup.
Breaking changes require a MAJOR bump under SemVer.

---

## The changelog

### Changelog
A human-readable file (`CHANGELOG.md`) that lists, version by version, what changed and
**why**. Readers consult it to decide whether to upgrade. shipmate writes a *curated*
changelog — explaining the reasoning, not just dumping a list of commits.

### Curated changelog
A changelog written for humans: it explains the *why* and the user-facing impact of a
change, not just the raw *what*. This is shipmate's core difference from tools that
auto-generate changelogs from commit messages.

### `[Unreleased]` section
The top part of `CHANGELOG.md` where you jot down changes as you make them, before they
have a version number. At release time shipmate turns this section into a dated, numbered
release entry. You keep adding to `[Unreleased]`; shipmate "graduates" it.

### Keep a Changelog
The widely-used format/convention shipmate's changelog follows (sections like *Added*,
*Changed*, *Fixed*, an `[Unreleased]` block). Reference: <https://keepachangelog.com>.

---

## Contracts — the central idea

A **contract** is the one concept shipmate is built around, so this section explains it
slowly. If you only read one part of this glossary, read this.

### Contract
A **set of files that all carry the same version number and are released together.**

Think of the version number as a *promise* you make to your users: "anything labelled
`1.x` works the same way." A contract is the group of files that share that one promise —
hence the name.

**The everyday case — one contract.** Most projects have a single version that lives in a
couple of files. A JavaScript library, for example, has its version in `package.json`, and
maybe repeated in a `README` badge. Those files form **one contract**. When you release,
they all move from `1.4.2` to `1.5.0` together. You rarely think about the word "contract"
at all — there's just *your version*.

**Why the concept exists at all.** Some repositories ship **two or more things that
version independently** (see *Multi-contract repo*). For those, "the version" is ambiguous
— which one? Naming each group as a contract removes the ambiguity: shipmate can bump, tag,
and changelog each one on its own. The idea scales down to nothing (one contract = just
your version) and up cleanly (many contracts = many independent promises).

**What a contract holds** (all declared in `.shipmate.json`):
- its **name** (e.g. `kit`, `cli`, `plugin`),
- its **version locations** — every file where its version number lives,
- a **tag template** — how to name its tag (e.g. `v{version}`),
- a **bump source** (`bumpFrom`) — how it decides its next version.

### Multi-contract repo
A repository that ships **more than one independent version** at once — e.g. a CLI at
`3.0.0` and a separate plugin at `0.7.1` living in the same repo. Each is its own contract:
shipmate versions, tags, and bumps each separately, and writes a changelog entry per
contract. (Overlaps with *monorepo* — a single repo holding multiple projects — but a
monorepo can still be one contract if everything shares one version.)

### `primaryContract`
In a multi-contract repo, the one contract shipmate treats as the "main" one — its tag
drives the GitHub release, and its history is the default diff shipmate looks at. Must be a
*tagged* contract. In a single-contract repo it's simply that one contract.

### Tagged vs untagged contract
A **tagged** contract gets a Git tag and a published release when it bumps — it's a thing
the outside world consumes. An **untagged** contract bumps its version in files but gets no
tag/release — useful for an internal component you track but don't publish on its own. The
`primaryContract` must always be tagged.

### `bumpFrom` — how a contract picks its next version
A per-contract setting telling shipmate *where the bump decision comes from*:
- **`changelog`** (the usual mode) — shipmate derives the SemVer bump
  (MAJOR/MINOR/PATCH) from the contract's curated `[Unreleased]` changelog content plus the
  diff, and proposes it with reasoning. You write *why* changed; shipmate decides *how big*.
- **`manual`** — shipmate does **not** bump this contract automatically; it's skipped unless
  you explicitly ask with `--bump <contract-name>`. Use it for a contract you only release
  on purpose, on its own schedule.

### Version location
A specific place where a version number physically lives — a line in `package.json`, a
`__version__` in a Python file, a field in `pyproject.toml`, etc. A contract lists all its
locations so shipmate can update them together and detect when they disagree (see *Drift*).

### Locator (json / toml / regex)
*How* shipmate finds the version inside a location's file. Each location names a **file**
plus exactly **one** of three locator types:
- **`json`** — a dotted path into a JSON file, e.g. `.version` in `package.json`, or
  `.plugins[0].version`. The cleanest option for JSON config.
- **`toml`** — a dotted path into a TOML file, e.g. `.project.version` in `pyproject.toml`.
- **`regex`** — a free-form search pattern with exactly **one capture group** — the
  parentheses `(...)` wrapping the version. Example: `__version__ = "(.*)"` finds `1.4.2`.
  Use it when the version lives in source code or an unusual format.

For common files `shipmate:init` proposes the right locator for you — you rarely write one
by hand.

---

## Config & repo health

### `.shipmate.json`
The config file at your repo root that declares your contracts, their version locations,
tag templates, and policies (like security review). `shipmate:init` creates it;
`shipmate:verify` checks it.

### Drift (version drift)
When the files inside one contract **stop agreeing on the same version** — e.g.
`package.json` says `1.5.0` but a source file still says `1.4.2`. Drift means a release
went half-applied somewhere. `shipmate:verify` detects it; the drift guard prevents it.

### Drift guard
An optional safety net `shipmate:init` can install — a pre-push hook and/or CI step that
blocks a push when version locations have drifted apart.

### Migrator
A short guide or script that helps users move across a breaking change (e.g. "how to
upgrade from 1.x to 2.0"). In multi-contract changelogs, shipmate links the relevant
migrator next to a breaking entry.

---

## Git & GitHub terms

### Repository (repo)
The folder, tracked by Git, that holds your project and its full history of changes.

### Commit
One saved snapshot of changes in Git, with a message describing it. History is a chain of
commits.

### Branch
A movable line of development. `main` is usually the official branch; you do work on a
separate branch and merge it back. shipmate creates a `release/<version>` branch for each
release.

### `main` / default branch
The primary branch that represents your "real", shippable code. Most teams protect it (see
below) so nothing lands without review.

### Remote
A copy of your repo hosted elsewhere (usually on GitHub), that your local copy syncs with.
Named `origin` by default. shipmate pushes tags and releases to the remote.

### Protected branch / branch protection
A GitHub setting that **blocks direct pushes** to an important branch (like `main`) and
forces changes to go through a Pull Request with passing checks. When you set
`protectedBranch`, shipmate routes its release through a PR instead of committing straight
to the branch.

### Pull Request (PR)
A GitHub request to merge one branch into another, with a page where people review the
diff, run CI, and discuss before it lands. shipmate opens a PR for the release; **you**
review and merge it — shipmate never merges for you.

### Merge
Combining a branch's changes into another branch. Merging a release PR into `main` is the
human's review gate in shipmate. A merge can be undone with a *revert*.

### Revert
A new commit that undoes a previous one. This is why a merge is considered "reversible" —
unlike a published tag/release, which is not.

### CI (Continuous Integration)
Automated checks (tests, linters, builds) that run on every PR or push, usually on GitHub
Actions. "Wait for CI to pass" means: let those checks finish green before merging.

### `gh`
The official GitHub command-line tool. shipmate uses it to open PRs and create releases.

---

## Releasing & tags

### Release
The act of publishing a new version: finalize the changelog, set the version numbers,
create a tag, and publish it (on GitHub) so users can get it. Also refers to the published
artifact itself (a "GitHub Release").

### Tag
A permanent name pinned to one exact commit, almost always a version like `v1.5.0`. Tags
are how a version becomes a fixed, referenceable point in history. **Publishing a tag is
effectively irreversible** — you should never move or force-overwrite a published tag,
which is why shipmate does tagging last, after your go-ahead.

### Annotated tag
A tag that stores extra metadata (author, date, message), as opposed to a bare
"lightweight" tag. shipmate creates annotated tags.

### Tag template
The pattern shipmate uses to build a tag name for a contract, e.g. `v{version}` →
`v1.5.0`, or `cli-{version}` in a multi-contract repo. Defined per contract in
`.shipmate.json`.

### GitHub Release
A GitHub page tied to a tag that presents the release notes (your extracted changelog
section) and downloadable assets. shipmate creates it as the final publish step.

---

## Safety & process terms

### Security review
A pass over the release diff to catch security problems (leaked secrets, risky code)
before publishing. shipmate runs it by dispatching a **subagent** (not the
turn-terminating `/security-review` slash command) and surfaces the findings at the
checkpoint. Controlled by the `securityReview` policy: `auto` (default — review when code
changed), `always`, or `off`.

### Secret scan
An automated check that looks for credentials accidentally committed (API keys, tokens,
passwords). shipmate scans the changelog text it's about to publish and aborts on a hit.

### Dry-run
Running the whole process **without making any changes** — shipmate prints exactly what it
*would* do (bumps, changelog, tags) and stops. Use `--dry-run` to preview safely.

### Reversible vs irreversible
shipmate orders its steps from undoable to permanent. Editing files, committing, and
merging a PR are **reversible**. Creating/pushing a tag and publishing a GitHub release are
**irreversible** — so they always come last, only after the human checkpoint.

### Checkpoint
The single human go/no-go gate near the end of a release. shipmate shows a full recap
(version bumps, changelog section, security findings, tag plan) and waits for one explicit
approval before doing anything irreversible.

### Guard / pre-flight
Checks shipmate runs *before* touching anything — clean working tree, up-to-date branch,
reachable remote, no version drift. If a guard fails, shipmate stops before doing harm.

### Rollback
Undoing a partially-done release (delete the local tag/branch, restore changed files) when
you say "no-go" at the checkpoint. Handled by shipmate's rollback script.

### Pre-push hook
A small script Git runs automatically right before `git push`. shipmate can install one as
a drift guard so a push is blocked when versions are out of sync.

---

## Claude Code / plugin terms

### Skill
A capability you invoke inside Claude Code with a slash command, e.g. `shipmate:release`.
shipmate ships three: `init`, `verify`, `release`.

### Subagent
A separate AI helper that Claude Code can dispatch to do a focused task and **report
back**, keeping control in the main conversation. shipmate uses one to run the security
review (so the flow continues afterward, unlike a slash command that ends the turn).

### State machine
A process defined as ordered states with strict transitions (shipmate's release runs
PRE-FLIGHT → PLAN → LOCAL-WRITE → PR → CHECKPOINT → PUBLISH). It exists so irreversible
actions can never happen before the safe, reversible ones and the human gate.
