# Fase 0 · Prueba técnica

Aquí está todo lo que se está haciendo en la Fase 0: lo que ya está hecho y lo que falta, lote por
lote. Si vas a contribuir, empieza por esta página.

## Estado

| Carpeta | Qué es | Dificultad | Responsable | Estado |
|---|---|---|---|---|
| [`cimientos/`](cimientos/) | La base de todo: backend, app, contrato, infraestructura y CI | — | — | **Hecho** |
| [`lote-a-nucleo-offline/`](lote-a-nucleo-offline/) | PowerSync, base cifrada y purga, cola de subida, datos sensibles, pruebas de campo e integración | ★★★★ | Stefano | Pendiente (0 de 6 partes) |
| [`lote-b-api-identidad-y-trabajos/`](lote-b-api-identidad-y-trabajos/) | Inicio de sesión con código, sesiones, roles, trabajos en segundo plano, muro completo y carga | ★★★ | Por asignar | Pendiente (0 de 6 partes) |
| [`lote-c-mapas-y-avisos/`](lote-c-mapas-y-avisos/) | Mapa sin conexión y notificaciones push | ★★ | Por asignar | Pendiente (0 de 4 partes) |
| [`lote-d-experiencia-accesible/`](lote-d-experiencia-accesible/) | Diseño accesible, publicar en 3 toques, estados visibles, tutorial, inicio de sesión y cuenta | ★ | Por asignar | Pendiente (0 de 5 partes) |

El estado de **cada parte** está en la tabla "Estado del lote" del README de cada carpeta. Los
cuatro lotes se trabajan en simultáneo: ninguno espera a otro para empezar.

## Cómo contribuir

1. Elige un lote que no tenga responsable o una parte **Pendiente** de tu lote.
2. Abre la carpeta del lote y lee su README completo: dice lo que ya está hecho (sección 0.2), las
   reglas y, parte por parte, qué archivos crear, cómo probarlos y cuándo está terminado.
3. Marca la parte **En curso** con tu nombre (en el issue del lote o en un PR pequeño) para que
   nadie la duplique.
4. Trabaja en la rama `lote-<letra>/parte-<n>-<tema>`, compila y depura, y abre el PR como dice
   [`revision-y-entregas.md`](revision-y-entregas.md). En ese PR marca la parte **Hecha**.

## Documentos de la Fase 0

| Documento | Para qué sirve |
|---|---|
| [`plan-de-lotes.md`](plan-de-lotes.md) | Visión general: los 4 lotes, cómo encajan, hitos y lo que sigue después de la Fase 0 |
| [`revision-y-entregas.md`](revision-y-entregas.md) | Cómo se entrega cada parte y cómo se revisa antes de integrarla |
| [`criterios-de-salida.md`](criterios-de-salida.md) | Cuándo termina la Fase 0 (sección 13.1 de la arquitectura) |
| [`evidencias/`](evidencias/) | Resultados de las pruebas de campo |

Las tareas con casillas de cada lote están en `openspec/changes/<lote>/tasks.md`. Cuando un lote
termina, su change se archiva en `openspec/changes/archive/` y sus criterios pasan a
`openspec/specs/`.
