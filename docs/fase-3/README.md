# Fase 3 · Escala

El objetivo es pasar de un barrio a la ciudad y luego al país sin cambiar el producto: más zonas y
distritos, quechua, colas y lecturas que aguanten el volumen, y servicios separados solo cuando una
métrica lo pida (secciones 4.6 y 5.6). La fase empieza cuando la Fase 2 cumple sus
[criterios de salida](../fase-2/criterios-de-salida.md). No tiene una salida única: avanza por
etapas, cada una con sus [metas](criterios-de-salida.md).

## Estado

| Carpeta | Qué es | Dificultad | Responsable | Estado |
|---|---|---|---|---|
| [`lote-a-sincronizacion-a-escala/`](lote-a-sincronizacion-a-escala/) | Sincronización a escala, varias zonas por persona, I+D de malla entre celulares e integración | ★★★★ | Stefano | Pendiente (0 de 4 partes) |
| [`lote-b-colas-replicas-y-servicios/`](lote-b-colas-replicas-y-servicios/) | Valkey + BullMQ, réplicas de lectura, particionado y extracción de servicios | ★★★ | Por asignar | Pendiente (0 de 4 partes) |
| [`lote-c-zonas-borde-y-costos/`](lote-c-zonas-borde-y-costos/) | Más zonas y distritos, CDN + WAF, recuperación ante desastres y costos | ★★ | Por asignar | Pendiente (0 de 3 partes) |
| [`lote-d-quechua-y-accesibilidad/`](lote-d-quechua-y-accesibilidad/) | Quechua, auditoría de accesibilidad y mejoras por métricas | ★ | Por asignar | Pendiente (0 de 3 partes) |

## Etapas (sección 5.6)

| Etapa | Alcance | Usuarios aprox. | Qué cambia en la infraestructura |
|---|---|---|---|
| **Micro** | Un barrio o distrito | Hasta ~10 mil | Lo que dejan las fases 1 y 2 |
| **Ciudad** | Lima Metropolitana | ~100 mil a 1 millón | Autoescalado, PgBouncer, réplicas de lectura, Valkey + BullMQ, workers separados, vistas materializadas |
| **País** | Todo el Perú | Varios millones | Particionado, *sharding* por zona, extracción de Notificaciones, Media y Emergencias, varias zonas de disponibilidad |

Una etapa se trabaja cuando las métricas de la anterior se acercan a su límite, no antes: así no se
paga infraestructura que todavía no hace falta.

## Cómo contribuir

Igual que en la [Fase 1](../fase-1/README.md#cómo-contribuir), con ramas
`f3-lote-<letra>/parte-<n>-<tema>`. Cada extracción de un servicio o cambio de infraestructura grande
lleva su ADR.

## Documentos de la Fase 3

| Documento | Para qué sirve |
|---|---|
| [`plan-de-lotes.md`](plan-de-lotes.md) | Los 4 lotes, cómo encajan y cuándo se activa cada parte |
| [`criterios-de-salida.md`](criterios-de-salida.md) | Metas de cada etapa |
| [`evidencias/`](evidencias/) | Pruebas de carga, costos y pruebas con usuarios |
