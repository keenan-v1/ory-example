data "aws_ssm_parameter" "network_info" {
  name = "/${var.organization}/${var.project_name}/${var.environment}/network/info"
}

data "aws_ssm_parameter" "cidr_allow_list" {
  count = var.cidr_allow_list_parameter == "" ? 0 : 1
  name  = var.cidr_allow_list_parameter
}

locals {
  name            = "${var.project_name}-${var.environment}"
  cluster_name    = "${local.name}-cluster"
  network_info    = jsondecode(data.aws_ssm_parameter.network_info.value)
  cidr_allow_list = var.cidr_allow_list_parameter == "" ? [] : split(",", data.aws_ssm_parameter.cidr_allow_list[0].value)
  user_data       = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.cluster_name}
    ECS_LOGLEVEL=debug
    EOF
  EOT
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-asg-sg"
  description = "Autoscaling group security group"
  vpc_id      = local.network_info.vpc_id

  ingress_rules = ["ssh-tcp", "all-icmp"]
  ingress_cidr_blocks = concat(
    local.network_info.private_subnets_cidr_blocks,
    local.cidr_allow_list
  )

  egress_rules = ["all-all"]
}

data "aws_ssm_parameter" "ecs_ami" {
  name = var.ami_ssm_parameter
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "read_ssm_secretsmanager" {
  statement {
    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.organization}/${var.project_name}/${var.environment}/*",
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:/${var.organization}/${var.project_name}/${var.environment}/*"
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "read_ssm_secretsmanager" {
  name        = "${local.name}-read-ssm-secretsmanager"
  description = "Allows read access to the Secrets Manager"
  policy      = data.aws_iam_policy_document.read_ssm_secretsmanager.json
}


module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  name = "${local.name}-asg"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_ami.value)["image_id"]
  instance_type = var.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}-asg"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ReadSSMSecretsManager               = aws_iam_policy.read_ssm_secretsmanager.arn
  }

  vpc_zone_identifier = local.network_info.private_subnets_ids
  health_check_type   = "EC2"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${local.cluster_name}"
  retention_in_days = 7
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "4.1.3"

  cluster_name = local.cluster_name

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs.name
      }
    }
  }

  default_capacity_provider_use_fargate = false

  autoscaling_capacity_providers = {
    one = {
      auto_scaling_group_arn         = module.autoscaling.autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

      default_capacity_provider_strategy = {
        weight = 100
        base   = 20
      }
    }
  }
}

locals {
  cluster_info = {
    cluster_name                  = module.ecs.cluster_name
    cluster_arn                   = module.ecs.cluster_arn
    autoscaling_group_id          = module.autoscaling.autoscaling_group_id
    autoscaling_group_arn         = module.autoscaling.autoscaling_group_arn
    autoscaling_security_group_id = module.autoscaling_sg.security_group_id
  }
}

resource "aws_ssm_parameter" "cluster_info" {
  name        = "/${var.organization}/${var.project_name}/${var.environment}/cluster/info"
  description = "ECS cluster info"
  type        = "String"
  value       = jsonencode(local.cluster_info)
  overwrite   = true
}
