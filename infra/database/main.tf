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
  # NOTE FOR PRODUCTION: You will likely want to control this manually or have it reboot during maintenance windows.
  apply_immediately = true
}

resource "aws_secretsmanager_secret" "database_password" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/database/user/${var.db_admin_username}/password"
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = random_password.password.result
}

locals {
  database_runners = toset([
    "database-provisioner",
    # "database-migrator"
  ])
}

data "aws_iam_policy_document" "ecs_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  for_each           = local.database_runners
  name               = "${var.project_name}-${var.environment}-${each.value}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume_role_policy.json
}

resource "aws_cloudwatch_log_group" "runner_log" {
  for_each          = local.database_runners
  name              = "/${var.organization}/${var.project_name}/${var.environment}/ecs/service/${each.value}"
  retention_in_days = 7
}

// Create a CloudWatch logging policy
data "aws_iam_policy_document" "ecs_execution_cloudwatch_logging_policy" {
  for_each = local.database_runners
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.runner_log[each.key].arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution_cloudwatch_logging_policy" {
  for_each = local.database_runners
  name     = "${var.project_name}-${var.environment}-${each.value}-ecs-cloudwatch-logging-policy"
  role     = aws_iam_role.ecs_execution_role[each.value].id
  policy   = data.aws_iam_policy_document.ecs_execution_cloudwatch_logging_policy[each.value].json
}

data "aws_iam_policy_document" "ecs_execution_ecr" {
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetAuthorizationToken"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_execution_ecr" {
  for_each = local.database_runners
  name     = "${var.project_name}-${var.environment}-${each.value}-ecs-ecr"
  role     = aws_iam_role.ecs_execution_role[each.value].id
  policy   = data.aws_iam_policy_document.ecs_execution_ecr.json
}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  for_each           = local.database_runners
  name               = "${var.project_name}-${var.environment}-${each.value}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

// Secrets Manager Read & Write policy
data "aws_iam_policy_document" "ecs_task_secretsmanager_read_write_policy" {
  statement {
    sid = "Create"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = [
      "*"
    ]
  }
  statement {
    sid = "Read"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      aws_secretsmanager_secret.database_password.arn,
      "arn:aws:secretsmanager:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:secret:/${var.organization}/${var.project_name}/${var.environment}/database/user/*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_secretsmanager_read_write_policy" {
  for_each = local.database_runners
  name     = "${var.project_name}-${var.environment}-${each.value}-ecs-task-secretsmanager-read-write-policy"
  role     = aws_iam_role.ecs_task_role[each.value].id
  policy   = data.aws_iam_policy_document.ecs_task_secretsmanager_read_write_policy.json
}

// Describe RDS policy
data "aws_iam_policy_document" "ecs_task_rds_describe_policy" {
  statement {
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_rds_describe_policy" {
  for_each = local.database_runners
  name     = "${var.project_name}-${var.environment}-${each.value}-ecs-task-rds-describe-policy"
  role     = aws_iam_role.ecs_task_role[each.value].id
  policy   = data.aws_iam_policy_document.ecs_task_rds_describe_policy.json
}

locals {
  database_info = {
    identifier = aws_db_instance.database.identifier
    host       = aws_db_instance.database.address
    port       = aws_db_instance.database.port
    runner_log_names = {
      for _, runner in local.database_runners : runner => aws_cloudwatch_log_group.runner_log[runner].name
    }
    runner_execution_roles = {
      for _, runner in local.database_runners : runner => aws_iam_role.ecs_execution_role[runner].arn
    }
    runner_task_roles = {
      for _, runner in local.database_runners : runner => aws_iam_role.ecs_task_role[runner].arn
    }
  }
}

resource "aws_ssm_parameter" "database_info" {
  name  = "/${var.organization}/${var.project_name}/${var.environment}/database/info"
  type  = "String"
  value = jsonencode(local.database_info)
}
