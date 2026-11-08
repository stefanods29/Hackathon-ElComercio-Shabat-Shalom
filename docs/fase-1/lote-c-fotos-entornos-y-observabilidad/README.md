# Lote C · Fotos, entornos y observabilidad (Fase 1)

| Dato | Valor |
|---|---|
| Dificultad | ★★ Media |
| Área | `backend/src/modules/media/`, `app/lib/features/fotos/` (nuevo), `infra/tofu/` (nuevo), `infra/docker-compose.yml`, `.github/workflows/`, configuración nativa de `app/android` y `app/ios` |
| Change de OpenSpec | `openspec/changes/fase-1-lote-c-fotos-entornos-y-observabilidad/` (proposal, design, specs, tasks) |
| Partes | 5. Fotos (1–2), enlaces (3) e infraestructura (4–5) avanzan en paralelo |
| Depende de | Moderación de B (parte 5) para las imágenes; métricas de A (parte 3) para los tableros |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Módulo Media en el backend | Pendiente | Por asignar | — |
| 2 | Fotos en la app | Pendiente | Por asignar | — |
| 3 | Compartir por WhatsApp y enlaces | Pendiente | Por asignar | — |
| 4 | Entornos dev · staging · prod | Pendiente | Por asignar | — |
| 5 | Observabilidad | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## 0. Antes de empezar

### 0.1 Reglas

Las de la Fase 0 ([`../../fase-0/lote-c-mapas-y-avisos/README.md`](../../fase-0/lote-c-mapas-y-avisos/README.md))
y las [reglas comunes de la fase](../README.md#reglas-para-todos-los-lotes). Las credenciales de la
nube, de Sentry y del almacenamiento nunca van al repo: viven en el gestor de secretos de cada
entorno y en los secretos de GitHub Actions. Cada variable nueva se documenta en
`backend/.env.example`.

### 0.2 Lo que ya existe

- CDN local (`infra/cdn/`) con soporte de Range y CORS; avisos por token y por tópico (Fase 0,
  Lote C).
- Puerto `JobQueue` con pg-boss y workers separados (Fase 0, Lote B): el procesamiento de imágenes
  es un trabajo más.
- CI de backend, app (APK) e iOS en `.github/workflows/`.

---

## Parte 1 · Módulo Media en el backend

- Tabla `media.archivos`: `id`, `propietario_id`, `storage_key`, `tipo`, `bytes`, `ancho`, `alto`,
  `blurhash`, `estado` (`pendiente`, `procesando`, `listo` o `rechazado`) y `creado_en`. La foto
  vive en el almacenamiento de objetos, nunca en la base de datos.
- `POST /v1/archivos` (`@Idempotent()`): valida tipo y tamaño y devuelve una URL firmada de subida
  que vence en minutos. `POST /v1/archivos/{id}/confirmar` encola `media.procesar_archivo`.
- El worker comprueba el tipo real por su firma de bytes, vuelve a borrar EXIF y GPS (segunda
  barrera), genera miniaturas y `blurhash`, y deja la imagen en revisión para el Lote B (parte 5).
- Local: un almacenamiento compatible con S3 en `infra/docker-compose.yml`. En la nube, el del
  entorno (Cloudflare R2 no cobra la salida, sección 11).

Pruebas: integración con el almacenamiento local (URL firmada, confirmación, miniaturas, EXIF
borrado, tipo falso rechazado) y una revisión de licencias de las librerías de imágenes
(sección 14).

## Parte 2 · Fotos en la app

- `features/fotos/`: tomar o elegir (`image_picker`), comprimir a unos 250 KB y borrar EXIF y GPS
  en el celular (`flutter_image_compress`).
- Subida en segundo plano (`background_downloader`) con una cola persistente que muestra
  "Guardado en tu celular", "Enviando…", "Enviado" o "No se pudo completar". Reintenta con la
  misma política que la cola de datos y respeta la opción "subir solo con Wi-Fi".
- El registro (reseña o servicio) viaja por PowerSync y la foto por su propia cola. El Lote A
  (parte 4) borra las fotos pendientes al cerrar sesión.

Pruebas: unitarias de la cola (reintento, cancelación, borrado); prueba de que el archivo
resultante no tiene EXIF; prueba en un celular sin señal que sube al reconectar.

## Parte 3 · Compartir por WhatsApp y enlaces

- Botón compartir (`share_plus`) en servicios y publicaciones, con un texto corto y un enlace del
  tipo `https://<dominio>/s/<id>` o `/p/<id>`, sin datos personales.
- Enlaces profundos con `go_router`, más los archivos de verificación de Android App Links y de
  iOS Universal Links servidos desde el dominio. Si la app no está instalada, el enlace abre una
  página estática con los enlaces a las tiendas.

Pruebas: prueba del enrutamiento de enlaces y una prueba manual en Android y en iOS.

## Parte 4 · Entornos dev · staging · prod

- `infra/tofu/` con OpenTofu (o Terraform): PostgreSQL gestionado con PostGIS y replicación lógica
  (confirmar la disponibilidad de PostgreSQL 18 + PostGIS 3.6 en el proveedor, matriz 13.2),
  almacenamiento de objetos con CDN, PowerSync, API y workers en contenedores con autoescalado,
  secretos, DNS y backups con recuperación a un punto en el tiempo (PITR).
- Despliegue continuo: staging en cada integración a `main` y producción con una etiqueta. Betas
  móviles por TestFlight y por las pruebas internas de Google Play (Fastlane o Codemagic).
- Ingreso por SMS ([ADR 0009](../../adr/0009-proveedor-de-codigos-firebase.md)):
  - Registrar en Firebase las huellas SHA-1 y SHA-256 de la clave de firma de Google Play (*App
    signing*) y de la clave de subida.
  - Con la app instalada desde Play, Play Integrity la reconoce y el vecino no ve la página de
    verificación.
  - Comprobar con un celular sin Google Play o con otro navegador predeterminado que la página
    de reCAPTCHA vuelve a la app.
  - En iOS, cargar la clave APNs para el ingreso por teléfono.
- Con B: correr en staging la prueba de capacidad de la Fase 0 (`npm run test:load`) y cerrar ese
  criterio.
- Un simulacro de restauración del backup, documentado.

Pruebas: `tofu plan` sin cambios después de aplicar, despliegue de staging desde el CI y un
simulacro de restauración con resultado en `evidencias/entornos.md`.

## Parte 5 · Observabilidad

- OpenTelemetry en el backend (trazas, métricas y logs) y Sentry en el backend y en la app
  (`sentry_flutter`), con limpieza de datos personales: sin teléfonos, contenido ni ubicaciones.
- Tableros de sincronización (métricas de A, parte 3), de operación (`GET /v1/operacion/metricas`)
  y de colas, con alertas básicas (cola crítica detenida o errores en aumento).

Pruebas: un error de prueba llega a Sentry sin datos personales y una traza recorre la API, la
base de datos y el worker.

---

## Puntos de contacto con otros lotes

- **A:** CDN del directorio de emergencia, métricas de sincronización y fotos pendientes.
- **B:** moderación de imágenes, `archivoId` en reseñas y servicios, capacidad en staging.
- **D:** componentes de foto y de compartir para sus pantallas.

## Fuera de alcance

Consola web y SMS de respaldo (Fase 2); WAF, más distritos y costos a escala (Fase 3).

## Definición de terminado del lote

Las 5 partes aprobadas e integradas, staging y producción creados con OpenTofu y las evidencias de
fotos y entornos listas para los criterios de salida.
