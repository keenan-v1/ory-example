# Create an ECR repository for database provisioning
resource "aws_ecr_repository" "database_provisioner" {
  name                 = "${var.project_name}-${var.environment}-database-provisioner"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Create an ECR repository for database migrations
resource "aws_ecr_repository" "database_migrator" {
  name                 = "${var.project_name}-${var.environment}-database-migrator"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Create an ECR repository for Kratos
resource "aws_ecr_repository" "kratos" {
  name                 = "${var.project_name}-${var.environment}-kratos"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Create an ECR repository for Hydra
resource "aws_ecr_repository" "hydra" {
  name                 = "${var.project_name}-${var.environment}-hydra"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Create an ECR repository for Oathkeeper
resource "aws_ecr_repository" "oathkeeper" {
  name                 = "${var.project_name}-${var.environment}-oathkeeper"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Create an ECR repository for Keto
resource "aws_ecr_repository" "keto" {
  name                 = "${var.project_name}-${var.environment}-keto"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Store repository URIs in a map
locals {
  repository_uris = {
    database_provisioner = aws_ecr_repository.database_provisioner.repository_url
    database_migrator    = aws_ecr_repository.database_migrator.repository_url
    kratos               = aws_ecr_repository.kratos.repository_url
    hydra                = aws_ecr_repository.hydra.repository_url
    oathkeeper           = aws_ecr_repository.oathkeeper.repository_url
    keto                 = aws_ecr_repository.keto.repository_url
  }
}

# Push repository URIs to Parameter Store
resource "aws_ssm_parameter" "repositories" {
  name  = "/${var.organization}/${var.project_name}/${var.environment}/container/repository/info"
  type  = "String"
  value = jsonencode(local.repository_uris)
}
