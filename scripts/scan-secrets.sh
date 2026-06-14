#!/usr/bin/env bash
# Fail if the given text (file arg or stdin) contains secret-shaped strings.
# Usage: scan-secrets.sh [file]   (reads stdin if no file)
# Pattern set is intentionally narrow + tested; extend with a test for each addition.
set -euo pipefail

if [ "${1:-}" != "" ]; then
  content="$(cat "$1")"
else
  content="$(cat)"
fi

# Each pattern is an ERE. Keep one per line; every addition needs a bats case.
patterns=(
  'ghp_[A-Za-z0-9]{36}'                 # GitHub personal access token
  'gho_[A-Za-z0-9]{36}'                 # GitHub OAuth token
  'github_pat_[A-Za-z0-9_]{22,}'        # GitHub fine-grained PAT
  'AKIA[0-9A-Z]{16}'                    # AWS access key id
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'  # PEM private key
  'xox[baprs]-[A-Za-z0-9-]{10,}'        # Slack token
  'AIza[0-9A-Za-z_-]{35}'               # Google API key
  'glpat-[0-9A-Za-z_-]{20}'             # GitLab personal access token
  'sk_live_[0-9A-Za-z]{24,}'            # Stripe live secret key
  'npm_[A-Za-z0-9]{36}'                 # npm access token
)

hit=0
for p in "${patterns[@]}"; do
  if grep -Eq -e "$p" <<<"$content"; then
    echo "scan-secrets: matched secret-shaped pattern: /$p/" >&2
    hit=1
  fi
done

if [ "$hit" -ne 0 ]; then
  echo "scan-secrets: refusing to publish — secret-shaped strings found" >&2
  exit 1
fi
echo "scan-secrets: clean"
