# ============================================================================
# Triggers de Cloud Build (CI en Pull Request y CD en push a main)
# Ambos corren con la Service Account dedicada sa-cloudbuild-cicd (sin SA default)
# ============================================================================

resource "google_cloudbuild_trigger" "ci_pr" {
  count           = var.enable_github_triggers ? 1 : 0
  name            = "${var.service_name}-ci-pr"
  location        = var.trigger_location
  description     = "CI en Pull Request hacia main: gitleaks, hadolint, tests, terraform validate y trivy"
  filename        = "cloudbuild/ci.yaml"
  service_account = google_service_account.cicd.id

  github {
    owner = var.github_owner
    name  = var.github_repo
    pull_request {
      branch          = "^main$"
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }
}

resource "google_cloudbuild_trigger" "cd_main" {
  count           = var.enable_github_triggers ? 1 : 0
  name            = "${var.service_name}-cd-main"
  location        = var.trigger_location
  description     = "CD en push a main: build inmutable, push a Artifact Registry, escaneo y deploy a Cloud Run"
  filename        = "cloudbuild/cd.yaml"
  service_account = google_service_account.cicd.id

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }
}
