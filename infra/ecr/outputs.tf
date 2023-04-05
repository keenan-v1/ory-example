output "repository_uris" {
  value = aws_ecr_repository.*.repository_url
}
