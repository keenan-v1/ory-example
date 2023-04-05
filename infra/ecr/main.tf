locals {
  # List of ECR repositories to create
  repositories = toset([
    "database-provisioner",
    "database-migrator",
    "kratos",
    "hydra",
    "oathkeeper",
    "keto",
  ])
}

# Create an ECR repositories
resource "aws_ecr_repository" "repositories" {
  for_each             = local.repositories
  name                 = "${var.organization}/${var.project_name}/${var.environment}/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ssm_parameter" "repository_info" {
  name  = "/${var.organization}/${var.project_name}/${var.environment}/ecr/info"
  type  = "String"
  value = jsonencode({ for _, name in local.repositories : name => aws_ecr_repository.repositories[name].repository_url })
}
