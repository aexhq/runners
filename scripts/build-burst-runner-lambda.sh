#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module_root="${repository_root}/terraform/.terraform/modules/github_runners"
control_plane_root="${module_root}/lambdas/functions/control-plane"
patch_file="${repository_root}/patches/runner-job-burst.patch"
destination="${repository_root}/terraform/.lambda/runners.zip"

if [[ ! -d "${control_plane_root}" ]]; then
  echo "Pinned runner module is not initialized: ${module_root}" >&2
  echo "Run terraform -chdir=terraform init before building the burst Lambda." >&2
  exit 1
fi

version="$(tr -d '[:space:]' < "${repository_root}/.runner-module-version")"
terraform_version="$(sed -n 's/^[[:space:]]*version = "\([0-9][0-9.]*\)"/\1/p' "${repository_root}/terraform/runners.tf" | head -n 1)"
if [[ "v${terraform_version}" != "${version}" ]]; then
  echo "Terraform module version ${terraform_version} does not match ${version}." >&2
  exit 1
fi

if ! grep -Fq 'const desiredNewRunners = Math.max(scaleUp, 3);' "${control_plane_root}/src/scale-runners/scale-up.ts"; then
  pushd "${repository_root}" >/dev/null
  git apply --check --directory=terraform/.terraform/modules/github_runners patches/runner-job-burst.patch
  git apply --directory=terraform/.terraform/modules/github_runners patches/runner-job-burst.patch
  popd >/dev/null
fi

pushd "${module_root}/lambdas" >/dev/null
corepack_path="$(command -v corepack || true)"
if [[ -n "${corepack_path}" && -f "${corepack_path}.cmd" ]]; then
  yarn_command=(cmd.exe /d /c corepack.cmd yarn)
else
  yarn_command=(corepack yarn)
fi
"${yarn_command[@]}" install --immutable
"${yarn_command[@]}" workspace @aws-github-runner/control-plane build
cp "${control_plane_root}/package.json" "${control_plane_root}/dist/package.json"
if command -v zip >/dev/null 2>&1; then
  (cd "${control_plane_root}/dist" && zip -q "../runners.zip" ./*)
elif command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  windows_dist="$(wslpath -w "${control_plane_root}/dist")"
  windows_zip="$(wslpath -w "${control_plane_root}/runners.zip")"
  powershell.exe -NoProfile -Command "if (Test-Path -LiteralPath '${windows_zip}') { Remove-Item -LiteralPath '${windows_zip}' -Force }; Compress-Archive -Path '${windows_dist}\\*' -DestinationPath '${windows_zip}' -Force"
else
  echo "Neither zip nor a PowerShell archive tool is available." >&2
  exit 1
fi
popd >/dev/null

mkdir -p "$(dirname "${destination}")"
cp "${control_plane_root}/runners.zip" "${destination}"
if command -v unzip >/dev/null 2>&1; then
  unzip -tq "${destination}" >/dev/null
elif command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  windows_destination="$(wslpath -w "${destination}")"
  powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; \$archive = [System.IO.Compression.ZipFile]::OpenRead('${windows_destination}'); try { if (\$archive.Entries.Count -lt 1) { exit 1 } } finally { \$archive.Dispose() }"
else
  echo "Neither unzip nor a PowerShell archive verifier is available." >&2
  exit 1
fi
echo "Built demand-burst runner Lambda from ${version}: ${destination}"
