## Context

La Fase 0 tiene mapas y avisos locales. Identidad, sincronización y moderación de otros lotes
todavía no están integradas en esta rama. No se sustituye esa autorización por una sesión falsa.

## Goals / Non-Goals

Implementar fotos, compartir y bases operativas verificables. No publicar imágenes sin moderación
ni desplegar recursos con costo. Las fotos originales nunca se vuelven públicas.

## Decisions

- Subida de un JPEG/PNG/WebP de hasta 2 MiB a cuarentena privada mediante URL de cinco minutos.
  El cliente conserva ID y huella; una URL vencida se renueva con una operación nueva.
- Saneamiento en el dispositivo y nuevamente en servidor: orientación, tamaño, EXIF/GPS borrado,
  salida WebP y miniatura; leer bytes reales y verificar SHA-256 antes de procesar.
- Estados y arrendamiento de procesamiento en la tabla Media: el worker recupera pendientes y
  trabajos interrumpidos. No se agrega una segunda cola general que sustituya el trabajo de B.
- Un archivo listo solo es accesible a su dueño; su publicación requiere integración con B.
- Separar selección, almacenamiento cifrado, API y transferencia nativa con puertos inyectables.
- Monitoreo por exclusión predeterminada: no exportar solicitudes ni excepciones sin filtrar.

```mermaid
flowchart LR
  P[Foto seleccionada] --> S[Saneamiento local]
  S --> L[Borrador cifrado]
  L --> A[API autenticada]
  A --> U[Subida firmada privada]
  U --> Q[Pendiente persistente]
  Q --> W[Worker Media]
  W --> R[Foto y miniatura sin EXIF]
  R --> O[Vista privada del autor]
```

## Risks / Trade-offs

La ejecución nativa es oportunista: el sistema puede retrasar una transferencia y las URLs
caducan. Se reintenta desde el estado durable. El saneamiento no sustituye la moderación de
contenido. Infraestructura propuesta requiere evaluación de región, costos y proveedor.

## Migration Plan

Agregar el esquema Media sin incluirlo en PowerSync. Desplegar API/worker de la misma versión,
configurar almacenamiento privado y luego habilitar fotos en la app. Rollback de código conserva
objetos privados; no borrar datos al revertir una versión. Las migraciones se ejecutan como tarea
controlada antes del cambio de tráfico, nunca desde cada réplica.
