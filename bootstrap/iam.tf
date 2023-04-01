# TODO: Restrict access to AWS account
data "aws_iam_policy" "tfe" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create Terraform Cloud user in AWS
resource "aws_iam_user" "tfe" {
  name = local.tfe_user_name
}

# Attach policy to Terraform Cloud user
resource "aws_iam_user_policy_attachment" "tfe" {
  user       = aws_iam_user.tfe.name
  policy_arn = data.aws_iam_policy.tfe.arn
}

# Create access key for Terraform Cloud user
resource "aws_iam_access_key" "tfe" {
  user = aws_iam_user.tfe.name
}
