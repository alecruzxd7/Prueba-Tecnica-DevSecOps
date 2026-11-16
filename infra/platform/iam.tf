# Service Accounts con mínimo privilegio
# 1- sa-tramites-run: identidad en tiempo de ejecución de Cloud Run
# 2- sa-cloudbuild-cicd: identidad exclusiva del pipeline de Cloud Build


resource "google_service_account" "run_runtime" {
  account_id   = "sa-tramites-run"
  display_name = "Runtime SA para Cloud Run (${var.service_name})"
  description  = "Identidad mínima del servicio Cloud Run; solo lee el secreto ${var.secret_id}."
}

resource "google_service_account" "cicd" {
  account_id   = "sa-cloudbuild-cicd"
  display_name = "CI/CD SA para Cloud Build"
  description  = "Identidad dedicada del pipeline CI/CD con permisos acotados."
}

# Permisos de sa-tramites-run (SOLO sobre el secreto específico) 
resource "google_secret_manager_secret_iam_member" "run_secret_accessor" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run_runtime.email}"
}

# Permisos de sa-cloudbuild-cicd 

# 1. Publicar imágenes únicamente en el repositorio de Artifact Registry de la app
resource "google_artifact_registry_repository_iam_member" "cicd_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd.email}"
}

# 2. Desplegar revisiones en Cloud Run
resource "google_project_iam_member" "cicd_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# 3. Actuar como la SA de runtime de Cloud Run (acotado solo a sa-tramites-run, no a todo el proyecto)
resource "google_service_account_iam_member" "cicd_act_as_runtime" {
  service_account_id = google_service_account.run_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

# 4. Escribir logs de construcción en Cloud Logging (requerido para custom SA con CLOUD_LOGGING_ONLY)
resource "google_project_iam_member" "cicd_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# 5. Permisos mínimos para Binary Authorization (firmar con KMS y registrar la atestación)
resource "google_kms_crypto_key_iam_member" "cicd_signer" {
  crypto_key_id = google_kms_crypto_key.attestor_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_binary_authorization_attestor_iam_member" "cicd_attestor_viewer" {
  project  = var.project_id
  attestor = google_binary_authorization_attestor.cicd_attestor.name
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_container_analysis_note_iam_member" "cicd_note_attacher" {
  project = var.project_id
  note    = google_container_analysis_note.attestor_note.name
  role    = "roles/containeranalysis.notes.attacher"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_occurrences_editor" {
  project = var.project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}