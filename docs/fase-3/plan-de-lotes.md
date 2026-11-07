# Plan de lotes · Fase 3 (escala)

**Entra** cuando la Fase 2 cumple sus criterios de salida. Cada parte se activa con una señal
medida, no con una fecha: la tabla dice cuál.

## Los 4 lotes

| Lote | Partes | Qué entrega |
|---|---|---|
| **A · Sincronización a escala** ★★★★ | 4 | PowerSync con miles de reconexiones simultáneas, varias zonas por persona y zonas vecinas, I+D de malla entre celulares e integración de cada etapa |
| **B · Colas, réplicas y servicios** ★★★ | 4 | Valkey + BullMQ detrás de `JobQueue`, réplicas de lectura y PgBouncer, particionado y extracción de servicios con Strangler Fig |
| **C · Zonas, borde y costos** ★★ | 3 | Alta de zonas y distritos con mapas y directorio de emergencia, CDN + WAF y recuperación ante desastres, costos por etapa |
| **D · Quechua y accesibilidad** ★ | 3 | Quechua revisado con hablantes, auditoría WCAG 2.2 AA completa y mejoras por métricas de uso |

## Cuándo se activa cada parte

| Parte | Señal que la activa |
|---|---|
| A1 · Sincronización a escala | Se planea abrir la etapa ciudad, o la reconexión masiva supera lo medido en el simulacro |
| A2 · Varias zonas | Hay vecinos en el límite entre zonas o se dividen zonas |
| A3 · Malla entre celulares | El equipo decide investigarla (es I+D: puede terminar en "no seguir") |
| B1 · Valkey + BullMQ | La cola en Postgres compite con las consultas o su latencia crece en los picos |
| B2 · Réplicas y PgBouncer | Las lecturas pesadas (búsqueda y rankings) suben la carga del primario |
| B3 · Particionado | Los pedidos de ayuda o los datos por región crecen hasta afectar las consultas o el mantenimiento |
| B4 · Extracción | Una señal de la sección 4.6, por ejemplo envíos masivos de Notificaciones que compiten con el resto en una emergencia |
| C1 · Más zonas | Un aliado o distrito nuevo pide sumarse |
| C2 · Borde | Tráfico abusivo o el paso a la etapa ciudad |
| C3 · Costos | Desde el inicio de la fase, y en cada cambio de etapa |
| D1–D3 | Desde el inicio de la fase |

## Cómo encajan

- `JobQueue` no cambia de interfaz: B1 agrega un adaptador y las pruebas de contrato de la cola son
  las mismas para pg-boss y BullMQ.
- Cada extracción (B4) se comunica por los eventos que ya existen y tiene su propia base de datos;
  A comprueba que los streams no dependan del servicio extraído.
- Cada distrito nuevo (C1) necesita sus teselas, su directorio de emergencia y su regla de
  cobertura antes de habilitar pedidos de ayuda (Fase 2).
- D trabaja sobre `app_es.arb`: cada texto nuevo de cualquier lote tiene que llegar también al
  quechua.

## Changes de OpenSpec

Uno por lote al abrir la fase (`fase-3-lote-a-sincronizacion-a-escala`,
`fase-3-lote-b-colas-replicas-y-servicios`, `fase-3-lote-c-zonas-borde-y-costos` y
`fase-3-lote-d-quechua-y-accesibilidad`). Si una parte se activa mucho después que las demás, puede
ir en su propio change.
