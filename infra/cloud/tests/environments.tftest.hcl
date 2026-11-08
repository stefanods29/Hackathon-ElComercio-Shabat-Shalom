mock_provider "google" {
  mock_resource "google_compute_network" {
    defaults = { id = "projects/vecinal-test-project/global/networks/vecinal" }
  }
}
mock_provider "cloudflare" {}

variables {
  project_id              = "vecinal-test-project"
  environment             = "prod"
  image                   = "southamerica-west1-docker.pkg.dev/vecinal-test-project/vecinal-prod/backend@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  powersync_url           = "https://sync.example.com"
  cloudflare_account_id   = "00000000000000000000000000000000"
  monthly_budget_reviewed = true
  secrets = {
    DATABASE_URL                    = { name = "database-url", version = "1" }
    JWT_PRIVATE_KEY_PEM             = { name = "jwt-private-key", version = "1" }
    FIREBASE_SERVICE_ACCOUNT_BASE64 = { name = "firebase-admin", version = "1" }
    MEDIA_ACCESS_KEY_ID             = { name = "r2-access-key", version = "1" }
    MEDIA_SECRET_ACCESS_KEY         = { name = "r2-secret-key", version = "1" }
  }
}
run "production_is_private_and_bounded" {
  command = plan
  assert {
    condition     = google_sql_database_instance.main.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "La base de datos no debe tener IP pública."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].scaling[0].min_instance_count == 2
    error_message = "Producción necesita dos réplicas mínimas."
  }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].scaling[0].max_instance_count == 10
    error_message = "Debe existir un límite de escalado."
  }
  assert {
    condition     = google_cloud_scheduler_job.media.paused == true
    error_message = "La ejecución programada requiere habilitación explícita."
  }
}
run "development_scales_to_zero" {
  command = plan
  variables { environment = "dev" }
  assert {
    condition     = google_cloud_run_v2_service.api.template[0].scaling[0].min_instance_count == 0
    error_message = "La API de desarrollo debe poder escalar a cero."
  }
}
run "budget_must_be_reviewed" {
  command = plan
  variables { monthly_budget_reviewed = false }
  expect_failures = [google_sql_database_instance.main]
}
