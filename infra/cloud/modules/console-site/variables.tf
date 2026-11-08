variable "environment" {
  type        = string
  description = "staging o prod. En dev la consola corre con flutter run."
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Elige staging o prod."
  }
}

variable "cloudflare_account_id" {
  type = string
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_account_id))
    error_message = "Se requiere el identificador de la cuenta de Cloudflare."
  }
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zona DNS del dominio de la consola."
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_zone_id))
    error_message = "Se requiere el identificador de la zona DNS de Cloudflare."
  }
}

variable "domain" {
  type        = string
  description = "Dominio de la consola, por ejemplo consola.staging.<dominio>, sin https://."
  validation {
    condition     = can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.domain))
    error_message = "Escribe un dominio en minúsculas, sin https:// ni barra final."
  }
}
