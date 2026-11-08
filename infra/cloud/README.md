# Propuesta de entornos · OpenTofu

Propuesta GCP + R2 compatible con un proyecto Firebase existente. No crea Firebase Auth ni
integra WhatsApp Business. Firebase continúa en avisos; la autenticación SMS la configura B.
No se ha desplegado ningún recurso ni aprobado un presupuesto.

## Qué prepara

Cada entorno (`dev`, `staging`, `prod`) tiene nombres propios para Cloud Run API y Job Media,
Cloud SQL PostgreSQL 18, VPC privada, R2 privado, registro de imágenes e identidades de servicio.
La API usa JWT para las rutas privadas. Solo el transporte HTTP de Cloud Run es público.
Las imágenes deben fijarse por digest SHA-256; la imagen de backend corre como usuario `node`.

| Entorno | Instancias API mín./máx. | Base de datos |
| --- | --- | --- |
| dev | 0 / 2 | Zonal, 1 CPU / 3,75 GiB |
| staging | 1 / 3 | Zonal, 1 CPU / 3,75 GiB |
| prod | 2 / 10 | Regional, 2 CPU / 7,5 GiB |

Cloud SQL carece de IP pública, habilita replicación lógica, backups y recuperación temporal.
El conector oficial de Node usa TLS, credenciales de la carga y la red privada. R2 no tiene
acceso público. La base, Cloud Run y el bucket están protegidos contra borrados accidentales.
La ubicación y la retención definitiva deben acordarse antes de usar datos reales.

El Job procesa como máximo 50 ciclos por ejecución; el programador de cinco minutos está
pausado por defecto. La limpieza de originales/derivados también necesita que corra el worker.
No activar `enable_media_schedule` hasta comprobar subida, procesamiento y baja de extremo a extremo.

## Validar sin credenciales ni recursos

Con OpenTofu 1.13.x:

```powershell
tofu -chdir=infra/cloud fmt -check -recursive
tofu -chdir=infra/cloud init -backend=false -input=false
tofu -chdir=infra/cloud validate
tofu -chdir=infra/cloud test
```

Las pruebas sustituyen proveedores con dobles y verifican aislamiento de base, escalado y
bloqueo por presupuesto. No equivalen a un plan real, prueba de conexión o despliegue.
Versiones de proveedores verificadas en `.terraform.lock.hcl`; conservarlo en Git.

## Preparación pendiente del equipo

1. Acordar proyecto(s) GCP/Firebase y cuenta R2, región, presupuesto mensual, retención y
   acceso del equipo. `monthly_budget_reviewed=false` bloquea el plan de la base hasta revisarlo;
   es una declaración de revisión, no una alerta ni un límite automático de facturación.
2. Preparar un bucket GCS privado para estado remoto con versionado y acceso mínimo. El bloque
   backend no lo crea. Usar prefijos distintos por entorno y un archivo privado de configuración
   en `tofu init -backend-config=...`. No compartir estado local ni credenciales.
3. Crear identidades de despliegue con credenciales temporales; el proveedor Google usa ADC y
   Cloudflare su token de entorno. No guardar claves ni valores secretos en `.tfvars` o en el estado.
4. Compilar/publicar el backend en un registro existente y fijar su digest. El registro de esta
   propuesta puede utilizarse en despliegues posteriores; el primer arranque requiere imagen ya
   disponible y permisos de lectura para Cloud Run.
5. Crear los secretos y versiones en Secret Manager por el canal privado del equipo. Los ejemplos
   contienen solo nombres: URI de base, clave JWT, cuenta Firebase y claves R2 limitadas al bucket.
   Se puede añadir `SENTRY_DSN` y `OTEL_EXPORTER_OTLP_ENDPOINT` como referencias opcionales.
6. Crear un rol PostgreSQL de aplicación con los permisos necesarios, y una identidad separada
   para migraciones. Este módulo no crea ni almacena contraseñas. Con `CLOUD_SQL_INSTANCE`,
   la URI usa usuario/contraseña y nombre de base, sin `sslmode=require`: el conector establece TLS.
   Ejecutar migraciones por una ruta privada con la identidad de migración. Revisar PostGIS,
   publicación y credenciales de replicación de PowerSync con A/B antes de permitir tráfico.
7. Copiar el ejemplo del entorno a un `.tfvars` privado y sustituir todos los marcadores. Revisar
   un plan real con el equipo, especialmente permisos, conectividad, coste y exposición HTTP.
   El despliegue y la revisión de ese plan requieren autorización posterior.
8. Comprobar autenticación real, R2, Firebase, recepción de telemetría, bajas y recuperación; después
   habilitar el Job si procede. Acordar el dominio público para compartir y las asociaciones móviles.

OpenTelemetry está integrado en el código, pero esta propuesta no aloja un recolector/panel
de producción ni proporciona un DSN de Sentry. PowerSync sigue siendo un servicio externo
configurado con su URL; su alojamiento no se resuelve con esta propuesta.

No ejecutar `apply`/`destroy` con marcadores. Los planes pueden contener datos privados y quedan
excluidos de Git, al igual que estados, cachés de proveedores y archivos de variables reales.
