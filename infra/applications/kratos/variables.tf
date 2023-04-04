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

variable "hosted_zone_name" {
  type        = string
  description = "The Route53 hosted zone name to use"
}

variable "smtp_connection_uri" {
  type        = string
  description = "The SMTP connection URI to use"
}

variable "alb_ssl_policy" {
  type        = string
  description = "The SSL policy to use for the ALB"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "image" {
  type        = string
  description = "The image to use"
  default     = "oryd/kratos:v0.11.1"
}

variable "service_name" {
  type        = string
  description = "The name of the service"
  default     = "kratos"
}

variable "db_user" {
  type        = string
  description = "The database user to use"
  default     = "kratos"
}

variable "db_name" {
  type        = string
  description = "The database name to use"
  default     = "kratos"
}
