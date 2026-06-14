# shipmate on a JS/TS repo

Your version lives in `package.json` (`"version"`). A typical single-contract config:

```json
{ "remote": "origin", "protectedBranch": "main", "primaryContract": "kit",
  "securityReview": "auto",
  "contracts": [ { "name": "kit", "tag": "v{version}", "bumpFrom": "changelog",
    "locations": [ { "file": "package.json", "json": ".version" } ] } ] }
```

Have a version repeated in docs (e.g. "currently `1.2.3`")? Add a `regex` location with one
capture group around the version. `shipmate:init` proposes these for you.
