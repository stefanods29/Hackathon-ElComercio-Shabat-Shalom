# 0005 · Idempotencia y outbox propios en PostgreSQL

**Contexto.** Los reintentos de la cola offline no pueden duplicar acciones, y los eventos no se
pueden perder si la API se cae entre guardar y publicar.

**Decisión.** `Idempotency-Key` obligatoria en las escrituras marcadas con `@Idempotent()`, guardada
en `compartido.idempotencia` (reserva atómica con `INSERT … ON CONFLICT`, 200 +
`Idempotent-Replayed: true` en los reintentos, rechazos 4xx guardados, 5xx/408/429 liberan la
clave, reservas abandonadas se retoman a los 60 s). Eventos de dominio en `compartido.outbox` en
la misma transacción; el relay y los workers son del Lote B (pg-boss detrás del puerto `JobQueue`).

**Consecuencias.** Sin Valkey en la etapa micro; el cambio a BullMQ + Valkey (Fase 3) es otro
adaptador del mismo puerto.
