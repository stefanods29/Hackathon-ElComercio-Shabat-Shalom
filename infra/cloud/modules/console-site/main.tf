# Sitio estático de la consola de operación (Fase 2, Lote C) en Cloudflare Pages, con su dominio.
# Los encabezados de seguridad (CSP, index.html sin caché) viajan en el archivo _headers del
# build: consola/tool/write_headers.sh lo escribe para cada entorno antes de desplegar.

locals {
  name = "vecinal-consola-${var.environment}"
}

# Proyecto de subida directa: el build llega con `wrangler pages deploy`, no desde un repositorio.
resource "cloudflare_pages_project" "console" {
  account_id        = var.cloudflare_account_id
  name              = local.name
  production_branch = "main"
}

resource "cloudflare_pages_domain" "console" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.console.name
  name         = var.domain
}

resource "cloudflare_dns_record" "console" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CNAME"
  content = cloudflare_pages_project.console.subdomain
  proxied = true
  ttl     = 1
  comment = "Consola de operación (${var.environment})"
}
