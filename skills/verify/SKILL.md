---
name: verify
description: Check a shipmate-configured repo for version drift — validate .shipmate.json against its schema and confirm every contract's locations agree on the same version. Use to run shipmate verify, diagnose drift, or check release config health. Read-only.
---

# shipmate:verify — drift doctor (read-only)

This skill never writes. Scripts at `${CLAUDE_PLUGIN_ROOT}/scripts/`.

1. **Schema check** — validate `.shipmate.json`:
   `npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s ${CLAUDE_PLUGIN_ROOT}/schemas/shipmate-config.schema.json -d .shipmate.json`
2. **Beyond-schema check** — `validate-config.sh .shipmate.json` (primaryContract tagged,
   regex single-group, tag uniqueness, locations readable).
3. **Drift check** — `version-sync-check.sh .shipmate.json`.

Report each result in plain language. If drift is found, name the contract, the files, and
the differing versions, and suggest the fix (bump the lagging file, or run `shipmate:release`).
Define "drift" for the reader: the declared files no longer agree on one version.
