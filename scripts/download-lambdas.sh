#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "${repository_root}/.runner-module-version")"
destination="${1:-${repository_root}/terraform/.lambda}"
checksum_file="${repository_root}/.runner-lambda-sha256"

if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid runner module version: ${version}" >&2
  exit 1
fi

terraform_version="$(sed -n 's/^[[:space:]]*version = "\([0-9][0-9.]*\)"/\1/p' "${repository_root}/terraform/runners.tf" | head -n 1)"
if [[ "v${terraform_version}" != "${version}" ]]; then
  echo "Terraform module version ${terraform_version} does not match ${version}." >&2
  exit 1
fi

mkdir -p "${destination}"

for artifact in webhook runners runner-binaries-syncer; do
  target="${destination}/${artifact}.zip"
  url="https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${version}/${artifact}.zip"
  expected_checksum="$(awk -v file="${artifact}.zip" '$2 == file { print $1 }' "${checksum_file}")"
  if [[ -z "${expected_checksum}" ]]; then
    echo "No pinned checksum for ${artifact}.zip" >&2
    exit 1
  fi
  echo "Downloading ${artifact} ${version}"
  curl --fail --location --retry 3 --silent --show-error --output "${target}.tmp" "${url}"
  unzip -tq "${target}.tmp" >/dev/null
  actual_checksum="$(sha256sum "${target}.tmp" | awk '{ print $1 }')"
  if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
    rm -f "${target}.tmp"
    echo "Checksum mismatch for ${artifact}.zip" >&2
    exit 1
  fi
  mv "${target}.tmp" "${target}"
done
