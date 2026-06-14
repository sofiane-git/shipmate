#!/usr/bin/env bash
# One-time dev setup: route git hooks to the committed hooks/ dir.
set -euo pipefail
git config core.hooksPath hooks
chmod +x hooks/pre-commit
echo "setup-dev: core.hooksPath -> hooks/"
