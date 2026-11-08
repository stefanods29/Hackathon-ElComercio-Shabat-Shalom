# Módulo `console-site`

Sitio estático de la consola de operación (Fase 2, Lote C) en Cloudflare Pages, con su dominio y
su registro DNS. Va junto al OpenTofu de la Fase 1 (Lote C, `infra/cloud/`), que ya usa el
proveedor de Cloudflare para las fotos.

## Qué crea

| Recurso | Para qué |
|---|---|
| `cloudflare_pages_project.console` | Proyecto `vecinal-consola-<entorno>` de subida directa |
| `cloudflare_pages_domain.console` | El dominio propio de la consola en Pages |
| `cloudflare_dns_record.console` | El CNAME del dominio hacia `<proyecto>.pages.dev`, con proxy |

No guarda ningún secreto. El token de Cloudflare vive en el entorno de quien aplica el plan
(`CLOUDFLARE_API_TOKEN`) y en los secretos de GitHub del flujo de despliegue.

## Uso desde `infra/cloud/main.tf`

Cuando la Fase 1 (Lote C) esté en `main`:

```hcl
module "console_site" {
  source                = "./modules/console-site"
  count                 = var.environment == "dev" ? 0 : 1
  environment           = var.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  domain                = var.console_domain
}
```

`cloudflare_zone_id` y `console_domain` son variables nuevas de `infra/cloud/variables.tf`, con
sus valores en `environments/<entorno>.tfvars`.

## Después de aplicar

1. Poner la salida `origin` en `CONSOLE_ORIGINS` de la API del mismo entorno (solo `https://`).
2. Compilar la consola y escribir sus encabezados (ver `consola/README.md`):

   ```bash
   cd consola
   tool/vendor_maplibre.sh
   flutter build web --release --no-web-resources-cdn \
     --dart-define=CONSOLE_ENV=staging \
     --dart-define=API_BASE_URL=https://api.staging.<dominio> \
     --dart-define=MAP_STYLE_URL=https://cdn.staging.<dominio>/estilos/vecinal.json
   tool/write_headers.sh https://api.staging.<dominio> https://cdn.staging.<dominio>
   ```

3. Desplegar: `npx wrangler pages deploy build/web --project-name=vecinal-consola-staging`.

## Verificar (pendiente)

`tofu -chdir=infra/cloud fmt -check -recursive`, `tofu -chdir=infra/cloud init -backend=false`
y `tofu -chdir=infra/cloud validate`.
