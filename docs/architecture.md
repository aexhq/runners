# Architecture

```text
GitHub workflow_job webhook
            |
            v
 API Gateway -> webhook Lambda -> SQS -> scale-up Lambda
                                              |
                                              v
                                ephemeral EC2 Spot runner
                                              |
                        outbound HTTPS to GitHub, package registries,
                        and any services required by the workflow
                                              |
                                    one job, then terminate

EventBridge schedule -> scale-down/housekeeping Lambda
```

The control plane is serverless and remains available while the runner count is
zero. The data plane is a diversified set of `m*.large` Spot capacity pools
spread over the configured availability zones.

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
the runner distribution directly from GitHub every time.
