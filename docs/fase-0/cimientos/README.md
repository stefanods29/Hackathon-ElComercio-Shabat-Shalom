# Cimientos de la Fase 0

> **Estado: Hecho.** Está integrado en `main` y su change de OpenSpec ya está archivado en
> `openspec/changes/archive/2026-11-07-fase-0-cimientos/`. Sus criterios pasaron a
> `openspec/specs/`, la especificación viva de la app.

Esto es lo que ya existe y **no hay que volver a hacer**. Cada lote parte de aquí.

## Backend (`backend/`)

- Monolito modular en NestJS 12 con los 8 módulos de la arquitectura. `identidad` y `solidaridad`
  ya funcionan; `directorio`, `reputacion`, `emergencias`, `notificaciones`, `media` y `moderacion`
  son esqueletos listos para llenar. Las fronteras entre módulos se verifican con
  `npm run boundaries`.
- Núcleo compartido (`src/shared/`): errores en formato Problem Details (RFC 9457), validación con
  Zod, tokens JWT ES256 con su JWKS, `Idempotency-Key` guardada en PostgreSQL, outbox
  transaccional, puerto de colas (con un doble en memoria) y `GET /v1/salud`.
- `identidad`: sesión de desarrollo (`POST /v1/dev/sesiones`, prohibida en producción) y
  credenciales de PowerSync (`GET /v1/sync/credenciales`).
- `solidaridad`, la implementación de referencia: publicar en el muro y tomar un favor, sin
  duplicados, con concurrencia optimista y eventos en el outbox.
- Migraciones de `compartido`, `identidad` y `solidaridad`, y una semilla de demostración (zona
  piloto y 5 vecinos).
- Verificado: 36 pruebas unitarias y 17 de integración contra PostgreSQL + PostGIS, lint,
  formato, fronteras y build.

## App (`app/`)

- Flutter 3.47.9 con Riverpod 3, go_router y textos en español (`app_es.arb`).
- Núcleo: estados de envío (*Guardado en tu celular*, *Enviado*, *No se pudo completar*),
  clasificación de las respuestas de la API, reintentos con espera aleatoria, modo
  Normal/Emergencia/Recuperación, tema accesible, aviso sin conexión, almacén seguro y cliente HTTP.
- Muro de favores de referencia sobre un doble en memoria, que el Lote A cambia por PowerSync sin
  tocar las pantallas.
- Plataformas `android/` e `ios/` generadas y versiones fijadas en `pubspec.lock`.
- Verificado en Windows: `flutter analyze` sin avisos y 28 pruebas en verde, más la CI de GitHub.

## Contrato, infraestructura y CI

- `contracts/openapi.yaml` (OpenAPI 3.1), validado con Redocly.
- `infra/`: PostgreSQL 18 + PostGIS 3.6 con replicación lógica, PowerSync y una CDN local. Los Sync
  Streams por zona están validados con el parser oficial de PowerSync.
- GitHub Actions para el backend, la app (Android e iOS) y las especificaciones.

## Organización

- OpenSpec con un change por lote, plan de lotes, protocolo de revisión, criterios de salida,
  7 ADRs (`docs/adr/`) y `CONTRIBUTING.md`.
