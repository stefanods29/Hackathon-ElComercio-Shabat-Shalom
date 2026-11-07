# Metas de la Fase 3 por etapa

La Fase 3 no tiene una única condición de salida (sección 12): cada etapa se da por cumplida con sus
metas. Los números son un **ejemplo** y se fijan con el presupuesto de cada etapa (decisión 13.3.5).

## Etapa ciudad

| Meta | Aceptación (ejemplo) | Lote · parte | Evidencia | Estado |
|---|---|---|---|---|
| Aguanta el pico de emergencia | k6 con ~2 500 peticiones por segundo más la reconexión simultánea de miles de clientes de sync, en un entorno de tamaño real: p95 y tasa de error dentro de lo acordado y la cola crítica sin degradarse | A · 1 + B · 1–2 | `evidencias/capacidad-ciudad.md` | ☐ |
| Las colas no pierden trabajos | Migración de pg-boss a BullMQ sin pérdidas ni duplicados, con las pruebas de contrato en verde | B · 1 | `evidencias/colas.md` | ☐ |
| Las lecturas escalan | Búsqueda y rankings servidos desde réplicas, con el retraso de replicación vigilado y quien escribe viendo su propio cambio | B · 2 | `evidencias/replicas.md` | ☐ |
| Sumar un distrito es rutina | Un distrito nuevo con zonas, teselas y directorio de emergencia en 1 día o menos | C · 1 | `evidencias/nuevo-distrito.md` | ☐ |
| El borde protege la API | WAF y límites de tasa activos; una prueba de tráfico abusivo no afecta a los vecinos | C · 2 | `evidencias/borde.md` | ☐ |
| Cuesta lo presupuestado | Costo mensual por usuario activo dentro del presupuesto de la etapa | C · 3 | `evidencias/costos.md` | ☐ |
| Se entiende en quechua | Todos los textos traducidos y revisados por hablantes; prueba con usuarios quechuahablantes | D · 1 | `evidencias/quechua.md` | ☐ |
| Accesible de punta a punta | Auditoría WCAG 2.2 AA sin hallazgos críticos en los flujos principales | D · 2 | `evidencias/accesibilidad.md` | ☐ |

## Etapa país

| Meta | Aceptación (ejemplo) | Lote · parte | Evidencia | Estado |
|---|---|---|---|---|
| Cada extracción está justificada | Cada servicio extraído tiene la métrica que la pidió (sección 4.6) y su ADR | B · 4 | ADR de cada extracción | ☐ |
| Los datos crecen sin degradar | Particionado por región y por fecha con consultas y mantenimiento dentro de lo acordado | B · 3 | `evidencias/particionado.md` | ☐ |
| Se recupera de un desastre | Simulacro de recuperación con varias zonas de disponibilidad, dentro del RTO y el RPO acordados | C · 2 | `evidencias/recuperacion.md` | ☐ |
| La sincronización aguanta el país | Prueba de carga de sync con el volumen de la etapa | A · 1 | `evidencias/capacidad-pais.md` | ☐ |
