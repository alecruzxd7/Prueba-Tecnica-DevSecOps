output "cloud_run_url" {
  description = "URL pública del servicio Cloud Run."
  value       = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_repo" {
  description = "Ruta del repositorio Docker en Artifact Registry."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "runtime_service_account" {
  description = "Service account de ejecución de Cloud Run."
  value       = google_service_account.run_runtime.email
}

output "cicd_service_account" {
  description = "Service account dedicada del pipeline de Cloud Build."
  value       = google_service_account.cicd.email
}

output "secret_id" {
  description = "Nombre del secreto en Secret Manager."
  value       = google_secret_manager_secret.api_key.secret_id
}

output "binauthz_attestor" {
  description = "Nombre del attestor de Binary Authorization."
  value       = google_binary_authorization_attestor.cicd_attestor.name
}

output "kms_signing_key_version" {
  description = "ID de la versión de la llave asimétrica en Cloud KMS usada para firmar imágenes."
  value       = data.google_kms_crypto_key_version.attestor_key_v1.id
}