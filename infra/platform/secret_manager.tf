# Contenedor del secreto en Secret Manager.
resource "google_secret_manager_secret" "api_key" {
  secret_id = var.secret_id

  replication {
    auto {}
  }

  labels = {
    app        = var.service_name
    managed_by = "terraform"
  }
}

# Valor inicial efímero: NO se guarda en terraform.tfstate gracias a ephemeral + secret_data_wo.
# Permite que el primer `terraform apply` levante Cloud Run sin fallar, y puede rotarse
# fuera de banda con: gcloud secrets versions add tramites-api-key --data-file=-
ephemeral "random_password" "initial_api_key" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret_version" "initial" {
  secret                 = google_secret_manager_secret.api_key.id
  secret_data_wo         = ephemeral.random_password.initial_api_key.result
  secret_data_wo_version = 1
}
