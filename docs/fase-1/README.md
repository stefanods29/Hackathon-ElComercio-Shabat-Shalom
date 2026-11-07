# Fase 1 · Piloto en un barrio

El objetivo es que un barrio real use la app todas las semanas: buscar un servicio cercano con
Visto Bueno de sus vecinos, reseñarlo con fotos, pedir y ofrecer favores, denunciar lo que no
corresponde y tener a mano el directorio de emergencia aunque no haya señal. La fase empieza
cuando la Fase 0 cumple sus [criterios de salida](../fase-0/criterios-de-salida.md) y termina con
los [criterios de esta fase](criterios-de-salida.md).

## Estado

**En curso desde el 7 de noviembre de 2026.** Cada lote tiene su change de OpenSpec con sus
tareas y los contratos acordados entre lotes. Hasta que el equipo los confirme se asume que el
barrio piloto es la zona sembrada de Lince (demo) y que entran todos los flujos de la sección 12
(decisión 13.3.1). Los números de los criterios de salida se fijan al preparar el piloto (Lote A,
parte 5).

| Carpeta | Qué es | Dificultad | Responsable | Estado |
|---|---|---|---|---|
| [`lote-a-datos-offline-y-metricas/`](lote-a-datos-offline-y-metricas/) | Streams públicos del directorio y la reputación, directorio de emergencia offline, métricas de sincronización, piloto e integración | ★★★★ | JDiazD33 | Pendiente (0 de 6 partes) |
| [`lote-b-directorio-reputacion-y-moderacion/`](lote-b-directorio-reputacion-y-moderacion/) | Directorio, búsqueda, reseñas y ranking, identidad del piloto y moderación | ★★★ | Por asignar | Pendiente (0 de 5 partes) |
| [`lote-c-fotos-entornos-y-observabilidad/`](lote-c-fotos-entornos-y-observabilidad/) | Módulo Media, fotos en la app, compartir por WhatsApp, entornos con OpenTofu y observabilidad | ★★ | Por asignar | Pendiente (0 de 5 partes) |
| [`lote-d-pantallas-del-piloto/`](lote-d-pantallas-del-piloto/) | Pantallas del directorio, perfil y reseñas, botón de emergencia, consentimiento y derechos ARCO | ★ | Por asignar | Pendiente (0 de 5 partes) |

El estado de cada parte está en la tabla "Estado del lote" de cada guía. Los cuatro lotes se
trabajan en simultáneo; donde uno necesita algo de otro, la guía dice qué doble usar mientras
tanto.

## Cómo contribuir

1. Lee la guía de tu lote y su change de OpenSpec: el change fija los contratos con los demás
   lotes (tablas, columnas, rutas, eventos y puertos).
2. Al abrirse la fase ([`../hoja-de-ruta.md`](../hoja-de-ruta.md#cómo-se-abre-una-fase)), elige
   un lote sin responsable o una parte **Pendiente** del tuyo y márcala **En curso** con tu
   nombre.
3. Trabaja en la rama `f1-lote-<letra>/parte-<n>-<tema>`, compila y depura, y abre el PR como dice
   [`revision-y-entregas.md`](../fase-0/revision-y-entregas.md). En ese PR marca la parte
   **Hecha**.

## Reglas para todos los lotes

Valen las mismas de la Fase 0 (sección 0.1 de cada guía), además de estas:

1. **Datos públicos sin ubicación exacta de personas.** Todo lo que viaja en un stream automático
   usa la precisión que decide el Lote A en su parte 1.
2. **Contenido de vecinos siempre moderable.** Toda publicación, reseña, servicio o foto puede
   denunciarse y ocultarse. Al ocultarse, sale de los streams y de los celulares.
3. **Consentimiento antes de tratar datos** (Ley 29733 y D.S. 016-2024-JUS). Si una función
   nueva usa datos personales, declara su finalidad y pide el consentimiento que corresponda.
4. **Sin datos personales en la telemetría.** Métricas, trazas y errores no llevan teléfonos,
   nombres, contenido ni ubicaciones.

## Documentos de la Fase 1

| Documento | Para qué sirve |
|---|---|
| [`plan-de-lotes.md`](plan-de-lotes.md) | Los 4 lotes, cómo encajan, hitos y decisiones de la fase |
| [`criterios-de-salida.md`](criterios-de-salida.md) | Cuándo termina el piloto |
| [`evidencias/`](evidencias/) | Resultados del piloto y de las pruebas |

Las tareas con casillas de cada lote están en
`openspec/changes/fase-1-lote-<letra>-…/tasks.md`.
