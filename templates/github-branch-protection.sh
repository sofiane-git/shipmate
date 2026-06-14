#!/usr/bin/env bash
# Configure GitHub branch protection (the real barrier) + required CI check.
set -euo pipefail
gh api -X PUT "repos/{{OWNER}}/{{REPO}}/branches/{{BRANCH}}/protection" \
  -H "Accept: application/vnd.github+json" \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=CI' \
  -F 'enforce_admins=true' \
  -F 'required_pull_request_reviews=null' \
  -F 'restrictions=null'
echo "Branch protection enabled on {{BRANCH}}."
