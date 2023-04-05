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
  name                 = "/${var.organization}/${var.project_name}/${var.environment}/${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}
