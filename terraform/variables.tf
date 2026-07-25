variable "aws_region" {
  description = "AWS region in which to deploy the runner fleet."
  type        = string
  default     = "eu-west-1"
}

variable "github_organization" {
  description = "GitHub organization that owns the App installation and runners."
  type        = string
  default     = "aexhq"

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_organization))
    error_message = "github_organization must be a valid GitHub organization login."
  }
}

variable "github_app_id" {
  description = "Numeric GitHub App ID."
  type        = string
  sensitive   = true
}

variable "github_app_private_key_base64" {
  description = "Base64-encoded PEM private key for the GitHub App."
  type        = string
  sensitive   = true
}

variable "github_app_webhook_secret" {
  description = "Shared secret used to authenticate GitHub webhook deliveries."
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Short prefix applied to AWS resources and runner names."
  type        = string
  default     = "github-runners"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-20 lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the runner VPC."
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones and public subnets used for Spot diversity."
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count >= 1 && var.availability_zone_count <= 6
    error_message = "availability_zone_count must be between 1 and 6."
  }
}

variable "instance_types" {
  description = "Normal x64 EC2 Spot type for standard jobs; large jobs use guarded dynamic labels."
  type        = list(string)
  default     = ["m6i.large"]

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "instance_types must contain at least one EC2 instance type."
  }
}

variable "allowed_dynamic_instance_types" {
  description = "Approved x64 instance types workflows may request with ghr-ec2-instance-type."
  type        = list(string)
  default = [
    "m7a.large",
    "m7i.large",
    "m6a.large",
    "m6i.large",
    "m5a.large",
    "m5.large",
    "m7a.xlarge",
    "m7i.xlarge",
    "m6a.xlarge",
    "m6i.xlarge",
    "m5a.xlarge",
    "m5.xlarge",
    "c7a.xlarge",
    "c7i.xlarge",
    "c6a.xlarge",
    "c6i.xlarge",
    "r7a.xlarge",
    "r7i.xlarge",
    "r6a.xlarge",
    "r6i.xlarge",
  ]

  validation {
    condition     = length(var.allowed_dynamic_instance_types) > 0
    error_message = "allowed_dynamic_instance_types must contain at least one EC2 instance type."
  }
}

variable "allowed_dynamic_instance_types" {
  description = "Approved x64 instance types workflows may request with ghr-ec2-instance-type."
  type        = list(string)
  default = [
    "m7a.large",
    "m7i.large",
    "m6a.large",
    "m6i.large",
    "m5a.large",
    "m5.large",
    "m7a.xlarge",
    "m7i.xlarge",
    "m6a.xlarge",
    "m6i.xlarge",
    "m5a.xlarge",
    "m5.xlarge",
    "c7a.xlarge",
    "c7i.xlarge",
    "c6a.xlarge",
    "c6i.xlarge",
    "r7a.xlarge",
    "r7i.xlarge",
    "r6a.xlarge",
    "r6i.xlarge",
  ]

  validation {
    condition     = length(var.allowed_dynamic_instance_types) > 0
    error_message = "allowed_dynamic_instance_types must contain at least one EC2 instance type."
  }
}

variable "maximum_runner_count" {
  description = "Maximum concurrent EC2 runners; this is the primary cost guardrail."
  type        = number
  default     = 20

  validation {
    condition     = var.maximum_runner_count >= 1 && var.maximum_runner_count <= 100
    error_message = "maximum_runner_count must be between 1 and 100."
  }
}

variable "runner_group_name" {
  description = "Existing GitHub organization runner group to join."
  type        = string
  default     = "Default"
}

variable "repository_allow_list" {
  description = "Optional full repository names accepted by the webhook, for example octo-org/api."
  type        = list(string)
  default     = []
}

variable "create_service_linked_role_spot" {
  description = "Create AWSServiceRoleForEC2Spot. Set false if another stack already manages it."
  type        = bool
  default     = true
}

variable "runner_role_permissions_boundary_arn" {
  description = "Optional IAM permissions boundary applied to every role created by the runner module."
  type        = string
  default     = null

  validation {
    condition = (
      var.runner_role_permissions_boundary_arn == null ||
      var.runner_role_permissions_boundary_arn == "" ||
      can(regex("^arn:[^:]+:iam::[0-9]{12}:policy/.+$", var.runner_role_permissions_boundary_arn))
    )
    error_message = "runner_role_permissions_boundary_arn must be empty or an IAM policy ARN."
  }
}

variable "root_volume_size_gib" {
  description = "Encrypted gp3 root volume size for each ephemeral runner."
  type        = number
  default     = 40

  validation {
    condition     = var.root_volume_size_gib >= 20 && var.root_volume_size_gib <= 500
    error_message = "root_volume_size_gib must be between 20 and 500."
  }
}

variable "dynamic_root_volume_max_size_gib" {
  description = "Maximum gp3 root volume size a workflow may request with a dynamic runner label."
  type        = number
  default     = 200

  validation {
    condition = (
      var.dynamic_root_volume_max_size_gib >= var.root_volume_size_gib &&
      var.dynamic_root_volume_max_size_gib <= 500
    )
    error_message = "dynamic_root_volume_max_size_gib must be at least root_volume_size_gib and no more than 500."
  }
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
