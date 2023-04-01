locals {
  github_role_name = "${var.project_name}-${var.environment}-github-oidc-role"
  tfe_user_name    = "${var.project_name}-${var.environment}-terraform-cloud"
}
