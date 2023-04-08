data "aws_ssm_parameter" "network_info" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/network/info"
}

data "aws_ssm_parameter" "cluster_info" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/cluster/info"
}

data "aws_ssm_parameter" "database_info" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/database/info"
}

locals {
  network_info  = jsondecode(data.aws_ssm_parameter.network_info.value)
  cluster_info  = jsondecode(data.aws_ssm_parameter.cluster_info.value)
  database_info = jsondecode(data.aws_ssm_parameter.database_info.value)
  base_domain   = var.environment == "production" ? var.hosted_zone_name : "${var.environment}.${var.hosted_zone_name}"
  lb_domain     = "auth.${local.base_domain}"
}

data "aws_route53_zone" "domain" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "cert" {
  domain_name       = local.lb_domain
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.6.0"

  name = "${var.project_name}-${var.environment}-alb"

  load_balancer_type = "application"

  vpc_id  = local.network_info.vpc_id
  subnets = local.network_info.public_subnet_ids

  security_group_name = "${var.project_name}-${var.environment}-alb-sg"
  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "HTTP web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress_all_https = {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS web traffic"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress_all_icmp = {
      type        = "ingress"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      description = "ICMP"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  target_groups = [
    {
      name_prefix          = "pub-"
      backend_protocol     = "HTTP"
      backend_port         = 4433
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health/alive"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    },
    {
      name_prefix          = "adm-"
      backend_protocol     = "HTTP"
      backend_port         = 4434
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/health/alive"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listeners = [
    {
      port                              = 443
      protocol                          = "HTTPS"
      certificate_arn                   = aws_acm_certificate.cert.arn
      default_action_type               = "forward"
      default_action_target_group_index = 0
    }
  ]

  https_listener_rules = [
    {
      https_listener_index = 0
      priority             = 100

      actions = [
        {
          type               = "forward"
          target_group_index = 1
        }
      ]

      conditions = [{
        path_patterns = ["/admin/*"]
      }]
    }
  ]
}

resource "aws_route53_record" "lb" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = local.lb_domain
  type    = "A"

  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_autoscaling_attachment" "asg_to_alb" {
  count                  = length(module.alb.target_group_arns)
  autoscaling_group_name = local.cluster_info.autoscaling_group_id
  lb_target_group_arn    = module.alb.target_group_arns[count.index]
}

resource "aws_cloudwatch_log_group" "log" {
  name              = "/${var.organization}/${var.project_name}/${var.environment}/ecs/service/${var.service_name}"
  retention_in_days = 7
}

data "aws_secretsmanager_secret" "db_user_password" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/database/user/${var.db_user}/password"
}

data "aws_secretsmanager_secret_version" "db_user_password" {
  secret_id = data.aws_secretsmanager_secret.db_user_password.id
}

resource "aws_security_group_rule" "alb" {
  security_group_id        = local.cluster_info.autoscaling_security_group_id
  type                     = "ingress"
  protocol                 = "TCP"
  from_port                = 1
  to_port                  = 65535
  source_security_group_id = module.alb.security_group_id
}

resource "random_password" "application_secrets" {
  count            = 3
  length           = 32
  special          = true
  override_special = "_%@"
}

locals {
  application_secrets = {
    dsn                 = "mysql://${var.db_user}:${data.aws_secretsmanager_secret_version.db_user_password.secret_string}@tcp(${local.database_info.host}:${local.database_info.port})/${var.db_name}?parseTime=true"
    secrets_cookie      = random_password.application_secrets[0].result
    secrets_cipher      = random_password.application_secrets[1].result
    secrets_default     = random_password.application_secrets[2].result
    smtp_connection_uri = var.smtp_connection_uri
  }
  family_name = "${var.organization}-${var.project_name}-${var.environment}-${var.service_name}"
}

resource "aws_secretsmanager_secret" "application_secrets" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/application/${var.service_name}"
}

resource "aws_secretsmanager_secret_version" "application_secrets" {
  secret_id     = aws_secretsmanager_secret.application_secrets.id
  secret_string = jsonencode(local.application_secrets)
}

data "aws_iam_policy_document" "ecs_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_secrets_manager_policy" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      aws_secretsmanager_secret.application_secrets.arn,
    ]
  }
}

// Create a CloudWatch logging policy
data "aws_iam_policy_document" "ecs_task_cloudwatch_logging_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "${aws_cloudwatch_log_group.log.arn}:*",
    ]
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "${var.project_name}-${var.environment}-${var.service_name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_execution_assume_role_policy.json
}

resource "aws_iam_role_policy" "ecs_task_secrets_manager_policy" {
  name   = "${var.project_name}-${var.environment}-${var.service_name}-ecs-task-secrets-manager-policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_secrets_manager_policy.json
}

resource "aws_iam_role_policy" "ecs_task_cloudwatch_logging_policy" {
  name   = "${var.project_name}-${var.environment}-${var.service_name}-ecs-task-cloudwatch-logging-policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = data.aws_iam_policy_document.ecs_task_cloudwatch_logging_policy.json
}

data "aws_iam_policy_document" "ecr" {
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

resource "aws_iam_role_policy" "ecs_task_ecr" {
  name   = "${var.project_name}-${var.environment}-${var.service_name}-ecs-task-ecr"
  role   = aws_iam_role.ecs_execution_role.id
  policy = data.aws_iam_policy_document.ecr.json
}

# Dummy task definition to force ECS to create the service
# This is replaced by GitHub Actions
resource "aws_ecs_task_definition" "service" {
  family             = local.family_name
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode(
    [
      {
        name            = var.service_name
        image           = var.image
        cpu             = 128
        memory          = 512
        essential       = true
        cpuArchitecture = "ARM64"
      }
    ]
  )
  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = local.cluster_info.cluster_name
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 0
  propagate_tags  = "SERVICE"

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  # placement_constraints {
  # type       = "distinctInstance"
  # expression = ""
  # }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  capacity_provider_strategy {
    capacity_provider = "one"
    weight            = 100
    base              = 20
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[0]
    container_name   = var.service_name
    container_port   = 4433
  }

  load_balancer {
    target_group_arn = module.alb.target_group_arns[1]
    container_name   = var.service_name
    container_port   = 4434
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_count, task_definition]
  }
}

# Set the application info in SSM, this is consumed by GitHub Actions
locals {
  application_info = {
    family_name         = aws_ecs_task_definition.service.family
    cluster_name        = local.cluster_info.cluster_name
    container_name      = var.service_name
    service_name        = aws_ecs_service.service.name
    service_id          = aws_ecs_service.service.id
    execution_role_arn  = aws_iam_role.ecs_execution_role.arn
    task_definition_arn = aws_ecs_task_definition.service.arn_without_revision
    secrets_arn         = aws_secretsmanager_secret.application_secrets.arn
    log_group           = aws_cloudwatch_log_group.log.name
    app_domain          = local.lb_domain
    base_domain         = local.base_domain
  }
}

resource "aws_ssm_parameter" "application_info" {
  name        = "/${var.organization}/${var.project_name}/${var.environment}/application/${var.service_name}/info"
  description = "Application info"
  type        = "String"
  value       = jsonencode(local.application_info)
}

moved {
  from = aws_ssm_parameter.application_into
  to   = aws_ssm_parameter.application_info
}
