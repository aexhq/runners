#!/usr/bin/env bash
set -euo pipefail

backend_file="${1:-terraform/.backend.hcl}"
region="${AWS_REGION:?AWS_REGION must be set}"
account_id="$(aws sts get-caller-identity --query Account --output text)"
bucket="${TF_STATE_BUCKET:-github-runners-tfstate-${account_id}-${region}}"
repository="${GITHUB_REPOSITORY:-local/runners}"
project="${TF_VAR_name_prefix:-github-runners}"
state_key="github/${repository}/terraform.tfstate"
bucket_created=false

if ! aws s3api head-bucket --bucket "${bucket}" 2>/dev/null; then
  echo "Creating Terraform state bucket ${bucket}"
  if [[ "${region}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${bucket}" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "${bucket}" \
      --create-bucket-configuration "LocationConstraint=${region}" >/dev/null
  fi
  aws s3api wait bucket-exists --bucket "${bucket}"
  bucket_created=true
fi

aws s3api put-public-access-block \
  --bucket "${bucket}" \
  --public-access-block-configuration \
  'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws s3api put-bucket-encryption \
  --bucket "${bucket}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-versioning \
  --bucket "${bucket}" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-ownership-controls \
  --bucket "${bucket}" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
if [[ "${bucket_created}" == "true" ]]; then
  aws s3api put-bucket-tagging \
    --bucket "${bucket}" \
    --tagging "TagSet=[{Key=ManagedBy,Value=github-actions},{Key=Purpose,Value=terraform-state},{Key=Project,Value=${project}},{Key=Service,Value=github-actions-runners}]"
fi

mkdir -p "$(dirname "${backend_file}")"
cat > "${backend_file}" <<EOF
bucket       = "${bucket}"
key          = "${state_key}"
region       = "${region}"
encrypt      = true
use_lockfile = true
EOF

echo "Terraform state: s3://${bucket}/${state_key}"
