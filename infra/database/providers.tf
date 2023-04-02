terraform {
  cloud {
    workspaces {
      name = "database"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>4.61.0"
    }
    tfe = {
      version = "~> 0.43.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project      = var.project_name
      ManagedBy    = "Terraform Cloud"
      Organization = var.tfe_organization
      Environment  = var.environment
      Workspace    = terraform.workspace
      Repository   = var.repository
    }
  }
}

provider "tfe" {
  organization = var.tfe_organization
}