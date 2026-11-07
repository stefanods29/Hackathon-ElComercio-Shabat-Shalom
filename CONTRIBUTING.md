# Cómo contribuir · App vecinal (Hackathon El Comercio)

Reglas para todas las personas que trabajan en este repositorio. La arquitectura aprobada está en
`docs/arquitectura/` y las correcciones posteriores en `docs/adr/`. Fase actual: **Fase 1**,
dividida en los Lotes A–D (`docs/fase-1/plan-de-lotes.md`).

## Estructura

| Carpeta | Contenido |
|---|---|
| `backend/` | API NestJS 12 (monolito modular): `src/shared/` núcleo, `src/modules/<módulo>/` |
| `app/` | App Flutter: `lib/core/` transversal, `lib/features/<funcionalidad>/` |
| `contracts/` | Contrato OpenAPI 3.1 de la API (`openapi.yaml`): primero el contrato, luego el código |
| `infra/` | Docker Compose local: PostgreSQL 18 + PostGIS 3.6, PowerSync, CDN |
| `openspec/` | Specs y changes (un change por lote) |
| `docs/` | Arquitectura, ADRs, plan de lotes, revisión, criterios de salida, grafos |

## Stack y versiones

Node 26 · NestJS 12.4 (ESM) · TypeScript 6.0 · Kysely 0.29 · Zod 4 · jose (ES256) · Vitest 4 ·
oxlint · Prettier · dependency-cruiser · Flutter 3.47.9 / Dart 3.13 · Riverpod 3.4 ·
go_router 18 · dio 5 · PowerSync (Sync Streams) · PostgreSQL 18 + PostGIS 3.6 · OpenSpec 1.16.1.

## Comandos

```bash
# Infraestructura local
cd infra && docker compose up -d

# Backend
cd backend
npm ci
npm run dev:keys          # crea .env con una clave ES256 nueva (no se sube)
npm run db:migrate        # migraciones de todos los módulos
npm run db:seed           # zonas y vecinos de demostración
npm run start:dev
npm run start:workers:dev # otra terminal: relay, trabajos y limpieza (Lote B, Parte 4)
npm run verify            # tipos, lint, formato, fronteras, Sync Streams, pruebas y build
DATABASE_URL_ADMIN=postgres://postgres:postgres@localhost:5432/postgres npm run test:integration
npm run graph             # grafo de dependencias en docs/grafos/

# App (desde app/)
flutter pub get && flutter gen-l10n
flutter analyze && flutter test
dart format lib test
tool\verify.cmd           # Windows · en macOS/Linux: tool/verify.sh

# Specs y contrato (desde la raíz)
openspec validate --all --strict
npx @redocly/cli lint contracts/openapi.yaml
```

## Convenciones

- **Código en inglés:** clases, funciones, variables, archivos, variables de entorno y scripts.
- **En español:** todo lo que ve el vecino (textos de la app en `app_es.arb`), el contrato de la
  API (rutas, campos JSON, códigos de error), tablas y columnas, carpetas de módulos y la
  documentación.
- **OpenSpec:** documentos en español; encabezados estructurales y SHALL/MUST en inglés.
- **Backend:** cada módulo es dueño de su esquema de Postgres; otros módulos solo usan su
  `index.ts` o eventos de dominio (`npm run boundaries`). Errores en Problem Details (RFC 9457).
  Toda escritura que el celular puede reintentar lleva `@Idempotent()`. Los eventos van al outbox
  en la misma transacción. Copia el patrón de `src/modules/solidaridad`.
- **App:** la UI solo lee de la base local; la red solo actualiza la base local. Cada pieza real
  reemplaza a su doble sobreescribiendo el proveedor de Riverpod. Toda acción muestra su estado:
  "Guardado en tu celular", "Enviado" o "No se pudo completar". Meta WCAG 2.2 AA. Copia el patrón
  de `lib/features/solidaridad`.

## Forma de trabajo

- Una parte de un lote por rama: `f<fase>-lote-<letra>/parte-<n>-<tema>` (en la Fase 0 fue
  `lote-<letra>/parte-<n>-<tema>`).
- **Al terminar cada parte se compila y se depura** lo tocado (backend y/o app) antes de pedir
  revisión.
- La entrega y la revisión siguen `docs/fase-0/revision-y-entregas.md`.
- Si una parte cambia dependencias entre módulos, se actualiza el grafo (`npm run graph`).

## Seguridad

- Secretos en `.env` (fuera del repo); cada variable nueva se documenta en `backend/.env.example`.
- Nunca subir contraseñas, claves, tokens ni datos reales de vecinos.
- Datos sensibles (pedidos de ayuda, ubicación exacta, salud) nunca en streams automáticos ni en el
  texto de una notificación.
