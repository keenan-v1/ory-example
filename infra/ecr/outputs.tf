output "repository_uris" {
  value = { for _, name in local.repositories : name => aws_ecr_repository.repositories[name].repository_url }
}
