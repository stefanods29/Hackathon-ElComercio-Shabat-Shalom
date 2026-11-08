variable "project_id" {
  type = string
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Elige dev, staging o prod."
  }
}
variable "region" {
  type    = string
  default = "southamerica-west1"
}
variable "image" {
  type        = string
  description = "Imagen ya compilada. Fijar por digest, no por latest."
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "La imagen debe fijarse mediante su digest SHA-256."
  }
}
variable "powersync_url" {
  type = string
  validation {
    condition     = startswith(var.powersync_url, "https://")
    error_message = "PowerSync necesita HTTPS."
  }
}
variable "cloudflare_account_id" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_account_id))
    error_message = "Se requiere el identificador de cuenta R2."
  }
}
variable "secrets" {
  description = "Solo nombres y versiones existentes de Secret Manager. Nunca valores secretos. DATABASE_URL usa credenciales de aplicación y el conector Cloud SQL."
  type = map(object({ name = string, version = string
  }))
  validation {
    condition     = alltrue([for key in ["DATABASE_URL", "JWT_PRIVATE_KEY_PEM", "FIREBASE_SERVICE_ACCOUNT_BASE64", "MEDIA_ACCESS_KEY_ID", "MEDIA_SECRET_ACCESS_KEY"] : contains(keys(var.secrets), key)])
    error_message = "Faltan referencias privadas de base de datos, identidad, Firebase o R2."

  }
}
variable "enable_media_schedule" {
  type    = bool
  default = false
}
variable "monthly_budget_reviewed" {
  type        = bool
  default     = false
  description = "Debe aprobarse el presupuesto antes de generar un plan de despliegue."
}


