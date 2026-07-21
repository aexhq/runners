module "github_runners" {
  source  = "github-aws-runners/github-runner/aws"
  version = "7.9.0"

  aws_region = var.aws_region
  prefix     = var.name_prefix
  vpc_id     = aws_vpc.runners.id
  subnet_ids = [for subnet in aws_subnet.public : subnet.id]

  github_app = {
    id             = var.github_app_id
    key_base64     = var.github_app_private_key_base64
    webhook_secret = var.github_app_webhook_secret
  }

  webhook_lambda_zip                = "${path.module}/.lambda/webhook.zip"
  runners_lambda_zip                = "${path.module}/.lambda/runners.zip"
  runner_binaries_syncer_lambda_zip = "${path.module}/.lambda/runner-binaries-syncer.zip"

  enable_organization_runners = true
  runner_group_name           = var.runner_group_name
  runner_extra_labels         = ["ec2-spot"]
  repository_white_list       = var.repository_allow_list

  enable_ephemeral_runners                = true
  enable_jit_config                       = true
  enable_job_queued_check                 = true
  enable_runner_bidirectional_label_match = true
  runners_maximum_count                   = var.maximum_runner_count
  runner_name_prefix                      = "${var.name_prefix}-"
  delay_webhook_event                     = 0
  scale_down_schedule_expression          = "cron(* * * * ? *)"
  enable_ssm_on_runners                   = false
  enable_user_data_debug_logging_runner   = false

  instance_target_capacity_type = "spot"
  instance_allocation_strategy  = "price-capacity-optimized"
  instance_types                = var.instance_types
  associate_public_ipv4_address = true

  block_device_mappings = [{
    device_name           = "/dev/xvda"
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.root_volume_size_gib
    volume_type           = "gp3"
  }]

  create_service_linked_role_spot = var.create_service_linked_role_spot
  logging_retention_in_days       = 14
  role_permissions_boundary = (
    var.runner_role_permissions_boundary_arn == ""
    ? null
    : var.runner_role_permissions_boundary_arn
  )

  eventbridge = {
    enable = false
  }

  tags = merge(var.tags, {
    GitHubOrganization = var.github_organization
    RunnerLifecycle    = "ephemeral"
    CapacityType       = "spot"
  })
}
