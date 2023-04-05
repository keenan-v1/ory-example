resource "random_password" "password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

data "aws_ssm_parameter" "network_info" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/network/info"
}

data "aws_ssm_parameter" "cidr_allow_list" {
  count = var.cidr_allow_list_parameter == "" ? 0 : 1
  name  = var.cidr_allow_list_parameter
}

locals {
  network_info    = jsondecode(data.aws_ssm_parameter.network_info.value)
  cidr_allow_list = var.cidr_allow_list_parameter == "" ? [] : split(",", data.aws_ssm_parameter.cidr_allow_list[0].value)
}


resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-${var.environment}-database-sg-"
  description = "${title(var.project_name)} ${title(var.environment)} Database Security Group"
  vpc_id      = local.network_info.vpc_id

  ingress {
    description = "Allow database inbound traffic from the VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP"
    cidr_blocks = concat(
      local.network_info.private_subnets_cidr_blocks,
      local.network_info.public_subnets_cidr_blocks,
      local.network_info.database_subnets_cidr_blocks,
      local.cidr_allow_list,
    )
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "default" {
  name_prefix = "${var.project_name}-${var.environment}-pg-"
  family      = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  parameter {
    name  = "sql_mode"
    value = "TRADITIONAL"
  }

  # TODO: Remove this parameter when you are ready to enable foreign key checks.
  # Should find a better way of handling this.
  parameter {
    name  = "foreign_key_checks"
    value = "0"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "database" {
  identifier_prefix     = "${var.project_name}-${var.environment}-"
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = var.db_instance_type
  username              = var.db_admin_username
  password              = random_password.password.result
  publicly_accessible   = true
  storage_type          = "gp2"
  storage_encrypted     = true
  allocated_storage     = 5
  max_allocated_storage = 10
  parameter_group_name  = aws_db_parameter_group.default.name
  skip_final_snapshot   = true # Don't create a snapshot when destroying the database, you may want to change this in production.
  db_subnet_group_name  = local.network_info.database_subnet_group_name
  vpc_security_group_ids = [
    aws_security_group.database.id,
  ]
}

resource "aws_secretsmanager_secret" "database_password" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/database/user/${var.db_admin_username}/password"
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = random_password.password.result
}

locals {
  database_info = {
    identifier = aws_db_instance.database.identifier
    host       = aws_db_instance.database.address
    port       = aws_db_instance.database.port
  }
}

resource "aws_ssm_parameter" "database_info" {
  name  = "/${var.organization}/${var.project_name}/${var.environment}/database/info"
  type  = "String"
  value = jsonencode(local.database_info)
}
