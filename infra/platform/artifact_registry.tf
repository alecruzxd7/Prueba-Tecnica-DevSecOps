resource "google_artifact_registry_repository" "app" {
  location               = var.region
  repository_id          = var.artifact_repo_id
  description            = "Repositorio Docker inmutable para ${var.service_name}"
  format                 = "DOCKER"
  cleanup_policy_dry_run = false

  docker_config {
    immutable_tags = true
  }

  # Políticas de limpieza para mantener el consumo dentro del free tier (0.5 GB)
  cleanup_policies {
    id     = "delete-older-7d"
    action = "DELETE"
    condition {
      older_than = "604800s" # 7 días
    }
  }

  cleanup_policies {
    id     = "keep-recent-5"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}
