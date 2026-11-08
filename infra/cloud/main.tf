locals {
  name = "vecinal-${var.environment}"
  minimum_instances = {
    dev = 0, staging = 1, prod = 2
  }
  maximum_instances = {
    dev = 2, staging = 3, prod = 10
  }
  services = toset(["run.googleapis.com", "sqladmin.googleapis.com", "compute.googleapis.com", "servicenetworking.googleapis.com", "secretmanager.googleapis.com", "cloudscheduler.googleapis.com", "artifactregistry.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com"])
  common_environment = {
    NODE_ENV               = "production"
    APP_ENVIRONMENT        = var.environment
    NOTIFICATION_DRIVER    = "fcm"
    POWERSYNC_URL          = var.powersync_url
    MEDIA_DRIVER           = "s3"
    MEDIA_REGION           = "auto"
    MEDIA_ENDPOINT         = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
    MEDIA_BUCKET           = cloudflare_r2_bucket.photos.name
    MEDIA_FORCE_PATH_STYLE = "true"
    CLOUD_SQL_INSTANCE     = google_sql_database_instance.main.connection_name

  }
}
resource "google_project_service" "required" {
  for_each           = local.services
  service            = each.value
  disable_on_destroy = false
}
resource "google_compute_network" "private" {
  name                    = local.name
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required]
}
resource "google_compute_subnetwork" "runtime" {
  name                     = "${local.name}-runtime"
  network                  = google_compute_network.private.id
  region                   = var.region
  ip_cidr_range            = "10.20.0.0/24"
  private_ip_google_access = true
}
resource "google_compute_global_address" "sql" {
  name          = "${local.name}-sql-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private.id
}
resource "google_service_networking_connection" "sql" {
  network                 = google_compute_network.private.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql.name]
}
resource "google_sql_database_instance" "main" {
  name                = local.name
  database_version    = "POSTGRES_18"
  region              = var.region
  deletion_protection = true
  settings {
    tier                  = var.environment == "prod" ? "db-custom-2-7680" : "db-custom-1-3840"
    availability_type     = var.environment == "prod" ? "REGIONAL" : "ZONAL"
    disk_size             = 20
    disk_autoresize       = true
    disk_autoresize_limit = var.environment == "prod" ? 100 : 30
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.private.id
    }
    database_flags {
      name  = "cloudsql.logical_decoding"
      value = "on"
    }
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "08:00"

    }

  }
  depends_on = [google_service_networking_connection.sql]
  lifecycle {
    precondition {
      condition     = var.monthly_budget_reviewed
      error_message = "Revisar y aprobar el presupuesto antes de planificar un despliegue."
    }

  }
}
resource "google_sql_database" "app" {
  name     = "vecinal"
  instance = google_sql_database_instance.main.name
}
resource "cloudflare_r2_bucket" "photos" {
  account_id = var.cloudflare_account_id
  name       = "${var.project_id}-${var.environment}-fotos"
  location   = "ENAM"
  lifecycle {
    prevent_destroy = true
  }
}
resource "google_service_account" "runtime" {
  account_id   = "${local.name}-runtime"
  display_name = "API y worker Media ${var.environment}"
  depends_on   = [google_project_service.required]
}
resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_secret_manager_secret_iam_member" "runtime" {
  for_each  = toset([for reference in values(var.secrets) : reference.name])
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}
resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = local.name
  format        = "DOCKER"
  depends_on    = [google_project_service.required]
}
resource "google_cloud_run_v2_service" "api" {
  name                = "${local.name}-api"
  location            = var.region
  deletion_protection = true
  ingress             = "INGRESS_TRAFFIC_ALL"
  template {
    service_account                  = google_service_account.runtime.email
    max_instance_request_concurrency = 40
    scaling {
      min_instance_count = local.minimum_instances[var.environment]
      max_instance_count = local.maximum_instances[var.environment]
    }
    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.private.name
        subnetwork = google_compute_subnetwork.runtime.name
      }
    }
    containers {
      image = var.image
      ports {
        container_port = 8080
      }
      resources {
        limits = {
          cpu = "1", memory = "1Gi"
        }
      }
      startup_probe {
        http_get {
          path = "/v1/salud"
          port = 8080
        }
        period_seconds    = 10
        failure_threshold = 12
      }
      dynamic "env" {
        for_each = local.common_environment
        content {
          name  = env.key
          value = env.value
        }
      }
      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.name
              version = env.value.version
            }
          }
        }
      }

    }

  }
  depends_on = [google_project_service.required, google_secret_manager_secret_iam_member.runtime, google_project_iam_member.sql_client]
}
resource "google_cloud_run_v2_service_iam_member" "public_api" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
  # Application JWT authentication remains mandatory for all private routes.
}
resource "google_cloud_run_v2_job" "media" {
  name                = "${local.name}-media"
  location            = var.region
  deletion_protection = true
  template {
    task_count  = 1
    parallelism = 1
    template {
      service_account = google_service_account.runtime.email
      timeout         = "900s"
      max_retries     = 1
      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = google_compute_network.private.name
          subnetwork = google_compute_subnetwork.runtime.name
        }
      }
      containers {
        image   = var.image
        command = ["node"]
        args    = ["dist/modules/media/media-worker.js", "--batch=50"]
        resources {
          limits = {
            cpu = "1", memory = "1Gi"
          }
        }
        dynamic "env" {
          for_each = local.common_environment
          content {
            name  = env.key
            value = env.value
          }
        }
        dynamic "env" {
          for_each = var.secrets
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.name
                version = env.value.version
              }
            }
          }
        }

      }

    }

  }
  depends_on = [google_secret_manager_secret_iam_member.runtime, google_project_iam_member.sql_client]
}
resource "google_service_account" "scheduler" {
  account_id = "${local.name}-scheduler"
  depends_on = [google_project_service.required]
}
resource "google_cloud_run_v2_job_iam_member" "scheduler" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.media.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}
resource "google_cloud_scheduler_job" "media" {
  name      = "${local.name}-media"
  region    = var.region
  schedule  = "*/5 * * * *"
  time_zone = "America/Lima"
  paused    = !var.enable_media_schedule
  http_target {
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.media.name}:run"
    http_method = "POST"
    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }

  }
  depends_on = [google_cloud_run_v2_job_iam_member.scheduler]
}

