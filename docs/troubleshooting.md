# Troubleshooting

## A job stays queued

1. Confirm `runs-on` includes all of `self-hosted`, `linux`, `x64`, and
   `ec2-spot`.
2. Confirm the repository can access the configured runner group.
3. In the GitHub App's **Advanced** page, verify a `workflow_job` delivery was
   sent and returned HTTP 202.
4. Inspect the webhook and scale-up Lambda log groups in CloudWatch.
5. Check the SQS queue and the account's EC2 Spot and On-Demand quotas.
6. Confirm at least one configured instance type has Spot capacity in one of
   the selected availability zones.

## Terraform cannot create the Spot service-linked role

The role may already be managed elsewhere or the deploy identity may lack
`iam:CreateServiceLinkedRole`. Set the repository variable
`CREATE_SPOT_SERVICE_LINKED_ROLE` to `false` after confirming
`AWSServiceRoleForEC2Spot` exists in the account.

## The GitHub App check fails

Make sure the App is installed on the exact organization named by
`TARGET_GITHUB_ORG`, not just created under it. Confirm the App ID and base64
private key belong to the same App.

## OIDC role assumption is denied

Read the repository's exact subject prefix and compare it with the deployment
role trust policy:

```bash
gh api repos/YOUR_ORG/YOUR_REPOSITORY/actions/oidc/customization/sub \
  --jq .sub_claim_prefix
```

Append `:ref:refs/heads/main` to that value. Do not assume the prefix is only
`repo:OWNER/REPOSITORY`: newly created GitHub repositories use immutable owner
and repository IDs in this claim.

## `ubuntu-latest` software is missing

The default image is Amazon Linux 2023 with the runner, Docker, Git, Node.js 22,
npm, jq, and curl installed; it does not contain GitHub's complete hosted-runner
tool cache. Add a setup action, run the job in a container, or build and select
a custom AMI.
