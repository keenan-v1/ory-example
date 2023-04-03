variable "region" {
  type        = string
  description = "The AWS region to use"
}

variable "organization" {
  type        = string
  description = "The Terraform Cloud organization to use"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment to use"
}

variable "repository" {
  type        = string
  description = "The name of the repository"
}

variable "github_token" {
  type        = string
  description = "The GitHub token to use"
}

variable "terraform_version" {
  type        = string
  description = "The version of Terraform to use"
  default     = "1.4.4"
}

variable "terraform_token" {
  type        = string
  description = "The Terraform Cloud token to use"
}

variable "hosted_zone_name" {
  type        = string
  description = "The name of the hosted zone to use for the organization"
}

variable "smtp_connection_uri" {
  type        = string
  description = "The SMTP connection URI to use"
}

variable "oidc_provider_arn" {
  type        = string
  description = "The ARN of the OIDC provider to use"
  default     = ""
}

variable "github_thumbprint" {
  type        = string
  description = "The thumbprint of the GitHub certificate"
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

variable "github_max_session_duration" {
  type        = number
  description = "The maximum session duration for GitHub"
  default     = 3600
}
