# shipmate on a Python repo

Your version lives in `pyproject.toml` (`[project] version`). A single-contract config:

```json
{ "remote": "origin", "protectedBranch": "main", "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [ { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
    "locations": [ { "file": "pyproject.toml", "toml": "project.version" } ] } ] }
```

A TS app shipping together with its Python agent under one version? Put both
`package.json` and `pyproject.toml` as locations of the **same** contract.
