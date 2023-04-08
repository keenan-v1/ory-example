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

variable "instance_type" {
  type        = string
  description = "The instance type to use"
  default     = "t4g.micro"
}

variable "ami_ssm_parameter" {
  type        = string
  description = "The SSM parameter to use for the AMI"
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/arm64/recommended"
}

variable "cidr_allow_list_parameter" {
  type        = string
  description = "The SSM parameter to use for the comma-separated CIDR allow list. (Optional)"
  default     = ""
}
