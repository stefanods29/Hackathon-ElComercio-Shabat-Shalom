# Backend · API vecinal (NestJS 12)

Monolito modular: `src/shared/` es el núcleo compartido y `src/modules/<módulo>/` son los módulos
de negocio (cada uno dueño de su esquema de Postgres). El módulo `solidaridad` es la
implementación de referencia: dominio puro, casos de uso con puertos, adaptadores Kysely y API con
Zod alineada con `../contracts/openapi.yaml`.

```bash
npm ci
npm run dev:keys && npm run db:migrate && npm run db:seed
npm run start:dev                       # http://localhost:3000/v1/salud
npm run verify                          # todo lo que corre CI
DATABASE_URL_ADMIN=postgres://postgres:postgres@localhost:5432/postgres npm run test:integration
```

Variables: `.env.example`. Vecinos de demostración: `scripts/seed-data.ts`
(`POST /v1/dev/sesiones` con su teléfono, solo en desarrollo).
