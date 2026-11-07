# 0002 · Stack del backend

**Contexto.** La sección 13.2 dejaba por confirmar NestJS 12 con Node 26 y el ORM (Drizzle o
Kysely) con ESM.

**Decisión.** NestJS 12.4 en ESM sobre Node 26, **Kysely 0.29** (consultas tipadas y SQL explícito
para PostGIS), migraciones por módulo con un proveedor propio, Zod 4 vía Standard Schema, Vitest 4,
oxlint y dependency-cruiser para las fronteras del monolito modular.

**Consecuencias.** Confirmado en los cimientos: compila, pasa pruebas unitarias y de integración
con PostgreSQL real. Las fronteras se verifican en CI (`npm run boundaries`).
