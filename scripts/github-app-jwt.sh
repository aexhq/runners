#!/usr/bin/env bash

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

github_app_jwt() {
  local app_id="${1:?GitHub App ID is required}"
  local private_key_base64="${2:?GitHub App private key is required}"
  local now issued_at expires_at header payload signature private_key_file

  now="$(date +%s)"
  issued_at="$((now - 60))"
  expires_at="$((now + 540))"
  header="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)"
  payload="$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "${issued_at}" "${expires_at}" "${app_id}" | base64url)"
  private_key_file="$(mktemp)"
  chmod 600 "${private_key_file}"
  if ! printf '%s' "${private_key_base64}" | base64 --decode > "${private_key_file}"; then
    rm -f "${private_key_file}"
    return 1
  fi
  signature="$(printf '%s' "${header}.${payload}" \
    | openssl dgst -sha256 -sign "${private_key_file}" -binary \
    | base64url)" || {
      rm -f "${private_key_file}"
      return 1
    }
  rm -f "${private_key_file}"

  printf '%s.%s.%s' "${header}" "${payload}" "${signature}"
}
