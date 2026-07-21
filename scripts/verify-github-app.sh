#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=github-app-jwt.sh
source "${script_directory}/github-app-jwt.sh"

app_id="${GH_APP_ID:?GH_APP_ID must be set}"
private_key="${GH_APP_PRIVATE_KEY_BASE64:?GH_APP_PRIVATE_KEY_BASE64 must be set}"
organization="${GITHUB_ORGANIZATION:?GITHUB_ORGANIZATION must be set}"
jwt="$(github_app_jwt "${app_id}" "${private_key}")"

app_details="$(curl --fail --silent --show-error \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${jwt}" \
  --header "X-GitHub-Api-Version: 2026-03-10" \
  'https://api.github.com/app')"

if ! jq --exit-status '
  .permissions.actions == "read"
  and .permissions.checks == "read"
  and .permissions.metadata == "read"
  and .permissions.organization_self_hosted_runners == "write"
  and (.events | index("workflow_job") != null)
' <<<"${app_details}" >/dev/null; then
  echo "GitHub App permissions or Workflow job subscription do not match docs/github-app.md." >&2
  exit 1
fi

installations="$(curl --fail --silent --show-error \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${jwt}" \
  --header "X-GitHub-Api-Version: 2026-03-10" \
  'https://api.github.com/app/installations?per_page=100')"

if ! jq --exit-status --arg organization "${organization}" \
  'any(.[]; (.account.login | ascii_downcase) == ($organization | ascii_downcase))' \
  <<<"${installations}" >/dev/null; then
  echo "GitHub App ${app_id} is not installed on organization ${organization}." >&2
  exit 1
fi

echo "Verified GitHub App installation on ${organization}."
