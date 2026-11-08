output "api_url" {
  value = google_cloud_run_v2_service.api.uri
}
output "database_instance" {
  value = google_sql_database_instance.main.connection_name
}
output "photo_bucket" {
  value = cloudflare_r2_bucket.photos.name
}
output "registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}

