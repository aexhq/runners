# AWS authentication

## Recommended: GitHub OIDC

The quickest reusable setup is the included CloudFormation template:

```bash
OIDC_SUBJECT_PREFIX="$(
  gh api repos/YOUR_ORG/runners/actions/oidc/customization/sub \
    --jq .sub_claim_prefix
)"

aws cloudformation deploy \
  --template-file bootstrap/aws-oidc.yaml \
  --stack-name github-runners-bootstrap \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    RepositoryOwner=YOUR_ORG \
    RepositoryName=runners \
    OidcSubjectPrefix="$OIDC_SUBJECT_PREFIX" \
    ResourcePrefix=github-runners
```

Use the API value rather than constructing the subject from names. GitHub
repositories created after July 15, 2026 use an immutable prefix containing
the organization and repository IDs, while older repositories can retain the
name-only prefix.

If the account already has GitHub's OIDC provider, also pass:

```text
CreateGitHubOidcProvider=false
ExistingGitHubOidcProviderArn=arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com
```

Use the stack outputs for `AWS_DEPLOY_ROLE_ARN` and
`RUNNER_ROLE_PERMISSIONS_BOUNDARY_ARN`. `ResourcePrefix` must equal the
repository's `NAME_PREFIX` variable.

Alternatively, create the identity manually as described below.

Create an IAM OpenID Connect provider for
`https://token.actions.githubusercontent.com` with audience
`sts.amazonaws.com`, then create a deployment role whose trust policy is scoped
to this repository and `main` branch:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "YOUR_OIDC_SUBJECT_PREFIX:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Replace the account and subject prefix. Obtain the exact prefix with the
`gh api` command above. Store the role ARN as the
`AWS_DEPLOY_ROLE_ARN` repository secret. The workflow requests `id-token: write`
only for this exchange.

The role needs permission to manage this stack's VPC, EC2, IAM, Lambda, API
Gateway, SQS, S3, SSM, CloudWatch Logs, and EventBridge resources, including
creating and passing the runner roles. It also needs S3 access to the state
bucket. Establishing a narrow deployment policy is account-specific; use a
dedicated deployment role and apply your organization's permission boundary.

The supplied policy is intentionally broad within the listed AWS services
because Terraform creates and destroys complete networking and runner control
planes. Use a dedicated AWS account for stronger isolation when possible.

If your account has a permissions-boundary policy for workload roles, set its
ARN as the `RUNNER_ROLE_PERMISSIONS_BOUNDARY_ARN` repository variable. The
module then applies that boundary to every EC2, Lambda, and scheduler role it
creates. Keep the boundary outside this Terraform stack so the deployment role
cannot weaken its own guardrail.

## Bootstrap alternative: access-key secrets

If OIDC is not ready, add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as
repository secrets. Add `AWS_SESSION_TOKEN` for temporary credentials. The
workflow uses these only when `AWS_DEPLOY_ROLE_ARN` is absent.

Do not create long-lived keys solely for CI. Use the access-key path to
bootstrap OIDC, then remove the secrets. Never put credentials in `.tfvars`,
workflow YAML, issues, or logs.

## Terraform state permissions

CI creates a deterministic bucket named
`github-runners-tfstate-ACCOUNT-REGION` unless `TF_STATE_BUCKET` is set. The
role needs these actions on that bucket:

- `s3:CreateBucket`, `s3:GetBucketLocation`, and `s3:ListBucket`
- `s3:PutBucketEncryption`, `s3:PutBucketVersioning`,
  `s3:PutBucketPublicAccessBlock`, `s3:PutBucketOwnershipControls`, and
  `s3:PutBucketTagging`
- `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` for the state and lock
  objects

No DynamoDB lock table is required; this repository uses S3-native lock files.
