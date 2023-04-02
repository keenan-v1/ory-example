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
