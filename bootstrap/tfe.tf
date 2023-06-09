# Create the origanization
data "tfe_organization" "organization" {
  name = var.organization
}

# Create global variable set for the Terraform Cloud organization
resource "tfe_variable_set" "defaults" {
  name         = "default-tfvars"
  description  = "Default Terraform variables for Terraform Cloud"
  organization = data.tfe_organization.organization.name
  global       = true
}

# Create Terraform Cloud variable for the AWS region
resource "tfe_variable" "region" {
  key             = "region"
  value           = var.region
  sensitive       = false
  category        = "terraform"
  description     = "The AWS region to use"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable for the Terraform Cloud organization
resource "tfe_variable" "organization" {
  key             = "organization"
  value           = data.tfe_organization.organization.name
  sensitive       = false
  category        = "terraform"
  description     = "The Terraform Cloud organization to use"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable for the project name
resource "tfe_variable" "project_name" {
  key             = "project_name"
  value           = var.project_name
  sensitive       = false
  category        = "terraform"
  description     = "The name of the project"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable for the environment
resource "tfe_variable" "environment" {
  key             = "environment"
  value           = var.environment
  sensitive       = false
  category        = "terraform"
  description     = "The environment to use"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable for the repository
resource "tfe_variable" "repository" {
  key             = "repository"
  value           = var.repository
  sensitive       = false
  category        = "terraform"
  description     = "The name of the repository"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable for the Hosted Zone name
resource "tfe_variable" "hosted_zone_name" {
  key             = "hosted_zone_name"
  value           = var.hosted_zone_name
  sensitive       = false
  category        = "terraform"
  description     = "The name of the hosted zone to use for the organization"
  variable_set_id = tfe_variable_set.defaults.id
}

# Create Terraform Cloud variable set for AWS credentials
resource "tfe_variable_set" "aws" {
  name         = "aws-credentials"
  description  = "AWS credentials for Terraform Cloud"
  organization = data.tfe_organization.organization.name
  global       = true
}

# Create Terraform Cloud variable for AWS access key
resource "tfe_variable" "access_key_id" {
  key             = "AWS_ACCESS_KEY_ID"
  value           = aws_iam_access_key.tfe.id
  sensitive       = true
  category        = "env"
  description     = "AWS Access Key ID"
  variable_set_id = tfe_variable_set.aws.id
}

# Create Terraform Cloud variable for AWS access key secret
resource "tfe_variable" "access_key_secret" {
  key             = "AWS_SECRET_ACCESS_KEY"
  value           = aws_iam_access_key.tfe.secret
  sensitive       = true
  category        = "env"
  description     = "AWS Access Key Secret"
  variable_set_id = tfe_variable_set.aws.id
}

# Create Terraform Cloud workspace for the network infrastructure
resource "tfe_workspace" "network" {
  name              = "network"
  organization      = data.tfe_organization.organization.name
  terraform_version = var.terraform_version
}

# Create Terraform Cloud workspace for the ECR infrastructure
resource "tfe_workspace" "ecr" {
  name              = "ecr"
  organization      = data.tfe_organization.organization.name
  terraform_version = var.terraform_version
}

# Create Terraform Cloud workspace for the database infrastructure
resource "tfe_workspace" "database" {
  name              = "database"
  organization      = data.tfe_organization.organization.name
  terraform_version = var.terraform_version
}

# Create Terraform Cloud workspace for the ECS infrastructure
resource "tfe_workspace" "ecs" {
  name              = "ecs"
  organization      = data.tfe_organization.organization.name
  terraform_version = var.terraform_version
}

# Create Terraform Cloud workspace for the Kratos application
resource "tfe_workspace" "kratos" {
  name              = "kratos"
  organization      = data.tfe_organization.organization.name
  terraform_version = var.terraform_version
}

# Create Terraform Cloud variable set for Kratos-specific variables
resource "tfe_variable_set" "kratos" {
  name         = "kratos-tfvars"
  description  = "Kratos-specific variables for Terraform Cloud"
  organization = data.tfe_organization.organization.name
  workspace_ids = [
    tfe_workspace.kratos.id
  ]
}

# Create Terraform Cloud variable for the SMTP server
resource "tfe_variable" "smtp_connection_uri" {
  key             = "smtp_connection_uri"
  value           = var.smtp_connection_uri
  sensitive       = true
  category        = "terraform"
  description     = "SMTP connection URI"
  variable_set_id = tfe_variable_set.kratos.id
}
