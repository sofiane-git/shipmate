# Contributing

## Dev setup
```bash
./setup-dev.sh   # routes git hooks to hooks/ (pre-commit: shellcheck + ajv)
```

## Workflow
`main` is protected. Branch (`feat/…`, `fix/…`, `docs/…`, `ci/…`), open a PR, get CI green
(shellcheck + schema + bats + frontmatter), squash-merge. Tags are pushed after a release
PR merges.

## Before a PR
```bash
shellcheck scripts/*.sh hooks/pre-commit setup-dev.sh
npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s schemas/shipmate-config.schema.json -d examples/config-valid.json
bats tests
```

Run `/security-review` on your branch before requesting review (shipmate dogfoods the
secure-by-default review it ships).

## Releases
From v0.1.1 on, shipmate releases itself with `shipmate:release`.

## Adding a secret pattern to `scan-secrets.sh`
Every new pattern needs a matching bats case in `tests/scan-secrets.bats`.
