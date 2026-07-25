# Architecture

```text
GitHub workflow_job webhook
            |
            v
 API Gateway -> webhook Lambda -> SQS (up to 3 messages / 1 second)
                                      -> scale-up Lambda -> 3x EC2 Spot burst
                                              |
                                              v
                                ephemeral EC2 Spot runner
                                              |
                        outbound HTTPS to GitHub, package registries,
                        and any services required by the workflow
                                              |
                                    one job, then terminate

EventBridge cleanup schedule -> scale-down/housekeeping Lambda
```

The control plane is serverless and remains available while the runner count is
zero. Standard jobs use `m6i.large` Spot capacity; larger jobs select an
approved instance type through guarded dynamic labels. All capacity is spread
over the configured availability zones.

Runners receive public IPv4 addresses and use an internet gateway. This avoids
the fixed hourly cost of NAT gateways. Their security group has no inbound
requirement; runner communication with GitHub is outbound. The public IPv4
address is billed only while an instance exists.

The module stores GitHub App values as encrypted SSM parameters. The Terraform
state also contains sensitive values, so CI stores it in a private, encrypted,
versioned S3 bucket and uses S3-native state locking.

EventBridge event routing in the upstream module is disabled; the direct
webhook-to-SQS path is sufficient for one runner class and has fewer resources.
The runner binary syncer remains enabled so fresh instances do not need to fetch
the runner distribution directly from GitHub every time. The SQS event source
mapping batches up to three nearby queued jobs; the scale-up Lambda requests a
bounded three-runner burst for each valid job group. `ghr-*` labels are dynamic
job labels: the webhook ignores them for base matching and the scale-up Lambda
applies them to the ephemeral runner for that job. The default m6i selector is
also present on the runner as a safe fallback for jobs that use that selector.
The one-minute EventBridge
rule is cleanup only, and does not maintain idle capacity; unused ephemeral
runners are eligible for termination after the one-minute minimum runtime.
