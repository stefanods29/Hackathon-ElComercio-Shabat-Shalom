# Módulo `solidaridad` (implementación de referencia)

**Responsabilidad:** muro de favores: publicar, tomar un favor (el primero gana; el segundo
recibe un 409 explicable), cancelar, resolver y buscar por cercanía.

Las escrituras exigen `Idempotency-Key`; los cambios de estado comprueban autoría/participación,
zona y versión, y guardan su evento en el outbox en la misma transacción. Repetir una
cancelación o resolución ya aceptada no incrementa la versión ni duplica el evento.

`GET /v1/publicaciones` requiere acceso y zona, y devuelve solo publicaciones abiertas,
no eliminadas y no vencidas de esa zona. Usa PostGIS con radio de 100–5000 m, páginas de
1–50 filas y orden por distancia/id. La distancia visible y el cursor se redondean a 50 m;
la posición de búsqueda no se guarda. El servidor recalcula la distancia de la última fila
para continuar sin perder el orden real. La ubicación publicada ya es aproximada (≈100 m).

`MAX_POSTS_PER_DAY` limita las nuevas publicaciones por autor en las últimas 24 horas
(por defecto 10). Incluye canceladas y eliminadas; no incluye nuevamente los reintentos del
mismo id. Un bloqueo transaccional por autor protege la comprobación e inserción concurrentes.
Al superar el límite se devuelve 429 `limite_diario_alcanzado` y `Retry-After`.

La Parte 5 se entrega sobre la Parte 2; roles/guards y workers se conservan en sus ramas
respectivas para revisión. Evidencia: `docs/fase-0/evidencias/muro.md`.

Copia este patrón en los demás módulos: `domain/` (TypeScript puro), `application/` (casos de
uso y puertos), `infrastructure/` (Kysely y `migrations/`), `api/` (controlador y esquemas Zod).
Esquema propio: `solidaridad.*`.
