module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = var.private_subnet_cidrs
  public_subnets   = var.public_subnet_cidrs
  database_subnets = var.database_subnet_cidrs

  create_database_internet_gateway_route = true

  enable_dns_hostnames = true
  enable_dns_support   = true

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

locals {
  network_info = {
    vpc_id                     = module.vpc.vpc_id
    vpc_cidr_block             = module.vpc.vpc_cidr_block
    public_subnet_ids          = module.vpc.public_subnets
    private_subnet_ids         = module.vpc.private_subnets
    database_subnet_ids        = module.vpc.database_subnets
    database_subnet_group_name = module.vpc.database_subnet_group_name
  }
}

resource "aws_ssm_parameter" "network_info" {
  name        = "/${var.project_name}/${var.environment}/network/info"
  description = "Network information for ${var.project_name} ${var.environment} environment"
  type        = "String"
  value       = jsonencode(local.network_info)
}
