# Lote B · Colas, réplicas y servicios (Fase 3)

| Dato | Valor |
|---|---|
| Dificultad | ★★★ Media-alta |
| Área | `backend/src/shared/queues/`, `backend/src/shared/database/`, `backend/src/modules/`, `infra/tofu/`, `docs/adr/` |
| Change de OpenSpec | `fase-3-lote-b-colas-replicas-y-servicios` (se crea al abrir la fase) |
| Partes | 4. Cada una se activa con su señal (ver el [plan](../plan-de-lotes.md#cuándo-se-activa-cada-parte)) |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Valkey + BullMQ detrás de `JobQueue` | Pendiente | Por asignar | — |
| 2 | Réplicas de lectura, PgBouncer y vistas materializadas | Pendiente | Por asignar | — |
| 3 | Particionado y retención | Pendiente | Por asignar | — |
| 4 | Extracción de servicios con Strangler Fig | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## Parte 1 · Valkey + BullMQ detrás de `JobQueue`

- Adaptador nuevo de `JobQueue` (ADR-0005 ya lo anticipa) con las mismas pruebas de contrato que
  pg-boss: prioridades, reintentos, trabajos programados e idempotencia.
- Migración sin pérdidas: se vacía la cola de Postgres mientras la nueva toma los trabajos nuevos.
- Límites de tasa (*token bucket*) en Valkey para los picos de emergencia (sección 4.3).

## Parte 2 · Réplicas de lectura, PgBouncer y vistas materializadas

- PgBouncer delante de PostgreSQL y una o dos réplicas de lectura en OpenTofu.
- Enrutar a las réplicas solo las lecturas pesadas (búsqueda del directorio y rankings). Quien
  acaba de escribir lee del primario, para ver su propio cambio.
- Vistas materializadas para los rankings, refrescadas por un worker.

## Parte 3 · Particionado y retención

- Particionado de los pedidos de ayuda por fecha y de los datos por región (sección 5.6).
- Políticas de retención y anonimización que respeten la Ley 29733 y el cierre de eventos de la
  Fase 2.

## Parte 4 · Extracción de servicios con Strangler Fig

- Solo con una señal de la sección 4.6. El primer candidato es Notificaciones; después Media y
  Emergencias.
- Cada extracción tiene su ADR, su base de datos propia y se comunica por los eventos que ya
  existen. Las claves foráneas entre módulos se reemplazan por validación con eventos.
- `npm run boundaries` y `npm run graph` reflejan el nuevo límite.

## Fuera de alcance

Funciones nuevas del producto y cambios en el contrato que no pida la escala.
