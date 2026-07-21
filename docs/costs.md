# Cost model

With no queued jobs, EC2 runner cost is zero. The VPC, route table, internet
gateway, subnets, and use of multiple availability zones have no fixed hourly
charge.

Small usage-based charges remain even at zero runners:

- S3 storage and requests for Terraform state and runner binaries.
- SSM Parameter Store, API Gateway, SQS, Lambda invocations, and CloudWatch
  logs. At light CI volume these are normally small and several may remain
  inside AWS free-tier allowances.
- A public IPv4 hourly charge and EBS storage while each runner exists.
- EC2 Spot compute while jobs run and during boot/shutdown.
- Internet data transfer and any paid services used by a workflow.

There is no NAT gateway in the default architecture. NAT gateway hourly and
per-GB processing fees often dominate the idle cost of a small private-subnet
runner deployment.

Spot is usually the cheapest EC2 purchasing model for interruptible CI, but it
is not always the cheapest execution platform overall. Compare actual job
duration, boot latency, architecture, interruption rate, GitHub plan minutes,
and alternatives such as AWS Graviton Spot. The default `m*.large` x64 list is
chosen for broad workflow compatibility and roughly 2 vCPU / 8 GiB capacity,
not the absolute lowest price.

Set an AWS Budget and alarms before enabling the fleet. `MAXIMUM_RUNNER_COUNT`
is the hard concurrency/cost guardrail and defaults to 10.
