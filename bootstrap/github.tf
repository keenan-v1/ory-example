# Push the Terraform Cloud token to GitHub as an Actions Secret
resource "github_actions_secret" "terraform_cloud_token" {
  repository      = split("/", var.repository)[1]
  secret_name     = "terraform_cloud_token"
  plaintext_value = tfe_organization_token.token.token
}

# Create the Terraform Cloud organization variable in GitHub
resource "github_actions_variable" "terraform_cloud_organization" {
  repository    = split("/", var.repository)[1]
  variable_name = "terraform_cloud_organization"
  value         = data.tfe_organization.organization.name
}

# Add AWS Region to GitHub Actions Variables
resource "github_actions_variable" "aws_region" {
  repository    = split("/", var.repository)[1]
  variable_name = "aws_region"
  value         = var.region
}

# GitHub OIDC
resource "aws_iam_openid_connect_provider" "oidc" {
  count = var.oidc_provider_arn == "" ? 1 : 0
  client_id_list = [
    "sts.amazonaws.com",
  ]
  thumbprint_list = [var.github_thumbprint]
  url             = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "oidc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test = "StringLike"
      values = [
        "repo:%{if length(regexall(":+", var.repository)) > 0}${var.repository}%{else}${var.repository}:*%{endif}"
      ]
      variable = "token.actions.githubusercontent.com:sub"
    }

    principals {
      identifiers = ["${var.oidc_provider_arn == "" ? join("", aws_iam_openid_connect_provider.oidc.*.arn) : var.oidc_provider_arn}"]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "oidc" {
  name                 = local.github_role_name
  description          = "Role for GitHub Actions for the ${var.project_name} project"
  max_session_duration = var.github_max_session_duration
  assume_role_policy   = data.aws_iam_policy_document.oidc.json
  depends_on           = [aws_iam_openid_connect_provider.oidc]
}

# TODO: Create least privilege policy
resource "aws_iam_role_policy_attachment" "attach" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.oidc.name
  depends_on = [aws_iam_role.oidc]
}

# Add OIDC Role ARN to GitHub Actions Variables
resource "github_actions_variable" "oidc_role_arn" {
  repository    = split("/", var.repository)[1]
  variable_name = "aws_role"
  value         = aws_iam_role.oidc.arn
}
