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
  lb_domain     = "auth.${var.environment}.${var.hosted_zone_name}"
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

resource "random_password" "application_secrets" {
  count            = 3
  length           = 32
  special          = true
  override_special = "_%@"
}

locals {
  application_secrets = {
    dsn             = "mysql://${var.db_user}:${data.aws_secretsmanager_secret_version.db_user_password.secret_string}@${local.database_info.host}:${local.database_info.port}/${var.db_name}?parseTime=true"
    secrets_cookie  = random_password.application_secrets[0].result
    secrets_cipher  = random_password.application_secrets[1].result
    secrets_default = random_password.application_secrets[2].result
  }
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

resource "aws_ecs_task_definition" "service" {
  family             = var.service_name
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode(
    [
      {
        name            = var.service_name
        image           = var.image
        cpu             = 256
        memory          = 512
        essential       = true
        cpuArchitecture = "ARM64"
        portMappings = [
          {
            containerPort = 4433
            hostPort      = 0
          },
          {
            containerPort = 4434
            hostPort      = 0
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.log.name
            awslogs-region        = var.region
            awslogs-stream-prefix = "ecs-${var.service_name}-"
          }
        }
        secrets = [
          {
            name      = "DSN",
            valueFrom = "${aws_secretsmanager_secret.application_secrets.arn}:dsn::"
          },
          {
            name      = "SECRETS_COOKIE",
            valueFrom = "${aws_secretsmanager_secret.application_secrets.arn}:secrets_cookie::"
          },
          {
            name      = "SECRETS_CIPHER",
            valueFrom = "${aws_secretsmanager_secret.application_secrets.arn}:secrets_cipher::"
          },
          {
            name      = "SECRETS_DEFAULT",
            valueFrom = "${aws_secretsmanager_secret.application_secrets.arn}:secrets_default::"
          }
        ]
      }
    ]
  )
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = local.cluster_info.cluster_name
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 2

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
    ignore_changes = [desired_count, task_definition]
  }
}
