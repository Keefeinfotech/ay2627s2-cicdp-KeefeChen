#!/usr/bin/env bash
# Enforce the CI quality gate and peer review on the long-lived branches.
# Branch protection is repository settings, not a file in this repo, so this
# script makes the configuration reproducible and reviewable.
#
# Usage:
#   GH_TOKEN=<token with admin rights> ./scripts/configure-branch-protection.sh
set -euo pipefail

REPO="${GITHUB_REPOSITORY:-Keefeinfotech/ay2627s2-cicdp-KeefeChen}"
REQUIRED_CHECK="CI - Final Quality Gate"

for branch in main develop; do
  echo "Configuring protection for ${branch}..."

  # Classic branch protection. Use required_status_checks.strict so PRs must be
  # up to date with the base branch before merging.
  gh api --method PUT "repos/${REPO}/branches/${branch}/protection" \
    -F required_status_checks.strict=true \
    -f "required_status_checks.contexts[]=${REQUIRED_CHECK}" \
    -F enforce_admins=true \
    -F required_pull_request_reviews.required_approving_review_count=1 \
    -F required_pull_request_reviews.dismiss_stale_reviews=true \
    -F required_pull_request_reviews.require_code_owner_reviews=true \
    -F restrictions=null \
    -F allow_force_pushes.enabled=false \
    -F allow_deletions.enabled=false

  echo "Protected ${branch}."
done

echo ""
echo "Remaining manual step: GitHub > Settings > Environments > production >"
echo "Required reviewers - add at least one reviewer and restrict deployments"
echo "to the main branch. Environment protection cannot be set by this script."
