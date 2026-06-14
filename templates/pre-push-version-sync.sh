#!/usr/bin/env bash
# shipmate-scaffolded pre-push hook: block a push if version locations drift.
set -euo pipefail
bash "$(git rev-parse --show-toplevel)/.shipmate/version-sync-check.sh" \
  "$(git rev-parse --show-toplevel)/.shipmate.json"
