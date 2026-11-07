# Tasks

## 1. Parte 1 · Módulo Media en el backend

- [ ] 1.1 Contrato de `POST /v1/archivos` y `POST /v1/archivos/{id}/confirmar` en `contracts/openapi.yaml`, en un commit propio; verificar con `npx @redocly/cli lint contracts/openapi.yaml`
- [ ] 1.2 Migración `media.archivos`, puerto `ObjectStorage` con adaptadores S3 y de sistema de archivos, y servicio S3 compatible en `infra/docker-compose.yml` y en el job de integración de la CI; verificar con pruebas de integración del adaptador S3 (URL firmada, subida, copia y borrado)
- [ ] 1.3 Registro y confirmación con `@Idempotent()`, solo para el dueño, con tipos y tamaño permitidos; verificar con pruebas de integración (201, 403, 422 `tipo_de_archivo_no_permitido`)
- [ ] 1.4 Trabajo `media.procesar_archivo`: firma de bytes, borrado de EXIF y GPS, variantes WebP y `blurhash`, evento `media.archivo_listo`; verificar con pruebas (tipo falso rechazado, ningún metadato en las variantes)
- [ ] 1.5 Publicación y retiro de variantes en el prefijo público con los eventos de B, `findOwnedReadyFile` en `media/index.ts` y limpieza de archivos vencidos; verificar con pruebas (404 antes de publicar, retiro al ocultar)
- [ ] 1.6 Revisión de licencias de las librerías de imágenes; registrarla en `docs/fase-1/evidencias/fotos.md`
- [ ] 1.7 Compilar y depurar: `npm run verify`, `npm run test:integration`, `npm run graph` y CI en verde

## 2. Parte 2 · Fotos en la app

- [ ] 2.1 Paquetes `image_picker`, `flutter_image_compress` y `background_downloader`, con permisos de cámara y galería en Android e iOS y textos en español; verificar con `flutter analyze` y el build de la CI
- [ ] 2.2 Captura, compresión a unos 250 KB y borrado de EXIF y GPS en `features/fotos/`; verificar con una prueba que el archivo resultante no tiene metadatos de ubicación
- [ ] 2.3 Cola persistente por cuenta con estados visibles, `RetryPolicy`, opción "solo con Wi-Fi" y rechazos definitivos; verificar con pruebas unitarias (reintento, cancelación, borrado, Wi-Fi)
- [ ] 2.4 `PhotoQueuePurger` que implementa `PendingPhotoPurger` del Lote A y componente `PhotoPicker` accesible (hasta 3 fotos); verificar con pruebas de widgets al 200 % y con una prueba de purga
- [ ] 2.5 Prueba en un celular sin señal que sube al reconectar; registrarla en `docs/fase-1/evidencias/fotos.md`
- [ ] 2.6 Compilar y depurar: `tool/verify.sh` y CI en verde

## 3. Parte 3 · Compartir por WhatsApp y enlaces

- [ ] 3.1 Botón compartir con `share_plus` y texto sin datos personales; verificar con una prueba de widgets que revisa el texto generado
- [ ] 3.2 Rutas `/s/:id` y `/p/:id` en `go_router`, destino guardado si no hay sesión; verificar con pruebas del enrutamiento
- [ ] 3.3 Archivos `assetlinks.json` y `apple-app-site-association` y página estática con enlaces a las tiendas en `infra/cdn/publico/`; verificar con `npm test` en `infra/cdn`
- [ ] 3.4 Prueba manual en Android y en iOS; registrarla en `docs/fase-1/evidencias/enlaces.md`
- [ ] 3.5 Compilar y depurar: `tool/verify.sh`, `npm test` en `infra/cdn` y CI en verde

## 4. Parte 4 · Entornos dev · staging · prod

- [ ] 4.1 ADR del proveedor de la nube con el presupuesto de la etapa micro y la matriz 13.2, aprobado por el equipo; verificar que figura en el índice de ADRs
- [ ] 4.2 `infra/tofu/` con PostgreSQL + PostGIS y replicación lógica, almacenamiento y CDN, PowerSync, API y workers, secretos, DNS y PITR; verificar con `tofu validate`, `tofu plan` y, tras aplicar, un `tofu plan` sin cambios
- [ ] 4.3 Despliegue continuo de staging en cada integración a `main` y de producción por etiqueta; verificar con un despliegue de staging desde la CI
- [ ] 4.4 Betas por TestFlight y Google Play (Fastlane), huellas de firma en Firebase y clave APNs; verificar instalando la beta y entrando con un número real
- [ ] 4.5 Correr con el Lote B `npm run test:load` contra staging y actualizar `docs/fase-0/evidencias/capacidad.md`; verificar el informe de p95, errores y cola crítica
- [ ] 4.6 Simulacro de restauración del respaldo de staging; registrarlo en `docs/fase-1/evidencias/entornos.md`
- [ ] 4.7 Compilar y depurar: CI en verde con el despliegue de staging

## 5. Parte 5 · Observabilidad

- [ ] 5.1 ADR de OpenTelemetry y su configuración en la API y los workers con `x-request-id` en las trazas; verificar con una prueba que una traza recorre la API, la base y el worker
- [ ] 5.2 Sentry en el backend y en la app con limpieza de datos personales; verificar con un error de prueba que llega sin el teléfono ni el cuerpo
- [ ] 5.3 Exportar el resumen de sincronización del Lote A y las métricas operativas y de colas; tableros de sincronización, operación y colas; verificar que el tablero muestra el envío de un celular de prueba
- [ ] 5.4 Alertas de cola crítica detenida y de aumento de errores; verificar disparando cada una en staging y registrarlo en `docs/fase-1/evidencias/entornos.md`
- [ ] 5.5 Compilar y depurar: `npm run verify`, `npm run test:integration`, `tool/verify.sh` y CI en verde

## Workflow follow-up

- Entregar cada parte en su rama `f1-lote-c/parte-<n>-<tema>` y pedir la revisión del Lote A.
- Archivar el change cuando el Lote A integre la última parte y la CI esté en verde.
