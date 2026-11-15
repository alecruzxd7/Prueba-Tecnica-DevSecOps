output "tfstate_bucket_name" {
  description = "Nombre del bucket GCS donde se guarda el estado remoto de infra/platform."
  value       = google_storage_bucket.tfstate.name
}

output "enabled_apis" {
  description = "Lista de APIs habilitadas en el proyecto."
  value       = sort(keys(google_project_service.apis))
}
