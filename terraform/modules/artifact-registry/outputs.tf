output "repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}

output "repository_name" {
  value = google_artifact_registry_repository.docker.name
}

output "image_prefix" {
  description = "Prefix to tag images with, e.g. <prefix>/demo-app:<sha>."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}
