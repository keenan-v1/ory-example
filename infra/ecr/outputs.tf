output "repository_uris" {
  value = aws_ecr_repository.repositories.*.repository_url
}
