resource "google_kms_key_ring" "binauthz" {
  name     = "${var.service_name}-binauthz-kr"
  location = var.region
}

resource "google_kms_crypto_key" "attestor_key" {
  name                       = "${var.service_name}-attestor-key"
  key_ring                   = google_kms_key_ring.binauthz.id
  purpose                    = "ASYMMETRIC_SIGN"
  destroy_scheduled_duration = "86400s"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"
  }
}

data "google_kms_crypto_key_version" "attestor_key_v1" {
  crypto_key = google_kms_crypto_key.attestor_key.id
  version    = 1
  depends_on = [google_kms_crypto_key.attestor_key]
}

resource "google_container_analysis_note" "attestor_note" {
  name = "${var.service_name}-attestor-note"

  attestation_authority {
    hint {
      human_readable_name = "Attestor CI/CD para ${var.service_name}"
    }
  }
}

resource "google_binary_authorization_attestor" "cicd_attestor" {
  name        = "${var.service_name}-attestor"
  description = "Attestor que verifica que la imagen fue construida y escaneada por el pipeline CD"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor_note.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor_key_v1.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor_key_v1.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.attestor_key_v1.public_key[0].algorithm
      }
    }
  }
}

resource "google_binary_authorization_policy" "policy" {
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.cicd_attestor.name]
  }

  admission_whitelist_patterns {
    name_pattern = "us-docker.pkg.dev/cloudrun/container/*"
  }

  depends_on = [google_cloud_run_v2_service.app]
}