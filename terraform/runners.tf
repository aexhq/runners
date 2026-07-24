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

  enable_ephemeral_runners = true
  enable_jit_config        = true
  # Ephemeral jobs must scale from the webhook event itself. GitHub's job
  # API can briefly report a newly-created job as not queued even though the
  # workflow is waiting for a runner; enabling this check drops that event
  # and strands the job indefinitely.
  enable_job_queued_check                 = false
  enable_runner_bidirectional_label_match = true
  enable_dynamic_labels                   = true
  ec2_dynamic_labels_policy = {
    # Dynamic configuration is intentionally default-deny for every EC2
    # override supported by the pinned module except the bounded instance and
    # root-volume controls below. Workflow authors must not be able to replace
    # the AMI, escape the runner subnets, disable encryption, or request GPUs.
    blocked_keys = [
      "max-price",
      "subnet-id",
      "availability-zone",
      "availability-zone-id",
      "weighted-capacity",
      "priority",
      "image-id",
      "vcpu-count-min",
      "vcpu-count-max",
      "memory-mib-min",
      "memory-mib-max",
      "memory-gib-per-vcpu-min",
      "memory-gib-per-vcpu-max",
      "cpu-manufacturers",
      "instance-generations",
      "excluded-instance-types",
      "allowed-instance-types",
      "burstable-performance",
      "bare-metal",
      "accelerator-types",
      "accelerator-count-min",
      "accelerator-count-max",
      "accelerator-manufacturers",
      "accelerator-names",
      "accelerator-total-memory-mib-min",
      "accelerator-total-memory-mib-max",
      "network-interface-count-min",
      "network-interface-count-max",
      "network-bandwidth-gbps-min",
      "network-bandwidth-gbps-max",
      "local-storage",
      "local-storage-types",
      "total-local-storage-gb-min",
      "total-local-storage-gb-max",
      "baseline-ebs-bandwidth-mbps-min",
      "baseline-ebs-bandwidth-mbps-max",
      "placement-group-name",
      "placement-group-id",
      "placement-tenancy",
      "placement-host-id",
      "placement-affinity",
      "placement-partition-number",
      "placement-availability-zone",
      "placement-availability-zone-id",
      "placement-spread-domain",
      "placement-host-resource-group-arn",
      "block-device-name",
      "ebs-iops",
      "ebs-throughput",
      "ebs-encrypted",
      "ebs-kms-key-id",
      "ebs-delete-on-termination",
      "ebs-snapshot-id",
      "block-device-virtual-name",
      "block-device-no-device",
      "spot-max-price-percentage-over-lowest-price",
      "on-demand-max-price-percentage-over-lowest-price",
      "max-spot-price-as-percentage-of-optimal-on-demand-price",
      "require-hibernate-support",
      "require-encryption-in-transit",
      "baseline-performance-factors-cpu-reference-families",
    ]
    restricted_keys = {
      "instance-type" = {
        allowed = var.allowed_dynamic_instance_types
      }
      "ebs-volume-size" = {
        max = var.dynamic_root_volume_max_size_gib
      }
      "ebs-volume-type" = {
        allowed = ["gp3"]
      }
    }
  }
  runners_maximum_count                 = var.maximum_runner_count
  runner_name_prefix                    = "${var.name_prefix}-"
  delay_webhook_event                   = 0
  scale_down_schedule_expression        = "cron(* * * * ? *)"
  enable_ssm_on_runners                 = false
  enable_user_data_debug_logging_runner = false

  # Keep the image lean while providing the system Node.js binary that many
  # workflows use before their setup action runs. npm is a separate AL2023
  # package for the namespaced Node.js releases.
  userdata_pre_install = <<-EOT
    install_with_retry nodejs22 nodejs22-npm rsync unzip
  EOT

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
    ManagedBy          = "terraform"
    Project            = var.name_prefix
    Service            = "github-actions-runners"
  })
}
