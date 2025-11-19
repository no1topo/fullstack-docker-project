output "backend_image_uri" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_image_uri" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_registry_id" {
  value = aws_ecr_repository.backend.registry_id
}

output "frontend_registry_id" {
  value = aws_ecr_repository.frontend.registry_id
}
