# 0001 · Monorepo y contrato OpenAPI primero

**Contexto.** Cuatro lotes trabajan en paralelo sobre backend, app e infraestructura que deben
encajar.

**Decisión.** Un solo repositorio (`backend/`, `app/`, `contracts/`, `infra/`, `openspec/`,
`docs/`). Toda ruta nueva se define primero en `contracts/openapi.yaml` (validado con Redocly en
CI) y luego se implementa con esquemas Zod alineados.

**Consecuencias.** Un PR puede cambiar contrato, backend y app a la vez; los lotes se coordinan
sobre el contrato y no sobre el código del otro.
