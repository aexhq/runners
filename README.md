# EC2 Spot GitHub Actions runners

Deploy ephemeral, organization-level GitHub Actions runners on AWS EC2 Spot
instances. A push to `main` runs Terraform from a GitHub-hosted
`ubuntu-latest` runner, then configures the GitHub App webhook automatically.
The fleet scales to zero when idle.

The default target is the `aexhq` organization, but every organization-specific
value is configurable. This repository is safe to publish: it contains no
credentials, and pull requests receive validation only.

## What gets deployed

- One small VPC, internet gateway, route table, and three public subnets.
- An API Gateway webhook, SQS queue, Lambda scaling functions, IAM roles,
  encrypted SSM parameters, S3 runner-binary cache, and CloudWatch logs.
- Ephemeral Amazon Linux 2023 EC2 Spot instances with Docker, created only when
  a matching job is queued and terminated after one job.
- An encrypted and versioned S3 Terraform-state bucket, created idempotently by
  CI. No NAT gateway, load balancer, database, Kubernetes cluster, or always-on
  runner is used.

The three subnets span availability zones to give EC2 Spot more capacity pools.
Empty subnets and availability zones do not have an hourly charge. Set
`AVAILABILITY_ZONE_COUNT` to `1` if you prefer the absolute smallest topology.

## Quick start

1. Fork or clone this repository into a public or private GitHub repository.
2. Create and install a GitHub App by following [GitHub App setup](docs/github-app.md).
3. Add these repository secrets:

   | Secret | Purpose |
   | --- | --- |
   | `GH_APP_ID` | Numeric GitHub App ID |
   | `GH_APP_PRIVATE_KEY_BASE64` | Base64-encoded App private-key PEM |
   | `GH_APP_WEBHOOK_SECRET` | A long random webhook secret |
   | `AWS_DEPLOY_ROLE_ARN` | Recommended: AWS role trusted through GitHub OIDC |

   Instead of `AWS_DEPLOY_ROLE_ARN`, the first deployment can use
   `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, plus optional
   `AWS_SESSION_TOKEN`. See [AWS authentication](docs/aws-auth.md).

   For a new AWS account, `bootstrap/aws-oidc.yaml` creates the recommended
   OIDC role and workload permissions boundary without storing AWS keys in
   GitHub. The setup command reads GitHub's exact OIDC subject prefix, including
   immutable repository IDs when applicable.

4. Optionally add repository variables. Defaults are shown below:

   | Variable | Default |
   | --- | --- |
   | `TARGET_GITHUB_ORG` | `aexhq` |
   | `AWS_REGION` | `eu-west-1` |
   | `NAME_PREFIX` | `github-runners` |
   | `RUNNER_GROUP_NAME` | `Default` |
   | `MAXIMUM_RUNNER_COUNT` | `20` |
   | `AVAILABILITY_ZONE_COUNT` | `3` |
   | `REPOSITORY_ALLOW_LIST` | `[]` (the App installation and runner group control access) |
   | `CREATE_SPOT_SERVICE_LINKED_ROLE` | `true` (set `false` if the account already manages it) |
   | `RUNNER_ROLE_PERMISSIONS_BOUNDARY_ARN` | empty (recommended for governed AWS accounts) |
   | `TF_STATE_BUCKET` | deterministic name in the current AWS account |

   `REPOSITORY_ALLOW_LIST` is a JSON array such as
   `["octo-org/api","octo-org/web"]`.

5. Protect `main`, review the runner group's repository access, then push to
   `main` or run **Deploy runners** manually. The workflow verifies that the
   GitHub App is installed on `TARGET_GITHUB_ORG`, creates the state bucket,
   applies Terraform, and updates the App's webhook URL.

   `RUNNER_GROUP_NAME` must name an existing group; every organization already
   has the `Default` group.

6. Replace a Linux job's runner selector:

   ```yaml
   # Before
   runs-on: ubuntu-latest

   # After
   runs-on: [self-hosted, linux, x64, ec2-spot]
   ```

Demand scale-up batches up to three nearby workflow-job webhook deliveries for
one scale-up invocation and requests a three-runner ephemeral `m6i.large` Spot
burst for each valid job group. When concurrent jobs are already queued, they
consume the burst immediately; when they are not, the unused runners are
reaped by the one-minute cleanup Lambda after the one-minute minimum runtime.
There is no always-on warm pool. Large jobs remain cold and use their guarded
dynamic labels only when requested.

Ephemeral scaling intentionally does not re-check GitHub's job API before
launching. GitHub can briefly report a new workflow job as not queued while
the webhook is already waiting for a runner; enabling that check can strand the
job. A cancelled job may therefore cause one short-lived Spot instance to be
created, but a valid queued job is never dropped by a transient API race.

Jobs use a 2-vCPU/8-GiB instance and a 40-GiB encrypted gp3 root volume by
default. Trusted workflows can select an approved larger x64 instance or a
larger gp3 root volume with guarded dynamic labels:

```yaml
runs-on:
  - self-hosted
  - linux
  - x64
  - ec2-spot
  - ghr-ec2-instance-type:m7a.xlarge
  - ghr-ec2-ebs-volume-size:80
  - ghr-ec2-ebs-volume-type:gp3
```

The Terraform policy allow-lists instance types and caps dynamic root volumes
at 200 GiB. AMI, subnet, placement, accelerator, encryption, and arbitrary EBS
performance overrides are rejected by the webhook. Extend the approved catalog
in Terraform before a workflow requests a new hardware shape.

## Checkout, actions, and secrets

Nothing special is required. GitHub assigns the job to the registered runner
and gives it the same short-lived `GITHUB_TOKEN` and referenced Actions secrets
that a GitHub-hosted job would receive. `actions/checkout` uses that token to
fetch the repository, and actions are downloaded over outbound HTTPS:

```yaml
jobs:
  test:
    runs-on: [self-hosted, linux, x64, ec2-spot]
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - run: docker version
      - run: ./ci/test.sh
        env:
          SERVICE_TOKEN: ${{ secrets.SERVICE_TOKEN }}
```

The important difference is trust: code running on a self-hosted machine can
read any secret explicitly supplied to that job. These instances are ephemeral,
but you should still restrict the runner group to selected, trusted repositories
and avoid unreviewed fork pull requests.

Amazon Linux 2023 is not a byte-for-byte replacement for GitHub's
`ubuntu-latest` image. The baseline includes Docker, Git, Node.js 22, npm, jq,
curl, and the runner itself. Use setup actions or a job container for other
tools your build needs. Docker and container/service jobs are supported.

The pinned module-managed Amazon Linux 2023 image is the validated baseline;
this repository does not select an untested custom AMI. A future pre-baked
Image Builder/Packer AMI must be built and validated here before changing the
runner image contract.

## Operations

- Review [architecture](docs/architecture.md), [costs](docs/costs.md), and
  [security](docs/security.md) before production use.
- Use **Destroy runners** and type the required confirmation to tear down the
  Terraform-managed stack. The state bucket remains intentionally so it can
  retain version history; delete it separately only after confirming it is no
  longer needed.
- See [troubleshooting](docs/troubleshooting.md) when a job remains queued.

The implementation is built around the MIT-licensed
[`github-aws-runners/terraform-aws-github-runner`](https://github.com/github-aws-runners/terraform-aws-github-runner)
module, pinned to the release recorded in `.runner-module-version`.
The release Lambda archives are also checked against committed SHA-256 hashes
before Terraform can use them.
