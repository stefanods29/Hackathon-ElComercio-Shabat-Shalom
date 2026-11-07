# Tasks

## 1. Estructura y contratos

- [x] 1.1 Crear el monorepo (`backend/`, `app/`, `contracts/`, `infra/`, `openspec/`, `docs/`) y verificar que cada carpeta tiene su README
- [x] 1.2 Escribir `contracts/openapi.yaml` (Fase 0) y verificar con `redocly lint` que es válido
- [x] 1.3 Escribir las migraciones de `compartido`, `identidad` y `solidaridad` y verificar con las pruebas de integración que se aplican en orden y crean la publicación `powersync`
- [x] 1.4 Escribir `infra/powersync/sync-config.yaml` y verificar con `npm run sync:validate` (parser oficial de PowerSync)

## 2. Backend

- [x] 2.1 Núcleo compartido (Problem Details, validación, JWT ES256 + JWKS, idempotencia, outbox, puerto de colas) y verificar con las pruebas unitarias de `src/shared`
- [x] 2.2 Implementación de referencia del muro (publicar, tomar favor) y verificar con las pruebas de dominio, de casos de uso y de punta a punta contra PostgreSQL
- [x] 2.3 Esqueletos de los 8 módulos y reglas de fronteras, y verificar con `npm run boundaries`
- [x] 2.4 Compilar y depurar: `npm run verify` y `npm run test:integration` en verde

## 3. App

- [x] 3.1 Núcleo (tema accesible, router, Riverpod, i18n, estados de envío, reintentos, modo de la app) y verificar con las pruebas de `test/core`
- [x] 3.2 Muro de referencia sobre un doble en memoria y verificar con `test/features` y `test/widget_test.dart`
- [ ] 3.3 Compilar y depurar en la PC del Lote A con `tool/verify.cmd` (Flutter 3.47.9) y en CI

## 4. Organización

- [x] 4.1 CONTRIBUTING.md, ADRs, plan de lotes con grafos, protocolo de revisión, CODEOWNERS y plantilla de PR
- [x] 4.2 Changes de OpenSpec para los Lotes A–D y verificar con `openspec validate --all --strict`
- [x] 4.3 Workflows de CI (backend, app, especificaciones)

## Workflow follow-up

- Archivar este change cuando los cimientos estén en `main` y la tarea 3.3 (compilar la app en la PC del Lote A) esté hecha.
