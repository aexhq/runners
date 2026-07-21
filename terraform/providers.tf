provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy          = "terraform"
      Project            = var.name_prefix
      GitHubOrganization = var.github_organization
    })
  }
}
