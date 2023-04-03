# Terraform Cloud Bootstrap

This folder contains bootstrapping Terraform files.

It is designed to be _run locally_, with state being saved securely in Terraform Cloud. In order to accomplish this, the following steps must be taken:

1. [Login to Terraform Cloud](https://app.terraform.io); create an account if you don't have one.
2. Create your organization if you don't have one.
3. Create a `bootstrap` workspace.
4. Create a User API Token. **Important: Only User tokens can perform plans and applies!**
5. Set the execution to `local`.
6. [Configure your local AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

Why local? The bootstrapping process creates a special IAM user for Terraform runs, since Terraform has neglected to provide a means to use IAM Roles to authenticate.
In this way, your privileged credentials are only ever stored locally.

**NOTE:** This bootstrapping process creates an AWS access key as well as a Terraform Cloud API token. It stores these in Terraform Cloud and GitHub, respectively.
These values are stored in _plaintext_ in your Terraform state. **DO NOT COMMIT YOUR TERRAFORM STATE FILES TO A REPOSITORY!**

To bootstrap, create a `terraform.tfvars` file with the following, replacing placeholders with your own information. Leave out the `oidc_provider_arn` if you have
never setup GitHub OIDC in your AWS environment, otherwise specify the ARN for the provider.

```hcl
github_token="YOUR-SECRET-TOKEN"
terraform_token="YOUR-SECRET-TOKEN"
organization="your-tf-org"
project_name="your-project"
region="aws-region"
repository="owner/repository-name"
environment="your-env"
hosted_zone_name="example.com"
# Optional, only required if you already have an OIDC provider for GitHub!
oidc_provider_arn="arn::of::provider"
```

Next, initialize Terraform and your backend:

```bash
export TF_CLOUD_ORGANIZATION="YOUR-ORG-HERE"
terraform init
```

Finally, it's time to plan and apply. NOTE: Review the plan before applying!

```bash
terraform plan -out bootstrap.tfplan
terraform apply "bootstrap.tfplan"
```
