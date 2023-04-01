module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  database_subnet_group_name = "${var.project_name}-${var.environment}-database-subnet-group"

  enable_ipv6 = true

  public_subnet_tags = {
    Name  = "${var.project_name}-${var.environment}-public-subnet"
    Usage = "public"
  }

  private_subnet_tags = {
    Name  = "${var.project_name}-${var.environment}-private-subnet"
    Usage = "private"
  }

  database_subnet_tags = {
    Name  = "${var.project_name}-${var.environment}-database-subnet"
    Usage = "database"
  }

  vpc_tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}
