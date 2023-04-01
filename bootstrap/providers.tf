terraform {
  cloud {
    # This is the workspace that will be used to bootstrap the Terraform Cloud
    # organization. It will be used to create the workspaces that will be used
    # to deploy the rest of the infrastructure.
    workspaces {
      name = "bootstrap"
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
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project      = var.project_name
      ManagedBy    = "Terraform Cloud"
      Organization = var.organization
      Environment  = var.environment
      Workspace    = terraform.workspace
      Repository   = var.repository
    }
  }
}

provider "tfe" {
  organization = var.organization
}

provider "github" {
  token = var.github_token
}