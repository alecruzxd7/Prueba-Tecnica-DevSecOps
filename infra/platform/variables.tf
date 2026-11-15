variable "project_id" {
  description = "ID del proyecto de GCP."
  type        = string
  default     = "prueba-tecnica-devops-514820"
}

variable "region" {
  description = "Región principal de despliegue."
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "ID de la cuenta de facturación (formato XXXXXX-XXXXXX-XXXXXX) para la alerta de presupuesto."
  type        = string
}

variable "budget_amount_usd" {
  description = "Tope mensual del presupuesto en USD (Regla 2: máximo USD 10)."
  type        = number
  default     = 10
}

variable "service_name" {
  description = "Nombre del servicio en Cloud Run."
  type        = string
  default     = "tramites-app"
}

variable "artifact_repo_id" {
  description = "ID del repositorio Docker en Artifact Registry."
  type        = string
  default     = "tramites-repo"
}

variable "secret_id" {
  description = "ID del secreto en Secret Manager que consume la aplicación."
  type        = string
  default     = "tramites-api-key"
}

variable "initial_image" {
  description = "Imagen inicial fijada por digest para el primer terraform apply (luego el pipeline actualiza la imagen)."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello@sha256:f70f8f419442544f3e2c95684666518b3d565220a4c6a5703d76808427cccf88"
}

variable "github_owner" {
  description = "Usuario u organización de GitHub propietaria del repositorio."
  type        = string
  default     = "alecruzxd7"
}

variable "github_repo" {
  description = "Nombre del repositorio en GitHub."
  type        = string
  default     = "Prueba-Tenica-DevOps"
}

variable "enable_github_triggers" {
  description = "Habilita los triggers automáticos de Cloud Build una vez vinculado el repositorio con la GitHub App."
  type        = bool
  default     = false
}

variable "trigger_location" {
  description = "Ubicación de los triggers de Cloud Build (global por defecto al conectar la GitHub App en consola)."
  type        = string
  default     = "global"
}
