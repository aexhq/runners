output "webhook_endpoint" {
  description = "URL configured as the GitHub App webhook endpoint."
  value       = module.github_runners.webhook.endpoint
}

output "runner_selector" {
  description = "Labels to use in a workflow runs-on array."
  value       = ["self-hosted", "linux", "x64", "ec2-spot"]
}

output "runner_group_name" {
  description = "GitHub runner group configured for new ephemeral runners."
  value       = var.runner_group_name
}

output "vpc_id" {
  description = "ID of the runner VPC."
  value       = aws_vpc.runners.id
}

output "public_subnet_ids" {
  description = "Public subnets offered to the Spot allocation request."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "github_organization" {
  description = "Expected GitHub App installation owner."
  value       = var.github_organization
}
