# Módulo `media`

**Responsabilidad:** borradores de fotos privados, URLs firmadas, saneamiento, miniaturas y borrado recuperable. Lote C · Fase 1.

**Entidades principales:** Archivo.

La aprobación y la asociación a perfiles/reseñas/publicaciones pertenecen a B. `listo` significa
procesado, no publicado ni moderado. Nunca usar la existencia de un archivo como autorización pública.

## Estructura (igual en todos los módulos)

```text
media/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── media.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`media.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_media_<descripcion>.ts`.

## Flujo y límites

1. `POST /v1/archivos`: UUID del cliente, SHA-256, bytes y tipo. Requiere cuenta autenticada,
   zona y confianza ≥1. Máximo 2 MiB, JPEG/PNG/WebP y 20 reservas por cuenta en 24 horas.
2. `POST /v1/archivos/:id/subida`: PUT de un solo objeto, 5 minutos, tamaño/tipo y
   `If-None-Match: *` firmados. Conservar todos los encabezados devueltos. Renovar con otra
   `Idempotency-Key`; repetir una clave devuelve su respuesta original, incluso si ya venció.
3. `POST /v1/archivos/:id/confirmar`: verifica existencia y cabeceras, y encola el archivo.
4. El worker verifica bytes y SHA-256, decodifica con límite de 20 megapíxeles, orienta y
   reescribe WebP sin EXIF/XMP/ICC/GPS. Principal ≤1280 px, miniatura ≤320 px, sin ampliar;
   genera blurhash. SVG, animación y contenido ilegible se rechazan.
5. `GET /v1/archivos/:id`: solo el dueño; devuelve estado y, cuando está listo, URLs privadas
   de lectura por 5 minutos. Las respuestas con firmas llevan `Cache-Control: no-store`.
6. `POST /v1/archivos/:id/baja`: baja lógica inmediata. La limpieza física espera a que
   expiren firmas/leases para impedir que una transferencia antigua recree el original.

Todas las escrituras requieren `Idempotency-Key`. Consultar los DTO en
`contracts/openapi.yaml`; no guardar URLs firmadas en PowerSync, publicaciones o registros.

La fila persistente de Media conserva el estado de su procesamiento. `SKIP LOCKED`, lease de
5 minutos, tres intentos y nombres de derivados por lease permiten varios workers y recuperación
tras una interrupción. Un worker vencido no sustituye ni borra derivados de otro. La limpieza
tiene su propio lease. Los originales sin confirmar caducan a las 24 horas; los borradores listos
siguen privados hasta su baja. El acuerdo de retención de publicaciones se completará con B.
Esta cola de procesamiento no reemplaza la cola general de trabajos del Lote B.

## Ejecutar

`MEDIA_DRIVER=disabled` es el valor por defecto. Para pruebas se inyecta `FakeObjectStore`;
`fake` está prohibido en producción. Para un bucket privado configurar en el entorno:

| Variable | Uso |
| --- | --- |
| `MEDIA_DRIVER=s3` | S3 o R2 compatible |
| `MEDIA_BUCKET` | Nombre del bucket privado |
| `MEDIA_ENDPOINT` | Endpoint HTTPS de R2; HTTP solo para desarrollo local |
| `MEDIA_REGION=auto` | Región de R2 |
| `MEDIA_ACCESS_KEY_ID`, `MEDIA_SECRET_ACCESS_KEY` | Credenciales limitadas al bucket |
| `MEDIA_FORCE_PATH_STYLE=true` | Compatible con R2 y almacenamiento local |

Aplicar migraciones (`npm run db:migrate`), compilar (`npm run build`) y ejecutar
`npm run start:media-worker` en un proceso separado de la API. Admite `--once` y `--batch=50`
para ejecución limitada. API y worker comparten configuración y base de datos.
La aplicación móvil debe autorizar el mismo origen del almacenamiento; no se reescribe el host
de una firma. Ver `infra/media/README.md` para desarrollo con Android.

## Integrar con otros lotes

Importar `ManagePhotos` y `Photo` exclusivamente desde `media/index.ts`, e importar `MediaModule`
en la composición correspondiente. `owned(id, actor)` valida propiedad y oculta archivos ajenos
con 404; B comprueba además `state === 'listo'` al guardar una referencia. La autorización del
padre, moderación, publicación, retirada de referencias y entrega pública se resuelven con B/D.
No se ofrece lectura anónima de borradores ni se aceptan URLs del cliente como referencias.

Pruebas: `npm run verify` y `npm run test:integration` con PostgreSQL 18/PostGIS 3.6.
La integración utiliza almacenamiento falso; el firmado se comprueba con el SDK real y el
procesamiento con Sharp real. La recepción en R2 y el worker desplegado requieren credenciales.
