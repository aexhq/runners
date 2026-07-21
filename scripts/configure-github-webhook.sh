#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=github-app-jwt.sh
source "${script_directory}/github-app-jwt.sh"

app_id="${GH_APP_ID:?GH_APP_ID must be set}"
private_key="${GH_APP_PRIVATE_KEY_BASE64:?GH_APP_PRIVATE_KEY_BASE64 must be set}"
webhook_secret="${GH_APP_WEBHOOK_SECRET:?GH_APP_WEBHOOK_SECRET must be set}"
webhook_endpoint="${WEBHOOK_ENDPOINT:?WEBHOOK_ENDPOINT must be set}"
jwt="$(github_app_jwt "${app_id}" "${private_key}")"

jq --null-input \
  --arg url "${webhook_endpoint}" \
  --arg secret "${webhook_secret}" \
  '{url: $url, content_type: "json", secret: $secret, insecure_ssl: "0"}' \
  | curl --fail --silent --show-error \
      --request PATCH \
      --header "Accept: application/vnd.github+json" \
      --header "Authorization: Bearer ${jwt}" \
      --header "X-GitHub-Api-Version: 2026-03-10" \
      --header "Content-Type: application/json" \
      --data-binary @- \
      'https://api.github.com/app/hook/config' >/dev/null

echo "Configured GitHub App webhook endpoint."
