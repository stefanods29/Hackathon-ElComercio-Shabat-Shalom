# Proposal

## Why

La arquitectura v2 está aprobada y la Fase 0 (sección 12) exige un esqueleto con todas las piezas
del stack. Para que los cuatro lotes trabajen **en simultáneo** sin bloquearse, primero hacen falta
cimientos comunes: estructura del monorepo, contratos (API, base de datos, Sync Streams), núcleo
compartido del backend, núcleo de la app y CI. Dueño y aprobación: Lote A.

## What Changes

- Monorepo con `backend/` (NestJS 12 en Node.js 26), `app/` (Flutter 3.47), `contracts/`
  (OpenAPI 3.1), `infra/` (PostgreSQL 18 + PostGIS 3.6, PowerSync, CDN local), `openspec/`, `docs/`.
- Backend: monolito modular con los 8 módulos de la sección 4.2 (esqueletos) y fronteras
  verificadas en CI; núcleo compartido con Problem Details (RFC 9457), validación Standard Schema,
  JWT ES256 + JWKS, `Idempotency-Key`, outbox transaccional y puerto de colas.
- Implementación de referencia de punta a punta: muro de favores (publicar y tomar un favor) con
  concurrencia optimista, eventos en el outbox y pruebas contra PostgreSQL real.
- Sync Streams iniciales por zona (validados con el parser oficial de PowerSync).
- App: núcleo (tema accesible, router, inyección con Riverpod, i18n es-PE, máquina de estados de
  envío, política de reintentos con jitter, modo Normal/Emergencia/Recuperación) y dobles en memoria
  para que la UI avance sin esperar al motor de sincronización.
- CI en GitHub Actions para backend, app (Android en cada PR, iOS en `main`) y especificaciones.

Fuera de alcance (lo entregan los lotes): OTP y sesiones reales (B), motor PowerSync en el celular,
cifrado y purga (A), mapas y notificaciones (C), pantallas finales y tutorial (D).

## Capabilities

### New Capabilities
- `plataforma/convenciones-api`: formato de errores, versión, autenticación por defecto y salud.
- `plataforma/idempotencia`: reintentos seguros con `Idempotency-Key`.
- `identidad/credenciales`: sesión de desarrollo, credenciales de PowerSync y JWKS.
- `solidaridad/muro-de-favores`: publicar en el muro y tomar un favor sin duplicados ni carreras.
- `app/estados-de-envio`: estados visibles de cada acción y decisión de reintentar o rechazar.
- `sincronizacion/datos-por-zona`: qué datos públicos llegan a cada celular según su zona.

### Modified Capabilities

## Impact

Crea todo el código base del repositorio. Contratos que los lotes deben respetar:
`contracts/openapi.yaml`, migraciones por módulo (`backend/src/**/migrations/`),
`infra/powersync/sync-config.yaml` e interfaces de `app/lib/**/domain/`.
