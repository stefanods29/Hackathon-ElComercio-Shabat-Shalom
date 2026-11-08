output "project_name" {
  description = "Proyecto de Pages al que despliega `wrangler pages deploy`."
  value       = cloudflare_pages_project.console.name
}

output "origin" {
  description = "Origen de la consola: va en CONSOLE_ORIGINS de la API del mismo entorno."
  value       = "https://${var.domain}"
}
