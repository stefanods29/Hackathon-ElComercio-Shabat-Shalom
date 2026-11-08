# Almacenamiento local de fotos

Desde la raíz:

```powershell
docker compose -f infra/docker-compose.yml -f infra/compose.media.yml config --quiet
docker compose -f infra/docker-compose.yml -f infra/compose.media.yml up -d object-storage prepare-photos telemetry
```

El almacenamiento queda en `fotos_locales`, accesible solo por loopback: puerto 9000 para S3,
9001 para consola. `prepare-photos` crea `vecinal-fotos` sin ACL ni política pública.
Las credenciales del Compose son ficticias y exclusivas de esta prueba local.

La imagen se compila desde el commit oficial MinIO
`9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a` (RELEASE.2025-10-15T17-29-55Z), con licencia
AGPL incluida y proceso sin privilegios. Antes de distribuirla, revisar licencia y actualizaciones
de seguridad. No se reutiliza esta configuración como despliegue público.

Configurar el entorno privado del backend:

```dotenv
MEDIA_DRIVER=s3
MEDIA_BUCKET=vecinal-fotos
MEDIA_REGION=us-east-1
MEDIA_ENDPOINT=http://127.0.0.1:9000
MEDIA_ACCESS_KEY_ID=vecinal-local
MEDIA_SECRET_ACCESS_KEY=vecinal-local-only-2026
MEDIA_FORCE_PATH_STYLE=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
```

Con PostgreSQL y la configuración de Identidad existentes, ejecutar migraciones, API y worker
en procesos separados (ver `backend/src/modules/media/README.md`). El worker no se inicia
automáticamente dentro de la API.

Para un Android conectado o emulador, mantener el mismo origen de la firma mediante:

```powershell
adb reverse tcp:9000 tcp:9000
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=ENABLE_PHOTOS=true --dart-define=API_BASE_URL=http://127.0.0.1:3000 --dart-define=MEDIA_STORAGE_ORIGIN=http://127.0.0.1:9000
```

Ejecutar Flutter desde `app/`; el puerto API debe coincidir con su entorno. Para iOS, configurar
el origen accesible tanto al servidor como al simulador/teléfono; nunca cambiar el host de una
URL después de firmarla. El modo autenticado necesita la sesión real del Lote A.

`telemetry` recibe OTLP HTTP en 4318 y aplica la lista permitida de
`infra/observability/collector.yaml` antes de escribir eventos técnicos en consola. No es un
panel ni almacén de métricas de producción. Sentry sigue siendo opcional y requiere su DSN.

Validación local de Compose/imagen y comprobación en teléfono: ver el informe de evidencias.
El equipo necesita Docker para ejecutar estas instrucciones.
