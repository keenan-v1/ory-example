output "repository_uris" {
  value = [for repo in aws_ecr_repository.repositories : repo.repository_url]
}
