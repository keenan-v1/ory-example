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

variable "cidr_allow_list_parameter" {
  type        = string
  description = "The SSM parameter to use for the comma-separated CIDR allow list. (Optional)"
  default     = ""
}

variable "db_instance_type" {
  type        = string
  description = "The type of database instance to use"
  default     = "db.t4g.micro"
}

variable "db_admin_username" {
  type        = string
  description = "The username of the database admin user"
  default     = "admin"
}
